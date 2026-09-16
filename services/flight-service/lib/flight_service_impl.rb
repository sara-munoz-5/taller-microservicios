require "grpc"
require "time"
require_relative "aeroreserva_services_pb"
require_relative "cassandra_client"

class FlightServiceImpl < Aeroreserva::V1::FlightService::Service
  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  def list_flights(_request, _call)
    rows = CassandraClient.session.execute(
      "SELECT * FROM flights_catalog WHERE catalog = 'ACTIVE'"
    )

    Aeroreserva::V1::FlightList.new(
      flights: rows.map { |row| flight_message(row) }
    )
  end

  def get_flight(request, _call)
    flight_message(find_flight(request.id))
  end

  def check_availability(request, _call)
    flight = find_flight(request.id)

    Aeroreserva::V1::AvailabilityResponse.new(
      available: flight["available_seats"] > 0,
      available_seats: flight["available_seats"]
    )
  end

  def occupy_seat(request, _call)
    flight = find_flight(request.id)

    if flight["available_seats"] <= 0
      raise grpc_error(
        GRPC::Core::StatusCodes::FAILED_PRECONDITION,
        "El vuelo no tiene cupos disponibles"
      )
    end

    update_available_seats(flight, flight["available_seats"] - 1)
    flight_message(find_flight(request.id))
  end

  def release_seat(request, _call)
    flight = find_flight(request.id)

    if flight["available_seats"] >= flight["total_capacity"]
      raise grpc_error(
        GRPC::Core::StatusCodes::FAILED_PRECONDITION,
        "El vuelo ya tiene todos sus cupos disponibles"
      )
    end

    update_available_seats(flight, flight["available_seats"] + 1)
    flight_message(find_flight(request.id))
  end

  private

  def find_flight(id)
    validate_uuid(id)

    row = CassandraClient.session.execute(
      "SELECT * FROM flights_by_id WHERE id = #{id}"
    ).first

    unless row
      raise grpc_error(
        GRPC::Core::StatusCodes::NOT_FOUND,
        "Vuelo no encontrado"
      )
    end

    row
  end

  def update_available_seats(flight, new_available_seats)
    id = flight["id"].to_s
    departure_at = flight["departure_at"].utc.strftime("%Y-%m-%dT%H:%M:%SZ")

    CassandraClient.session.execute(
      "UPDATE flights_by_id
       SET available_seats = #{new_available_seats}
       WHERE id = #{id}"
    )

    CassandraClient.session.execute(
      "UPDATE flights_catalog
       SET available_seats = #{new_available_seats}
       WHERE catalog = 'ACTIVE'
       AND departure_at = '#{departure_at}'
       AND id = #{id}"
    )
  end

  def flight_message(row)
    Aeroreserva::V1::Flight.new(
      id: row["id"].to_s,
      flight_number: row["flight_number"],
      origin: row["origin"],
      destination: row["destination"],
      departure_at: row["departure_at"].utc.iso8601,
      arrival_at: row["arrival_at"].utc.iso8601,
      total_capacity: row["total_capacity"],
      available_seats: row["available_seats"]
    )
  end

  def validate_uuid(id)
    return if id.match?(UUID_PATTERN)

    raise grpc_error(
      GRPC::Core::StatusCodes::INVALID_ARGUMENT,
      "El identificador del vuelo no es válido"
    )
  end

  def grpc_error(status_code, message)
    GRPC::BadStatus.new_status_exception(status_code, message)
  end
end