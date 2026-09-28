# AeroReserva

Demo de reservas con BFF Astro, servicios Ruby/gRPC y Cassandra. Arranque:

```sh
docker compose up --build -d
docker compose ps
```

Abrir http://127.0.0.1:4321. Inicio permite filtrar por origen/destino y seleccionar un vuelo. Si falta identificación, se conserva la selección al pasar por **Ingresar / crear perfil**. Después de confirmar, el código y **Mis reservas** permiten consultar y cancelar sin escribir UUID.

## Identificación de demostración

No es autenticación productiva: conocer tipo/número de documento y correo permite ingresar. No hay contraseña, JWT ni proveedor externo. Usa datos ficticios.

El BFF firma la cookie `aeroreserva_session` con HMAC-SHA256. Dura ocho horas y usa `HttpOnly`, `SameSite=Lax`, `Path=/` y `Secure` bajo HTTPS. La clave aleatoria se genera por proceso: reiniciar el frontend invalida las sesiones. Se puede proporcionar `SESSION_SECRET` fuera del repositorio si se requiere compartir una clave entre procesos. Compose no se modifica ni requiere secretos de desarrollo.

Las operaciones de escritura verifican el origen. El BFF obtiene el pasajero exclusivamente de la cookie; no acepta `passenger_id` del navegador. Salir elimina la cookie. Es una sesión firmada sin almacenamiento ni revocación central: no usar como solución productiva.

## Contratos y consultas

- Se conserva `proto/aeroreserva.proto`, paquete `aeroreserva.v1` y los métodos existentes.
- Nuevo `PassengerService.FindPassenger(FindPassengerRequest)`: tipo/número de documento y correo. Consulta `aeroreserva_passengers.passengers_by_document` por su clave y verifica el correo.
- Nuevo `BookingService.ListBookingsByPassenger(GetByIdRequest)`: el `id` es el pasajero. Consulta `aeroreserva_bookings.bookings_by_passenger`, incluyendo todas las páginas Cassandra.
- Las tablas ya existían; no fue necesario modificar el esquema. Cada servicio conserva su keyspace. No se usa `ALLOW FILTERING`.
- `GET /api/bookings` devuelve solo reservas de la sesión; el antiguo parámetro `id` no expone reservas globales. El BFF agrega vuelos con una llamada `ListFlights` y deduplica consultas `GetFlight` si un vuelo no está en el catálogo.
- `POST /api/bookings` recibe `flight_number`; `DELETE /api/bookings` recibe `booking_code` y comprueba que pertenece al pasajero. Los UUID quedan dentro del BFF/gRPC.
- `/api/passengers`: POST con `mode=login|register`; GET consulta el nombre identificado; DELETE cierra la sesión. `/pasajeros` redirige a `/ingresar`.
- Seed de nueve vuelos colombianos del 20 al 27 de octubre de 2026, futuros a la fecha de esta entrega (28 de septiembre de 2026). Cada vuelo se inserta en `flights_by_id` y `flights_catalog`. `IF NOT EXISTS` conserva datos y cupos al repetir el inicializador; no actualiza vuelos ya existentes. Las horas de la interfaz usan `America/Bogota`.

## Regenerar stubs Ruby

Con los contenedores existentes, en PowerShell:

```powershell
docker cp proto/aeroreserva.proto aeroreserva-passenger-service:/tmp/aeroreserva.proto
docker exec aeroreserva-passenger-service bundle exec grpc_tools_ruby_protoc -I /tmp --ruby_out=/tmp --grpc_out=/tmp /tmp/aeroreserva.proto
foreach ($service in @('flight-service', 'passenger-service', 'booking-service')) {
  docker cp aeroreserva-passenger-service:/tmp/aeroreserva_pb.rb "services/$service/lib/aeroreserva_pb.rb"
  docker cp aeroreserva-passenger-service:/tmp/aeroreserva_services_pb.rb "services/$service/lib/aeroreserva_services_pb.rb"
}
```

## Validación

```powershell
npm --prefix frontend run build
docker compose up --build -d
docker compose ps
npm exec --yes --package=@playwright/test -- playwright --version
$env:TEST_BASE_URL = 'http://127.0.0.1:4321'
node tests/demo-flow.cjs <ruta-al-paquete-playwright>
```

La prueba usa Edge instalado, crea dos perfiles ficticios con documento único y deja la reserva de prueba cancelada. Comprueba aislamiento, cookie alterada, origen externo, filtros, cupos, reingreso y ausencia de UUID visibles. No elimina datos. El argumento de Playwright es la carpeta del paquete instalado temporalmente por npm, no su ejecutable.

Resultados y lista exacta de archivos: [validación del incremento](docs/validacion-identificacion.md).
