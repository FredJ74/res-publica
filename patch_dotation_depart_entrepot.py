#!/usr/bin/env python3
PATH = "api/cron-minuit.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """      const etat = await sbGetBatimentEtat('republic', city, buildingId).catch(() => null);
      if (!etat) continue; // batiment pas encore accessible dans cette ville
      const entrepot = etat.entrepot || { stock: {}, caisse: 0 };"""
new = """      const etat = await sbGetBatimentEtat('republic', city, buildingId).catch(() => null);
      if (!etat) continue; // batiment pas encore accessible dans cette ville
      // Dotation de depart : de quoi remplir un stock vide a son plafond au prix fournisseur
      // (~8500 FR, calcule sur les 8 ressources livrables). Sans ca, la caisse resterait a 0
      // et l'entrepot ne pourrait jamais payer sa toute premiere livraison.
      const entrepot = etat.entrepot || { stock: {}, caisse: 8500 };"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Dotation de départ (8500 FR) ajoutée : chaque entrepôt démarre avec de quoi remplir son stock au prix fournisseur.")
