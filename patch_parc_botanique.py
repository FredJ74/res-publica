#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  'place-formulaire-liberte': {"""

new = """  'parc-botanique-national': {
    name: "Parc Botanique National de Républia",
    shortName: "Parc Botanique",
    cat: "Lieu public",
    icon: "ti-leaf",
    bgColor: "#0c140c",
    desc: "Fondé en 1897, le parc botanique national accueille étangs, allées ombragées et une grande serre tropicale.",
    rooms: {
      parc: {
        name: "Parc Botanique",
        imageBg: "linear-gradient(135deg,#0c140c,#141c14)",
        desc: "Étangs, cygnes, allées gravillonnées et pelouses (interdites). Un lieu paisible au cœur de la ville.",
        persons: [
          {name:'Florian Grès (PNJ)', role:'Jardinier', rel:'neutral', job:'jardinier', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/florian-gres-jardinier.png', photoPos:'50% 20%'}
        ],
        orders: []
      },
      serre: {
        name: "Serre Tropicale",
        imageBg: "linear-gradient(135deg,#0a1410,#101c18)",
        desc: "Plantes exotiques fragiles, orchidées et bassin d'ornement sous verrière. Merci de ne pas toucher les végétaux.",
        persons: [
          {name:'Jean-Pierre Ciseaux (PNJ)', role:'Conservateur', rel:'neutral', job:'conservateur', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jean-pierre-ciseaux-conservateur.png', photoPos:'50% 15%'}
        ],
        orders: []
      }
    }
  },

  'place-formulaire-liberte': {"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Parc Botanique National de Républia créé (2 pièces : Parc, Serre).")
