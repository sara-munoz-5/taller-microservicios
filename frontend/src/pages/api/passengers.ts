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

const passengerClient = new proto.aeroreserva.v1.PassengerService(
  process.env.PASSENGER_SERVICE_URL || "localhost:50052",
  grpc.credentials.createInsecure()
);

function createPassenger(request: {
  document_type: string;
  document_number: string;
  full_name: string;
  email: string;
}) {
  return new Promise<any>((resolve, reject) => {
    passengerClient.CreatePassenger(
      request,
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

export const POST: APIRoute = async ({ request }) => {
  const body = await request.json();

  try {
    const passenger = await createPassenger({
      document_type: body.document_type,
      document_number: body.document_number,
      full_name: body.full_name,
      email: body.email,
    });

    return new Response(JSON.stringify(passenger), {
      status: 201,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    const grpcError = error as grpc.ServiceError;

    if (grpcError.code === grpc.status.INVALID_ARGUMENT) {
      return errorResponse(400, grpcError.details || "Datos de pasajero inválidos.");
    }

    if (grpcError.code === grpc.status.ALREADY_EXISTS) {
      return errorResponse(409, grpcError.details || "Ya existe un pasajero con ese documento.");
    }

    console.error("No fue posible consultar Passenger Service:", error);

    return errorResponse(500, "No fue posible registrar el pasajero.");
  }
};
