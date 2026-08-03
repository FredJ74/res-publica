#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """      open_space: {
        name: "Open Space — Local à louer",
        imageBg: "linear-gradient(135deg,#080a10,#0f1218)",
        desc: "📋 À LOUER — Espace partagé, ambiance start-up. Moins cher, mais moins discret.",
        imageUrl: "https://images.unsplash.com/photo-1527192491265-7e15c55b1ed2?w=1200&q=80",
        isLocationRoom: true,
        locationData: { prix: 200, bonusPOP: 2, bonusINF: 3, bonusDIS: 1, label: 'Open Space', tier: 3 },
        persons: [],
        orders: [
          {fn:'louer_local', label:'Louer ce local (200 FR/jour)', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'+3 INF +2 POP +1 DIS.'},
          {fn:'gerer_local', label:'Gérer mon local', pa:1, cost:0, type:'legal', icon:'ti-settings', successRate:100}
        ]
      }
    }
  },

  'terrain-a-batir-7': {"""

new = """      open_space: {
        name: "Open Space — Local à louer",
        imageBg: "linear-gradient(135deg,#080a10,#0f1218)",
        desc: "📋 À LOUER — Espace partagé, ambiance start-up. Moins cher, mais moins discret.",
        imageUrl: "https://images.unsplash.com/photo-1527192491265-7e15c55b1ed2?w=1200&q=80",
        isLocationRoom: true,
        locationData: { prix: 200, bonusPOP: 2, bonusINF: 3, bonusDIS: 1, label: 'Open Space', tier: 3 },
        persons: [],
        orders: [
          {fn:'louer_local', label:'Louer ce local (200 FR/jour)', pa:1, cost:0, type:'legal', icon:'ti-key', successRate:100, desc:'+3 INF +2 POP +1 DIS.'},
          {fn:'gerer_local', label:'Gérer mon local', pa:1, cost:0, type:'legal', icon:'ti-settings', successRate:100}
        ]
      },
      tribune_republia: {
        name: "La Tribune de Republia — Antenne Locale",
        imageBg: "linear-gradient(135deg,#100808,#1c0c0c)",
        desc: "L'antenne locale du grand journal national d'opposition. Petite rédaction, mais grande influence.",
        persons: [
          {name:'Correspondant Local (PNJ)', role:'PNJ - Journaliste', rel:'neutral', job:'journaliste'}
        ],
        orders: [
          {fn:'produire_fuite', label:'Produire une fuite', pa:3, cost:0, type:'illegal', icon:'ti-leak', successRate:55, desc:"Choisir une cible dans le répertoire. Rumeur IA dans le journal. Mail à la cible. -10 INF -10 POP."},
          {fn:'interview', label:'Donner une interview', pa:1, cost:0, type:'legal', icon:'ti-microphone', successRate:100, desc:'Impact sur la popularité.'},
          {fn:'article', label:'Placer un article favorable', pa:2, cost:300, type:'grey', icon:'ti-pencil', successRate:70}
        ]
      }
    }
  },

  'terrain-a-batir-7': {"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ La Tribune de Republia (antenne locale) créée dans le Centre d'Affaires.")
