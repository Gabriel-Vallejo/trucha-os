// Fangames: pinta la biblioteca que le pasa trucha-fangames y le devuelve las órdenes (jugar, carpeta, log).
// Todo el texto entra con textContent: los manifiestos son archivos del usuario, no HTML de confianza.
"use strict";

const Fangames = (() => {
  const $ = (sel) => document.querySelector(sel);
  const ESTADOS = { jugable: "#4ac982", beta: "#f0b648", "en pruebas": "#8a8580" };
  let datos = { juegos: [], avisos: [], en_juego: [] };
  let actual = null;
  let temporizador = null;

  const enviar = (cmd, extra = {}) =>
    window.webkit?.messageHandlers?.fangames?.postMessage(JSON.stringify({ cmd, ...extra }));

  function el(tag, attrs = {}, ...hijos) {
    const n = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs)) {
      if (k === "class") n.className = v;
      else if (k === "style") n.style.cssText = v;
      else if (k.startsWith("on")) n.addEventListener(k.slice(2), v);
      else if (v !== false && v != null) n.setAttribute(k, v === true ? "" : v);
    }
    for (const h of hijos.flat()) if (h != null && h !== false && h !== "") n.append(h instanceof Node ? h : String(h));
    return n;
  }

  const inicial = (nombre) => (nombre.replace(/^pok[eé]mon\s+/i, "")[0] || "?").toUpperCase();

  function cuando(segundos) {
    if (!segundos) return "nunca";
    const dias = Math.floor((Date.now() / 1000 - segundos) / 86400);
    if (dias <= 0) return "hoy";
    if (dias === 1) return "ayer";
    if (dias < 30) return `hace ${dias} días`;
    return new Date(segundos * 1000).toLocaleDateString("es-ES", { day: "numeric", month: "short", year: "numeric" });
  }

  function tiempo(minutos) {
    if (!minutos) return "0 min";
    const h = Math.floor(minutos / 60);
    return h ? `${h} h ${minutos % 60} min` : `${minutos} min`;
  }

  const jugando = (j) => datos.en_juego.includes(j.id);
  const colorDe = (j) => j.color || getComputedStyle(document.documentElement).getPropertyValue("--accent").trim();

  function pintarLista() {
    $("#lista").replaceChildren(...datos.juegos.map((j) => {
      const punto = jugando(j) ? "punto jugando" : j.listo ? "punto listo" : "punto";
      const linea = jugando(j) ? "jugando ahora" : j.listo ? j.motor_nombre : "falta algo";
      return el("button", {
        class: "juego" + (j.id === actual ? " activo" : ""), style: `--color:${colorDe(j)}`,
        "data-id": j.id, onclick: () => elegir(j.id),
        ondblclick: () => j.listo && enviar("jugar", { id: j.id }),
      }, el("span", { class: "ficha-mini" }, j.logo ? el("img", { src: j.logo, alt: "" }) : inicial(j.nombre)),
        el("span", {}, el("div", { class: "titulo" }, j.nombre),
          el("div", { class: "linea" }, el("span", { class: punto }), linea)));
    }));
  }

  function problema(j) {
    if (!j.instalado) return `No encuentro el juego en ${j.ruta}. Descomprímelo ahí.`;
    if (!j.motor_listo) return `Falta el motor ${j.motor_nombre} en ~/Juegos/fangames/_runtimes.`;
    return null;
  }

  function pintarVacio() {
    $("#fondo").style.backgroundImage = "";
    $("#contenido").replaceChildren(el("div", { class: "vacio" },
      el("div", { class: "kanji" }, "遊"),
      el("p", {}, "No hay ningún fangame en el catálogo."),
      el("p", {}, "Añade un ", el("code", {}, "<id>.toml"), " en ", el("code", {}, "~/.config/trucha-os/fangames"),
        " y pulsa Recargar."),
      ...datos.avisos.map((a) => el("p", { class: "problema" }, a))));
  }

  function pintarFicha() {
    const j = datos.juegos.find((x) => x.id === actual);
    if (!j) return pintarVacio();
    document.documentElement.style.setProperty("--juego", colorDe(j));
    const imagen = j.fondo || j.logo;
    $("#fondo").style.backgroundImage = imagen ? `url("${imagen}")` : "";
    const meta = [j.autor, j.version && `v${j.version.replace(/^v/i, "")}`].filter(Boolean).join(" · ");
    const fallo = problema(j);
    const enMarcha = jugando(j);
    $("#contenido").replaceChildren(...[
      j.logo ? el("img", { class: "logo", src: j.logo, alt: j.nombre }) : el("div", { class: "monograma" }, inicial(j.nombre)),
      el("div", {}, el("h1", {}, j.nombre), meta && el("div", { class: "meta" }, meta)),
      el("div", { class: "chips" },
        el("span", { class: "chip", style: `--c:${ESTADOS[j.estado] || "#8a8580"}` }, j.estado),
        el("span", { class: "chip", style: `--c:${colorDe(j)}` }, j.motor_nombre),
        ...j.etiquetas.map((t) => el("span", { class: "chip" }, t))),
      j.descripcion && el("p", { class: "descripcion" }, j.descripcion),
      fallo && el("div", { class: "problema" }, "⚠ " + fallo),
      el("div", { class: "acciones" },
        el("button", { class: "jugar", disabled: !j.listo || enMarcha, onclick: () => enviar("jugar", { id: j.id }) },
          enMarcha ? "Jugando…" : "▶  Jugar"),
        el("button", { class: "secundario", onclick: () => enviar("carpeta", { id: j.id }) }, "Carpeta"),
        j.ultima_vez && el("button", { class: "secundario", onclick: () => enviar("log", { id: j.id }) }, "Log")),
      el("div", { class: "datos" },
        el("span", {}, el("b", {}, cuando(j.ultima_vez)), "última partida"),
        el("span", {}, el("b", {}, tiempo(j.minutos)), "jugado")),
    ].filter(Boolean));   // replaceChildren pintaría «null» por cada hueco
  }

  function elegir(id) {
    actual = id;
    pintarLista();
    pintarFicha();
    document.querySelector(`.juego[data-id="${CSS.escape(id)}"]`)?.scrollIntoView({ block: "nearest" });
  }

  function mover(paso) {
    const ids = datos.juegos.map((j) => j.id);
    if (!ids.length) return;
    const i = Math.max(0, ids.indexOf(actual));
    elegir(ids[(i + paso + ids.length) % ids.length]);
  }

  function jugarActual() {
    const j = datos.juegos.find((x) => x.id === actual);
    if (j?.listo && !jugando(j)) enviar("jugar", { id: j.id });
  }

  function aplicarTema(t = {}) {
    const mapa = { accent: "--accent", accentBright: "--accent-bright", accentDark: "--accent-dark", bone: "--bone",
                   ash: "--ash", surface: "--surface", card: "--card", track: "--track" };
    for (const [k, v] of Object.entries(mapa)) if (t[k]) document.documentElement.style.setProperty(v, t[k]);
  }

  // ── teclado y mando ──
  document.addEventListener("keydown", (e) => {
    const enBotonDeAccion = e.target instanceof HTMLButtonElement && !e.target.classList.contains("juego");
    if (e.key === "ArrowDown") { mover(1); e.preventDefault(); }
    else if (e.key === "ArrowUp") { mover(-1); e.preventDefault(); }
    else if (e.key === "Enter" && !enBotonDeAccion) { jugarActual(); e.preventDefault(); }
    else if (e.key === "F5") { enviar("recargar"); e.preventDefault(); }
  });

  const pulsados = new Set();
  function sondearMando() {
    for (const p of navigator.getGamepads?.() || []) {
      if (!p) continue;
      const eje = p.axes[1] || 0;
      const botones = { abajo: p.buttons[13]?.pressed || eje > 0.6, arriba: p.buttons[12]?.pressed || eje < -0.6,
                        a: p.buttons[0]?.pressed };
      for (const [k, v] of Object.entries(botones)) {
        const clave = `${p.index}:${k}`;
        if (v && !pulsados.has(clave)) {
          pulsados.add(clave);
          if (k === "abajo") mover(1); else if (k === "arriba") mover(-1); else jugarActual();
        } else if (!v) pulsados.delete(clave);
      }
    }
    requestAnimationFrame(sondearMando);
  }
  window.addEventListener("gamepadconnected", () => requestAnimationFrame(sondearMando), { once: true });

  $("#recargar").addEventListener("click", () => enviar("recargar"));

  return {
    enviar,
    cargar(nuevos) {
      datos = { juegos: [], avisos: [], en_juego: [], ...nuevos };
      aplicarTema(nuevos.tema);
      if (!datos.juegos.some((j) => j.id === actual)) actual = datos.juegos[0]?.id ?? null;
      pintarLista();
      pintarFicha();
    },
    aviso(texto) {
      const caja = $("#aviso");
      caja.textContent = texto;
      caja.classList.add("visible");
      clearTimeout(temporizador);
      temporizador = setTimeout(() => caja.classList.remove("visible"), 6000);
    },
  };
})();

window.Fangames = Fangames;
Fangames.enviar("ready");
