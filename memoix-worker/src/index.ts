interface Env {
  AI: Ai;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_KEY: string;
  WORKER_SECRET_APP?: string;
  WORKER_SECRET_APP_PREVIOUS?: string;
  WORKER_SECRET_PIPELINE?: string;
  WORKER_SECRET_PIPELINE_PREVIOUS?: string;
}

// The app sends one short search question; it has no length limit of its own.
const MAX_EMBED_TEXT_CHARS = 2_000;
const MAX_EMBED_BODY_BYTES = 16 * 1024;

// The request body is essentially the serialized payload, so this caps both.
const MAX_PIPELINE_BODY_BYTES = 256 * 1024;
const MAX_PIPELINE_TEXT_CHARS = 16_000;

// Values the app writes to rag_telemetry.domain_type.
const PIPELINE_DOMAIN_TYPES = new Set([
  'recipe',
  'modernist',
  'smoking',
  'pizza',
  'sandwich',
  'cellar',
  'cheese',
]);

const encoder = new TextEncoder();

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const { pathname } = new URL(request.url);

    if (pathname !== '/embed' && pathname !== '/pipeline') {
      return new Response('Not found', { status: 404 });
    }

    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405, headers: { Allow: 'POST' } });
    }

    if (pathname === '/embed') {
      if (!(await isAuthorized(request, [env.WORKER_SECRET_APP, env.WORKER_SECRET_APP_PREVIOUS]))) {
        return new Response('Unauthorized', { status: 401 });
      }
      return handleEmbed(request, env);
    }

    if (!(await isAuthorized(request, [env.WORKER_SECRET_PIPELINE, env.WORKER_SECRET_PIPELINE_PREVIOUS]))) {
      return new Response('Unauthorized', { status: 401 });
    }
    return handlePipeline(request, env);
  },
};

async function sha256(value: string): Promise<Uint8Array> {
  return new Uint8Array(await crypto.subtle.digest('SHA-256', encoder.encode(value)));
}

/** Fails closed when no secret is configured; compares digests so lengths match. */
async function isAuthorized(request: Request, secrets: Array<string | undefined>): Promise<boolean> {
  const configured = secrets.filter((s): s is string => typeof s === 'string' && s.length > 0);
  if (configured.length === 0) return false;

  const given = await sha256(request.headers.get('Authorization') ?? '');
  let authorized = false;
  for (const secret of configured) {
    const matches = crypto.subtle.timingSafeEqual(given, await sha256(`Bearer ${secret}`));
    authorized = authorized || matches;
  }
  return authorized;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/** Returns the parsed JSON body, or undefined when it is too large or not valid JSON. */
async function readJsonBody(request: Request, maxBytes: number): Promise<unknown> {
  if (Number(request.headers.get('Content-Length')) > maxBytes) return undefined;

  const reader = request.body?.getReader();
  if (!reader) return undefined;

  const chunks: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel();
      return undefined;
    }
    chunks.push(value);
  }

  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }

  try {
    return JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    return undefined;
  }
}

async function handleEmbed(request: Request, env: Env): Promise<Response> {
  try {
    const body = await readJsonBody(request, MAX_EMBED_BODY_BYTES);
    const text = isRecord(body) ? body.text : undefined;
    if (typeof text !== 'string' || text.trim().length === 0 || text.length > MAX_EMBED_TEXT_CHARS) {
      return new Response('Invalid request', { status: 400 });
    }

    const result = await env.AI.run('@cf/baai/bge-m3', { text: [text] });
    const embedding = (result as { data: number[][] }).data[0];

    return Response.json({ embedding });
  } catch (err) {
    console.error('Embed error:', String(err));
    return new Response('Internal error', { status: 500 });
  }
}

async function handlePipeline(request: Request, env: Env): Promise<Response> {
  try {
    const body = await readJsonBody(request, MAX_PIPELINE_BODY_BYTES);
    if (!isRecord(body)) {
      return new Response('Invalid request', { status: 400 });
    }

    const { id, domain_type, payload } = body;
    if (typeof id !== 'number' || !Number.isSafeInteger(id) || id <= 0) {
      return new Response('Invalid request', { status: 400 });
    }
    if (typeof domain_type !== 'string' || !PIPELINE_DOMAIN_TYPES.has(domain_type)) {
      return new Response('Invalid request', { status: 400 });
    }
    if (!isRecord(payload)) {
      return new Response('Invalid request', { status: 400 });
    }

    const text = extractText(payload);
    if (!text) {
      return new Response('Could not extract text from payload', { status: 422 });
    }
    if (text.length > MAX_PIPELINE_TEXT_CHARS) {
      return new Response('Invalid request', { status: 400 });
    }

    const result = await env.AI.run('@cf/baai/bge-m3', { text: [text] });
    const embedding = (result as { data: number[][] }).data[0];

    const supabaseResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/rag_embeddings`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_KEY,
          'Prefer': 'return=minimal',
          'Content-Profile': 'memoix',
        },
        body: JSON.stringify({
          telemetry_id: id,
          model: '@cf/baai/bge-m3',
          embedding: `[${embedding.join(',')}]`,
        }),
      }
    );

    if (!supabaseResponse.ok) {
      const error = await supabaseResponse.text();
      console.error('Supabase insert failed:', error);
      return new Response('Internal error', { status: 500 });
    }

    return new Response('OK', { status: 200 });

  } catch (err) {
    console.error('Pipeline error:', String(err));
    return new Response('Internal error', { status: 500 });
  }
}

function extractText(payload: Record<string, unknown>): string {
  const recipe = (payload.recipe ?? payload) as Record<string, unknown>;
  const parts: string[] = [];

  if (typeof recipe.name === 'string') parts.push(recipe.name);
  if (typeof recipe.course === 'string') parts.push(recipe.course);
  if (typeof recipe.cuisine === 'string') parts.push(recipe.cuisine);

  if (Array.isArray(recipe.tags)) {
    const tags = recipe.tags.filter((t): t is string => typeof t === 'string');
    if (tags.length) parts.push(tags.join(' '));
  }

  if (Array.isArray(recipe.ingredients)) {
    const names = recipe.ingredients
      .map((i: unknown) => (i as Record<string, unknown>)?.name)
      .filter((n): n is string => typeof n === 'string');
    if (names.length) parts.push(names.join(' '));
  }

  if (Array.isArray(recipe.directions)) {
    const steps = recipe.directions.filter((d): d is string => typeof d === 'string');
    if (steps.length) parts.push(steps.join(' '));
  }

  if (typeof recipe.comments === 'string') parts.push(recipe.comments);

  return parts.filter(Boolean).join('. ');
}