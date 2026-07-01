const DOCUMENT_BUCKET = "load-documents";
const SIGNED_URL_EXPIRES_IN_SECONDS = 300;

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

type DocumentRow = {
  id: string;
  object_key: string | null;
  sync_state: string;
};

type RuntimeEnvironment = {
  supabaseUrl: string;
  publicKey: string;
  serviceRoleKey: string;
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const authorization = request.headers.get("authorization") ?? "";
  if (!authorization.toLowerCase().startsWith("bearer ")) {
    return json({ error: "missing_authorization" }, 401);
  }

  const documentId = documentIdFromPayload(await readJson(request));

  if (!isUuid(documentId)) {
    return json({ error: "invalid_document_id" }, 400);
  }

  const environment = readEnvironment();
  if (!environment) {
    return json({ error: "missing_function_configuration" }, 500);
  }

  const documentResult = await fetchDocument(environment, authorization, documentId);
  if (!documentResult.ok) {
    return documentResult.response;
  }

  const document = documentResult.document;
  if (!document.object_key || document.sync_state !== "synced") {
    return json({ error: "document_not_synced" }, 409);
  }

  const signResult = await signDocumentObject(environment, document.object_key);
  if (!signResult.ok) {
    return signResult.response;
  }

  return json({
    bucket: DOCUMENT_BUCKET,
    path: document.object_key,
    expiresIn: SIGNED_URL_EXPIRES_IN_SECONDS,
    signedUrl: signResult.signedUrl,
  });
});

async function readJson(request: Request): Promise<unknown> {
  try {
    return await request.json();
  } catch {
    return null;
  }
}

function documentIdFromPayload(payload: unknown): string {
  if (typeof payload !== "object" || payload === null || !("documentId" in payload)) {
    return "";
  }

  const documentId = (payload as { documentId?: unknown }).documentId;
  return typeof documentId === "string" ? documentId.trim() : "";
}

function readEnvironment(): RuntimeEnvironment | null {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const publicKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !publicKey || !serviceRoleKey) {
    return null;
  }

  return { supabaseUrl, publicKey, serviceRoleKey };
}

async function fetchDocument(
  environment: RuntimeEnvironment,
  authorization: string,
  documentId: string
): Promise<
  | { ok: true; document: DocumentRow }
  | { ok: false; response: Response }
> {
  const query = new URLSearchParams({
    select: "id,object_key,sync_state",
    id: `eq.${documentId}`,
    limit: "1",
  });

  const response = await fetch(`${environment.supabaseUrl}/rest/v1/documents?${query}`, {
    headers: {
      apikey: environment.publicKey,
      authorization,
      accept: "application/json",
    },
  });

  if (response.status === 401 || response.status === 403) {
    return { ok: false, response: json({ error: "unauthorized" }, 401) };
  }

  if (!response.ok) {
    return { ok: false, response: json({ error: "document_lookup_failed" }, 502) };
  }

  const rows = (await response.json()) as DocumentRow[];
  const document = rows[0];
  if (!document) {
    return { ok: false, response: json({ error: "document_not_found" }, 404) };
  }

  return { ok: true, document };
}

async function signDocumentObject(
  environment: RuntimeEnvironment,
  objectKey: string
): Promise<
  | { ok: true; signedUrl: string }
  | { ok: false; response: Response }
> {
  const objectPath = objectKey.split("/").map(encodeURIComponent).join("/");
  const response = await fetch(
    `${environment.supabaseUrl}/storage/v1/object/sign/${DOCUMENT_BUCKET}/${objectPath}`,
    {
      method: "POST",
      headers: {
        apikey: environment.serviceRoleKey,
        authorization: `Bearer ${environment.serviceRoleKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ expiresIn: SIGNED_URL_EXPIRES_IN_SECONDS }),
    }
  );

  const payload = (await response.json().catch(() => null)) as
    | { signedURL?: string; signedUrl?: string }
    | null;

  if (!response.ok) {
    return { ok: false, response: json({ error: "signed_url_failed" }, 502) };
  }

  const signedPath = payload?.signedURL ?? payload?.signedUrl;
  if (!signedPath) {
    return { ok: false, response: json({ error: "signed_url_missing" }, 502) };
  }

  const signedUrl = signedPath.startsWith("http")
    ? signedPath
    : `${environment.supabaseUrl}/storage/v1${signedPath.startsWith("/") ? "" : "/"}${signedPath}`;

  return { ok: true, signedUrl };
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json",
    },
  });
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}
