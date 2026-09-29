require "grpc"
require "time"
require "json"
require_relative "aeroreserva_services_pb"
require_relative "cassandra_client"

class FlightServiceImpl < Aeroreserva::V1::FlightService::Service
  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  SOURCE_COLUMNS = "id, flight_number, origin, destination, departure_at, arrival_at, total_capacity, available_seats, WRITETIME(available_seats) AS seat_timestamp".freeze

  def initialize(cas_attempts: ENV.fetch("FLIGHT_CAS_ATTEMPTS", "32"),
                 catalog_batch_size: ENV.fetch("FLIGHT_CATALOG_BATCH_SIZE", "50"), logger: $stdout)
    @cas_attempts, @catalog_batch_size = Integer(cas_attempts), Integer(catalog_batch_size)
    raise ArgumentError, "Flight configuration must be positive" unless @cas_attempts.positive? && @catalog_batch_size.positive?
    @logger = logger
  end

  def list_flights(_request, _call)
    result = CassandraClient.session.execute("SELECT id FROM flights_catalog WHERE catalog = 'ACTIVE'")
    ids = result.map { |row| row["id"] }
    until result.last_page?
      result = result.next_page
      ids.concat(result.map { |row| row["id"] })
    end
    # Catalog indexes membership; flights_by_id is the source of truth for seats.
    # Read in bounded groups, rather than an extra query per flight.
    flights = ids.each_slice(@catalog_batch_size).flat_map do |group|
      placeholders = Array.new(group.length, "?").join(", ")
      CassandraClient.session.execute(
        "SELECT #{SOURCE_COLUMNS} FROM flights_by_id WHERE id IN (#{placeholders})",
        arguments: group, consistency: :local_quorum
      ).to_a
    end
    flights.each { |flight| project_safely(flight) }
    Aeroreserva::V1::FlightList.new(flights: flights.sort_by { |row| [row["departure_at"], row["id"].to_s] }.map { |row| flight_message(row) })
  end

  def get_flight(request, _call)
    flight_message(find_flight(request.id))
  end

  def check_availability(request, _call)
    flight = find_flight(request.id)
    Aeroreserva::V1::AvailabilityResponse.new(available: flight["available_seats"] > 0, available_seats: flight["available_seats"])
  end

  def occupy_seat(request, _call)
    change_seats(request.id, -1)
  end

  def release_seat(request, _call)
    change_seats(request.id, 1)
  end

  private

  def find_flight(id)
    validate_uuid(id)
    row = CassandraClient.session.execute(
      "SELECT #{SOURCE_COLUMNS} FROM flights_by_id WHERE id = ?",
      arguments: [Cassandra::Uuid.new(id)], consistency: :local_quorum
    ).first
    raise GRPC::NotFound.new("Vuelo no encontrado") unless row
    row
  end

  def change_seats(id, delta)
    @cas_attempts.times do
      flight = find_flight(id)
      current = flight["available_seats"]
      updated = current + delta
      unless updated.between?(0, flight["total_capacity"])
        raise GRPC::FailedPrecondition.new(delta.negative? ? "El vuelo no tiene cupos disponibles" : "El vuelo ya tiene todos sus cupos disponibles")
      end
      applied = CassandraClient.session.execute(
        CassandraClient.prepare("UPDATE flights_by_id SET available_seats = ? WHERE id = ? IF available_seats = ?"),
        arguments: [updated, flight["id"], current], consistency: :local_quorum,
        serial_consistency: :local_serial
      ).first["[applied]"]
      # Only a definite CAS conflict may repeat. A transport timeout is ambiguous
      # and propagates without retrying the seat mutation.
      next unless applied

      # Projection failures must not turn a committed mutation into a failed RPC:
      # the re-read and the projection write are both logged, never raised.
      begin
        project_safely(find_flight(id))
      rescue StandardError => error
        projection_log(id, error)
      end
      return flight_message(flight.merge("available_seats" => updated))
    end
    raise GRPC::Aborted.new("El vuelo está recibiendo muchas solicitudes. Consulta de nuevo sus cupos.")
  end

  def project_safely(flight)
    # Replay the source cell timestamp, not a fresh client timestamp. Therefore
    # a delayed projection cannot overwrite a newer seat update (Cassandra LWW).
    CassandraClient.session.execute(
      CassandraClient.prepare("UPDATE flights_catalog USING TIMESTAMP ? SET available_seats = ? WHERE catalog = 'ACTIVE' AND departure_at = ? AND id = ?"),
      arguments: [flight["seat_timestamp"], flight["available_seats"], flight["departure_at"], flight["id"]],
      consistency: :local_quorum
    )
  rescue StandardError => error
    projection_log(flight["id"].to_s, error)
  end

  def projection_log(id, error)
    @logger.puts(JSON.generate(pattern: "flight_projection", event: "repair_pending", flight_id: id, error: error.class.name))
  end

  def flight_message(row)
    Aeroreserva::V1::Flight.new(
      id: row["id"].to_s, flight_number: row["flight_number"], origin: row["origin"],
      destination: row["destination"], departure_at: row["departure_at"].utc.iso8601,
      arrival_at: row["arrival_at"].utc.iso8601, total_capacity: row["total_capacity"],
      available_seats: row["available_seats"]
    )
  end

  def validate_uuid(id)
    raise GRPC::InvalidArgument.new("El identificador del vuelo no es válido") unless id.match?(UUID_PATTERN)
  end
end
