#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Ajouter la salle EHPAD au Dispensaire Public (capitale) ---
old_dispensaire = """  'dispensaire-public': {
    name: "Dispensaire Public",
    shortName: "Dispensaire",
    cat: "Sante (public)",
    icon: "ti-first-aid-kit",
    bgColor: "#081008",
    desc: "Soins gratuits mais lents. Files d'attente, moyens limites, mais accessible a tous.",
    rooms: {
      salle_attente: {"""
new_dispensaire = """  'dispensaire-public': {
    name: "Dispensaire Public",
    shortName: "Dispensaire",
    cat: "Sante (public)",
    icon: "ti-first-aid-kit",
    bgColor: "#081008",
    desc: "Soins gratuits mais lents. Files d'attente, moyens limites, mais accessible a tous.",
    rooms: {
      ehpad_tilleuls: {
        name: "EHPAD — Résidence Les Tilleuls",
        imageBg: "linear-gradient(135deg,#141008,#1c1810)",
        desc: "Un salon commun paisible. Fauteuils usés, photos de famille, et des pensionnaires toujours prêts à raconter le passé de Luthécia — à condition qu'on prenne le temps de les écouter.",
        imageUrl: "https://images.unsplash.com/photo-1573497491765-dccce02b29df?w=1200&q=80",
        persons: [
          {name:'Jeanine Dubois (PNJ)', role:'Ancienne institutrice', rel:'neutral', job:'pensionnaire_ehpad', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jeanine-dubois-ehpad.png', photoPos:'50% 15%'},
          {name:'Louis Chevillard (PNJ)', role:'Policier en retraite', rel:'neutral', job:'pensionnaire_ehpad', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/louis-chevillard-ehpad.png', photoPos:'50% 15%'},
          {name:'Noël Chauchay (PNJ)', role:'Agriculteur à la retraite', rel:'neutral', job:'pensionnaire_ehpad', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/noel-chauchay-ehpad.png', photoPos:'50% 15%'}
        ],
        orders: []
      },
      salle_attente: {"""
assert content.count(old_dispensaire) == 1, f"dispensaire : trouvé {content.count(old_dispensaire)} fois (attendu 1)"
content = content.replace(old_dispensaire, new_dispensaire)

# --- 2. Ajouter le PNJ Gerard Poincon au hall du musee + la salle Debarras (verrouillee) ---
old_musee_hall = """      hall: {
        name: "Hall d'accueil",
        imageBg: "linear-gradient(135deg,#1c160c,#241c10)",
        desc: "Le hall d'accueil du musee de la ville de Luthecia.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-musee-ville-luthecia.png",
        persons: [],
        orders: []
      },
      salle_criminels: {"""
new_musee_hall = """      hall: {
        name: "Hall d'accueil",
        imageBg: "linear-gradient(135deg,#1c160c,#241c10)",
        desc: "Le hall d'accueil du musee de la ville de Luthecia.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/hall-musee-ville-luthecia.png",
        persons: [
          {name:'Gérard Poinçon (PNJ)', role:'Gardien du musée', rel:'neutral', job:'gardien_musee', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/gerard-poincon-gardien-musee.png', photoPos:'50% 15%'}
        ],
        orders: []
      },
      debarras: {
        name: "Débarras",
        imageBg: "linear-gradient(135deg,#0a0806,#100c08)",
        desc: "Une porte fermée à clé, discrète, au fond du musée. Personne ne semble jamais y entrer.",
        imageUrl: "https://images.unsplash.com/photo-1558959357-d7a08d1f7e13?w=1200&q=80",
        locked: true,
        persons: [],
        orders: []
      },
      salle_criminels: {"""
assert content.count(old_musee_hall) == 1, f"musee hall : trouvé {content.count(old_musee_hall)} fois (attendu 1)"
content = content.replace(old_musee_hall, new_musee_hall)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Salle EHPAD (Dispensaire) + Débarras verrouillé + 4 PNJ ajoutés.")
