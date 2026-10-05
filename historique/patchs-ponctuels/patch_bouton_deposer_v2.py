#!/usr/bin/env python3
PATH = "plateau-divers.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """      '<button onclick="supprimerItemInventaire(' + idx + ')" title="Supprimer" style="flex-shrink:0;background:none;border:1px solid #3a1a1a;color:#cc5540;cursor:pointer;padding:.15rem .35rem;font-size:.85rem;font-family:Bebas Neue,sans-serif">✕</button>' +
    '</div>';"""
new = """      '<button onclick="jeterObjetInventaire(' + idx + ')" title="Déposer ici (visible par les autres joueurs)" style="flex-shrink:0;background:none;border:1px solid #4a3010;color:#a0905a;cursor:pointer;padding:.15rem .35rem;font-size:.85rem;font-family:Bebas Neue,sans-serif"><i class="ti ti-map-pin"></i></button>' +
      '<button onclick="supprimerItemInventaire(' + idx + ')" title="Supprimer" style="flex-shrink:0;background:none;border:1px solid #3a1a1a;color:#cc5540;cursor:pointer;padding:.15rem .35rem;font-size:.85rem;font-family:Bebas Neue,sans-serif">✕</button>' +
    '</div>';"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Bouton 'Déposer ici' ajouté en raccourci direct dans la liste compacte.")
