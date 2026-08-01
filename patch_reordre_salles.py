#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Dispensaire : remettre salle_attente en premier, ehpad_tilleuls juste apres ---
old_1 = """    rooms: {
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
      salle_attente: {
        name: "Salle d'attente",
        image: "⏳",
        imageBg: "linear-gradient(135deg,#081008,#0c180c)",
        desc: "Salle bondee. Patience requise.",
        imageUrl: "https://images.unsplash.com/photo-1584515933487-779824d29309?w=1200&q=80",
        persons: [{name:'Infirmiere (PNJ)', role:'Soignante', rel:'neutral', job:'infirmier'}],
        orders: [
          {fn:'soins_basiques', label:'Soins basiques (gratuit)', pa:0, cost:0, type:'legal', icon:'ti-bandage', successRate:100, desc:'+10 Sante.'}
        ]
      }
    }
  },

  'commissariat-local': {"""
new_1 = """    rooms: {
      salle_attente: {
        name: "Salle d'attente",
        image: "⏳",
        imageBg: "linear-gradient(135deg,#081008,#0c180c)",
        desc: "Salle bondee. Patience requise.",
        imageUrl: "https://images.unsplash.com/photo-1584515933487-779824d29309?w=1200&q=80",
        persons: [{name:'Infirmiere (PNJ)', role:'Soignante', rel:'neutral', job:'infirmier'}],
        orders: [
          {fn:'soins_basiques', label:'Soins basiques (gratuit)', pa:0, cost:0, type:'legal', icon:'ti-bandage', successRate:100, desc:'+10 Sante.'}
        ]
      },
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
      }
    }
  },

  'commissariat-local': {"""
assert content.count(old_1) == 1, f"bloc 1 (dispensaire) : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

print("✅ Étape 1/2 (Dispensaire) terminée. Étape 2 (Débarras) à préparer une fois le nom de l'hôtesse connu.")

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)
