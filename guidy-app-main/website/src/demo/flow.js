// What the home-page demo is showing, as a plain reducer so it can be tested
// without a browser. Every action a visitor triggers carries `user: true`,
// which stops the autoplay for good.

export const SCENES = ["trip", "metro", "share", "simple"];

export const initialState = {
  scene: "trip",
  screen: "home", // trip planner: home -> options -> nav -> recap
  trip: null,
  lastTrip: -1,
  option: 0,
  view: "list", // route list or quick compare
  step: 0,
  metroFrom: 0,
  metroTo: 0,
  metroShown: false,
  share: "riding", // riding -> sheet -> family
  simple: false,
  auto: true,
};

function sceneReset(state, scene) {
  return {
    ...state,
    scene,
    screen: "home",
    trip: null,
    option: 0,
    view: "list",
    step: 0,
    metroShown: false,
    share: "riding",
    simple: false,
  };
}

function apply(state, a) {
  switch (a.type) {
    case "scene": {
      let next = sceneReset(state, a.scene);
      if (a.pair) next = { ...next, metroFrom: a.pair[0], metroTo: a.pair[1] };
      // "Share live trip" from inside a trip carries that trip along.
      if (a.trip != null) next = { ...next, trip: a.trip, option: a.option ?? 0 };
      return next;
    }
    case "pick":
      return { ...state, screen: "options", trip: a.trip, lastTrip: a.trip, option: 0, view: "list" };
    case "option":
      return { ...state, option: a.option };
    case "view":
      return { ...state, view: a.view };
    case "start":
      return { ...state, screen: "nav", step: 0 };
    case "next":
      return state.step + 1 >= a.total ? { ...state, screen: "recap" } : { ...state, step: state.step + 1 };
    case "back":
      return { ...state, screen: state.screen === "nav" ? "options" : "home" };
    case "metroFrom":
      return { ...state, metroFrom: a.i, metroShown: false };
    case "metroTo":
      return { ...state, metroTo: a.i, metroShown: false };
    case "metroPair":
      return { ...state, metroFrom: a.from, metroTo: a.to, metroShown: false };
    case "metroShow":
      return { ...state, metroShown: true };
    case "share":
      return { ...state, share: a.stage };
    case "simple":
      return { ...state, simple: a.on };
    case "replay":
      return initialState;
    default:
      return state;
  }
}

export function reduce(state, action) {
  const next = apply(state, action);
  return action.user ? { ...next, auto: false } : next;
}

// The next thing autoplay does, and how long to wait before doing it.
// Plays a whole trip, then tours the other scenes and comes back to a
// different destination.
export function nextAuto(s, data) {
  if (!s.auto) return null;
  const go = (action, delay) => ({ action, delay });
  switch (s.scene) {
    case "trip": {
      if (s.screen === "home") return go({ type: "pick", trip: (s.lastTrip + 1) % data.trips.length }, 2600);
      if (s.screen === "options") return go({ type: "start" }, 3600);
      if (s.screen === "nav") {
        const total = data.trips[s.trip].options[s.option].steps.length;
        return go({ type: "next", total }, 2800);
      }
      // A different pair of stations each time round.
      const n = data.metro.to.length;
      const p = (s.metroFrom * n + s.metroTo + 1) % (data.metro.from.length * n);
      return go({ type: "scene", scene: "metro", pair: [Math.floor(p / n), p % n] }, 3400);
    }
    case "metro":
      if (!s.metroShown) return go({ type: "metroShow" }, 2200);
      return go({ type: "scene", scene: "share" }, 5200);
    case "share": {
      if (s.share === "riding") return go({ type: "share", stage: "sheet" }, 2800);
      if (s.share === "sheet") return go({ type: "share", stage: "family" }, 2600);
      return go({ type: "scene", scene: "simple" }, 6000);
    }
    default: {
      if (!s.simple) return go({ type: "simple", on: true }, 2400);
      return go({ type: "scene", scene: "trip" }, 5200);
    }
  }
}
