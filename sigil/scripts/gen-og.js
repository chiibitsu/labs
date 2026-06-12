// gen-og.js — renders the Open Graph preview image for Sigil.
//
// No dependencies: it rasterises a representative "cosmos" into a pixel buffer
// and encodes a PNG by hand (zlib is built into Node). Run with:
//
//     node scripts/gen-og.js
//
// Output: og.png (1200x630), the social-card image referenced by index.html.

const zlib = require("zlib");
const fs = require("fs");
const path = require("path");

const WIDTH = 1200, HEIGHT = 630;
const SEED = "chiibitsu"; // the card mirrors the default cosmos

/* ---- the same seeded randomness the page uses ---- */
function xmur3(str) {
  let h = 1779033703 ^ str.length;
  for (let i = 0; i < str.length; i++) {
    h = Math.imul(h ^ str.charCodeAt(i), 3432918353);
    h = (h << 13) | (h >>> 19);
  }
  return function () {
    h = Math.imul(h ^ (h >>> 16), 2246822507);
    h = Math.imul(h ^ (h >>> 13), 3266489909);
    h ^= h >>> 16;
    return h >>> 0;
  };
}
function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const seedFn = xmur3(SEED);
const rand = mulberry32(seedFn());

/* ---- HSL -> RGB (0..1) ---- */
function hsl2rgb(h, s, l) {
  h /= 360; s /= 100; l /= 100;
  const k = (n) => (n + h * 12) % 12;
  const a = s * Math.min(l, 1 - l);
  const f = (n) => l - a * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1)));
  return [f(0), f(8), f(4)];
}

/* ---- palette derived from the seed (same recipe as the page) ---- */
const baseHue = Math.floor(rand() * 360);
const spread = rand() < 0.4 ? 28 : rand() < 0.75 ? 60 : 140;
const palette = [];
for (let i = 0; i < 5; i++) {
  const hue = (baseHue + (i - 2) * (spread / 5) + 360) % 360;
  palette.push(hsl2rgb(hue, 55 + rand() * 35, 50 + i * 6 + rand() * 8));
}

/* ---- float RGB framebuffer with additive ("lighter") compositing ---- */
const buf = new Float32Array(WIDTH * HEIGHT * 3);
function add(x, y, r, g, b, a) {
  x |= 0; y |= 0;
  if (x < 0 || x >= WIDTH || y < 0 || y >= HEIGHT) return;
  const i = (y * WIDTH + x) * 3;
  buf[i] += r * a; buf[i + 1] += g * a; buf[i + 2] += b * a;
}
// soft round splat (a tiny gaussian) for glow
function splat(x, y, rad, col, a) {
  const r0 = Math.max(1, rad | 0);
  for (let dy = -r0; dy <= r0; dy++) {
    for (let dx = -r0; dx <= r0; dx++) {
      const d2 = dx * dx + dy * dy;
      if (d2 > r0 * r0) continue;
      const fall = Math.exp(-d2 / (r0 * r0 * 0.5));
      add(x + dx, y + dy, col[0], col[1], col[2], a * fall);
    }
  }
}
function line(x0, y0, x1, y1, col, a, rad) {
  const steps = Math.max(1, Math.hypot(x1 - x0, y1 - y0) | 0);
  for (let s = 0; s <= steps; s++) {
    const t = s / steps;
    splat(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, rad, col, a);
  }
}

/* ---- base wash + tinted vignette ---- */
const cx = WIDTH / 2, cy = HEIGHT * 0.46;
for (let y = 0; y < HEIGHT; y++) {
  for (let x = 0; x < WIDTH; x++) {
    const i = (y * WIDTH + x) * 3;
    buf[i] = 0.02; buf[i + 1] = 0.024; buf[i + 2] = 0.039; // #05060a-ish
    const d = Math.hypot(x - cx, y - cy) / (Math.max(WIDTH, HEIGHT) * 0.75);
    const v = Math.max(0, 1 - d) * 0.10;
    const c = palette[4];
    buf[i] += c[0] * v; buf[i + 1] += c[1] * v; buf[i + 2] += c[2] * v;
  }
}

/* ---- flowing particle streaks ---- */
const R = Math.min(WIDTH, HEIGHT);
for (let n = 0; n < 13000; n++) {
  const ang = rand() * Math.PI * 2;
  const rr = Math.pow(rand(), 0.6) * R * 0.62;
  const x = cx + Math.cos(ang) * rr * (1.6);
  const y = cy + Math.sin(ang) * rr;
  // streak tangent to the swirl
  const ta = ang + Math.PI / 2 + (rand() - 0.5) * 0.6;
  const len = 6 + rand() * 30;
  const col = palette[(rand() * palette.length) | 0];
  const a = 0.08 + rand() * 0.18;
  line(x, y, x + Math.cos(ta) * len, y + Math.sin(ta) * len, col, a, 1);
}

/* ---- central breathing glyph (rings + nodes) ---- */
const symmetry = 3 + ((rand() * 7) | 0);
const rings = 4 + ((rand() * 3) | 0);
for (let r = 0; r < rings; r++) {
  const baseR = (0.07 + r * 0.075) * R;
  const nodes = symmetry * (1 + ((rand() * 2) | 0));
  const phase = rand() * Math.PI * 2;
  const wob = 0.1 + rand() * 0.4;
  const col = palette[(r + 1) % palette.length];
  let px = 0, py = 0;
  for (let k = 0; k <= nodes; k++) {
    const a = (k / nodes) * Math.PI * 2 + phase;
    const wf = 1 + Math.sin(a * symmetry) * wob * 0.25;
    const x = cx + Math.cos(a) * baseR * wf;
    const y = cy + Math.sin(a) * baseR * wf;
    if (k > 0) { line(px, py, x, y, col, 0.26, 2); line(px, py, x, y, col, 0.5, 1); }
    px = x; py = y;
  }
  for (let k = 0; k < nodes; k++) {
    const a = (k / nodes) * Math.PI * 2 + phase;
    const wf = 1 + Math.sin(a * symmetry) * wob * 0.25;
    const x = cx + Math.cos(a) * baseR * wf;
    const y = cy + Math.sin(a) * baseR * wf;
    splat(x, y, 5, col, 0.45);
    splat(x, y, 2, [1, 1, 1], 0.5);
  }
}
// luminous core
splat(cx, cy, 80, palette[0], 0.16);
splat(cx, cy, 34, palette[1], 0.4);
splat(cx, cy, 14, [1, 1, 1], 0.7);

/* ---- wordmark: SIGIL (tiny 5x7 hand-set font, scaled into glowing blocks) ---- */
const FONT = {
  S: ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
  I: ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
  G: ["01110", "10001", "10000", "10111", "10001", "10001", "01110"],
  L: ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
};
function stamp(word, ox, oy, px, col, a) {
  const glyphW = 5 * px, gap = 2 * px;
  let x = ox;
  for (const ch of word) {
    const g = FONT[ch];
    if (g) {
      for (let ry = 0; ry < 7; ry++) {
        for (let rx = 0; rx < 5; rx++) {
          if (g[ry][rx] === "1") {
            for (let yy = 0; yy < px; yy++)
              for (let xx = 0; xx < px; xx++)
                add(x + rx * px + xx, oy + ry * px + yy, col[0], col[1], col[2], a);
          }
        }
      }
    }
    x += glyphW + gap;
  }
  return x - gap - ox; // width drawn
}
const word = "SIGIL";
const px = 9;
const wordWidth = (5 * px) * word.length + (2 * px) * (word.length - 1);
const ox = cx - wordWidth / 2;
const oy = HEIGHT - 132;
// soft glow underlay then crisp mark
stamp(word, ox, oy, px, palette[2], 0.18);
stamp(word, ox - 1, oy - 1, px, [0.95, 0.97, 1], 0.95);

/* ---- tone map + gamma, then pack to bytes ---- */
const raw = Buffer.alloc(HEIGHT * (1 + WIDTH * 3));
for (let y = 0; y < HEIGHT; y++) {
  const rowStart = y * (1 + WIDTH * 3);
  raw[rowStart] = 0; // filter: none
  for (let x = 0; x < WIDTH; x++) {
    const i = (y * WIDTH + x) * 3;
    const o = rowStart + 1 + x * 3;
    for (let c = 0; c < 3; c++) {
      let v = buf[i + c];
      v = v / (1 + v);                 // reinhard tone map -> keeps highlights
      v = Math.pow(Math.min(1, v), 1 / 1.8); // gamma
      raw[o + c] = Math.max(0, Math.min(255, (v * 255) | 0));
    }
  }
}

/* ---- minimal PNG encoder (truecolor, 8-bit) ---- */
const CRC = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return (buf) => {
    let c = 0xFFFFFFFF;
    for (let i = 0; i < buf.length; i++) c = t[(c ^ buf[i]) & 0xFF] ^ (c >>> 8);
    return (c ^ 0xFFFFFFFF) >>> 0;
  };
})();
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, "ascii");
  const body = Buffer.concat([typeBuf, data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(CRC(body), 0);
  return Buffer.concat([len, body, crc]);
}
const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(WIDTH, 0); ihdr.writeUInt32BE(HEIGHT, 4);
ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
const idat = zlib.deflateSync(raw, { level: 9 });
const png = Buffer.concat([
  sig,
  chunk("IHDR", ihdr),
  chunk("IDAT", idat),
  chunk("IEND", Buffer.alloc(0)),
]);

const out = path.join(__dirname, "..", "og.png");
fs.writeFileSync(out, png);
console.log("wrote " + out + " (" + png.length + " bytes, " + WIDTH + "x" + HEIGHT + ")");
