export default {
  async fetch(request) {
    return new Response(JSON.stringify({
      life: '0.1',
      name: 'hello',
      status: 'alive',
      timestamp: new Date().toISOString(),
    }), {
      headers: { 'Content-Type': 'application/json' },
    });
  },
};
