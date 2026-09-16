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

const flightClient = new proto.aeroreserva.v1.FlightService(
  process.env.FLIGHT_SERVICE_URL || "localhost:50051",
  grpc.credentials.createInsecure()
);

function listFlights() {
  return new Promise<any>((resolve, reject) => {
    flightClient.ListFlights({}, (error: Error | null, response: any) => {
      if (error) reject(error);
      else resolve(response);
    });
  });
}

export const GET: APIRoute = async () => {
  try {
    const response = await listFlights();

    return new Response(JSON.stringify(response.flights), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("No fue posible consultar Flight Service:", error);

    return new Response(
      JSON.stringify({
        message: "No fue posible consultar el servicio de vuelos.",
      }),
      { status: 503, headers: { "Content-Type": "application/json" } }
    );
  }
};
