# 1. Setup
pip3 install playwright
playwright install chromium

# 2. Create the Multi-User Script
cat > multi_user.py <<EOF
import asyncio
import random
import time
from playwright.async_api import async_playwright

TARGET_URL = "https://notnahid.xo.je/"
TOTAL_USERS_TO_SIMULATE = 100
# WARNING: Setting this higher than 20 might crash Cloud Shell!
MAX_CONCURRENT_USERS = 15  
TIME_ON_SITE = 180  # 3 minutes

async def simulate_single_user(user_id, semaphore):
    """Function representing one unique visitor."""
    async with semaphore:
        print(f"[User {user_id}] Entering the site...")
        
        async with async_playwright() as p:
            try:
                # Launch a fresh browser for every user to ensure a unique GA Client ID
                browser = await p.chromium.launch(headless=True)
                
                # Each context has unique cookies/session data
                context = await browser.new_context(
                    user_agent=f"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/{random.randint(110, 122)}.0.0.0 Safari/537.36",
                    viewport={'width': random.randint(1280, 1920), 'height': random.randint(720, 1080)}
                )
                
                page = await context.new_page()
                
                # Visit the site
                await page.goto(TARGET_URL, wait_until="networkidle", timeout=60000)
                print(f" !!! [User {user_id}] Connected. Stay time: 3 mins.")

                # Human-like behavior loop
                start_time = time.time()
                while time.time() - start_time < TIME_ON_SITE:
                    # Random Scroll
                    await page.mouse.wheel(0, random.randint(300, 700))
                    
                    # 30% chance to click a sub-link to increase "Pages per Session"
                    if random.random() < 0.3:
                        links = await page.query_selector_all("a")
                        if links:
                            target = random.choice(links)
                            if await target.is_visible():
                                try:
                                    await target.click()
                                    await page.wait_for_load_state("networkidle", timeout=10000)
                                except: pass
                    
                    await asyncio.sleep(random.uniform(20, 40))

                print(f"--- [User {user_id}] Session finished. Leaving site. ---")
                await browser.close()
                
            except Exception as e:
                print(f" [!] User {user_id} error: {e}")

async def main():
    print(f"Starting Multi-User Simulation...")
    print(f"Total to run: {TOTAL_USERS_TO_SIMULATE} | Max Concurrent: {MAX_CONCURRENT_USERS}")
    
    # Semaphore limits how many browsers run at exactly the same time
    semaphore = asyncio.Semaphore(MAX_CONCURRENT_USERS)
    
    tasks = []
    for i in range(1, TOTAL_USERS_TO_SIMULATE + 1):
        tasks.append(simulate_single_user(i, semaphore))
    
    # Run all users
    await asyncio.gather(*tasks)

if __name__ == "__main__":
    asyncio.run(main())
EOF

# 3. Run
python3 multi_user.py
