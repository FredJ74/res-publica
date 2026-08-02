#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_1 = """      parc: {
        name: "Parc Botanique",
        imageBg: "linear-gradient(135deg,#0c140c,#141c14)",
        desc: "Étangs, cygnes, allées gravillonnées et pelouses (interdites). Un lieu paisible au cœur de la ville.",
        persons: ["""
new_1 = """      parc: {
        name: "Parc Botanique",
        imageBg: "linear-gradient(135deg,#0c140c,#141c14)",
        desc: "Étangs, cygnes, allées gravillonnées et pelouses (interdites). Un lieu paisible au cœur de la ville.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/parc-botanique-national.png",
        persons: ["""
assert content.count(old_1) == 1, f"parc : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

old_2 = """      serre: {
        name: "Serre Tropicale",
        imageBg: "linear-gradient(135deg,#0a1410,#101c18)",
        desc: "Plantes exotiques fragiles, orchidées et bassin d'ornement sous verrière. Merci de ne pas toucher les végétaux.",
        persons: ["""
new_2 = """      serre: {
        name: "Serre Tropicale",
        imageBg: "linear-gradient(135deg,#0a1410,#101c18)",
        desc: "Plantes exotiques fragiles, orchidées et bassin d'ornement sous verrière. Merci de ne pas toucher les végétaux.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/serre-botanique-luthecia.png",
        persons: ["""
assert content.count(old_2) == 1, f"serre : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Images du Parc et de la Serre ajoutées.")
