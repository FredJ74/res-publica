#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- Lot 1 ---
old_1 = """  'terrain-a-batir-1': {
    name: "Terrain a batir - Lot 1",
    shortName: "Terrain Lot 1",
    cat: "Immobilier",
    icon: "ti-fence",
    bgColor: "#0a0a05",
    desc: "Terrain vague en plein centre de Luthecia. A acheter, a construire... ou a speculer.",
    rooms: {
      terrain: {
        name: "Terrain vague",
        image: "🏗️",
        imageBg: "linear-gradient(135deg,#0a0a05,#12120a)",
        desc: "Un terrain de 2000m2 en friche. Enormes possibilites.",
        imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80",
        persons: [],
        orders: [
          {fn:'appeler_police_terrain', label:'Appeler la police', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100},
          {fn:'faire_disparaitre_cadavre', label:'Faire disparaitre le corps', pa:2, cost:0, type:'illegal', icon:'ti-eye-off', successRate:0, requiresCadavre:true},
          {fn:'negocier_squatteurs', label:'Negocier le depart', pa:1, cost:0, type:'legal', icon:'ti-messages', successRate:0, requiresSquatteurs:true},
          {fn:'donner_argent_pnj', label:'Donner de l\\'argent', pa:1, cost:0, type:'legal', icon:'ti-coins', successRate:0, desc:'Offrir une somme a un PNJ present. Effet immediat selon sa personnalite.'},
          {fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:500, type:'legal', icon:'ti-file-certificate', successRate:100},
          {fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\\'instruction varie selon le palier choisi.'},
          {fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\\'instruction restante. Risque de decouverte.'},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\\'etait pas justifie par le zonage, le maire en subit les consequences.'},
          {fn:'acheter_terrain', label:'Acheter ce terrain', pa:2, cost:5000, type:'legal', icon:'ti-home-plus', successRate:100},
          {fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}"""

new_1 = """  'terrain-a-batir-1': {
    name: "Terrain a batir - Lot 1 (La Châtaigneraie)",
    shortName: "Lot 1 — Châtaigneraie",
    cat: "Immobilier",
    icon: "ti-fence",
    bgColor: "#0a0a05",
    desc: "Autrefois un seul grand domaine agricole en périphérie de Luthécia — la Châtaigneraie — ce terrain a été loti en cinq parcelles distinctes, aujourd'hui proposées séparément à la vente.",
    rooms: {
      terrain: {
        name: "Terrain vague",
        image: "🏗️",
        imageBg: "linear-gradient(135deg,#0a0a05,#12120a)",
        desc: "Le lot central de la Châtaigneraie (2150 m²), en léger retrait de la route.",
        imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80",
        persons: [],
        orders: [
          {fn:'appeler_police_terrain', label:'Appeler la police', pa:1, cost:0, type:'legal', icon:'ti-shield', successRate:100},
          {fn:'faire_disparaitre_cadavre', label:'Faire disparaitre le corps', pa:2, cost:0, type:'illegal', icon:'ti-eye-off', successRate:0, requiresCadavre:true},
          {fn:'negocier_squatteurs', label:'Negocier le depart', pa:1, cost:0, type:'legal', icon:'ti-messages', successRate:0, requiresSquatteurs:true},
          {fn:'donner_argent_pnj', label:'Donner de l\\'argent', pa:1, cost:0, type:'legal', icon:'ti-coins', successRate:0, desc:'Offrir une somme a un PNJ present. Effet immediat selon sa personnalite.'},
          {fn:'signer_compromis', label:'Signer un compromis', pa:2, cost:500, type:'legal', icon:'ti-file-certificate', successRate:100},
          {fn:'deposer_demande_permis', label:'Déposer une demande de permis', pa:2, cost:0, type:'legal', icon:'ti-file-text', successRate:100, desc:'Toujours obtenu a terme -- seule la duree d\\'instruction varie selon le palier choisi.'},
          {fn:'corrompre_fonctionnaire_permis', label:'Corrompre un fonctionnaire (accélérer)', pa:2, cost:800, type:'illegal', icon:'ti-coins', successRate:100, desc:'Reduit de moitie la duree d\\'instruction restante. Risque de decouverte.'},
          {fn:'plainte_obstruction_permis', label:'Contester un refus (obstruction)', pa:1, cost:0, type:'legal', icon:'ti-gavel', successRate:100, desc:'Si le refus n\\'etait pas justifie par le zonage, le maire en subit les consequences.'},
          {fn:'acheter_terrain', label:'Acheter ce terrain (2150 m² — 25 800 FR)', pa:2, cost:25800, type:'legal', icon:'ti-home-plus', successRate:100},
          {fn:'racheter_terrain', label:'Offre de rachat', pa:2, cost:0, type:'legal', icon:'ti-arrows-exchange', successRate:100}"""

assert content.count(old_1) == 1, f"lot 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- Lot 2 ---
old_2 = """  'terrain-a-batir-2': {
    name: "Terrain a batir - Lot 2",
    shortName: "Terrain Lot 2",
    cat: "Immobilier",
    icon: "ti-fence",
    bgColor: "#0a0a05",
    desc: "Terrain en bord de port. Ideal pour commerce ou entrepot.",
    rooms: {
      terrain2: {
        name: "Terrain",
        image: "🏗️",
        imageBg: "linear-gradient(135deg,#0a0a05,#12120a)",
        desc: "Terrain de 1500m2 en bord de port.",
        imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80",
        persons: [],
        orders: [
          {fn:'acheter_terrain',  label:'Acheter ce terrain',       pa:2, cost:3500, type:'legal',   icon:'ti-home-plus', successRate:100},"""

new_2 = """  'terrain-a-batir-2': {
    name: "Terrain a batir - Lot 2 (La Châtaigneraie)",
    shortName: "Lot 2 — Châtaigneraie",
    cat: "Immobilier",
    icon: "ti-fence",
    bgColor: "#0a0a05",
    desc: "Autrefois un seul grand domaine agricole en périphérie de Luthécia — la Châtaigneraie — ce terrain a été loti en cinq parcelles distinctes, aujourd'hui proposées séparément à la vente.",
    rooms: {
      terrain2: {
        name: "Terrain",
        image: "🏗️",
        imageBg: "linear-gradient(135deg,#0a0a05,#12120a)",
        desc: "Lot d'angle de la Châtaigneraie (2300 m²), exposition dégagée sur deux côtés.",
        imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80",
        persons: [],
        orders: [
          {fn:'acheter_terrain',  label:'Acheter ce terrain (2300 m² — 27 600 FR)',       pa:2, cost:27600, type:'legal',   icon:'ti-home-plus', successRate:100},"""

assert content.count(old_2) == 1, f"lot 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

# --- Lot 3 ---
old_3 = """  'terrain-a-batir-3': {
    name: "Terrain a batir - Lot 3",
    shortName: "Terrain Lot 3",
    cat: "Immobilier",
    icon: "ti-fence",
    bgColor: "#0a0a05",
    desc: "Terrain industriel a Montrouge. Adjacent a l'usine.",
    rooms: {
      terrain3: {
        name: "Terrain",
        imageBg: "linear-gradient(135deg,#0a0a05,#12120a)",
        desc: "Terrain de 3000m2 en zone industrielle.",
        imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80",
        persons: [],
        orders: [
          {fn:'acheter_terrain',   label:'Acheter ce terrain',          pa:2, cost:4000, type:'legal',   icon:'ti-home-plus', successRate:100},"""

new_3 = """  'terrain-a-batir-3': {
    name: "Terrain a batir - Lot 3 (La Châtaigneraie)",
    shortName: "Lot 3 — Châtaigneraie",
    cat: "Immobilier",
    icon: "ti-fence",
    bgColor: "#0a0a05",
    desc: "Autrefois un seul grand domaine agricole en périphérie de Luthécia — la Châtaigneraie — ce terrain a été loti en cinq parcelles distinctes, aujourd'hui proposées séparément à la vente.",
    rooms: {
      terrain3: {
        name: "Terrain",
        imageBg: "linear-gradient(135deg,#0a0a05,#12120a)",
        desc: "Lot de la Châtaigneraie (2300 m²) en bordure de la route principale, bonne visibilité.",
        imageUrl: "https://images.unsplash.com/photo-1590496793929-36417d3117de?w=1200&q=80",
        persons: [],
        orders: [
          {fn:'acheter_terrain',   label:'Acheter ce terrain (2300 m² — 27 600 FR)',          pa:2, cost:27600, type:'legal',   icon:'ti-home-plus', successRate:100},"""

assert content.count(old_3) == 1, f"lot 3 : trouvé {content.count(old_3)} fois (attendu 1)"
content = content.replace(old_3, new_3)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Lots 1, 2 et 3 réécrits (Domaine de la Châtaigneraie, surfaces et prix corrects).")
