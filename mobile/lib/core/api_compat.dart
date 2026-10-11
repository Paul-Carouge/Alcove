/// API versions this build understands. Bump together with the OpenAPI spec.
const kClientApiRange = (min: 1, max: 1);

enum Compatibility { ok, clientTooOld, serverTooOld }

Compatibility checkCompatibility(
  ({int min, int max}) server, {
  ({int min, int max}) client = kClientApiRange,
}) {
  if (client.max < server.min) return Compatibility.clientTooOld;
  if (client.min > server.max) return Compatibility.serverTooOld;
  return Compatibility.ok;
}
