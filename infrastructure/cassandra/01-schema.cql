-- ==================== KEYSPACE DE VUELOS ====================

CREATE KEYSPACE IF NOT EXISTS aeroreserva_flights
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

CREATE TABLE IF NOT EXISTS aeroreserva_flights.flights_by_id (
    id uuid PRIMARY KEY,
    flight_number text,
    origin text,
    destination text,
    departure_at timestamp,
    arrival_at timestamp,
    total_capacity int,
    available_seats int
);

CREATE TABLE IF NOT EXISTS aeroreserva_flights.flights_catalog (
    catalog text,
    departure_at timestamp,
    id uuid,
    flight_number text,
    origin text,
    destination text,
    arrival_at timestamp,
    total_capacity int,
    available_seats int,
    PRIMARY KEY ((catalog), departure_at, id)
) WITH CLUSTERING ORDER BY (departure_at ASC, id ASC);

-- ==================== KEYSPACE DE PASAJEROS ====================

CREATE KEYSPACE IF NOT EXISTS aeroreserva_passengers
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

CREATE TABLE IF NOT EXISTS aeroreserva_passengers.passengers_by_id (
    id uuid PRIMARY KEY,
    document_type text,
    document_number text,
    full_name text,
    email text
);

CREATE TABLE IF NOT EXISTS aeroreserva_passengers.passengers_by_document (
    document_type text,
    document_number text,
    id uuid,
    full_name text,
    email text,
    PRIMARY KEY ((document_type), document_number)
);

-- ==================== KEYSPACE DE RESERVAS ====================

CREATE KEYSPACE IF NOT EXISTS aeroreserva_bookings
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

CREATE TABLE IF NOT EXISTS aeroreserva_bookings.bookings_by_id (
    id uuid PRIMARY KEY,
    booking_code text,
    passenger_id uuid,
    flight_id uuid,
    created_at timestamp,
    status text
);

CREATE TABLE IF NOT EXISTS aeroreserva_bookings.bookings_by_passenger (
    passenger_id uuid,
    created_at timestamp,
    id uuid,
    booking_code text,
    flight_id uuid,
    status text,
    PRIMARY KEY ((passenger_id), created_at, id)
) WITH CLUSTERING ORDER BY (created_at DESC, id ASC);

CREATE TABLE IF NOT EXISTS aeroreserva_bookings.bookings_by_status (
    status text,
    created_at timestamp,
    id uuid,
    booking_code text,
    passenger_id uuid,
    flight_id uuid,
    PRIMARY KEY ((status), created_at, id)
) WITH CLUSTERING ORDER BY (created_at DESC, id ASC);