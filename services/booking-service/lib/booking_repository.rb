require "securerandom"
require "sorted_set"
require "cassandra"
require_relative "cassandra_client"

class BookingRepository
  # Allocate identifiers before the saga so a partial write can be compensated.
  def prepare_booking(passenger_id:, flight_id:)
    {
      "id" => Cassandra::Uuid.new(SecureRandom.uuid),
      "booking_code" => "RES-" + SecureRandom.hex(3).upcase,
      "passenger_id" => Cassandra::Uuid.new(passenger_id),
      "flight_id" => Cassandra::Uuid.new(flight_id),
      "created_at" => Time.at((Time.now.to_r * 1000).floor / 1000r).utc,
      "status" => "CONFIRMED"
    }
  end

  def persist_booking(booking)
    write_booking(booking)
    booking
  end

  # Keep an audit row instead of deleting data. A logged batch removes the old
  # status projection and writes CANCELLED to all three tables.
  def compensate_creation(booking)
    write_booking(booking.merge("status" => "CANCELLED"), previous_status: "CONFIRMED")
  end

  def write_booking(booking, previous_status: nil)
    id, code, passenger, flight, created, status = booking.values_at(
      "id", "booking_code", "passenger_id", "flight_id", "created_at", "status"
    )
    batch = CassandraClient.session.batch
    batch.add("INSERT INTO bookings_by_id (id, booking_code, passenger_id, flight_id, created_at, status) VALUES (?, ?, ?, ?, ?, ?)",
              arguments: [id, code, passenger, flight, created, status])
    batch.add("INSERT INTO bookings_by_passenger (passenger_id, created_at, id, booking_code, flight_id, status) VALUES (?, ?, ?, ?, ?, ?)",
              arguments: [passenger, created, id, code, flight, status])
    batch.add("INSERT INTO bookings_by_status (status, created_at, id, booking_code, passenger_id, flight_id) VALUES (?, ?, ?, ?, ?, ?)",
              arguments: [status, created, id, code, passenger, flight])
    if previous_status
      batch.add("DELETE FROM bookings_by_status WHERE status = ? AND created_at = ? AND id = ?",
                arguments: [previous_status, created, id])
    end
    CassandraClient.session.execute(batch, consistency: :local_quorum)
  end

  def find_by_id(id)
    CassandraClient.session.execute(
      "SELECT * FROM bookings_by_id WHERE id = ?",
      arguments: [Cassandra::Uuid.new(id)]
    ).first
  end

  def list_by_passenger(id)
    result = CassandraClient.session.execute(
      "SELECT * FROM bookings_by_passenger WHERE passenger_id = ?",
      arguments: [Cassandra::Uuid.new(id)]
    )
    rows = result.to_a
    until result.last_page?
      result = result.next_page
      rows.concat(result.to_a)
    end
    rows
  end

  def list_all
    CassandraClient.session.execute("SELECT * FROM bookings_by_id").to_a
  end

  # CONFIRMED -> CANCELLED is a single Paxos (LWT) step on the source table:
  # of two concurrent cancellations only one is applied, so only that one
  # releases the seat. Returns true when this call won the transition.
  def mark_cancelled(booking)
    change_status(booking["id"], from: "CONFIRMED", to: "CANCELLED")
  end

  # Compensation when the seat could not be released.
  def revert_cancellation(booking)
    change_status(booking["id"], from: "CANCELLED", to: "CONFIRMED")
  end

  # Idempotent: rewrites the read projections after bookings_by_id changed.
  def project_cancellation(booking)
    id, code, passenger, flight, created = booking.values_at(
      "id", "booking_code", "passenger_id", "flight_id", "created_at"
    )
    batch = CassandraClient.session.batch
    batch.add("UPDATE bookings_by_passenger SET status = 'CANCELLED' WHERE passenger_id = ? AND created_at = ? AND id = ?",
              arguments: [passenger, created, id])
    batch.add("DELETE FROM bookings_by_status WHERE status = 'CONFIRMED' AND created_at = ? AND id = ?",
              arguments: [created, id])
    batch.add("INSERT INTO bookings_by_status (status, created_at, id, booking_code, passenger_id, flight_id) VALUES ('CANCELLED', ?, ?, ?, ?, ?)",
              arguments: [created, id, code, passenger, flight])
    CassandraClient.session.execute(batch, consistency: :local_quorum)
  end

  private

  def change_status(id, from:, to:)
    CassandraClient.session.execute(
      "UPDATE bookings_by_id SET status = ? WHERE id = ? IF status = ?",
      arguments: [to, id, from], consistency: :local_quorum, serial_consistency: :local_serial
    ).first["[applied]"]
  end
end
