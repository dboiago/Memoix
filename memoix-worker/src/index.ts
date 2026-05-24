interface Env {
  AI: Ai;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_KEY: string;
  WORKER_SECRET: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const auth = request.headers.get('Authorization');
    if (auth !== `Bearer ${env.WORKER_SECRET}`) {
      return new Response('Unauthorized', { status: 401 });
    }

    const url = new URL(request.url);

    if (request.method === 'POST' && url.pathname === '/embed') {
      return handleEmbed(request, env);
    }

    if (request.method === 'POST' && url.pathname === '/pipeline') {
      return handlePipeline(request, env);
    }

    return new Response('Not found', { status: 404 });
  },
};

async function handleEmbed(request: Request, env: Env): Promise<Response> {
  const body = await request.json() as { text?: string };
  if (!body.text || typeof body.text !== 'string') {
    return new Response('Missing or invalid text field', { status: 400 });
  }

  const result = await env.AI.run('@cf/baai/bge-m3', { text: [body.text] });
  const embedding = (result as { data: number[][] }).data[0];

  return Response.json({ embedding });
}

async function handlePipeline(request: Request, env: Env): Promise<Response> {
  try {
    const row = await request.json() as {
      id: number;
      domain_type: string;
      payload: Record<string, unknown>;
    };

    if (!row.id || !row.domain_type || !row.payload) {
      return new Response('Missing required fields: id, domain_type, payload', { status: 400 });
    }

    const text = extractText(row.payload);
    if (!text) {
      return new Response('Could not extract text from payload', { status: 422 });
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
          telemetry_id: row.id,
          model: '@cf/baai/bge-m3',
          embedding: `[${embedding.join(',')}]`,
        }),
      }
    );

    if (!supabaseResponse.ok) {
      const error = await supabaseResponse.text();
      console.error('Supabase insert failed:', error);
      return new Response(`Supabase insert failed: ${error}`, { status: 500 });
    }

    return new Response('OK', { status: 200 });

  } catch (err) {
    console.error('Pipeline error:', String(err));
    return new Response(`Pipeline error: ${String(err)}`, { status: 500 });
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