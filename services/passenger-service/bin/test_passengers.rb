$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "grpc"
require "securerandom"
require "aeroreserva_pb"
require "aeroreserva_services_pb"

stub = Aeroreserva::V1::PassengerService::Stub.new(
  "localhost:50052",
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

document_type = "CC"
document_number = SecureRandom.hex(6)

# (a) crear un pasajero válido
create_request = Aeroreserva::V1::CreatePassengerRequest.new(
  document_type: document_type,
  document_number: document_number,
  full_name: "Ana Torres",
  email: "ana.torres@example.com"
)

passenger = stub.create_passenger(create_request)
puts "OK: pasajero creado (id=#{passenger.id})"

# (b) crear el mismo pasajero otra vez -> ALREADY_EXISTS
expect_grpc_error(GRPC::Core::StatusCodes::ALREADY_EXISTS, "crear pasajero duplicado") do
  stub.create_passenger(create_request)
end

# (c) crear un pasajero con email inválido -> INVALID_ARGUMENT
invalid_email_request = Aeroreserva::V1::CreatePassengerRequest.new(
  document_type: "CC",
  document_number: SecureRandom.hex(6),
  full_name: "Luis Pérez",
  email: "correo-invalido"
)

expect_grpc_error(GRPC::Core::StatusCodes::INVALID_ARGUMENT, "crear pasajero con email inválido") do
  stub.create_passenger(invalid_email_request)
end

# (d) consultar el pasajero de (a) por id y confirmar que los datos coinciden
found = stub.get_passenger(Aeroreserva::V1::GetByIdRequest.new(id: passenger.id))

if found.id == passenger.id &&
   found.document_type == passenger.document_type &&
   found.document_number == passenger.document_number &&
   found.full_name == passenger.full_name &&
   found.email == passenger.email
  puts "OK: get_passenger devuelve los mismos datos"
else
  puts "FALLO: get_passenger devuelve datos distintos a los creados"
end

# (e) consultar un id inventado -> NOT_FOUND
fake_id = SecureRandom.uuid

expect_grpc_error(GRPC::Core::StatusCodes::NOT_FOUND, "consultar pasajero inexistente") do
  stub.get_passenger(Aeroreserva::V1::GetByIdRequest.new(id: fake_id))
end
