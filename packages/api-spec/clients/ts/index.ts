import createClient from "openapi-fetch";
import type { components, paths } from "./schema";

export type { components, paths };
export type Health = components["schemas"]["Health"];
export type Module = components["schemas"]["Module"];

/** API versions this build of the client understands. Bump with the spec. */
export const CLIENT_API_RANGE = { min: 1, max: 1 } as const;

export function createApiClient(baseUrl: string, fetchImpl?: typeof fetch) {
  return createClient<paths>({ baseUrl, fetch: fetchImpl });
}

export type Compatibility = "ok" | "client-too-old" | "server-too-old";

/** Overlap check between the server's [min, max] and ours. */
export function checkCompatibility(
  server: { min: number; max: number },
  client: { min: number; max: number } = CLIENT_API_RANGE,
): Compatibility {
  if (client.max < server.min) return "client-too-old";
  if (client.min > server.max) return "server-too-old";
  return "ok";
}
