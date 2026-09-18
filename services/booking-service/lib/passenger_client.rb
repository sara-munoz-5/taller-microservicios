require "grpc"
require_relative "aeroreserva_services_pb"

class PassengerClient
  def initialize
    @stub = Aeroreserva::V1::PassengerService::Stub.new(
      ENV.fetch("PASSENGER_SERVICE_ADDR", "localhost:50052"),
      :this_channel_is_insecure
    )
  end

  def get_passenger(id)
    call_with_deadline(id) { |request| @stub.get_passenger(request, deadline: Time.now + 3) }
  end

  private

  def call_with_deadline(id)
    yield Aeroreserva::V1::GetByIdRequest.new(id: id)
  rescue GRPC::NotFound
    nil
  rescue GRPC::DeadlineExceeded, GRPC::Unavailable
    raise GRPC::BadStatus.new_status_exception(
      GRPC::Core::StatusCodes::UNAVAILABLE,
      "El servicio de pasajeros no respondió a tiempo"
    )
  end
end
