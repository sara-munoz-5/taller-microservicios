import type { APIRoute } from 'astro';
import { rpc, json, failure } from '../../lib/server';
export const GET: APIRoute = async () => {
  try {
    const { flights } = await rpc('Flight', 'ListFlights');
    return json(flights.map(({ id, ...flight }: any) => flight));
  } catch (error) { return failure(error); }
};
