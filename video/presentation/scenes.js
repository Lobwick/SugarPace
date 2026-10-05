/* Scenes of the SugarPace presentation. Each one is a pure function of the local
 * time `lt` (seconds since the scene started) and its duration `d`.
 * Helpers (txt, fillRR, prog, mainScreen, treatScreen...) come from ../player.js.
 * All numbers and names shown are fictional. */
"use strict";

const LABELS = {
  en: {
    tagline: "Glucose at a glance. Carb entries in one tap.",
    treatments: "Treatments", disabled: "Disabled", send: "Send", confirm: "Confirm", sending: "Sending...", sent: "Sent",
    gelSend: "Sending...", gelOk: "Sent", ago2: "2m ago", ago12: "12m ago", ago17: "17m ago",
    c1: "Latest reading, color-coded", c2: "Trend arrow", c3: "Age of the reading", c4: "Last 4 hours", c5: "Your foods, one tap away",
    otp: "One-time code", otpSub: "changes every 30 s", result: "The tile shows the result", dbl: "Double tap ignored",
    r1: "Sending...", r2: "Sent", r3: "Failed + short reason",
    edge: "Edge", phone: "Phone", ns: "Your Nightscout", loop: "Your loop",
    glucose: "glucose", carbs: "carb entries", noServer: "No SugarPace server", viaPhone: "via the phone's connection",
    fresh: "Fresh", warn: "Getting old", stale: "Too old: greyed out",
    optIn: "Allow sending the recommended bolus", off: "OFF by default",
    k1: "Off by default", k2: "Two taps, same amount", k3: "Recommendation under 10 min old", k4: "Never the same one twice",
    k5: "Unsure? Check your loop first", real: "Real insulin: always confirm on your loop",
    need: "What you need", n1: "A Nightscout site", n2: "A loop accepting remote entries", n3: "Touchscreen Edge", n3b: "840 · 850 · 1040 · 1050",
    notMed: "Not a medical device", notAff: "Not affiliated with Garmin, Nightscout or any loop app",
    confirmVals: "Always confirm with your approved devices",
  },
  fr: {
    tagline: "Ta glycémie d'un coup d'œil. Tes glucides en un tap.",
    treatments: "Traitements", disabled: "Désactivé", send: "Envoyer", confirm: "Confirmer", sending: "Envoi...", sent: "Envoyé",
    gelSend: "Envoi...", gelOk: "Envoyé", ago2: "2m ago", ago12: "12m ago", ago17: "17m ago",
    c1: "Dernière mesure, colorée", c2: "Flèche de tendance", c3: "Âge de la mesure", c4: "4 dernières heures", c5: "Tes aliments, à un tap",
    otp: "Code à usage unique", otpSub: "change toutes les 30 s", result: "La vignette affiche le résultat", dbl: "Double tap ignoré",
    r1: "Envoi...", r2: "Envoyé", r3: "Échec + courte raison",
    edge: "Edge", phone: "Téléphone", ns: "Ton Nightscout", loop: "Ta boucle",
    glucose: "glycémie", carbs: "entrées de glucides", noServer: "Aucun serveur SugarPace", viaPhone: "via la connexion du téléphone",
    fresh: "Récente", warn: "Elle vieillit", stale: "Trop ancienne : grisée",
    optIn: "Autoriser l'envoi du bolus recommandé", off: "DÉSACTIVÉ par défaut",
    k1: "Désactivé par défaut", k2: "Deux taps, même montant", k3: "Recommandation de moins de 10 min", k4: "Jamais deux fois la même",
    k5: "Un doute ? Vérifie ta boucle d'abord", real: "Insuline réelle : confirme toujours sur ta boucle",
    need: "Ce qu'il te faut", n1: "Un site Nightscout", n2: "Une boucle acceptant les entrées à distance", n3: "Edge tactile", n3b: "840 · 850 · 1040 · 1050",
    notMed: "Pas un dispositif médical", notAff: "Sans affiliation avec Garmin, Nightscout ou une application de boucle",
    confirmVals: "Vérifie toujours avec tes dispositifs approuvés",
  },
};
const LBL = LABELS[LANG];

/* the SugarPace logo (same paths as branding/logo.svg), drawn at (cx, cy) with scale k */
const DROP = new Path2D("M128 24C128 24 60 118 60 165a68 68 0 0 0 136 0C196 118 128 24 128 24Z");
function logo(cx, cy, k, drawP, chevP) {
  ctx.save();
  ctx.translate(cx - 128 * k, cy - 128 * k);
  ctx.scale(k, k);
  ctx.lineJoin = "round"; ctx.lineCap = "round";
  ctx.strokeStyle = "#fff"; ctx.lineWidth = 12;
  ctx.setLineDash([700, 700]); ctx.lineDashOffset = 700 * (1 - drawP);
  ctx.stroke(DROP);
  ctx.setLineDash([]);
  ctx.globalAlpha *= chevP;
  ctx.lineWidth = 15;
  ctx.strokeStyle = C.green; ctx.beginPath(); ctx.moveTo(100, 138); ctx.lineTo(126, 165); ctx.lineTo(100, 192); ctx.stroke();
  ctx.strokeStyle = C.orange; ctx.beginPath(); ctx.moveTo(138, 138); ctx.lineTo(164, 165); ctx.lineTo(138, 192); ctx.stroke();
  ctx.restore();
}

/* a small card with a title and an icon-less body */
function card(x, y, w, h, alpha = 1) { fillRR(x, y, w, h, 18, C.panel, alpha); strokeRR(x, y, w, h, 18, C.line, 2, alpha); }

const SCENES = {
  /* ---------------------------------------------------------------- intro */
  intro(lt) {
    background();
    logo(640, 250, 1.55, prog(lt, 0.2, 1.8), prog(lt, 1.6, 2.4));
    const p = prog(lt, 2.0, 2.9);
    txt("SugarPace", 640, 500 + (1 - p) * 18, 104, C.ink, "center", "800", p);
    txt(LBL.tagline, 640, 560, 34, C.soft, "center", "500", prog(lt, 3.0, 3.8));
  },

  /* --------------------------------------------------------------- screen */
  screen(lt) {
    background();
    const p = prog(lt, 0.2, 3.2);
    const value = Math.round(lerp(98, 112, p));
    const st = {
      value, valueColor: C.green, fresh: LBL.ago2, profile: "sport", arrow: "→", bars: prog(lt, 0.5, 5),
      tiles: [{ label: "Gel", kind: "gel", mode: "idle" }, { label: "Jelly", kind: "jelly", mode: "idle" },
        { label: "Bar", kind: "bar", mode: "idle" }, { label: "Gel+", kind: "gel", mode: "idle" }],
    };
    const a = placed(470, 40, 0.88, (x, y) => mainScreen(x, y, st));
    callout(lt, 1.8, LBL.c1, 410, 100, a.numL.x, a.numL.y, "L");
    callout(lt, 3.6, LBL.c2, 790, 170, a.arrowR.x, a.arrowR.y);
    callout(lt, 5.4, LBL.c3, 790, 100, a.freshR.x, a.freshR.y);
    callout(lt, 7.4, LBL.c4, 410, 220, a.chartL.x, a.chartL.y, "L");
    callout(lt, 10.2, LBL.c5, 790, 420, a.tilesR.x, a.tilesR.y);
  },

  /* ------------------------------------------------------------------ tap */
  tap(lt) {
    background();
    const second = lt >= 9.6;
    let mode = "idle";
    if (lt >= 4.2 && lt < 6.4) mode = "pending";
    else if (lt >= 6.4) mode = "ok";
    const st = {
      value: 112, valueColor: C.green, fresh: LBL.ago2, profile: "sport", arrow: "→", bars: 1,
      tiles: [{ label: "Gel", kind: "gel", mode: "idle" },
        { label: "Jelly", kind: "jelly", mode, pending: LBL.gelSend, ok: LBL.gelOk },
        { label: "Bar", kind: "bar", mode: "idle" }, { label: "Gel+", kind: "gel", mode: "idle" }],
    };
    const a = placed(130, 40, 0.88, (x, y) => mainScreen(x, y, st));
    const tp = a.tile(1);
    touch(lt, 3.6, tp.x, tp.y);
    touch(lt, 9.4, tp.x, tp.y);
    // right column: the one-time code
    const px = 600;
    const pc = prog(lt, 1.0, 1.6);
    card(px, 70, 500, 190, pc);
    txt(LBL.otp, px + 30, 118, 28, C.soft, "left", "600", pc);
    const code = ("000000" + Math.floor(((Math.floor(lt / 2.2) + 3) * 7919 + 104729) % 1000000)).slice(-6);
    txt(code.slice(0, 3) + " " + code.slice(3), px + 30, 200, 76, C.yellow, "left", "700", pc);
    txt(LBL.otpSub, px + 30, 240, 22, C.faint, "left", "500", pc);
    // right column: what the tile can say
    const rs = prog(lt, 6.8, 7.6);
    card(px, 300, 500, 220, rs);
    txt(LBL.result, px + 30, 346, 26, C.soft, "left", "600", rs);
    [[LBL.r1, C.orange], [LBL.r2, C.green], [LBL.r3, C.red]].forEach(([s, c], i) => {
      const p = prog(lt, 7.4 + i * 0.5, 7.9 + i * 0.5);
      fillRR(px + 30, 370 + i * 46, 26, 26, 6, c, p);
      txt(s, px + 72, 392 + i * 46, 26, C.ink, "left", "600", p);
    });
    if (second) txt("× " + LBL.dbl, 850, 566, 30, C.orange, "center", "700", prog(lt, 9.8, 10.4));
  },

  /* ----------------------------------------------------------------- flow */
  flow(lt) {
    background();
    const nodes = [{ x: 170, l: LBL.edge, k: "edge" }, { x: 450, l: LBL.phone, k: "phone" },
      { x: 780, l: LBL.ns, k: "cloud" }, { x: 1090, l: LBL.loop, k: "loop" }];
    const y = 280;
    for (let i = 0; i < 3; i++) line(nodes[i].x + 60, y, nodes[i + 1].x - 60, y, C.line, 3, prog(lt, 0.3 + i * 0.3, 0.9 + i * 0.3));
    nodes.forEach((n, i) => {
      const p = prog(lt, 0.2 + i * 0.35, 0.9 + i * 0.35);
      ctx.save(); ctx.globalAlpha *= p;
      if (n.k === "edge") { fillRR(n.x - 38, y - 56, 76, 112, 12, "#1a1f26"); strokeRR(n.x - 38, y - 56, 76, 112, 12, C.ink, 2); fillRR(n.x - 30, y - 48, 60, 96, 6, "#000"); circle(n.x, y - 10, 12, C.green); }
      if (n.k === "phone") { fillRR(n.x - 34, y - 58, 68, 116, 14, "#1a1f26"); strokeRR(n.x - 34, y - 58, 68, 116, 14, C.ink, 2); fillRR(n.x - 24, y - 44, 48, 82, 4, "#0e141b"); circle(n.x, y + 46, 5, C.faint); }
      if (n.k === "cloud") { serverIcon(n.x, y, 1.05); }
      if (n.k === "loop") { ctx.strokeStyle = C.ink; ctx.lineWidth = 6; ctx.beginPath(); ctx.arc(n.x, y, 40, 0.3, Math.PI * 1.6); ctx.stroke(); ctx.beginPath(); ctx.arc(n.x, y, 40, Math.PI * 1.3, Math.PI * 2.6); ctx.stroke(); circle(n.x, y, 8, C.green); }
      txt(n.l, n.x, y + 100, 26, C.ink, "center", "600");
      ctx.restore();
    });
    // glucose packets: loop -> Edge (right to left)
    if (lt > 3.5) {
      for (let k = 0; k < 6; k++) {
        const ph = ((lt - 3.5) * 0.28 + k / 6) % 1;
        const x = lerp(nodes[3].x - 60, nodes[0].x + 60, ph);
        if (!nodes.some((nd) => Math.abs(x - nd.x) < 62)) circle(x, y - 22, 9, C.yellow, Math.min(1, prog(lt, 3.5, 4.5)));
      }
      txt(LBL.glucose + "  ←", 640, y - 90, 28, C.yellow, "center", "600", prog(lt, 3.5, 4.5));
    }
    // carb packets: Edge -> loop (left to right), later
    if (lt > 8) {
      for (let k = 0; k < 5; k++) {
        const ph = ((lt - 8) * 0.24 + k / 5) % 1;
        const x = lerp(nodes[0].x + 60, nodes[3].x - 60, ph);
        if (!nodes.some((nd) => Math.abs(x - nd.x) < 62)) circle(x, y + 22, 9, C.green, Math.min(1, prog(lt, 8, 9)));
      }
      txt("→  " + LBL.carbs, 640, y + 160, 28, C.green, "center", "600", prog(lt, 8, 9));
    }
    if (lt > 5) txt(LBL.viaPhone, (nodes[0].x + nodes[1].x) / 2, y - 80, 20, C.faint, "center", "500", prog(lt, 5, 6));
    // no developer server
    if (lt > 12.5) {
      const p = prog(lt, 12.5, 13.5);
      ctx.save(); ctx.globalAlpha *= p;
      ctx.setLineDash([8, 6]); strokeRR(480, 465, 320, 60, 14, C.faint, 2); ctx.setLineDash([]);
      txt("SugarPace", 640, 504, 28, C.faint, "center", "600");
      line(470, 535, 810, 455, C.red, 6);
      ctx.restore();
      txt(LBL.noServer, 640, 565, 26, C.red, "center", "700", p);
    }
  },

  /* ---------------------------------------------------------------- treat */
  treat(lt) {
    background();
    const active = lt >= 4.4 ? 2 : 0;
    const a = placed(130, 40, 0.88, (x, y) => treatScreen(x, y, { active, bolusValue: "1.65 U", bolusAge: "3m ago", btn: "off" }));
    touch(lt, 3.8, a.row(2).x, a.row(2).y);
    // right: how the age is shown
    const px = 600;
    const items = [
      { t: LBL.ago2, v: 112, c: C.green, ac: C.faint, label: LBL.fresh, at: 6.4 },
      { t: LBL.ago12, v: 112, c: C.green, ac: C.orange, label: LBL.warn, at: 8.4 },
      { t: LBL.ago17, v: 112, c: "#666", ac: C.red, label: LBL.stale, at: 10.4 },
    ];
    items.forEach((it, i) => {
      const p = prog(lt, it.at, it.at + 0.6), y = 60 + i * 150;
      card(px, y, 540, 124, p);
      txt(String(it.v), px + 30, y + 82, 64, it.c, "left", "700", p);
      txt("mg/dL  →", px + 150, y + 78, 24, it.c === "#666" ? "#666" : C.ink, "left", "500", p);
      txt(it.t, px + 510, y + 46, 22, it.ac, "right", "600", p);
      txt(it.label, px + 510, y + 96, 24, C.soft, "right", "600", p);
    });
  },

  /* ---------------------------------------------------------------- bolus */
  bolus(lt) {
    background();
    let btn = "off";
    if (lt >= 4.0 && lt < 7.0) btn = "send";
    else if (lt >= 7.0 && lt < 9.6) btn = "confirm";
    else if (lt >= 9.6 && lt < 11.6) btn = "sending";
    else if (lt >= 11.6) btn = "sent";
    if (lt >= 7.0 && lt < 7.8) btn = "confirm";
    const a = placed(130, 40, 0.88, (x, y) => treatScreen(x, y, { active: 0, bolusValue: "1.65 U", bolusAge: "3m ago", btn }));
    touch(lt, 6.4, a.btn.x, a.btn.y);
    touch(lt, 9.0, a.btn.x, a.btn.y);
    // setting card
    const px = 600, pc = prog(lt, 0.4, 1.0);
    card(px, 50, 560, 130, pc);
    txt(LBL.optIn, px + 28, 102, 26, C.ink, "left", "600", pc);
    const on = lt >= 2.8;
    fillRR(px + 28, 126, 78, 38, 19, on ? C.green : "#444", pc);
    circle(px + (on ? 87 : 47), 145, 15, C.ink, pc);
    txt(on ? "ON" : LBL.off, px + 126, 153, 22, on ? C.green : C.faint, "left", "700", pc);
    // checklist
    const ks = [LBL.k1, LBL.k2, LBL.k3, LBL.k4, LBL.k5];
    ks.forEach((k, i) => {
      const p = prog(lt, 12.6 + i * 0.9, 13.2 + i * 0.9);
      ctx.save(); ctx.globalAlpha *= p;
      ctx.strokeStyle = C.green; ctx.lineWidth = 4; ctx.beginPath();
      ctx.moveTo(px + 30, 235 + i * 46); ctx.lineTo(px + 40, 247 + i * 46); ctx.lineTo(px + 58, 223 + i * 46); ctx.stroke();
      ctx.restore();
      txt(k, px + 80, 245 + i * 46, 26, C.ink, "left", "600", p);
    });
    const rp = prog(lt, 1.0, 1.8);
    fillRR(px, 480, 560, 60, 12, "#3a1111", rp);
    strokeRR(px, 480, 560, 60, 12, C.red, 2, rp);
    txt(LBL.real, px + 280, 519, 24, C.red, "center", "700", rp);
  },

  /* ----------------------------------------------------------------- need */
  need(lt) {
    background();
    txt(LBL.need, 640, 150, 52, C.ink, "center", "700", prog(lt, 0.2, 0.9));
    const items = [[LBL.n1, "", "cloud"], [LBL.n2, "", "loop"], [LBL.n3, LBL.n3b, "edge"]];
    items.forEach(([a, b, k], i) => {
      const p = prog(lt, 1.0 + i * 1.2, 1.8 + i * 1.2), x = 110 + i * 370, y = 230;
      card(x, y, 330, 300, p);
      ctx.save(); ctx.globalAlpha *= p;
      const cx = x + 165, cy = y + 100;
      if (k === "edge") { fillRR(cx - 34, cy - 52, 68, 104, 12, "#1a1f26"); strokeRR(cx - 34, cy - 52, 68, 104, 12, C.ink, 2); fillRR(cx - 26, cy - 44, 52, 88, 6, "#000"); circle(cx, cy - 8, 11, C.green); }
      if (k === "cloud") { serverIcon(cx, cy, 1.0); }
      if (k === "loop") { ctx.strokeStyle = C.ink; ctx.lineWidth = 6; ctx.beginPath(); ctx.arc(cx, cy, 38, 0.3, Math.PI * 1.6); ctx.stroke(); ctx.beginPath(); ctx.arc(cx, cy, 38, Math.PI * 1.3, Math.PI * 2.6); ctx.stroke(); circle(cx, cy, 8, C.green); }
      ctx.restore();
      wrap(a, 290, 28, "700").forEach((s, j) => txt(s, x + 165, y + 200 + j * 34, 28, C.ink, "center", "700", p));
      if (b) txt(b, x + 165, y + 270, 24, C.green, "center", "600", p);
    });
  },

  /* ---------------------------------------------------------------- outro */
  outro(lt) {
    background();
    logo(640, 200, 0.9, 1, 1);
    txt(LBL.notMed, 640, 360, 60, C.ink, "center", "700", prog(lt, 0.3, 1.0));
    txt(LBL.confirmVals, 640, 420, 32, C.soft, "center", "500", prog(lt, 0.8, 1.5));
    txt(LBL.notAff, 640, 500, 28, C.faint, "center", "500", prog(lt, 4.5, 5.3));
    txt("github.com/Lobwick/SugarPace", 640, 580, 38, C.green, "center", "700", prog(lt, 6.5, 7.3));
  },
};
