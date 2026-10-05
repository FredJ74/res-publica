#!/usr/bin/env python3
PATH = "api/cron-minuit.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """// Validation automatique d'un permis en attente depuis 7 jours sans decision du maire —
// evite qu'une demande reste bloquee indefiniment si le poste est vacant ou inactif.
// Sans reponse = reputee positive.
async function autoValiderPermisEnAttente() {
  const resultats = { valides: 0 };
  const LIMITE_JOURS_MS = 7 * 24 * 60 * 60 * 1000;
  try {
    const terrains = await sbGet('terrains_etat', '');
    if (!terrains) return resultats;

    for (const row of terrains) {
      let etat;
      try { etat = JSON.parse(row.data); } catch(e) { continue; }
      if (!etat.permis || etat.permis.statut !== 'attente_validation') continue;
      if (!etat.permis.dateEntreeAttente) continue;
      if (Date.now() - etat.permis.dateEntreeAttente < LIMITE_JOURS_MS) continue;

      etat.permis.statut = 'valide';
      etat.permis.autoValide = true;
      etat.constructionAutorisee = true;
      await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(row.id)}`, { data: JSON.stringify(etat), updated_at: new Date().toISOString() }).catch(() => {});
      resultats.valides++;
    }
  } catch(e) { console.error('autoValiderPermisEnAttente error', e); }
  return resultats;
}"""

new = """// Resolution ATOMIQUE d'un compromis de vente arrive a echeance (J+7). Tranche en un seul
// passage, dans le meme calcul, le permis ET le pret eventuellement demandes — pas de
// minuteurs separes qui pourraient se decaler. Regle : refus explicite (maire ou tirage
// pret) = remboursement de l'acompte, sans faute du joueur. Sinon (accepte ou non demande)
// = le compromis arrive simplement a echeance sans que le joueur ait acheté = acompte perdu.
// Chaque resolution est archivee dans compromis_historique.
async function resoudreCompromisExpires() {
  const resultats = { resolus: 0, rembourses: 0, perdus: 0 };
  try {
    const terrains = await sbGet('terrains_etat', '');
    if (!terrains) return resultats;

    for (const row of terrains) {
      let etat;
      try { etat = JSON.parse(row.data); } catch(e) { continue; }
      if (!etat.compromis || !etat.compromisExpireAt) continue;
      if (Date.now() < etat.compromisExpireAt) continue; // pas encore echu

      let refusExplicite = false;
      let detail = [];

      // --- Permis : decision du maire si donnee, sinon "pas de reponse = positif" MAINTENANT ---
      if (etat.permis && etat.permis.statut === 'attente_validation') {
        etat.permis.statut = 'valide';
        etat.permis.autoValide = true;
        etat.constructionAutorisee = true;
        detail.push('permis validé (sans réponse du maire)');
      } else if (etat.permis && etat.permis.statut === 'valide') {
        etat.constructionAutorisee = true;
        detail.push('permis validé par le maire');
      } else if (etat.permis && etat.permis.statut === 'refuse') {
        refusExplicite = true;
        detail.push('permis refusé par le maire');
      }

      // --- Pret : evaluation algorithmique si en attente ---
      if (etat.pretDemande && etat.pretDemande.statut === 'attente_validation') {
        const demRows = await sbGet('personnages', `name=eq.${encodeURIComponent(etat.pretDemande.demandeur)}`);
        const demandeur = demRows && demRows[0];
        const argActuel = demandeur ? (demandeur.arg || 0) : 0;
        const risque = argActuel < etat.pretDemande.montant * 0.10;
        const accorde = !risque || Math.random() < 0.5;

        if (accorde) {
          etat.pretDemande.statut = 'accorde';
          if (demandeur) {
            await sbUpdate('personnages', `name=eq.${encodeURIComponent(etat.pretDemande.demandeur)}`, { arg: argActuel + etat.pretDemande.montant });
            await sbInsert('prets', {
              id: 'pret-' + Date.now(),
              emprunteur: etat.pretDemande.demandeur,
              country: row.country,
              building_id: row.building_id,
              type_banque: 'nationale',
              montant_initial: etat.pretDemande.montant,
              montant_restant: etat.pretDemande.montantTotal,
              duree_jours: etat.pretDemande.duree,
              mensualite: etat.pretDemande.mensualite,
              jours_impayes: 0,
              statut: 'en_cours'
            }).catch(() => {});
          }
          detail.push('prêt accordé (+' + etat.pretDemande.montant + ' FR virés)');
        } else {
          etat.pretDemande.statut = 'refuse';
          refusExplicite = true;
          detail.push('prêt refusé par la banque');
        }
      }

      // --- Issue : rembourser si refus explicite, sinon l'acompte est perdu (compromis
      // arrive simplement a echeance sans achat) ---
      const proprietaireActuel = etat.compromisPar;
      if (refusExplicite && proprietaireActuel && etat.acompte) {
        const propRows = await sbGet('personnages', `name=eq.${encodeURIComponent(proprietaireActuel)}`);
        const proprio = propRows && propRows[0];
        if (proprio) {
          await sbUpdate('personnages', `name=eq.${encodeURIComponent(proprietaireActuel)}`, { arg: (proprio.arg || 0) + etat.acompte });
        }
        resultats.rembourses++;
        detail.push('acompte remboursé (' + etat.acompte + ' FR)');
      } else {
        resultats.perdus++;
        detail.push('acompte perdu (' + (etat.acompte || 0) + ' FR)');
      }

      await sbInsert('compromis_historique', {
        id: 'compromis-' + row.id + '-' + Date.now(),
        country: row.country,
        building_id: row.building_id,
        demandeur: proprietaireActuel || 'inconnu',
        resultat: refusExplicite ? 'rembourse' : 'perdu',
        detail: detail.join(' · ')
      }).catch(() => {});

      // Libere le terrain (le compromis est termine, quelle que soit l'issue)
      delete etat.compromis;
      delete etat.compromisPar;
      delete etat.acompte;
      delete etat.compromisAt;
      delete etat.compromisExpireAt;
      await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(row.id)}`, { data: JSON.stringify(etat), updated_at: new Date().toISOString() }).catch(() => {});
      resultats.resolus++;
    }
  } catch(e) { console.error('resoudreCompromisExpires error', e); }
  return resultats;
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

old_2 = """    // 6. Validation automatique des permis en attente depuis 7 jours (sans reponse = positive)
    const permisAutoValides = await autoValiderPermisEnAttente();

    return res.status(200).json({ ok: true, traites: results.length, details: results, mailsSupprimes: mailsSuppres, fuites, taxeFonciere, loyersLots, permisAutoValides });"""
new_2 = """    // 6. Resolution atomique des compromis arrives a echeance (permis + pret, ensemble)
    const compromisResolus = await resoudreCompromisExpires();

    return res.status(200).json({ ok: true, traites: results.length, details: results, mailsSupprimes: mailsSuppres, fuites, taxeFonciere, loyersLots, compromisResolus });"""
assert content.count(old_2) == 1, f"trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Résolution atomique du compromis créée : permis + prêt tranchés ensemble, remboursement si refus, archivage.")
