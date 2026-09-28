# Validación: identificación y Mis reservas

Fecha: 28 de septiembre de 2026. Entorno real Docker y navegador Edge sin interfaz, mediante Playwright 1.63.0. URL validada: http://127.0.0.1:4321.

## Resultado

| Prueba | Resultado |
| --- | --- |
| Build local del frontend | OK, salida 0 |
| Construcción y arranque Docker | OK, salida 0, ejecutado nuevamente con el código final |
| Estado Docker | Cassandra y tres servicios gRPC saludables; frontend Up; inicializador Exited (0) |
| Catálogo y filtros | 9 vuelos futuros, capacidades válidas; Cali → Bogotá devuelve una tarjeta |
| Selección anónima | Redirige a Ingresar y conserva AR404 |
| Registro de pasajero | Perfil creado; vuelve al vuelo seleccionado |
| Confirmación | Muestra código RES; no pide de nuevo datos personales; cupos disminuyen en uno |
| Mis reservas | Muestra código, estado y detalles del vuelo del pasajero identificado |
| Aislamiento | Otro perfil obtiene lista vacía y 404 al intentar cancelar la reserva ajena |
| Sesión | Cookie HttpOnly y SameSite=Lax; cookie alterada devuelve 401 |
| Origen externo | Escritura rechazada con 403 |
| Salir | API de reservas vuelve a responder 401 |
| Identificación existente | Correo incorrecto rechazado; documento/correo correctos recuperan las reservas |
| Recarga | Conserva identificación y reservas |
| Cancelación | Estado Cancelada persistido al recargar; cupo restaurado; botón retirado |
| Cancelación repetida | Devuelve 409 sin liberar otro cupo |
| Pasajero ya identificado | Selecciona un vuelo y crea una segunda reserva sin formularios personales; se cancela también |
| UUID | Ninguno visible ni en URL; respuestas públicas de vuelos y reservas tampoco contienen UUID |
| Navegador | Sin errores JavaScript; Mis reservas sin desbordamiento horizontal a 390 px |
| Cassandra | Nueve vuelos con los mismos datos y cupos en flights_by_id y flights_catalog |
| Revisión de diff | Sin errores de whitespace; Git avisa de normalización LF/CRLF en Windows |

La última ejecución completa creó `DEMO1790610511969` y `DEMO1790610511969B`. La primera reserva de esa ejecución fue `RES-5E58C3`; sus dos reservas quedaron canceladas. Una ejecución previa satisfactoria creó `DEMO1790610352512`, `DEMO1790610352512B` y `RES-381253`, también cancelada. Se conservaron los datos de prueba.

## Comandos ejecutados

Inspección con `rg --files`, `rg`, `Get-Content`, `git status --short` y `git diff`: contratos, servicios, clientes gRPC, CQL, inicializador, rutas/componentes Astro, configuración y documentación. Se consultaron las guías oficiales de rutas, componentes y estilos exigidas por `frontend/AGENTS.md`.

```powershell
npm --prefix frontend run build

docker cp proto/aeroreserva.proto aeroreserva-passenger-service:/tmp/aeroreserva.proto
docker exec aeroreserva-passenger-service bundle exec grpc_tools_ruby_protoc -I /tmp --ruby_out=/tmp --grpc_out=/tmp /tmp/aeroreserva.proto
foreach ($service in @('flight-service', 'passenger-service', 'booking-service')) {
  docker cp aeroreserva-passenger-service:/tmp/aeroreserva_pb.rb "services/$service/lib/aeroreserva_pb.rb"
  docker cp aeroreserva-passenger-service:/tmp/aeroreserva_services_pb.rb "services/$service/lib/aeroreserva_services_pb.rb"
}

docker compose up --build -d
docker compose ps
docker compose ps -a
docker compose logs --tail 5 cassandra-init

npm exec --yes --package=@playwright/test -- playwright --version
$env:TEST_BASE_URL = 'http://127.0.0.1:4321'
node tests/demo-flow.cjs C:/Users/munoz/AppData/Local/npm-cache/_npx/420ff84f11983ee5/node_modules/playwright

git -c core.quotePath=false diff --check
```

La comprobación Cassandra se ejecutó enviando el script Ruby por entrada estándar a `docker exec -i aeroreserva-flight-service bundle exec ruby -`. Quedó guardado para repetirla:

```powershell
Get-Content -Raw -Encoding UTF8 tests/catalog_consistency.rb | docker exec -i aeroreserva-flight-service bundle exec ruby -
```

Todos los comandos de validación final terminaron correctamente. Incidencias resueltas durante la preparación:

- Docker y npm inicialmente no tenían acceso desde el sandbox. Se repitieron con elevación autorizada; Docker respondió y npm obtuvo Playwright sin cambiar dependencias del proyecto.
- La primera prueba de navegador contra `localhost` devolvió `ECONNRESET` antes de crear datos. `docker compose logs --tail 50 frontend` mostró el servidor activo y `curl.exe -I http://127.0.0.1:4321/` respondió 200. Las pruebas completas se ejecutaron correctamente por IPv4.

## Archivos exactos

Modificados:

- `README.md`
- `frontend/src/components/GlobalNav.astro`
- `frontend/src/pages/api/bookings.ts`
- `frontend/src/pages/api/flights.ts`
- `frontend/src/pages/api/passengers.ts`
- `frontend/src/pages/index.astro`
- `frontend/src/pages/pasajeros.astro`
- `frontend/src/pages/reservas.astro`
- `frontend/src/pages/reservar.astro` (ya existía sin seguimiento en el árbol de trabajo)
- `infrastructure/cassandra/02-seed-flights.cql`
- `proto/aeroreserva.proto`
- `services/booking-service/lib/aeroreserva_pb.rb`
- `services/booking-service/lib/aeroreserva_services_pb.rb`
- `services/booking-service/lib/booking_repository.rb`
- `services/booking-service/lib/booking_service_impl.rb`
- `services/flight-service/lib/aeroreserva_pb.rb`
- `services/flight-service/lib/aeroreserva_services_pb.rb`
- `services/passenger-service/lib/aeroreserva_pb.rb`
- `services/passenger-service/lib/aeroreserva_services_pb.rb`
- `services/passenger-service/lib/passenger_service_impl.rb`

Nuevos:

- `frontend/src/layouts/DemoLayout.astro`
- `frontend/src/lib/server.ts`
- `frontend/src/lib/browser.ts`
- `frontend/src/pages/ingresar.astro`
- `tests/demo-flow.cjs`
- `tests/catalog_consistency.rb`
- `docs/validacion-identificacion.md`

Eliminados por quedar sin uso y pertenecer al flujo anterior que solicitaba UUID:

- `frontend/src/components/bookings/BookingForm.astro`
- `frontend/src/components/bookings/BookingLookup.astro`
- `frontend/src/components/bookings/booking-api.ts`
- `frontend/src/components/passengers/PassengerForm.astro`

No se modificaron `docker-compose.yml`, volúmenes, esquema CQL ni los archivos raíz `package.json` y `package-lock.json` que ya estaban sin seguimiento. No se borraron datos Cassandra.

## Límites de la demo

La identificación por documento/correo no es autenticación productiva. La clave de firma aleatoria por proceso invalida sesiones al reiniciar el BFF. El seed conserva filas existentes y contiene fechas fijas de octubre de 2026; habrá que actualizarlo para demostraciones posteriores. Este incremento conserva el mecanismo existente de ocupación/liberación de cupos entre servicios; no introduce transacciones distribuidas ni una garantía nueva frente a reservas concurrentes.
