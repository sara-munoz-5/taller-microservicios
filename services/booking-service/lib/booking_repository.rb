require "securerandom"
require "cassandra"
require_relative "cassandra_client"

class BookingRepository
  def crear(passenger_id:, flight_id:)
    id = SecureRandom.uuid
    uuid = Cassandra::Uuid.new(id)
    passenger_uuid = Cassandra::Uuid.new(passenger_id)
    flight_uuid = Cassandra::Uuid.new(flight_id)
    booking_code = "RES-" + SecureRandom.hex(3).upcase
    created_at = Time.now.utc
    status = "CONFIRMED"

    CassandraClient.session.execute(
      "INSERT INTO bookings_by_id (id, booking_code, passenger_id, flight_id, created_at, status) VALUES (?, ?, ?, ?, ?, ?)",
      arguments: [uuid, booking_code, passenger_uuid, flight_uuid, created_at, status]
    )

    CassandraClient.session.execute(
      "INSERT INTO bookings_by_passenger (passenger_id, created_at, id, booking_code, flight_id, status) VALUES (?, ?, ?, ?, ?, ?)",
      arguments: [passenger_uuid, created_at, uuid, booking_code, flight_uuid, status]
    )

    CassandraClient.session.execute(
      "INSERT INTO bookings_by_status (status, created_at, id, booking_code, passenger_id, flight_id) VALUES (?, ?, ?, ?, ?, ?)",
      arguments: [status, created_at, uuid, booking_code, passenger_uuid, flight_uuid]
    )

    {
      "id" => id,
      "booking_code" => booking_code,
      "passenger_id" => passenger_id,
      "flight_id" => flight_id,
      "created_at" => created_at,
      "status" => status
    }
  end

  def find_by_id(id)
    CassandraClient.session.execute(
      "SELECT * FROM bookings_by_id WHERE id = ?",
      arguments: [Cassandra::Uuid.new(id)]
    ).first
  end

  def list_all
    CassandraClient.session.execute("SELECT * FROM bookings_by_id").to_a
  end

  def cancelar(booking)
    id = booking["id"]
    passenger_id = booking["passenger_id"]
    flight_id = booking["flight_id"]
    created_at = booking["created_at"]
    old_status = booking["status"]
    booking_code = booking["booking_code"]
    new_status = "CANCELLED"

    CassandraClient.session.execute(
      "UPDATE bookings_by_id SET status = ? WHERE id = ?",
      arguments: [new_status, id]
    )

    CassandraClient.session.execute(
      "UPDATE bookings_by_passenger SET status = ? WHERE passenger_id = ? AND created_at = ? AND id = ?",
      arguments: [new_status, passenger_id, created_at, id]
    )

    CassandraClient.session.execute(
      "DELETE FROM bookings_by_status WHERE status = ? AND created_at = ? AND id = ?",
      arguments: [old_status, created_at, id]
    )

    CassandraClient.session.execute(
      "INSERT INTO bookings_by_status (status, created_at, id, booking_code, passenger_id, flight_id) VALUES (?, ?, ?, ?, ?, ?)",
      arguments: [new_status, created_at, id, booking_code, passenger_id, flight_id]
    )

    find_by_id(id.to_s)
  end
end
