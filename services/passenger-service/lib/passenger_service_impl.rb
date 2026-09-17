require "grpc"
require "securerandom"
require_relative "aeroreserva_services_pb"
require_relative "cassandra_client"

class PassengerServiceImpl < Aeroreserva::V1::PassengerService::Service
  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  EMAIL_PATTERN = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  def create_passenger(request, _call)
    validate_passenger_input(request)
    ensure_document_not_taken(request.document_type, request.document_number)

    id = SecureRandom.uuid
    uuid = Cassandra::Uuid.new(id)

    CassandraClient.session.execute(
      "INSERT INTO passengers_by_id (id, document_type, document_number, full_name, email) VALUES (?, ?, ?, ?, ?)",
      arguments: [uuid, request.document_type, request.document_number, request.full_name, request.email]
    )

    CassandraClient.session.execute(
      "INSERT INTO passengers_by_document (document_type, document_number, id, full_name, email) VALUES (?, ?, ?, ?, ?)",
      arguments: [request.document_type, request.document_number, uuid, request.full_name, request.email]
    )

    Aeroreserva::V1::Passenger.new(
      id: id,
      document_type: request.document_type,
      document_number: request.document_number,
      full_name: request.full_name,
      email: request.email
    )
  end

  def get_passenger(request, _call)
    validate_uuid(request.id)

    row = CassandraClient.session.execute(
      "SELECT * FROM passengers_by_id WHERE id = ?",
      arguments: [Cassandra::Uuid.new(request.id)]
    ).first

    unless row
      raise grpc_error(
        GRPC::Core::StatusCodes::NOT_FOUND,
        "Pasajero no encontrado"
      )
    end

    passenger_message(row)
  end

  private

  def ensure_document_not_taken(document_type, document_number)
    existing = CassandraClient.session.execute(
      "SELECT id FROM passengers_by_document WHERE document_type = ? AND document_number = ?",
      arguments: [document_type, document_number]
    ).first

    return unless existing

    raise grpc_error(
      GRPC::Core::StatusCodes::ALREADY_EXISTS,
      "Ya existe un pasajero con el documento #{document_type} #{document_number}"
    )
  end

  def validate_passenger_input(request)
    if request.document_type.to_s.strip.empty? ||
       request.document_number.to_s.strip.empty? ||
       request.full_name.to_s.strip.empty? ||
       request.email.to_s.strip.empty?
      raise grpc_error(
        GRPC::Core::StatusCodes::INVALID_ARGUMENT,
        "document_type, document_number, full_name y email son obligatorios"
      )
    end

    return if request.email.match?(EMAIL_PATTERN)

    raise grpc_error(
      GRPC::Core::StatusCodes::INVALID_ARGUMENT,
      "El email no tiene un formato válido"
    )
  end

  def passenger_message(row)
    Aeroreserva::V1::Passenger.new(
      id: row["id"].to_s,
      document_type: row["document_type"],
      document_number: row["document_number"],
      full_name: row["full_name"],
      email: row["email"]
    )
  end

  def validate_uuid(id)
    return if id.match?(UUID_PATTERN)

    raise grpc_error(
      GRPC::Core::StatusCodes::INVALID_ARGUMENT,
      "El identificador del pasajero no es válido"
    )
  end

  def grpc_error(status_code, message)
    GRPC::BadStatus.new_status_exception(status_code, message)
  end
end
