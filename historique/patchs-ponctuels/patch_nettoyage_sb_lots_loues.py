#!/usr/bin/env python3
PATH = "supabase.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """// Tous les lots subdivises loues par ce joueur, tous terrains du pays confondus (necessaire
// pour le paiement nocturne du loyer, cote locataire, ou qu'il se trouve).
async function sbGetTerrainsAvecLotsLoues(country, nom) {
  const rows = await sbGet('terrains_etat', `country=eq.${encodeURIComponent(country)}`);
  const resultats = [];
  (rows || []).forEach(function(r) {
    let etat;
    try { etat = JSON.parse(r.data); } catch(e) { return; }
    const subdivisions = etat.subdivisions || [];
    const monLot = subdivisions.find(function(l) { return l.locataire === nom; });
    if (monLot) resultats.push({ rowId: r.id, buildingId: r.building_id, proprietaire: etat.proprietaire, lot: monLot, subdivisions: subdivisions });
  });
  return resultats;
}

"""
new = """// NOTE : sbGetTerrainsAvecLotsLoues a ete retiree — le paiement des loyers de lots se fait
// desormais cote serveur (preleverLoyersLots, api/cron-minuit.js), pas via ce client.

"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ sbGetTerrainsAvecLotsLoues retirée (devenue inutile côté client).")
