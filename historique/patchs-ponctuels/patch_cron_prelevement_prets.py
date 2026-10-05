#!/usr/bin/env python3
PATH = "api/cron-minuit.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """async function nettoyerAchatsDirectsManques() {"""
new = """// Prelevement quotidien des mensualites de pret, cote serveur — a heure fixe, que le
// joueur ait passe l'ordre Dormir ou non (demande explicite de Fred le 5 aout 2026).
// Portee fidelement depuis l'ancienne version client (jamais appelee), avec la meme
// differenciation narrative Banque Nationale (procedure legale) / Banque Privee
// (intimidation puis expropriation violente).
async function preleverPretsBancairesServeur() {
  const resultats = { preleves: 0, impayes: 0, saisies: 0 };
  try {
    const prets = await sbGet('prets', 'statut=eq.en_cours');
    if (!prets) return resultats;

    for (const pret of prets) {
      if (pret.montant_restant <= 0) {
        await sbUpdatePret(pret.id, { statut: 'remboursé' }).catch(() => {});
        continue;
      }

      const empRows = await sbGet('personnages', `name=eq.${encodeURIComponent(pret.emprunteur)}`);
      const emprunteur = empRows && empRows[0];
      if (!emprunteur) continue;

      const cur = 'FR';
      const aPayer = Math.min(pret.mensualite, pret.montant_restant);

      if ((emprunteur.arg || 0) >= aPayer) {
        const nouveauRestant = pret.montant_restant - aPayer;
        await sbUpdate('personnages', `name=eq.${encodeURIComponent(pret.emprunteur)}`, { arg: emprunteur.arg - aPayer });
        await sbUpdatePret(pret.id, {
          montant_restant: nouveauRestant,
          jours_impayes: 0,
          statut: nouveauRestant <= 0 ? 'remboursé' : 'en_cours'
        });
        resultats.preleves++;
      } else {
        const nouveauxJoursImpayes = (pret.jours_impayes || 0) + 1;
        const estPrivee = pret.type_banque === 'privee';
        resultats.impayes++;

        if (!estPrivee) {
          if (nouveauxJoursImpayes === 1) {
            await sbInsert('mails', { destinataire: pret.emprunteur, expediteur: 'Banque Nationale', sujet: 'Impayé', corps: 'Avertissement : votre mensualité de prêt n\\'a pas pu être prélevée.', archived: false }).catch(() => {});
          } else if (nouveauxJoursImpayes === 2) {
            const penalite = Math.round(pret.montant_restant * 0.10);
            await sbUpdatePret(pret.id, { montant_restant: pret.montant_restant + penalite });
            await sbInsert('mails', { destinataire: pret.emprunteur, expediteur: 'Banque Nationale', sujet: 'Mise en demeure', corps: 'Pénalité de 10% appliquée : +' + penalite + ' ' + cur + '.', archived: false }).catch(() => {});
          } else if (nouveauxJoursImpayes === 3) {
            await sbInsert('mails', { destinataire: pret.emprunteur, expediteur: 'Banque Nationale', sujet: 'ULTIMATUM', corps: 'Remboursez l\\'intégralité de la dette sous 24h ou le bien sera saisi.', archived: false }).catch(() => {});
          } else if (nouveauxJoursImpayes >= 4) {
            await sbUpdatePret(pret.id, { statut: 'saisi' });
            if (pret.building_id) {
              const tRows = await sbGet('terrains_etat', `country=eq.${encodeURIComponent(pret.country)}&building_id=eq.${encodeURIComponent(pret.building_id)}`);
              const tRow = tRows && tRows[0];
              if (tRow) {
                let etat; try { etat = JSON.parse(tRow.data); } catch(e) { etat = {}; }
                etat.proprietaire = null; etat.coproprietaire = null;
                etat.enVenteParBanque = true;
                etat.prixVenteBanque = Math.round((etat.valeur_totale || 0) * 0.7);
                await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(tRow.id)}`, { data: JSON.stringify(etat), updated_at: new Date().toISOString() });
              }
            }
            await sbInsert('mails', { destinataire: pret.emprunteur, expediteur: 'Banque Nationale', sujet: 'SAISIE', corps: 'Votre bien a été saisi pour non-remboursement et sera remis en vente.', archived: false }).catch(() => {});
            resultats.saisies++;
            continue;
          }
        } else {
          if (nouveauxJoursImpayes >= 1 && nouveauxJoursImpayes <= 3) {
            const fraisRappel = Math.round(pret.mensualite * 0.15);
            await sbUpdate('personnages', `name=eq.${encodeURIComponent(pret.emprunteur)}`, {
              arg: Math.max(0, (emprunteur.arg || 0) - fraisRappel),
              moral: Math.max(0, (emprunteur.moral || 75) - 10)
            });
            await sbUpdatePret(pret.id, { montant_restant: pret.montant_restant + fraisRappel });
            await sbInsert('mails', { destinataire: pret.emprunteur, expediteur: 'Banque Privée Helvetia', sujet: 'Visite désagréable', corps: 'Des hommes sont passés. -' + fraisRappel + ' ' + cur + ', -10 Moral.', archived: false }).catch(() => {});
          } else if (nouveauxJoursImpayes >= 4) {
            await sbUpdatePret(pret.id, { statut: 'saisi' });
            if (pret.building_id) {
              const tRows = await sbGet('terrains_etat', `country=eq.${encodeURIComponent(pret.country)}&building_id=eq.${encodeURIComponent(pret.building_id)}`);
              const tRow = tRows && tRows[0];
              if (tRow) {
                let etat; try { etat = JSON.parse(tRow.data); } catch(e) { etat = {}; }
                etat.proprietaire = null; etat.coproprietaire = null; etat.enVenteParBanque = false;
                await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(tRow.id)}`, { data: JSON.stringify(etat), updated_at: new Date().toISOString() });
              }
            }
            await sbUpdate('personnages', `name=eq.${encodeURIComponent(pret.emprunteur)}`, { moral: Math.max(0, (emprunteur.moral || 75) - 20) });
            await sbInsert('mails', { destinataire: pret.emprunteur, expediteur: 'Banque Privée Helvetia', sujet: 'EXPROPRIATION', corps: 'Des hommes se sont présentés et ont pris les clés. Le bien a disparu. -20 Moral.', archived: false }).catch(() => {});
            resultats.saisies++;
            continue;
          }
        }

        await sbUpdatePret(pret.id, { jours_impayes: nouveauxJoursImpayes });
      }
    }
  } catch(e) { console.error('preleverPretsBancairesServeur error', e); }
  return resultats;
}

async function nettoyerAchatsDirectsManques() {"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

old_2 = """    // 8. Progression quotidienne des chantiers (versements, alea, livraison)
    const chantiers = await avancerChantiersQuotidien();

    return res.status(200).json({ ok: true, traites: results.length, details: results, mailsSupprimes: mailsSuppres, fuites, taxeFonciere, loyersLots, compromisResolus, achatsDirectsManques, chantiers });"""
new_2 = """    // 8. Progression quotidienne des chantiers (versements, alea, livraison)
    const chantiers = await avancerChantiersQuotidien();

    // 9. Mensualites des prets bancaires (a heure fixe, que le joueur dorme ou non)
    const prets = await preleverPretsBancairesServeur();

    return res.status(200).json({ ok: true, traites: results.length, details: results, mailsSupprimes: mailsSuppres, fuites, taxeFonciere, loyersLots, compromisResolus, achatsDirectsManques, chantiers, prets });"""
assert content.count(old_2) == 1, f"trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Prélèvement des mensualités de prêt porté vers le cron serveur.")
