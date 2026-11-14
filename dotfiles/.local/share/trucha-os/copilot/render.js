// Markdown + LaTeX seguros para las respuestas de Trucha Copilot.
// Las fórmulas se apartan antes de marked (si no, rompe \\ y _) y se pintan con KaTeX al final.
// El HTML crudo se escapa y solo se enlaza a http(s) u obsidian: el texto viene del modelo.
(function (root) {
  const MATH = /\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]|\\\(([\s\S]+?)\\\)|\$([^$\n]+?)\$/g;
  const CODE = /(```[\s\S]*?(?:```|$)|`[^`\n]*`)/;   // el código se deja tal cual (p. ej. $HOME)
  const ESC = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };
  const esc = s => String(s).replace(/[&<>"']/g, c => ESC[c]);

  function makeRender(marked, katex) {
    marked.use({
      gfm: true,
      renderer: {
        html: html => esc(html),
        link: (href, title, text) => /^(https?|obsidian):/i.test(href || "") ? `<a href="${esc(href)}">${text}</a>` : text,
        image: (href, title, text) => esc(text || ""),
      },
    });
    return function render(md) {
      const math = [];
      const text = String(md).split(CODE).map((part, i) => i % 2 ? part : part.replace(MATH, (m, d1, d2, i1, i2) => {
        math.push({ tex: d1 ?? d2 ?? i1 ?? i2, display: d1 !== undefined || d2 !== undefined });
        return `@@M${math.length - 1}@@`;
      })).join("");
      return marked.parse(text).replace(/@@M(\d+)@@/g, (_, k) =>
        katex.renderToString(math[k].tex, { displayMode: math[k].display, throwOnError: false }));
    };
  }

  root.makeRender = makeRender;
  if (typeof module !== "undefined") module.exports = makeRender;
})(typeof window !== "undefined" ? window : globalThis);
