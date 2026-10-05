#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (etape === 'attente_entree_mairie' && buildingId === 'mairie-capitale' && roomId === 'hall_mairie') {
    queteAccueilSurbrillance('.person-card[data-enc*="Petit"]', 15000);
  }"""
new = """  // Filet de securite : si le joueur atteint l'Hotel de Ville par un autre chemin que le
  // nœud de rue prevu (ex: navigation directe), on effectue quand meme la transition ici,
  // plutot que de laisser la quete bloquee sur 'guide_hdv' indefiniment (bug remonte par
  // l'audit ChatGPT du 4 aout 2026 : Petit ne reconnaissait jamais "je suis nouveau").
  if (etape === 'guide_hdv' && buildingId === 'mairie-capitale') {
    state.char.queteAccueil = { etape: 'attente_entree_mairie' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    if (typeof afficherGuidageBatiments === 'function') afficherGuidageBatiments('luthecia-hotel-de-ville');
    queteAccueilSurbrillance('.person-card[data-enc*="Petit"]', 15000);
    return;
  }

  if (etape === 'attente_entree_mairie' && buildingId === 'mairie-capitale' && roomId === 'hall_mairie') {
    queteAccueilSurbrillance('.person-card[data-enc*="Petit"]', 15000);
  }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Filet de sécurité ajouté : la transition vers 'attente_entree_mairie' se fait désormais aussi à l'entrée directe du bâtiment, peu importe le chemin emprunté.")
