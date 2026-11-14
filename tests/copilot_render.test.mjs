// Pruebas del pintado de respuestas de Trucha Copilot (Markdown + LaTeX).  node tests/copilot_render.test.mjs
import assert from "node:assert/strict";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const D = new URL("../dotfiles/.local/share/trucha-os/copilot/", import.meta.url).pathname;
const { marked } = require(D + "vendor/marked.min.js");
const katex = require(D + "vendor/katex/katex.min.js");
const render = require(D + "render.js")(marked, katex);

// fórmulas: en línea y en bloque, con \frac y subíndices intactos (marked no las toca)
const math = render("La serie: $c_n=\\frac{1}{T}$ y\n\n$$\\sum_{n} a_n$$");
assert.match(math, /class="katex"/);
assert.match(math, /katex-display/);
assert.match(math, /mfrac/);
assert.doesNotMatch(math, /@@M/);
assert.match(render("\\(x^2\\) y \\[y\\]"), /katex-display/);

// el código no se interpreta como fórmula
assert.match(render("`echo $HOME $PATH`"), /<code>echo \$HOME \$PATH<\/code>/);
assert.doesNotMatch(render("```sh\nA=$1; B=$2\n```"), /katex/);

// nada de HTML ni enlaces peligrosos del modelo
const tags = render('<script>alert(1)</script> <img src=x onerror=alert(1)>');
assert.doesNotMatch(tags, /<script|<img/);
assert.match(tags, /&lt;script&gt;/);
assert.doesNotMatch(render("Texto con [x](javascript:alert(1)) dentro"), /<a /);
assert.doesNotMatch(render("Imagen ![a](http://fuera/i.png) aquí"), /<img|src=/);
assert.match(render("[nota](obsidian://open?vault=T&file=a.md)"), /<a href="obsidian:/);
// LaTeX con \href no abre enlaces (KaTeX sin trust)
assert.doesNotMatch(render("$\\href{javascript:alert(1)}{x}$"), /href="javascript/);

// respuesta a medias (bloque de código sin cerrar) no rompe
assert.ok(render("Mira:\n```c\nint x = $y;").includes("int x"));
console.log("OK: render de trucha-copilot-app");
