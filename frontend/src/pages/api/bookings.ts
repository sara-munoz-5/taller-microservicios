import type { APIRoute } from "astro";
import * as grpc from "@grpc/grpc-js";
import * as protoLoader from "@grpc/proto-loader";
import path from "node:path";

export const prerender = false;

const protoPath = path.resolve(process.cwd(), "../proto/aeroreserva.proto");

const packageDefinition = protoLoader.loadSync(protoPath, {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true,
});

const proto = grpc.loadPackageDefinition(packageDefinition) as any;

const bookingClient = new proto.aeroreserva.v1.BookingService(
  process.env.BOOKING_SERVICE_URL || "localhost:50053",
  grpc.credentials.createInsecure()
);

function getBooking(id: string) {
  return new Promise<any>((resolve, reject) => {
    bookingClient.GetBooking(
      { id },
      (error: grpc.ServiceError | null, response: any) => {
        if (error) reject(error);
        else resolve(response);
      }
    );
  });
}

function listBookings() {
  return new Promise<any>((resolve, reject) => {
    bookingClient.ListBookings(
      {},
      (error: grpc.ServiceError | null, response: any) => {
        if (error) reject(error);
        else resolve(response);
      }
    );
  });
}

function createBooking(request: { passenger_id: string; flight_id: string }) {
  return new Promise<any>((resolve, reject) => {
    bookingClient.CreateBooking(
      request,
      (error: grpc.ServiceError | null, response: any) => {
        if (error) reject(error);
        else resolve(response);
      }
    );
  });
}

function cancelBooking(id: string) {
  return new Promise<any>((resolve, reject) => {
    bookingClient.CancelBooking(
      { id },
      (error: grpc.ServiceError | null, response: any) => {
        if (error) reject(error);
        else resolve(response);
      }
    );
  });
}

function errorResponse(status: number, message: string) {
  return new Response(JSON.stringify({ message }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function jsonResponse(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function handleGrpcError(error: unknown, fallbackMessage: string) {
  const grpcError = error as grpc.ServiceError;

  switch (grpcError.code) {
    case grpc.status.INVALID_ARGUMENT:
      return errorResponse(400, grpcError.details || "Datos de la reserva inválidos.");
    case grpc.status.NOT_FOUND:
      return errorResponse(404, grpcError.details || "Reserva no encontrada.");
    case grpc.status.FAILED_PRECONDITION:
      return errorResponse(409, grpcError.details || "La operación no se puede completar.");
    case grpc.status.UNAVAILABLE:
      return errorResponse(503, grpcError.details || "El servicio de reservas no respondió a tiempo.");
    default:
      console.error("Error inesperado de Booking Service:", error);
      return errorResponse(500, fallbackMessage);
  }
}

export const GET: APIRoute = async ({ url }) => {
  const id = url.searchParams.get("id");

  try {
    if (id) {
      const booking = await getBooking(id);
      return jsonResponse(200, booking);
    }

    const response = await listBookings();
    return jsonResponse(200, response.bookings);
  } catch (error) {
    return handleGrpcError(error, "No fue posible consultar las reservas.");
  }
};

export const POST: APIRoute = async ({ request }) => {
  const body = await request.json();

  try {
    const booking = await createBooking({
      passenger_id: body.passenger_id,
      flight_id: body.flight_id,
    });

    return jsonResponse(201, booking);
  } catch (error) {
    return handleGrpcError(error, "No fue posible crear la reserva.");
  }
};

export const DELETE: APIRoute = async ({ url, request }) => {
  let id = url.searchParams.get("id");

  if (!id) {
    try {
      const body = await request.json();
      id = body?.id ?? null;
    } catch {
      id = null;
    }
  }

  if (!id) {
    return errorResponse(400, "Debes indicar el id de la reserva a cancelar.");
  }

  try {
    const booking = await cancelBooking(id);
    return jsonResponse(200, booking);
  } catch (error) {
    return handleGrpcError(error, "No fue posible cancelar la reserva.");
  }
};
