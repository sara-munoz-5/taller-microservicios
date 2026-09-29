# AeroReserva

Sistema web de reservas de vuelos construido con arquitectura de microservicios para el taller de Arquitectura de Software. Grupo 5: Samuel Daza, Samuel Velandia y Sara Muñoz.

## 1. Descripción del sistema

### Qué es y qué problema resuelve

AeroReserva permite consultar vuelos disponibles, identificarse como pasajero, reservar un cupo, ver las reservas propias y cancelarlas. Su propósito es demostrar cómo se reparten las responsabilidades de un flujo de reservas entre servicios independientes, cada uno con sus propios datos, y cómo se mantiene la consistencia de los cupos cuando una operación involucra varios servicios o varias solicitudes llegan al mismo tiempo: un vuelo nunca se sobrevende y una cancelación devuelve exactamente un cupo.

### Arquitectura general

```text
Navegador ──HTTP/JSON (puerto 4321)──► frontend (Astro: páginas + BFF)
                                          │ gRPC
                  ┌───────────────────────┼────────────────────────┐
                  ▼                       ▼                        ▼
          flight-service          passenger-service         booking-service
             (50051)                   (50052)                  (50053)
                  ▲                       ▲                        │
                  └─── gRPC: cupos ───────┴── gRPC: valida pasajero ┘
                  │                       │                        │
          aeroreserva_flights    aeroreserva_passengers   aeroreserva_bookings
                  └──────────── Cassandra 4.0 (una instancia, 3 keyspaces) ┘
```

| Componente | Carpeta | Responsabilidad |
| --- | --- | --- |
| frontend | `frontend/` | Páginas web y BFF (*Backend for Frontend*): las rutas `src/pages/api/*.ts` reciben HTTP/JSON del navegador, verifican la sesión y llaman por gRPC a los microservicios. |
| flight-service | `services/flight-service/` | Catálogo de vuelos y cupos. Ocupa y libera cupos con transacciones ligeras (LWT) de Cassandra para evitar la sobreventa. |
| passenger-service | `services/passenger-service/` | Registro e identificación de pasajeros por documento y correo. |
| booking-service | `services/booking-service/` | Crea, consulta y cancela reservas. Orquesta el flujo como una Saga: valida al pasajero y al vuelo, ocupa el cupo y guarda la reserva, y compensa si algo falla. Protege sus llamadas a los otros servicios con un Circuit Breaker. |
| cassandra / cassandra-init | `infrastructure/cassandra/` | Base de datos. El inicializador crea los keyspaces, las tablas y 9 vuelos de ejemplo. |

**Comunicación.** El navegador solo habla HTTP/JSON con el frontend. Toda la comunicación interna usa gRPC con el contrato `proto/aeroreserva.proto` (paquete `aeroreserva.v1`). booking-service es el único servicio que llama a los otros dos. Cada servicio accede solo a su propio keyspace; nunca consulta las tablas de otro.

### Alcance funcional

- Consultar el catálogo de vuelos con rutas, horarios y cupos, y filtrarlo por origen y destino.
- Registrarse o identificarse con tipo y número de documento más correo (identificación de demostración, sin contraseña).
- Crear una reserva para el pasajero identificado en un vuelo con cupos; se muestra un código `RES-XXXXXX`.
- Consultar únicamente las reservas propias en "Mis reservas".
- Cancelar una reserva propia y devolver el cupo al vuelo.
- Informar errores con mensajes claros, sin mostrar identificadores técnicos (UUID) al usuario.

### Fuera de alcance

Según `docs/01-definicion-aeroreserva.md`: pagos reales, reembolsos, selección de sillas, check-in, equipaje, autenticación real de usuarios, envío de correos reales, gestión de tripulación, aeronaves y mantenimiento, cambios de itinerario e integración con aerolíneas externas.

## 2. Tecnologías usadas

Versiones tomadas de los Dockerfiles, `frontend/package-lock.json`, los `Gemfile.lock` de los servicios y `docker-compose.yml`.

### Frontend y BFF (`frontend/`)

| Tecnología | Versión | Uso |
| --- | --- | --- |
| Node.js | 24 (imagen `node:24-bookworm-slim`; `package.json` exige >= 22.12.0) | Ejecuta el servidor de Astro |
| Astro | 7.3.2 | Páginas `.astro` y rutas API del BFF, renderizado en servidor (`output: "server"`) |
| @astrojs/node | 11.1.6 | Adaptador Node en modo `standalone` |
| TypeScript | Configuración `astro/tsconfigs/strict` | Lenguaje de las rutas API y de `src/lib/` |
| @grpc/grpc-js | 1.14.4 | Cliente gRPC hacia los tres microservicios |
| @grpc/proto-loader | 0.8.1 | Carga `proto/aeroreserva.proto` al iniciar (no se genera código) |

### Backend (`services/*`, las tres gemas son iguales en los tres servicios)

| Tecnología | Versión | Uso |
| --- | --- | --- |
| Ruby | 4.0 (imagen `ruby:4.0`; `.ruby-version` 4.0.7) | Lenguaje de los tres microservicios |
| Ruby on Rails | 8.1.3.1, modo `api_only`, sin Active Record | Estructura y configuración de cada servicio; el proceso principal es `bin/grpc_server`, no `rails server` |
| grpc / grpc-tools | 1.84.0 | Servidor y clientes gRPC, y generación de stubs Ruby |
| google-protobuf | 4.36.1 | Mensajes Protocol Buffers |
| cassandra-driver | 3.2.5 | Acceso a Cassandra desde Ruby |
| Minitest | 6.0.6 | Pruebas unitarias y de integración (`bin/rails test`) |

### Base de datos

| Tecnología | Versión | Uso |
| --- | --- | --- |
| Apache Cassandra | 4.0 (imagen `cassandra:4.0`) | Un keyspace por servicio (`aeroreserva_flights`, `aeroreserva_passengers`, `aeroreserva_bookings`), `SimpleStrategy` con factor de replicación 1; tablas diseñadas por consulta y LWT (`IF ...`) para cupos, cancelaciones y documentos únicos |

### Comunicación entre servicios

| Tecnología | Uso |
| --- | --- |
| gRPC sobre HTTP/2 | Llamadas del BFF a los servicios y de booking-service a flight-service y passenger-service |
| Protocol Buffers (`proto3`) | Contrato único `proto/aeroreserva.proto`, paquete `aeroreserva.v1` |
| HTTP/JSON | Navegador ↔ BFF, con sesión en cookie firmada HMAC-SHA256 |

### Orquestación e infraestructura

| Tecnología | Uso |
| --- | --- |
| Docker | Imagen del frontend (`frontend/Dockerfile`) e imagen común de los servicios (`services/Dockerfile`, que elige el servicio con el argumento `SERVICE`) |
| Docker Compose | 6 contenedores, red `aeroreserva-network`, volumen persistente `aeroreserva_cassandra_4_data`, healthchecks y orden de arranque con `depends_on` |
| Playwright (con Microsoft Edge) | Prueba de navegador de extremo a extremo `tests/demo-flow.cjs`; se instala temporalmente con `npm exec` y no es una dependencia del proyecto |

## 3. Pasos para despliegue

### Requisitos previos

- **Docker** con **Docker Compose v2** (el comando `docker compose`, no `docker-compose`). En Windows y macOS: Docker Desktop abierto y con el motor iniciado. Verificado con Docker 29.8.0 y Docker Compose 5.5.1.
- **Git**, para clonar el repositorio.
- Conexión a Internet la primera vez, para descargar imágenes, gemas y paquetes npm.
- Puertos libres en el equipo: **4321** (web), **9042** (Cassandra) y **50061** (flight-service).

No es necesario instalar Node, Ruby, Rails ni Cassandra en el equipo: todo corre dentro de los contenedores.

### Levantar el sistema

```sh
# 1. Obtener el código
git clone https://github.com/sara-munoz-5/taller-microservicios.git
cd taller-microservicios
# (si ya estaba clonado: git pull origin main)

# 2. Construir las imágenes y levantar los 6 contenedores en segundo plano
docker compose up --build -d

# 3. Revisar el estado
docker compose ps -a
```

La primera construcción tarda varios minutos. Las siguientes tardan alrededor de un minuto, casi todo mientras Cassandra arranca. Compose respeta este orden: Cassandra healthy → `cassandra-init` termina bien → flight-service y passenger-service healthy → booking-service healthy → frontend.

Opcional: para cambiar tiempos de espera o parámetros del Circuit Breaker, copiar `.env.example` a `.env`, editarlo y volver a ejecutar `docker compose up --build -d`.

### Verificar que todo quedó arriba

`docker compose ps -a` debe mostrar:

| Contenedor | Estado esperado | Puertos |
| --- | --- | --- |
| `aeroreserva-cassandra` | `Up (healthy)` | `9042` publicado |
| `aeroreserva-cassandra-init` | **`Exited (0)`**. Es normal: solo crea el esquema y carga los vuelos, y luego termina. Cualquier otro código de salida indica un error. | — |
| `aeroreserva-flight-service` | `Up (healthy)` | interno `50051`, publicado como `50061` |
| `aeroreserva-passenger-service` | `Up (healthy)` | `50052`, solo dentro de la red de Docker |
| `aeroreserva-booking-service` | `Up (healthy)` | `50053`, solo dentro de la red de Docker |
| `aeroreserva-web` | `Up (healthy)` | `4321` publicado |

Si algún contenedor aparece como `starting`, esperar unos segundos y repetir el comando. El frontend queda healthy cuando responde correctamente `GET /api/flights`, lo que confirma la cadena web → gRPC → flight-service → Cassandra.

### URL del sistema

- Aplicación web: **http://127.0.0.1:4321** (o `http://localhost:4321`).
- Desde otro equipo de la misma red: `http://IP_DEL_EQUIPO:4321`, siempre que el firewall permita el puerto 4321.
- API del BFF, útil para comprobar: http://127.0.0.1:4321/api/flights devuelve los 9 vuelos en JSON.

### Ver logs

```sh
# Todos los contenedores, en vivo
docker compose logs -f

# Solo reservas: eventos de la Saga (pattern "booking_saga") y del Circuit Breaker (pattern "circuit_breaker")
docker compose logs -f booking-service

# Resultado del inicializador de Cassandra
docker compose logs cassandra-init
```

### Ejecutar las pruebas

```sh
docker exec aeroreserva-booking-service bin/rails test
docker exec aeroreserva-flight-service bin/rails test
docker exec aeroreserva-passenger-service bin/rails test
```

Cada comando debe terminar con `0 failures, 0 errors`. Las pruebas de integración usan Cassandra y los servicios reales. La prueba de navegador y sus resultados están en [docs/validacion-identificacion.md](docs/validacion-identificacion.md). La de resiliencia y concurrencia, en [docs/validacion-resiliencia.md](docs/validacion-resiliencia.md).

### Detener y reiniciar

```sh
# Detener conservando los datos
docker compose down

# Detener y BORRAR los datos (pasajeros, reservas y cupos); al volver a levantar se recargan los 9 vuelos
docker compose down -v
```

### Antes de una demostración

1. Levantar todo al menos 2 minutos antes y esperar a que `aeroreserva-web` esté `healthy`.
2. Para empezar con los cupos completos: `docker compose down -v` y luego `docker compose up --build -d`.
3. No reiniciar `aeroreserva-web` durante la presentación: la clave de la sesión se genera al iniciar el proceso, así que un reinicio cierra todas las sesiones.
4. Para mostrar el Circuit Breaker: `docker stop aeroreserva-flight-service`, intentar reservar o cancelar (se obtiene "servicio no disponible" y no se pierde ningún cupo) y luego `docker start aeroreserva-flight-service`. El circuito vuelve a cerrarse unos 10 segundos después.
5. Los vuelos de ejemplo salen entre el 20 y el 27 de octubre de 2026. Después de esas fechas hay que actualizar `infrastructure/cassandra/02-seed-flights.cql`.

### Problemas frecuentes

| Síntoma | Causa y solución |
| --- | --- |
| `docker compose` no conecta con el motor | Docker Desktop no está abierto o no ha terminado de iniciar. |
| `cassandra-init` termina con un código distinto de 0 | Revisar `docker compose logs cassandra-init` y volver a ejecutar `docker compose up -d`. |
| Error de puerto en uso | Otro programa usa el 4321, el 9042 o el 50061. Cerrarlo o cambiar el puerto publicado en `docker-compose.yml`. |
| La web pide ingresar de nuevo | Se reinició el contenedor `aeroreserva-web`. Ingresar otra vez con el mismo documento y correo. |

## Información adicional

### Identificación de demostración

No es autenticación productiva: conocer el tipo y número de documento y el correo permite ingresar. No hay contraseña, JWT ni proveedor externo. Usa datos ficticios.

El BFF firma la cookie `aeroreserva_session` con HMAC-SHA256. Dura ocho horas y usa `HttpOnly`, `SameSite=Lax`, `Path=/`, y `Secure` bajo HTTPS. La clave aleatoria se genera por proceso, así que reiniciar el frontend invalida las sesiones. Se puede proporcionar `SESSION_SECRET` fuera del repositorio si se requiere compartir la clave entre procesos.

Las operaciones de escritura verifican el origen de la petición. El BFF obtiene el pasajero exclusivamente de la cookie; no acepta `passenger_id` del navegador. Salir elimina la cookie. Es una sesión firmada sin almacenamiento ni revocación central.

### Contratos y consultas

- `proto/aeroreserva.proto`, paquete `aeroreserva.v1`:
  - FlightService: `ListFlights`, `GetFlight`, `CheckAvailability`, `OccupySeat`, `ReleaseSeat`.
  - PassengerService: `FindPassenger`, `CreatePassenger`, `GetPassenger`.
  - BookingService: `ListBookingsByPassenger`, `CreateBooking`, `GetBooking`, `ListBookings`, `CancelBooking`.
- `FindPassenger` consulta `aeroreserva_passengers.passengers_by_document` por su clave y verifica el correo.
- `ListBookingsByPassenger` consulta `aeroreserva_bookings.bookings_by_passenger`, incluyendo todas las páginas de Cassandra. No se usa `ALLOW FILTERING`.
- `GET /api/bookings` devuelve solo las reservas de la sesión y agrega los datos del vuelo.
- `POST /api/bookings` recibe `flight_number`.
- `DELETE /api/bookings` recibe `booking_code` y comprueba que la reserva pertenece al pasajero. Los UUID quedan dentro del BFF y de gRPC.
- `/api/passengers`: POST con `mode=login|register`, GET consulta el nombre identificado y DELETE cierra la sesión. `/pasajeros` redirige a `/ingresar`.
- Seed de nueve vuelos colombianos del 20 al 27 de octubre de 2026, insertados en `flights_by_id` y `flights_catalog`. `IF NOT EXISTS` conserva datos y cupos al repetir el inicializador. Las horas de la interfaz usan `America/Bogota`.

### Regenerar stubs Ruby

Si cambia el contrato, con los contenedores existentes, en PowerShell:

```powershell
docker cp proto/aeroreserva.proto aeroreserva-passenger-service:/tmp/aeroreserva.proto
docker exec aeroreserva-passenger-service bundle exec grpc_tools_ruby_protoc -I /tmp --ruby_out=/tmp --grpc_out=/tmp /tmp/aeroreserva.proto
foreach ($service in @('flight-service', 'passenger-service', 'booking-service')) {
  docker cp aeroreserva-passenger-service:/tmp/aeroreserva_pb.rb "services/$service/lib/aeroreserva_pb.rb"
  docker cp aeroreserva-passenger-service:/tmp/aeroreserva_services_pb.rb "services/$service/lib/aeroreserva_services_pb.rb"
}
```

### Prueba de navegador de extremo a extremo

```powershell
npm exec --yes --package=@playwright/test -- playwright --version
$env:TEST_BASE_URL = 'http://127.0.0.1:4321'
node tests/demo-flow.cjs <ruta-al-paquete-playwright>
```

Usa Microsoft Edge instalado, crea dos perfiles ficticios con documento único y deja canceladas sus reservas de prueba. Comprueba aislamiento entre pasajeros, cookie alterada, origen externo, filtros, cupos, reingreso y que no se vean UUID. No elimina datos. El argumento es la carpeta del paquete Playwright que npm instala temporalmente, no su ejecutable.

### Más documentación

- [docs/guia-aeroreserva.md](docs/guia-aeroreserva.md): guía de código, patrones y ejecución.
- [docs/01-definicion-aeroreserva.md](docs/01-definicion-aeroreserva.md): definición inicial del sistema.
- [docs/validacion-identificacion.md](docs/validacion-identificacion.md) y [docs/validacion-resiliencia.md](docs/validacion-resiliencia.md): resultados de validación.
- [docs/correcciones-documento-tecnico.md](docs/correcciones-documento-tecnico.md): correcciones pendientes del documento técnico en PDF.
