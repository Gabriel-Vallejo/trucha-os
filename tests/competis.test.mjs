// Pruebas de la lógica de la cola de competis (CTFtime + lista propia).  node tests/competis.test.mjs
import fs from "node:fs";
import assert from "node:assert/strict";
const src = fs.readFileSync(new URL("../dotfiles/.config/dms/plugins/truchaCompetis/competis.js", import.meta.url), "utf8").replace(".pragma library", "");
const C = new Function(src + "; return { desdeCtftime, desdePropias, cola, cuenta };")();
const eq = (a, b) => assert.deepEqual(a, b);

const H = 3600e3, D = 24 * H;
const ahora = Date.UTC(2026, 10, 26, 12);
const iso = (ms) => new Date(ms).toISOString();

// CTFtime: solo online; título y url de ctftime
const ctf = C.desdeCtftime([
    { title: "RedReaper CTF", start: iso(ahora + D), finish: iso(ahora + D + 8 * H), ctftime_url: "https://ctftime.org/event/3502/", onsite: false, weight: 0 },
    { title: "Presencial CTF", start: iso(ahora + 2 * D), finish: iso(ahora + 3 * D), ctftime_url: "https://ctftime.org/event/1/", onsite: true, weight: 50 },
    { title: "Roto", start: "no es fecha", finish: iso(ahora), ctftime_url: "x", onsite: false },
]);
eq(ctf.map(e => e.nombre), ["RedReaper CTF"]);
eq(ctf[0].propia, false);
eq(C.desdeCtftime(null), []);
eq(C.desdeCtftime({ error: "rate limit" }), []);

// lista propia: fechas ISO, se descartan entradas sin nombre o sin fechas válidas
const propias = C.desdePropias([
    { nombre: "Talent4Cyber", inicio: iso(ahora + 10 * D), fin: iso(ahora + 11 * D), url: "https://example.org" },
    { nombre: "", inicio: iso(ahora), fin: iso(ahora + D) },
    { nombre: "Sin fin", inicio: iso(ahora) },
]);
eq(propias.map(e => [e.nombre, e.propia]), [["Talent4Cyber", true]]);
eq(C.desdePropias("basura"), []);

// cola: fuera lo terminado, primero lo que está en marcha, luego por fecha; las propias siempre entran
const enMarcha = { nombre: "Ya empezó", inicio: ahora - H, fin: ahora + 5 * H, url: "", propia: false };
const acabada = { nombre: "Acabada", inicio: ahora - 2 * D, fin: ahora - D, url: "", propia: false };
const muchas = Array.from({ length: 6 }, (_, i) => ({ nombre: "ctf" + i, inicio: ahora + (i + 1) * H, fin: ahora + (i + 2) * H, url: "", propia: false }));
const q = C.cola(propias, [acabada, ...muchas, enMarcha], ahora, 4);
eq(q.map(e => e.nombre), ["Ya empezó", "ctf0", "ctf1", "Talent4Cyber"]);

// cuenta atrás
eq(C.cuenta({ inicio: ahora + 3 * D + 4 * H + 59e3, fin: ahora + 4 * D }, ahora), { texto: "3D 04H", enCurso: false, progreso: 0 });
eq(C.cuenta({ inicio: ahora + 4 * H + 12 * 60e3, fin: ahora + 5 * H }, ahora).texto, "04H 12M");
eq(C.cuenta({ inicio: ahora + 30e3, fin: ahora + H }, ahora).texto, "00H 00M");
const viva = C.cuenta({ inicio: ahora - 2 * H, fin: ahora + 6 * H }, ahora);
eq([viva.texto, viva.enCurso, viva.progreso], ["06H 00M", true, 0.25]);
console.log("competis: ok");
