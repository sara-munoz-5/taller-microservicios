# Correcciones al documento técnico (Plantilla_documentacion_AeroReserva)

Texto de reemplazo para que el documento describa exactamente el código de `main`. Cada punto indica la sección, lo que dice hoy y lo que debe decir.

## Datos generales

- **Profesor:** completar.
- **Versión o tag:** completar al crear el release final (el repositorio aún no tiene tags).
- **Numeración:** el documento salta de la sección 5 a la 7. Renumerar 7 → 6, 8 → 7, 9 → 8 y 10 → 9, o agregar una sección 6.

## Sección 4. Backend, gRPC y flujo de negocio

**Dice:** "compilado a Ruby como Aeroreserva::V1::\* en cada servicio y a TypeScript en el frontend vía @grpc/proto-loader".

**Debe decir:** "compilado a Ruby como Aeroreserva::V1::\* en cada servicio. El frontend no genera código: `@grpc/proto-loader` carga `proto/aeroreserva.proto` en tiempo de ejecución, al iniciar el BFF (`frontend/src/lib/server.ts`)".

**Tabla "Convención de errores gRPC", agregar filas:**

| Código gRPC | Valor | Cuándo se usa |
| --- | --- | --- |
| UNKNOWN | 2 | Excepción no controlada, por ejemplo un timeout de Cassandra dentro de un servicio. El BFF responde 503 con un mensaje genérico. |
| ALREADY_EXISTS | 6 | passenger-service: el documento ya está registrado. |
| ABORTED | 10 | flight-service agotó los `FLIGHT_CAS_ATTEMPTS` por contención sobre el mismo vuelo. El BFF responde 409 ("El vuelo está recibiendo muchas solicitudes"). |

## Sección 4.1. Flujo de creación de reserva

El orden descrito en los pasos 4 a 9 es correcto. Si en la presentación se resume, usar este orden: validar formato UUID → consultar pasajero → consultar vuelo y cupo → **generar id y código (`prepare_booking`)** → ocupar cupo → guardar reserva CONFIRMED. El id se genera después de las validaciones, no al principio.

## Sección 4.2. Endpoints BFF

**Dice:** "Cada endpoint del BFF vive en frontend/src/lib/server.ts".

**Debe decir:** "Cada endpoint del BFF vive en `frontend/src/pages/api/` (`flights.ts`, `passengers.ts`, `bookings.ts`). Todos comparten las piezas de `frontend/src/lib/server.ts`:".

**Traducción de errores, reemplazar la última frase por:** "INVALID_ARGUMENT(3)→400, NOT_FOUND(5)→404, ALREADY_EXISTS(6)→409, FAILED_PRECONDITION(9)→409, ABORTED(10)→409, UNKNOWN(2)→503, DEADLINE_EXCEEDED(4)→503, UNAVAILABLE(14)→503, INTERNAL(13)→500 y cualquier otro→500 (un cuerpo JSON inválido se responde con 400). Nunca se reenvía al navegador el detalle interno del error".

**Tabla de endpoints:** `GET /api/passengers` existe, pero ninguna página lo usa; el nombre del pasajero se obtiene de la sesión al renderizar en el servidor.

## Sección 5. Cassandra y modelo de datos

**Dice:** "BookingRepository resuelve esto con un batch de INSERT + DELETE en las tres tablas, tanto al cancelar como al compensar una reserva fallida (…) En bookings_by_id y bookings_by_passenger (…) sí se usa UPDATE directamente".

**Debe decir:** "Al compensar una reserva fallida, `compensate_creation` escribe CANCELLED en las tres tablas con un batch de INSERT + DELETE. Al cancelar, el cambio de estado se hace en dos pasos. Primero, `mark_cancelled` cambia `bookings_by_id` de CONFIRMED a CANCELLED con una Lightweight Transaction (`UPDATE … IF status = 'CONFIRMED'`): de dos cancelaciones simultáneas solo una se aplica, y solo esa libera el cupo. Después, `project_cancellation` actualiza `bookings_by_passenger` y mueve la fila en `bookings_by_status` con un batch. `passengers_by_document` también usa una LWT (`INSERT … IF NOT EXISTS`) para que dos registros simultáneos con el mismo documento no creen dos pasajeros".

## Sección 7. Calidad, pruebas y resiliencia

**Fila "Recuperación", agregar al final:** "Solo cuentan como fallo UNAVAILABLE y DEADLINE_EXCEEDED. Una respuesta de negocio (NOT_FOUND, FAILED_PRECONDITION) o un error interno del servicio remoto (UNKNOWN) prueba que la dependencia respondió y no abre el circuito".

**Fila "Disponibilidad":** es correcta desde este cambio: el frontend también tiene healthcheck (consulta `/api/flights`).

**"Pruebas de integración", reemplazar la primera frase por:** "Desde el pull del 28 de septiembre, los tres servicios tienen pruebas automatizadas con Minitest. Se ejecutan con `docker exec aeroreserva-<servicio> bin/rails test`:".

**Agregar a la lista de pruebas:**

- `cancel_booking_test.rb` (unitaria): la cancelación reclama el estado antes de liberar el cupo; una cancelación que pierde la carrera no libera otro cupo; un rechazo seguro (circuito abierto, servicio inalcanzable, FAILED_PRECONDITION) revierte la cancelación; un resultado ambiguo (timeout con la conexión establecida) deja la reserva cancelada y lo registra para conciliación, sin volver a confirmarla.
- `cancel_race_integration_test.rb` (integración real, concurrencia): dos cancelaciones simultáneas de la misma reserva liberan exactamente un cupo.
- `duplicate_document_integration_test.rb` (integración real, concurrencia, passenger-service): cinco registros simultáneos con el mismo documento crean un solo pasajero.
- `grpc_transport_test.rb`: además confirma, contra una conexión real, que un timeout sin conexión establecida se clasifica como "no ejecutado" y uno con la conexión establecida como ambiguo.

**Subsección "Saga", agregar un párrafo sobre la cancelación:** "La cancelación aplica la misma regla. Si flight-service no liberó el cupo con seguridad (circuito abierto, servicio inalcanzable o rechazo explícito), la reserva vuelve a CONFIRMED y el usuario recibe un error. Si el resultado es ambiguo (timeout después de enviar la solicitud), la reserva queda CANCELLED y se registra `seat_release_ambiguous`: en el peor caso queda un cupo retenido, nunca una reserva confirmada sin su cupo".

## Sección 8. ADR

- La tabla tiene dos filas **ADR-005**. La de Circuit Breaker es **ADR-006** y le falta el estado **Aceptada**.
- **ADR-005, Decisión:** reemplazar "La cancelación también actualiza la reserva y devuelve el cupo conforme al flujo implementado" por "La cancelación reclama primero el estado de la reserva con una transacción ligera y solo después libera el cupo; si la liberación falla con seguridad, revierte el estado".

## Sección 9. Limitaciones y trabajo futuro (texto propuesto)

- **Identificación demostrativa.** Basta con documento y correo para ingresar; no hay contraseña, JWT ni proveedor de identidad. La cookie firmada no tiene revocación central, y su clave se genera por proceso, así que reiniciar el BFF cierra todas las sesiones.
- **Despliegue local.** Todo corre en una sola máquina con Docker Compose y una única instancia de Cassandra (factor de replicación 1). Esa instancia es un punto único de fallo; no hay nube, Kubernetes, escalado horizontal ni alta disponibilidad.
- **Fuera de alcance funcional:** pagos, reembolsos, selección de silla, check-in, equipaje y correos reales.
- **Consistencia eventual acotada.** La Saga no ofrece atomicidad ACID entre servicios. Un timeout ambiguo al ocupar o liberar un cupo puede dejar un cupo retenido sin reserva; queda registrado en los logs y hoy se concilia manualmente. Un proceso automático de conciliación queda como trabajo futuro.
- **Observabilidad básica.** Solo hay logs JSON y healthchecks; no hay métricas, trazas distribuidas ni alertas.
- **Datos semilla con fechas fijas** (20 al 27 de octubre de 2026). Hay que actualizarlos para demostraciones posteriores.
- **Trabajo futuro:** autenticación real, conciliación automática de cupos, liberación idempotente por reserva, métricas y trazas (OpenTelemetry), réplicas de Cassandra y despliegue en la nube.

## Diagramas del PDF (redibujados)

Los diagramas redibujados que se pegaron en el PDF tienen etiquetas cruzadas. Las versiones PlantUML que existían en `docs/arquitecture` (eliminadas del repositorio en el commit `76ff4f8`) tenían las relaciones correctas y sirven de referencia en el historial de Git:

| Figura | Etiqueta actual | Corrección |
| --- | --- | --- |
| 2. Contenedores | Flight Service → Keyspace de vuelos: "Valida pasajeros" | "Lee y escribe vuelos y cupos" |
| 2. Contenedores | Passenger Service → Keyspace de pasajeros: "Lee y actualiza vuelos" | "Lee y escribe pasajeros" |
| 2. Contenedores | Booking Service → Flight Service: "Lee y escribe reservas" | "Consulta, ocupa y libera cupos (gRPC)" |
| 2. Contenedores | Booking Service → Passenger Service: "Lee y escribe pasajeros" | "Valida pasajero (gRPC)" |
| 2. Contenedores | Booking Service → Keyspace de reservas: "Ocupa y libera cupos" | "Lee y escribe reservas" |
| 5. Componentes de Passenger | Passenger Repository → Keyspace: "Lee/escribe vuelos" | "Lee/escribe pasajeros" |
| 6. Dinámico | Passenger Service en rojo y Flight Service en amarillo | Usar los mismos colores que en las demás figuras (Flight rojo, Passenger amarillo) |
| 7. Despliegue | Frontend → Booking: "gRPC · pasajeros" y Frontend → Passenger: "gRPC · reservas" | Intercambiar: Frontend → Booking "gRPC · reservas", Frontend → Passenger "gRPC · pasajeros" |
| 7. Despliegue | Flecha Flight → Booking "gRPC · cupos" | Invertir el sentido: Booking → Flight |
