import { useState } from "react";
import DemoMap from "./DemoMap";
import { stepColor } from "./colors";
import { Icon } from "./Icons";
import { fill } from "./format";

// The trip planner, screen by screen, drawn like the app.

const DEST_ICON = { tahrir: "landmark", university: "university", ramses: "metro", festival: "mall" };

export function TabBar({ d, active }) {
  const tabs = [
    ["lines", "lines"],
    ["metro", "metro"],
    ["home", "home"],
    ["trips", "trips"],
    ["settings", "settings"],
  ];
  return (
    <nav className="d-tabbar" aria-hidden="true">
      {tabs.map(([k, icon]) => (
        <span key={k} className={k === active ? "on" : ""}>
          <Icon name={icon} />
          {d.bar[k]}
        </span>
      ))}
    </nav>
  );
}

export function Header({ title, sub, onBack, backLabel, end }) {
  return (
    <header className="d-head">
      {onBack && (
        <button type="button" className="d-icon-btn" onClick={onBack} aria-label={backLabel}>
          <Icon name="back" className="flip" />
        </button>
      )}
      <div className="d-head-text">
        <strong className="d-h">{title}</strong>
        {sub && <p>{sub}</p>}
      </div>
      {end}
    </header>
  );
}

export function Tag({ tag, d }) {
  return <span className={`d-tag d-tag-${tag}`}>{tag === "recommended" && <Icon name="star" />}{d.tags[tag]}</span>;
}

export function ModeChain({ steps, w }) {
  return (
    <span className="d-chain">
      {steps.map((s, i) => (
        <span key={i} className="d-chip" style={{ "--c": stepColor(s) }}>
          <Icon kind={s.kind} />
          {s.kind === "walk" ? null : s.line ? w.n(s.line[w.lang]) : null}
        </span>
      ))}
    </span>
  );
}

export function Home({ data, s, d, w, lang, act, hint }) {
  // Tapping "Where to?" points at the places to pick from.
  const [searching, setSearching] = useState(false);
  const next = (s.lastTrip + 1) % data.trips.length;
  return (
    <div className="d-screen d-home">
      <div className="d-hello">
        <img src="/logo-white.svg" alt="" width="70" height="24" />
        <strong className="d-h">{d.home.greet}</strong>
        <p>{d.home.tagline}</p>
      </div>
      <button type="button" className={`d-search ${searching ? "open" : ""}`} onClick={() => setSearching((v) => !v)}>
        <span>{d.home.where}</span>
        <Icon name="search" />
      </button>
      <p className="d-label">{d.home.quick}</p>
      <div className="d-dests">
        {data.trips.map((trip, i) => {
          const best = trip.options[0];
          return (
            <button
              type="button"
              key={trip.id}
              className={`d-dest ${(hint && i === next) || searching ? "hint" : ""}`}
              onClick={() => act({ type: "pick", trip: i })}
            >
              <span className="d-dest-ic"><Icon name={DEST_ICON[trip.id] ?? "pin"} /></span>
              <strong>{trip.to[lang]}</strong>
              <small>{w.both(best.min, best.fare)}</small>
            </button>
          );
        })}
      </div>
      <TabBar d={d} active="home" />
    </div>
  );
}

export function Options({ data, s, d, w, lang, act, hint }) {
  const trip = data.trips[s.trip];
  return (
    <div className="d-screen d-options">
      <Header
        title={d.options.title}
        sub={w.route(data.origin, trip.to)}
        onBack={() => act({ type: "back" })}
        backLabel={d.back}
      />
      <div className="d-map-wrap">
        <DemoMap trip={trip} origin={data.origin} option={s.option} lang={lang} aspect={1.75} onPick={(i) => act({ type: "option", option: i })} />
      </div>
      <div className="d-seg" role="group">
        {["list", "compare"].map((v) => (
          <button key={v} type="button" aria-pressed={s.view === v} className={s.view === v ? "on" : ""} onClick={() => act({ type: "view", view: v })}>
            <Icon name={v === "list" ? "list" : "compare"} />
            {d.options[v]}
          </button>
        ))}
      </div>
      <div className="d-scroll">
        {s.view === "list" ? (
          trip.options.map((o, i) => (
            <button type="button" key={i} className={`d-card ${i === s.option ? "on" : ""}`} onClick={() => act({ type: "option", option: i })}>
              <span className="d-card-top">
                <span className="d-tags">{o.tags.map((t) => <Tag key={t} tag={t} d={d} />)}</span>
                <span className="d-fare">{w.egp(o.fare)}</span>
              </span>
              <span className="d-card-time">{w.min(o.min)}</span>
              <span className="d-card-meta">
                <Icon kind="walk" /> {w.dist(o.walkM)} {d.unit.walk}
                {d.unit.sep}
                {o.transfers ? `${w.n(o.transfers)} ${o.transfers === 1 ? d.unit.transfer : d.unit.transfers}` : d.unit.direct}
              </span>
              <ModeChain steps={o.steps} w={w} />
            </button>
          ))
        ) : (
          <table className="d-compare">
            <thead>
              <tr>{d.options.cols.map((c) => <th key={c}>{c}</th>)}</tr>
            </thead>
            <tbody>
              {trip.options.map((o, i) => (
                <tr key={i} className={i === s.option ? "on" : ""} onClick={() => act({ type: "option", option: i })}>
                  {/* The row takes the click; the button makes it reachable by keyboard. */}
                  <td><button type="button" className="d-row-btn" aria-pressed={i === s.option}>{d.tags[o.tags[0]]}</button></td>
                  <td className="t-time">{w.min(o.min)}</td>
                  <td className="t-fare">{w.egp(o.fare)}</td>
                  <td className="t-walk">{w.dist(o.walkM)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
      <div className="d-foot">
        <button type="button" className={`d-primary ${hint ? "hint" : ""}`} onClick={() => act({ type: "start" })}>
          <Icon name="navigate" />
          {d.options.start}
        </button>
      </div>
    </div>
  );
}

export function NavSheet({ opt, step, d, w, onNext, onShare, shareHint, nextHint }) {
  const st = opt.steps[step];
  const last = step === opt.steps.length - 1;
  return (
    <div className="d-sheet">
      <span className="d-grip" aria-hidden="true" />
      <div className="d-sheet-row">
        <span className="d-now">{d.step.now}</span>
        <span className="d-of">{fill(d.step.of, { i: w.n(step + 1), n: w.n(opt.steps.length) })}</span>
      </div>
      <div className="d-step" key={step}>
        <span className="d-step-ic" style={{ "--c": stepColor(st) }}>
          <Icon kind={st.kind} />
        </span>
        <div>
          <strong>{w.title(st)}</strong>
          <small>{w.sub(st)}</small>
        </div>
      </div>
      {st.kind !== "walk" && (
        <div className="d-pills">
          <span className="d-pill">{w.meta(st)}</span>
          {st.others > 0 && <span className="d-pill soft">{fill(d.step.others, { n: w.n(st.others) })}</span>}
        </div>
      )}
      <div className="d-dots" aria-hidden="true">
        {opt.steps.map((x, i) => (
          <span key={i} className={i < step ? "done" : i === step ? "now" : ""} style={{ "--c": stepColor(x) }} />
        ))}
      </div>
      <div className="d-sheet-actions">
        {onShare && (
          <button type="button" className={`d-ghost ${shareHint ? "hint" : ""}`} onClick={onShare}>
            <Icon name="share" />
            {d.share.button}
          </button>
        )}
        {onNext && (
          <button type="button" className={`d-primary ${nextHint ? "hint" : ""}`} onClick={onNext}>
            {last ? d.step.arrive : d.step.next}
          </button>
        )}
      </div>
    </div>
  );
}

export function Banner({ st, d, w }) {
  const text =
    st.kind === "walk"
      ? fill(d.step.walking, { x: st.to[w.lang] })
      : fill(d.step.until, { x: st.off[w.lang] });
  return (
    <div className="d-banner" style={{ "--c": stepColor(st) }}>
      <span className="d-step-ic small"><Icon kind={st.kind} /></span>
      <div>
        <strong>{st.kind === "walk" ? d.modes.walk : fill(d.step.on, { mode: w.mode(st) })}</strong>
        <small>{text}</small>
      </div>
    </div>
  );
}

export function Nav({ data, s, d, w, lang, act, hint, onShare, shareHint }) {
  const trip = data.trips[s.trip];
  const opt = trip.options[s.option];
  const st = opt.steps[s.step];
  return (
    <div className="d-screen d-nav">
      <DemoMap trip={trip} origin={data.origin} option={s.option} mode="nav" step={s.step} lang={lang} aspect={0.62} />
      <button type="button" className="d-icon-btn floating" onClick={() => act({ type: "back" })} aria-label={d.back}>
        <Icon name="back" className="flip" />
      </button>
      <Banner st={st} d={d} w={w} />
      <NavSheet
        opt={opt}
        step={s.step}
        d={d}
        w={w}
        onNext={() => act({ type: "next", total: opt.steps.length })}
        nextHint={hint}
        onShare={onShare}
        shareHint={shareHint}
      />
    </div>
  );
}

export function Recap({ data, s, d, w, lang, act }) {
  const trip = data.trips[s.trip];
  const opt = trip.options[s.option];
  return (
    <div className="d-screen d-recap">
      <div className="d-recap-body">
        <span className="d-big-check"><Icon name="check" /></span>
        <strong className="d-h">{d.recap.title}</strong>
        <p>{trip.to[lang]}</p>
        <dl className="d-stats">
          <div><dt>{d.recap.time}</dt><dd>{w.min(opt.min)}</dd></div>
          <div><dt>{d.recap.fare}</dt><dd>{w.egp(opt.fare)}</dd></div>
          <div><dt>{d.recap.changes}</dt><dd>{w.n(opt.transfers)}</dd></div>
        </dl>
        <ModeChain steps={opt.steps} w={w} />
      </div>
      <div className="d-foot">
        <button type="button" className="d-primary" onClick={() => act({ type: "back" })}>
          {d.recap.again}
        </button>
      </div>
      <TabBar d={d} active="trips" />
    </div>
  );
}
