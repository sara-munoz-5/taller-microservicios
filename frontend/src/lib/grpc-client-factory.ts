import * as grpc from '@grpc/grpc-js';

// Factory: builds one gRPC client per microservice from the loaded proto package.
// Each address comes from <NAME>_SERVICE_URL (set by Docker Compose) and falls
// back to localhost:50051/50052/50053 for local development.
export function createGrpcClients(proto: any): Record<string, any> {
  return Object.fromEntries(['Flight', 'Passenger', 'Booking'].map((name, index) => [name, new proto[`${name}Service`](process.env[`${name.toUpperCase()}_SERVICE_URL`] || `localhost:${50051 + index}`, grpc.credentials.createInsecure())]));
}
