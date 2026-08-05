#!/usr/bin/env python3
PATH = "plateau-personnage.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """    const tauxIncendie = Math.max(5, 30 - malusISN);
    html += '<button onclick="doOrder(\\'incendier\\',3,0,\\'Incendier\\',\\'Vous mettez le feu.\\','+tauxIncendie+');closeSelfView()" style="display:flex;justify-content:space-between;align-items:center;padding:.5rem .8rem;border:1px solid #4a1a08;background:#100805;color:#aa5a30;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">';
    html += '<span><i class="ti ti-flame" style="font-size:.85rem"></i> Incendier</span><span style="font-family:Bebas Neue,sans-serif;font-size:.68rem;color:#8a3a10">' + tauxIncendie + '% · 3 PA · ISN:' + (INDICES_NATIONAUX[state.country]?.ISN||30) + '</span></button>';"""
new = """    const tauxIncendie = Math.max(5, 30 - malusISN);
    html += '<button onclick="doOrder(\\'incendier\\',3,0,\\'Incendier\\',\\'Vous mettez le feu.\\','+tauxIncendie+');closeSelfView()" style="display:flex;justify-content:space-between;align-items:center;padding:.5rem .8rem;border:1px solid #4a1a08;background:#100805;color:#aa5a30;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">';
    html += '<span><i class="ti ti-flame" style="font-size:.85rem"></i> Incendier</span><span style="font-family:Bebas Neue,sans-serif;font-size:.68rem;color:#8a3a10">' + tauxIncendie + '% · 3 PA · ISN:' + (INDICES_NATIONAUX[state.country]?.ISN||30) + '</span></button>';

    // Utiliser des explosifs — jusqu'ici entierement construite (doUtiliserExplosifs) et
    // routee, mais sans aucun bouton nulle part pour y acceder. Corrige le 5 aout 2026.
    if (typeof doUtiliserExplosifs === 'function') {
      html += '<button onclick="closeSelfView();doUtiliserExplosifs()" style="display:flex;justify-content:space-between;align-items:center;padding:.5rem .8rem;border:1px solid #4a1a08;background:#100805;color:#cc6a44;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">';
      html += '<span><i class="ti ti-bomb" style="font-size:.85rem"></i> Utiliser des explosifs</span><span style="font-family:Bebas Neue,sans-serif;font-size:.68rem;color:#8a3a10">3 PA · nécessite l\\'objet</span></button>';
    }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Bouton 'Utiliser des explosifs' ajouté à la fiche personnage.")
