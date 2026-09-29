# Validación: resiliencia, concurrencia y consistencia de cupos

Fecha: 29 de septiembre de 2026. Entorno real Docker Compose (6 contenedores) en Windows 11 con Docker Desktop. Cada ejecución partió de un arranque en frío (`docker compose down` sin `-v` y luego `docker compose up --build -d`).

## Resultado

| Prueba | Resultado |
| --- | --- |
| Arranque en frío | Los 5 contenedores de larga duración healthy en 49 s; `cassandra-init` terminó con código 0 |
| booking-service, `bin/rails test` | 25 pruebas, 114 aserciones, 0 fallos, 3 de 3 pasadas |
| flight-service, `bin/rails test` | 3 pruebas, 13 aserciones, 0 fallos, 3 de 3 pasadas |
| passenger-service, `bin/rails test` | 1 prueba, 2 aserciones, 0 fallos, 3 de 3 pasadas |
| Extremo a extremo (`tests/demo-flow.cjs`) con Cassandra recién iniciada | 4 de 4 fases PASS, sin errores JavaScript |
| Scripts `bin/test_*.rb` de los tres servicios | Sin errores |
| `tests/catalog_consistency.rb` | 9 vuelos coherentes entre `flights_by_id` y `flights_catalog` |
| Catálogo `/api/flights`, 30 consultas seguidas | p95 = 0,051 s (meta: menos de 2 s) |
| OccupySeat, 20 ciclos ocupar/liberar | p95 = 18 ms (timeout gRPC: 1 s) |

## Escenarios de concurrencia

| Escenario | Antes de la corrección | Después |
| --- | --- | --- |
| 12 hilos ocupan un vuelo con 3 cupos (`atomic_seats_integration_test.rb`) | — | Exactamente 3 éxitos y 9 FAILED_PRECONDITION; lo mismo al liberar |
| 2 cancelaciones simultáneas de la misma reserva (`cancel_race_integration_test.rb`) | 5 de 5 intentos liberaban 2 cupos | 1 cupo liberado; la segunda recibe FAILED_PRECONDITION |
| 5 registros simultáneos con el mismo documento (`duplicate_document_integration_test.rb`) | Se creaban 5 pasajeros | 1 pasajero; los otros 4 reciben ALREADY_EXISTS |

## Escenarios de fallo

| Escenario | Comportamiento verificado |
| --- | --- |
| Falla guardar la reserva después de ocupar el cupo (`saga_integration_test.rb`) | La reserva queda CANCELLED, el cupo vuelve a su valor original y desaparece la proyección CONFIRMED |
| Resultado ambiguo al ocupar el cupo (`booking_saga_test.rb`) | No se compensa nada |
| flight-service apagado (`docker stop`) y se cancela una reserva | Responde UNAVAILABLE, la reserva sigue CONFIRMED y el cupo no se pierde. Al volver flight-service, la cancelación funciona y el cupo se restaura |
| Timeout con la conexión establecida al liberar el cupo (`cancel_booking_test.rb`, `grpc_transport_test.rb`) | La reserva queda CANCELLED y se registra `seat_release_ambiguous`; nunca vuelve a CONFIRMED sin su cupo |
| Circuito abierto (`grpc_resilience_test.rb`, `grpc_transport_test.rb`) | Tras el umbral rechaza sin tocar la red; pasado el tiempo de recuperación deja pasar una sola llamada de prueba |

Los eventos `booking_saga` y `circuit_breaker` se ven en vivo con `docker compose logs -f booking-service`.

## Comandos

```powershell
docker compose down
docker compose up --build -d
docker compose ps -a

docker exec aeroreserva-booking-service bin/rails test
docker exec aeroreserva-flight-service bin/rails test
docker exec aeroreserva-passenger-service bin/rails test

docker exec aeroreserva-flight-service bundle exec ruby bin/test_flights.rb
docker exec aeroreserva-flight-service bundle exec ruby bin/test_seat_cycle.rb
docker exec aeroreserva-passenger-service bundle exec ruby bin/test_passengers.rb
docker exec aeroreserva-booking-service bundle exec ruby bin/test_bookings.rb
Get-Content -Raw -Encoding UTF8 tests/catalog_consistency.rb | docker exec -i aeroreserva-flight-service bundle exec ruby -

$env:TEST_BASE_URL = 'http://127.0.0.1:4321'
node tests/demo-flow.cjs <ruta-al-paquete-playwright>
```

Las pruebas conservan sus datos: pasajeros con documentos `DEMO…`, `SAGA…`, `RACE…`, `DUP…` y reservas canceladas. Para empezar una demostración con datos limpios, ver "Preparar la demostración" en el README.
