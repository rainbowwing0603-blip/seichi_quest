import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-stamp-upload-token",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MAX_BYTES = 8 * 1024 * 1024;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function response(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function tokensMatch(supplied: string, expected: string): Promise<boolean> {
  const enc = new TextEncoder();
  const [a, b] = await Promise.all([
    crypto.subtle.digest("SHA-256", enc.encode(supplied)),
    crypto.subtle.digest("SHA-256", enc.encode(expected)),
  ]);
  const aa = new Uint8Array(a);
  const bb = new Uint8Array(b);
  let diff = 0;
  for (let i = 0; i < aa.length; i++) diff |= aa[i] ^ bb[i];
  return diff === 0 && supplied.length === expected.length;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return response({ error: "POST required" }, 405);

  const expectedToken = Deno.env.get("STAMP_UPLOAD_TOKEN");
  const productionKey = Deno.env.get("SUPABASE_PRODUCTION_SERVICE_ROLE_KEY");
  const testKey = Deno.env.get("SUPABASE_TEST_SERVICE_ROLE_KEY");
  if (!expectedToken) {
    return response({ error: "Upload service is not configured" }, 503);
  }

  const suppliedToken = req.headers.get("x-stamp-upload-token") ?? "";
  if (!(await tokensMatch(suppliedToken, expectedToken))) {
    return response({ error: "Unauthorized" }, 401);
  }

  const contentLength = Number(req.headers.get("content-length") ?? "0");
  if (contentLength > 12 * 1024 * 1024) {
    return response({ error: "Request body exceeds 12 MiB limit" }, 413);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return response({ error: "Expected JSON body" }, 400);
  }

  const eventContentId = payload.eventContentId;
  const imageBase64 = payload.imageBase64;
  const target = payload.target ?? "production";
  if (typeof eventContentId !== "string" || !UUID_RE.test(eventContentId)) {
    return response({ error: "eventContentId must be a UUID" }, 400);
  }
  if (typeof imageBase64 !== "string" || imageBase64.length === 0) {
    return response({ error: "imageBase64 is required" }, 400);
  }
  if (!["production", "test", "both"].includes(String(target))) {
    return response({ error: "target must be production, test, or both" }, 400);
  }

  let binary: Uint8Array;
  try {
    const clean = imageBase64.replace(/^data:image\/png;base64,/, "");
    const decoded = atob(clean);
    if (decoded.length > MAX_BYTES) return response({ error: "PNG exceeds 8 MiB limit" }, 413);
    binary = Uint8Array.from(decoded, (c) => c.charCodeAt(0));
  } catch {
    return response({ error: "imageBase64 is not valid base64" }, 400);
  }

  const pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (binary.length < 8 || !pngSignature.every((n, i) => binary[i] === n)) {
    return response({ error: "Image must be a PNG" }, 415);
  }

  const results: Array<{ target: string; ok: boolean; url?: string; error?: string }> = [];
  const projects = [
    { name: "production", url: "https://npirfaoxcarfuqjlwgav.supabase.co", key: productionKey },
    { name: "test", url: "https://wxlvhpmolrtcwryaazfb.supabase.co", key: testKey },
  ].filter((p) => target === "both" || target === p.name);

  const missingKey = projects.find((p) => !p.key);
  if (missingKey) {
    return response({ error: `Upload service is not configured for ${missingKey.name}` }, 503);
  }

  for (const project of projects) {
    const objectPath = `stamps/${eventContentId}.png`;
    try {
      const res = await fetch(`${project.url}/storage/v1/object/content-media/${objectPath}`, {
        method: "POST",
        headers: {
          apikey: project.key!,
          Authorization: `Bearer ${project.key!}`,
          "Content-Type": "image/png",
          "x-upsert": "true",
        },
        body: binary,
      });
      if (!res.ok) {
        results.push({ target: project.name, ok: false, error: `Storage returned HTTP ${res.status}` });
      } else {
        results.push({
          target: project.name,
          ok: true,
          url: `${project.url}/storage/v1/object/public/content-media/${objectPath}`,
        });
      }
    } catch {
      results.push({ target: project.name, ok: false, error: "Storage request failed" });
    }
  }

  const ok = results.every((r) => r.ok);
  return response({ ok, eventContentId, results }, ok ? 200 : 502);
});
