export default {
  async fetch(request, env) {
    return new Response(JSON.stringify({
      app: 'api',
      has_db: !!env.DATABASE_URL,
      has_key: !!env.API_KEY,
    }), {
      headers: { 'Content-Type': 'application/json' },
    });
  },
};
