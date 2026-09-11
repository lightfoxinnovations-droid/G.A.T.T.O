const STORAGE_KEY = 'gatto-robot-host';
const MODE_KEY = 'gatto-connect-mode';

export const LAN_HOST = '10.0.0.110:5000';
export const HOTSPOT_HOST = '192.168.4.1:5000';

export function isHttpsApp() {
  return typeof window !== 'undefined' && window.location.protocol === 'https:';
}

export function usesCloudLink() {
  return isHttpsApp();
}

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

export function getConnectMode() {
  return localStorage.getItem(MODE_KEY) || 'home';
}

export function setConnectMode(mode) {
  localStorage.setItem(MODE_KEY, mode);
}

export function isPaired() {
  return Boolean(getRobotHost());
}

export function markPaired(mode = 'home') {
  setConnectMode(mode);
  setRobotHost(usesCloudLink() ? 'cloud' : mode === 'hotspot' ? HOTSPOT_HOST : LAN_HOST);
}

export function apiUrl(path = '/status') {
  const clean = path.startsWith('/') ? path : `/${path}`;
  const suffix = clean.replace(/^\/api/, '') || '/status';
  if (usesCloudLink()) {
    return `/api/robot${suffix}`;
  }
  const host = getRobotHost() || LAN_HOST;
  if (host === 'cloud') {
    return `http://${LAN_HOST}/api${suffix}`;
  }
  return `http://${host}/api${suffix}`;
}

export async function testRobotConnection() {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 15000);
  try {
    const response = await fetch(apiUrl('/api/status'), { signal: controller.signal });
    const data = await response.json().catch(() => ({}));
    if (response.ok && data.status === 'success') {
      return {
        ok: true,
        message: 'G.A.T.T.O. è collegato.',
      };
    }
    return {
      ok: false,
      message: 'G.A.T.T.O. non risponde. Accendi il robot e riprova.',
    };
  } catch {
    return {
      ok: false,
      message: 'G.A.T.T.O. non risponde. Accendi il robot e riprova.',
    };
  } finally {
    clearTimeout(timer);
  }
}

export async function analyzePlant() {
  if (!isPaired()) throw new Error('Collega prima G.A.T.T.O. dalla sezione Wi-Fi.');
  const response = await fetch(apiUrl('/api/analyze'));
  const data = await response.json();
  if (data.status === 'success') return data.diagnosis;
  throw new Error(data.message || 'Analisi non riuscita');
}
