import { useEffect, useReducer, useRef, useState } from "react";
import { Link, Router, useLocation } from "./router";
import { CONTACT_EMAIL, PLAY_URL } from "./i18n";
import { useLang } from "./lang";
import { applySeo } from "./seo";
import networkHero from "./assets/network-hero.webp";
import networkHeroDark from "./assets/network-hero-dark.webp";
import { useTheme } from "./theme";
import Demo from "./demo/Demo";
import { initialState, reduce } from "./demo/flow";
import Features from "./Features";
import "./styles.css";

// Fade sections in as they scroll into view. Anything marked data-reveal
// starts hidden only once this has run, so nothing stays invisible without it.
function useReveal(deps) {
  useEffect(() => {
    const els = [...document.querySelectorAll("[data-reveal]:not(.is-in)")];
    if (!("IntersectionObserver" in window)) return els.forEach((el) => el.classList.add("is-in"));
    const io = new IntersectionObserver(
      (entries) =>
        entries.forEach((e) => {
          if (e.isIntersecting) {
            e.target.classList.add("is-in");
            io.unobserve(e.target);
          }
        }),
      { rootMargin: "0px 0px -8% 0px" },
    );
    els.forEach((el) => {
      el.classList.add("will-reveal");
      io.observe(el);
    });
    return () => io.disconnect();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);
}

function Page({ children }) {
  const { lang, t } = useLang();
  const { pathname, hash } = useLocation();
  useEffect(() => {
    document.documentElement.lang = lang;
    document.documentElement.dir = t.dir;
  }, [lang, t.dir]);
  const onFeatures = pathname.endsWith("/features");
  useEffect(() => {
    applySeo(lang, onFeatures ? "features" : "home");
  }, [lang, onFeatures]);
  useEffect(() => {
    if (hash) document.getElementById(hash.slice(1))?.scrollIntoView();
    else window.scrollTo(0, 0);
  }, [pathname, hash]);
  useReveal([pathname]);
  return (
    <div className={`site lang-${lang}`}>
      <Nav />
      <main>{children}</main>
      <Footer />
    </div>
  );
}

function Nav() {
  const { lang, t, base } = useLang();
  const { pathname, hash } = useLocation();
  // The menu belongs to the page it was opened on: following a link closes it.
  const here = pathname + hash;
  const [openOn, setOpenOn] = useState(null);
  const menuBtn = useRef(null);
  const open = openOn === here;
  const setOpen = (v) => setOpenOn(v ? here : null);
  const { theme, toggle } = useTheme();
  const other = lang === "ar" ? pathname.replace(/^\/ar/, "") || "/" : `/ar${pathname === "/" ? "" : pathname}`;
  useEffect(() => {
    if (!open) return;
    const esc = (e) => {
      if (e.key !== "Escape") return;
      setOpenOn(null);
      menuBtn.current?.focus();
    };
    window.addEventListener("keydown", esc);
    return () => window.removeEventListener("keydown", esc);
  }, [open]);
  const links = (
    <>
      <Link to={`${base}/features`}>{t.nav.features}</Link>
      <Link to={`${base || "/"}#how`}>{t.nav.how}</Link>
      <Link to={`${base || "/"}#contact`}>{t.nav.contact}</Link>
    </>
  );
  return (
    <header className={`nav ${open ? "is-open" : ""}`}>
      <div className="wrap nav-inner">
        <Link to={base || "/"} className="brand" aria-label="Guidy">
          <img className="logo-l" src="/logo-horizontal.svg" alt="" width="105" height="36" />
          <img className="logo-d" src="/logo-horizontal-white.svg" alt="" width="105" height="36" />
        </Link>
        <nav className="nav-links">{links}</nav>
        <div className="nav-end">
          <Link to={other} className="lang-switch" lang={lang === "ar" ? "en" : "ar"}>
            {t.switchLabel}
          </Link>
          <button type="button" className="icon-btn theme-btn" onClick={toggle} aria-label={theme === "dark" ? t.nav.toLight : t.nav.toDark} title={theme === "dark" ? t.nav.toLight : t.nav.toDark}>
            <svg className="i-moon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M20 14.5A8.5 8.5 0 0 1 9.5 4a8.5 8.5 0 1 0 10.5 10.5z" /></svg>
            <svg className="i-sun" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="4" /><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" /></svg>
          </button>
          <Link to={`${base || "/"}#get`} className="btn btn-small">
            {t.nav.get}
          </Link>
          <button
            ref={menuBtn}
            type="button"
            className="menu-btn"
            aria-expanded={open}
            aria-controls="mobile-menu"
            aria-label={t.nav.menu}
            onClick={() => setOpen(!open)}
          >
            <span />
            <span />
            <span />
          </button>
        </div>
      </div>
      {/* A link to the section already showing doesn't change the URL, so close the menu by hand. */}
      <nav className="mobile-menu" id="mobile-menu" hidden={!open} onClick={(e) => e.target.closest("a") && setOpenOn(null)}>
        <div className="wrap">
          {links}
          <Link to={`${base || "/"}#get`} className="btn">{t.nav.get}</Link>
        </div>
      </nav>
    </header>
  );
}

// Counts up to a number like "593" or "٣٬٢٨٠" the first time it is seen.
function CountUp({ value, lang }) {
  const ref = useRef(null);
  const target = Number(value.replace(/[٠-٩]/g, (c) => c.charCodeAt(0) - 0x660).replace(/[,٬]/g, ""));
  const format = (n) => n.toLocaleString(lang === "ar" ? "ar-EG" : "en-US");
  const [shown, setShown] = useState(value);
  useEffect(() => {
    const el = ref.current;
    if (!el || !("IntersectionObserver" in window) || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    let raf;
    const io = new IntersectionObserver(([e]) => {
      if (!e.isIntersecting) return;
      io.disconnect();
      const start = performance.now();
      const tick = (now) => {
        const k = Math.min((now - start) / 1400, 1);
        setShown(format(Math.round(target * (1 - Math.pow(1 - k, 3)))));
        if (k < 1) raf = requestAnimationFrame(tick);
      };
      raf = requestAnimationFrame(tick);
    });
    io.observe(el);
    return () => {
      io.disconnect();
      cancelAnimationFrame(raf);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [value]);
  // aria-label is ignored on a plain span: screen readers get the final
  // number as text, and never the digits rolling up.
  return (
    <>
      <span ref={ref} aria-hidden="true">{shown}</span>
      <span className="sr-only">{value}</span>
    </>
  );
}

function Footer() {
  const { t, base } = useLang();
  return (
    <footer className="footer">
      <div className="wrap footer-inner">
        <span className="brand">
          {/* The footer is dark in both themes. */}
          <img src="/logo-horizontal-white.svg" alt="Guidy" width="93" height="32" loading="lazy" />
        </span>
        <nav>
          <Link to={`${base}/features`}>{t.nav.features}</Link>
          {/* Plain links: these are separate static pages, not part of this app. */}
          <a href={t.legal.privacy}>{t.footer.privacy}</a>
          <a href={t.legal.terms}>{t.footer.terms}</a>
          <a href={t.legal.deletion}>{t.footer.deletion}</a>
          <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a>
        </nav>
        <small>© {new Date().getFullYear()} {t.footer.rights}</small>
      </div>
    </footer>
  );
}

// "How it works" step -> what the demo shows for it.
const HOW_DEMO = [
  [{ type: "scene", scene: "trip" }],
  [{ type: "scene", scene: "trip" }, { type: "pick", trip: 0 }],
  [{ type: "scene", scene: "trip" }, { type: "pick", trip: 0 }, { type: "start" }],
];

function Home() {
  const { lang, t, base } = useLang();
  const [demo, dispatch] = useReducer(reduce, initialState);
  const showInDemo = (i) => {
    HOW_DEMO[i].forEach((a) => dispatch({ ...a, user: true }));
    const still = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
    document.getElementById("demo")?.scrollIntoView({ behavior: still ? "auto" : "smooth", block: "center" });
    // After React has drawn the screen asked for: its stage takes the focus.
    setTimeout(() => document.querySelector("#demo .d-stage")?.focus({ preventScroll: true }), 0);
  };
  return (
    <Page>
      <section className="hero">
        <div className="hero-map" aria-hidden="true" style={{ "--map-light": `url(${networkHero})`, "--map-dark": `url(${networkHeroDark})` }} />
        <div className="wrap hero-grid">
          <div className="hero-copy">
            <p className="eyebrow">{t.hero.eyebrow}</p>
            <h1>{t.hero.title}</h1>
            <p className="lead">{t.hero.lead}</p>
            <div className="actions">
              <Link to={`${base || "/"}#get`} className="btn">{t.hero.primary}</Link>
              <Link to={`${base || "/"}#how`} className="btn btn-ghost">{t.hero.secondary}</Link>
            </div>
            <ul className="hero-points">
              {t.hero.points.map((p) => (
                <li key={p}>{p}</li>
              ))}
            </ul>
          </div>
          <Demo state={demo} dispatch={dispatch} lang={lang} t={t} />
        </div>
      </section>

      <section className="numbers">
        <div className="wrap" data-reveal>
          <h2 className="h-small">{t.numbers.title}</h2>
          <dl className="number-row">
            {t.numbers.items.map(([n, label]) => (
              <div key={label}>
                <dt><CountUp value={n} lang={lang} /></dt>
                <dd>{label}</dd>
              </div>
            ))}
          </dl>
          <p className="fine">
            {t.numbers.note}{" "}
            <Link to={`${base}/features#data-sources`} className="text-link">{t.numbers.sourcesLink}</Link>
          </p>
        </div>
      </section>

      <section className="about">
        <div className="wrap split" data-reveal>
          <div>
            <p className="eyebrow">{t.about.label}</p>
            <h2>{t.about.title}</h2>
          </div>
          <div className="prose">
            {t.about.body.map((p) => <p key={p}>{p}</p>)}
          </div>
        </div>
      </section>

      <section className="how" id="how">
        <div className="wrap">
          <p className="eyebrow" data-reveal>{t.how.label}</p>
          <h2 data-reveal>{t.how.title}</h2>
          <ol className="steps">
            {t.how.steps.map(([title, body], i) => (
              <li key={title} data-reveal style={{ "--delay": `${i * 90}ms` }}>
                <div className="step-card">
                  <span className="step-n">{String(i + 1).padStart(2, "0")}</span>
                  <h3 id={`how-${i}`}>{title}</h3>
                  <p>{body}</p>
                  {/* The whole card is clickable (the button's ::after covers it), but
                      only the button is in the outline and the tab order. */}
                  <button type="button" className="step-try" aria-describedby={`how-${i}`} onClick={() => showInDemo(i)}>
                    {t.how.try} <span aria-hidden="true">{t.dir === "rtl" ? "↖" : "↗"}</span>
                  </button>
                </div>
              </li>
            ))}
          </ol>
        </div>
      </section>

      <section className="teaser">
        <div className="wrap">
          <p className="eyebrow" data-reveal>{t.teaser.label}</p>
          <div className="teaser-grid">
            {t.teaser.items.map(([title, body], i) => (
              <div key={title} className="teaser-card" data-reveal style={{ "--delay": `${i * 90}ms` }}>
                <h3>{title}</h3>
                <p>{body}</p>
              </div>
            ))}
          </div>
          <Link to={`${base}/features`} className="text-link">{t.teaser.more} <span aria-hidden="true">{t.dir === "rtl" ? "←" : "→"}</span></Link>
        </div>
      </section>

      <section className="get" id="get">
        <div className="wrap get-inner" data-reveal>
          <div>
            <p className="eyebrow">{t.get.label}</p>
            <h2>{t.get.title}</h2>
            <p>{t.get.body}</p>
          </div>
          <div className="get-actions">
            <a className="play-badge" href={PLAY_URL} aria-label={t.get.badgeLabel} dir="ltr">
              <svg viewBox="0 0 24 26" width="26" height="28" aria-hidden="true">
                <path d="M1 1.2 13 13 1 24.8c-.6-.3-1-.9-1-1.7V2.9c0-.8.4-1.4 1-1.7z" fill="#00d7fe" />
                <path d="m16.9 9.1-3.9 3.9L1 1.2C1.5.9 2.2.9 2.9 1.3z" fill="#00f076" />
                <path d="m16.9 16.9-14 7.8c-.7.4-1.4.4-1.9.1L13 13z" fill="#ff3a44" />
                <path d="m16.9 9.1 4.6 2.6c1 .6 1 1.9 0 2.5l-4.6 2.7L13 13z" fill="#ffd500" />
              </svg>
              <span className="play-text"><small>{t.get.badgeTop}</small><b>{t.get.badgeName}</b></span>
            </a>
            <a className="btn btn-light" href={`mailto:${CONTACT_EMAIL}?subject=Guidy`}>{t.get.button}</a>
          </div>
        </div>
      </section>

      <section className="contact" id="contact">
        <div className="wrap split" data-reveal>
          <div>
            <p className="eyebrow">{t.contact.label}</p>
            <h2>{t.contact.title}</h2>
          </div>
          <div className="prose">
            <p>{t.contact.body}</p>
            <p><a className="email" href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a></p>
          </div>
        </div>
      </section>
    </Page>
  );
}

function FeaturesPage() {
  return (
    <Page>
      <Features />
    </Page>
  );
}

function Routes() {
  const { pathname } = useLocation();
  return pathname === "/features" || pathname === "/ar/features" ? <FeaturesPage /> : <Home />;
}

export default function App() {
  return (
    <Router>
      <Routes />
    </Router>
  );
}
