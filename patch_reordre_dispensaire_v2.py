#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """    rooms: {
      ehpad_tilleuls: {
        name: "EHPAD — Résidence Les Tilleuls",
        imageBg: "linear-gradient(135deg,#141008,#1c1810)",
        desc: "Un salon commun paisible. Fauteuils usés, photos de famille, et des pensionnaires toujours prêts à raconter le passé de Luthécia — à condition qu'on prenne le temps de les écouter.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/ehpad-residence-tilleuls.png",
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
        desc: "La salle d'attente est bondee. Comptez plusieurs heures.",
        imageUrl: "https://images.unsplash.com/photo-1584515933487-779824d29309?w=1200&q=80",
        imageUrl: "https://images.unsplash.com/photo-1584515933487-779824d29309?w=1200&q=80",
        persons: [
          {name:'Infirmiere Dupre', role:'PNJ - Soignante', rel:'neutral', job:'infirmier'}
        ],
        orders: [
          {fn:'soins_basiques', label:'Soins basiques (gratuit)', pa:0, cost:0,  type:'legal', icon:'ti-bandage',    successRate:100, desc:'+10 Sante. Lent mais gratuit.'},
          {fn:'soins',          label:'Consultation medecin',    pa:0, cost:20,  type:'legal', icon:'ti-stethoscope',successRate:100, desc:'+15 Sante.'},
          {fn:'centre_anti_poison', label:'Centre anti-poison', pa:1, cost:60, type:'legal', icon:'ti-vaccine', successRate:65, desc:'Guerit un empoisonnement en cours. Limite a 2 tentatives par jour.'},
          {fn:'transfert_clinique_privee', label:'Être transféré en clinique privée', pa:0, cost:1000, type:'legal', icon:'ti-ambulance', successRate:100, desc:'Meilleure prise en charge, convalescence plus rapide. 1000 FR.'}
        ]
      }
    }
  },

  // ---- COMMISSARIAT ----"""

new = """    rooms: {
      salle_attente: {
        name: "Salle d'attente",
        image: "⏳",
        imageBg: "linear-gradient(135deg,#081008,#0c180c)",
        desc: "La salle d'attente est bondee. Comptez plusieurs heures.",
        imageUrl: "https://images.unsplash.com/photo-1584515933487-779824d29309?w=1200&q=80",
        imageUrl: "https://images.unsplash.com/photo-1584515933487-779824d29309?w=1200&q=80",
        persons: [
          {name:'Infirmiere Dupre', role:'PNJ - Soignante', rel:'neutral', job:'infirmier'}
        ],
        orders: [
          {fn:'soins_basiques', label:'Soins basiques (gratuit)', pa:0, cost:0,  type:'legal', icon:'ti-bandage',    successRate:100, desc:'+10 Sante. Lent mais gratuit.'},
          {fn:'soins',          label:'Consultation medecin',    pa:0, cost:20,  type:'legal', icon:'ti-stethoscope',successRate:100, desc:'+15 Sante.'},
          {fn:'centre_anti_poison', label:'Centre anti-poison', pa:1, cost:60, type:'legal', icon:'ti-vaccine', successRate:65, desc:'Guerit un empoisonnement en cours. Limite a 2 tentatives par jour.'},
          {fn:'transfert_clinique_privee', label:'Être transféré en clinique privée', pa:0, cost:1000, type:'legal', icon:'ti-ambulance', successRate:100, desc:'Meilleure prise en charge, convalescence plus rapide. 1000 FR.'}
        ]
      },
      ehpad_tilleuls: {
        name: "EHPAD — Résidence Les Tilleuls",
        imageBg: "linear-gradient(135deg,#141008,#1c1810)",
        desc: "Un salon commun paisible. Fauteuils usés, photos de famille, et des pensionnaires toujours prêts à raconter le passé de Luthécia — à condition qu'on prenne le temps de les écouter.",
        imageUrl: "https://raw.githubusercontent.com/FredJ74/res-publica/main/images/ehpad-residence-tilleuls.png",
        persons: [
          {name:'Jeanine Dubois (PNJ)', role:'Ancienne institutrice', rel:'neutral', job:'pensionnaire_ehpad', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/jeanine-dubois-ehpad.png', photoPos:'50% 15%'},
          {name:'Louis Chevillard (PNJ)', role:'Policier en retraite', rel:'neutral', job:'pensionnaire_ehpad', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/louis-chevillard-ehpad.png', photoPos:'50% 15%'},
          {name:'Noël Chauchay (PNJ)', role:'Agriculteur à la retraite', rel:'neutral', job:'pensionnaire_ehpad', photoUrl:'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/noel-chauchay-ehpad.png', photoPos:'50% 15%'}
        ],
        orders: []
      }
    }
  },

  // ---- COMMISSARIAT ----"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Ordre corrigé : salle_attente en premier, ehpad_tilleuls ensuite.")
