const TARGET = 'https://solara.uonoe.com';

const CORS_HEADERS = {
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, Cookie',
  'Access-Control-Allow-Credentials': 'true',
};

function corsHeaders(origin) {
  return {
    ...CORS_HEADERS,
    'Access-Control-Allow-Origin': origin || '*',
  };
}

export async function onRequest(context) {
  const { request } = context;
  const url = new URL(request.url);
  const origin = request.headers.get('Origin') || '';

  if (request.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: corsHeaders(origin),
    });
  }

  const targetUrl = TARGET + url.pathname + url.search;

  const upstreamHeaders = new Headers(request.headers);
  upstreamHeaders.delete('Origin');
  upstreamHeaders.delete('Referer');
  upstreamHeaders.set('Host', 'solara.uonoe.com');

  const upstreamRequest = new Request(targetUrl, {
    method: request.method,
    headers: upstreamHeaders,
    body: ['GET', 'HEAD'].includes(request.method) ? undefined : request.body,
    redirect: 'manual',
  });

  const upstreamResponse = await fetch(upstreamRequest);

  const responseHeaders = new Headers(upstreamResponse.headers);
  const cors = corsHeaders(origin);
  for (const [k, v] of Object.entries(cors)) {
    responseHeaders.set(k, v);
  }
  responseHeaders.set('Access-Control-Expose-Headers', 'Set-Cookie');

  return new Response(upstreamResponse.body, {
    status: upstreamResponse.status,
    statusText: upstreamResponse.statusText,
    headers: responseHeaders,
  });
}
