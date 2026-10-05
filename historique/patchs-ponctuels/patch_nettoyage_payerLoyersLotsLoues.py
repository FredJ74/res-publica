#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """// Paiement nocturne des loyers de subdivision, cote locataire — l'argent va directement au
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
new = """// NOTE : le paiement des loyers de lots subdivises se fait desormais cote serveur
// (preleverLoyersLots, api/cron-minuit.js), pas ici — voir patch du 3 aout 2026.

function getValeurTotaleBien(ts) {"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Fonction client obsolète retirée (remplacée par le cron serveur).")
