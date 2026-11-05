import { test } from "node:test";
import assert from "node:assert/strict";
import { fit, pathD, along, lerpBox, xy } from "./geo.js";

test("xy projects lat/lon the same way as network.svg", () => {
  assert.deepEqual(xy(30.17, 31.12), [0, 0]);
  assert.deepEqual(xy(29.93, 31.5), [1000, 730]);
  // Doctors Tower, Nasr City -- the demo's starting point in data.json
  assert.deepEqual(xy(30.0565, 31.356), [621.1, 345.2]);
});

test("fit pads the points and matches the requested aspect ratio", () => {
  const b = fit([[100, 100], [200, 150]], 1, 0.1);
  assert.equal(b.w, b.h);
  assert.ok(b.x < 100 && b.x + b.w > 200);
  assert.ok(b.y < 100 && b.y + b.h > 150);
  // centred on the points
  assert.equal(b.x + b.w / 2, 150);
  assert.equal(b.y + b.h / 2, 125);
});

test("fit never zooms in closer than the minimum size", () => {
  const b = fit([[10, 10], [11, 11]], 2, 0, 40);
  assert.equal(b.w, 40);
  assert.equal(b.h, 20);
});

test("pathD draws a polyline", () => {
  assert.equal(pathD([[0, 0], [10, 5.5], [20, 0]]), "M0 0L10 5.5L20 0");
  assert.equal(pathD([]), "");
});

test("along finds the point at a fraction of the line's length", () => {
  const line = [[0, 0], [10, 0], [10, 10]];
  assert.deepEqual(along(line, 0), [0, 0]);
  assert.deepEqual(along(line, 0.5), [10, 0]);
  assert.deepEqual(along(line, 0.75), [10, 5]);
  assert.deepEqual(along(line, 1), [10, 10]);
  assert.deepEqual(along(line, 7), [10, 10]);
  assert.deepEqual(along([[3, 4]], 0.5), [3, 4]);
});

test("lerpBox moves one view box towards another", () => {
  const a = { x: 0, y: 0, w: 10, h: 10 };
  const b = { x: 10, y: 20, w: 30, h: 30 };
  assert.deepEqual(lerpBox(a, b, 0.5), { x: 5, y: 10, w: 20, h: 20 });
});
