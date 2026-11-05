import { test } from "node:test";
import assert from "node:assert/strict";
import { digits, distance, fill } from "./format.js";

test("digits are Arabic-Indic in Arabic and untouched in English", () => {
  assert.equal(digits(1162, "ar"), "١١٦٢");
  assert.equal(digits("Bus 66, 20 EGP", "ar"), "Bus ٦٦, ٢٠ EGP");
  assert.equal(digits(1162, "en"), "1162");
});

test("distance is metres under a kilometre, then kilometres with one decimal", () => {
  assert.equal(distance(690, "en"), "690 m");
  assert.equal(distance(1978, "en"), "2.0 km");
  assert.equal(distance(2475, "en"), "2.5 km");
  assert.equal(distance(690, "ar"), "٦٩٠ متر");
  assert.equal(distance(2475, "ar"), "٢٫٥ كم");
});

test("fill puts values into a template", () => {
  assert.equal(fill("Step {i} of {n}", { i: 2, n: 4 }), "Step 2 of 4");
  assert.equal(fill("towards {x}", {}), "towards ");
});
