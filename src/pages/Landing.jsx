import { Link } from 'react-router-dom';
import { BellRing, BrainCircuit, History, Route, Smartphone, Wifi, Sprout } from 'lucide-react';

function Phone({ title, children }) {
  return (
    <figure className="phone">
      <div className="phone-bezel">
        <div className="phone-screen">
          <div className="phone-status">
            <img src="/logo.png" alt="" />
            <div>
              <strong>G.A.T.T.O.</strong>
              <span>Collegato · Casa</span>
            </div>
          </div>
          {children}
          <nav className="phone-tabs" aria-hidden="true">
            <span className={title === 'Home' ? 'on' : ''}>Home</span>
            <span className={title === 'Controllo' ? 'on' : ''}>Controllo</span>
            <span className={title === 'Archivio' ? 'on' : ''}>Archivio</span>
          </nav>
        </div>
      </div>
      <figcaption>{title}</figcaption>
    </figure>
  );
}

function Landing() {
  return (
    <div className="app">
      <nav className="nav">
        <a href="#inizio" className="brand">
          <img src="/logo.png" alt="" className="logo-nav" />
          <span className="brand-name">G.A.T.T.O.</span>
        </a>
        <div className="nav-links">
          <a href="#funzioni">Cosa fa</a>
          <a href="#avvio">Come si parte</a>
          <a href="#download" className="nav-cta">
            Scarica App
          </a>
        </div>
      </nav>

      <header className="hero" id="inizio">
        <div className="logo-hero-wrap">
          <img src="/logo.png" alt="G.A.T.T.O." className="logo-hero" />
        </div>
        <div className="badge">Cane robot per l'orto</div>
        <h1>
          Gestore Autonomo Tecnologico <span>Terreni Orti</span>
        </h1>
        <p className="hero-text">
          G.A.T.T.O. cammina tra vasi e aiuole, guarda ogni pianta, tiene luce, umidità del terreno e batteria sotto controllo e ti avvisa se qualcosa sta male. L’archivio confronta oggi con una settimana fa.
        </p>
        <div className="hero-actions">
          <a href="#download" className="analyze-btn">
            Scarica l'app
          </a>
        </div>
      </header>

      <section id="app" className="shots" aria-labelledby="shots-title">
        <div className="features-head">
          <p className="features-kicker">L'app</p>
          <h2 id="shots-title">Home, Controllo, Archivio</h2>
          <p className="features-lead">
            Così la vedi sul telefono: sensori veri, guida a mano e confronto delle piante nel tempo.
          </p>
        </div>
        <div className="phone-row">
          <Phone title="Home">
            <p className="ph-kicker">CASA</p>
            <p className="ph-title">Gatto è fermo</p>
            <div className="ph-banner">
              <span>Pattuglia</span>
              <strong>In attesa</strong>
            </div>
            <div className="ph-grid">
              <div>
                <small>Luce</small>
                <b>8 lx</b>
                <em>Buio</em>
              </div>
              <div>
                <small>Umidità</small>
                <b>9%</b>
                <em>Secco</em>
              </div>
              <div>
                <small>Batteria</small>
                <b>92%</b>
                <em>8,0 V · Carica</em>
              </div>
            </div>
          </Phone>
          <Phone title="Controllo">
            <div className="ph-modes">
              <span>Autonomo</span>
              <span className="on">Manuale</span>
            </div>
            <div className="ph-cam">Camera</div>
            <div className="ph-scan">Scansiona pianta</div>
            <div className="ph-pad">
              <i />
              <i className="key">▲</i>
              <i />
              <i className="key">◀</i>
              <i className="stop">■</i>
              <i className="key">▶</i>
              <i />
              <i className="key">▼</i>
              <i />
            </div>
          </Phone>
          <Phone title="Archivio">
            <p className="ph-kicker">ARCHIVIO</p>
            <p className="ph-title">Basilico</p>
            <p className="ph-trend">Meglio rispetto a 7 giorni fa</p>
            <div className="ph-compare">
              <div>
                <small>Oggi</small>
                <div className="ph-shot now">Sta bene</div>
              </div>
              <div>
                <small>7 giorni fa</small>
                <div className="ph-shot past">Attenzione</div>
              </div>
            </div>
          </Phone>
        </div>
      </section>

      <section id="avvio" className="steps" aria-labelledby="steps-title">
        <div className="features-head">
          <p className="features-kicker">Prima volta</p>
          <h2 id="steps-title">Come si parte</h2>
          <p className="features-lead">Tre passi. Poi telefono e Gatto restano sul Wi‑Fi di casa.</p>
        </div>
        <ol className="step-list">
          <li>
            <span className="step-icon" aria-hidden="true">
              <Sprout strokeWidth={1.75} />
            </span>
            <h3>Accendi Gatto</h3>
            <p>Aspetta che finisca di avviarsi. Compare la rete Wi‑Fi G.A.T.T.O.</p>
          </li>
          <li>
            <span className="step-icon" aria-hidden="true">
              <Wifi strokeWidth={1.75} />
            </span>
            <h3>Entra nella sua rete</h3>
            <p>
              Dal telefono scegli <strong>G.A.T.T.O.</strong>, password <strong>gatto2026</strong>, poi apri l’app.
            </p>
          </li>
          <li>
            <span className="step-icon" aria-hidden="true">
              <Smartphone strokeWidth={1.75} />
            </span>
            <h3>Scegli il Wi‑Fi di casa</h3>
            <p>L’app te lo chiede una volta sola. Da lì lo guidi, lo fai pattugliare e ricevi gli avvisi.</p>
          </li>
        </ol>
      </section>

      <section id="funzioni" className="features" aria-labelledby="features-title">
        <div className="features-head">
          <p className="features-kicker">Cosa fa oggi</p>
          <h2 id="features-title">Quello che è già pronto</h2>
          <p className="features-lead">
            Luce, umidità del terreno e batteria di Gatto sono vere. La temperatura arriva quando il sensore è collegato.
          </p>
        </div>
        <div className="features-grid">
          <article className="feature-card">
            <div className="feature-icon" aria-hidden="true">
              <Route strokeWidth={1.75} />
            </div>
            <h3>Pattuglia da solo</h3>
            <p>Cammina tra i vasi, evita gli ostacoli e può ripetere il percorso che gli insegni.</p>
          </article>
          <article className="feature-card">
            <div className="feature-icon" aria-hidden="true">
              <BrainCircuit strokeWidth={1.75} />
            </div>
            <h3>Diagnosi della pianta</h3>
            <p>Inquadra la foglia: l’IA dice se sta bene, se ha bisogno di te o se sta male, in poche righe.</p>
          </article>
          <article className="feature-card">
            <div className="feature-icon" aria-hidden="true">
              <BellRing strokeWidth={1.75} />
            </div>
            <h3>Avvisi quando serve</h3>
            <p>Notifica sul telefono anche a app chiusa, lontano da casa o se era spento: arriva appena c’è internet.</p>
          </article>
          <article className="feature-card">
            <div className="feature-icon" aria-hidden="true">
              <History strokeWidth={1.75} />
            </div>
            <h3>Confronto nel tempo</h3>
            <p>Stesso basilico, oggi e una settimana fa: foto, stato e se è migliorato o peggiorato.</p>
          </article>
        </div>
      </section>

      <section id="download" className="download">
        <div className="download-inner">
          <h2>Scarica l'app</h2>
          <p>Android, versione 1.1.13 · circa 51 MB. Non è sul Play Store: si installa dal file.</p>
          <div className="download-card">
            <div className="download-actions">
              <a className="store-btn android" href="/gatto.apk?v=21" download="gatto.apk">
                Scarica per Android
              </a>
              <button type="button" className="store-btn ios" disabled>
                iOS in arrivo
              </button>
            </div>
            <p className="install-help">
              Se il telefono blocca l’installazione: Impostazioni → consenti origini sconosciute per Chrome o File, poi apri
              <strong> gatto.apk</strong> e conferma.
            </p>
          </div>
        </div>
      </section>

      <footer className="site-foot">
        <div className="foot-inner">
          <p>G.A.T.T.O. · Lightfox</p>
          <div className="foot-links">
            <Link to="/privacy">Privacy</Link>
          </div>
        </div>
      </footer>
    </div>
  );
}

export default Landing;
