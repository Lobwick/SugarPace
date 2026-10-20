/* Tiny video engine for the SugarPace presentation videos.
 *
 * Every frame is a PURE function of the time t: render(t) redraws everything from t,
 * with no hidden state and no unseeded randomness. Playing, seeking and the frame-by-frame
 * export (render.py -> window.renderFrame) therefore give identical images.
 *
 * Page parameters:  ?lang=en|fr   ?res=1|1.5|2  (1 = 1280x720)   ?t=12.5 (show one frame)
 * All data shown is fictional.
 */
"use strict";

const W = 1280, H = 720;
const params = new URLSearchParams(location.search);
const LANG = params.get("lang") === "fr" ? "fr" : "en";
const RES = parseFloat(params.get("res") || "1");
const TIMING = window.TIMING[LANG];

const C = {
  bg: "#0B0D10", bg2: "#141b23", panel: "#161c24", line: "#2c343f",
  ink: "#ffffff", soft: "#c9d1d9", faint: "#8b96a3",
  green: "#00C853", orange: "#FF9100", red: "#ff5252", yellow: "#FFD600", blue: "#2979ff",
};
const FONT = '-apple-system, "SF Pro Display", "Helvetica Neue", Helvetica, Arial, sans-serif';

const canvas = document.getElementById("c");
canvas.width = Math.round(W * RES);
canvas.height = Math.round(H * RES);
const ctx = canvas.getContext("2d");

/* ------------------------------ helpers ---------------------------------- */
const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
const ease = (v) => { v = clamp(v); return v * v * (3 - 2 * v); };
const lerp = (a, b, v) => a + (b - a) * v;
/* progress of lt between a and b, eased */
const prog = (lt, a, b) => ease((lt - a) / (b - a));

function rr(x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}
function fillRR(x, y, w, h, r, color, alpha = 1) {
  ctx.save(); ctx.globalAlpha *= alpha; ctx.fillStyle = color; rr(x, y, w, h, r); ctx.fill(); ctx.restore();
}
function strokeRR(x, y, w, h, r, color, lw = 2, alpha = 1) {
  ctx.save(); ctx.globalAlpha *= alpha; ctx.strokeStyle = color; ctx.lineWidth = lw; rr(x, y, w, h, r); ctx.stroke(); ctx.restore();
}
function txt(s, x, y, size, color = C.ink, align = "left", weight = "600", alpha = 1) {
  ctx.save();
  ctx.globalAlpha *= alpha;
  ctx.fillStyle = color;
  ctx.font = weight + " " + size + "px " + FONT;
  ctx.textAlign = align;
  ctx.textBaseline = "alphabetic";
  ctx.fillText(s, x, y);
  ctx.restore();
}
function measure(s, size, weight = "600") {
  ctx.save(); ctx.font = weight + " " + size + "px " + FONT; const w = ctx.measureText(s).width; ctx.restore(); return w;
}
function wrap(s, maxW, size, weight = "600") {
  const words = s.split(" "), lines = []; let cur = "";
  for (const w of words) {
    const t = cur ? cur + " " + w : w;
    if (measure(t, size, weight) > maxW && cur) { lines.push(cur); cur = w; } else cur = t;
  }
  if (cur) lines.push(cur);
  return lines;
}
function circle(x, y, r, color, alpha = 1) {
  ctx.save(); ctx.globalAlpha *= alpha; ctx.fillStyle = color; ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill(); ctx.restore();
}
function line(x1, y1, x2, y2, color, lw = 2, alpha = 1, dash) {
  ctx.save(); ctx.globalAlpha *= alpha; ctx.strokeStyle = color; ctx.lineWidth = lw;
  if (dash) ctx.setLineDash(dash);
  ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke(); ctx.restore();
}
function background(a = "#141b23", b = C.bg) {
  const g = ctx.createRadialGradient(W * 0.7, H * 0.4, 50, W * 0.5, H * 0.5, W * 0.8);
  g.addColorStop(0, a); g.addColorStop(1, b);
  ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
}
/* a finger touch: ripple around (x, y) starting at time `at` */
function touch(lt, at, x, y) {
  const p = (lt - at) / 0.9;
  if (p < 0 || p > 1) return;
  circle(x, y, 14 + 40 * p, C.ink, 0.45 * (1 - p));
  circle(x, y, 12, C.ink, 0.85 * (1 - p * 0.6));
}
/* a labelled callout: text at (tx, ty) joined by a line to the point (px, py) */
function callout(lt, at, s, tx, ty, px, py, side = "R") {
  const p = prog(lt, at, at + 0.5);
  if (p <= 0) return;
  ctx.save();
  ctx.globalAlpha *= p;
  line(side === "L" ? tx + 14 : tx - 14, ty - 9, px, py, C.faint, 1.5, 1, [4, 4]);
  circle(px, py, 5, C.green);
  txt(s, tx, ty, 26, C.ink, side === "L" ? "right" : "left", "600");
  ctx.restore();
}

/* --------------------------- the Edge screen ------------------------------ */
const GLUCOSE = [152, 158, 166, 172, 168, 160, 150, 142, 134, 128, 122, 118, 116, 120, 126, 130, 128, 124, 120, 116,
  114, 112, 111, 112, 113, 112, 111, 112, 112, 112, 113, 112, 112, 111, 112, 112, 112, 112, 112, 112];

/* Draws the device at (dx, dy); returns the anchors of the main elements. */
function edgeBody(dx, dy) {
  fillRR(dx, dy, 330, 560, 36, "#1a1f26");
  strokeRR(dx, dy, 330, 560, 36, C.line, 3);
  fillRR(dx + 20, dy + 20, 290, 520, 20, "#000");
  return { sx: dx + 20, sy: dy + 20 };
}
function glyph(kind, cx, cy, alpha = 1) {
  ctx.save(); ctx.globalAlpha *= alpha;
  if (kind === "gel") { fillRR(cx - 11, cy - 28, 22, 56, 11, "#d9534f"); fillRR(cx - 6, cy - 34, 12, 10, 3, "#eee"); }
  else if (kind === "jelly") { fillRR(cx - 28, cy - 18, 56, 36, 10, "#f0ad4e"); }
  else { fillRR(cx - 32, cy - 15, 64, 30, 8, "#8a6d3b"); }
  ctx.restore();
}
/* state: { value, valueColor, fresh, freshColor, bars (0..1 reveal), profile, arrow, tiles:[{label, kind, mode}] } */
function mainScreen(dx, dy, st) {
  const { sx, sy } = edgeBody(dx, dy);
  const valText = String(st.value);
  txt(valText, sx + 16, sy + 70, 62, st.valueColor || C.green, "left", "700");
  const vw = measure(valText, 62, "700");
  txt(st.unit || "mg/dL", sx + 16 + vw + 8, sy + 68, 16, C.ink, "left", "500");
  txt(st.arrow || "→", sx + 16 + vw + 8 + measure(st.unit || "mg/dL", 16, "500") + 10, sy + 66, 30, st.valueColor || C.green, "left", "700");
  txt(st.fresh || "", sx + 290 - 14, sy + 40, 14, st.freshColor || C.faint, "right", "500");
  if (st.profile) {
    circle(sx + 22, sy + 96, 5, C.blue);
    txt(st.profile, sx + 34, sy + 101, 15, C.ink, "left", "500");
  }
  // chart
  const cx0 = sx + 16, cw = 258, cy1 = sy + 192, ch = 80, n = GLUCOSE.length, bw = cw / n;
  const shown = Math.floor(clamp(st.bars === undefined ? 1 : st.bars) * n);
  for (let i = 0; i < shown; i++) {
    const h = Math.max(3, (GLUCOSE[i] - 90) / 90 * ch);
    ctx.fillStyle = C.soft; ctx.fillRect(cx0 + i * bw + 1, cy1 - h, bw - 2, h);
  }
  txt("4h ago", cx0, sy + 208, 11, C.faint, "left", "500");
  txt("2h ago", cx0 + cw / 2, sy + 208, 11, C.faint, "center", "500");
  txt("Now", cx0 + cw, sy + 208, 11, C.faint, "right", "500");
  // tiles
  const tiles = st.tiles || [];
  tiles.forEach((t, i) => {
    const col = i % 2, row = Math.floor(i / 2), tw = 124, th = 134;
    const x = sx + 14 + col * (tw + 8), y = sy + 222 + row * (th + 8);
    const mode = t.mode || "idle";
    const fill = mode === "pending" ? C.orange : mode === "ok" ? C.green : mode === "fail" ? C.red : null;
    if (fill) fillRR(x, y, tw, th, 4, fill);
    strokeRR(x, y, tw, th, 4, fill || C.ink, 2);
    glyph(t.kind, x + tw / 2, y + 52, mode === "idle" ? 1 : 0.9);
    const label = mode === "pending" ? t.pending : mode === "ok" ? t.ok : t.label;
    txt(label, x + tw / 2, y + th - 14, 15, mode === "idle" ? C.ink : "#000", "center", "600");
  });
  return {
    num: { x: sx + 16 + vw / 2, y: sy + 48 }, arrow: { x: sx + 16 + vw + 8 + measure(st.unit || "mg/dL", 16, "500") + 25, y: sy + 56 },
    fresh: { x: sx + 250, y: sy + 36 }, chart: { x: sx + 150, y: sy + 150 }, tiles: { x: sx + 150, y: sy + 330 },
    numL: { x: sx + 8, y: sy + 48 }, chartL: { x: sx + 8, y: sy + 150 }, freshR: { x: sx + 284, y: sy + 36 },
    arrowR: { x: sx + 16 + vw + 8 + measure(st.unit || "mg/dL", 16, "500") + 44, y: sy + 56 }, tilesR: { x: sx + 286, y: sy + 330 },
    tile: (i) => ({ x: sx + 14 + (i % 2) * 132 + 62, y: sy + 222 + Math.floor(i / 2) * 142 + 67 }),
  };
}

/* Treatments screen: profiles on top, bolus section at the bottom. */
function treatScreen(dx, dy, st) {
  const { sx, sy } = edgeBody(dx, dy);
  txt(LBL.treatments, sx + 145, sy + 36, 20, C.ink, "center", "600");
  line(sx, sy + 48, sx + 290, sy + 48, C.line, 1.5);
  const rows = ["Default", "stop", "sport", "long"];
  rows.forEach((name, i) => {
    const y = sy + 50 + i * 48, active = st.active === i;
    if (active) { fillRR(sx, y, 5, 48, 0, C.green); }
    txt(name, sx + 20, y + 31, 20, active ? C.green : C.ink, "left", "600");
    if (active) {
      ctx.save(); ctx.strokeStyle = C.green; ctx.lineWidth = 3; ctx.beginPath();
      ctx.moveTo(sx + 250, y + 25); ctx.lineTo(sx + 256, y + 32); ctx.lineTo(sx + 268, y + 17); ctx.stroke(); ctx.restore();
    }
    line(sx, y + 48, sx + 290, y + 48, C.line, 1);
  });
  // bolus section
  const top = sy + 520 - 120;
  line(sx, top, sx + 290, top, C.line, 1.5);
  txt("Bolus", sx + 16, top + 22, 13, C.faint, "left", "500");
  const valColor = st.valueGrey ? "#555" : C.yellow;
  txt(st.bolusValue || "--", sx + 16, top + 62, 30, valColor, "left", "700");
  txt(st.bolusAge || "", sx + 16, top + 100, 13, C.faint, "left", "500");
  const bx = sx + 290 - 16 - 126, by = top + 30, bw = 126, bh = 60;
  const mode = st.btn || "off";
  const fill = { off: null, send: null, confirm: C.orange, sending: C.orange, sent: C.green }[mode];
  const border = { off: "#555", send: C.ink, confirm: C.orange, sending: C.orange, sent: C.green }[mode];
  if (fill) fillRR(bx, by, bw, bh, 10, fill);
  strokeRR(bx, by, bw, bh, 10, border, 2);
  const label = { off: LBL.disabled, send: LBL.send, confirm: LBL.confirm, sending: LBL.sending, sent: LBL.sent }[mode];
  txt(label, bx + bw / 2, by + 38, 20, fill ? "#000" : (mode === "off" ? "#777" : C.ink), "center", "600");
  return { btn: { x: bx + bw / 2, y: by + bh / 2 }, row: (i) => ({ x: sx + 120, y: sy + 50 + i * 48 + 24 }) };
}

/* Draw fn(x, y) (a device screen) scaled by k with its top-left at (dx, dy);
 * the anchors it returns are converted to world coordinates. */
function placed(dx, dy, k, fn) {
  ctx.save(); ctx.translate(dx, dy); ctx.scale(k, k);
  const a = fn(0, 0);
  ctx.restore();
  const conv = (p) => ({ x: dx + p.x * k, y: dy + p.y * k });
  const out = {};
  for (const key in a) {
    const v = a[key];
    out[key] = typeof v === "function" ? (...args) => conv(v(...args)) : conv(v);
  }
  return out;
}

/* server icon (database): used for Nightscout */
function serverIcon(cx, cy, s = 1, alpha = 1) {
  ctx.save(); ctx.globalAlpha *= alpha;
  for (let i = 0; i < 3; i++) {
    const y = cy - 52 * s + i * 36 * s;
    fillRR(cx - 46 * s, y, 92 * s, 30 * s, 8 * s, "#1a1f26");
    strokeRR(cx - 46 * s, y, 92 * s, 30 * s, 8 * s, C.ink, 2);
    circle(cx + 28 * s, y + 15 * s, 4 * s, i === 0 ? C.green : C.faint);
    line(cx - 30 * s, y + 15 * s, cx + 4 * s, y + 15 * s, C.faint, 2);
  }
  ctx.restore();
}

/* ------------------------------- subtitles -------------------------------- */
function drawSubtitle(t) {
  let cue = null;
  for (const sc of TIMING.scenes) for (const l of sc.lines) if (t >= l.t0 - 0.05 && t <= l.t1 + 0.25) cue = l;
  if (!cue) return;
  const size = 26, maxW = 1120, lines = wrap(cue.text, maxW, size, "500");
  const lh = 34, h = lines.length * lh + 22, y0 = H - 24 - h;
  const wmax = Math.max(...lines.map((s) => measure(s, size, "500")));
  fillRR(W / 2 - wmax / 2 - 22, y0, wmax + 44, h, 14, "#000", 0.62);
  lines.forEach((s, i) => txt(s, W / 2, y0 + 31 + i * lh, size, C.ink, "center", "500"));
}

/* -------------------------------- render ---------------------------------- */
function render(t) {
  t = clamp(t, 0, TIMING.total);
  ctx.setTransform(RES, 0, 0, RES, 0, 0);
  ctx.globalAlpha = 1;
  ctx.fillStyle = C.bg; ctx.fillRect(0, 0, W, H);
  let sc = TIMING.scenes[TIMING.scenes.length - 1];
  for (const s of TIMING.scenes) if (t >= s.start && t < s.start + s.dur) { sc = s; break; }
  const lt = t - sc.start;
  const fade = Math.min(clamp(lt / 0.5), clamp((sc.dur - lt) / 0.5));
  ctx.save();
  ctx.globalAlpha = sc.id === "intro" ? clamp(1 - Math.max(0, lt - (sc.dur - 0.5)) / 0.5) : fade;
  if (SCENES[sc.id]) SCENES[sc.id](lt, sc.dur);
  ctx.restore();
  drawSubtitle(t);
}
window.renderFrame = render;
window.VIDEO_TOTAL = TIMING.total;
window.VIDEO_LANG = LANG;

/* ------------------------------- playback --------------------------------- */
window.addEventListener("load", function boot() {
  const q = params.get("t");
  if (q !== null) { render(parseFloat(q)); return; }
  if (params.has("capture")) { render(0); return; }
  const audio = new Audio("audio/" + LANG + ".wav");
  let playing = false, t0 = 0, base = 0;
  function frame() {
    if (playing) {
      const t = audio.src && !audio.error ? audio.currentTime : base + (performance.now() - t0) / 1000;
      render(t);
      if (t >= TIMING.total) { playing = false; return; }
    }
    requestAnimationFrame(frame);
  }
  document.body.addEventListener("click", () => {
    if (!playing) { playing = true; t0 = performance.now(); audio.play().catch(() => {}); requestAnimationFrame(frame); }
  });
  render(2);
  txt(LANG === "fr" ? "Cliquer pour lancer" : "Click to play", W / 2, H - 20, 20, C.faint, "center", "500");
});
