#!/usr/bin/env python3
PATH = "plateau-personnage.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """        html += '<button onclick="event.stopPropagation();dropItem(' + i + ')" style="font-size:.85rem;color:#cc5540;background:transparent;border:none;cursor:pointer;padding:.2rem .4rem;flex-shrink:0">Jeter</button>';"""
new = """        html += '<button onclick="event.stopPropagation();jeterObjetInventaire(' + i + ')" style="font-size:.85rem;color:#a0905a;background:transparent;border:none;cursor:pointer;padding:.2rem .4rem;flex-shrink:0">Déposer</button>';
        html += '<button onclick="event.stopPropagation();dropItem(' + i + ')" style="font-size:.85rem;color:#cc5540;background:transparent;border:none;cursor:pointer;padding:.2rem .4rem;flex-shrink:0">Détruire</button>';"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Bouton 'Déposer' ajouté dans la fiche personnage, 'Jeter' renommé en 'Détruire' pour éviter toute confusion.")
