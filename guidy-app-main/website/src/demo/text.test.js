import { test } from "node:test";
import assert from "node:assert/strict";
import { strings } from "../i18n.js";
import { words } from "./text.js";

const bus = {
  kind: "bus",
  line: { en: "1162", ar: "1162" },
  name: { en: "Moneeb - Zahraa Madinet Nasr", ar: "المنيب - زهراء مدينة نصر" },
  towards: { en: "Moneeb", ar: "المنيب" },
  off: { en: "Ghamra", ar: "غمرة" },
  stops: 17,
  fare: 20,
};
const microbus = { ...bus, kind: "microbus", line: null, name: { en: "Ramses - Remaya", ar: "رمسيس - الرماية" } };
const walk = { kind: "walk", m: 449, min: 6, to: { en: "Doctors Tower", ar: "برج الاطباء" } };

test("English step lines", () => {
  const w = words("en", strings.en.demo);
  assert.equal(w.mode(bus), "Bus 1162");
  assert.equal(w.title(bus), "Board Bus 1162");
  assert.equal(w.sub(bus), "towards Moneeb · get off at Ghamra");
  assert.equal(w.meta(bus), "17 stops · 20 EGP");
  assert.equal(w.title(walk), "Walk 449 m");
  assert.equal(w.sub(walk), "to Doctors Tower · 6 min");
});

test("a microbus with no number is named by its route", () => {
  const w = words("en", strings.en.demo);
  assert.equal(w.mode(microbus), "Microbus");
  assert.equal(w.title(microbus), "Board Microbus");
  assert.equal(w.sub(microbus), "Ramses - Remaya · get off at Ghamra");
});

test("Arabic step lines use Arabic digits", () => {
  const w = words("ar", strings.ar.demo);
  assert.equal(w.mode(bus), "أتوبيس ١١٦٢");
  assert.equal(w.title(walk), "امشي ٤٤٩ متر");
  assert.equal(w.min(43), "٤٣ دقيقة");
  assert.equal(w.egp(30), "٣٠ جنيه");
});

test("from -> to points the way the language reads", () => {
  const from = { en: "Nasr City", ar: "مدينة نصر" };
  const to = { en: "Tahrir", ar: "التحرير" };
  assert.equal(words("en", strings.en.demo).route(from, to), "Nasr City → Tahrir");
  assert.equal(words("ar", strings.ar.demo).route(from, to), "مدينة نصر ← التحرير");
});

// "·" next to Arabic digits reads as another zero ("٣٠ · جنيه" looks like ٣٠٠),
// so Arabic separates numbers with a comma instead.
test("Arabic never puts a middle dot next to a number", () => {
  const w = words("ar", strings.ar.demo);
  assert.equal(w.meta(bus), "عدد المحطات ١٧، ٢٠ جنيه");
  assert.equal(w.sub(walk), "لـ برج الاطباء، ٦ دقيقة");
  assert.equal(w.both(43, 30), "٤٣ دقيقة، ٣٠ جنيه");
  assert.equal(words("en", strings.en.demo).both(43, 30), "43 min · 30 EGP");
});
