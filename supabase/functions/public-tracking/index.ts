const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "GET, OPTIONS",
};

type RuntimeEnvironment = {
  supabaseUrl: string;
  serviceRoleKey: string;
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "GET") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const token = new URL(request.url).searchParams.get("token")?.trim() ?? "";
  if (!isPlausibleShareToken(token)) {
    return accessDenied();
  }

  const environment = readEnvironment();
  if (!environment) {
    return json({ error: "missing_function_configuration" }, 500);
  }

  const trackingResult = await readPublicTrackingShare(environment, token);
  if (!trackingResult.ok) {
    return trackingResult.response;
  }

  if (!trackingResult.payload) {
    return accessDenied();
  }

  return json(trackingResult.payload, 200, {
    "cache-control": "no-store",
  });
});

function readEnvironment(): RuntimeEnvironment | null {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = readDefaultKey(
    "SUPABASE_SECRET_KEYS",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY")
  );

  if (!supabaseUrl || !serviceRoleKey) {
    return null;
  }

  return { supabaseUrl, serviceRoleKey };
}

function readDefaultKey(jsonDictionaryName: string, fallback: string | undefined): string | undefined {
  if (fallback?.trim()) {
    return fallback.trim();
  }

  const dictionary = Deno.env.get(jsonDictionaryName);
  if (!dictionary) {
    return undefined;
  }

  try {
    const parsed = JSON.parse(dictionary) as Record<string, unknown>;
    const defaultKey = parsed.default;
    return typeof defaultKey === "string" && defaultKey.trim() ? defaultKey.trim() : undefined;
  } catch {
    return undefined;
  }
}

async function readPublicTrackingShare(
  environment: RuntimeEnvironment,
  token: string
): Promise<
  | { ok: true; payload: Record<string, unknown> | null }
  | { ok: false; response: Response }
> {
  const response = await fetch(`${environment.supabaseUrl}/rest/v1/rpc/read_public_tracking_share`, {
    method: "POST",
    headers: {
      apikey: environment.serviceRoleKey,
      authorization: `Bearer ${environment.serviceRoleKey}`,
      "content-type": "application/json",
      accept: "application/json",
    },
    body: JSON.stringify({ p_token: token }),
  });

  if (!response.ok) {
    return { ok: false, response: json({ error: "tracking_lookup_failed" }, 502) };
  }

  const payload = (await response.json().catch(() => null)) as Record<string, unknown> | null;
  return { ok: true, payload };
}

function accessDenied(): Response {
  return json(
    { error: "tracking_link_unavailable" },
    404,
    { "cache-control": "no-store" }
  );
}

function json(
  body: Record<string, unknown>,
  status = 200,
  extraHeaders: Record<string, string> = {}
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      ...extraHeaders,
      "content-type": "application/json",
    },
  });
}

function isPlausibleShareToken(value: string): boolean {
  return /^[A-Za-z0-9_-]{32,256}$/.test(value);
}
