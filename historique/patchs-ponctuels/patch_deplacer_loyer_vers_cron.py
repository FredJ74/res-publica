#!/usr/bin/env python3

# --- 1. Retirer l'appel cote client (plateau-personnage.js) ---
PATH_PERSO = "plateau-personnage.js"
with open(PATH_PERSO, "r", encoding="utf-8") as f:
    perso = f.read()

old_1 = """  // Revenu passif + bonus INF/POP/DIS des bâtiments construits sur des terrains possédés
  if (typeof collecterRevenusConstructions === 'function') await collecterRevenusConstructions();
  // Loyers des lots subdivisés loués ailleurs (paiement direct au propriétaire)
  if (typeof payerLoyersLotsLoues === 'function') await payerLoyersLotsLoues();"""
new_1 = """  // Revenu passif + bonus INF/POP/DIS des bâtiments construits sur des terrains possédés
  if (typeof collecterRevenusConstructions === 'function') await collecterRevenusConstructions();
  // NOTE : les loyers des lots subdivises sont desormais preleves par le cron serveur
  // (preleverLoyersLots, api/cron-minuit.js) — pas ici, pour ne pas defavoriser le
  // proprietaire si le locataire ne se connecte jamais."""
assert perso.count(old_1) == 1, f"perso : trouvé {perso.count(old_1)} fois (attendu 1)"
perso = perso.replace(old_1, new_1)

with open(PATH_PERSO, "w", encoding="utf-8") as f:
    f.write(perso)
print("✅ Appel côté client retiré (évite le double prélèvement).")

# --- 2. Ajouter le cron serveur ---
PATH_CRON = "api/cron-minuit.js"
with open(PATH_CRON, "r", encoding="utf-8") as f:
    cron = f.read()

old_2 = """async function traiterSouvenirsAccueil() {"""
new_2 = """// Prelevement quotidien des loyers de lots subdivises — le locataire paie, le proprietaire
// est credite directement, meme si aucun des deux ne s'est connecte. Avertissement puis
// expulsion en cas d'impaye (meme principe que payerLocations cote client, transpose au cron).
async function preleverLoyersLots() {
  const resultats = { collecte: 0, expulsions: 0 };
  try {
    const terrains = await sbGet('terrains_etat', '');
    if (!terrains) return resultats;

    for (const row of terrains) {
      let etat;
      try { etat = JSON.parse(row.data); } catch(e) { continue; }
      const subdivisions = etat.subdivisions || [];
      if (subdivisions.length === 0) continue;

      let modifie = false;

      for (const lot of subdivisions) {
        if (!lot.locataire || !lot.loyer) continue;

        const locRows = await sbGet('personnages', `name=eq.${encodeURIComponent(lot.locataire)}`);
        const locataire = locRows && locRows[0];
        if (!locataire) continue;

        const argLocataire = locataire.arg || 0;

        if (argLocataire >= lot.loyer) {
          await sbUpdate('personnages', `name=eq.${encodeURIComponent(lot.locataire)}`, { arg: argLocataire - lot.loyer });
          if (etat.proprietaire) {
            const propRows = await sbGet('personnages', `name=eq.${encodeURIComponent(etat.proprietaire)}`);
            const proprio = propRows && propRows[0];
            if (proprio) {
              await sbUpdate('personnages', `name=eq.${encodeURIComponent(etat.proprietaire)}`, { arg: (proprio.arg || 0) + lot.loyer });
              resultats.collecte += lot.loyer;
            }
          }
          if (lot.avertissement) { delete lot.avertissement; modifie = true; }
        } else {
          modifie = true;
          if (!lot.avertissement) {
            lot.avertissement = true;
            await sbInsert('mails', {
              destinataire: lot.locataire, expediteur: 'Gestionnaire immobilier',
              sujet: 'Loyer impayé — ' + lot.label,
              corps: 'Votre loyer de ' + lot.loyer + ' FR pour ' + lot.label + " n'a pas pu être prélevé. Régularisez sous 24h ou vous serez expulsé(e).",
              archived: false
            }).catch(() => {});
          } else {
            lot.locataire = null;
            delete lot.avertissement;
            resultats.expulsions++;
          }
        }
      }

      if (modifie) {
        etat.subdivisions = subdivisions;
        await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(row.id)}`, { data: JSON.stringify(etat), updated_at: new Date().toISOString() }).catch(() => {});
      }
    }
  } catch(e) { console.error('preleverLoyersLots error', e); }
  return resultats;
}

async function traiterSouvenirsAccueil() {"""
assert cron.count(old_2) == 1, f"cron : trouvé {cron.count(old_2)} fois (attendu 1)"
cron = cron.replace(old_2, new_2)

old_3 = """    // 4. Taxe fonciere quotidienne sur tous les terrains possedes
    const taxeFonciere = await preleverTaxeFonciere();

    return res.status(200).json({ ok: true, traites: results.length, details: results, mailsSupprimes: mailsSuppres, fuites, taxeFonciere });"""
new_3 = """    // 4. Taxe fonciere quotidienne sur tous les terrains possedes
    const taxeFonciere = await preleverTaxeFonciere();

    // 5. Loyers des lots subdivises (locataire -> proprietaire directement)
    const loyersLots = await preleverLoyersLots();

    return res.status(200).json({ ok: true, traites: results.length, details: results, mailsSupprimes: mailsSuppres, fuites, taxeFonciere, loyersLots });"""
assert cron.count(old_3) == 1, f"cron : trouvé {cron.count(old_3)} fois (attendu 1)"
cron = cron.replace(old_3, new_3)

with open(PATH_CRON, "w", encoding="utf-8") as f:
    f.write(cron)
print("✅ Cron de prélèvement des loyers de lots créé et branché.")
