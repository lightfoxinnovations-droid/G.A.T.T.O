import { Link } from 'react-router-dom';

function Privacy() {
  return (
    <div className="app legal">
      <nav className="nav">
        <Link to="/" className="brand">
          <img src="/logo.png" alt="" className="logo-nav" />
          <span className="brand-name">G.A.T.T.O.</span>
        </Link>
        <Link to="/" className="nav-cta">
          Torna al sito
        </Link>
      </nav>
      <article className="legal-body">
        <p className="features-kicker">Privacy</p>
        <h1>Come trattiamo i dati</h1>
        <p>
          Il sito serve solo a presentare G.A.T.T.O. e a scaricare l’app. Non chiediamo un account e non teniamo un database di utenti.
        </p>
        <h2>App e robot</h2>
        <p>
          L’app parla con il robot sulla tua rete di casa. Comandi, camera e sensori restano in locale, su Gatto.
        </p>
        <h2>Diagnosi delle piante</h2>
        <p>
          Quando chiedi un’analisi, la foto della pianta viene inviata a un servizio di intelligenza artificiale per la diagnosi. Non usiamo quelle foto per altro.
        </p>
        <h2>Notifiche a distanza</h2>
        <p>
          Se sei lontano da casa, l’avviso passa da un canale di notifica su internet, così arriva anche a telefono spento o fuori rete. Il canale è del tuo Gatto, non è una chat pubblica.
        </p>
        <h2>Sito</h2>
        <p>
          L’hosting può registrare accessi tecnici (indirizzo, browser) come ogni sito. Non usiamo pubblicità né tracker di terze parti.
        </p>
      </article>
    </div>
  );
}

export default Privacy;
