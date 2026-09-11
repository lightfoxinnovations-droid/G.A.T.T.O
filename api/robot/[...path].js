const DEFAULT_PUBLIC_URL = 'https://jackets-uses-reflected-dos.trycloudflare.com';

export default async function handler(req, res) {
  const base = (process.env.GATTO_PUBLIC_URL || DEFAULT_PUBLIC_URL).replace(/\/$/, '');
  const parts = req.query.path;
  const suffix = Array.isArray(parts) ? parts.join('/') : parts || 'status';
  const target = `${base}/api/${suffix}`;

  try {
    const response = await fetch(target, {
      method: req.method,
      headers: { Accept: 'application/json' },
    });
    const data = await response.json();
    res.status(response.status).json(data);
  } catch {
    res.status(502).json({
      status: 'error',
      message: 'G.A.T.T.O. non e raggiungibile dal cloud. Verifica che il robot sia acceso e in Wi-Fi.',
    });
  }
}
