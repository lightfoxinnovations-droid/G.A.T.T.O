const STORAGE_KEY = 'gatto-robot-host';
export const DEFAULT_HOST = '10.0.0.110:5000';

export function cleanHost(value) {
  return String(value || '')
    .trim()
    .replace(/^https?:\/\//i, '')
    .replace(/\/+$/, '');
}

export function getRobotHost() {
  return cleanHost(localStorage.getItem(STORAGE_KEY) || '');
}

export function setRobotHost(host) {
  const value = cleanHost(host);
  if (value) localStorage.setItem(STORAGE_KEY, value);
  else localStorage.removeItem(STORAGE_KEY);
  return value;
}

export function isPaired() {
  return Boolean(getRobotHost());
}

export function robotUrl(path = '/') {
  const host = getRobotHost();
  if (!host) return '';
  return `http://${host}${path.startsWith('/') ? path : `/${path}`}`;
}

export async function testRobotConnection(host = getRobotHost()) {
  const clean = cleanHost(host);
  if (!clean) return { ok: false, message: "Inserisci l'indirizzo di G.A.T.T.O." };

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 5000);
  const endpoints = ['/api/status', '/api/health', '/api/analyze'];

  try {
    for (const path of endpoints) {
      try {
        const response = await fetch(`http://${clean}${path}`, {
          signal: controller.signal,
        });
        if (response.ok || response.status < 500) {
          return { ok: true, message: `Collegato a ${clean}` };
        }
      } catch {
        // prova l'endpoint successivo
      }
    }
    return {
      ok: false,
      message: 'G.A.T.T.O. non risponde. Verifica il Wi‑Fi e l’indirizzo.',
    };
  } catch (error) {
    if (error.name === 'AbortError') {
      return { ok: false, message: 'Tempo scaduto. Sei sulla stessa rete Wi‑Fi?' };
    }
    return { ok: false, message: error.message || 'Collegamento non riuscito.' };
  } finally {
    clearTimeout(timer);
  }
}

export async function analyzePlant() {
  const host = getRobotHost();
  if (!host) throw new Error('Collega prima G.A.T.T.O. dalla sezione Wi‑Fi.');
  const response = await fetch(robotUrl('/api/analyze'));
  const data = await response.json();
  if (data.status === 'success') return data.diagnosis;
  throw new Error(data.message || 'Analisi non riuscita');
}
