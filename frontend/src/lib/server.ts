import * as grpc from '@grpc/grpc-js';
import * as loader from '@grpc/proto-loader';
import path from 'node:path';
import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';
import type { AstroCookies } from 'astro';
const definition = loader.loadSync(path.resolve(process.cwd(), '../proto/aeroreserva.proto'), { keepCase: true, enums: String, defaults: true });
const proto = (grpc.loadPackageDefinition(definition) as any).aeroreserva.v1;
const clients = Object.fromEntries(['Flight', 'Passenger', 'Booking'].map((name, index) => [name, new proto[`${name}Service`](process.env[`${name.toUpperCase()}_SERVICE_URL`] || `localhost:${50051 + index}`, grpc.credentials.createInsecure())]));
export function rpc(service: string, method: string, body = {}): Promise<any> {
  return new Promise((resolve, reject) => clients[service][method](body, { deadline: Date.now() + 8000 }, (error: unknown, response: unknown) => error ? reject(error) : resolve(response)));
}
// Demo identification only. Random process key expires sessions on BFF restart.
const secret = process.env.SESSION_SECRET || randomBytes(32).toString('hex');
const cookieName = 'aeroreserva_session';
const sign = (value: string) => createHmac('sha256', secret).update(value).digest('base64url');
export function setSession(cookies: AstroCookies, passenger: any, secure: boolean) {
  const value = Buffer.from(JSON.stringify({ id: passenger.id, name: passenger.full_name, expires: Date.now() + 8 * 3600000 })).toString('base64url');
  cookies.set(cookieName, `${value}.${sign(value)}`, { path: '/', httpOnly: true, sameSite: 'lax', secure, maxAge: 8 * 3600 });
}
export function session(cookies: AstroCookies): { id: string; name: string } | null {
  try {
    const [value, signature] = (cookies.get(cookieName)?.value || '').split('.');
    const actual = Buffer.from(signature || '');
    const expected = Buffer.from(sign(value));
    if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) return null;
    const data = JSON.parse(Buffer.from(value, 'base64url').toString());
    return data.expires > Date.now() && typeof data.id === 'string' ? data : null;
  } catch { return null; }
}
export function clearSession(cookies: AstroCookies) { cookies.delete(cookieName, { path: '/' }); }
export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });
}
export function sameOrigin(request: Request, url: URL) { return request.headers.get('origin') === url.origin; }
export function failure(error: any) {
  const messages: Record<number, [number, string]> = {
    3: [400, 'Revisa los datos ingresados.'], 5: [404, 'No encontramos datos que coincidan.'],
    6: [409, 'Ese documento ya está registrado. Ingresa con su correo.'],
    9: [409, 'La operación ya no está disponible. Actualiza la página.'],
    10: [409, 'El vuelo está recibiendo muchas solicitudes. Intenta de nuevo en unos segundos.'],
    2: [503, 'El servicio no pudo completar la operación. Intenta de nuevo.'],
    13: [500, 'No fue posible completar la operación. Revisa Mis reservas antes de intentar de nuevo.'],
    4: [503, 'El servicio tardó demasiado. Intenta de nuevo.'], 14: [503, 'El servicio no está disponible. Intenta de nuevo.'],
  };
  const [status, message] = error instanceof SyntaxError ? [400, 'La solicitud no es válida.'] : messages[error?.code] || [500, 'No pudimos completar la operación. Intenta de nuevo.'];
  return json({ message }, status as number);
}
