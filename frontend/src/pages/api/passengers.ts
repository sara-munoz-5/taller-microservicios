import type { APIRoute } from 'astro';
import { rpc, setSession, clearSession, session, sameOrigin, json, failure } from '../../lib/server';
export const prerender = false;
export const GET: APIRoute = ({ cookies }) => {
  const passenger = session(cookies);
  return passenger ? json({ full_name: passenger.name }) : json({ message: 'Ingresa para continuar.' }, 401);
};
export const POST: APIRoute = async ({ request, cookies, url }) => {
  if (!sameOrigin(request, url)) return json({ message: 'Solicitud no permitida.' }, 403);
  try {
    const body = await request.json();
    const input = Object.fromEntries(['document_type', 'document_number', 'email', 'full_name'].map(key => [key, typeof body[key] === 'string' ? body[key].trim() : '']));
    input.email = input.email.toLowerCase();
    if (!['CC', 'CE', 'Pasaporte'].includes(input.document_type) || !input.document_number || input.document_number.length > 50 || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(input.email) || input.email.length > 254 || (body.mode === 'register' && (!input.full_name || input.full_name.length > 150))) return json({ message: 'Completa correctamente los datos del perfil.' }, 400);
    if (!['register', 'login'].includes(body.mode)) return json({ message: 'Elige ingresar o crear perfil.' }, 400);
    const passenger = await rpc('Passenger', body.mode === 'register' ? 'CreatePassenger' : 'FindPassenger', input);
    setSession(cookies, passenger, url.protocol === 'https:');
    return json({ full_name: passenger.full_name }, body.mode === 'register' ? 201 : 200);
  } catch (error) { return failure(error); }
};
export const DELETE: APIRoute = ({ request, cookies, url }) => {
  if (!sameOrigin(request, url)) return json({ message: 'Solicitud no permitida.' }, 403);
  clearSession(cookies);
  return json({ message: 'Sesión cerrada.' });
};
