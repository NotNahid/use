cat <<'EOF' > yt_ultimate.js
const { firefox } = require('playwright');

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));
const random = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;

(async () => {
  console.log('[*] Launching ultimate stealth mode...');
  
  const browser = await firefox.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
    firefoxUserPrefs: {
      'media.peerconnection.enabled': false,
      'media.navigator.permission.disabled': true,
    }
  });

  const context = await browser.newContext({
    viewport: { width: 1920, height: 1080 },
    userAgent: 'Mozilla/5.0 (X11; Linux x86_64; rv:122.0) Gecko/20100101 Firefox/122.0',
    locale: 'en-US',
    timezoneId: 'America/New_York',
    permissions: ['geolocation'],
    geolocation: { latitude: 40.7128, longitude: -74.0060 },
    hasTouch: false,
    isMobile: false,
  });

  // Ultimate anti-detection
  await context.addInitScript(() => {
    delete Object.getPrototypeOf(navigator).webdriver;
    
    Object.defineProperty(navigator, 'plugins', {
      get: () => [
        { name: 'PDF Viewer' },
        { name: 'Chrome PDF Viewer' },
        { name: 'Chromium PDF Viewer' },
        { name: 'Microsoft Edge PDF Viewer' },
        { name: 'WebKit built-in PDF' }
      ],
    });
    
    Object.defineProperty(navigator, 'languages', {
      get: () => ['en-US', 'en'],
    });
    
    Object.defineProperty(navigator, 'hardwareConcurrency', {
      get: () => 8,
    });
    
    Object.defineProperty(navigator, 'deviceMemory', {
      get: () => 8,
    });
    
    // Make canvas fingerprint more realistic
    const getImageData = HTMLCanvasElement.prototype.toDataURL;
    HTMLCanvasElement.prototype.toDataURL = function(type) {
      if (type === 'image/png' && this.width === 0 && this.height === 0) {
        return 'data:image/png;base64,iVBORw0KGg';
      }
      return getImageData.apply(this, arguments);
    };
  });

  const page = await context.newPage();
  const videoURL = process.env.VIDEO_URL || 'https://www.youtube.com/watch?v=lnbOyEgLPgg';
  
  // Realistic browsing pattern
  console.log('[*] Step 1: Visiting YouTube homepage...');
  await page.goto('https://www.youtube.com', { waitUntil: 'domcontentloaded' });
  await sleep(random(3000, 5000));
  
  // Accept cookies
  try {
    const accept = await page.$('button[aria-label*="Accept"]');
    if (accept) {
      await accept.click();
      console.log('✅ Cookies accepted');
      await sleep(random(1500, 2500));
    }
  } catch (e) {}
  
  // Scroll homepage (human behavior)
  await page.mouse.wheel(0, random(200, 400));
  await sleep(random(1000, 2000));
  await page.mouse.wheel(0, random(200, 400));
  await sleep(random(2000, 3000));
  
  console.log('[*] Step 2: Navigating to video...');
  await page.goto(videoURL, { waitUntil: 'domcontentloaded' });
  await sleep(random(3000, 5000));

  const title = await page.evaluate(() => {
    const t = document.querySelector('h1 yt-formatted-string');
    return t ? t.textContent.trim() : 'Unknown';
  }).catch(() => 'Unknown');
  
  console.log(`✅ Video: "${title}"`);

  await page.waitForSelector('video', { timeout: 15000 });
  await sleep(random(2000, 4000));

  // Natural pre-play behavior
  await page.mouse.move(random(300, 900), random(200, 600));
  await sleep(random(800, 1500));
  await page.mouse.wheel(0, random(50, 150));
  await sleep(random(500, 1000));

  // Click play
  try {
    const playBtn = await page.$('button.ytp-large-play-button');
    if (playBtn) {
      const box = await playBtn.boundingBox();
      if (box) {
        await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
        console.log('✅ Clicked play');
        await sleep(random(2000, 3000));
      }
    }
  } catch (e) {}

  await page.evaluate(() => {
    const v = document.querySelector('video');
    if (v) {
      v.volume = 0.4 + Math.random() * 0.4;
      v.muted = false;
      v.play().catch(() => {});
    }
  });

  await sleep(2000);
  await page.screenshot({ path: 'ultimate_start.png' });
  console.log('📸 ultimate_start.png\n');

  console.log('[*] Monitoring with enhanced human simulation...\n');
  
  let i = 0;
  let maxTime = 0;
  let ads = 0;
  let inAd = false;
  let blocks = 0;
  let lastMove = Date.now();
  let interactionCount = 0;

  while (i < 500) {
    try {
      const status = await page.evaluate(() => {
        const v = document.querySelector('video');
        if (!v) return null;
        
        const hasAd = !!(
          document.querySelector('.ad-showing') ||
          document.querySelector('.ytp-ad-player-overlay') ||
          document.querySelector('.ytp-ad-text')
        );

        return {
          t: v.currentTime || 0,
          d: v.duration || 0,
          p: v.paused,
          e: v.ended,
          ad: hasAd,
          r: v.readyState
        };
      });

      if (!status) {
        console.log('⚠️  Lost video');
        await sleep(2000);
        continue;
      }

      if (status.t > maxTime) {
        maxTime = status.t;
        blocks = 0;
      }

      if (status.ad && !inAd) {
        inAd = true;
        ads++;
        console.log(`🔴 Ad #${ads}`);
      } else if (!status.ad && inAd) {
        inAd = false;
        console.log(`✅ Ad done`);
        await sleep(random(1000, 1500));
        await page.evaluate(() => document.querySelector('video')?.play());
      }

      if (maxTime > 30 && status.t === 0 && status.d === 0) {
        blocks++;
        if (blocks >= 5) {
          console.log(`\n🚫 Blocked at ${maxTime.toFixed(1)}s\n`);
          break;
        }
      }

      const pct = status.d > 0 ? (status.t / status.d * 100).toFixed(1) : '0.0';
      const icon = status.p ? '⏸️' : '▶️';
      const adMark = inAd ? '[AD]' : '';
      
      console.log(`[${i}] ${icon}${adMark} ${status.t.toFixed(1)}s/${status.d.toFixed(1)}s (${pct}%) Max:${maxTime.toFixed(1)}s`);

      if (status.p && !status.e && status.t > 0 && !inAd) {
        await page.evaluate(() => document.querySelector('video')?.play());
      }

      if (inAd && i % 3 === 0) {
        try {
          const skip = await page.$('button.ytp-ad-skip-button');
          if (skip && await skip.isVisible()) {
            await skip.click();
            console.log('⏭️  Skip');
          }
        } catch (e) {}
      }

      // Enhanced human interactions - more frequent and varied
      const timeSince = Date.now() - lastMove;
      if (timeSince > random(15000, 35000)) {
        interactionCount++;
        const actions = [
          async () => {
            await page.mouse.move(random(100, 1800), random(100, 1000));
            console.log(`🖱️  Mouse move #${interactionCount}`);
          },
          async () => {
            await page.mouse.wheel(0, random(-50, 50));
            console.log(`🖱️  Scroll #${interactionCount}`);
          },
          async () => {
            const bar = await page.$('.ytp-progress-bar');
            if (bar) {
              const box = await bar.boundingBox();
              if (box) {
                await page.mouse.move(box.x + box.width * Math.random(), box.y);
                console.log(`🖱️  Hover progress #${interactionCount}`);
              }
            }
          },
          async () => {
            await page.mouse.move(random(500, 1500), random(300, 700));
            await sleep(random(200, 500));
            await page.mouse.move(random(500, 1500), random(300, 700));
            console.log(`🖱️  Double move #${interactionCount}`);
          }
        ];
        await actions[Math.floor(Math.random() * actions.length)]();
        lastMove = Date.now();
      }

      if (i > 0 && i % 30 === 0) {
        await page.screenshot({ path: `ultimate_${i}.png` });
        console.log(`📸 ultimate_${i}.png`);
      }

      if (status.e && status.t > 60) {
        console.log('\n🎬 Complete!');
        break;
      }

      i++;
      await sleep(random(1400, 2600));

    } catch (error) {
      console.log(`❌ ${error.message}`);
      await sleep(2000);
    }
  }

  console.log('\n═══════════════════════════');
  console.log('       FINAL STATS');
  console.log('═══════════════════════════');
  console.log(`Iterations: ${i}`);
  console.log(`Max time: ${maxTime.toFixed(1)}s (${(maxTime/60).toFixed(2)} min)`);
  console.log(`Ads: ${ads}`);
  console.log(`Interactions: ${interactionCount}`);
  console.log('═══════════════════════════\n');
  
  await page.screenshot({ path: 'ultimate_final.png' });
  
  await sleep(2000);
  await browser.close();
  console.log('✅ Done!\n');
})();
EOF
