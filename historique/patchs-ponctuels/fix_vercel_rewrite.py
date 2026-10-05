#!/usr/bin/env python3
PATH = "vercel.json"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  "rewrites": [
    { "source": "/api/chat", "destination": "/api/chat.js" }
  ],
"""
new = ""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Règle de réécriture problématique retirée de vercel.json.")
