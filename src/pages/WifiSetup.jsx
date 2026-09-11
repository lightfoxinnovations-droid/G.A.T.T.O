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
      'Tieni il telefono sulla stessa Wi-Fi di casa del robot (LaserWiFi).',
      'Torna qui e premi Collega. L\'app trova il robot, anche se hai aperto il sito da Vercel.',
    ],
  },
  hotspot: {
    title: 'Hotspot (non attivo)',
    intro: 'In questo momento G.A.T.T.O. non crea una rete Wi-Fi propria. È collegato alla Wi-Fi di casa (LaserWiFi), così restano internet e l\'IA.',
    steps: [
      'Non troverai una rete chiamata G.A.T.T.O. nell\'elenco Wi-Fi del telefono.',
      'Il robot ha una sola antenna: se aprisse un hotspot, perderebbe la rete di casa e il cloud.',
      'Per usarlo ora, torna su "Già in casa", tieni il telefono sulla stessa Wi-Fi e premi Collega.',
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

      {mode === 'hotspot' && (
        <p className="wifi-warn">
          L'hotspot non è acceso di proposito: serve a non staccare G.A.T.T.O. da internet.
          Usa "Già in casa".
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
