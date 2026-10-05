#!/usr/bin/env python3
PATH = "plateau-musee-personnalites.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Rien à consulter ici pour l\\\\'instant.</div>';"""
new = """    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Rien à consulter ici pour l\\'instant.</div>';"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Erreur de syntaxe corrigée (l'instant).")
