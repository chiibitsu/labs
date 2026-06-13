// gen-og.js — renders the Open Graph preview image for Ghost Office.
//
// No dependencies: it rasterises a little "ghost office" into a float buffer
// and hand-encodes a PNG (zlib ships with Node). Mirrors sigil/scripts/gen-og.js.
//
//     node scripts/gen-og.js   ->   ../og.png  (1200x630)

const zlib = require("zlib");
const fs = require("fs");
const path = require("path");

const WIDTH = 1200, HEIGHT = 630;

function hsl2rgb(h, s, l) {
  h /= 360; s /= 100; l /= 100;
  const k = (n) => (n + h * 12) % 12;
  const a = s * Math.min(l, 1 - l);
  const f = (n) => l - a * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1)));
  return [f(0), f(8), f(4)];
}

const buf = new Float32Array(WIDTH * HEIGHT * 3);
function add(x, y, r, g, b, a) {
  x |= 0; y |= 0;
  if (x < 0 || x >= WIDTH || y < 0 || y >= HEIGHT) return;
  const i = (y * WIDTH + x) * 3;
  buf[i] += r * a; buf[i + 1] += g * a; buf[i + 2] += b * a;
}
function splat(x, y, rad, col, a) {
  const r0 = Math.max(1, rad | 0);
  for (let dy = -r0; dy <= r0; dy++)
    for (let dx = -r0; dx <= r0; dx++) {
      const d2 = dx * dx + dy * dy;
      if (d2 > r0 * r0) continue;
      add(x + dx, y + dy, col[0], col[1], col[2], a * Math.exp(-d2 / (r0 * r0 * 0.5)));
    }
}

// theme palette — the violet/indigo of the rest of labs
const PAL = [
  hsl2rgb(258, 72, 70), // violet
  hsl2rgb(285, 65, 72), // magenta-violet
  hsl2rgb(205, 75, 68), // cyan-blue
  hsl2rgb(160, 60, 65), // teal
  hsl2rgb(35, 80, 68),  // warm (one accent)
];

/* ---- base wash + tinted vignette ---- */
const cx = WIDTH / 2, cy = HEIGHT * 0.42;
for (let y = 0; y < HEIGHT; y++)
  for (let x = 0; x < WIDTH; x++) {
    const i = (y * WIDTH + x) * 3;
    buf[i] = 0.02; buf[i + 1] = 0.024; buf[i + 2] = 0.039;
    const d = Math.hypot(x - cx, y - cy) / (Math.max(WIDTH, HEIGHT) * 0.8);
    const v = Math.max(0, 1 - d) * 0.1;
    buf[i] += PAL[0][0] * v; buf[i + 1] += PAL[0][1] * v; buf[i + 2] += PAL[0][2] * v;
  }

/* ---- faint starfield ---- */
let s = 1234567;
const rnd = () => ((s = (s * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
for (let n = 0; n < 420; n++) {
  splat(rnd() * WIDTH, rnd() * HEIGHT, 1, [0.7, 0.75, 0.95], 0.05 + rnd() * 0.12);
}

/* ---- a ghost sprite (12x13), eyes are holes in the glow ---- */
const GHOST = [
  "000011110000",
  "000111111000",
  "001111111100",
  "011111111110",
  "011111111110",
  "111001100111",
  "111001100111",
  "111111111111",
  "111111111111",
  "111111111111",
  "111111111111",
  "110110110110",
  "100100100100",
];
function drawGhost(cxp, cyp, px, col) {
  const w = 12 * px, h = 13 * px;
  const ox = cxp - w / 2, oy = cyp - h / 2;
  splat(cxp, cyp + h * 0.05, w * 0.62, col, 0.1);            // body glow
  splat(cxp, cyp + h * 0.62, w * 0.4, [0.5, 0.55, 0.8], 0.06); // desk glow
  for (let ry = 0; ry < 13; ry++)
    for (let rx = 0; rx < 12; rx++) {
      if (GHOST[ry][rx] !== "1") continue;
      // fill each cell as a soft blob so the body reads as a glowing ghost
      splat(ox + rx * px + px / 2, oy + ry * px + px / 2, Math.max(1, px * 0.62), col, 0.5);
    }
}

/* ---- a row of ghosts at their desks ---- */
const N = 5, baseY = HEIGHT * 0.42, px = 12;
for (let k = 0; k < N; k++) {
  const t = N === 1 ? 0.5 : k / (N - 1);
  const x = 180 + t * (WIDTH - 360);
  const y = baseY + Math.sin(t * Math.PI) * -22; // gentle arc
  drawGhost(x, y, px, PAL[k % PAL.length]);
}

/* ---- wordmark: GHOST TEAM (5x7 hand-set font) ---- */
const FONT = {
  G: ["01110", "10001", "10000", "10111", "10001", "10001", "01110"],
  H: ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
  O: ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
  S: ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
  T: ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
  E: ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
  A: ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
  M: ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
};
function stamp(word, ox, oy, p, col, a) {
  let x = ox;
  for (const ch of word) {
    const g = FONT[ch];
    if (g)
      for (let ry = 0; ry < 7; ry++)
        for (let rx = 0; rx < 5; rx++)
          if (g[ry][rx] === "1")
            for (let yy = 0; yy < p; yy++)
              for (let xx = 0; xx < p; xx++)
                add(x + rx * p + xx, oy + ry * p + yy, col[0], col[1], col[2], a);
    x += 5 * p + 2 * p;
  }
}
const WORD = "GHOST TEAM", P = 9;
const wordW = (5 * P + 2 * P) * WORD.length - 2 * P;
const ox = cx - wordW / 2, oy = HEIGHT - 150;
stamp(WORD, ox, oy, P, PAL[0], 0.16);                 // glow underlay
stamp(WORD, ox - 1, oy - 1, P, [0.95, 0.97, 1], 0.95); // crisp mark

/* ---- tone map + gamma -> bytes ---- */
const raw = Buffer.alloc(HEIGHT * (1 + WIDTH * 3));
for (let y = 0; y < HEIGHT; y++) {
  const rowStart = y * (1 + WIDTH * 3);
  raw[rowStart] = 0;
  for (let x = 0; x < WIDTH; x++) {
    const i = (y * WIDTH + x) * 3, o = rowStart + 1 + x * 3;
    for (let c = 0; c < 3; c++) {
      let v = buf[i + c];
      v = v / (1 + v);
      v = Math.pow(Math.min(1, v), 1 / 1.8);
      raw[o + c] = Math.max(0, Math.min(255, (v * 255) | 0));
    }
  }
}

/* ---- minimal PNG encoder (truecolor 8-bit) ---- */
const CRC = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; }
  return (b) => { let c = 0xFFFFFFFF; for (let i = 0; i < b.length; i++) c = t[(c ^ b[i]) & 0xFF] ^ (c >>> 8); return (c ^ 0xFFFFFFFF) >>> 0; };
})();
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0);
  const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(CRC(body), 0);
  return Buffer.concat([len, body, crc]);
}
const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(WIDTH, 0); ihdr.writeUInt32BE(HEIGHT, 4);
ihdr[8] = 8; ihdr[9] = 2;
const png = Buffer.concat([sig, chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw, { level: 9 })), chunk("IEND", Buffer.alloc(0))]);
fs.writeFileSync(path.join(__dirname, "..", "og.png"), png);
console.log("wrote og.png", WIDTH + "x" + HEIGHT, (png.length / 1024 | 0) + "kb");
