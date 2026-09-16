$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "grpc"
require "aeroreserva_pb"
require "aeroreserva_services_pb"

stub = Aeroreserva::V1::FlightService::Stub.new(
  "localhost:50051",
  :this_channel_is_insecure
)

response = stub.list_flights(Aeroreserva::V1::Empty.new)

response.flights.each do |flight|
  puts "#{flight.flight_number}: #{flight.origin} -> #{flight.destination} | cupos: #{flight.available_seats}"
end