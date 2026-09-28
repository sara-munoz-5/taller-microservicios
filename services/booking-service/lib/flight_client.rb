require "grpc"
require_relative "aeroreserva_services_pb"
require_relative "grpc_resilience"

class FlightClient
  def initialize(stub: nil, resilience: nil)
    @resilience = resilience || GrpcResilience.new(dependency: "vuelos")
    @stub = stub || Aeroreserva::V1::FlightService::Stub.new(
      ENV.fetch("FLIGHT_SERVICE_ADDR", "localhost:50051"),
      :this_channel_is_insecure
    )
  end

  def get_flight(id)
    @resilience.call(operation: "GetFlight", read: true) do |deadline|
      @stub.get_flight(Aeroreserva::V1::GetByIdRequest.new(id: id), deadline: deadline)
    end
  rescue GRPC::NotFound
    nil
  end

  def occupy_seat(id)
    @resilience.call(operation: "OccupySeat") do |deadline|
      @stub.occupy_seat(Aeroreserva::V1::GetByIdRequest.new(id: id), deadline: deadline)
    end
  end

  def release_seat(id)
    @resilience.call(operation: "ReleaseSeat") do |deadline|
      @stub.release_seat(Aeroreserva::V1::GetByIdRequest.new(id: id), deadline: deadline)
    end
  end

end
