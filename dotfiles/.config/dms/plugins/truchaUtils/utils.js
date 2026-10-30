.pragma library
// Lógica pura de "Utilidades Trucha" (sin QML): calculadora segura y conversiones típicas de CTF.
// Cada resultado es { name, comment, icon, value }: lo que se ve y lo que se copia al elegirlo.

// ── calculadora: descenso recursivo, sin eval ───────────────────────────────
const FUNCS = {
    sqrt: Math.sqrt, abs: Math.abs, round: Math.round, floor: Math.floor, ceil: Math.ceil,
    sin: Math.sin, cos: Math.cos, tan: Math.tan, ln: Math.log, log: Math.log10, log2: Math.log2, exp: Math.exp
};
const CONSTS = { pi: Math.PI, e: Math.E };

function tokenize(src) {
    const re = /\s*(0x[0-9a-f]+|0b[01]+|\d+(?:\.\d+)?(?:e[+-]?\d+)?|\.\d+|[a-z]\w*|\*\*|[-+*/%^(),!])/gy;
    const out = [];
    let m;
    re.lastIndex = 0;
    while (re.lastIndex < src.length && (m = re.exec(src)) !== null)
        out.push(m[1]);
    if (src.slice(re.lastIndex).trim() !== "")
        return null;
    return out;
}

function calc(input) {
    let src = String(input).toLowerCase().replace(/×/g, "*").replace(/÷/g, "/");
    // coma decimal española (3,5) solo si no hay funciones: en max(1,7) la coma separa argumentos
    if (!/[a-z]/.test(src.replace(/0x[0-9a-f]+|0b[01]+/g, "")))
        src = src.replace(/(\d),(\d)/g, "$1.$2");
    const toks = tokenize(src);
    if (!toks || toks.length === 0)
        return null;
    let i = 0;
    const peek = () => toks[i];
    const eat = (t) => { if (toks[i] !== t) throw "esperaba " + t; i++; };

    // expr := term (('+'|'-') term)*
    function expr() {
        let v = term();
        while (peek() === "+" || peek() === "-")
            v = toks[i++] === "+" ? v + term() : v - term();
        return v;
    }
    // term := unary (('*'|'/'|'%') unary)*
    function term() {
        let v = unary();
        while (peek() === "*" || peek() === "/" || peek() === "%") {
            const op = toks[i++], r = unary();
            v = op === "*" ? v * r : op === "/" ? v / r : v % r;
        }
        return v;
    }
    function unary() {
        if (peek() === "-") { i++; return -unary(); }
        if (peek() === "+") { i++; return unary(); }
        return power();
    }
    // potencia asociativa por la derecha: 2^3^2 = 2^9
    function power() {
        const b = postfix();
        if (peek() === "^" || peek() === "**") { i++; return Math.pow(b, unary()); }
        return b;
    }
    function postfix() {
        let v = atom();
        while (peek() === "!") {
            i++;
            if (v < 0 || v > 170 || v % 1 !== 0) throw "factorial";
            let f = 1;
            for (let k = 2; k <= v; k++) f *= k;
            v = f;
        }
        return v;
    }
    function atom() {
        const t = toks[i++];
        if (t === undefined) throw "fin";
        if (t === "(") { const v = expr(); eat(")"); return v; }
        if (/^0x/.test(t)) return parseInt(t.slice(2), 16);
        if (/^0b/.test(t)) return parseInt(t.slice(2), 2);
        if (/^[\d.]/.test(t)) return parseFloat(t);
        if (t in CONSTS) return CONSTS[t];
        if (t in FUNCS) { eat("("); const v = expr(); eat(")"); return FUNCS[t](v); }
        if (t === "min" || t === "max" || t === "pow") {
            eat("(");
            const args = [expr()];
            while (peek() === ",") { i++; args.push(expr()); }
            eat(")");
            return t === "pow" ? Math.pow(args[0], args[1]) : Math[t].apply(null, args);
        }
        throw "token " + t;
    }

    try {
        const v = expr();
        if (i !== toks.length || !isFinite(v))
            return null;
        return v;
    } catch (e) {
        return null;
    }
}

function fmtNum(v) {
    // quita el ruido de coma flotante (0.1+0.2) sin perder enteros grandes
    return Number.isInteger(v) ? String(v) : String(parseFloat(v.toPrecision(12)));
}

// ── texto ↔ bytes (UTF-8) y codificaciones ──────────────────────────────────
function utf8(s) {
    const b = [];
    for (const ch of s) {
        let c = ch.codePointAt(0);
        if (c < 0x80) b.push(c);
        else if (c < 0x800) b.push(0xc0 | c >> 6, 0x80 | c & 63);
        else if (c < 0x10000) b.push(0xe0 | c >> 12, 0x80 | c >> 6 & 63, 0x80 | c & 63);
        else b.push(0xf0 | c >> 18, 0x80 | c >> 12 & 63, 0x80 | c >> 6 & 63, 0x80 | c & 63);
    }
    return b;
}

// null si los bytes no son UTF-8 válido (para no enseñar basura al decodificar)
function fromUtf8(b) {
    let s = "";
    for (let i = 0; i < b.length;) {
        const c = b[i];
        const n = c < 0x80 ? 0 : (c & 0xe0) === 0xc0 ? 1 : (c & 0xf0) === 0xe0 ? 2 : (c & 0xf8) === 0xf0 ? 3 : -1;
        if (n < 0 || i + n >= b.length + (n ? 0 : 1)) return null;
        let cp = n ? c & (0x3f >> n) : c;
        for (let k = 1; k <= n; k++) {
            if ((b[i + k] & 0xc0) !== 0x80) return null;
            cp = cp << 6 | b[i + k] & 63;
        }
        if (cp < 32 && cp !== 9 && cp !== 10 && cp !== 13) return null;
        s += String.fromCodePoint(cp);
        i += n + 1;
    }
    return s;
}

const B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

function b64enc(s) {
    const b = utf8(s);
    let out = "";
    for (let i = 0; i < b.length; i += 3) {
        const n = b[i] << 16 | (b[i + 1] ?? 0) << 8 | (b[i + 2] ?? 0);
        out += B64[n >> 18 & 63] + B64[n >> 12 & 63] + (i + 1 < b.length ? B64[n >> 6 & 63] : "=") + (i + 2 < b.length ? B64[n & 63] : "=");
    }
    return out;
}

function b64dec(s) {
    const clean = s.replace(/\s/g, "").replace(/-/g, "+").replace(/_/g, "/").replace(/=+$/, "");
    if (clean.length < 2 || !/^[A-Za-z0-9+/]+$/.test(clean) || clean.length % 4 === 1)
        return null;
    const b = [];
    let buf = 0, bits = 0;
    for (const ch of clean) {
        buf = buf << 6 | B64.indexOf(ch);
        bits += 6;
        if (bits >= 8) { bits -= 8; b.push(buf >> bits & 255); }
    }
    return fromUtf8(b);
}

const hexenc = (s) => utf8(s).map(x => x.toString(16).padStart(2, "0")).join("");

function hexdec(s) {
    const clean = s.replace(/^0x/i, "").replace(/[\s:]/g, "");
    if (clean.length < 2 || clean.length % 2 || !/^[0-9a-f]+$/i.test(clean))
        return null;
    return fromUtf8(clean.match(/../g).map(h => parseInt(h, 16)));
}

const rot13 = (s) => s.replace(/[a-z]/gi, c => String.fromCharCode((c <= "Z" ? 65 : 97) + (c.toLowerCase().charCodeAt(0) - 97 + 13) % 26));
const binenc = (s) => utf8(s).map(x => x.toString(2).padStart(8, "0")).join(" ");

function bindec(s) {
    const clean = s.replace(/\s/g, "");
    if (clean.length < 8 || clean.length % 8 || !/^[01]+$/.test(clean))
        return null;
    return fromUtf8(clean.match(/.{8}/g).map(x => parseInt(x, 2)));
}

function urldec(s) {
    try { return decodeURIComponent(s.replace(/\+/g, " ")); } catch (e) { return null; }
}

// ── números, fechas y colores ───────────────────────────────────────────────
function parseInteger(s) {
    const t = s.trim().toLowerCase();
    if (/^0x[0-9a-f]+$/.test(t)) return parseInt(t, 16);
    if (/^0b[01]+$/.test(t)) return parseInt(t.slice(2), 2);
    if (/^0o[0-7]+$/.test(t)) return parseInt(t.slice(2), 8);
    if (/^\d+$/.test(t)) return parseInt(t, 10);
    return null;
}

const pad2 = (n) => String(n).padStart(2, "0");

function fecha(ms) {
    const d = new Date(ms);
    return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate()) + " " + pad2(d.getHours()) + ":" + pad2(d.getMinutes()) + ":" + pad2(d.getSeconds());
}

function hexColor(s) {
    const m = s.trim().match(/^#?([0-9a-f]{3}|[0-9a-f]{6})$/i);
    if (!m || (!s.trim().startsWith("#") && m[1].length === 3)) return null;
    const h = m[1].length === 3 ? m[1].replace(/./g, c => c + c) : m[1];
    const r = parseInt(h.slice(0, 2), 16), g = parseInt(h.slice(2, 4), 16), b = parseInt(h.slice(4), 16);
    const mx = Math.max(r, g, b) / 255, mn = Math.min(r, g, b) / 255, l = (mx + mn) / 2, d = mx - mn;
    let hue = 0;
    if (d) {
        const R = r / 255, G = g / 255, B = b / 255;
        hue = mx === R ? ((G - B) / d) % 6 : mx === G ? (B - R) / d + 2 : (R - G) / d + 4;
        hue = Math.round(hue * 60 + 360) % 360;
    }
    const sat = d ? d / (1 - Math.abs(2 * l - 1)) : 0;
    return { hex: "#" + h.toLowerCase(), rgb: "rgb(" + r + ", " + g + ", " + b + ")", hsl: "hsl(" + hue + ", " + Math.round(sat * 100) + "%, " + Math.round(l * 100) + "%)" };
}

// ── resultados para el lanzador ─────────────────────────────────────────────
function item(name, comment, icon, value) {
    return { name: name, comment: comment, icon: "material:" + icon, value: value };
}

// prefijos explícitos: "b64 hola", "unhex 686f6c61", "ts 1700000000"...
const PREFIXES = {
    b64: [s => b64enc(s), "Base64", "lock"], b64d: [b64dec, "Base64 → texto", "lock_open"],
    hex: [hexenc, "Hex", "tag"], unhex: [hexdec, "Hex → texto", "tag"],
    rot13: [rot13, "ROT13", "rotate_right"], url: [s => encodeURIComponent(s), "URL", "link"], urld: [urldec, "URL → texto", "link"],
    bin: [binenc, "Binario", "data_array"], unbin: [bindec, "Binario → texto", "data_array"],
    up: [s => s.toUpperCase(), "MAYÚSCULAS", "text_increase"], low: [s => s.toLowerCase(), "minúsculas", "text_decrease"],
    rev: [s => Array.from(s).reverse().join(""), "Al revés", "swap_horiz"], len: [s => String(Array.from(s).length), "Longitud", "straighten"]
};

function results(query, nowMs) {
    const q = (query ?? "").trim();
    const out = [];
    if (q === "")
        return out;

    // marca de tiempo: "ts" sola da la de ahora
    const ts = q.match(/^ts(?:\s+(\d{9,13}))?$/i);
    if (ts) {
        if (!ts[1]) {
            out.push(item(String(Math.floor(nowMs / 1000)), "Unix ahora · " + fecha(nowMs), "schedule", String(Math.floor(nowMs / 1000))));
        } else {
            const ms = ts[1].length > 10 ? Number(ts[1]) : Number(ts[1]) * 1000;
            out.push(item(fecha(ms), "Unix → fecha local", "schedule", fecha(ms)));
            out.push(item(new Date(ms).toISOString(), "Unix → ISO 8601 (UTC)", "public", new Date(ms).toISOString()));
        }
        return out;
    }

    const sp = q.indexOf(" ");
    const head = sp > 0 ? q.slice(0, sp).toLowerCase() : "";
    if (head in PREFIXES) {
        const [fn, label, icon] = PREFIXES[head];
        const r = fn(q.slice(sp + 1));
        out.push(r === null ? item("No se puede convertir", label, "error", "") : item(r, label, icon, r));
        return out;
    }

    const color = hexColor(q);
    if (color) {
        out.push(item(color.rgb, "Color " + color.hex, "palette", color.rgb));
        out.push(item(color.hsl, "Color " + color.hex, "palette", color.hsl));
        return out;
    }

    const n = parseInteger(q);
    if (n !== null && Number.isSafeInteger(n)) {
        out.push(item(String(n), "Decimal", "pin", String(n)));
        out.push(item("0x" + n.toString(16), "Hexadecimal", "tag", "0x" + n.toString(16)));
        out.push(item("0b" + n.toString(2), "Binario", "data_array", "0b" + n.toString(2)));
        out.push(item("0o" + n.toString(8), "Octal", "filter_8", "0o" + n.toString(8)));
        if (n >= 32 && n < 0x110000)
            out.push(item(String.fromCodePoint(n), "Carácter U+" + n.toString(16).toUpperCase().padStart(4, "0"), "text_fields", String.fromCodePoint(n)));
        if (q.length >= 9 && q.length <= 13 && /^\d+$/.test(q)) {
            const ms = q.length > 10 ? n : n * 1000;
            out.push(item(fecha(ms), "Si es un timestamp Unix", "schedule", fecha(ms)));
        }
        return out;
    }

    const v = calc(q);
    if (v !== null) {
        out.push(item("= " + fmtNum(v), q, "calculate", fmtNum(v)));
        if (Number.isInteger(v) && Math.abs(v) < 2 ** 53 && v >= 0)
            out.push(item("0x" + v.toString(16), "En hexadecimal", "tag", "0x" + v.toString(16)));
        return out;
    }

    // texto libre: primero lo que se pueda decodificar, luego las codificaciones
    const dec = [[b64dec(q), "Base64 → texto"], [hexdec(q), "Hex → texto"], [bindec(q), "Binario → texto"]];
    if (/%[0-9a-f]{2}/i.test(q)) dec.push([urldec(q), "URL → texto"]);
    for (const [r, label] of dec)
        if (r !== null && r !== q) out.push(item(r, label, "lock_open", r));
    out.push(item(b64enc(q), "Base64", "lock", b64enc(q)));
    out.push(item(hexenc(q), "Hex", "tag", hexenc(q)));
    out.push(item(rot13(q), "ROT13", "rotate_right", rot13(q)));
    out.push(item(encodeURIComponent(q), "URL", "link", encodeURIComponent(q)));
    return out;
}
