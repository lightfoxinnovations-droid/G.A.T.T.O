import { useState } from 'react';
import { CheckCircle2, House, Smartphone, Wifi, WifiOff } from 'lucide-react';
import {
  getConnectMode,
  isHttpsApp,
  markPaired,
  setConnectMode,
  testRobotConnection,
} from '../lib/robot';

const TUTORIALS = {
  home: {
    title: 'G.A.T.T.O. è già in casa',
    intro: 'Usa questa modalità tutti i giorni. Il robot resta sulla Wi-Fi di casa: controllo e cloud (IA) funzionano insieme.',
    steps: [
      'Accendi G.A.T.T.O. e attendi che la spia di rete sia attiva.',
      'Tieni il telefono sulla Wi-Fi di casa (non sull\'hotspot del robot).',
      'Torna qui e premi Collega. L\'app trova il robot, anche se hai aperto il sito da Vercel.',
    ],
  },
  hotspot: {
    title: 'Prima configurazione (hotspot)',
    intro: 'Serve solo la prima volta, o se G.A.T.T.O. non e ancora sulla Wi-Fi di casa. In hotspot il telefono perde internet: il cloud si riaccende dopo.',
    steps: [
      'Accendi G.A.T.T.O. e aspetta la rete Wi-Fi chiamata G.A.T.T.O.',
      'Sul telefono: Impostazioni → Wi-Fi → entra nella rete G.A.T.T.O.',
      'Torna in questa app e premi Collega.',
      'Quando hai finito, riporta il robot e il telefono sulla Wi-Fi di casa. Cosi tornano IA e notifiche.',
    ],
  },
};

function WifiSetup({ onConnected }) {
  const [mode, setMode] = useState(getConnectMode());
  const [checking, setChecking] = useState(false);
  const [result, setResult] = useState(null);
  const cloud = isHttpsApp();
  const guide = TUTORIALS[mode];

  const connect = async (event) => {
    event.preventDefault();
    setChecking(true);
    setResult(null);
    setConnectMode(mode);
    const test = await testRobotConnection();
    setResult(test);
    setChecking(false);
    if (test.ok) {
      markPaired(mode);
      onConnected?.();
    }
  };

  return (
    <section className="mapp-panel wifi-panel">
      <p className="mapp-kicker">Tutorial di collegamento</p>
      <h1>Come collegarti a G.A.T.T.O.</h1>

      {cloud && (
        <article className="wifi-banner">
          Stai usando l'app online. Il telefono non deve entrare nell'hotspot:
          G.A.T.T.O. resta in casa, internet resta acceso e l'IA continua a funzionare.
        </article>
      )}

      <div className="wifi-modes">
        <button
          type="button"
          className={mode === 'home' ? 'active' : ''}
          onClick={() => {
            setMode('home');
            setResult(null);
          }}
        >
          <House size={16} />
          Già in casa
        </button>
        <button
          type="button"
          className={mode === 'hotspot' ? 'active' : ''}
          onClick={() => {
            setMode('hotspot');
            setResult(null);
          }}
        >
          <Smartphone size={16} />
          Hotspot
        </button>
      </div>

      <p className="wifi-intro">{guide.intro}</p>

      <ol className="wifi-steps">
        {guide.steps.map((step) => (
          <li key={step}>{step}</li>
        ))}
      </ol>

      {cloud && mode === 'hotspot' && (
        <p className="wifi-warn">
          Da Vercel l'hotspot non basta: il browser sicuro non puo parlare con una rete locale.
          Usa hotspot solo per configurare il robot, poi passa a "Già in casa".
        </p>
      )}

      <form className="wifi-form" onSubmit={connect}>
        <button type="submit" className="mapp-primary" disabled={checking}>
          {checking ? 'Verifica in corso...' : 'Collega G.A.T.T.O.'}
        </button>
      </form>

      {result && (
        <article className={`wifi-result ${result.ok ? 'ok' : 'err'}`}>
          {result.ok ? <CheckCircle2 size={18} /> : <WifiOff size={18} />}
          <p>{result.message}</p>
        </article>
      )}

      <p className="wifi-note">
        <Wifi size={14} />
        {cloud
          ? 'Canale: cloud HTTPS. G.A.T.T.O. deve essere acceso e connesso a internet.'
          : 'Canale: rete locale. Telefono e robot devono essere sulla stessa Wi-Fi.'}
      </p>
    </section>
  );
}

export default WifiSetup;
