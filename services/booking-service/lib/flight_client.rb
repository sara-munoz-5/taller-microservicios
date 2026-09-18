require "grpc"
require_relative "aeroreserva_services_pb"

class FlightClient
  def initialize
    @stub = Aeroreserva::V1::FlightService::Stub.new(
      ENV.fetch("FLIGHT_SERVICE_ADDR", "localhost:50051"),
      :this_channel_is_insecure
    )
  end

  def get_flight(id)
    call_with_deadline(id) { |request| @stub.get_flight(request, deadline: Time.now + 3) }
  end

  def occupy_seat(id)
    call_with_deadline(id) { |request| @stub.occupy_seat(request, deadline: Time.now + 3) }
  end

  def release_seat(id)
    call_with_deadline(id) { |request| @stub.release_seat(request, deadline: Time.now + 3) }
  end

  private

  def call_with_deadline(id)
    yield Aeroreserva::V1::GetByIdRequest.new(id: id)
  rescue GRPC::NotFound
    nil
  rescue GRPC::DeadlineExceeded, GRPC::Unavailable
    raise GRPC::BadStatus.new_status_exception(
      GRPC::Core::StatusCodes::UNAVAILABLE,
      "El servicio de vuelos no respondió a tiempo"
    )
  end
end
