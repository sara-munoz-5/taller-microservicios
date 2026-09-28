INSERT INTO aeroreserva_flights.flights_by_id (
    id, flight_number, origin, destination, departure_at, arrival_at,
    total_capacity, available_seats
) VALUES (
    11111111-1111-1111-1111-111111111111,
    'AR101', 'Bogotá', 'Medellín',
    '2026-10-20T08:00:00Z', '2026-10-20T09:05:00Z',
    150, 150
) IF NOT EXISTS;

INSERT INTO aeroreserva_flights.flights_catalog (
    catalog, departure_at, id, flight_number, origin, destination,
    arrival_at, total_capacity, available_seats
) VALUES (
    'ACTIVE', '2026-10-20T08:00:00Z',
    11111111-1111-1111-1111-111111111111,
    'AR101', 'Bogotá', 'Medellín',
    '2026-10-20T09:05:00Z', 150, 150
) IF NOT EXISTS;

INSERT INTO aeroreserva_flights.flights_by_id (
    id, flight_number, origin, destination, departure_at, arrival_at,
    total_capacity, available_seats
) VALUES (
    22222222-2222-2222-2222-222222222222,
    'AR202', 'Bogotá', 'Cartagena',
    '2026-10-20T11:30:00Z', '2026-10-20T13:00:00Z',
    180, 180
) IF NOT EXISTS;

INSERT INTO aeroreserva_flights.flights_catalog (
    catalog, departure_at, id, flight_number, origin, destination,
    arrival_at, total_capacity, available_seats
) VALUES (
    'ACTIVE', '2026-10-20T11:30:00Z',
    22222222-2222-2222-2222-222222222222,
    'AR202', 'Bogotá', 'Cartagena',
    '2026-10-20T13:00:00Z', 180, 180
) IF NOT EXISTS;

INSERT INTO aeroreserva_flights.flights_by_id (
    id, flight_number, origin, destination, departure_at, arrival_at,
    total_capacity, available_seats
) VALUES (
    33333333-3333-3333-3333-333333333333,
    'AR303', 'Medellín', 'Bogotá',
    '2026-10-21T15:00:00Z', '2026-10-21T16:05:00Z',
    150, 150
) IF NOT EXISTS;

INSERT INTO aeroreserva_flights.flights_catalog (
    catalog, departure_at, id, flight_number, origin, destination,
    arrival_at, total_capacity, available_seats
) VALUES (
    'ACTIVE', '2026-10-21T15:00:00Z',
    33333333-3333-3333-3333-333333333333,
    'AR303', 'Medellín', 'Bogotá',
    '2026-10-21T16:05:00Z', 150, 150
) IF NOT EXISTS;
INSERT INTO aeroreserva_flights.flights_by_id (id, flight_number, origin, destination, departure_at, arrival_at, total_capacity, available_seats) VALUES (44444444-4444-4444-4444-444444444444, 'AR404', 'Cali', 'Bogotá', '2026-10-22T13:00:00Z', '2026-10-22T14:05:00Z', 150, 150) IF NOT EXISTS;
INSERT INTO aeroreserva_flights.flights_catalog (catalog, departure_at, id, flight_number, origin, destination, arrival_at, total_capacity, available_seats) VALUES ('ACTIVE', '2026-10-22T13:00:00Z', 44444444-4444-4444-4444-444444444444, 'AR404', 'Cali', 'Bogotá', '2026-10-22T14:05:00Z', 150, 150) IF NOT EXISTS;

INSERT INTO aeroreserva_flights.flights_by_id (id, flight_number, origin, destination, departure_at, arrival_at, total_capacity, available_seats) VALUES (55555555-5555-5555-5555-555555555555, 'AR505', 'Bogotá', 'Santa Marta', '2026-10-23T15:00:00Z', '2026-10-23T16:35:00Z', 180, 180) IF NOT EXISTS;
INSERT INTO aeroreserva_flights.flights_catalog (catalog, departure_at, id, flight_number, origin, destination, arrival_at, total_capacity, available_seats) VALUES ('ACTIVE', '2026-10-23T15:00:00Z', 55555555-5555-5555-5555-555555555555, 'AR505', 'Bogotá', 'Santa Marta', '2026-10-23T16:35:00Z', 180, 180) IF NOT EXISTS;

INSERT INTO aeroreserva_flights.flights_by_id (id, flight_number, origin, destination, departure_at, arrival_at, total_capacity, available_seats) VALUES (66666666-6666-6666-6666-666666666666, 'AR606', 'Medellín', 'Cartagena', '2026-10-24T17:00:00Z', '2026-10-24T18:15:00Z', 150, 150) IF NOT EXISTS;
INSERT INTO aeroreserva_flights.flights_catalog (catalog, departure_at, id, flight_number, origin, destination, arrival_at, total_capacity, available_seats) VALUES ('ACTIVE', '2026-10-24T17:00:00Z', 66666666-6666-6666-6666-666666666666, 'AR606', 'Medellín', 'Cartagena', '2026-10-24T18:15:00Z', 150, 150) IF NOT EXISTS;

INSERT INTO aeroreserva_flights.flights_by_id (id, flight_number, origin, destination, departure_at, arrival_at, total_capacity, available_seats) VALUES (77777777-7777-7777-7777-777777777777, 'AR707', 'Barranquilla', 'Bogotá', '2026-10-25T12:00:00Z', '2026-10-25T13:35:00Z', 180, 180) IF NOT EXISTS;
INSERT INTO aeroreserva_flights.flights_catalog (catalog, departure_at, id, flight_number, origin, destination, arrival_at, total_capacity, available_seats) VALUES ('ACTIVE', '2026-10-25T12:00:00Z', 77777777-7777-7777-7777-777777777777, 'AR707', 'Barranquilla', 'Bogotá', '2026-10-25T13:35:00Z', 180, 180) IF NOT EXISTS;

INSERT INTO aeroreserva_flights.flights_by_id (id, flight_number, origin, destination, departure_at, arrival_at, total_capacity, available_seats) VALUES (88888888-8888-8888-8888-888888888888, 'AR808', 'Bogotá', 'Pereira', '2026-10-26T19:00:00Z', '2026-10-26T20:00:00Z', 120, 120) IF NOT EXISTS;
INSERT INTO aeroreserva_flights.flights_catalog (catalog, departure_at, id, flight_number, origin, destination, arrival_at, total_capacity, available_seats) VALUES ('ACTIVE', '2026-10-26T19:00:00Z', 88888888-8888-8888-8888-888888888888, 'AR808', 'Bogotá', 'Pereira', '2026-10-26T20:00:00Z', 120, 120) IF NOT EXISTS;

INSERT INTO aeroreserva_flights.flights_by_id (id, flight_number, origin, destination, departure_at, arrival_at, total_capacity, available_seats) VALUES (99999999-9999-9999-9999-999999999999, 'AR909', 'Cali', 'Medellín', '2026-10-27T14:00:00Z', '2026-10-27T14:55:00Z', 150, 150) IF NOT EXISTS;
INSERT INTO aeroreserva_flights.flights_catalog (catalog, departure_at, id, flight_number, origin, destination, arrival_at, total_capacity, available_seats) VALUES ('ACTIVE', '2026-10-27T14:00:00Z', 99999999-9999-9999-9999-999999999999, 'AR909', 'Cali', 'Medellín', '2026-10-27T14:55:00Z', 150, 150) IF NOT EXISTS;
