// Generates platform files from tokens.json:
//   web/src/lib/styles/tokens.css   (CSS custom properties, light/dark)
//   mobile/lib/theme/tokens.g.dart  (Dart constants + ThemeExtension)
// Usage: node src/build.mjs [--check]   (--check fails if outputs are stale)
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const repo = resolve(root, "../..");
const tokens = JSON.parse(readFileSync(resolve(root, "tokens.json"), "utf8"));

const HEADER = "GENERATED from packages/design-tokens/tokens.json. Do not edit.";
const kebab = (s) => s.replace(/([a-z0-9])([A-Z])/g, "$1-$2").toLowerCase();
const shadowCss = (layers) =>
  layers.map((l) => `${l.x}px ${l.y}px ${l.blur}px ${l.spread}px ${l.color}`).join(", ");
const bezier = (p) => `cubic-bezier(${p.join(", ")})`;

export function toCss(t) {
  const themeVars = (mode) => [
    ...Object.entries(t.color[mode]).map(([k, v]) => `  --color-${kebab(k)}: ${v};`),
    ...Object.entries(t.shadow[mode]).map(([k, v]) => `  --shadow-${k}: ${shadowCss(v)};`),
    `  color-scheme: ${mode};`,
  ];
  const base = [
    ...Object.entries(t.font.family).map(
      ([k, v]) => `  --font-${k}: "${v}", ${t.font.fallback[k]};`,
    ),
    ...Object.entries(t.font.size).map(([k, v]) => `  --text-${k}: ${v / 16}rem;`),
    ...Object.entries(t.font.weight).map(([k, v]) => `  --weight-${k}: ${v};`),
    ...Object.entries(t.font.lineHeight).map(([k, v]) => `  --leading-${k}: ${v};`),
    ...Object.entries(t.space).map(([k, v]) => `  --space-${k}: ${v / 16}rem;`),
    ...Object.entries(t.radius).map(([k, v]) => `  --radius-${k}: ${v}px;`),
    ...Object.entries(t.motion.duration).map(([k, v]) => `  --duration-${k}: ${v}ms;`),
    ...Object.entries(t.motion.easing).map(([k, v]) => `  --ease-${k}: ${bezier(v)};`),
  ];
  const dark = themeVars("dark").map((l) => "  " + l);
  return [
    `/* ${HEADER} */`,
    `/* Breakpoints (not usable in media queries as vars): ${JSON.stringify(t.breakpoint)} */`,
    ":root {",
    ...base,
    ...themeVars("light"),
    "}",
    "",
    "@media (prefers-color-scheme: dark) {",
    '  :root:not([data-theme="light"]) {',
    ...dark,
    "  }",
    "}",
    "",
    ':root[data-theme="dark"] {',
    ...themeVars("dark"),
    "}",
    "",
    "@media (prefers-reduced-motion: reduce) {",
    "  :root {",
    ...Object.keys(t.motion.duration).map((k) => `    --duration-${k}: 0ms;`),
    "  }",
    "}",
    "",
  ].join("\n");
}

const dartColor = (hex) => {
  const h = hex.replace("#", "");
  const rgb = h.slice(0, 6);
  const a = h.length === 8 ? h.slice(6, 8) : "FF";
  return `Color(0x${(a + rgb).toUpperCase()})`;
};
const dartName = (k) => (/^\d/.test(k) ? `s${k}` : k.replace(/^(\d)/, "x$1"));
const dartSize = (k) => (/^\d/.test(k) ? `x${k}` : k);

export function toDart(t) {
  const colorKeys = Object.keys(t.color.light);
  const shadowKeys = Object.keys(t.shadow.light);
  const shadowList = (layers) =>
    `[${layers
      .map(
        (l) =>
          `BoxShadow(offset: Offset(${l.x}, ${l.y}), blurRadius: ${l.blur}, spreadRadius: ${l.spread}, color: ${dartColor(l.color)})`,
      )
      .join(", ")}]`;
  const instance = (mode) =>
    [
      `  static const ${mode} = AlcoveColors(`,
      ...colorKeys.map((k) => `    ${k}: ${dartColor(t.color[mode][k])},`),
      ...shadowKeys.map((k) => `    shadow${k.toUpperCase()}: ${shadowList(t.shadow[mode][k])},`),
      "  );",
    ].join("\n");
  const curve = (p) => `Cubic(${p.join(", ")})`;

  return `// ${HEADER}
// ignore_for_file: public_member_api_docs, constant_identifier_names

import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';

/// Theme-dependent tokens (colors, shadows). Read with
/// \`Theme.of(context).extension<AlcoveColors>()!\`.
@immutable
class AlcoveColors extends ThemeExtension<AlcoveColors> {
  const AlcoveColors({
${colorKeys.map((k) => `    required this.${k},`).join("\n")}
${shadowKeys.map((k) => `    required this.shadow${k.toUpperCase()},`).join("\n")}
  });

${colorKeys.map((k) => `  final Color ${k};`).join("\n")}
${shadowKeys.map((k) => `  final List<BoxShadow> shadow${k.toUpperCase()};`).join("\n")}

${instance("light")}

${instance("dark")}

  @override
  AlcoveColors copyWith({
${colorKeys.map((k) => `    Color? ${k},`).join("\n")}
${shadowKeys.map((k) => `    List<BoxShadow>? shadow${k.toUpperCase()},`).join("\n")}
  }) {
    return AlcoveColors(
${colorKeys.map((k) => `      ${k}: ${k} ?? this.${k},`).join("\n")}
${shadowKeys.map((k) => `      shadow${k.toUpperCase()}: shadow${k.toUpperCase()} ?? this.shadow${k.toUpperCase()},`).join("\n")}
    );
  }

  @override
  AlcoveColors lerp(AlcoveColors? other, double t) {
    if (other == null) return this;
    return AlcoveColors(
${colorKeys.map((k) => `      ${k}: Color.lerp(${k}, other.${k}, t)!,`).join("\n")}
${shadowKeys.map((k) => `      shadow${k.toUpperCase()}: BoxShadow.lerpList(shadow${k.toUpperCase()}, other.shadow${k.toUpperCase()}, t)!,`).join("\n")}
    );
  }
}

abstract final class AlcoveFont {
${Object.entries(t.font.family).map(([k, v]) => `  static const String ${k} = '${v}';`).join("\n")}
${Object.entries(t.font.size).map(([k, v]) => `  static const double size${dartSize(k).replace(/^./, (c) => c.toUpperCase())} = ${v};`).join("\n")}
${Object.entries(t.font.weight).map(([k, v]) => `  static const FontWeight ${k} = FontWeight.w${v};`).join("\n")}
${Object.entries(t.font.lineHeight).map(([k, v]) => `  static const double leading${k.replace(/^./, (c) => c.toUpperCase())} = ${v};`).join("\n")}
}

abstract final class AlcoveSpace {
${Object.entries(t.space).map(([k, v]) => `  static const double ${dartName(k)} = ${v};`).join("\n")}
}

abstract final class AlcoveRadius {
${Object.entries(t.radius).map(([k, v]) => `  static const double ${k} = ${v};`).join("\n")}
}

abstract final class AlcoveMotion {
${Object.entries(t.motion.duration).map(([k, v]) => `  static const Duration ${k} = Duration(milliseconds: ${v});`).join("\n")}
${Object.entries(t.motion.easing).map(([k, v]) => `  static const Curve ${k}Curve = ${curve(v)};`).join("\n")}
}

abstract final class AlcoveBreakpoint {
${Object.entries(t.breakpoint).map(([k, v]) => `  static const double ${k} = ${v};`).join("\n")}
}
`;
}

const outputs = [
  [resolve(repo, "web/src/lib/styles/tokens.css"), toCss(tokens)],
  [resolve(repo, "mobile/lib/theme/tokens.g.dart"), toDart(tokens)],
];

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const check = process.argv.includes("--check");
  let stale = false;
  for (const [path, content] of outputs) {
    if (check) {
      if (!existsSync(path) || readFileSync(path, "utf8") !== content) {
        console.error(`stale: ${path}`);
        stale = true;
      }
    } else {
      mkdirSync(dirname(path), { recursive: true });
      writeFileSync(path, content);
      console.log(`wrote ${path.replace(repo + "/", "")}`);
    }
  }
  if (stale) {
    console.error("Run `pnpm tokens` and commit the result.");
    process.exit(1);
  }
}
