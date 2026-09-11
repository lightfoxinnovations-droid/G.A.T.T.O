import { useEffect, useState } from 'react';
import {
  ChevronUp,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  Gauge,
  History,
  Home,
  Leaf,
  Smartphone,
  Square,
  Sun,
  Droplets,
  Wifi,
} from 'lucide-react';
import { analyzePlant, getRobotHost, isPaired, usesCloudLink } from '../lib/robot';
import WifiSetup from './WifiSetup';

function MobileApp() {
  const [paired, setPaired] = useState(() => isPaired());
  const [tab, setTab] = useState(() => (isPaired() ? 'home' : 'wifi'));
  const [mode, setMode] = useState('autonomous');
  const [diagnosis, setDiagnosis] = useState('');
  const [loading, setLoading] = useState(false);
  const [iosTip, setIosTip] = useState(false);
  const [online, setOnline] = useState(false);
  const host = usesCloudLink() ? 'Cloud · casa' : getRobotHost();

  useEffect(() => {
    if (sessionStorage.getItem('gatto-ios-tip') === '1') {
      setIosTip(true);
      sessionStorage.removeItem('gatto-ios-tip');
    }
  }, []);

  const handleConnected = () => {
    setPaired(true);
    setOnline(true);
    setTab('home');
  };

  const runScan = async () => {
    setLoading(true);
    setDiagnosis('Scansione in corso...');
    try {
      const text = await analyzePlant();
      setDiagnosis(text);
      setOnline(true);
    } catch (error) {
      setDiagnosis(error.message);
      setOnline(false);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="mapp-shell">
      <div className="mapp">
        <header className="mapp-top">
          <div className="mapp-top-left">
            <img src="/logo.png" alt="" className="mapp-logo" />
            <div>
              <strong>G.A.T.T.O.</strong>
              <span>{host || 'Non collegato'}</span>
            </div>
          </div>
          <span className={`mapp-status ${online ? 'on' : 'off'}`}>
            {online ? 'In linea' : 'Offline'}
          </span>
        </header>

        <main className="mapp-body">
          {(!paired || tab === 'wifi') && (
            <WifiSetup onConnected={handleConnected} />
          )}

          {paired && tab === 'home' && (
            <section className="mapp-panel">
              <p className="mapp-kicker">Oggi</p>
              <h1>Il tuo orto è sotto controllo</h1>
              <div className="mapp-hero-card">
                <div>
                  <p>Pattugliamento</p>
                  <strong>Autonomo attivo</strong>
                </div>
                <Leaf size={28} />
              </div>
              <button type="button" className="mapp-primary" onClick={runScan} disabled={loading}>
                {loading ? 'Analisi in corso...' : 'Avvia scansione'}
              </button>
              {diagnosis && (
                <article className="mapp-card">
                  <h3>Ultima diagnosi</h3>
                  <p className="mapp-diagnosis">{diagnosis}</p>
                </article>
              )}
              <div className="mapp-stats">
                <article className="mapp-card">
                  <Droplets size={18} />
                  <span>Umidità</span>
                  <strong>68%</strong>
                </article>
                <article className="mapp-card">
                  <Sun size={18} />
                  <span>Luce</span>
                  <strong>840 lx</strong>
                </article>
              </div>
            </section>
          )}

          {paired && tab === 'sensors' && (
            <section className="mapp-panel">
              <p className="mapp-kicker">Telemetria</p>
              <h1>Sensori in tempo reale</h1>
              <div className="mapp-sensor-grid">
                <article className="mapp-card">
                  <span>Umidità terreno</span>
                  <strong>68%</strong>
                  <em className="ok">Ottimale</em>
                </article>
                <article className="mapp-card">
                  <span>Luce</span>
                  <strong>840 lx</strong>
                  <em className="warn">Soleggiato</em>
                </article>
                <article className="mapp-card">
                  <span>Temperatura</span>
                  <strong>23°C</strong>
                  <em className="ok">Stabile</em>
                </article>
                <article className="mapp-card">
                  <span>Batteria</span>
                  <strong>84%</strong>
                  <em className="ok">In carica solare</em>
                </article>
              </div>
            </section>
          )}

          {paired && tab === 'control' && (
            <section className="mapp-panel">
              <p className="mapp-kicker">Movimento</p>
              <h1>Gestione del robot</h1>
              <div className="mapp-mode">
                <button
                  type="button"
                  className={mode === 'autonomous' ? 'active' : ''}
                  onClick={() => setMode('autonomous')}
                >
                  Autonomo
                </button>
                <button
                  type="button"
                  className={mode === 'manual' ? 'active' : ''}
                  onClick={() => setMode('manual')}
                >
                  Manuale
                </button>
              </div>
              {mode === 'autonomous' ? (
                <article className="mapp-card">
                  <h3>Percorso in corso</h3>
                  <p>G.A.T.T.O. sta ispezionando i vasi del balcone. Nessun intervento richiesto.</p>
                </article>
              ) : (
                <div className="mapp-pad-wrap">
                  <p>Pilotaggio manuale</p>
                  <div className="mapp-pad">
                    <span />
                    <button type="button" aria-label="Avanti"><ChevronUp size={22} /></button>
                    <span />
                    <button type="button" aria-label="Sinistra"><ChevronLeft size={22} /></button>
                    <button type="button" className="stop" aria-label="Stop"><Square size={16} /></button>
                    <button type="button" aria-label="Destra"><ChevronRight size={22} /></button>
                    <span />
                    <button type="button" aria-label="Indietro"><ChevronDown size={22} /></button>
                    <span />
                  </div>
                </div>
              )}
            </section>
          )}

          {paired && tab === 'history' && (
            <section className="mapp-panel">
              <p className="mapp-kicker">Archivio</p>
              <h1>Storico ispezioni</h1>
              <article className="mapp-history">
                <div className="mapp-history-head">
                  <strong>Basilico · Vaso balcone</strong>
                  <span className="up">+15%</span>
                </div>
                <div className="mapp-compare">
                  <div>
                    <small>1 settembre</small>
                    <div className="shot past">Prima</div>
                  </div>
                  <div>
                    <small>Oggi</small>
                    <div className="shot now">Attuale</div>
                  </div>
                </div>
              </article>
            </section>
          )}
        </main>

        <nav className="mapp-tabs">
          <button type="button" className={tab === 'home' ? 'active' : ''} onClick={() => setTab('home')} disabled={!paired}>
            <Home size={18} />
            Home
          </button>
          <button type="button" className={tab === 'sensors' ? 'active' : ''} onClick={() => setTab('sensors')} disabled={!paired}>
            <Gauge size={18} />
            Sensori
          </button>
          <button type="button" className={tab === 'control' ? 'active' : ''} onClick={() => setTab('control')} disabled={!paired}>
            <Smartphone size={18} />
            Controllo
          </button>
          <button type="button" className={tab === 'history' ? 'active' : ''} onClick={() => setTab('history')} disabled={!paired}>
            <History size={18} />
            Storico
          </button>
          <button type="button" className={tab === 'wifi' ? 'active' : ''} onClick={() => setTab('wifi')}>
            <Wifi size={18} />
            Wi‑Fi
          </button>
        </nav>

        {iosTip && (
          <div className="mapp-tip">
            <p>
              Su iPhone: tocca Condividi e poi <strong>Aggiungi a Home</strong> per tenere solo l'app.
            </p>
            <button type="button" onClick={() => setIosTip(false)}>Ho capito</button>
          </div>
        )}
      </div>
    </div>
  );
}

export default MobileApp;
