import { useState } from 'react';
import { Wifi, WifiOff } from 'lucide-react';
import {
  DEFAULT_HOST,
  getRobotHost,
  setRobotHost,
  testRobotConnection,
} from '../lib/robot';

function WifiSetup({ onConnected }) {
  const [host, setHost] = useState(getRobotHost() || DEFAULT_HOST);
  const [checking, setChecking] = useState(false);
  const [result, setResult] = useState(null);

  const connect = async (event) => {
    event.preventDefault();
    setChecking(true);
    setResult(null);
    const test = await testRobotConnection(host);
    setResult(test);
    setChecking(false);
    if (test.ok) {
      setRobotHost(host);
      onConnected?.(getRobotHost());
    }
  };

  const saveAnyway = () => {
    setRobotHost(host);
    onConnected?.(getRobotHost());
  };

  return (
    <section className="mapp-panel wifi-panel">
      <p className="mapp-kicker">Collegamento</p>
      <h1>Connetti G.A.T.T.O. in Wi‑Fi</h1>

      <ol className="wifi-steps">
        <li>Accendi il robot e attendi la rete Wi‑Fi.</li>
        <li>Sul telefono entra nella stessa rete di G.A.T.T.O. (casa o hotspot del robot).</li>
        <li>Inserisci l'indirizzo e verifica il collegamento.</li>
      </ol>

      <form className="wifi-form" onSubmit={connect}>
        <label htmlFor="gatto-host">Indirizzo di G.A.T.T.O.</label>
        <input
          id="gatto-host"
          type="text"
          inputMode="url"
          autoComplete="off"
          placeholder={DEFAULT_HOST}
          value={host}
          onChange={(event) => setHost(event.target.value)}
        />
        <button type="submit" className="mapp-primary" disabled={checking}>
          {checking ? 'Verifica in corso...' : 'Collega al robot'}
        </button>
      </form>

      {result && (
        <article className={`wifi-result ${result.ok ? 'ok' : 'err'}`}>
          {result.ok ? <Wifi size={18} /> : <WifiOff size={18} />}
          <p>{result.message}</p>
        </article>
      )}

      {result && !result.ok && (
        <button type="button" className="wifi-skip" onClick={saveAnyway}>
          Salva comunque e continua
        </button>
      )}
    </section>
  );
}

export default WifiSetup;
