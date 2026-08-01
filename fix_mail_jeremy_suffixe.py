#!/usr/bin/env python3
PATH = "forum.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (to === 'Jérémy' && typeof queteAccueilGenererReponseMailJeremy === 'function') {
    queteAccueilGenererReponseMailJeremy(subject, body);
  }"""
new = """  if ((to || '').replace(' (PNJ)', '').trim() === 'Jérémy' && typeof queteAccueilGenererReponseMailJeremy === 'function') {
    queteAccueilGenererReponseMailJeremy(subject, body);
  }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Détection du destinataire corrigée (suffixe (PNJ) désormais ignoré).")
