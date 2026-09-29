export async function api(url: string, method = 'GET', body?: unknown) {
  const response = await fetch(url, { method, headers: body ? { 'Content-Type': 'application/json' } : undefined, body: body ? JSON.stringify(body) : undefined });
  const data = await response.json();
  if (response.status === 401) {
    location.href = `/ingresar?next=${encodeURIComponent(location.pathname + location.search)}`;
    throw new Error('Ingresa para continuar.');
  }
  if (!response.ok) throw new Error(data.message || 'No pudimos completar la solicitud.');
  return data;
}
export const formatDate = (value: string) => new Intl.DateTimeFormat('es-CO', { dateStyle: 'medium', timeStyle: 'short', timeZone: 'America/Bogota' }).format(new Date(value));
export const statusLabel = (value: string) => value === 'BOOKING_STATUS_CONFIRMED' ? 'Confirmada' : value === 'BOOKING_STATUS_CANCELLED' ? 'Cancelada' : 'Pendiente';
export const escapeHtml = (value: unknown) => String(value ?? '').replace(/[&<>"']/g, c => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' })[c]!);
