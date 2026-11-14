// Trucha Copilot — interfaz. Habla con trucha-copilot-app (Python) por mensajes:
//   página → Python: ready · open · send · stop · delete · source · copy
//   Python → página: Copilot.init · setChats · chatCreated · showChat · askNew · event
"use strict";
const post = msg => window.webkit.messageHandlers.copilot.postMessage(JSON.stringify(msg));
const render = makeRender(marked, katex);
const $ = sel => document.querySelector(sel);
const hilo = $("#hilo"), entrada = $("#entrada"), enviar = $("#enviar"), razonar = $("#razonar");

const ESTADOS = {
  idle: "Lista para nadar en tus apuntes",
  searching: "Buscando en tus apuntes…",
  thinking: "Pensando…",
  answering: "Respondiendo…",
  confused: "Eso no está en tus apuntes",
};
const state = { chat: null, chats: [], busy: false, turn: null, moodTimer: 0 };

function mood(m, ms) {
  clearTimeout(state.moodTimer);
  $("#mascota").dataset.mood = m;
  $("#estado").textContent = ESTADOS[m];
  if (ms) state.moodTimer = setTimeout(() => mood("idle"), ms);
}

function el(tag, cls, text) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
}

function nearBottom() { return hilo.scrollHeight - hilo.scrollTop - hilo.clientHeight < 80; }
function scrollDown(force) { if (force || nearBottom()) hilo.scrollTop = hilo.scrollHeight; }

function setBusy(busy) {
  state.busy = busy;
  enviar.textContent = busy ? "Parar" : "Enviar";
  enviar.classList.toggle("parar", busy);
}

function clearThread() {
  hilo.querySelectorAll(".msg").forEach(m => m.remove());
  $("#vacio").hidden = false;
}

function addUser(text) {
  $("#vacio").hidden = true;
  const m = el("div", "msg user");
  m.append(el("div", "burbuja", text));
  hilo.append(m);
  scrollDown(true);
}

function addBot({ content = "", thinking = "", sources = null } = {}) {
  $("#vacio").hidden = true;
  const m = el("div", "msg bot");
  const det = el("details", "razonamiento");
  det.append(el("summary", "", "Razonamiento"), el("div", "texto", thinking));
  det.hidden = !thinking;
  const md = el("div", "md");
  md.innerHTML = render(content);
  const fuentes = el("div", "fuentes");
  const acciones = el("div", "acciones");
  const copiar = el("button", "", "Copiar");
  copiar.type = "button";
  acciones.append(copiar);
  acciones.hidden = !content;
  m.append(det, md, fuentes, acciones);
  hilo.append(m);
  const turn = { m, det, md, fuentes, acciones, content, thinking, frame: 0 };
  copiar.onclick = () => { post({ cmd: "copy", text: turn.content }); copiar.textContent = "Copiado"; setTimeout(() => copiar.textContent = "Copiar", 1500); };
  if (sources) showSources(turn, sources);
  return turn;
}

function showSources(turn, sources) {
  turn.fuentes.replaceChildren();
  if (!sources.items || !sources.items.length) return;
  turn.fuentes.append(el("span", "titulo", sources.cited ? "Fuentes" : "Consultado"));
  for (const s of sources.items) {
    const b = el("button", "fuente");
    b.type = "button";
    b.title = `${s.path}\nClic: abrir en Obsidian`;
    b.append(el("b", "", `[${s.n}]`), document.createTextNode(s.head));
    b.onclick = () => post({ cmd: "source", path: s.path });
    turn.fuentes.append(b);
  }
}

function paint(turn) {   // como mucho una vez por fotograma
  if (turn.frame) return;
  turn.frame = requestAnimationFrame(() => {
    turn.frame = 0;
    const stick = nearBottom();
    turn.md.innerHTML = render(turn.content);
    turn.det.querySelector(".texto").textContent = turn.thinking;
    turn.det.hidden = !turn.thinking;
    scrollDown(stick);
  });
}

function send(text) {
  text = text.trim();
  if (!text || state.busy) return;
  let think = razonar.getAttribute("aria-pressed") === "true";
  if (text.startsWith("!")) { think = true; text = text.replace(/^!+\s*/, ""); if (!text) return; }
  addUser(text);
  state.turn = addBot();
  state.turn.md.classList.add("escribiendo");
  setBusy(true);
  mood("searching");
  post({ cmd: "send", chat: state.chat, text, think });
}

function renderChats(chats = state.chats) {
  state.chats = chats;
  const nav = $("#chats");
  nav.replaceChildren();
  for (const c of chats) {
    const row = el("div", "chat" + (c.id === state.chat ? " activo" : ""));
    const abrir = el("button", "abrir", c.title);
    abrir.type = "button";
    abrir.title = c.title;
    abrir.onclick = () => { if (!state.busy) post({ cmd: "open", chat: c.id }); };
    const borrar = el("button", "borrar", "✕");
    borrar.type = "button";
    borrar.title = "Borrar chat";
    borrar.setAttribute("aria-label", `Borrar «${c.title}»`);
    borrar.onclick = () => {
      if (state.busy || !confirm(`¿Borrar el chat «${c.title}»? No se puede deshacer.`)) return;
      if (c.id === state.chat) newChat();
      post({ cmd: "delete", chat: c.id });
    };
    row.append(abrir, borrar);
    nav.append(row);
  }
}

function newChat() {
  if (state.busy) return;
  state.chat = null;
  state.turn = null;
  clearThread();
  renderChats();
  entrada.focus();
}

window.Copilot = {
  init({ theme, chats }) {
    const css = document.documentElement.style;
    const vars = { accent: "--accent", accentBright: "--accent-bright", accentDark: "--accent-dark", bone: "--bone",
                   ash: "--ash", surface: "--surface", card: "--card", track: "--track" };
    for (const [k, v] of Object.entries(vars)) if (theme[k]) css.setProperty(v, theme[k]);
    if (theme.kanji) { $("#hanko-kanji").textContent = theme.kanji; $("#vacio-kanji").textContent = theme.kanji; }
    renderChats(chats);
    mood("idle");
    entrada.focus();
  },
  setChats: renderChats,
  chatCreated(id, chats) { state.chat = id; renderChats(chats); },
  showChat(id, msgs) {
    state.chat = id;
    state.turn = null;
    clearThread();
    for (const m of msgs) m.role === "user" ? addUser(m.content) : addBot(m);
    renderChats();
    scrollDown(true);
  },
  askNew(q) { newChat(); send(q); },
  event(chat, kind, data) {
    const turn = chat === state.chat ? state.turn : null;
    if (kind === "searched") mood("thinking");
    else if (kind === "thinking" && turn) { turn.thinking += data; paint(turn); }
    else if (kind === "content") {
      if ($("#mascota").dataset.mood !== "answering") mood("answering");
      if (turn) { turn.content += data; paint(turn); }
    } else if (kind === "done") {
      setBusy(false);
      mood(data.confused ? "confused" : "idle", data.confused ? 6000 : 0);
      if (turn) {
        turn.md.classList.remove("escribiendo");
        paint(turn);
        showSources(turn, data.sources);
        turn.acciones.hidden = !turn.content;
        if (data.stopped) turn.fuentes.prepend(el("span", "titulo", "(parado)"));
      }
      entrada.focus();
    } else if (kind === "error") {
      setBusy(false);
      mood("confused", 6000);
      if (turn) { turn.md.classList.remove("escribiendo"); turn.md.replaceChildren(el("div", "error", data)); }
    }
  },
};

$("#redactor").addEventListener("submit", e => {
  e.preventDefault();
  if (state.busy) { post({ cmd: "stop" }); return; }
  send(entrada.value);
  entrada.value = "";
  entrada.style.height = "";
});
entrada.addEventListener("keydown", e => {
  if (e.key === "Enter" && !e.shiftKey && !e.isComposing) { e.preventDefault(); $("#redactor").requestSubmit(); }
});
entrada.addEventListener("input", () => { entrada.style.height = ""; entrada.style.height = entrada.scrollHeight + "px"; });
razonar.addEventListener("click", () => razonar.setAttribute("aria-pressed", String(razonar.getAttribute("aria-pressed") !== "true")));
$("#nuevo").addEventListener("click", newChat);
post({ cmd: "ready" });
