require "grpc"
require "time"
require_relative "aeroreserva_services_pb"
require_relative "booking_repository"
require_relative "flight_client"
require_relative "passenger_client"

class BookingServiceImpl < Aeroreserva::V1::BookingService::Service
  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  def initialize
    @repository = BookingRepository.new
    @flight_client = FlightClient.new
    @passenger_client = PassengerClient.new
  end

  def create_booking(request, _call)
    validate_uuid(request.passenger_id, "El identificador del pasajero no es válido")
    validate_uuid(request.flight_id, "El identificador del vuelo no es válido")

    passenger = @passenger_client.get_passenger(request.passenger_id)
    unless passenger
      raise grpc_error(GRPC::Core::StatusCodes::NOT_FOUND, "pasajero no encontrado")
    end

    flight = @flight_client.get_flight(request.flight_id)
    unless flight
      raise grpc_error(GRPC::Core::StatusCodes::NOT_FOUND, "vuelo no encontrado")
    end

    if flight.available_seats <= 0
      raise grpc_error(
        GRPC::Core::StatusCodes::FAILED_PRECONDITION,
        "el vuelo no tiene cupos disponibles"
      )
    end

    @flight_client.occupy_seat(request.flight_id)

    booking = @repository.crear(passenger_id: request.passenger_id, flight_id: request.flight_id)
    booking_message(booking)
  end

  def get_booking(request, _call)
    validate_uuid(request.id, "El identificador de la reserva no es válido")

    booking = @repository.find_by_id(request.id)
    unless booking
      raise grpc_error(GRPC::Core::StatusCodes::NOT_FOUND, "reserva no encontrada")
    end

    booking_message(booking)
  end

  def list_bookings(_request, _call)
    Aeroreserva::V1::BookingList.new(
      bookings: @repository.list_all.map { |row| booking_message(row) }
    )
  end

  def cancel_booking(request, _call)
    validate_uuid(request.id, "El identificador de la reserva no es válido")

    booking = @repository.find_by_id(request.id)
    unless booking
      raise grpc_error(GRPC::Core::StatusCodes::NOT_FOUND, "reserva no encontrada")
    end

    if booking["status"] == "CANCELLED"
      raise grpc_error(
        GRPC::Core::StatusCodes::FAILED_PRECONDITION,
        "la reserva ya fue cancelada"
      )
    end

    @flight_client.release_seat(booking["flight_id"].to_s)

    updated_booking = @repository.cancelar(booking)
    booking_message(updated_booking)
  end

  private

  def booking_message(row)
    Aeroreserva::V1::Booking.new(
      id: row["id"].to_s,
      booking_code: row["booking_code"],
      passenger_id: row["passenger_id"].to_s,
      flight_id: row["flight_id"].to_s,
      created_at: row["created_at"].utc.iso8601,
      status: status_enum(row["status"])
    )
  end

  def status_enum(status)
    case status
    when "CONFIRMED"
      :BOOKING_STATUS_CONFIRMED
    when "CANCELLED"
      :BOOKING_STATUS_CANCELLED
    else
      :BOOKING_STATUS_UNSPECIFIED
    end
  end

  def validate_uuid(id, message)
    return if id.to_s.match?(UUID_PATTERN)

    raise grpc_error(GRPC::Core::StatusCodes::INVALID_ARGUMENT, message)
  end

  def grpc_error(status_code, message)
    GRPC::BadStatus.new_status_exception(status_code, message)
  end
end
