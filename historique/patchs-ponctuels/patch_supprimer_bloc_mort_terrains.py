#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  'terrain-a-batir-4': {
    name: "Terrain a batir - Lot 4",
    shortName: "Terrain Lot 4",
    cat: "Immobilier",
    icon: "ti-fence",
    bgColor: "#0a0a05",
    desc: "Terrain disponible a la construction. Quartier Est.",
    rooms: {
      terrain: {
        name: "Terrain vague",
        imageBg: "linear-gradient(135deg,#0a0a05,#12120a)",
        desc: "Un terrain en friche. Enormes possibilites.",
        imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80",
        persons: [],
        orders: [
          {fn:'acheter_terrain', label:'Acheter ce terrain', pa:2, cost:5000, type:'legal', icon:'ti-home-plus', successRate:100},
          {fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\\'instruction varie selon le palier choisi.'},
          {fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\\'instruction restante. Risque de decouverte.'},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\\'etait pas justifie par le zonage, le maire en subit les consequences.'}
        ]
      }
    }
  },
  'terrain-a-batir-5': {
    name: "Terrain a batir - Lot 5", shortName: "Terrain Lot 5", cat: "Immobilier", icon: "ti-fence", bgColor: "#0a0a05",
    desc: "Terrain disponible. Quartier Nord.",
    rooms: { terrain: { name: "Terrain vague", imageBg: "linear-gradient(135deg,#0a0a05,#12120a)", desc: "Terrain en friche.", imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80", persons: [], orders: [{fn:'appeler_police_terrain', label:'Appeler la police', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100},{fn:'faire_disparaitre_cadavre', label:'Faire disparaitre le corps', pa:2, cost:0, type:'illegal', icon:'ti-eye-off', successRate:0, requiresCadavre:true},{fn:'negocier_squatteurs', label:'Negocier le depart', pa:1, cost:0, type:'legal', icon:'ti-messages', successRate:0, requiresSquatteurs:true},{fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:500, type:'legal', icon:'ti-file-certificate', successRate:100},{fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\\'instruction varie selon le palier choisi.'},{fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\\'instruction restante. Risque de decouverte.'},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\\'etait pas justifie par le zonage, le maire en subit les consequences.'},{fn:'acheter_terrain', label:'Acheter ce terrain', pa:2, cost:25000, type:'legal', icon:'ti-home-plus', successRate:100},{fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100},{fn:'emprunter_construction', label:'Faire un prêt (Banque Nationale)', pa:0, cost:0, type:'legal', icon:'ti-bank', successRate:100},{fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}] } }
  },
  'terrain-a-batir-6': {
    name: "Terrain a batir - Lot 6", shortName: "Terrain Lot 6", cat: "Immobilier", icon: "ti-fence", bgColor: "#0a0a05",
    desc: "Terrain disponible. Quartier Sud.",
    rooms: { terrain: { name: "Terrain vague", imageBg: "linear-gradient(135deg,#0a0a05,#12120a)", desc: "Terrain en friche.", imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80", persons: [], orders: [{fn:'appeler_police_terrain', label:'Appeler la police', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100},{fn:'faire_disparaitre_cadavre', label:'Faire disparaitre le corps', pa:2, cost:0, type:'illegal', icon:'ti-eye-off', successRate:0, requiresCadavre:true},{fn:'negocier_squatteurs', label:'Negocier le depart', pa:1, cost:0, type:'legal', icon:'ti-messages', successRate:0, requiresSquatteurs:true},{fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:500, type:'legal', icon:'ti-file-certificate', successRate:100},{fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\\'instruction varie selon le palier choisi.'},{fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\\'instruction restante. Risque de decouverte.'},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\\'etait pas justifie par le zonage, le maire en subit les consequences.'},{fn:'acheter_terrain', label:'Acheter ce terrain', pa:2, cost:25000, type:'legal', icon:'ti-home-plus', successRate:100},{fn:'construire_sur_terrain', label:'Construire', pa:0, cost:0, type:'legal', icon:'ti-building', successRate:100},{fn:'emprunter_construction', label:'Faire un prêt (Banque Nationale)', pa:0, cost:0, type:'legal', icon:'ti-bank', successRate:100},{fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}] } }
  },


  // ====================="""

new = """  // ====================="""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Bloc mort (ancienne version des lots 4, 5, 6) supprimé.")
