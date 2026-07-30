#!/usr/bin/env python3
"""
Patch plateau-navigation.js :
1. Reconstruit PLAN_LAYOUTS.ville_a (PSM) pour coller au plan Excalidraw a jour
   (retire cimetiere-marin obsolete, fusionne dans notre-dame-mer ; scinde
   Terrains a batir en 5 bandes distinctes comme a Luthecia).
2. Remplace le trace de rue (routePts) par le reseau de rues reel du plan
   Excalidraw (plusieurs segments), au lieu de l'ancien chemin schematique a 3 points.
A executer a la racine du repo res-publica.
"""

PATH = "plateau-navigation.js"

with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Bloc PLAN_LAYOUTS.ville_a ---
old_ville_a = """  ville_a: {
    'centre-artisanal':            [304,   7, 123,  86],
    'zone-production':             [459,   7, 203,  84],
    'centre-multinodal-port-sainte-marie': [673, 8, 91,  85],
    'port-sainte-marie':           [786,   8,  69, 226],
    'chantier-naval':              [ 11,  95, 114, 127],
    'stade':                       [685, 105,  75, 128],
    'notre-dame-mer':              [ 13, 228,  93,  85],
    'ecole-marine':                [684, 252,  73, 153],
    'cimetiere-marin':             [  8, 311, 103,  99],
    'centre-affaires':             [252, 314, 185,  97],
    'phare-psm':                   [772, 375,  86,  85],
    'centre-commercial':           [253, 423, 189,  95],
    'dispensaire-public-v':        [664, 435,  98, 159],
    'place-armes-psm':             [ 14, 437,  97,  92],
    'port-plaisance-psm':          [786, 512,  81, 143],
    'marche-psm':                  [121, 527, 137,  53],
    'mairie':                      [ 35, 532,  67,  59],
    'hotel-port':                  [  7, 591,  61,  57],
    'tribunal-local':              [570, 600,  97,  58],
    'banque-locale':               [673, 600,  89,  56],
    'chasse-peche-psm':            [237, 603,  79,  53],
    'bar-des-pecheurs':            [321, 603,  54,  54],
    'imprimerie-librairie':        [382, 605,  67,  52],
    'capitaine-sauvage':           [125, 606,  84,  50],
    'commissariat-local':          [454, 607,  67,  50],
    'terrain-a-batir-2':           [ 26,   8,  50,  83],
    'terrain-a-batir-8':           [ 80,   8,  50,  83],
    'terrain-a-batir-9':           [135,   8,  50,  83],
    'terrain-a-batir-10':          [189,   8,  50,  83],
    'terrain-a-batir-11':          [244,   8,  50,  83],

    // Musee : entre Centre Commercial et Dispensaire, meme rangee (voir plan Excalidraw). Position estimee, a ajuster.
    'musee-port-sainte-marie':     [460, 423, 180,  95],
  },"""

new_ville_a = """  ville_a: {
    // Grille reconstruite le 30 juillet 2026 a partir du plan Excalidraw a jour de Fred.
    // cimetiere-marin retire (fusionne dans notre-dame-mer). Terrains scindes en 5 bandes
    // (meme principe qu'a Luthecia). Positions fideles au plan, a affiner en jouant si besoin.

    // --- Quadrant Nord-Ouest : terrains, chantier naval, front de mer ---
    'terrain-a-batir-2':           [150,  20,  56,  85],
    'terrain-a-batir-8':           [206,  20,  56,  85],
    'terrain-a-batir-9':           [262,  20,  56,  85],
    'terrain-a-batir-10':          [318,  20,  56,  85],
    'terrain-a-batir-11':          [374,  20,  56,  85],
    'chantier-naval':              [ 18, 113, 113, 113],
    'notre-dame-mer':              [ 18, 230, 113,  95],
    'centre-affaires':             [265, 330, 175,  98],

    // --- Quadrant Nord-Est : production, industrie, ecole de marine ---
    'centre-artisanal':            [462,  25, 125,  83],
    'centre-multinodal-port-sainte-marie': [680, 25, 118, 83],
    'port-sainte-marie':           [800,  33,  78, 133],
    'zone-production':             [462, 133, 203,  83],
    'stade':                       [692, 125,  75, 125],
    'ecole-marine':                [692, 288,  75, 128],
    'phare-psm':                   [800, 395,  78,  75],

    // --- Quadrant Sud-Ouest : place d'armes, mairie, marche, quartier des pecheurs ---
    'place-armes-psm':             [ 18, 453, 113,  93],
    'mairie':                      [ 45, 545,  70,  60],
    'hotel-port':                  [  5, 605,  78,  68],
    'marche-psm':                  [128, 505, 133, 140],
    'capitaine-sauvage':           [135, 615,  85,  58],
    'chasse-peche-psm':            [243, 615,  85,  58],
    'bar-des-pecheurs':            [333, 615,  45,  58],
    'imprimerie-librairie':        [383, 615,  65,  58],
    'commissariat-local':          [450, 615,  70,  58],
    'centre-commercial':           [263, 453, 185,  93],

    // --- Quadrant Sud-Est : musee, hopital, justice, banque, port de plaisance ---
    'musee-port-sainte-marie':     [500, 453, 158,  93],
    'dispensaire-public-v':        [665, 453, 103, 153],
    'tribunal-local':              [578, 615,  88,  58],
    'banque-locale':               [668, 615, 100,  58],
    'port-plaisance-psm':          [800, 523,  78, 123],
  },"""

assert content.count(old_ville_a) == 1, f"ville_a : trouvé {content.count(old_ville_a)} fois (attendu 1)"
content = content.replace(old_ville_a, new_ville_a)

# --- 2. Trace de rue (routePts) pour ville_a ---
old_route = "    const routePts = 'M 730 420 L 130 420 L 130 90';"

new_route = """    // Reseau de rues reconstruit le 30 juillet 2026 a partir du plan Excalidraw a jour :
    // grand axe nord-sud central, jonction est-ouest au nord, allee ouest le long des
    // terrains/chantier naval, grande traverse est-ouest a mi-hauteur, et desserte
    // diagonale vers le quartier sud-est (musee/hopital/tribunal/banque).
    const routePts = 'M 450 13 L 450 430 M 450 115 L 890 115 M 145 115 L 145 430 M 240 300 L 450 325 M 8 430 L 890 430 M 460 430 L 528 673';"""

assert content.count(old_route) == 1, f"routePts : trouvé {content.count(old_route)} fois (attendu 1)"
content = content.replace(old_route, new_route)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Patch appliqué avec succès : grille PSM reconstruite + nouveau tracé de rue.")
