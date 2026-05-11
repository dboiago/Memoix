import "@supabase/functions-js/edge-runtime.d.ts"

const WORKER_URL = Deno.env.get('CLOUDFLARE_WORKER_URL')!
const WORKER_SECRET = Deno.env.get('CLOUDFLARE_WORKER_SECRET')!

Deno.serve(async (req) => {
  try {
    const payload = await req.json()

    const record = payload.record as {
      id: number
      domain_type: string
      payload: Record<string, unknown>
    }

    if (!record?.id || !record?.domain_type || !record?.payload) {
      return new Response('Missing required fields', { status: 400 })
    }

    const response = await fetch(`${WORKER_URL}/pipeline`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${WORKER_SECRET}`,
      },
      body: JSON.stringify({
        id: record.id,
        domain_type: record.domain_type,
        payload: record.payload,
      }),
    })

    if (!response.ok) {
      const error = await response.text()
      console.error(`Worker pipeline failed: ${error}`)
      return new Response(`Worker error: ${error}`, { status: 500 })
    }

    return new Response('OK', { status: 200 })

  } catch (err) {
    console.error('Edge function error:', err)
    return new Response('Internal error', { status: 500 })
  }
})