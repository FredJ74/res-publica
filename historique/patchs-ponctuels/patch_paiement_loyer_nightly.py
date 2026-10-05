#!/usr/bin/env python3

# --- 1. Nouvelle fonction Supabase : tous les lots loues par un joueur, tous terrains confondus ---
PATH_SB = "supabase.js"
with open(PATH_SB, "r", encoding="utf-8") as f:
    sb = f.read()

old_sb = """async function sbGetTerrainsLibres(country) {"""
new_sb = """// Tous les lots subdivises loues par ce joueur, tous terrains du pays confondus (necessaire
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

async function sbGetTerrainsLibres(country) {"""
assert sb.count(old_sb) == 1, f"supabase.js : trouvé {sb.count(old_sb)} fois (attendu 1)"
sb = sb.replace(old_sb, new_sb)

with open(PATH_SB, "w", encoding="utf-8") as f:
    f.write(sb)
print("✅ sbGetTerrainsAvecLotsLoues créée.")

# --- 2. Ne pas cumuler revenu fixe ET loyers si le terrain est subdivise ---
PATH_JE = "plateau-justice-economie.js"
with open(PATH_JE, "r", encoding="utf-8") as f:
    je = f.read()

old_je_1 = """  (terrains || []).forEach(function(ts) {
    if (!ts.niveau_construction) return;
    const revenu = REVENU_CONSTRUCTION[ts.niveau_construction] || 0;"""
new_je_1 = """  (terrains || []).forEach(function(ts) {
    if (!ts.niveau_construction) return;
    // Si le batiment est divise, le revenu vient des loyers reels des locataires (voir
    // payerLoyersLotsLoues), pas d'un montant fixe — evite un double revenu.
    const revenu = (ts.subdivisions && ts.subdivisions.length > 0) ? 0 : (REVENU_CONSTRUCTION[ts.niveau_construction] || 0);"""
assert je.count(old_je_1) == 1, f"bloc 1 : trouvé {je.count(old_je_1)} fois (attendu 1)"
je = je.replace(old_je_1, new_je_1)

# --- 3. Paiement nocturne du loyer, cote locataire ---
old_je_2 = """function getValeurTotaleBien(ts) {"""
new_je_2 = """// Paiement nocturne des loyers de subdivision, cote locataire — l'argent va directement au
// propriétaire (pas une caisse abstraite). Avertissement puis expulsion en cas d'impaye,
// sur le meme principe que payerLocations().
async function payerLoyersLotsLoues() {
  if (typeof sbGetTerrainsAvecLotsLoues !== 'function' || !state.char?.name) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  let lots;
  try {
    lots = await sbGetTerrainsAvecLotsLoues(state.country, state.char.name);
  } catch(e) { return; }

  for (const item of (lots || [])) {
    const loyer = item.lot.loyer || 0;
    if (state.arg >= loyer) {
      state.arg -= loyer;
      if (item.proprietaire && typeof sbGet === 'function' && typeof sbUpdate === 'function') {
        const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(item.proprietaire)}`).catch(function() { return null; });
        const proprio = rows && rows[0];
        if (proprio) {
          await sbUpdate('personnages', `name=eq.${encodeURIComponent(item.proprietaire)}`, { arg: (proprio.arg || 0) + loyer }).catch(function() {});
        }
      }
      addJournalEntry('Loyer payé : ' + item.lot.label + ' -' + loyer + ' ' + cur, 'event-info');
    } else {
      if (!item.lot.avertissement) {
        item.lot.avertissement = true;
        addMailNotification('Gestionnaire immobilier', 'Loyer impayé — ' + item.lot.label,
          'Votre loyer de ' + loyer + ' ' + cur + ' pour ' + item.lot.label + ' n\\'a pas pu être prélevé. Régularisez sous 24h ou vous serez expulsé(e).');
        addJournalEntry('⚠️ Loyer impayé : ' + item.lot.label + '. Avertissement envoyé.', 'event-bad');
      } else {
        item.lot.locataire = null;
        delete item.lot.avertissement;
        addJournalEntry('🚪 Expulsion : ' + item.lot.label + ' pour loyer impayé.', 'event-bad');
      }
      if (typeof sbSetTerrainState === 'function') {
        await sbSetTerrainState(state.country, item.buildingId, { subdivisions: item.subdivisions }).catch(function() {});
      }
      continue;
    }
  }
}

function getValeurTotaleBien(ts) {"""
assert je.count(old_je_2) == 1, f"bloc 2 : trouvé {je.count(old_je_2)} fois (attendu 1)"
je = je.replace(old_je_2, new_je_2)

with open(PATH_JE, "w", encoding="utf-8") as f:
    f.write(je)
print("✅ Paiement nocturne du loyer créé (locataire → propriétaire direct), évite le double revenu.")
