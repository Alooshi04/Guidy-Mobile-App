import { test } from "node:test";
import assert from "node:assert/strict";
import { initialState, reduce, nextAuto } from "./flow.js";

const data = {
  trips: [
    { options: [{ steps: [1, 2, 3] }, { steps: [1, 2] }] },
    { options: [{ steps: [1, 2] }] },
  ],
  metro: { from: [{}, {}], to: [{}, {}, {}] },
};
const run = (...actions) => actions.reduce(reduce, initialState);

test("starts on the trip planner home screen, autoplaying", () => {
  assert.equal(initialState.scene, "trip");
  assert.equal(initialState.screen, "home");
  assert.equal(initialState.auto, true);
});

test("picking a destination opens its route options on the first option", () => {
  const s = run({ type: "option", option: 1 }, { type: "pick", trip: 1 });
  assert.equal(s.screen, "options");
  assert.equal(s.trip, 1);
  assert.equal(s.option, 0);
  assert.equal(s.view, "list");
});

test("start trip goes to step one of navigation", () => {
  const s = run({ type: "pick", trip: 0 }, { type: "option", option: 1 }, { type: "start" });
  assert.equal(s.screen, "nav");
  assert.equal(s.step, 0);
  assert.equal(s.option, 1);
});

test("next walks through the steps and ends on the recap", () => {
  let s = run({ type: "pick", trip: 0 }, { type: "start" });
  s = reduce(s, { type: "next", total: 3 });
  assert.equal(s.step, 1);
  s = reduce(s, { type: "next", total: 3 });
  assert.equal(s.step, 2);
  s = reduce(s, { type: "next", total: 3 });
  assert.equal(s.screen, "recap");
});

test("back goes nav -> options -> home, and recap -> home", () => {
  let s = run({ type: "pick", trip: 0 }, { type: "start" }, { type: "back" });
  assert.equal(s.screen, "options");
  s = reduce(s, { type: "back" });
  assert.equal(s.screen, "home");
  s = run({ type: "pick", trip: 0 }, { type: "start" }, { type: "next", total: 1 }, { type: "back" });
  assert.equal(s.screen, "home");
});

test("switching scenes resets that scene", () => {
  const s = run(
    { type: "metroPair", from: 1, to: 2 },
    { type: "metroShow" },
    { type: "scene", scene: "metro" },
  );
  assert.equal(s.scene, "metro");
  assert.equal(s.metroShown, false);
  const t = run({ type: "pick", trip: 1 }, { type: "scene", scene: "trip" });
  assert.equal(t.screen, "home");
});

test("sharing from a trip shares that trip, not the default one", () => {
  const s = run(
    { type: "pick", trip: 1 },
    { type: "option", option: 2 },
    { type: "start" },
    { type: "scene", scene: "share", trip: 1, option: 2 },
  );
  assert.equal(s.scene, "share");
  assert.equal(s.share, "riding");
  assert.equal(s.trip, 1);
  assert.equal(s.option, 2);
  // opening the tab on its own still starts from scratch
  assert.equal(run({ type: "pick", trip: 1 }, { type: "scene", scene: "share" }).trip, null);
});

test("changing a metro station hides the old result", () => {
  const s = run({ type: "metroShow" }, { type: "metroFrom", i: 1 });
  assert.equal(s.metroFrom, 1);
  assert.equal(s.metroShown, false);
});

test("any action from the visitor stops autoplay", () => {
  const s = run({ type: "pick", trip: 0, user: true });
  assert.equal(s.auto, false);
  assert.equal(nextAuto(s, data), null);
});

test("replay restarts the tour from the top with autoplay on", () => {
  const s = run({ type: "scene", scene: "metro", user: true }, { type: "metroShow" }, { type: "replay" });
  assert.deepEqual(s, initialState);
});

test("autoplay plays a trip: pick, start, every step, then on to the metro", () => {
  let s = initialState;
  const seen = [];
  for (let i = 0; i < 7; i++) {
    const next = nextAuto(s, data);
    assert.ok(next.delay > 0);
    seen.push(next.action.type);
    s = reduce(s, next.action);
  }
  assert.deepEqual(seen, ["pick", "start", "next", "next", "next", "scene", "metroShow"]);
  assert.equal(s.scene, "metro");
});

test("autoplay picks a different destination each time round", () => {
  const first = run({ type: "pick", trip: 0 }, { type: "scene", scene: "trip" });
  assert.equal(nextAuto(first, data).action.trip, 1);
  const second = run({ type: "pick", trip: 1 }, { type: "scene", scene: "trip" });
  assert.equal(nextAuto(second, data).action.trip, 0);
});

test("autoplay tours metro, sharing and simple mode, then comes back to trips", () => {
  let s = run({ type: "scene", scene: "metro" });
  const scenes = [];
  for (let i = 0; i < 12 && scenes.length < 3; i++) {
    const { action } = nextAuto(s, data);
    if (action.type === "scene") scenes.push(action.scene);
    s = reduce(s, action);
  }
  assert.deepEqual(scenes, ["share", "simple", "trip"]);
});
