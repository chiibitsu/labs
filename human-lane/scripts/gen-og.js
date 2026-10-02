// gen-og.js — renders og.png (1200x630) for The Human Lane by screenshotting
// the page's own hero in headless Chromium. Run from the repo root:
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
  await browser.close();
})();
