#!/usr/bin/env python3
PATH = "plateau-enigme-portrait.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Ajouter le champ imageGrosPlan a chaque entree ---
old_1 = """  salle_maires: {
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-maires-cadre-vide-luthecia.png',
    personnage: 'Marcel Torcieu',"""
new_1 = """  salle_maires: {
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-maires-cadre-vide-luthecia.png',
    imageGrosPlan: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/cadre-vide-torcieu-maire.png',
    personnage: 'Marcel Torcieu',"""
assert content.count(old_1) == 1, f"bloc maires : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

old_2 = """  salle_criminels: {
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-criminels-cadre-vide-luthecia.png',
    personnage: 'Maurice Caillon',"""
new_2 = """  salle_criminels: {
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-criminels-cadre-vide-luthecia.png',
    imageGrosPlan: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/cadre-vide-caillon-criminel.png',
    personnage: 'Maurice Caillon',"""
assert content.count(old_2) == 1, f"bloc criminels : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

old_3 = """  salle_entrepreneurs: {
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-entrepreneurs-cadre-vide-luthecia.png',
    personnage: 'Jacques Moulin',"""
new_3 = """  salle_entrepreneurs: {
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-entrepreneurs-cadre-vide-luthecia.png',
    imageGrosPlan: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/cadre-vide-moulin-entrepreneur.png',
    personnage: 'Jacques Moulin',"""
assert content.count(old_3) == 1, f"bloc entrepreneurs : trouvé {content.count(old_3)} fois (attendu 1)"
content = content.replace(old_3, new_3)

old_4 = """  salle_plumes: {
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-plumes-cadre-vide-luthecia.png',
    personnage: 'Étienne Tintabin',"""
new_4 = """  salle_plumes: {
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-plumes-cadre-vide-luthecia.png',
    imageGrosPlan: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/cadre-vide-tintabin-plume.png',
    personnage: 'Étienne Tintabin',"""
assert content.count(old_4) == 1, f"bloc plumes : trouvé {content.count(old_4)} fois (attendu 1)"
content = content.replace(old_4, new_4)

# --- 2. Afficher l'image dans la pop-up ---
old_5 = """  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.05em;margin-bottom:.3rem">Un cadre vide</div>';
  html += '<div style="font-size:.9rem;color:#e0d8c0;margin-bottom:.5rem">Seule la plaque subsiste : <strong>' + info.personnage + '</strong> (' + info.dates + ').</div>';
  html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic;line-height:1.5">' + info.texteAccroche + '</div>';
  html += '</div>';"""
new_5 = """  let html = '<div style="padding:1.2rem">';
  if (info.imageGrosPlan) {
    html += '<img src="' + info.imageGrosPlan + '" style="width:100%;border-radius:4px;margin-bottom:.9rem;display:block" />';
  }
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.05em;margin-bottom:.3rem">Un cadre vide</div>';
  html += '<div style="font-size:.9rem;color:#e0d8c0;margin-bottom:.5rem">Seule la plaque subsiste : <strong>' + info.personnage + '</strong> (' + info.dates + ').</div>';
  html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic;line-height:1.5">' + info.texteAccroche + '</div>';
  html += '</div>';"""
assert content.count(old_5) == 1, f"bloc image popup : trouvé {content.count(old_5)} fois (attendu 1)"
content = content.replace(old_5, new_5)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Image en gros plan ajoutée dans la pop-up du cadre vide.")
