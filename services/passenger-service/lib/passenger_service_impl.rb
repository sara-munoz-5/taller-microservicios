require "grpc"
require "securerandom"
require_relative "aeroreserva_services_pb"
require_relative "cassandra_client"

class PassengerServiceImpl < Aeroreserva::V1::PassengerService::Service
  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  EMAIL_PATTERN = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  def create_passenger(request, _call)
    validate_passenger_input(request)

    id = SecureRandom.uuid
    uuid = Cassandra::Uuid.new(id)

    # Claim the document with a Paxos (LWT) insert: of two simultaneous
    # registrations only one wins, so a document never maps to two passengers.
    claimed = CassandraClient.session.execute(
      "INSERT INTO passengers_by_document (document_type, document_number, id, full_name, email) VALUES (?, ?, ?, ?, ?) IF NOT EXISTS",
      arguments: [request.document_type, request.document_number, uuid, request.full_name, request.email],
      serial_consistency: :local_serial
    ).first["[applied]"]
    document_taken(request.document_type, request.document_number) unless claimed

    CassandraClient.session.execute(
      "INSERT INTO passengers_by_id (id, document_type, document_number, full_name, email) VALUES (?, ?, ?, ?, ?)",
      arguments: [uuid, request.document_type, request.document_number, request.full_name, request.email]
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

  def find_passenger(request, _call)
    if [request.document_type, request.document_number, request.email].any? { |value| value.strip.empty? }
      raise grpc_error(GRPC::Core::StatusCodes::INVALID_ARGUMENT, "Completa documento y correo")
    end
    row = CassandraClient.session.execute(
      "SELECT * FROM passengers_by_document WHERE document_type = ? AND document_number = ?",
      arguments: [request.document_type, request.document_number]
    ).first
    unless row && row["email"].strip.casecmp?(request.email.strip)
      raise grpc_error(GRPC::Core::StatusCodes::NOT_FOUND, "No encontramos un perfil con esos datos")
    end
    passenger_message(row)
  end

  private

  def document_taken(document_type, document_number)
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
