export interface Booking {
  id: string;
  booking_code: string;
  passenger_id: string;
  flight_id: string;
  created_at: string;
  status: string;
}

export interface Flight {
  id: string;
  flight_number: string;
  origin: string;
  destination: string;
  available_seats: number;
}

interface ApiErrorPayload {
  message?: string;
}

export const CONFIRMED_STATUS = "BOOKING_STATUS_CONFIRMED";

export function isConfirmedStatus(status: string): boolean {
  return status === CONFIRMED_STATUS;
}

async function parseJsonOrThrow<T>(response: Response, fallbackMessage: string): Promise<T> {
  const data = await response.json();

  if (!response.ok) {
    const errorPayload = data as ApiErrorPayload;
    throw new Error(errorPayload.message || fallbackMessage);
  }

  return data as T;
}

export async function fetchAvailableFlights(): Promise<Flight[]> {
  const response = await fetch("/api/flights");
  const flights = await parseJsonOrThrow<Flight[]>(response, "No fue posible obtener los vuelos.");

  return flights.filter((flight) => flight.available_seats > 0);
}

export async function createBooking(passengerId: string, flightId: string): Promise<Booking> {
  const response = await fetch("/api/bookings", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ passenger_id: passengerId, flight_id: flightId }),
  });

  return parseJsonOrThrow<Booking>(response, "No fue posible crear la reserva.");
}

export async function fetchBookingById(bookingId: string): Promise<Booking> {
  const response = await fetch(`/api/bookings?id=${encodeURIComponent(bookingId)}`);

  return parseJsonOrThrow<Booking>(response, "No fue posible consultar la reserva.");
}

export async function cancelBookingById(bookingId: string): Promise<Booking> {
  const response = await fetch(`/api/bookings?id=${encodeURIComponent(bookingId)}`, {
    method: "DELETE",
  });

  return parseJsonOrThrow<Booking>(response, "No fue posible cancelar la reserva.");
}

export function toErrorMessage(error: unknown, fallbackMessage: string): string {
  return error instanceof Error ? error.message : fallbackMessage;
}
