#!/usr/bin/env node
// Exporte les matières et le drapeau de la maquette (Design/Decor/*.svg) en images pour Assets.xcassets.
//
// Les filtres SVG (bruit, relief) ne sont pas gérés par le moteur SVG d'Xcode : on les fait
// calculer par Chromium, puis on range les images dans RadioMoustache/Resources/Assets.xcassets/Decor.
//
// Usage (Node 18+ et Playwright avec Chromium) :
//   npm install --global playwright && npx playwright install chromium
//   NODE_PATH="$(npm root --global)" node scripts/export-decor.cjs

const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const sources = path.join(root, 'Design', 'Decor');
const catalog = path.join(root, 'RadioMoustache', 'Resources', 'Assets.xcassets', 'Decor');

// Les matières se répètent en mosaïque (bruit « stitchTiles ») : exportées en JPEG, opaques.
// Le drapeau garde sa transparence : PNG.
const items = [
  { asset: 'Bulkhead', svg: 'bulkhead.svg', width: 480, height: 480, type: 'jpeg' },
  { asset: 'Wood', svg: 'wood.svg', width: 600, height: 300, type: 'jpeg' },
  { asset: 'Crinkle', svg: 'crinkle.svg', width: 300, height: 300, type: 'jpeg' },
  { asset: 'Paper', svg: 'paper.svg', width: 200, height: 200, type: 'jpeg' },
  { asset: 'Grain', svg: 'grain.svg', width: 256, height: 256, type: 'jpeg' },
  { asset: 'PirateFlag', svg: 'flag.svg', width: 600, height: 420, type: 'png' },
];

const scale = 2;

function writeJSON(file, value) {
  fs.writeFileSync(file, JSON.stringify(value, null, 2) + '\n');
}

(async () => {
  fs.mkdirSync(catalog, { recursive: true });
  writeJSON(path.join(catalog, 'Contents.json'), { info: { author: 'xcode', version: 1 } });

  const browser = await chromium.launch();
  try {
    for (const item of items) {
      const context = await browser.newContext({
        viewport: { width: item.width, height: item.height },
        deviceScaleFactor: scale,
      });
      const page = await context.newPage();
      await page.goto('file://' + path.join(sources, item.svg));

      const extension = item.type === 'jpeg' ? 'jpg' : 'png';
      const fileName = `${item.asset.toLowerCase()}@${scale}x.${extension}`;
      const set = path.join(catalog, `${item.asset}.imageset`);
      fs.rmSync(set, { recursive: true, force: true });
      fs.mkdirSync(set, { recursive: true });

      await page.screenshot({
        path: path.join(set, fileName),
        type: item.type,
        quality: item.type === 'jpeg' ? 90 : undefined,
        omitBackground: item.type === 'png',
        clip: { x: 0, y: 0, width: item.width, height: item.height },
      });
      writeJSON(path.join(set, 'Contents.json'), {
        images: [{ filename: fileName, idiom: 'universal', scale: `${scale}x` }],
        info: { author: 'xcode', version: 1 },
      });
      console.log(`${item.asset} ← ${item.svg} (${item.width * scale} × ${item.height * scale})`);
      await context.close();
    }
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
