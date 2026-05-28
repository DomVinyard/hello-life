// Exercises all three bindings: KV, D1, R2.
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

    if (path === '/kv') {
      await env.KV.put('test-key', 'kv-value');
      const v = await env.KV.get('test-key');
      return Response.json({ binding: 'KV', value: v });
    }

    if (path === '/d1') {
      try {
        await env.DB.exec('CREATE TABLE IF NOT EXISTS t (k TEXT PRIMARY KEY, v TEXT)');
        await env.DB.prepare('INSERT OR REPLACE INTO t (k, v) VALUES (?, ?)').bind('key', 'd1-value').run();
        const { results } = await env.DB.prepare('SELECT v FROM t WHERE k = ?').bind('key').all();
        return Response.json({ binding: 'DB', value: results[0]?.v });
      } catch (e) {
        return Response.json({ binding: 'DB', error: e.message }, { status: 500 });
      }
    }

    if (path === '/r2') {
      await env.OBJECTS.put('hello.txt', 'r2-value');
      const obj = await env.OBJECTS.get('hello.txt');
      const text = obj ? await obj.text() : null;
      return Response.json({ binding: 'OBJECTS', value: text });
    }

    return Response.json({
      bindings: {
        KV: !!env.KV,
        DB: !!env.DB,
        OBJECTS: !!env.OBJECTS,
      },
      try: ['/kv', '/d1', '/r2'],
    });
  },
};
