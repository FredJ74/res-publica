// =====================
// CRON VERCEL — Traitement quotidien (élections, etc.)
// Déclenché automatiquement par vercel.json
// =====================

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://jxpwoosmmhohoihxpbuc.supabase.co';
const SUPABASE_ANON = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw';

const HEADERS = {
  'Content-Type': 'application/json',
  'apikey': SUPABASE_ANON,
  'Authorization': `Bearer ${SUPABASE_ANON}`
};

async function sbGet(table, filters = '') {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${filters}`, { headers: HEADERS });
  if (!res.ok) { console.error('sbGet error', table, await res.text()); return null; }
  return res.json();
}

async function sbInsert(table, data) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
    method: 'POST',
    headers: { ...HEADERS, 'Prefer': 'return=representation' },
    body: JSON.stringify(data)
  });
  if (!res.ok) { console.error('sbInsert error', table, await res.text()); return null; }
  return res.json();
}

async function sbUpdate(table, filters, data) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${filters}`, {
    method: 'PATCH',
    headers: { ...HEADERS, 'Prefer': 'return=representation' },
    body: JSON.stringify(data)
  });
  if (!res.ok) { console.error('sbUpdate error', table, await res.text()); return null; }
  return res.json();
}

// Noms des postes pour les annonces (synchronisé avec data.js POSTES_ELECTIFS)
const POSTE_NOMS = {
  president: 'Président de la République',
  maire: 'Maire',
  depute: 'Député',
};

const POSTE_SCOPE = {
  president: 'national', // visible empire entier
  maire: 'local',         // visible ville uniquement
  depute: 'local',
};

function calculerResultatsServer(cycle) {
  const candidats = cycle.candidats || [];
  if (candidats.length === 0) return null;

  const scores = {};
  candidats.forEach(c => { scores[c.nom] = 0; });

  (cycle.votes_pj || []).forEach(v => { if (scores[v.candidat] !== undefined) scores[v.candidat]++; });
  (cycle.votes_pnj || []).forEach(v => { if (scores[v.candidat] !== undefined) scores[v.candidat]++; });

  const totalVoix = Object.values(scores).reduce((s, v) => s + v, 0);
  if (totalVoix === 0) return { scores, totalVoix: 0, elu: null, secondTour: [] };

  const sorted = Object.entries(scores).sort((a, b) => b[1] - a[1]);
  const premier = sorted[0];

  if (premier[1] > totalVoix / 2) {
    return { scores, totalVoix, elu: premier[0], secondTour: [] };
  }
  const qualifies = sorted.filter(([, v]) => v / totalVoix >= 0.15).map(([n]) => n);
  return { scores, totalVoix, elu: null, secondTour: qualifies };
}

async function purgerVieuxMails() {
  const limite = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString();
  try {
    const filtre = `created_at=lt.${encodeURIComponent(limite)}&archived=eq.false`;
    const res = await fetch(`${SUPABASE_URL}/rest/v1/mails?${filtre}`, {
      method: 'DELETE',
      headers: { ...HEADERS, 'Prefer': 'return=representation' }
    });
    if (!res.ok) { console.error('purgerVieuxMails error', await res.text()); return 0; }
    const deleted = await res.json();
    return Array.isArray(deleted) ? deleted.length : 0;
  } catch(e) { console.error('purgerVieuxMails exception', e); return 0; }
}

// Prelevement quotidien de la taxe fonciere sur tous les terrains possedes. Priorite absolue
// sur les mensualites de prets (appelee avant preleverPretsBancaires si les deux coexistent
// un jour). Progression d'avertissements calquee sur celle des prets bancaires : 5% de la
// valeur du bien = avertissement, 15% = mise en demeure + penalite 10%, 25% = saisie par la
// mairie et mise en vente. NOTE : suppose un seul terrain par (pays, buildingId) — verifie
// le 3 aout 2026 que ce n'etait pas garanti (collision Luthecia/PSM corrigee cote data.js).
async function preleverTaxeFonciere() {
  const resultats = { collecte: 0, avertissements: 0, saisies: 0 };
  try {
    const terrains = await sbGet('terrains_etat', '');
    if (!terrains) return resultats;

    const collectesParMairie = {};
    const budgetsCache = {};

    async function getBudgetMuni(villeKey) {
      if (budgetsCache[villeKey] !== undefined) return budgetsCache[villeKey];
      const rows = await sbGet('budgets_municipaux', `id=eq.${encodeURIComponent(villeKey)}`);
      const budget = (rows && rows[0]) ? rows[0].data : null;
      budgetsCache[villeKey] = budget;
      return budget;
    }

    for (const row of terrains) {
      let etat;
      try { etat = JSON.parse(row.data); } catch(e) { continue; }
      if (!etat.proprietaire || !etat.surface) continue;

      const country = row.country;
      const city = etat.city || 'capitale';
      const villeKey = country + '_' + city;

      const budgetMuni = await getBudgetMuni(villeKey);
      if (!budgetMuni) continue;
      const tauxFoncier = budgetMuni.tauxFoncier ?? 0.05;
      const taxeDue = Math.round(etat.surface * tauxFoncier * 100) / 100;
      const valeurBien = etat.valeur_totale || (etat.surface * 12);

      const persoRows = await sbGet('personnages', `name=eq.${encodeURIComponent(etat.proprietaire)}`);
      const perso = persoRows && persoRows[0];
      if (!perso) continue;

      const argActuel = perso.arg || 0;

      if (argActuel >= taxeDue) {
        await sbUpdate('personnages', `name=eq.${encodeURIComponent(etat.proprietaire)}`, { arg: argActuel - taxeDue });
        etat.dette_fonciere = 0;
        collectesParMairie[villeKey] = (collectesParMairie[villeKey] || 0) + taxeDue;
      } else {
        const nouvelleDette = (etat.dette_fonciere || 0) + taxeDue;
        const ratio = valeurBien > 0 ? nouvelleDette / valeurBien : 0;

        if (ratio >= 0.25) {
          etat.proprietaire = null;
          etat.coproprietaire = null;
          etat.enVenteParMairie = true;
          etat.prixVenteMairie = Math.round(valeurBien * 0.7);
          etat.dette_fonciere = 0;
          resultats.saisies++;
          await sbInsert('evenements_globaux', { country, city, texte: '🏛️ SAISIE MUNICIPALE : un bien a été saisi pour non-paiement de la taxe foncière et sera remis en vente.', jour: null });
        } else {
          etat.dette_fonciere = (ratio >= 0.15) ? Math.round(nouvelleDette * 1.10) : nouvelleDette;
          resultats.avertissements++;
        }
      }

      await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(row.id)}`, { data: JSON.stringify(etat), updated_at: new Date().toISOString() });
    }

    for (const [villeKey, montant] of Object.entries(collectesParMairie)) {
      const budgetMuni = await getBudgetMuni(villeKey);
      if (!budgetMuni) continue;
      budgetMuni.caisse = (budgetMuni.caisse || 0) + montant;
      await sbUpdate('budgets_municipaux', `id=eq.${encodeURIComponent(villeKey)}`, { data: JSON.stringify(budgetMuni), updated_at: new Date().toISOString() }).catch(() => {});
      resultats.collecte += montant;
    }
  } catch(e) { console.error('preleverTaxeFonciere error', e); }
  return resultats;
}

// Prelevement quotidien des loyers de lots subdivises — le locataire paie, le proprietaire
// est credite directement, meme si aucun des deux ne s'est connecte. Avertissement puis
// expulsion en cas d'impaye (meme principe que payerLocations cote client, transpose au cron).
// Resolution ATOMIQUE d'un compromis de vente arrive a echeance (J+7). Tranche en un seul
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
}

// Nettoie les rendez-vous d'achat direct manques (au-dela des 24h de rattrapage) : le depot
// de garantie est perdu, le terrain redevient libre.
// Table dupliquee cote serveur (les niveaux de construction ne changent que rarement — si
// modifies un jour cote client, penser a repercuter ici aussi).
const NIVEAUX_CONSTRUCTION_SERVEUR = {
  hangar:            { label: 'Hangar',             cout: 30000 },
  commerce_standard: { label: 'Commerce standard',  cout: 50000 },
  commerce_premium:  { label: 'Commerce premium',   cout: 70000 },
  building:          { label: 'Building',           cout: 100000 }
};

const ALEAS_CHANTIER = [
  { cle: 'intemperies', texte: "Intempéries : le chantier a pris du retard à cause de la pluie." },
  { cle: 'canicule',    texte: "Canicule : les travaux ont été suspendus par forte chaleur, pour la sécurité des ouvriers." }
];

// Progression quotidienne de tous les chantiers en cours : verifie les versements dus,
// gere les impayes (relance J+2, perte de l'acompte + recul d'un palier a J+3), tire les
// aleas (intemperies/canicule pour l'instant), et livre le batiment quand tout est paye et
// la date de fin prevue atteinte.
async function avancerChantiersQuotidien() {
  const resultats = { livraisons: 0, impayes: 0, expulsions_palier: 0, aleas: 0 };
  try {
    const terrains = await sbGet('terrains_etat', '');
    if (!terrains) return resultats;

    for (const row of terrains) {
      let etat;
      try { etat = JSON.parse(row.data); } catch(e) { continue; }
      const ch = etat.chantier;
      if (!ch) continue;

      const maintenant = Date.now();
      const cur = 'FR';
      let modifie = true;

      if (ch.enAttentePaiement) {
        ch.joursImpayes = (ch.joursImpayes || 0) + 1;

        if (ch.joursImpayes === 2) {
          const montantDu = ch.palierPaye === 1 ? ch.montant35 : ch.montant30;
          await sbInsert('mails', {
            destinataire: etat.proprietaire, expediteur: 'Chef de Chantier',
            sujet: 'Relance — versement impayé',
            corps: 'Dernier rappel : le versement de ' + montantDu + ' ' + cur + ' n\'est toujours pas réglé. Sans paiement demain, le chantier régressera et l\'acompte déjà versé pour ce palier sera perdu.',
            archived: false
          }).catch(() => {});
        } else if (ch.joursImpayes >= 3) {
          ch.palierPaye = Math.max(1, ch.palierPaye - 1);
          ch.dateFinPrevue += 3 * 86400000;
          ch.enAttentePaiement = false;
          ch.joursImpayes = 0;
          resultats.expulsions_palier++;
          await sbInsert('mails', {
            destinataire: etat.proprietaire, expediteur: 'Chef de Chantier',
            sujet: 'Chantier régressé — acompte perdu',
            corps: 'Faute de paiement, le chantier a régressé d\'un palier. L\'acompte déjà versé pour ce palier est perdu. Il faudra le repayer pour reprendre les travaux.',
            archived: false
          }).catch(() => {});
        }
      } else if (ch.palierPaye === 1 && maintenant >= ch.dateDebut + Math.floor(ch.dureeJours / 2) * 86400000) {
        ch.enAttentePaiement = true;
        ch.joursImpayes = 0;
        await sbInsert('mails', {
          destinataire: etat.proprietaire, expediteur: 'Chef de Chantier',
          sujet: 'Versement de mi-chantier dû',
          corps: 'Le chantier a atteint la moitié de son avancement. Un versement de ' + ch.montant35 + ' ' + cur + ' est attendu pour continuer.',
          archived: false
        }).catch(() => {});
      } else if (ch.palierPaye === 2 && maintenant >= ch.dateFinPrevue) {
        ch.enAttentePaiement = true;
        ch.joursImpayes = 0;
        await sbInsert('mails', {
          destinataire: etat.proprietaire, expediteur: 'Chef de Chantier',
          sujet: 'Solde du chantier dû',
          corps: 'Le chantier est prêt à être livré. Le solde de ' + ch.montant30 + ' ' + cur + ' est attendu pour la remise des clés.',
          archived: false
        }).catch(() => {});
      } else if (ch.palierPaye >= 3 && maintenant >= ch.dateFinPrevue) {
        // Livraison
        const niveau = NIVEAUX_CONSTRUCTION_SERVEUR[ch.niveau];
        etat.niveau_construction = ch.niveau;
        etat.constructionAutorisee = true;
        delete etat.chantier;
        resultats.livraisons++;
        await sbInsert('mails', {
          destinataire: etat.proprietaire, expediteur: 'Chef de Chantier',
          sujet: 'Chantier livré !',
          corps: 'Le chantier est terminé : ' + (niveau ? niveau.label : ch.niveau) + ' livré. Les clés vous attendent sur place.',
          archived: false
        }).catch(() => {});
        await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(row.id)}`, { data: JSON.stringify(etat), updated_at: new Date().toISOString() }).catch(() => {});
        continue;
      } else if (Math.random() < 0.08) {
        const alea = ALEAS_CHANTIER[Math.floor(Math.random() * ALEAS_CHANTIER.length)];
        const joursAjoutes = 1 + Math.floor(Math.random() * 2);
        ch.dateFinPrevue += joursAjoutes * 86400000;
        ch.evenements = ch.evenements || [];
        ch.evenements.push({ cle: alea.cle, date: maintenant, joursAjoutes });
        resultats.aleas++;
        await sbInsert('mails', {
          destinataire: etat.proprietaire, expediteur: 'Chef de Chantier',
          sujet: 'Retard de chantier',
          corps: alea.texte + ' Retard : +' + joursAjoutes + ' jour(s).',
          archived: false
        }).catch(() => {});
      } else {
        modifie = false;
      }

      if (modifie) {
        etat.chantier = ch;
        await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(row.id)}`, { data: JSON.stringify(etat), updated_at: new Date().toISOString() }).catch(() => {});
      }
    }
  } catch(e) { console.error('avancerChantiersQuotidien error', e); }
  return resultats;
}

// Prelevement quotidien des mensualites de pret, cote serveur — a heure fixe, que le
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
            await sbInsert('mails', { destinataire: pret.emprunteur, expediteur: 'Banque Nationale', sujet: 'Impayé', corps: 'Avertissement : votre mensualité de prêt n\'a pas pu être prélevée.', archived: false }).catch(() => {});
          } else if (nouveauxJoursImpayes === 2) {
            const penalite = Math.round(pret.montant_restant * 0.10);
            await sbUpdatePret(pret.id, { montant_restant: pret.montant_restant + penalite });
            await sbInsert('mails', { destinataire: pret.emprunteur, expediteur: 'Banque Nationale', sujet: 'Mise en demeure', corps: 'Pénalité de 10% appliquée : +' + penalite + ' ' + cur + '.', archived: false }).catch(() => {});
          } else if (nouveauxJoursImpayes === 3) {
            await sbInsert('mails', { destinataire: pret.emprunteur, expediteur: 'Banque Nationale', sujet: 'ULTIMATUM', corps: 'Remboursez l\'intégralité de la dette sous 24h ou le bien sera saisi.', archived: false }).catch(() => {});
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

// Fin automatique d'un blocus syndical si aucun des deux leaders (Secretaire General ou
// Adjoint) ne l'a renouvele depuis plus de 25h (marge de securite sur le cycle de 24h) —
// evite qu'un blocus persiste indefiniment sans intervention. Concerne tous les bâtiments
// (pas seulement les terrains), via la table generique batiments_etat.
// Effet quotidien d'un blocus actif : malus sur la popularite du maire de la ville
// concernee, proportionnel a l'intensite du blocus. NOTE : le malus prevu sur les indices
// de ville n'est pas encore possible — INDICES_VILLES (cote client, plateau-divers.js) n'a
// aucune persistance serveur ; c'est le futur chantier dedie deja identifie le 4 aout 2026.
async function appliquerEffetsBlocusActifs() {
  const resultats = { appliques: 0 };
  try {
    const batiments = await sbGet('batiments_etat', '');
    if (!batiments) return resultats;

    for (const row of batiments) {
      let etat;
      try { etat = JSON.parse(row.data); } catch(e) { continue; }
      if (!etat.blocus) continue;

      const malusPop = Math.max(1, Math.round((etat.blocus.intensite || 40) / 15));
      const maireRows = await sbGet('personnages', `country=eq.${encodeURIComponent(row.country)}&poste->>id=like.maire*`);
      const maire = maireRows && maireRows[0];
      if (maire) {
        await sbUpdate('personnages', `name=eq.${encodeURIComponent(maire.name)}`, { pop: Math.max(0, (maire.pop || 50) - malusPop) }).catch(() => {});
        resultats.appliques++;
      }
    }
  } catch(e) { console.error('appliquerEffetsBlocusActifs error', e); }
  return resultats;
}

async function nettoyerBlocusExpires() {
  const resultats = { leves: 0 };
  try {
    const batiments = await sbGet('batiments_etat', '');
    if (!batiments) return resultats;

    for (const row of batiments) {
      let etat;
      try { etat = JSON.parse(row.data); } catch(e) { continue; }
      if (!etat.blocus) continue;

      const dernierRenouvellement = etat.blocus.dernierRenouvellementTimestamp || etat.blocus.lanceLe;
      if (Date.now() - dernierRenouvellement < 25 * 3600000) continue; // encore dans les temps

      await sbInsert('mails', {
        destinataire: etat.blocus.leaderActuel, expediteur: etat.blocus.syndicatNom || 'Syndicat',
        sujet: 'Blocus levé', corps: 'Faute de renouvellement, le blocus a été levé.', archived: false
      }).catch(() => {});

      delete etat.blocus;
      await sbUpdate('batiments_etat', `id=eq.${encodeURIComponent(row.id)}`, { data: JSON.stringify(etat), updated_at: new Date().toISOString() }).catch(() => {});
      resultats.leves++;
    }
  } catch(e) { console.error('nettoyerBlocusExpires error', e); }
  return resultats;
}

async function nettoyerAchatsDirectsManques() {
  const resultats = { manques: 0 };
  try {
    const terrains = await sbGet('terrains_etat', '');
    if (!terrains) return resultats;

    for (const row of terrains) {
      let etat;
      try { etat = JSON.parse(row.data); } catch(e) { continue; }
      if (!etat.achatDirect || !etat.achatDirect.dateLimite) continue;
      if (Date.now() <= etat.achatDirect.dateLimite) continue;

      await sbInsert('compromis_historique', {
        id: 'achatdirect-' + row.id + '-' + Date.now(),
        country: row.country,
        building_id: row.building_id,
        demandeur: etat.achatDirect.demandeur,
        resultat: 'perdu',
        detail: 'Rendez-vous notarial manqué (dépôt de ' + etat.achatDirect.acompte + ' FR perdu)'
      }).catch(() => {});

      delete etat.achatDirect;
      await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(row.id)}`, { data: JSON.stringify(etat), updated_at: new Date().toISOString() }).catch(() => {});
      resultats.manques++;
    }
  } catch(e) { console.error('nettoyerAchatsDirectsManques error', e); }
  return resultats;
}

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

async function traiterSouvenirsAccueil() {
  const resultats = { fuites: 0, expires: 0 };
  try {
    // Recuperer tous les souvenirs non encore reveles
    const res = await fetch(`${SUPABASE_URL}/rest/v1/souvenirs_accueil?revele=eq.false`, { headers: HEADERS });
    if (!res.ok) return resultats;
    const souvenirs = await res.json();
    const aujourdHui = Math.max(...souvenirs.map(s => s.jour_creation), 1); // approx, pas critique

    for (const s of souvenirs) {
      // Nettoyage : souvenir expire (12 jours passes) -> on ignore silencieusement, sera filtre cote client
      // Fuite spontanee : 5-10% de chance par jour, seulement si pas deja revele
      const chanceFuite = 0.05 + Math.random() * 0.05; // entre 5% et 10%
      if (Math.random() < chanceFuite) {
        await fetch(`${SUPABASE_URL}/rest/v1/souvenirs_accueil?id=eq.${s.id}`, {
          method: 'PATCH', headers: HEADERS, body: JSON.stringify({ revele: true })
        });
        const texte = `📰 SCANDALE : un journaliste révèle que ${s.pj_nom} a récupéré "${s.objet_nom}" au service des objets trouvés de l'Assemblée.`;
        await sbInsert('evenements_globaux', { country: 'republic', city: null, texte, jour: null });
        resultats.fuites++;
      }
    }
  } catch(e) { console.error('traiterSouvenirsAccueil error', e); }
  return resultats;
}

export default async function handler(req, res) {
  // Sécurité minimale : autoriser uniquement les appels Vercel Cron ou avec un secret
  const authHeader = req.headers['authorization'];
  if (process.env.CRON_SECRET && authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const now = new Date();
  const results = [];

  try {
    // 1. Récupérer tous les cycles électoraux
    const cycles = await sbGet('cycles_electoraux', 'select=*');
    if (!cycles) {
      return res.status(200).json({ ok: true, message: 'Aucun cycle électoral trouvé.' });
    }

    for (const row of cycles) {
      let cycle;
      try { cycle = JSON.parse(row.data); } catch(e) { continue; }

      const dateResultats = cycle.dateResultats;
      if (!dateResultats || now.getTime() < dateResultats) continue; // Pas encore échu
      if (cycle.resultatsTraites) continue; // Déjà traité

      const posteId = row.poste_id;
      const country = row.country;
      const posteNom = POSTE_NOMS[posteId] || posteId;
      const scope = POSTE_SCOPE[posteId] || 'national';

      const resultat = calculerResultatsServer(cycle);
      if (!resultat) continue;

      if (resultat.elu) {
        // Élu au tour actuel
        cycle.eluId = resultat.elu;
        cycle.resultatsTraites = true;
        cycle.phase = 'vacant'; // sera réinitialisé au prochain cycle

        const villeLabel = row.city ? ` (${row.city})` : '';
        const texte = `🗳️ RÉSULTATS : ${resultat.elu} est élu(e) ${posteNom}${villeLabel} avec ${Math.round((resultat.scores[resultat.elu]/resultat.totalVoix)*100)}% des voix.`;
        await sbInsert('evenements_globaux', {
          country, city: scope === 'local' ? (row.city || null) : null,
          texte, jour: null
        });
        results.push({ poste: posteId, country, city: row.city || null, statut: 'elu', gagnant: resultat.elu });
      } else if (resultat.secondTour.length >= 2) {
        // Second tour
        const semaine = 7 * 24 * 60 * 60 * 1000;
        cycle.tour = 2;
        cycle.candidats = resultat.secondTour.map(nom => ({ nom, voix: 0 }));
        cycle.votes_pj = [];
        cycle.votes_pnj = [];
        cycle.dateDebutCampagne = now.getTime();
        cycle.dateVote = now.getTime() + semaine;
        cycle.dateResultats = now.getTime() + semaine + 24*60*60*1000;
        cycle.phase = 'second_tour';

        const villeLabel2 = row.city ? ` (${row.city})` : '';
        const texte = `🗳️ SECOND TOUR : Aucune majorité absolue pour ${posteNom}${villeLabel2}. Second tour entre ${resultat.secondTour.join(' et ')}.`;
        await sbInsert('evenements_globaux', {
          country, city: scope === 'local' ? (row.city || null) : null,
          texte, jour: null
        });
        results.push({ poste: posteId, country, city: row.city || null, statut: 'second_tour', candidats: resultat.secondTour });
      } else {
        // Pas de résultat exploitable (0 candidat ou 0 vote) — poste vacant
        cycle.resultatsTraites = true;
        cycle.phase = 'vacant';
        results.push({ poste: posteId, country, statut: 'vacant' });
      }

      // Sauvegarder le cycle mis à jour
      await sbUpdate('cycles_electoraux', `id=eq.${row.id}`, {
        data: JSON.stringify(cycle),
        updated_at: now.toISOString()
      });
    }

    // 2. Purger les mails de plus de 14 jours, non archives (recus ET envoyes)
    const mailsSuppres = await purgerVieuxMails();

    // 3. Fuites spontanees des souvenirs de l'accueil (5-10% par jour) + nettoyage des souvenirs expires
    const fuites = await traiterSouvenirsAccueil();

    // 4. Taxe fonciere quotidienne sur tous les terrains possedes
    const taxeFonciere = await preleverTaxeFonciere();

    // 5. Loyers des lots subdivises (locataire -> proprietaire directement)
    const loyersLots = await preleverLoyersLots();

    // 6. Resolution atomique des compromis arrives a echeance (permis + pret, ensemble)
    const compromisResolus = await resoudreCompromisExpires();

    // 7. Rendez-vous d'achat direct manques (depot perdu, terrain libere)
    const achatsDirectsManques = await nettoyerAchatsDirectsManques();

    // 8. Progression quotidienne des chantiers (versements, alea, livraison)
    const chantiers = await avancerChantiersQuotidien();

    // 9. Mensualites des prets bancaires (a heure fixe, que le joueur dorme ou non)
    const prets = await preleverPretsBancairesServeur();

    // 10. Expiration des blocus syndicaux non renouveles
    const blocusExpires = await nettoyerBlocusExpires();

    // 11. Effets quotidiens des blocus actifs (malus popularite du maire)
    const effetsBlocus = await appliquerEffetsBlocusActifs();

    return res.status(200).json({ ok: true, traites: results.length, details: results, mailsSupprimes: mailsSuppres, fuites, taxeFonciere, loyersLots, compromisResolus, achatsDirectsManques, chantiers, prets, blocusExpires, effetsBlocus });
  } catch (e) {
    console.error('Erreur cron-minuit', e);
    return res.status(500).json({ error: e.message });
  }
}
