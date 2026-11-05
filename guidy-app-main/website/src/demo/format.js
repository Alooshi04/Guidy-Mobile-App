// Numbers and distances the way the app writes them in each language.

const AR_DIGITS = "٠١٢٣٤٥٦٧٨٩";

export function digits(value, lang) {
  const s = String(value);
  return lang === "ar" ? s.replace(/\d/g, (d) => AR_DIGITS[d]) : s;
}

export function distance(m, lang) {
  if (m < 1000) return lang === "ar" ? `${digits(m, lang)} متر` : `${m} m`;
  const km = (m / 1000).toFixed(1);
  return lang === "ar" ? `${digits(km, lang).replace(".", "٫")} كم` : `${km} km`;
}

export function fill(template, vars) {
  return template.replace(/\{(\w+)\}/g, (_, k) => vars[k] ?? "");
}
