.pragma library
// Lógica pura de la cola de competis (sin QML). Un evento es { nombre, inicio, fin, url, propia }
// con inicio y fin en milisegundos.

const MIN = 60e3, HORA = 60 * MIN, DIA = 24 * HORA;

function evento(nombre, inicio, fin, url, propia) {
    const a = Date.parse(inicio), b = Date.parse(fin);
    if (!nombre || isNaN(a) || isNaN(b) || b <= a)
        return null;
    // solo webs: un file:// o similar no se abre al hacer clic
    const web = /^https?:\/\//i.test(String(url ?? "")) ? String(url) : "";
    return { nombre: String(nombre), inicio: a, fin: b, url: web, propia: propia };
}

// Respuesta de https://ctftime.org/api/v1/events/ ; los presenciales no interesan
function desdeCtftime(lista) {
    if (!Array.isArray(lista))
        return [];
    return lista.filter(e => e && !e.onsite)
        .map(e => evento(e.title, e.start, e.finish, e.ctftime_url, false))
        .filter(e => e !== null);
}

// ~/.config/trucha-os/competis.json: [{ "nombre", "inicio", "fin", "url" }] con fechas ISO 8601
function desdePropias(lista) {
    if (!Array.isArray(lista))
        return [];
    return lista.map(e => e && evento(e.nombre, e.inicio, e.fin, e.url, true)).filter(e => e);
}

function ordenar(lista, ahora) {
    const clave = e => (e.inicio <= ahora ? 0 : 1);
    return lista.slice().sort((x, y) => clave(x) - clave(y) || x.inicio - y.inicio);
}

// Lo que se ve: primero lo que está en marcha, luego por fecha. Las propias entran siempre.
function cola(propias, ctf, ahora, max) {
    const vivas = l => ordenar(l.filter(e => e.fin > ahora), ahora);
    const mias = vivas(propias).slice(0, max);
    return ordenar(mias.concat(vivas(ctf).slice(0, max - mias.length)), ahora);
}

const dos = n => (n < 10 ? "0" : "") + n;

// "3D 04H" si falta un día o más, si no "04H 12M"; en marcha cuenta lo que queda para acabar
function cuenta(e, ahora) {
    const enCurso = e.inicio <= ahora;
    const falta = Math.max(0, (enCurso ? e.fin : e.inicio) - ahora);
    const d = Math.floor(falta / DIA), h = Math.floor(falta % DIA / HORA), m = Math.floor(falta % HORA / MIN);
    return {
        texto: d > 0 ? d + "D " + dos(h) + "H" : dos(h) + "H " + dos(m) + "M",
        enCurso: enCurso,
        progreso: enCurso ? Math.min(1, (ahora - e.inicio) / (e.fin - e.inicio)) : 0
    };
}
