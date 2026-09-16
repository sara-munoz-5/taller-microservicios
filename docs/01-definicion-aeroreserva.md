# AeroReserva – Definición inicial del sistema

## 1. Descripción del sistema

AeroReserva es una aplicación web simplificada que permite consultar vuelos disponibles, registrar pasajeros y crear o cancelar reservas.

Su propósito es demostrar una arquitectura basada en microservicios mediante el uso de Astro, Ruby on Rails, Cassandra, gRPC y Docker.

El sistema no pretende reproducir todas las operaciones de una aerolínea real. Se limita a un flujo de reservas básico, funcional y demostrable, con el fin de mantener un alcance viable para un equipo de tres integrantes.

---

## 2. Objetivo del caso práctico

Implementar un flujo completo de reserva aérea que permita consultar un vuelo, validar la existencia de un pasajero y la disponibilidad de cupos, crear una reserva y mostrar una confirmación.

También se incluirá la cancelación básica de una reserva, liberando el cupo asociado al vuelo.

---

## 3. Alcance funcional

El sistema permitirá:

* Consultar vuelos disponibles.
* Visualizar la información básica de un vuelo.
* Registrar un pasajero.
* Consultar un pasajero registrado.
* Crear una reserva para un pasajero en un vuelo con cupos disponibles.
* Consultar una reserva mediante su código.
* Cancelar una reserva existente.
* Liberar un cupo del vuelo cuando una reserva sea cancelada.
* Mostrar mensajes de confirmación o error al usuario.

---

## 4. Fuera de alcance

Para mantener un alcance viable, el sistema no incluirá:

* Pagos reales.
* Reembolsos.
* Selección de sillas.
* Check-in.
* Gestión de equipaje.
* Autenticación real de usuarios.
* Envío de correos reales.
* Gestión de pilotos o tripulación.
* Gestión de aeronaves y mantenimiento.
* Cambios de itinerario.
* Integración con aerolíneas externas.

---

## 5. Actores

### Usuario o pasajero

Es la persona que utiliza la aplicación web para consultar vuelos, registrarse, crear una reserva o cancelar una reserva existente.

---

## 6. Entidades de negocio

### Pasajero

Representa a la persona que realiza una reserva.

Atributos principales:

* Identificador del pasajero.
* Tipo de documento.
* Número de documento.
* Nombre completo.
* Correo electrónico.

### Vuelo

Representa un trayecto aéreo programado y ofrecido por la aerolínea.

Atributos principales:

* Identificador del vuelo.
* Número de vuelo.
* Ciudad de origen.
* Ciudad de destino.
* Fecha y hora de salida.
* Fecha y hora estimada de llegada.
* Capacidad total.
* Cupos disponibles.

### Reserva

Representa la relación entre un pasajero y un vuelo.

La reserva posee identidad, código, estado y fecha propios; por lo tanto, no es solamente una relación técnica entre dos entidades.

Atributos principales:

* Identificador de la reserva.
* Código único de reserva.
* Identificador del pasajero.
* Identificador del vuelo.
* Fecha y hora de creación.
* Estado: `CONFIRMED` o `CANCELLED`.

---

## 7. Microservicios

### 7.1. flight-service

**Responsabilidad:** administrar la información y disponibilidad de los vuelos.

Funciones principales:

* Consultar todos los vuelos disponibles.
* Consultar un vuelo por identificador.
* Validar que un vuelo exista.
* Validar que un vuelo tenga cupos disponibles.
* Ocupar un cupo cuando se confirme una reserva.
* Liberar un cupo cuando se cancele una reserva.

Datos propios:

* Vuelos.
* Capacidad total.
* Cupos disponibles.

### 7.2. passenger-service

**Responsabilidad:** administrar la información de los pasajeros.

Funciones principales:

* Registrar un pasajero.
* Consultar los pasajeros registrados.
* Consultar un pasajero por identificador.
* Validar la existencia de un pasajero.

Datos propios:

* Pasajeros.
* Datos de identificación.
* Datos de contacto.

### 7.3. booking-service

**Responsabilidad:** administrar las reservas y coordinar el flujo principal del sistema.

Funciones principales:

* Recibir una solicitud de reserva.
* Validar, por medio de gRPC, que el pasajero exista.
* Validar, por medio de gRPC, que el vuelo exista y tenga cupos.
* Solicitar a `flight-service` la ocupación de un cupo.
* Crear y consultar reservas.
* Cancelar una reserva.
* Solicitar a `flight-service` liberar un cupo al cancelar una reserva.
* Generar un código único de confirmación.

Datos propios:

* Reservas.
* Código de reserva.
* Estado de la reserva.
* Identificadores de pasajero y vuelo asociados.

---

## 8. Relación entre los microservicios

Cada microservicio tiene una responsabilidad y datos propios.

* `flight-service` no se comunica directamente con `passenger-service`.
* `passenger-service` no se comunica directamente con `flight-service`.
* `booking-service` coordina las validaciones necesarias para crear o cancelar una reserva.
* La comunicación interna se realiza mediante gRPC.

```text
booking-service
   ├── consulta a passenger-service
   └── consulta a flight-service
```

Esta separación evita que un único servicio tenga toda la lógica del sistema y permite que cada dominio evolucione de manera independiente.

---

## 9. Flujo principal: crear una reserva

1. El usuario ingresa a AeroReserva desde el navegador.
2. El usuario consulta los vuelos disponibles.
3. El frontend muestra la lista de vuelos.
4. El usuario registra o selecciona un pasajero.
5. El usuario selecciona un vuelo y solicita crear una reserva.
6. El frontend envía la solicitud a `booking-service`.
7. `booking-service` consulta mediante gRPC a `passenger-service` para validar que el pasajero exista.
8. `booking-service` consulta mediante gRPC a `flight-service` para validar que el vuelo exista y tenga cupos.
9. Si las validaciones son exitosas, `booking-service` solicita a `flight-service` ocupar un cupo.
10. `booking-service` guarda la reserva con estado `CONFIRMED`.
11. El sistema muestra el código de reserva y la confirmación al usuario.

---

## 10. Flujo secundario: cancelar una reserva

1. El usuario consulta una reserva mediante su código.
2. El usuario solicita cancelar la reserva.
3. El frontend envía la solicitud a `booking-service`.
4. `booking-service` valida que la reserva exista y esté en estado `CONFIRMED`.
5. `booking-service` solicita por gRPC a `flight-service` liberar un cupo.
6. `booking-service` cambia el estado de la reserva a `CANCELLED`.
7. El sistema muestra la confirmación de cancelación al usuario.

No se realizarán reembolsos ni modificaciones de pagos, debido a que estos procesos se encuentran fuera del alcance del proyecto.

---

## 11. Comunicación entre componentes

### Navegador y frontend

El usuario utilizará un navegador web para acceder a la interfaz desarrollada con Astro.

La comunicación entre el navegador y Astro se realizará mediante HTTP.

### Astro como BFF simplificado

Astro actuará como un Backend for Frontend o BFF simplificado.

Su función será recibir las solicitudes de la interfaz web y comunicarse con los microservicios sin exponer directamente la complejidad interna al navegador.

Astro no se considerará un API Gateway completo, ya que no será un componente independiente con políticas avanzadas de enrutamiento, seguridad o balanceo de carga.

### Comunicación interna

La comunicación entre Astro y los microservicios, así como entre `booking-service`, `flight-service` y `passenger-service`, se realizará mediante gRPC.

Los contratos de comunicación se definirán mediante archivos `.proto`.

---

## 12. Persistencia

Se utilizará una única instancia de Cassandra ejecutada dentro de Docker.

Para mantener la separación lógica de datos, cada microservicio contará con su propio keyspace:

* `aeroreserva_flights`
* `aeroreserva_passengers`
* `aeroreserva_bookings`

Un keyspace en Cassandra funciona como un espacio lógico para agrupar los datos de un servicio.

Esta decisión permite aislar los datos de cada microservicio sin aumentar innecesariamente la infraestructura del proyecto académico con tres instancias físicas de Cassandra.

---

## 13. Manejo básico de errores y validaciones

El sistema deberá validar e informar de forma clara cuando ocurra alguna de las siguientes situaciones:

* El pasajero no existe.
* El vuelo no existe.
* El vuelo no tiene cupos disponibles.
* La reserva no existe.
* La reserva ya fue cancelada.
* Se envían datos incompletos o inválidos.
* Un microservicio no responde dentro del tiempo esperado.
* Ocurre un error al guardar información en Cassandra.

Los servicios usarán tiempos de espera o *timeouts* en las comunicaciones gRPC para evitar que una solicitud quede esperando indefinidamente.

---

## 14. Tecnologías seleccionadas

| Componente           | Tecnología              | Propósito                                                              |
| -------------------- | ----------------------- | ---------------------------------------------------------------------- |
| Frontend             | Astro                   | Construir la interfaz web de AeroReserva.                              |
| Backend              | Ruby on Rails           | Implementar los microservicios de vuelos, pasajeros y reservas.        |
| Persistencia         | Cassandra               | Almacenar los datos de cada microservicio.                             |
| Comunicación interna | gRPC                    | Comunicar los microservicios mediante contratos definidos.             |
| Contenedores         | Docker y Docker Compose | Ejecutar el frontend, los servicios y Cassandra de forma reproducible. |
| Control de versiones | Git y GitHub            | Gestionar el código fuente, ramas, versiones y entrega final.          |

---

## 15. Decisiones arquitectónicas iniciales

* Se utilizará arquitectura de microservicios para separar los dominios de vuelos, pasajeros y reservas.
* Cada microservicio tendrá una responsabilidad concreta y datos propios.
* Se utilizará gRPC para la comunicación interna entre servicios.
* `booking-service` coordinará el proceso de crear y cancelar reservas.
* Se utilizará Astro para la interfaz web y como BFF simplificado.
* Se utilizará Ruby on Rails para implementar los servicios backend.
* Se utilizará Cassandra como motor de persistencia.
* Se utilizará una sola instancia de Cassandra, con keyspaces separados por microservicio.
* Se utilizará Docker Compose para levantar todos los componentes del sistema.
* El proyecto se limitará a reservas y cancelaciones básicas, sin pagos, reembolsos ni operaciones aéreas avanzadas.
