require "grpc"
require "json"
require "thread"

# One instance per dependency, shared by the gRPC worker threads.
class GrpcResilience
  TRANSIENT = [GRPC::Unavailable, GRPC::DeadlineExceeded].freeze

  def initialize(dependency:, timeout: ENV.fetch("GRPC_TIMEOUT_SECONDS", "1.0"),
                 threshold: ENV.fetch("GRPC_FAILURE_THRESHOLD", "3"),
                 recovery: ENV.fetch("GRPC_RECOVERY_SECONDS", "10"),
                 retries: ENV.fetch("GRPC_READ_RETRIES", "1"),
                 retry_delay: ENV.fetch("GRPC_RETRY_DELAY_SECONDS", "0.05"),
                 clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
                 sleeper: ->(seconds) { sleep(seconds) }, logger: $stdout)
    @dependency, @clock, @sleeper, @logger = dependency, clock, sleeper, logger
    @timeout, @recovery, @retry_delay = Float(timeout), Float(recovery), Float(retry_delay)
    @threshold, @retries = Integer(threshold), Integer(retries)
    unless @timeout.positive? && @recovery.positive? && @threshold.positive? &&
           @retries.between?(0, 2) && @retry_delay >= 0
      raise ArgumentError, "Invalid gRPC resilience configuration"
    end
    @mutex = Mutex.new
    @state, @failures, @generation = :closed, 0, 0
  end

  def call(operation:, read: false)
    retries_left = read ? @retries : 0
    loop do
      generation, probe = acquire(operation)
      begin
        result = yield(Time.now + @timeout)
      rescue *TRANSIENT => error
        failed(generation, operation, error)
        # A half-open probe is always a single attempt. Writes never retry.
        raise unavailable unless retries_left.positive? && !probe
        retries_left -= 1
        log("retry", operation: operation)
        @sleeper.call(@retry_delay)
        next
      rescue StandardError
        # NOT_FOUND and other business errors prove that the dependency answered.
        succeeded(generation)
        raise
      else
        succeeded(generation)
        return result
      end
    end
  end

  private

  def acquire(operation)
    @mutex.synchronize do
      if @state == :open && @clock.call - @opened_at >= @recovery
        @state = :half_open
        log("half_open_probe", operation: operation)
        return [@generation, true]
      end
      unless @state == :closed
        log("rejected", operation: operation, state: @state)
        raise unavailable
      end
      [@generation, false]
    end
  end

  def succeeded(generation)
    @mutex.synchronize do
      return unless generation == @generation
      return if @state == :open
      log("recovered") if @state == :half_open
      @state, @failures = :closed, 0
    end
  end

  def failed(generation, operation, error)
    @mutex.synchronize do
      return unless generation == @generation
      @failures += 1
      log("failure", operation: operation, failures: @failures, error: error.class.name)
      if @state == :half_open || @failures >= @threshold
        @state, @opened_at = :open, @clock.call
        @generation += 1 # Ignore late results from calls admitted before opening.
        log("opened", operation: operation)
      end
    end
  end

  def unavailable
    GRPC::Unavailable.new("El servicio de #{@dependency} no está disponible temporalmente. Intenta más tarde.")
  end

  def log(event, **fields)
    @logger.puts(JSON.generate({ pattern: "circuit_breaker", dependency: @dependency, event: event }.merge(fields)))
  end
end
