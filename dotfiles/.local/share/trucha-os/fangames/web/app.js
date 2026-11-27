// Fangames: pinta lo que le pasa trucha-fangames (biblioteca, ajustes, motores) y le devuelve las órdenes.
// Todo el texto entra con textContent: los manifiestos son archivos del usuario, no HTML de confianza.
"use strict";

const Fangames = (() => {
  const $ = (sel) => document.querySelector(sel);
  const ESTADOS = { jugable: "var(--ok)", beta: "var(--warn)", "en pruebas": "var(--ash)" };
  let datos = { juegos: [], avisos: [], en_juego: [], ajustes: {}, motores: [], claude: false, importando: false };
  let actual = null;
  let vista = "biblioteca";
  let origen = null;
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
  const llenar = (nodo, hijos) => nodo.replaceChildren(...hijos.flat().filter((h) => h != null && h !== false && h !== ""));

  const inicial = (nombre) => (nombre.replace(/^pok[eé]mon\s+/i, "")[0] || "?").toUpperCase();
  const jugando = (j) => datos.en_juego.includes(j.id);
  const colorDe = (j) => j.color || getComputedStyle(document.documentElement).getPropertyValue("--accent").trim();
  const urlCss = (u) => `url("${u.replace(/["\\]/g, "\\$&")}")`;

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

  function miniatura(j, clase) {
    if (j.portada) return el("span", { class: clase }, el("img", { src: j.portada, alt: "" }));
    if (j.logo) return el("span", { class: clase }, el("img", { src: j.logo, alt: "", class: "logo-mini" }));
    return el("span", { class: clase }, inicial(j.nombre));
  }

  // ── lateral ──
  function pintarLista() {
    llenar($("#lista"), datos.juegos.map((j) => {
      const punto = jugando(j) ? "punto jugando" : j.listo ? "punto listo" : "punto";
      const linea = jugando(j) ? "jugando ahora" : j.listo ? j.motor_nombre : "falta algo";
      return el("button", {
        class: "juego" + (j.id === actual && vista === "biblioteca" ? " activo" : ""), style: `--color:${colorDe(j)}`,
        "data-id": j.id, onclick: () => elegir(j.id), ondblclick: () => j.listo && enviar("jugar", { id: j.id }),
      }, miniatura(j, "ficha-mini"), el("span", {}, el("div", { class: "titulo" }, j.nombre),
        el("div", { class: "linea" }, el("span", { class: punto }), linea)));
    }));
  }

  function cambiarVista(nueva) {
    vista = nueva;
    document.querySelectorAll("#pestanas button").forEach((b) => b.classList.toggle("activa", b.dataset.vista === nueva));
    document.querySelectorAll(".vista").forEach((v) => v.classList.toggle("activa", v.id === `vista-${nueva}`));
    pintarLista();
  }

  // ── ficha ──
  function problema(j) {
    if (!j.instalado) return `No encuentro el juego en ${j.ruta}. Descomprímelo ahí o añádelo desde «＋ Añadir».`;
    if (!j.motor_listo) return `Falta el motor ${j.motor_nombre}: lo tienes en Ajustes → Motores.`;
    return null;
  }

  function filaInfo(etiqueta, valor) {
    return valor ? [el("dt", {}, etiqueta), el("dd", {}, valor)] : [];
  }

  function pintarFicha() {
    const caja = $("#vista-biblioteca");
    const j = datos.juegos.find((x) => x.id === actual);
    if (!j) {
      llenar(caja, [el("div", { class: "vacio" }, el("div", { class: "kanji" }, "遊"),
        el("p", {}, "Todavía no hay ningún fangame en la biblioteca."),
        el("button", { class: "jugar", onclick: () => cambiarVista("anadir") }, "＋ Añadir un juego"),
        ...datos.avisos.map((a) => el("p", { class: "nota" }, a)))]);
      return;
    }
    document.documentElement.style.setProperty("--juego", colorDe(j));
    const imagen = j.banner || j.captura || j.fondo || j.logo;
    const meta = [j.autor, j.version && `v${j.version.replace(/^v/i, "")}`].filter(Boolean).join(" · ");
    const enMarcha = jugando(j);
    const web = j.web && /^https?:\/\//.test(j.web) ? el("a", { href: j.web }, j.web.replace(/^https?:\/\/(www\.)?/, "").replace(/\/$/, "")) : null;
    const fallo = problema(j);

    llenar(caja, [
      el("div", { class: "heroe" }, el("div", {
        class: "banner" + (j.banner || j.captura ? "" : " difuso"), style: imagen ? `background-image:${urlCss(imagen)}` : "",
      })),
      el("div", { class: "cabecera" },
        miniatura(j, "portada"),
        el("div", { class: "titular" },
          j.logo && !j.portada ? el("img", { class: "logo", src: j.logo, alt: "" }) : null,
          el("h1", {}, j.nombre),
          meta && el("div", { class: "meta" }, meta),
          el("div", { class: "chips" },
            el("span", { class: "chip", style: `--c:${ESTADOS[j.estado] || "var(--ash)"}` }, j.estado),
            el("span", { class: "chip", style: `--c:${colorDe(j)}` }, j.motor_nombre),
            j.genero && el("span", { class: "chip" }, j.genero),
            ...j.etiquetas.map((t) => el("span", { class: "chip" }, t))))),
      el("div", { class: "acciones" },
        el("button", { class: "jugar", disabled: !j.listo || enMarcha, onclick: () => enviar("jugar", { id: j.id }) },
          enMarcha ? "Jugando…" : "▶  Jugar"),
        el("button", { class: "secundario", onclick: () => enviar("carpeta", { id: j.id }) }, "Carpeta"),
        j.ultima_vez && el("button", { class: "secundario", onclick: () => enviar("log", { id: j.id }) }, "Log"),
        datos.claude && j.instalado && el("button", {
          class: "secundario", disabled: datos.importando, title: "Claude busca su info, le hace portada y banner y lo prueba",
          onclick: () => { cambiarVista("anadir"); enviar("integrar", { id: j.id }); },
        }, "✦ Mejorar con Claude"),
        el("div", { class: "datos" },
          el("span", {}, el("b", {}, cuando(j.ultima_vez)), "última partida"),
          el("span", {}, el("b", {}, tiempo(j.minutos)), "jugado"))),
      fallo && el("div", { class: "problema" }, "⚠ " + fallo),
      el("div", { class: "cuerpo" },
        el("div", { class: "tarjeta" }, el("h3", {}, "Sobre el juego"),
          el("p", { class: "descripcion" }, j.descripcion || "Sin descripción todavía. «Mejorar con Claude» la busca por ti."),
          j.caracteristicas.length > 0 && el("ul", { class: "caracteristicas" }, j.caracteristicas.map((c) => el("li", {}, c))),
          j.captura && el("img", { class: "captura", src: j.captura, alt: `Captura de ${j.nombre}` })),
        el("div", { class: "tarjeta" }, el("h3", {}, "Información"),
          el("dl", { class: "info" },
            filaInfo("Autor", j.autor), filaInfo("Versión", j.version), filaInfo("Género", j.genero),
            filaInfo("Idioma", j.idioma), filaInfo("Región", j.region), filaInfo("Salió", j.lanzamiento),
            filaInfo("Motor", j.motor_nombre), filaInfo("Web", web), filaInfo("Carpeta", j.ruta)),
          j.notas && el("p", { class: "notas" }, j.notas))),
    ]);
    caja.scrollTop = 0;
  }

  function elegir(id) {
    actual = id;
    if (vista !== "biblioteca") cambiarVista("biblioteca");
    pintarLista();
    pintarFicha();
    document.querySelector(`.juego[data-id="${CSS.escape(id)}"]`)?.scrollIntoView({ block: "nearest" });
  }

  function mover(paso) {
    const ids = datos.juegos.map((j) => j.id);
    if (!ids.length) return;
    elegir(ids[(Math.max(0, ids.indexOf(actual)) + paso + ids.length) % ids.length]);
  }

  function jugarActual() {
    const j = datos.juegos.find((x) => x.id === actual);
    if (vista === "biblioteca" && j?.listo && !jugando(j)) enviar("jugar", { id: j.id });
  }

  // ── motores, ajustes y añadir ──
  function pintarMotores() {
    const filas = () => datos.motores.map((m) => el("div", { class: "motor" },
      el("span", { class: m.listo ? "punto listo" : "punto" }),
      el("b", {}, m.nombre),
      el("span", {}, el("small", {}, m.listo ? m.para : `No está instalado · ${m.para}`), el("code", {}, m.ruta))));
    llenar($("#motores-ajustes"), filas());
    llenar($("#motores-anadir"), filas());
  }

  function pintarAjustes() {
    const a = datos.ajustes;
    $("#aj-carpeta").value = a.carpeta_juegos ?? "";
    $("#aj-orden").value = a.orden ?? "recientes";
    $("#aj-minimizar").checked = !!a.minimizar_al_jugar;
    $("#aj-completa").checked = !!a.pantalla_completa;
    $("#aj-escalado").value = a.escalado ?? "nitido";
    $("#aj-no-listos").checked = !!a.mostrar_no_listos;
    $("#aj-claude").checked = !!a.integrar_con_claude;
  }

  function pintarAnadir() {
    const conClaude = $("#con-claude");
    conClaude.disabled = !datos.claude;
    if (!conClaude.dataset.tocado) conClaude.checked = datos.claude && !!datos.ajustes.integrar_con_claude;
    $("#sin-claude").hidden = datos.claude;
    $("#importar").disabled = !origen || datos.importando;
    $("#importar").textContent = datos.importando ? "Trabajando…" : "Añadir a la biblioteca";
  }

  function lineaProgreso(texto, clase) {
    const pre = $("#progreso");
    pre.hidden = false;
    pre.append(el("div", { class: clase || "" }, texto));
    pre.scrollTop = pre.scrollHeight;
  }

  function aplicarTema(t = {}) {
    const mapa = { accent: "--accent", accentBright: "--accent-bright", accentDark: "--accent-dark", bone: "--bone",
                   ash: "--ash", surface: "--surface", card: "--card", track: "--track" };
    for (const [k, v] of Object.entries(mapa)) if (t[k]) document.documentElement.style.setProperty(v, t[k]);
  }

  // ── eventos ──
  document.querySelectorAll("#pestanas button").forEach((b) => b.addEventListener("click", () => cambiarVista(b.dataset.vista)));
  document.querySelectorAll("[data-abrir]").forEach((b) => b.addEventListener("click", (e) => {
    e.preventDefault();
    enviar("abrir", { que: b.dataset.abrir });
  }));
  $("#recargar").addEventListener("click", () => enviar("recargar"));
  $("#elegir-zip").addEventListener("click", () => enviar("elegir_origen", { tipo: "zip" }));
  $("#elegir-carpeta").addEventListener("click", () => enviar("elegir_origen", { tipo: "carpeta" }));
  $("#con-claude").addEventListener("change", (e) => { e.target.dataset.tocado = "1"; });
  $("#importar").addEventListener("click", () => {
    if (!origen || datos.importando) return;
    llenar($("#progreso"), []);
    enviar("importar", { origen, nombre: $("#nombre-nuevo").value, claude: $("#con-claude").checked });
  });
  $("#guardar-ajustes").addEventListener("click", () => enviar("guardar_ajustes", { ajustes: {
    carpeta_juegos: $("#aj-carpeta").value.trim(), orden: $("#aj-orden").value,
    minimizar_al_jugar: $("#aj-minimizar").checked, mostrar_no_listos: $("#aj-no-listos").checked,
    integrar_con_claude: $("#aj-claude").checked,
    pantalla_completa: $("#aj-completa").checked, escalado: $("#aj-escalado").value,
  } }));
  $("#crear-accesos").addEventListener("click", () => enviar("accesos"));

  document.addEventListener("keydown", (e) => {
    const escribiendo = e.target instanceof HTMLInputElement || e.target instanceof HTMLSelectElement;
    const enBotonDeAccion = e.target instanceof HTMLButtonElement && !e.target.classList.contains("juego");
    if (e.key === "F5") { enviar("recargar"); e.preventDefault(); return; }
    if (escribiendo) return;
    if (e.key === "ArrowDown") { mover(1); e.preventDefault(); }
    else if (e.key === "ArrowUp") { mover(-1); e.preventDefault(); }
    else if (e.key === "Enter" && !enBotonDeAccion) { jugarActual(); e.preventDefault(); }
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

  return {
    enviar,
    vista: cambiarVista,
    cargar(nuevos) {
      datos = { ...datos, ...nuevos };
      aplicarTema(nuevos.tema);
      if (!datos.juegos.some((j) => j.id === actual)) actual = datos.juegos[0]?.id ?? null;
      pintarLista();
      pintarFicha();
      pintarMotores();
      pintarAjustes();
      pintarAnadir();
    },
    origen(ruta) {
      origen = ruta;
      const caja = $("#origen");
      caja.textContent = ruta;
      caja.classList.remove("vacio-origen");
      pintarAnadir();
    },
    progreso(p) {
      if (p.linea) lineaProgreso(p.linea, p.linea.startsWith("✘") ? "mal" : p.linea.startsWith("✔") ? "ok" : "");
      if (!p.fin) return;
      if (p.ok) {
        lineaProgreso("Listo. Ya lo tienes en la biblioteca.", "ok");
        origen = null;
        $("#origen").textContent = "Ningún juego elegido";
        $("#origen").classList.add("vacio-origen");
        $("#nombre-nuevo").value = "";
        if (p.id) actual = p.id;
      }
      pintarAnadir();
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
if (["anadir", "ajustes"].includes(location.hash.slice(1))) Fangames.vista(location.hash.slice(1));
Fangames.enviar("ready");
