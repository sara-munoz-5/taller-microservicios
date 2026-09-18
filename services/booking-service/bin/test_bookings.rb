$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "grpc"
require "securerandom"
require "aeroreserva_pb"
require "aeroreserva_services_pb"

passenger_stub = Aeroreserva::V1::PassengerService::Stub.new(
  "localhost:50052",
  :this_channel_is_insecure
)

flight_stub = Aeroreserva::V1::FlightService::Stub.new(
  "localhost:50051",
  :this_channel_is_insecure
)

booking_stub = Aeroreserva::V1::BookingService::Stub.new(
  "localhost:50053",
  :this_channel_is_insecure
)

def expect_grpc_error(code, description)
  yield
  puts "FALLO: #{description} (no se levantó ningún error)"
rescue GRPC::BadStatus => e
  if e.code == code
    puts "OK: #{description} (#{e.code})"
  else
    puts "FALLO: #{description} (se esperaba #{code}, se obtuvo #{e.code})"
  end
end

# (a) crear un pasajero de prueba directamente en passenger-service
passenger = passenger_stub.create_passenger(
  Aeroreserva::V1::CreatePassengerRequest.new(
    document_type: "CC",
    document_number: SecureRandom.hex(6),
    full_name: "Pasajero de Prueba",
    email: "prueba.#{SecureRandom.hex(4)}@example.com"
  )
)
puts "OK: pasajero de prueba creado (id=#{passenger.id})"

# (b) consultar vuelos existentes y tomar el primero con cupos
flights = flight_stub.list_flights(Aeroreserva::V1::Empty.new).flights
flight = flights.find { |f| f.available_seats > 0 }

unless flight
  puts "FALLO: no hay vuelos con cupos disponibles para probar"
  exit 1
end

original_available_seats = flight.available_seats
puts "OK: vuelo elegido (id=#{flight.id}, cupos=#{original_available_seats})"

# (c) crear una reserva válida -> CONFIRMED
booking = booking_stub.create_booking(
  Aeroreserva::V1::CreateBookingRequest.new(
    passenger_id: passenger.id,
    flight_id: flight.id
  )
)

if booking.status == :BOOKING_STATUS_CONFIRMED
  puts "OK: reserva creada con estado CONFIRMED (id=#{booking.id}, codigo=#{booking.booking_code})"
else
  puts "FALLO: la reserva no quedó CONFIRMED (status=#{booking.status})"
end

# (d) crear una reserva con un passenger_id inventado -> NOT_FOUND
expect_grpc_error(GRPC::Core::StatusCodes::NOT_FOUND, "crear reserva con pasajero inexistente") do
  booking_stub.create_booking(
    Aeroreserva::V1::CreateBookingRequest.new(
      passenger_id: SecureRandom.uuid,
      flight_id: flight.id
    )
  )
end

# (e) crear una reserva con un flight_id inventado -> NOT_FOUND
expect_grpc_error(GRPC::Core::StatusCodes::NOT_FOUND, "crear reserva con vuelo inexistente") do
  booking_stub.create_booking(
    Aeroreserva::V1::CreateBookingRequest.new(
      passenger_id: passenger.id,
      flight_id: SecureRandom.uuid
    )
  )
end

# (f) consultar la reserva creada en (c) por id y confirmar que los datos coinciden
found_booking = booking_stub.get_booking(Aeroreserva::V1::GetByIdRequest.new(id: booking.id))

if found_booking.id == booking.id &&
   found_booking.booking_code == booking.booking_code &&
   found_booking.passenger_id == booking.passenger_id &&
   found_booking.flight_id == booking.flight_id &&
   found_booking.status == booking.status
  puts "OK: get_booking devuelve los mismos datos"
else
  puts "FALLO: get_booking devuelve datos distintos a los creados"
end

# (g) cancelar la reserva -> CANCELLED
cancelled_booking = booking_stub.cancel_booking(Aeroreserva::V1::GetByIdRequest.new(id: booking.id))

if cancelled_booking.status == :BOOKING_STATUS_CANCELLED
  puts "OK: reserva cancelada con estado CANCELLED"
else
  puts "FALLO: la reserva no quedó CANCELLED (status=#{cancelled_booking.status})"
end

# (h) cancelarla otra vez -> FAILED_PRECONDITION
expect_grpc_error(GRPC::Core::StatusCodes::FAILED_PRECONDITION, "cancelar una reserva ya cancelada") do
  booking_stub.cancel_booking(Aeroreserva::V1::GetByIdRequest.new(id: booking.id))
end

# (i) consultar el vuelo usado en (b) y confirmar que available_seats volvió al valor original
flight_after = flight_stub.get_flight(Aeroreserva::V1::GetByIdRequest.new(id: flight.id))

if flight_after.available_seats == original_available_seats
  puts "OK: available_seats volvió al valor original (#{original_available_seats})"
else
  puts "FALLO: available_seats no volvió al valor original (esperado=#{original_available_seats}, obtenido=#{flight_after.available_seats})"
end
