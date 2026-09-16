INSERT INTO aeroreserva_flights.flights_by_id (
    id, flight_number, origin, destination, departure_at, arrival_at,
    total_capacity, available_seats
) VALUES (
    11111111-1111-1111-1111-111111111111,
    'AR101', 'Bogotá', 'Medellín',
    '2026-10-20T08:00:00Z', '2026-10-20T09:05:00Z',
    150, 150
);

INSERT INTO aeroreserva_flights.flights_catalog (
    catalog, departure_at, id, flight_number, origin, destination,
    arrival_at, total_capacity, available_seats
) VALUES (
    'ACTIVE', '2026-10-20T08:00:00Z',
    11111111-1111-1111-1111-111111111111,
    'AR101', 'Bogotá', 'Medellín',
    '2026-10-20T09:05:00Z', 150, 150
);

INSERT INTO aeroreserva_flights.flights_by_id (
    id, flight_number, origin, destination, departure_at, arrival_at,
    total_capacity, available_seats
) VALUES (
    22222222-2222-2222-2222-222222222222,
    'AR202', 'Bogotá', 'Cartagena',
    '2026-10-20T11:30:00Z', '2026-10-20T13:00:00Z',
    180, 180
);

INSERT INTO aeroreserva_flights.flights_catalog (
    catalog, departure_at, id, flight_number, origin, destination,
    arrival_at, total_capacity, available_seats
) VALUES (
    'ACTIVE', '2026-10-20T11:30:00Z',
    22222222-2222-2222-2222-222222222222,
    'AR202', 'Bogotá', 'Cartagena',
    '2026-10-20T13:00:00Z', 180, 180
);

INSERT INTO aeroreserva_flights.flights_by_id (
    id, flight_number, origin, destination, departure_at, arrival_at,
    total_capacity, available_seats
) VALUES (
    33333333-3333-3333-3333-333333333333,
    'AR303', 'Medellín', 'Bogotá',
    '2026-10-21T15:00:00Z', '2026-10-21T16:05:00Z',
    150, 150
);

INSERT INTO aeroreserva_flights.flights_catalog (
    catalog, departure_at, id, flight_number, origin, destination,
    arrival_at, total_capacity, available_seats
) VALUES (
    'ACTIVE', '2026-10-21T15:00:00Z',
    33333333-3333-3333-3333-333333333333,
    'AR303', 'Medellín', 'Bogotá',
    '2026-10-21T16:05:00Z', 150, 150
);