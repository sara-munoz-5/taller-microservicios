import type { APIRoute } from 'astro';
import { rpc, session, sameOrigin, json, failure } from '../../lib/server';
export const prerender = false;
const summary = (booking: any) => ({ booking_code: booking.booking_code, status: booking.status, created_at: booking.created_at });
export const GET: APIRoute = async ({ cookies }) => {
  const passenger = session(cookies);
  if (!passenger) return json({ message: 'Ingresa para consultar tus reservas.' }, 401);
  try {
    const { bookings } = await rpc('Booking', 'ListBookingsByPassenger', { id: passenger.id });
    if (!bookings.length) return json([]);
    const { flights } = await rpc('Flight', 'ListFlights');
    const byId = new Map(flights.map((flight: any) => [flight.id, flight]));
    // Deduplicate missing flights outside the active catalog.
    await Promise.all([...new Set<string>(bookings.map((b: any) => b.flight_id))].filter(id => !byId.has(id)).map(async id => {
      try { byId.set(id, await rpc('Flight', 'GetFlight', { id })); }
      catch (error: any) { if (error.code !== 5) throw error; }
    }));
    return json(bookings.map((booking: any) => {
      const flight: any = byId.get(booking.flight_id);
      return { ...summary(booking), flight: flight ? { flight_number: flight.flight_number, origin: flight.origin, destination: flight.destination, departure_at: flight.departure_at, arrival_at: flight.arrival_at } : null };
    }));
  } catch (error) { return failure(error); }
};
export const POST: APIRoute = async ({ cookies, request, url }) => {
  if (!sameOrigin(request, url)) return json({ message: 'Solicitud no permitida.' }, 403);
  const passenger = session(cookies);
  if (!passenger) return json({ message: 'Tu sesión terminó. Ingresa de nuevo.' }, 401);
  try {
    const body = await request.json();
    const { flights } = await rpc('Flight', 'ListFlights');
    const flight = flights.find((item: any) => item.flight_number === body.flight_number);
    if (!flight) return json({ message: 'El vuelo seleccionado ya no está disponible.' }, 404);
    return json(summary(await rpc('Booking', 'CreateBooking', { passenger_id: passenger.id, flight_id: flight.id })), 201);
  } catch (error) { return failure(error); }
};
export const DELETE: APIRoute = async ({ cookies, request, url }) => {
  if (!sameOrigin(request, url)) return json({ message: 'Solicitud no permitida.' }, 403);
  const passenger = session(cookies);
  if (!passenger) return json({ message: 'Tu sesión terminó. Ingresa de nuevo.' }, 401);
  try {
    const body = await request.json();
    const { bookings } = await rpc('Booking', 'ListBookingsByPassenger', { id: passenger.id });
    const matches = bookings.filter((b: any) => b.booking_code === body.booking_code);
    if (matches.length !== 1) return json({ message: 'No encontramos esa reserva en tu perfil.' }, 404);
    return json(summary(await rpc('Booking', 'CancelBooking', { id: matches[0].id })));
  } catch (error) { return failure(error); }
};
