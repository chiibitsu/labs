// gen-og.js — renders og.png (1200x630) for The Human Lane and for its mirror
// page, human-first/, by screenshotting each page's own hero in headless
// Chromium. Run from the repo root:
//
//     node human-lane/scripts/gen-og.js
//
// Needs Playwright (set PLAYWRIGHT_PATH if it isn't resolvable by require).

const path = require("path");
const { chromium } = require(process.env.PLAYWRIGHT_PATH || "playwright");

(async () => {
  const dir = path.join(__dirname, "..");
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1200, height: 630 } });
  await page.goto("file://" + path.join(dir, "index.html") + "?lane");
  await page.addStyleTag({ content: `
    .bar, .meters, .feed { display: none !important; }
    .lane { animation: none !important; }
    .hero { padding-top: 64px !important; }
    .hero .wrap { max-width: 1200px; padding: 0 72px; }
    .hero h1 { font-size: 104px !important; }
    .hero .lede { font-size: 22px !important; max-width: 60ch !important; }
    .lane > section, .closing, .foot { display: none !important; }
  ` });
  await page.evaluate(() => {
    const k = document.querySelector(".hero .kicker");
    k.textContent = "the human lane  ·  2041  ·  the internet, AI-first";
  });
  await page.waitForTimeout(400);
  await page.screenshot({ path: path.join(dir, "og.png") });

  // Human First, the mirror page: its hero at dawn.
  await page.goto("file://" + path.join(dir, "human-first", "index.html"));
  await page.addStyleTag({ content: `
    .bar, .meters, .dial, .noverify, section, .closing, .foot { display: none !important; }
    .hero { padding-top: 64px !important; }
    .hero .kicker { margin-top: 0 !important; }
    .hero .wrap { max-width: 1200px; padding: 0 72px; }
    .hero h1 { font-size: 104px !important; }
    .hero .lede { font-size: 22px !important; max-width: 60ch !important; }
  ` });
  await page.evaluate(() => {
    document.querySelector(".hero .kicker").textContent = "human first  ·  2041  ·  the other way round";
  });
  await page.waitForTimeout(300);
  await page.screenshot({ path: path.join(dir, "human-first", "og.png") });
  await browser.close();
})();
