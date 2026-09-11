import { BellRing, BrainCircuit, History, Route } from 'lucide-react';

function Landing() {
  return (
    <div className="app">
      <nav className="nav">
        <div className="brand">
          <img src="/logo.png" alt="" className="logo-nav" />
          <span className="brand-name">G.A.T.T.O.</span>
        </div>
        <a href="#download" className="nav-cta">
          Scarica App
        </a>
      </nav>

      <header className="hero">
        <div className="logo-hero-wrap">
          <img src="/logo.png" alt="G.A.T.T.O." className="logo-hero" />
        </div>
        <div className="badge">Il futuro dell'orto intelligente</div>
        <h1>
          Gestore Autonomo Tecnologico <span>Terreni Orti</span>
        </h1>
        <p className="hero-text">
          G.A.T.T.O. pattuglia il tuo giardino o balcone in piena autonomia, analizza la salute delle tue piante sfruttando l'intelligenza artificiale e protegge il tuo verde avvisandoti solo quando serve.
        </p>
        <a href="#download" className="analyze-btn" style={{ display: 'inline-block', textDecoration: 'none' }}>
          Scarica l'app
        </a>
      </header>

      <section className="features" aria-labelledby="features-title">
        <div className="features-head">
          <p className="features-kicker">Funzionalità</p>
          <h2 id="features-title">Progettato per curare l'orto al posto tuo</h2>
          <p className="features-lead">
            Quattro strumenti pensati per chi vuole piante sane, senza controllarle ogni giorno.
          </p>
        </div>
        <div className="features-grid">
          <article className="feature-card">
            <div className="feature-icon" aria-hidden="true">
              <Route strokeWidth={1.75} />
            </div>
            <h3>Pattugliamento autonomo</h3>
            <p>
              Si muove da solo tra vasi e aiuole, in giardino o sul balcone, e ispeziona ogni pianta senza supervisione.
            </p>
          </article>
          <article className="feature-card">
            <div className="feature-icon" aria-hidden="true">
              <BrainCircuit strokeWidth={1.75} />
            </div>
            <h3>Diagnosi con intelligenza artificiale</h3>
            <p>
              Rileva malattie, foglie ingiallite e stress idrico, poi suggerisce l'intervento più adatto in tempo reale.
            </p>
          </article>
          <article className="feature-card">
            <div className="feature-icon" aria-hidden="true">
              <BellRing strokeWidth={1.75} />
            </div>
            <h3>Notifiche puntuali</h3>
            <p>
              Ricevi un avviso sull'app solo quando una pianta richiede attenzione, senza messaggi superflui.
            </p>
          </article>
          <article className="feature-card">
            <div className="feature-icon" aria-hidden="true">
              <History strokeWidth={1.75} />
            </div>
            <h3>Storico delle ispezioni</h3>
            <p>
              Ogni controllo resta registrato: confronti l'andamento nel tempo e intervieni con dati, non a sensazione.
            </p>
          </article>
        </div>
      </section>

      <section id="download" className="download">
        <div className="download-inner">
          <h2>Porta G.A.T.T.O. sul tuo smartphone</h2>
          <p>
            Scarica l'app, entra nella rete G.A.T.T.O. e scegli la Wi-Fi di casa. La procedura è guidata, passo dopo passo.
          </p>
          <div className="download-actions">
            <a className="store-btn android" href="/gatto.apk" download>
              Scarica per Android
            </a>
            <button type="button" className="store-btn ios" disabled>
              iOS in arrivo
            </button>
          </div>
        </div>
      </section>
    </div>
  );
}

export default Landing;
