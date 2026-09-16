$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "grpc"
require "aeroreserva_pb"
require "aeroreserva_services_pb"

stub = Aeroreserva::V1::FlightService::Stub.new(
  "localhost:50051",
  :this_channel_is_insecure
)

flight_id = "11111111-1111-1111-1111-111111111111"
request = Aeroreserva::V1::GetByIdRequest.new(id: flight_id)

before = stub.check_availability(request)
puts "Antes: #{before.available_seats} cupos"

stub.occupy_seat(request)

after_occupy = stub.check_availability(request)
puts "Después de ocupar: #{after_occupy.available_seats} cupos"

stub.release_seat(request)

after_release = stub.check_availability(request)
puts "Después de liberar: #{after_release.available_seats} cupos"