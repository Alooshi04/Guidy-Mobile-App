import { useEffect, useRef, useState } from "react";
import data from "./data.json";
import { SCENES, nextAuto } from "./flow";
import { Icon } from "./Icons";
import { Home, Nav, Options, Recap } from "./TripScreens";
import { Metro, Share, Simple } from "./OtherScenes";
import { words } from "./text";
import "./demo.css";

// The interactive app on the home page. State lives in the page (App.jsx)
// so "How it works" can jump the demo to a step.

const reducedMotion = () => window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;

const SHOWN = 0.35; // of the demo on screen, for the tour to run

function shownEnough(el) {
  const r = el.getBoundingClientRect();
  const seen = Math.min(r.bottom, window.innerHeight) - Math.max(r.top, 0);
  return r.height > 0 && seen / r.height >= SHOWN;
}

// Autoplay only while the demo is on screen and the tab is visible.
function useOnScreen(ref) {
  const [on, setOn] = useState(false);
  useEffect(() => {
    const el = ref.current;
    if (!el || !("IntersectionObserver" in window)) return setOn(true);
    const io = new IntersectionObserver(([e]) => setOn(e.isIntersecting), { threshold: SHOWN });
    io.observe(el);
    // The observer only reports crossings: back on the tab, look again.
    const vis = () => setOn(!document.hidden && shownEnough(el));
    document.addEventListener("visibilitychange", vis);
    return () => {
      io.disconnect();
      document.removeEventListener("visibilitychange", vis);
    };
  }, [ref]);
  return on;
}

export default function Demo({ state: s, dispatch, lang, t }) {
  const d = t.demo;
  const w = words(lang, d);
  const ref = useRef(null);
  const stage = useRef(null);
  const focusInside = useRef(false);
  const onScreen = useOnScreen(ref);

  // With reduced motion the tour doesn't start by itself; "Play the tour"
  // still plays it.
  useEffect(() => {
    if (reducedMotion()) dispatch({ type: "stop", user: true });
  }, [dispatch]);

  useEffect(() => {
    if (!onScreen) return;
    const next = nextAuto(s, data);
    if (!next) return;
    const id = setTimeout(() => dispatch(next.action), next.delay);
    return () => clearTimeout(id);
  }, [s, onScreen, dispatch]);

  // A visitor reaching into the demo -- pointer or keyboard -- takes over:
  // the tour stops where it is, so the screen never changes under them.
  const takeOver = () => {
    if (s.auto) dispatch({ type: "stop", user: true });
  };

  const act = (a) => dispatch({ ...a, user: true });
  const hint = s.auto && onScreen;
  const props = { data, s, d, w, lang, dir: t.dir, act, hint, onScreen };

  let screen;
  if (s.scene === "metro") screen = <Metro {...props} />;
  else if (s.scene === "share") screen = <Share {...props} />;
  else if (s.scene === "simple") screen = <Simple {...props} />;
  else if (s.screen === "options") screen = <Options {...props} />;
  else if (s.screen === "nav")
    screen = <Nav {...props} onShare={() => act({ type: "scene", scene: "share", trip: s.trip, option: s.option })} />;
  else if (s.screen === "recap") screen = <Recap {...props} />;
  else screen = <Home {...props} />;

  const caption = s.scene === "trip" ? d.captions[s.screen] : d.captions[s.scene];
  const key = `${s.scene}-${s.scene === "trip" ? s.screen : ""}`;

  // Each screen gets a fresh stage (for its entrance animation), which takes
  // the button just pressed with it: keep the keyboard in the demo.
  useEffect(() => {
    if (focusInside.current && (!document.activeElement || document.activeElement === document.body)) {
      stage.current?.focus({ preventScroll: true });
    }
  }, [key]);

  return (
    <div
      className={onScreen ? "demo" : "demo is-off"}
      ref={ref}
      id="demo"
      onPointerEnter={takeOver}
      onFocus={() => {
        focusInside.current = true;
        takeOver();
      }}
      onBlur={(e) => {
        if (e.relatedTarget && !e.currentTarget.contains(e.relatedTarget)) focusInside.current = false;
      }}
    >
      <div className="demo-tabs" role="group" aria-label={d.label}>
        {SCENES.map((k) => (
          <button
            key={k}
            type="button"
            aria-pressed={s.scene === k}
            className={s.scene === k ? "on" : ""}
            onClick={() => act({ type: "scene", scene: k })}
          >
            {d.tabs[k]}
          </button>
        ))}
      </div>

      <div className="phone">
        <div className="phone-screen" dir={t.dir} lang={lang}>
          <div className="d-status" aria-hidden="true">
            <span>{w.n("9:30")}</span>
            <span className="d-island" />
            <span className="d-bat" />
          </div>
          <div className="d-stage" key={key} ref={stage} tabIndex={-1} role="group" aria-label={caption}>
            {screen}
          </div>
        </div>
      </div>

      {/* Read out only what a visitor's own taps change, not every step of the tour. */}
      <div className="demo-caption" aria-live={s.auto ? "off" : "polite"}>
        <p>{caption}</p>
        {s.auto && (
          <span className="demo-auto">
            <span className="demo-auto-dot" />
            {d.label}
          </span>
        )}
        {/* One button that stays put, so pressing it keeps the keyboard where it is. */}
        <button
          type="button"
          className="demo-replay"
          onClick={() => dispatch(s.auto ? { type: "stop", user: true } : { type: "replay" })}
        >
          <Icon name={s.auto ? "pause" : "play"} />
          {s.auto ? d.pause : d.replay}
        </button>
      </div>
    </div>
  );
}
