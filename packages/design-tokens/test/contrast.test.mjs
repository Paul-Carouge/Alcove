// Enforces WCAG 2.2 AA contrast for every text/background pair we ship.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const tokens = JSON.parse(readFileSync(new URL("../tokens.json", import.meta.url), "utf8"));

const luminance = (hex) => {
  const [r, g, b] = [1, 3, 5].map((i) => {
    const c = parseInt(hex.slice(i, i + 2), 16) / 255;
    return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};
export const contrast = (a, b) => {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
};

// [foreground, background, minimum ratio]
const PAIRS = [
  ["text", "bg", 4.5],
  ["text", "surface", 4.5],
  ["text", "surfaceSunken", 4.5],
  ["textMuted", "bg", 4.5],
  ["textMuted", "surface", 4.5],
  ["textMuted", "surfaceSunken", 4.5],
  ["accent", "bg", 4.5],
  ["accent", "surface", 4.5],
  ["accentContrast", "accent", 4.5],
  ["accent", "accentSubtle", 4.5],
  ["danger", "surface", 4.5],
  ["dangerContrast", "danger", 4.5],
  ["success", "surface", 4.5],
  ["warning", "surface", 4.5],
  ["focus", "bg", 3],
  ["borderStrong", "surface", 1.8],
  ["onStage", "stage", 4.5],
  ["onStage", "stagePanel", 4.5],
  ["onStageMuted", "stagePanel", 4.5],
  ["onStageLink", "stagePanel", 4.5],
  ["favorite", "stage", 3],
  // Tag chips: coloured text on a tint of the same colour.
  ...["Gray", "Red", "Orange", "Yellow", "Green", "Teal", "Blue", "Violet", "Pink"].map((c) => [
    `tag${c}`,
    `tag${c}Bg`,
    4.5,
  ]),
];

for (const mode of ["light", "dark"]) {
  const c = tokens.color[mode];
  test(`${mode}: both themes define the same keys`, () => {
    assert.deepEqual(Object.keys(c).sort(), Object.keys(tokens.color.light).sort());
  });
  for (const [fg, bg, min] of PAIRS) {
    test(`${mode}: ${fg} on ${bg} >= ${min}:1`, () => {
      const ratio = contrast(c[fg], c[bg]);
      assert.ok(ratio >= min, `${c[fg]} on ${c[bg]} is ${ratio.toFixed(2)}:1`);
    });
  }
}
