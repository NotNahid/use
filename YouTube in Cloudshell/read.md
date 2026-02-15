You need to install Playwright first:
bashnpm install playwright
npx playwright install firefox
Then run:
bashnode yt_ultimate.js
Or if you want to run your previous working script (yt_stealth.js) that was getting 80+ seconds:
bashnode yt_stealth.js
Note: It looks like you're on a different Cloud Shell session (wayn7683 vs justche9). If this is a fresh session, you'll need to reinstall everything:
bash# Quick setup
npm install playwright
npx playwright install firefox

# Then run
node yt_stealth.js
