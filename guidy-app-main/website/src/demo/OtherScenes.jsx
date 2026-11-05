import DemoMap from "./DemoMap";
import { stepColor } from "./colors";
import { Icon } from "./Icons";
import { fill } from "./format";
import { Banner, Header, ModeChain, NavSheet, TabBar, Tag } from "./TripScreens";

// The other three tabs of the demo: metro planner, live sharing, simple mode.

const LINE = { NAT_L1: "#d6453b", NAT_L2: "#e8a31a", NAT_L3: "#1f9d6b" };

export function Metro({ data, s, d, w, lang, act, hint }) {
  const m = data.metro;
  const from = m.from[s.metroFrom];
  const to = m.to[s.metroTo];
  const plan = m.plans.find((p) => p.from === from.id && p.to === to.id);
  const changes = d.metro.changes[Math.min(plan.changes, 2)];
  return (
    <div className="d-screen d-metro">
      <Header title={d.metro.title} sub={d.metro.sub} />
      <div className="d-scroll">
        <div className="d-pick">
          <span className="d-pick-label"><span className="dot from" />{d.metro.from}</span>
          <div className="d-pick-opts">
            {m.from.map((st, i) => (
              <button type="button" key={st.id} className={i === s.metroFrom ? "on" : ""} onClick={() => act({ type: "metroFrom", i })}>
                {st[lang]}
              </button>
            ))}
          </div>
          <span className="d-pick-label"><span className="dot to" />{d.metro.to}</span>
          <div className="d-pick-opts">
            {m.to.map((st, i) => (
              <button type="button" key={st.id} className={i === s.metroTo ? "on" : ""} onClick={() => act({ type: "metroTo", i })}>
                {st[lang]}
              </button>
            ))}
          </div>
        </div>
        {!s.metroShown ? (
          <button type="button" className={`d-primary wide ${hint ? "hint" : ""}`} onClick={() => act({ type: "metroShow" })}>
            {d.metro.show}
          </button>
        ) : (
          <div className="d-metro-result" key={`${from.id}-${to.id}`}>
            <div className="d-metro-card">
              <div><small>{d.metro.time}</small><strong>{w.min(plan.min)}</strong></div>
              <div><small>{d.metro.fare}</small><strong>{w.egp(plan.fare)}</strong></div>
              <div><small>{d.metro.stops}</small><strong>{w.n(plan.stops)}</strong></div>
              <span className="d-metro-changes">{fill(changes, { n: w.n(plan.changes) })}</span>
            </div>
            {plan.legs.map((leg, i) => (
              <div className="d-leg" key={i} style={{ "--c": LINE[leg.line] ?? "#2da3e3" }}>
                <div className="d-leg-head">
                  <span className="d-line-badge">{w.n(leg.name)}</span>
                  <div>
                    <strong>{fill(d.metro.line, { n: w.n(leg.name) })}</strong>
                    <small>{fill(d.metro.towards, { x: leg.towards[lang], n: w.n(leg.stops.length - 1) })}</small>
                  </div>
                </div>
                <ol className="d-stops">
                  {leg.stops.map((st, k) => (
                    <li key={st.id + k} className={k === 0 || k === leg.stops.length - 1 ? "end" : ""}>
                      {st[lang]}
                      {i < plan.legs.length - 1 && k === leg.stops.length - 1 && (
                        <em>{fill(d.metro.change, { n: w.n(plan.legs[i + 1].name) })}</em>
                      )}
                    </li>
                  ))}
                </ol>
              </div>
            ))}
          </div>
        )}
      </div>
      <TabBar d={d} active="metro" />
    </div>
  );
}

// Sharing plays on the trip being taken (the first one if none), riding
// its first vehicle.
export function Share({ data, s, d, w, lang, dir, act, hint, onScreen }) {
  const trip = data.trips[s.trip ?? 0];
  const option = s.trip == null ? 0 : s.option;
  const opt = trip.options[option];
  const step = Math.max(0, opt.steps.findIndex((x) => x.kind !== "walk"));
  const st = opt.steps[step];

  if (s.share === "family") {
    const left = opt.steps.slice(step).reduce((a, x) => a + (x.min || 0) + (x.wait || 0), 0);
    return (
      <div className="d-screen d-live">
        <div className="d-family-tag">{d.share.family}</div>
        <Header
          title={d.share.viewer}
          sub={w.route(data.origin, trip.to)}
          end={<span className="d-live-pill">{d.share.live}</span>}
        />
        <div className="d-map-wrap tall">
          <DemoMap trip={trip} origin={data.origin} option={option} mode="live" lang={lang} aspect={0.75} running={onScreen} />
        </div>
        <div className="d-rider">
          <span className="d-avatar">{dir === "rtl" ? "ع" : "O"}</span>
          <div>
            <strong>{fill(d.share.on, { mode: d.modes[st.kind], line: st.line ? w.n(st.line[lang]) : "" })}</strong>
            <small>{fill(d.share.eta, { n: w.n(left) })}</small>
            <small className="muted">{d.share.updated}</small>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="d-screen d-nav">
      <DemoMap trip={trip} origin={data.origin} option={option} mode="nav" step={step} lang={lang} aspect={0.62} />
      <Banner st={st} d={d} w={w} />
      <NavSheet
        opt={opt}
        step={step}
        d={d}
        w={w}
        onShare={() => act({ type: "share", stage: "sheet" })}
        shareHint={hint && s.share === "riding"}
      />
      {s.share === "sheet" && (
        <div className="d-modal" onClick={() => act({ type: "share", stage: "riding" })}>
          <div className="d-modal-sheet" onClick={(e) => e.stopPropagation()}>
            <span className="d-grip" aria-hidden="true" />
            <strong className="d-h">{d.share.title}</strong>
            <p>{d.share.body}</p>
            <div className="d-link"><Icon name="link" /><span dir="ltr">guidyapp.com/l/k7Qm2x</span></div>
            <button type="button" className={`d-wa ${hint ? "hint" : ""}`} onClick={() => act({ type: "share", stage: "family" })}>
              <Icon name="chat" />
              {d.share.whatsapp}
            </button>
            <button type="button" className="d-ghost wide" onClick={() => act({ type: "share", stage: "family" })}>
              <Icon name="link" />
              {d.share.copy}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

// Simple mode: the same trip, told as one sentence in big type.
export function Simple({ data, s, d, w, lang, act, hint }) {
  const trip = data.trips[0];
  const opt = trip.options[0];
  const rides = opt.steps.filter((x) => x.kind !== "walk");
  return (
    <div className={`d-screen d-simple ${s.simple ? "is-on" : ""}`}>
      <div className="d-setting">
        <div>
          <strong>{d.simple.setting}</strong>
          <small>{d.simple.hint}</small>
        </div>
        <button
          type="button"
          role="switch"
          aria-checked={s.simple}
          aria-label={d.simple.setting}
          className={`d-switch ${hint && !s.simple ? "hint" : ""}`}
          onClick={() => act({ type: "simple", on: !s.simple })}
        >
          <span />
        </button>
      </div>
      <div className="d-scroll">
        {s.simple ? (
          <div className="d-simple-card" key="on">
            <p className="d-simple-to"><Icon name="pin" />{trip.to[lang]}</p>
            <p className="d-simple-say">
              {fill(d.simple.take, { x: rides.map((x) => w.mode(x)).join(` ${d.simple.then} `) })}
            </p>
            <p className="d-simple-total">{fill(d.simple.total, { t: w.n(opt.min), f: w.n(opt.fare) })}</p>
            <ol className="d-simple-steps">
              {opt.steps.map((x, i) => (
                <li key={i} style={{ "--c": stepColor(x) }}>
                  <span className="d-step-ic"><Icon kind={x.kind} /></span>
                  <div>
                    <strong>{w.title(x)}</strong>
                    <small>{w.sub(x)}</small>
                  </div>
                </li>
              ))}
            </ol>
            <button
              type="button"
              className="d-primary wide big"
              onClick={() => [{ type: "scene", scene: "trip" }, { type: "pick", trip: 0 }, { type: "start" }].forEach(act)}
            >
              {d.simple.start}
            </button>
          </div>
        ) : (
          <div className="d-simple-off" key="off">
            <Header title={d.options.title} sub={w.route(data.origin, trip.to)} />
            {trip.options.map((o, i) => (
              <div key={i} className={`d-card static ${i === 0 ? "on" : ""}`}>
                <span className="d-card-top">
                  <span className="d-tags">{o.tags.map((t) => <Tag key={t} tag={t} d={d} />)}</span>
                  <span className="d-fare">{w.egp(o.fare)}</span>
                </span>
                <span className="d-card-time">{w.min(o.min)}</span>
                <ModeChain steps={o.steps} w={w} />
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
