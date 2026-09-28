require "grpc"
require_relative "aeroreserva_services_pb"
require_relative "grpc_resilience"

class PassengerClient
  def initialize(stub: nil, resilience: nil)
    @resilience = resilience || GrpcResilience.new(dependency: "pasajeros")
    @stub = stub || Aeroreserva::V1::PassengerService::Stub.new(
      ENV.fetch("PASSENGER_SERVICE_ADDR", "localhost:50052"),
      :this_channel_is_insecure
    )
  end

  def get_passenger(id)
    @resilience.call(operation: "GetPassenger", read: true) do |deadline|
      @stub.get_passenger(Aeroreserva::V1::GetByIdRequest.new(id: id), deadline: deadline)
    end
  rescue GRPC::NotFound
    nil
  end
end
