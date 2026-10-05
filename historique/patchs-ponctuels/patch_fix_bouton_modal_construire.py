#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  html += '<button onclick="ouvrirModalPretBancaire()" style="width:100%;margin-top:.6rem;font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.5rem;border:1px solid #4a6a8a;background:transparent;color:#6a9aca;cursor:pointer">🏦 Faire un prêt bancaire</button>';"""
new = """  html += '<button onclick="ouvrirModalPretBancaire(&quot;nationale&quot;,&quot;travaux&quot;)" style="width:100%;margin-top:.6rem;font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.5rem;border:1px solid #4a6a8a;background:transparent;color:#6a9aca;cursor:pointer">🏦 Faire un prêt travaux</button>';"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Bouton du modal de construction pointe directement vers le prêt Travaux.")
