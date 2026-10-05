#!/usr/bin/env python3
PATH = "plateau-organisations-quetes.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_1 = """  const patch = {
    blocus: {
      syndicatId: syndicatId,
      syndicatNom: syndicat?.nom || 'Syndicat',
      revendication: revendication,
      nbMilitants: nbMilitants,
      intensite: intensite,
      leaderActuel: state.char?.name,
      lanceLe: Date.now(),
      dernierRenouvellementJour: state.day || 1
    }
  };"""
new_1 = """  const patch = {
    blocus: {
      syndicatId: syndicatId,
      syndicatNom: syndicat?.nom || 'Syndicat',
      revendication: revendication,
      nbMilitants: nbMilitants,
      intensite: intensite,
      leaderActuel: state.char?.name,
      lanceLe: Date.now(),
      dernierRenouvellementTimestamp: Date.now() // horodatage reel, verifie par le cron (pas un numero de jour, peu fiable pour un calcul de duree ecoulee)
    }
  };"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

old_2 = """  const patch = { blocus: { ...etatActuel.blocus, dernierRenouvellementJour: state.day || 1, leaderActuel: state.char?.name } };"""
new_2 = """  const patch = { blocus: { ...etatActuel.blocus, dernierRenouvellementTimestamp: Date.now(), leaderActuel: state.char?.name } };"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Horodatage réel (dernierRenouvellementTimestamp) utilisé au lancement et au renouvellement, au lieu d'un numéro de jour.")
