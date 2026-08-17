// =====================
// CRON VERCEL — Traitement quotidien (élections, etc.)
// Déclenché automatiquement par vercel.json
// =====================

// Journal du jour (Lot B, 17-18 aout 2026) : génération appelée en toute dernière étape du
// handler, dans son propre try/catch (voir plus bas) — jamais mélangée aux tâches critiques
// existantes ci-dessous, qui restent strictement inchangées.
import { genererToutesLesEditions } from './_journal-generation.js';

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

// Etat generique par batiment (id = country_city_buildingId), duplique de supabase.js
// car le cron tourne dans un contexte serverless isole, sans acces aux fonctions client.
// BUG CORRIGE LE 8 AOUT 2026 : ces deux fonctions etaient appelees (livrerEntrepotsQuotidien,
// produireTransformateursQuotidien) mais jamais definies ici -> ReferenceError silencieuse,
// avalee par le try/catch englobant -> aucune livraison, caisse jamais alimentee.
async function sbGetBatimentEtat(country, city, buildingId) {
  const id = country + '_' + city + '_' + buildingId;
  const rows = await sbGet('batiments_etat', `id=eq.${encodeURIComponent(id)}`);
  if (rows && rows[0]) {
    try { return JSON.parse(rows[0].data); } catch(e) { return {}; }
  }
  return {};
}

async function sbSetBatimentEtat(country, city, buildingId, patch) {
  const id = country + '_' + city + '_' + buildingId;
  const actuel = await sbGetBatimentEtat(country, city, buildingId);
  const fusion = { ...actuel, ...patch };
  const rows = await sbGet('batiments_etat', `id=eq.${encodeURIComponent(id)}`);
  if (rows && rows[0]) {
    await sbUpdate('batiments_etat', `id=eq.${encodeURIComponent(id)}`, { data: JSON.stringify(fusion), updated_at: new Date().toISOString() });
  } else {
    await sbInsert('batiments_etat', { id, country, city, building_id: buildingId, data: JSON.stringify(fusion) });
  }
  return fusion;
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

// Duree de mandat — commune aux 4 postes electifs aujourd'hui (voir POSTES_ELECTIFS,
// data.js, mandatSemaines:5 partout). A dupliquer en table complete si jamais ca diverge
// par poste un jour.
const MANDAT_SEMAINES = 5;
const SEMAINE_MS = 7 * 24 * 60 * 60 * 1000;

// Construit un cycle electoral frais (memes valeurs que initCycleElectoral cote client,
// plateau-politique.js) — utilise pour renouveler un mandat echu (PJ ou PNJ).
function construireNouveauCycleElectoral(posteId, city, now) {
  return {
    posteId, city: city || null,
    phase: 'candidatures',
    dateDebutCandidatures: now,
    dateDebutCampagne: now + SEMAINE_MS,
    dateVote: now + 2 * SEMAINE_MS,
    dateResultats: now + 2 * SEMAINE_MS + 24 * 60 * 60 * 1000,
    candidats: [],
    votes: {},
    votesPNJ: {},
    tour: 1,
    eluId: null,
    resultatsTraites: false
  };
}

function calculerResultatsServer(cycle) {
  const candidats = cycle.candidats || [];
  if (candidats.length === 0) return null;

  const scores = {};
  candidats.forEach(c => { scores[c.nom] = 0; });

  // Bug corrige le 9 aout 2026 : cette fonction lisait cycle.votes_pj/votes_pnj, des champs
  // qui n'existent nulle part ailleurs dans le jeu (toujours undefined -> totalVoix restait
  // a 0 -> aucune election traitee par ce cron n'a jamais pu declarer d'elu, meme a l'unanimite).
  // Les vrais champs, ecrits partout ailleurs (plateau-politique.js, construireNouveauCycleElectoral
  // ci-dessus), sont cycle.votes (objet votant -> nom candidat) et cycle.votesPNJ (objet pnjId -> nom candidat).
  Object.values(cycle.votes || {}).forEach(nom => { if (scores[nom] !== undefined) scores[nom]++; });
  Object.values(cycle.votesPNJ || {}).forEach(nom => { if (scores[nom] !== undefined) scores[nom]++; });

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
  const resultats = { resolus: 0, rembourses: 0, perdus: 0, pretsEnAttenteFinalisation: 0 };
  try {
    const terrains = await sbGet('terrains_etat', '');
    if (!terrains) return resultats;

    for (const row of terrains) {
      let etat;
      try { etat = JSON.parse(row.data); } catch(e) { continue; }
      if (!etat.compromis || !etat.compromisExpireAt) continue;
      if (Date.now() < etat.compromisExpireAt) continue; // pas encore echu

      // Fix du 10 aout 2026 : un pret deja accorde lors d'une precedente passe gele le
      // compromis indefiniment (pas de nouvelle echeance a fixer) -- en attente que le joueur
      // finalise via acte_vente_terrain (le controle pretOk existant, mort jusqu'ici, redevient
      // utile). Sans ce garde-fou, compromisExpireAt reste dans le passe et cette meme ligne
      // se ferait perdre/wiper a chaque passage du cron, chaque nuit, indefiniment.
      if (etat.pretDemande && etat.pretDemande.statut === 'accorde') continue;

      let refusExplicite = false;
      let detail = [];
      let pretVientDetreAccorde = false;

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
          pretVientDetreAccorde = true;
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

      // Pret accorde a l'instant, aucune autre clause (permis) refusee en meme temps : le
      // compromis reste actif, ni rembourse ni perdu -- le joueur finalisera plus tard avec
      // l'argent prete. On sauvegarde juste la decision du pret et on passe au suivant.
      if (pretVientDetreAccorde && !refusExplicite) {
        await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(row.id)}`, { data: JSON.stringify(etat), updated_at: new Date().toISOString() }).catch(() => {});
        resultats.pretsEnAttenteFinalisation++;
        continue;
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

      // Libere le terrain (le compromis est termine, quelle que soit l'issue). pretDemande
      // efface aussi desormais (10 aout 2026) : un {statut:'refuse'} laisse accroche aurait
      // bloque a tort le pretOk d'un futur compromis n'ayant rien demande.
      delete etat.compromis;
      delete etat.compromisPar;
      delete etat.acompte;
      delete etat.compromisAt;
      delete etat.compromisExpireAt;
      delete etat.pretDemande;
      await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(row.id)}`, { data: JSON.stringify(etat), updated_at: new Date().toISOString() }).catch(() => {});
      resultats.resolus++;
    }
  } catch(e) { console.error('resoudreCompromisExpires error', e); }
  return resultats;
}

// Resolution des compromis de rachat d'entreprise arrives a echeance (Notaire, chantier du
// 10 aout 2026). Pas de clause "permis" ici (aucun equivalent pour une entreprise), mais la
// meme clause "pret bancaire" que le terrain existe desormais -- meme logique que
// resoudreCompromisExpires ci-dessus (et son fix du 10 aout 2026) : un pret accorde gele le
// compromis indefiniment, en attente que le joueur finalise via acte_rachat_entreprise. Balaie
// toute la table 'entreprises' (pas une liste figee par type) pour couvrir automatiquement les
// futures entreprises rachetables sans avoir a toucher ce cron. Table 'entreprises' stocke
// data en jsonb natif (pas de JSON.parse/stringify, contrairement a terrains_etat).
async function resoudreCompromisEntreprisesExpires() {
  const resultats = { resolus: 0, rembourses: 0, perdus: 0, pretsEnAttenteFinalisation: 0 };
  try {
    const entreprises = await sbGet('entreprises', '');
    if (!entreprises) return resultats;

    for (const row of entreprises) {
      const data = row.data;
      if (!data || !data.compromis || !data.compromisExpireAt) continue;
      if (Date.now() < data.compromisExpireAt) continue; // pas encore echu

      // Meme garde-fou que le terrain : un pret deja accorde a une precedente passe ne doit
      // plus jamais faire wiper/perdre ce compromis.
      if (data.pretDemande && data.pretDemande.statut === 'accorde') continue;

      let refusExplicite = false;
      let detail = [];
      let pretVientDetreAccorde = false;
      // A2 (16 aout 2026) : le pays est lu directement dans les donnees de l'entreprise, plus
      // jamais parse depuis l'id -- 'armurerie-<country>-<city>' rendait l'ancien parsing
      // (split('-').slice(1).join('-')) faux des qu'une ville s'ajoutait a l'id (retournait
      // 'republic-ville_b' au lieu de 'republic'). Repli sur l'ancien format id sans ville
      // (compatibilite avec d'anciennes lignes qui n'auraient pas encore le champ country).
      const country = data.country || (data.id || row.id || '').split('-').slice(1)[0] || null;

      if (data.pretDemande && data.pretDemande.statut === 'attente_validation') {
        const demRows = await sbGet('personnages', `name=eq.${encodeURIComponent(data.pretDemande.demandeur)}`);
        const demandeur = demRows && demRows[0];
        const argActuel = demandeur ? (demandeur.arg || 0) : 0;
        const risque = argActuel < data.pretDemande.montant * 0.10;
        const accorde = !risque || Math.random() < 0.5;

        if (accorde) {
          data.pretDemande.statut = 'accorde';
          pretVientDetreAccorde = true;
          if (demandeur) {
            await sbUpdate('personnages', `name=eq.${encodeURIComponent(data.pretDemande.demandeur)}`, { arg: argActuel + data.pretDemande.montant });
            await sbInsert('prets', {
              id: 'pret-' + Date.now(),
              emprunteur: data.pretDemande.demandeur,
              country,
              building_id: row.id,
              type_banque: 'nationale',
              montant_initial: data.pretDemande.montant,
              montant_restant: data.pretDemande.montantTotal,
              duree_jours: data.pretDemande.duree,
              mensualite: data.pretDemande.mensualite,
              jours_impayes: 0,
              statut: 'en_cours'
            }).catch(() => {});
          }
          detail.push('prêt accordé (+' + data.pretDemande.montant + ' FR virés)');
        } else {
          data.pretDemande.statut = 'refuse';
          refusExplicite = true;
          detail.push('prêt refusé par la banque');
        }
      }

      if (pretVientDetreAccorde && !refusExplicite) {
        await sbUpdate('entreprises', `id=eq.${encodeURIComponent(row.id)}`, { data, updated_at: new Date().toISOString() }).catch(() => {});
        resultats.pretsEnAttenteFinalisation++;
        continue;
      }

      const demandeurActuel = data.compromisPar;
      if (refusExplicite && demandeurActuel && data.acompte) {
        const propRows = await sbGet('personnages', `name=eq.${encodeURIComponent(demandeurActuel)}`);
        const proprio = propRows && propRows[0];
        if (proprio) {
          await sbUpdate('personnages', `name=eq.${encodeURIComponent(demandeurActuel)}`, { arg: (proprio.arg || 0) + data.acompte });
        }
        resultats.rembourses++;
        detail.push('acompte remboursé (' + data.acompte + ' FR)');
      } else {
        resultats.perdus++;
        detail.push('acompte perdu (' + (data.acompte || 0) + ' FR)');
      }

      await sbInsert('compromis_historique', {
        id: 'compromis-entreprise-' + row.id + '-' + Date.now(),
        country,
        building_id: row.id,
        demandeur: demandeurActuel || 'inconnu',
        resultat: refusExplicite ? 'rembourse' : 'perdu',
        detail: detail.join(' · ') || ('compromis de rachat d\'entreprise expiré sans finalisation')
      }).catch(() => {});

      delete data.compromis;
      delete data.compromisPar;
      delete data.acompte;
      delete data.compromisAt;
      delete data.compromisExpireAt;
      delete data.pretDemande;
      await sbUpdate('entreprises', `id=eq.${encodeURIComponent(row.id)}`, { data, updated_at: new Date().toISOString() }).catch(() => {});
      resultats.resolus++;
    }
  } catch(e) { console.error('resoudreCompromisEntreprisesExpires error', e); }
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
              } else {
                // Pas un terrain (cle building_id+country) : tenter une entreprise (cle id
                // directe, table 'entreprises', pret de compromis de rachat d'entreprise du
                // 10 aout 2026). Pas de remise "prixVenteBanque" ici -- ce mecanisme n'existe
                // pas pour les entreprises, elle redevient simplement rachetable au prix normal.
                const eRows = await sbGet('entreprises', `id=eq.${encodeURIComponent(pret.building_id)}`);
                const eRow = eRows && eRows[0];
                if (eRow) {
                  const dataE = eRow.data || {};
                  dataE.proprietaire = 'PNJ';
                  delete dataE.compromis; delete dataE.compromisPar; delete dataE.acompte;
                  delete dataE.compromisAt; delete dataE.compromisExpireAt; delete dataE.pretDemande;
                  await sbUpdate('entreprises', `id=eq.${encodeURIComponent(eRow.id)}`, { data: dataE, updated_at: new Date().toISOString() });
                }
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
              } else {
                // Meme repli qu'a la saisie nationale ci-dessus : pas un terrain, tenter une
                // entreprise.
                const eRows = await sbGet('entreprises', `id=eq.${encodeURIComponent(pret.building_id)}`);
                const eRow = eRows && eRows[0];
                if (eRow) {
                  const dataE = eRow.data || {};
                  dataE.proprietaire = 'PNJ';
                  delete dataE.compromis; delete dataE.compromisPar; delete dataE.acompte;
                  delete dataE.compromisAt; delete dataE.compromisExpireAt; delete dataE.pretDemande;
                  await sbUpdate('entreprises', `id=eq.${encodeURIComponent(eRow.id)}`, { data: dataE, updated_at: new Date().toISOString() });
                }
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

// Remboursement quotidien du pret de preemption d'Etat (chantier "refonte des ordres",
// Doctrine V2, droit de preemption du Ministre des Finances). Contrairement aux prets joueurs
// ci-dessus, pas d'escalade/saisie en cas d'impaye -- l'Etat ne peut pas se saisir lui-meme :
// la mensualite est simplement reportee a la nuit suivante si la caisse du Ministere des
// Finances est insuffisante, sans penalite.
async function preleverPreemptionsServeur() {
  const resultats = { payes: 0, reportes: 0, soldes: 0 };
  try {
    for (const pays of ['republic', 'narco', 'soviet', 'khalija']) {
      const budgetRows = await sbGet('budgets_nationaux', `id=eq.${pays}`);
      const budgetRow = budgetRows && budgetRows[0];
      const preemption = budgetRow?.data?.preemption;
      if (!preemption) continue;

      const mensualite = Math.min(preemption.mensualite, preemption.montantRestant);
      const caisseKey = pays + '_gouvernement-min_fin';
      const caisseRows = await sbGet('caisses_batiments', `id=eq.${encodeURIComponent(caisseKey)}`);
      const caisse = caisseRows?.[0]?.data || { solde: 0 };

      if ((caisse.solde || 0) >= mensualite) {
        caisse.solde -= mensualite;
        preemption.montantRestant -= mensualite;
        await sbUpdate('caisses_batiments', `id=eq.${encodeURIComponent(caisseKey)}`, { data: caisse, updated_at: new Date().toISOString() });
        resultats.payes++;

        const nouvelleData = { ...budgetRow.data };
        if (preemption.montantRestant <= 0) {
          delete nouvelleData.preemption;
          resultats.soldes++;
        } else {
          nouvelleData.preemption = preemption;
        }
        await sbUpdate('budgets_nationaux', `id=eq.${pays}`, { data: nouvelleData, updated_at: new Date().toISOString() });
      } else {
        resultats.reportes++;
      }
    }
  } catch(e) { console.error('preleverPreemptionsServeur error', e); }
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

// Table dupliquee cote serveur (voir RESSOURCES_ECONOMIE, data.js — si modifiee cote
// client, repercuter ici aussi).
const RESSOURCES_ECONOMIE_SERVEUR = {
  cereales:     { plafond: 150, prixAchatFournisseur: 1.5, source: 'livraison' },
  poisson:      { plafond: 125, prixAchatFournisseur: 2,   source: 'livraison' },
  viande:       { plafond: 125, prixAchatFournisseur: 2.5, source: 'livraison' },
  bois:         { plafond: 750, prixAchatFournisseur: 2.5, source: 'livraison' },
  charbon:      { plafond: 400, prixAchatFournisseur: 3.5, source: 'livraison' }, // valeurs miroir de RESSOURCES_ECONOMIE.charbon, data.js (17 aout 2026)
  petrole:      { plafond: 200, prixAchatFournisseur: 4,   source: 'livraison' },
  minerai:      { plafond: 500, prixAchatFournisseur: 5,   source: 'livraison' },
  metal:        { plafond: 200, prixAchatFournisseur: 7.5, source: 'livraison' },
  plantes:      { plafond: 300, prixAchatFournisseur: 3,   source: 'livraison' },
  medicaments:  { plafond: 100, prixAchatFournisseur: 11,  source: 'transformation' },
  alcool:       { plafond: 100, prixAchatFournisseur: 7,   source: 'transformation' },
  tabac:        { plafond: 100, prixAchatFournisseur: 9,   source: 'transformation' },
  carburant:    { plafond: 100, prixAchatFournisseur: 10,  source: 'transformation' }
};

const ENTREPOTS_VILLES = [
  { buildingId: 'entrepot-logistique-luthecia', city: 'capitale' },
  { buildingId: 'entrepot-logistique-psm',      city: 'ville_a' },
  { buildingId: 'entrepot-logistique-montrouge', city: 'ville_b' }
];

const VOLUME_TOTAL_JOUR = 800;
const NB_LIVRAISONS_JOUR = 6;

// Simule les 6 livraisons quotidiennes d'un entrepot en une seule passe (limite du plan
// Vercel Hobby : un seul cron autorise par jour, pas de vrai rythme toutes les 4h). Chaque
// livraison tire aleatoirement 3 a 8 matieres premieres parmi celles pas encore pleines,
// et repartit un volume aleatoire entre elles (le total des 6 livraisons visant ~800
// unites/jour, avec une vraie irregularite entre chaque livraison). Facilement migrable
// vers un vrai cron toutes les 4h si le plan Pro est active un jour.
// Simplification actee (note pour Fred) : le prix de la vente directe du transformateur
// utilise la MEME formule dynamique que l'entrepot (stock eleve = prix bas) tant qu'aucun
// prix manuel n'est fixe — evite un systeme de prix parallele, reste coherent avec tout ce
// qu'on a deja construit. Mode "PJ directeur" (prix reglable dans la fourchette ±40%, et
// repartition entrepots/vente directe reglable) construit le 8 aout 2026 — voir
// DIRECTEUR_USINE_INFO et verifierSalaireDirecteur dans plateau-justice-economie.js.
const TRANSFORMATEURS = [
  { buildingId: 'usine-pharmaceutique-luthecia', city: 'capitale', chaines: [{ matiere: 'plantes', produit: 'medicaments' }] },
  { buildingId: 'pole-tabac-alcools-psm',        city: 'ville_a',  chaines: [{ matiere: 'cereales', produit: 'alcool' }, { matiere: 'plantes', produit: 'tabac' }] },
  { buildingId: 'raffinerie-montrouge',          city: 'ville_b',  chaines: [{ matiere: 'petrole', produit: 'carburant' }] }
];

// Volume et ratio alignes sur le travail PJ (produire_medicaments/alcool/tabac/carburant,
// plateau-justice-economie.js) le 10 aout 2026 : meme ratio de transformation pour les deux
// modes (1 matiere = 2 produits, au lieu de l'ancien RATIO_TRANSFORMATION=2 qui faisait
// l'inverse), seul le volume differe desormais. Le mode PNJ automatique n'est plus que le
// filet de securite (10% du volume d'origine, 80 -> 8) ; les 90% restants sont censes venir
// du travail remunere des joueurs.
const VOLUME_MATIERE_PAR_CHAINE_JOUR = 8; // -> 16 unites produites (ratio 1:2)
const PART_REDISTRIBUTION_ENTREPOTS = 0.6; // 20% a chacun des 3 entrepots
const PLAFOND_VENTE_DIRECTE = 50;

// Redirection d'une partie de chaque livraison quotidienne vers le stock physique de matiere
// premiere de l'usine locale (usine.stockMatieres, meme principe que l'Armurerie -- ajoute le
// 10 aout 2026, remplace l'ancien achat instantane sur la caisse de l'usine). S'accumule si
// personne ne produit, se consomme avec la production (PNJ + PJ). 20% de chaque livraison
// concernee, carve sur le meme flux (pas un volume supplementaire) -- si l'usine n'a pas la
// place, le surplus reste simplement a l'entrepot (pas de perte), demande de Fred.
const USINE_LOCALE_PAR_VILLE = {
  capitale: { buildingId: 'usine-pharmaceutique-luthecia', matieres: ['plantes'] },
  ville_a:  { buildingId: 'pole-tabac-alcools-psm',        matieres: ['cereales', 'plantes'] },
  ville_b:  { buildingId: 'raffinerie-montrouge',          matieres: ['petrole'] }
};
const PART_REDIRECTION_USINE = 0.20;

// Production quotidienne automatique (mode PNJ, filet de securite) de chaque transformateur :
// consomme sa matiere premiere depuis son propre stock physique (usine.stockMatieres, alimente
// par livrerEntrepotsQuotidien ci-dessous -- plus d'achat instantane sur caisse depuis le 10
// aout 2026), produit le bien fini au ratio 1:2, redistribue 60% aux 3 entrepots (20% chacun,
// perdu si un entrepot est deja plein sur ce produit), garde 40% en vente directe sur place
// (mini-stock propre, plafonne, prix dynamique comme un entrepot).
async function produireTransformateursQuotidien() {
  const resultats = { transformateurs: 0, uniteesProduites: 0 };
  try {
    for (const transfo of TRANSFORMATEURS) {
      const etat = await sbGetBatimentEtat('republic', transfo.city, transfo.buildingId).catch(() => null);
      if (!etat) continue; // batiment pas encore accessible dans cette ville

      // Dotation de depart, meme logique que l'entrepot
      const usine = etat.usine || { caisse: 3000, venteDirecte: {}, stockMatieres: {} };
      const venteDirecte = usine.venteDirecte || {};
      const stockMatieres = usine.stockMatieres || {};
      // Reglable par le directeur PJ en poste (tableau de bord, aout 2026) — 0.6 par defaut (mode PNJ)
      const partEntrepots = usine.repartitionEntrepots != null ? usine.repartitionEntrepots : PART_REDISTRIBUTION_ENTREPOTS;

      for (const chaine of transfo.chaines) {
        const matiereCfg = RESSOURCES_ECONOMIE_SERVEUR[chaine.matiere];
        if (!matiereCfg) continue;

        const stockDispo = stockMatieres[chaine.matiere] || 0;
        if (stockDispo < VOLUME_MATIERE_PAR_CHAINE_JOUR) continue; // pas assez de matiere en stock aujourd'hui
        stockMatieres[chaine.matiere] = stockDispo - VOLUME_MATIERE_PAR_CHAINE_JOUR;

        const uniteesProduites = VOLUME_MATIERE_PAR_CHAINE_JOUR * 2; // 1 matiere = 2 produits
        const versEntrepots = Math.round(uniteesProduites * partEntrepots);
        const venteDirecteQte = uniteesProduites - versEntrepots;
        const parEntrepot = Math.floor(versEntrepots / ENTREPOTS_VILLES.length);

        // Redistribution 20% a chaque entrepot, perdu si deja plein sur ce produit
        for (const cible of ENTREPOTS_VILLES) {
          const etatCible = await sbGetBatimentEtat('republic', cible.city, cible.buildingId).catch(() => null);
          if (!etatCible) continue;
          const entrepotCible = etatCible.entrepot || { stock: {}, caisse: 8500 };
          const stockCible = entrepotCible.stock || {};
          const plafondProduit = RESSOURCES_ECONOMIE_SERVEUR[chaine.produit].plafond;
          const placeRestante = Math.max(0, plafondProduit - (stockCible[chaine.produit] || 0));
          const qteStockee = Math.min(parEntrepot, placeRestante);
          stockCible[chaine.produit] = (stockCible[chaine.produit] || 0) + qteStockee;
          await sbSetBatimentEtat('republic', cible.city, cible.buildingId, { ...etatCible, entrepot: { ...entrepotCible, stock: stockCible } }).catch(() => {});
        }

        // Le reste part en vente directe, plafonne sur place
        const plafondLocal = PLAFOND_VENTE_DIRECTE;
        const placeRestanteLocal = Math.max(0, plafondLocal - (venteDirecte[chaine.produit] || 0));
        venteDirecte[chaine.produit] = (venteDirecte[chaine.produit] || 0) + Math.min(venteDirecteQte, placeRestanteLocal);

        resultats.uniteesProduites += uniteesProduites;
      }

      await sbSetBatimentEtat('republic', transfo.city, transfo.buildingId, { ...etat, usine: { ...usine, venteDirecte, stockMatieres } }).catch(() => {});
      resultats.transformateurs++;
    }
  } catch(e) { console.error('produireTransformateursQuotidien error', e); }
  return resultats;
}

async function livrerEntrepotsQuotidien() {
  const resultats = { entrepots: 0, unitesLivrees: 0, coutTotal: 0 };
  try {
    const ressourcesLivrables = Object.entries(RESSOURCES_ECONOMIE_SERVEUR).filter(([, r]) => r.source === 'livraison');

    for (const { buildingId, city } of ENTREPOTS_VILLES) {
      const etat = await sbGetBatimentEtat('republic', city, buildingId).catch(() => null);
      if (!etat) continue; // batiment pas encore accessible dans cette ville
      // Dotation de depart : de quoi remplir un stock vide a son plafond au prix fournisseur
      // (~8500 FR, calcule sur les 8 ressources livrables). Sans ca, la caisse resterait a 0
      // et l'entrepot ne pourrait jamais payer sa toute premiere livraison.
      const entrepot = etat.entrepot || { stock: {}, caisse: 8500 };
      const stock = entrepot.stock || {};
      let caisse = entrepot.caisse || 0;
      let unitesEntrepot = 0;
      let coutEntrepot = 0;

      // Usine locale de cette ville (redirection 20% des matieres qu'elle utilise, voir constante
      // PART_REDIRECTION_USINE ci-dessus)
      const usineLocale = USINE_LOCALE_PAR_VILLE[city];
      let etatUsine = null;
      let stockMatieresUsine = {};
      if (usineLocale) {
        etatUsine = await sbGetBatimentEtat('republic', city, usineLocale.buildingId).catch(() => null);
        if (etatUsine) stockMatieresUsine = (etatUsine.usine && etatUsine.usine.stockMatieres) || {};
      }

      for (let i = 0; i < NB_LIVRAISONS_JOUR; i++) {
        // Volume de cette livraison : moyenne 800/6 ~133, avec une vraie irregularite
        const moyenneParLivraison = VOLUME_TOTAL_JOUR / NB_LIVRAISONS_JOUR;
        const volumeLivraison = Math.round(moyenneParLivraison * (0.5 + Math.random()));

        // Ressources disponibles pour cette livraison (pas deja pleines)
        const disponibles = ressourcesLivrables.filter(([cle]) => (stock[cle] || 0) < RESSOURCES_ECONOMIE_SERVEUR[cle].plafond);
        if (disponibles.length === 0) continue; // tout est plein, pas de livraison possible

        const nbRessources = Math.min(disponibles.length, 3 + Math.floor(Math.random() * 6)); // 3 a 8
        const tirage = [...disponibles].sort(() => Math.random() - 0.5).slice(0, nbRessources);

        // Repartition aleatoire et inegale du volume entre les ressources tirees
        const poids = tirage.map(() => Math.random() + 0.2);
        const sommePoids = poids.reduce((s, p) => s + p, 0);

        tirage.forEach(([cle, res], idx) => {
          const qteLivree = Math.round(volumeLivraison * (poids[idx] / sommePoids));
          if (qteLivree <= 0) return;

          // Redirection vers l'usine locale, carvee sur cette meme livraison (pas un volume
          // supplementaire) -- gratuite pour l'usine (dotation publique, comme la livraison
          // elle-meme). Si l'usine n'a pas la place, le surplus reste simplement a l'entrepot.
          let qteRedirigee = 0;
          if (usineLocale && etatUsine && usineLocale.matieres.includes(cle)) {
            const qteVisee = Math.round(qteLivree * PART_REDIRECTION_USINE);
            const placeUsine = Math.max(0, res.plafond - (stockMatieresUsine[cle] || 0));
            qteRedirigee = Math.min(qteVisee, placeUsine);
            if (qteRedirigee > 0) stockMatieresUsine[cle] = (stockMatieresUsine[cle] || 0) + qteRedirigee;
          }
          const qteRestante = qteLivree - qteRedirigee;

          const placeRestante = Math.max(0, res.plafond - (stock[cle] || 0));
          const qteStockee = Math.min(qteRestante, placeRestante);

          // L'entrepot paie la totalite restante (hors part redirigee), meme ce qui depasse et se perd
          const cout = qteRestante * res.prixAchatFournisseur;
          if (caisse >= cout) {
            caisse -= cout;
            stock[cle] = (stock[cle] || 0) + qteStockee;
            unitesEntrepot += qteStockee;
            coutEntrepot += cout;
          }
          // Si la caisse ne peut pas payer, la livraison est simplement annulee (pas de dette)
        });
      }

      await sbSetBatimentEtat('republic', city, buildingId, { ...etat, entrepot: { ...entrepot, stock, caisse } }).catch(() => {});
      if (usineLocale && etatUsine) {
        await sbSetBatimentEtat('republic', city, usineLocale.buildingId, { ...etatUsine, usine: { ...(etatUsine.usine || {}), stockMatieres: stockMatieresUsine } }).catch(() => {});
      }
      resultats.entrepots++;
      resultats.unitesLivrees += unitesEntrepot;
      resultats.coutTotal += coutEntrepot;
    }
  } catch(e) { console.error('livrerEntrepotsQuotidien error', e); }
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

// =====================
// CASCADE DE NOMINATION AUTOMATIQUE — quand un poste nomme reste vacant parce que l'autorite
// censee le pourvoir est elle-meme absente (PJ ou PNJ), on installe le PNJ par defaut plutot
// que de bloquer indefiniment les mecaniques qui en dependent (plan du 8 aout 2026). Perimetre
// volontairement restreint : president->pm->[6 ministeres]->juge (via min_just), et maire->
// commissaire (par ville). N'inclut PAS commandant ni les directeurs d'usine/entrepot, deja
// fonctionnels sans titulaire. Republia uniquement pour l'instant, comme le reste du systeme
// fiscal/electoral (voir meme choix dans plateau-justice-economie.js).
// =====================
const PAYS_CASCADE = 'republic';
const VILLES_CASCADE = ['capitale', 'ville_a', 'ville_b'];

const PNJ_PAR_DEFAUT_POSTE = {
  president:   'Le Président (PNJ)',
  maire:       'Le Maire (PNJ)',
  pm:          'Le Premier Ministre (PNJ)',
  min_int:     "Le Ministre de l'Intérieur (PNJ)",
  min_fin:     'Le Ministre des Finances (PNJ)',
  min_just:    'Le Ministre de la Justice (PNJ)',
  min_def:     'Le Ministre de la Défense (PNJ)',
  min_info:    "Le Ministre de l'Information (PNJ)",
  min_ae:      'Le Ministre des Affaires Étrangères (PNJ)',
  juge:        'Juge Fontaine',
  commissaire: 'Raoul Toufaud (PNJ)',
  // Commandant et les 3 directeurs d'usine ajoutes le 10 aout 2026 (chantier "priorite PJ",
  // point 2 du backlog). Reutilise les PNJ deja en poste dans chaque batiment (data.js) plutot
  // que d'inventer des noms, sauf Commandant qui n'en avait pas encore.
  commandant:              'Commandant Tom Hawak',
  directeur_pharma:        'Bernard Piluler (PNJ)',
  directeur_tabac_alcools: 'Fernand Cendrier (PNJ)',
  directeur_raffinerie:    'Gustave Baril (PNJ)'
};

// Directeur d'entrepot (scope:ville, nomme par le maire) : un PNJ different par ville, deja en
// poste dans chaque entrepot (data.js) -- traite dans la boucle par ville ci-dessous, pas dans
// CASCADE_NATIONALE (national uniquement).
const PNJ_DIRECTEUR_ENTREPOT_PAR_VILLE = {
  capitale: 'Marcel Silo (PNJ)',
  ville_a:  'Yvon Paletier (PNJ)',
  ville_b:  'Norbert Charton (PNJ)'
};

// Cascade des postes nommes nationaux, dans l'ordre de dependance (chaque poste ne peut etre
// auto-pourvu qu'une fois celui qui le nomme deja resolu, PJ ou PNJ)
const CASCADE_NATIONALE = [
  { posteId: 'pm',       nommePar: 'president' },
  { posteId: 'min_int',  nommePar: 'pm' },
  { posteId: 'min_fin',  nommePar: 'pm' },
  { posteId: 'min_just', nommePar: 'pm' },
  { posteId: 'min_def',  nommePar: 'pm' },
  { posteId: 'min_info', nommePar: 'pm' },
  { posteId: 'min_ae',   nommePar: 'pm' },
  { posteId: 'juge',     nommePar: 'min_just' },
  { posteId: 'commandant',              nommePar: 'min_def' },
  { posteId: 'directeur_pharma',        nommePar: 'min_fin' },
  { posteId: 'directeur_tabac_alcools', nommePar: 'min_fin' },
  { posteId: 'directeur_raffinerie',    nommePar: 'min_fin' }
];

async function verifierPostesVacantsEtAutoPourvoir() {
  const resultats = { pourvus: [] };
  try {
    const now = Date.now();

    // Etat initial en memoire : qui occupe deja quoi (PJ), et quels PNJ sont deja enregistres.
    // Resolution en un seul passage (choix explicite du 8 aout 2026) : la map est mise a jour
    // au fur et a mesure des ecritures, pas relue en base entre chaque etape de la cascade.
    const joueurs = await sbGet('personnages', `select=name,country,poste,poste_depute&country=eq.${PAYS_CASCADE}`) || [];
    const titulairesPnjRows = await sbGet('titulaires_pnj', `country=eq.${PAYS_CASCADE}`) || [];

    const cle = (posteId, ville) => posteId + '|' + (ville || 'national');
    const occupePJ = new Set();
    joueurs.forEach(j => {
      let poste = j.poste;
      if (typeof poste === 'string') { try { poste = JSON.parse(poste); } catch(e) { poste = null; } }
      if (poste?.id) {
        const idNormalise = poste.id.startsWith('maire') ? 'maire' : poste.id;
        occupePJ.add(cle(idNormalise, poste.city));
      }
      // Depute est stocke a part (poste_depute), cumulable avec un autre poste — pas encore
      // couvert par la cascade ci-dessous (aucun fallback PNJ pour depute pour l'instant),
      // mais on l'enregistre deja pour ne pas ecraser un vrai depute le jour ou ce sera le cas.
      let posteDepute = j.poste_depute;
      if (typeof posteDepute === 'string') { try { posteDepute = JSON.parse(posteDepute); } catch(e) { posteDepute = null; } }
      if (posteDepute?.id) occupePJ.add(cle(posteDepute.id, posteDepute.city));
    });
    const occupePNJ = new Set(titulairesPnjRows.filter(r => r.nom_pnj).map(r => cle(r.poste_id, r.city)));
    const estOccupe = (posteId, ville) => occupePJ.has(cle(posteId, ville)) || occupePNJ.has(cle(posteId, ville));

    async function pourvoirPnj(posteId, ville, nomPnj) {
      const id = PAYS_CASCADE + '_' + posteId + '_' + (ville || 'national');
      const existing = titulairesPnjRows.find(r => r.id === id);
      const payload = { id, country: PAYS_CASCADE, poste_id: posteId, city: ville || null, nom_pnj: nomPnj, updated_at: new Date().toISOString() };
      if (existing) await sbUpdate('titulaires_pnj', `id=eq.${encodeURIComponent(id)}`, payload);
      else await sbInsert('titulaires_pnj', payload);
      occupePNJ.add(cle(posteId, ville));
      resultats.pourvus.push({ poste: posteId, city: ville || null, pnj: nomPnj });
    }

    async function pourvoirCycleElu(posteId, ville) {
      const filtre = ville
        ? `country=eq.${PAYS_CASCADE}&poste_id=eq.${posteId}&city=eq.${ville}`
        : `country=eq.${PAYS_CASCADE}&poste_id=eq.${posteId}&city=is.null`;
      const row = (await sbGet('cycles_electoraux', filtre) || [])[0];
      if (!row) return;
      const cycle = JSON.parse(row.data);
      if (!cycle.resultatsTraites || cycle.eluId) return; // pas encore echu, ou deja pourvu
      cycle.eluId = PNJ_PAR_DEFAUT_POSTE[posteId];
      cycle.phase = 'mandat';
      cycle.dateFinMandat = now + MANDAT_SEMAINES * SEMAINE_MS;
      await sbUpdate('cycles_electoraux', `id=eq.${row.id}`, { data: JSON.stringify(cycle), updated_at: new Date().toISOString() });
      occupePJ.add(cle(posteId, ville));
      resultats.pourvus.push({ poste: posteId, city: ville || null, pnj: PNJ_PAR_DEFAUT_POSTE[posteId] });
    }

    // --- President (elu, titulaire stocke dans cycle.eluId — pas dans titulaires_pnj) ---
    if (!estOccupe('president', null)) await pourvoirCycleElu('president', null);

    // --- Cascade nationale, dans l'ordre (president avant pm avant ministres avant juge) ---
    for (const { posteId, nommePar } of CASCADE_NATIONALE) {
      if (estOccupe(posteId, null)) continue;
      if (!estOccupe(nommePar, null)) continue; // l'autorite au-dessus pas encore resolue
      await pourvoirPnj(posteId, null, PNJ_PAR_DEFAUT_POSTE[posteId]);
    }

    // --- Maire (elu, par ville) + Commissaire + Directeur d'entrepot (nommes par le maire, par ville) ---
    for (const ville of VILLES_CASCADE) {
      if (!estOccupe('maire', ville)) await pourvoirCycleElu('maire', ville);
      if (!estOccupe('commissaire', ville) && estOccupe('maire', ville)) {
        await pourvoirPnj('commissaire', ville, PNJ_PAR_DEFAUT_POSTE.commissaire);
      }
      if (!estOccupe('directeur_entrepot', ville) && estOccupe('maire', ville)) {
        await pourvoirPnj('directeur_entrepot', ville, PNJ_DIRECTEUR_ENTREPOT_PAR_VILLE[ville]);
      }
    }
  } catch(e) { console.error('verifierPostesVacantsEtAutoPourvoir error', e); }
  return resultats;
}

// =====================
// BUREAU NATIONAL DE L'EMPLOI — conflit poste politique + emploi BNE (9 aout 2026)
// =====================
// Detecte tout PJ ayant simultanement un poste politique (personnages.poste) ET un emploi BNE
// actif (batiments_etat, id='<pays>_national_bne', voir sbGetEtatBNE cote client) — rendu
// possible par les 3 systemes de postes paralleles et non synchronises entre eux (dette
// technique notee le 9 aout 2026, JOURNAL-SESSION.md), qui ne verifient jamais l'incompatibilite
// avec un emploi BNE. Envoie un mail d'arbitrage plutot que de trancher automatiquement (regle
// demandee par Fred) — l'emploi BNE n'est PAS touche ici, il continue d'etre paye tant que
// le joueur n'a pas explicitement demissionne (au Bureau, ou de son poste politique par les
// canaux habituels).
//
// IMPORTANT : le reste de ce fichier envoie ses mails avec des noms de colonnes differents
// (destinataire/expediteur/sujet/corps) de ceux relus par le client (to_player/from_player/
// subject/body, voir sbGetMailsFor et l'affichage des mails non lus dans plateau-communication.js)
// — tres probablement le meme genre de bug que celui corrige ce soir sur le cycle electoral
// (votes_pj/votes_pnj). Pas corrige ici (hors perimetre BNE), mais le nouveau mail ci-dessous
// utilise volontairement le VRAI schema (to_player/from_player/subject/body) pour ne pas
// reproduire le probleme. A signaler/traiter separement.
// Resolution des investissements arrives a echeance (J+7, chantier "refonte des ordres" /
// Doctrine V2). Score = Base(50) + 2*(INT_snapshot-13) + (IE_ville-50)/5 -- INT est fige au
// moment de la mise (equipe du joueur a ce moment-la), IE_ville est lu EN DIRECT a l'echeance
// (pas snapshot), pour Republia uniquement (indices_villes). Rendement borne [-12%;+12%].
async function resoudreInvestissementsExpires() {
  const resultats = { resolus: 0 };
  const investissements = await sbGet('investissements', 'statut=eq.en_cours');
  if (!investissements) return resultats;

  for (const inv of investissements) {
    if (Date.now() < new Date(inv.jour_resolution_at).getTime()) continue;

    let ie = 50;
    if (inv.pays === 'republic' && inv.ville) {
      const rows = await sbGet('indices_villes', `id=eq.${encodeURIComponent(inv.pays + '_' + inv.ville)}`);
      ie = rows?.[0]?.data?.ie ?? 50;
    }

    const score = 50 + 2 * ((inv.int_snapshot || 8) - 13) + (ie - 50) / 5;
    const rendementPct = Math.max(-12, Math.min(12, (score - 50) * 0.24));
    const montantFinal = Math.round(inv.montant_initial * (1 + rendementPct / 100));

    const demRows = await sbGet('personnages', `name=eq.${encodeURIComponent(inv.joueur)}`);
    const demandeur = demRows && demRows[0];
    if (demandeur) {
      await sbUpdate('personnages', `name=eq.${encodeURIComponent(inv.joueur)}`, { arg: (demandeur.arg || 0) + montantFinal });
    }
    await sbUpdate('investissements', `id=eq.${encodeURIComponent(inv.id)}`, {
      statut: 'resolu',
      rendement_pct: Math.round(rendementPct * 100) / 100,
      montant_final: montantFinal
    });
    resultats.resolus++;
  }
  return resultats;
}

async function verifierConflitsEmploiBNE() {
  const resultats = { notifies: [] };
  try {
    const idBNE = PAYS_CASCADE + '_national_bne';
    const etatRows = await sbGet('batiments_etat', `id=eq.${encodeURIComponent(idBNE)}`);
    if (!etatRows || !etatRows[0]) return resultats;
    let etat;
    try { etat = JSON.parse(etatRows[0].data); } catch(e) { return resultats; }
    const offres = etat.offres || {};

    const joueurs = await sbGet('personnages', `select=name,country,poste&country=eq.${PAYS_CASCADE}`) || [];

    for (const [offreId, occupants] of Object.entries(offres)) {
      for (const occ of (occupants || [])) {
        if (occ.statut !== 'actif') continue;
        const joueur = joueurs.find(j => j.name === occ.pjNom);
        if (!joueur) continue;
        let poste = joueur.poste;
        if (typeof poste === 'string') { try { poste = JSON.parse(poste); } catch(e) { poste = null; } }
        if (!poste?.id) continue; // pas de poste politique, pas de conflit

        // Deja notifie et pas encore traite (mail non archive avec ce sujet) : ne pas renvoyer chaque nuit
        const dejaNotifie = await sbGet('mails', `to_player=eq.${encodeURIComponent(occ.pjNom)}&subject=eq.${encodeURIComponent('Poste politique et emploi BNE en même temps')}&archived=eq.false`);
        if (dejaNotifie && dejaNotifie.length > 0) continue;

        const corps = 'Vous occupez à la fois le poste politique de <strong>' + (poste.name || poste.id) + '</strong> et un emploi du Bureau National de l\'Emploi (' + offreId + '). Les deux sont incompatibles.<br><br>' +
          'Si vous conservez votre poste politique : rendez-vous au Bureau National de l\'Emploi pour démissionner de votre emploi BNE (immédiat, gratuit).<br>' +
          'Si vous préférez garder l\'emploi BNE : démissionnez de votre poste politique par les moyens habituels. Votre emploi BNE reste actif et payé en attendant votre décision.';

        await sbInsert('mails', {
          id: 'mail-bne-conflit-' + Date.now() + '-' + occ.pjNom,
          to_player: occ.pjNom,
          from_player: 'Bureau National de l\'Emploi',
          subject: 'Poste politique et emploi BNE en même temps',
          body: corps,
          time: new Date().toLocaleDateString('fr-FR'),
          read: false,
          archived: false
        }).catch(() => {});
        resultats.notifies.push({ pjNom: occ.pjNom, poste: poste.id, offre: offreId });
      }
    }
  } catch(e) { console.error('verifierConflitsEmploiBNE error', e); }
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

      // Renouvellement d'un mandat echu (titulaire PJ ou PNJ) — rouvre un cycle de
      // candidatures frais. C'etait la piece manquante du systeme electoral : sans ca,
      // un cycle resolu restait fige indefiniment (bug remonte le 8 aout 2026).
      if (cycle.phase === 'mandat' && cycle.dateFinMandat && now.getTime() >= cycle.dateFinMandat) {
        const nouveauCycle = construireNouveauCycleElectoral(row.poste_id, row.city, now.getTime());
        await sbUpdate('cycles_electoraux', `id=eq.${row.id}`, { data: JSON.stringify(nouveauCycle), updated_at: now.toISOString() });
        results.push({ poste: row.poste_id, country: row.country, city: row.city || null, statut: 'nouveau_cycle' });
        continue;
      }

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
        // Élu au tour actuel — mandat de MANDAT_SEMAINES semaines, renouvelle automatiquement
        // a echeance (voir le bloc de renouvellement plus haut dans cette meme boucle).
        cycle.eluId = resultat.elu;
        cycle.resultatsTraites = true;
        cycle.phase = 'mandat';
        cycle.dateFinMandat = now.getTime() + MANDAT_SEMAINES * SEMAINE_MS;

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
        cycle.votes = {};
        cycle.votesPNJ = {};
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

    // 1b. Cascade de nomination automatique — installe un PNJ sur les postes nommes dont
    // l'autorite de nomination vient elle-meme d'etre resolue (voir plan du 8 aout 2026)
    const cascadeAutoPourvoi = await verifierPostesVacantsEtAutoPourvoir();

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

    // 6b. Meme resolution pour les compromis de rachat d'entreprise (pas de clause, acompte
    // toujours perdu a l'echeance)
    const compromisEntreprisesResolus = await resoudreCompromisEntreprisesExpires();

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

    // 12. Livraisons quotidiennes des entrepots logistiques (6 livraisons simulees en une
    // passe, limite du plan Vercel Hobby)
    const livraisons = await livrerEntrepotsQuotidien();

    // 13. Production quotidienne des transformateurs (mode PNJ), redistribution 60/40
    const production = await produireTransformateursQuotidien();

    // 14. Conflits poste politique + emploi BNE (mail d'arbitrage, rien n'est tranche automatiquement)
    const conflitsBNE = await verifierConflitsEmploiBNE();

    // 15. Investissements arrives a echeance (J+7, chantier "refonte des ordres")
    const investissements = await resoudreInvestissementsExpires();

    // 16. Remboursement quotidien des prets de preemption d'Etat (Ministre des Finances)
    const preemptions = await preleverPreemptionsServeur();

    // 17. Journal du jour (Lot B) — STRICTEMENT en dernier, dans son propre try/catch : un
    // echec ou un depassement de son propre budget interne ne doit jamais remettre en cause les
    // 16 taches critiques ci-dessus, deja executees et sauvegardees avant ce point.
    let journalDuJour = null;
    try {
      journalDuJour = await genererToutesLesEditions();
    } catch (e) {
      console.error('Erreur Journal du jour (non bloquante pour le cron)', e);
      journalDuJour = { erreur: e.message };
    }

    return res.status(200).json({ ok: true, traites: results.length, details: results, cascadeAutoPourvoi, mailsSupprimes: mailsSuppres, fuites, taxeFonciere, loyersLots, compromisResolus, compromisEntreprisesResolus, achatsDirectsManques, chantiers, prets, blocusExpires, effetsBlocus, livraisons, production, conflitsBNE, investissements, preemptions, journalDuJour });
  } catch (e) {
    console.error('Erreur cron-minuit', e);
    return res.status(500).json({ error: e.message });
  }
}
