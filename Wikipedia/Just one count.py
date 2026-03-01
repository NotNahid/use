cat <<'EOF' > fixed_check.py
#!/usr/bin/env python3
import requests
import re
import time
import urllib.parse

articles = [
    "আইজ্যাক অ্যাডেওল",
    "কৃত্রিম বুদ্ধিমত্তার দৃশ্যকলা",
    "আকিল আগা",
    "বুশি (অঞ্চল)",
    "সমারসেটের ভূগোল",
    "গারিবল্ডি আগ্নেয় বলয়",
    "ইডরেড",
    "ক্রোয়েশিয়া-সার্বিয়া সীমান্ত বিরোধ",
    "নেভাদাপ্লানো",
    "গেরেরো",
    "কেপ ইয়র্ক উপদ্বীপ",
    "রমনি ক্লাসিক্যাল ইনস্টিটিউট",
    "রেবেকা জোন্স",
    "হ্যালিফ্যাক্স বিস্ফোরণ",
    "এক্সপো ৬৭",
    "মাউন্ট এটনার অগ্ন্যুৎপাত, ১৬৬৯"
]

def count_words(title):
    """Count words with proper error handling"""
    # Properly encode title
    encoded_title = urllib.parse.quote(title)
    url = f"https://bn.wikipedia.org/w/api.php?action=query&prop=revisions&rvprop=content&format=json&titles={encoded_title}"
    
    try:
        # Add headers to avoid blocking
        headers = {
            'User-Agent': 'WikiWordCounter/1.0 (Educational Purpose)'
        }
        
        response = requests.get(url, headers=headers, timeout=15)
        
        # Check if response is valid
        if response.status_code != 200:
            print(f"  ⚠️  HTTP {response.status_code} for {title}")
            return 0
        
        data = response.json()
        
        pages = data.get('query', {}).get('pages', {})
        
        for page_id, page_data in pages.items():
            if page_id == '-1':
                print(f"  ⚠️  Article not found: {title}")
                return 0
                
            if 'revisions' in page_data:
                content = page_data['revisions'][0]['*']
                
                # Clean wiki markup
                clean = content
                clean = re.sub(r'\{\{[^}]+\}\}', '', clean)  # Remove templates
                clean = re.sub(r'\[\[(?:[^\]|]+\|)?([^\]]+)\]\]', r'\1', clean)  # Keep link text
                clean = re.sub(r'={2,}[^=]+={2,}', '', clean)  # Remove headers
                clean = re.sub(r'<[^>]+>', '', clean)  # Remove HTML
                clean = re.sub(r'\[\[File:[^\]]+\]\]', '', clean)  # Remove files
                clean = re.sub(r'\[\[চিত্র:[^\]]+\]\]', '', clean)  # Remove images
                clean = re.sub(r"'{2,}", '', clean)  # Remove bold/italic
                clean = re.sub(r'\|[^\n]*', '', clean)  # Remove table syntax
                clean = re.sub(r'&\w+;', '', clean)  # Remove HTML entities
                
                # Count words
                words = len([w for w in clean.split() if w.strip()])
                return words
                
    except requests.exceptions.JSONDecodeError as e:
        print(f"  ❌ JSON Error for {title}: {e}")
        return 0
    except requests.exceptions.Timeout:
        print(f"  ⏱️  Timeout for {title}")
        return 0
    except Exception as e:
        print(f"  ❌ Error for {title}: {type(e).__name__}")
        return 0
    
    return 0

# Main execution
print("=" * 75)
print("📊 NotNahid's Article Word Count - Ekushey Competition 2026")
print("=" * 75)
print(f"{'#':<4} {'Article':<50} {'Words':>15}")
print("-" * 75)

total_words = 0
successful = 0

for i, article in enumerate(articles, 1):
    print(f"{i:<4} {article:<50} ", end='', flush=True)
    words = count_words(article)
    
    if words > 0:
        print(f"{words:>15,}")
        total_words += words
        successful += 1
    else:
        print(f"{'ERROR':>15}")
    
    # Delay to avoid rate limiting
    time.sleep(0.5)

print("=" * 75)
print(f"{'Successful Articles':<54} {successful:>15}")
print(f"{'TOTAL WORDS':<54} {total_words:>15,}")
print("=" * 75)

# Estimated ranking
print("\n🏆 Prize Estimation:")
if total_words >= 40000:
    print("   🥇 Likely Top 3! Prize: ৬,০০০-১০,০০০ টাকা")
elif total_words >= 25000:
    print("   🥈 Likely Top 5-7! Prize: ২,০০০-৪,০০০ টাকা")
elif total_words >= 15000:
    print("   🥉 Likely Top 10! Prize: ২,০০০ টাকা")
elif total_words > 0:
    print("   ✅ Digital Certificate guaranteed!")
else:
    print("   ⚠️  Check internet connection or article names!")

print("\n💡 Note: This assumes jury accepts most articles!")
print("=" * 75)
EOF

chmod +x fixed_check.py
python3 fixed_check.py
