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
      // Correctif (lot isolation des villes, 22 aout 2026) : "data" etait ecrit ici via
      // JSON.stringify(budgetMuni), alors que getBudgetMuni() ci-dessus (et tout le reste du
      // projet, chargerBudgetMunicipal()/sbSaveBudgetMunicipal(), plateau-politique.js/
      // supabase.js) le lit et l'ecrit toujours comme un objet natif, jamais une chaine --
      // budgets_municipaux.data est une colonne jsonb, pas text (contrairement a terrains_etat
      // ci-dessus, dont le JSON.stringify/JSON.parse est lui correct et coherent des deux cotes).
      // Cette double-encodage transformait silencieusement la ligne en une chaine de caracteres
      // (confirme en audit lecture seule sur republic_capitale) : chaque lecture ulterieure de
      // budgetMuni.allocation/.caisse/.tauxFoncier redevenait alors "undefined" (proprietes d'une
      // chaine), bloquant silencieusement toute redistribution vers les caisses institutionnelles
      // (Commissariat/Multimodal/Stade/Marche/Dispensaire/Tribunal) sans jamais lever d'erreur
      // visible (l'appelant, plateau-personnage.js, avale toute exception via .catch(()=>{})).
      await sbUpdate('budgets_municipaux', `id=eq.${encodeURIComponent(villeKey)}`, { data: budgetMuni, updated_at: new Date().toISOString() }).catch(() => {});
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

// =====================
// SUCCESSIONS DIFFEREES (architecture v4, 21 aout 2026) -- meme doctrine que
// resoudreCompromisExpires ci-dessus : balayage complet de la table, comparaison de timestamps
// stockes, mutation, ecriture -- pas un second moteur temporel. Table 'successions' stocke
// dispositions en jsonb natif (comme 'entreprises', pas de JSON.parse/stringify contrairement a
// terrains_etat). Toute la logique de cascade/reglement est dupliquee ici dans l'idiome raw-fetch
// du cron -- le code client (plateau-personnage.js, determinerEtapeSuivante/doRepondreHeritage)
// tourne dans un runtime navigateur totalement isole, aucun partage de code possible.
// =====================

const DELAI_CONVOCATION_MS_SUCCESSION = 10 * 24 * 60 * 60 * 1000; // 10 jours reels

async function personnageExisteReellementServeur(nom) {
  if (!nom) return false;
  const rows = await sbGet('personnages', 'name=eq.' + encodeURIComponent(nom) + '&select=name').catch(() => null);
  return !!(rows && rows.length > 0);
}

// Cascade principal -> remplacant -> legal_conjoint, amorcee a partir du role qui vient de
// renoncer (explicitement ou tacitement) -- jamais de retour en arriere (dejaConvoques), jamais
// de transmission automatique. Miroir exact de determinerEtapeSuivante() cote client.
async function determinerEtapeSuivanteServeur(disposition, roleActuel, conjointNom) {
  const maintenant = Date.now();
  const expiresAt = new Date(maintenant + DELAI_CONVOCATION_MS_SUCCESSION).toISOString();
  const convoqueLe = new Date(maintenant).toISOString();
  const dejaConvoques = new Set((disposition.chaine || []).map(e => e.role));

  if (roleActuel === 'principal' && disposition.remplacant_prevu && !dejaConvoques.has('remplacant')) {
    if (await personnageExisteReellementServeur(disposition.remplacant_prevu)) {
      return { role: 'remplacant', beneficiaire: disposition.remplacant_prevu, convoque_le: convoqueLe, expires_at: expiresAt, reponse: null, repondu_le: null };
    }
  }
  if (roleActuel !== 'legal_conjoint' && conjointNom && !dejaConvoques.has('legal_conjoint')) {
    return { role: 'legal_conjoint', beneficiaire: conjointNom, convoque_le: convoqueLe, expires_at: expiresAt, reponse: null, repondu_le: null };
  }
  return null;
}

// Reglement IDEMPOTENT d'une succession dont TOUTES les dispositions ont une decision tranchee
// (d.resultat) : transfert des biens, credit des beneficiaires, degel, credit de la fiscalite
// globale deja figee a l'ouverture (Etat 90% / notaire 10%, meme en devolution integrale sans
// heritier vivant -- section 1/9 des arbitrages), cloture finale (statut 'resolue').
//
// IDEMPOTENCE (verification demandee le 21 aout 2026) : scenario couvert -- un terrain est
// transfere, un heritier est credite, la part Etat ou notaire est creditee, puis une etape
// SUIVANTE echoue ; la succession reste 'en_attente' ; le cron repasse le lendemain. Sans
// garde-fou, ce rejeu recrediterait TOUT depuis le debut (double transfert -- inoffensif en soi,
// re-ecrire le meme proprietaire -- mais surtout double credit reel d'argent a l'heritier, a
// l'Etat et au notaire, puisque ces credits sont des += additifs). Le garde-fou : chaque
// disposition porte son propre marqueur persistant dispositions[].regle, et la fiscalite globale
// porte DEUX marqueurs distincts successions.part_etat_reglee / part_notaire_reglee (distincts
// l'un de l'autre : un des deux peut reussir et l'autre echouer sans se confondre). Chaque
// marqueur est ecrit EN BASE immediatement apres que sa mutation reelle a reussi -- jamais tous
// en un seul commit final. statut='resolue' n'est PAS le mecanisme de protection contre le rejeu
// (ce serait insuffisant : il n'est ecrit qu'apres plusieurs mutations, exactement le risque
// signale) -- ce n'est qu'un marqueur de FERMETURE pose en tout dernier, une fois que tous les
// marqueurs individuels sont deja vrais. Au rejeu, toute etape deja marquee est sautee sans
// rejouer sa mutation : aucun transfert, credit heritier, credit Etat ou credit notaire ne peut
// s'executer deux fois par cette voie.
//
// Limite assumee (documentee, non corrigee ici -- aucune transaction multi-table reelle possible
// via l'API REST Supabase, deja le cas partout ailleurs dans ce projet) : pour chaque etape, la
// mutation reelle et la pose du marqueur qui la protege restent deux appels HTTP SEPARES et
// SEQUENTIELS. Si le premier reussit et que le second echoue (fenetre tres etroite, deux appels
// consecutifs vers le meme backend), CETTE etape precise sera rejouee le lendemain -- un risque
// de double credit reduit a une seule etape a la fois, plus jamais a l'ensemble du dossier comme
// avant ce correctif. Ordre mutation-puis-marqueur choisi deliberement (jamais l'inverse) : le
// risque symetrique (marquer "fait" avant que ce ne soit reellement fait) serait pire, un
// heritier ne recevant alors jamais son du sans aucune trace d'echec.
//
// Retourne true si la succession a ete effectivement cloturee (statut='resolue') lors de CET
// appel, false sinon (reglement partiel ou deja termine avant cet appel) -- utilise par
// resoudreSuccessionsExpirees() pour ne compter dans ses statistiques que les clotures reelles.
async function reglerSuccession(s, dispositions) {
  for (const d of dispositions) {
    if (d.regle) continue; // deja mutee lors d'une passe precedente -- ne jamais rejouer

    if (d.type === 'terrain') {
      const tRows = await sbGet('terrains_etat', `country=eq.${encodeURIComponent(s.country)}&building_id=eq.${encodeURIComponent(d.id)}`).catch(() => null);
      const tRow = tRows && tRows[0];
      if (!tRow) return false;
      let etat; try { etat = JSON.parse(tRow.data); } catch(e) { return false; }
      etat.proprietaire = d.resultat.beneficiaire || null;
      etat.coproprietaire = null;
      etat.succession_gel = null;
      const r = await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(tRow.id)}`, { data: JSON.stringify(etat), updated_at: new Date().toISOString() }).catch(() => null);
      if (!r) return false;
    } else if (d.type === 'entreprise') {
      const eRows = await sbGet('entreprises', `id=eq.${encodeURIComponent(d.id)}`).catch(() => null);
      const eRow = eRows && eRows[0];
      if (!eRow) return false;
      const data = eRow.data || {};
      data.proprietaire = d.resultat.beneficiaire || 'PNJ';
      data.succession_gel = null;
      const r = await sbUpdate('entreprises', `id=eq.${encodeURIComponent(eRow.id)}`, { data, updated_at: new Date().toISOString() }).catch(() => null);
      if (!r) return false;
    } else if (d.type === 'argent' && d.part_nette > 0) {
      let credite = false;
      if (d.resultat.beneficiaire) {
        const bRows = await sbGet('personnages', `name=eq.${encodeURIComponent(d.resultat.beneficiaire)}`).catch(() => null);
        const beneficiaire = bRows && bRows[0];
        if (beneficiaire) {
          const r = await sbUpdate('personnages', `name=eq.${encodeURIComponent(d.resultat.beneficiaire)}`, { arg: (beneficiaire.arg || 0) + d.part_nette }).catch(() => null);
          if (!r) return false;
          credite = true;
        }
      }
      // Devolution a l'Etat : soit d'emblee (aucun beneficiaire, chaine epuisee), soit en repli
      // si le beneficiaire resolu a lui-meme disparu entre l'acceptation et le reglement (plutot
      // que de laisser la somme silencieusement disparaitre).
      if (!credite) {
        const budgetRows = await sbGet('budgets_nationaux', `id=eq.${encodeURIComponent(s.country)}`).catch(() => null);
        const budgetData = budgetRows?.[0]?.data || { reserveJour: 0 };
        budgetData.reserveJour = (budgetData.reserveJour || 0) + d.part_nette;
        const r = await sbUpdate('budgets_nationaux', `id=eq.${encodeURIComponent(s.country)}`, { data: budgetData, updated_at: new Date().toISOString() }).catch(() => null);
        if (!r) return false;
      }
    }

    // Marqueur pose IMMEDIATEMENT apres la mutation reelle de CETTE disposition (ecriture
    // individuelle, pas d'attente du lot complet) -- protege cette disposition precise contre
    // tout rejeu, meme si une disposition suivante echoue juste apres.
    d.regle = true;
    const rMarque = await sbUpdate('successions', `id=eq.${encodeURIComponent(s.id)}`, { dispositions }).catch(() => null);
    if (!rMarque) return false;
  }

  // Fiscalite globale -- deux marqueurs INDEPENDANTS (Etat / notaire), chacun pose immediatement
  // apres son propre credit reel, jamais recredite si deja marque.
  if (s.droits_total > 0) {
    if (!s.part_etat_reglee) {
      const budgetRows = await sbGet('budgets_nationaux', `id=eq.${encodeURIComponent(s.country)}`).catch(() => null);
      const budgetData = budgetRows?.[0]?.data || { reserveJour: 0 };
      budgetData.reserveJour = (budgetData.reserveJour || 0) + s.part_etat;
      const r = await sbUpdate('budgets_nationaux', `id=eq.${encodeURIComponent(s.country)}`, { data: budgetData, updated_at: new Date().toISOString() }).catch(() => null);
      if (!r) return false;
      const rMarque = await sbUpdate('successions', `id=eq.${encodeURIComponent(s.id)}`, { part_etat_reglee: true }).catch(() => null);
      if (!rMarque) return false;
      s.part_etat_reglee = true;
    }
    if (!s.part_notaire_reglee) {
      // Ecriture directe (sbGet/sbUpdate/sbInsert propres a ce fichier), PAS via
      // crediterCaisseBatiment() (plateau-justice-economie.js) : cette primitive partagee est de
      // toute facon inaccessible depuis ce runtime serverless (code client uniquement, jamais
      // importe ici -- meme raison que tout le reste de ce cron dispose de ses propres sbGet/
      // sbUpdate/sbInsert dupliques). Elle serait de plus impropre a un usage financier verifie :
      // elle avale les echecs Supabase et renvoie le solde local optimiste MEME si l'ecriture
      // reelle a echoue (limite deja documentee ailleurs dans ce projet). Ici au contraire,
      // l'ecriture est verifiee (r falsy = echec reel, jamais de succes fictif) avant de poser le
      // marqueur -- une primitive serveur dediee et verifiee, pas la primitive partagee.
      const caisseKey = s.country + '_office-notarial';
      const caisseRows = await sbGet('caisses_batiments', `id=eq.${encodeURIComponent(caisseKey)}`).catch(() => null);
      const caisseData = caisseRows?.[0]?.data || { solde: 0 };
      caisseData.solde = (caisseData.solde || 0) + s.part_notaire;
      const r = (caisseRows && caisseRows.length > 0)
        ? await sbUpdate('caisses_batiments', `id=eq.${encodeURIComponent(caisseKey)}`, { data: caisseData, updated_at: new Date().toISOString() }).catch(() => null)
        : await sbInsert('caisses_batiments', { id: caisseKey, data: caisseData, updated_at: new Date().toISOString() }).catch(() => null);
      if (!r) return false;
      const rMarque = await sbUpdate('successions', `id=eq.${encodeURIComponent(s.id)}`, { part_notaire_reglee: true }).catch(() => null);
      if (!rMarque) return false;
      s.part_notaire_reglee = true;
    }
  }

  const toutesReglees = dispositions.every(d => d.regle);
  const fiscaliteReglee = s.droits_total === 0 || (s.part_etat_reglee && s.part_notaire_reglee);
  if (toutesReglees && fiscaliteReglee) {
    const r = await sbUpdate('successions', `id=eq.${encodeURIComponent(s.id)}`, { statut: 'resolue', resolved_at: new Date().toISOString() }).catch(() => null);
    return !!r;
  }
  return false;
}

// Passe quotidienne : fait avancer chaque disposition independamment (silence a l'echeance =
// renonciation tacite, jamais une acceptation ; cascade immediate vers l'etape suivante des que
// la renonciation -- explicite ou tacite -- est constatee, aucune attente artificielle une fois
// la chaine effectivement epuisee) ; regle et cloture des qu'une succession n'a plus aucune
// disposition en attente.
async function resoudreSuccessionsExpirees() {
  const resultats = { convocations_expirees: 0, remplacants_convoques: 0, conjoints_convoques: 0, successions_reglees: 0 };
  try {
    const successions = await sbGet('successions', 'statut=eq.en_attente');
    if (!successions) return resultats;

    for (const s of successions) {
      const dispositions = s.dispositions || [];
      let mutated = false;
      const nouveauxConvoques = [];

      for (const d of dispositions) {
        if (d.resultat) continue; // deja resolue individuellement lors d'une passe precedente

        const chaine = d.chaine || [];
        const etape = chaine[chaine.length - 1];

        if (!etape) {
          // Chaine vide des l'ouverture (aucun beneficiaire valide identifie) -- resolution
          // anticipee au premier passage du cron, aucune attente artificielle.
          d.resultat = { beneficiaire: null, statut: 'devolution_etat' };
          d.etat = 'resolue';
          mutated = true;
          continue;
        }

        if (etape.reponse === 'accepte') {
          d.resultat = { beneficiaire: etape.beneficiaire, statut: 'accepte' };
          d.etat = 'resolue';
          mutated = true;
          continue;
        }

        if (etape.reponse === null && Date.now() > new Date(etape.expires_at).getTime()) {
          etape.reponse = 'renonce';
          etape.repondu_le = new Date().toISOString();
          mutated = true;
          resultats.convocations_expirees++;
        }

        if (etape.reponse === 'renonce') {
          const suivante = await determinerEtapeSuivanteServeur(d, etape.role, s.conjoint);
          if (suivante) {
            d.chaine.push(suivante);
            mutated = true;
            nouveauxConvoques.push(suivante.beneficiaire);
            if (suivante.role === 'remplacant') resultats.remplacants_convoques++;
            else resultats.conjoints_convoques++;
          } else {
            d.resultat = { beneficiaire: null, statut: 'devolution_etat' };
            d.etat = 'resolue';
            mutated = true;
          }
        }
      }

      // Phase decision (ci-dessus) et phase reglement (reglerSuccession) separees par leur
      // propre ecriture : les decisions fraichement tranchees cette passe (resultat/chaine) sont
      // persistees ICI, AVANT toute tentative de reglement -- jamais implicitement portees par la
      // toute premiere ecriture interne de reglerSuccession. Si cette persistance echoue, on ne
      // tente meme pas le reglement sur un etat non confirme en base : la succession sera
      // retentee integralement demain, sans aucun risque d'avoir mute un actif sur la base d'une
      // decision jamais realmente ecrite.
      if (mutated) {
        const r = await sbUpdate('successions', `id=eq.${encodeURIComponent(s.id)}`, { dispositions }).catch(() => null);
        if (!r) continue;
      }

      const toutesResolues = dispositions.every(d => !!d.resultat);
      if (toutesResolues) {
        const cloturee = await reglerSuccession(s, dispositions);
        if (cloturee) resultats.successions_reglees++;
      }

      for (const dest of nouveauxConvoques) {
        await sbInsert('mails', {
          destinataire: dest, expediteur: 'Office Notarial', sujet: 'Succession — ' + s.defunt,
          corps: 'Vous êtes convoqué(e) au sujet de la succession de ' + s.defunt + '. Rendez-vous au Bureau des Successions de l\'Office Notarial de Luthécia, rubrique « Réclamer un héritage ».',
          archived: false
        }).catch(() => {});
      }
    }
  } catch(e) { console.error('resoudreSuccessionsExpirees error', e); }
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
  // Lot boissons (20 aout 2026) : valeurs miroir de RESSOURCES_ECONOMIE.fruits_legumes/
  // produits_exotiques, data.js.
  fruits_legumes:     { plafond: 150, prixAchatFournisseur: 2, source: 'livraison' },
  produits_exotiques: { plafond: 125, prixAchatFournisseur: 3, source: 'livraison' },
  medicaments:  { plafond: 100, prixAchatFournisseur: 11,  source: 'transformation' },
  alcool:       { plafond: 100, prixAchatFournisseur: 7,   source: 'transformation' },
  tabac:        { plafond: 100, prixAchatFournisseur: 9,   source: 'transformation' },
  carburant:    { plafond: 100, prixAchatFournisseur: 10,  source: 'transformation' },
  // Filiere alcool->desinfectant (20 aout 2026) : valeurs miroir de RESSOURCES_ECONOMIE.desinfectant, data.js.
  desinfectant: { plafond: 100, prixAchatFournisseur: 9,   source: 'transformation' }
};

const ENTREPOTS_VILLES = [
  { buildingId: 'entrepot-logistique-luthecia', city: 'capitale' },
  { buildingId: 'entrepot-logistique-psm',      city: 'ville_a' },
  { buildingId: 'entrepot-logistique-montrouge', city: 'ville_b' }
];

const VOLUME_TOTAL_JOUR = 800;
const NB_LIVRAISONS_JOUR = 6;

// =====================
// LOGISTIQUE PORTUAIRE NATIONALE (lot du 25 aout 2026, Port Industriel de PSM)
// =====================
// Principe impose (clarification explicite avant codage) : ne PAS recalibrer l'abondance des
// matieres premieres. livrerEntrepotsQuotidien() generait deja, chaque jour, un volume aleatoire
// de bois/petrole/produits_exotiques directement dans CHACUN des 3 entrepots (tirage
// independant par ville, cf. boucle ENTREPOTS_VILLES plus bas). Ce lot ne change RIEN a ce
// calcul (meme RNG, memes constantes VOLUME_TOTAL_JOUR/NB_LIVRAISONS_JOUR) : il redirige
// simplement une partie de ce qui etait deja genere vers un stock portuaire intermediaire
// (etat.port.stock, batiment 'port-sainte-marie'), puis le redistribue selon les pourcentages
// du Commandant (defaut 1/3-1/3-1/3) au lieu de le crediter directement a l'entrepot d'origine
// du tirage. Le volume national total attendu (somme des 3 tirages independants d'aujourd'hui)
// reste donc identique en moyenne a avant ce lot -- aucun nouveau chiffre invente.
//
// Origines fixes (arbitrage valide, non modifiable par un PJ dans ce lot -- seuls les futurs
// Commandants des autres empires, non developpes ici, pourront un jour regler leurs propres
// exports) :
//  - bois : 50% reste une "production interieure" republicaine, generee et creditee EXACTEMENT
//    comme avant (jamais rerouree par le port) ; les 50% restants (Sovarka) transitent desormais
//    par etat.port.stock.bois avant redistribution.
//  - petrole (BRUT, pas carburant) : 100% transite desormais par le port (2/3 Al-Khalija +
//    1/3 Sovarka). La redirection existante vers la raffinerie de Montrouge (USINE_LOCALE_PAR_
//    VILLE.ville_b) reste totalement inchangee et intervient AVANT ce reroutage (le port ne
//    recoit que ce qui restait apres cette redirection, exactement comme l'entrepot local
//    recevait ce reliquat avant ce lot).
//  - produits_exotiques : 100% transite desormais par le port (El Estado = pays 'narco').
// Ces fractions ne modifient QUE l'endroit ou la quantite deja calculee atterrit (port vs
// entrepot local), jamais sa valeur.
const ORIGINE_IMPORTS_PORT = {
  bois: { republic: 0.5, soviet: 0.5 },
  petrole: { khalija: 2 / 3, soviet: 1 / 3 },
  produits_exotiques: { narco: 1 }
};
const RESSOURCES_REROUTEES_PORT = Object.keys(ORIGINE_IMPORTS_PORT); // ['bois','petrole','produits_exotiques']
const BUILDING_ID_PORT_PSM = 'port-sainte-marie';
const VILLE_ID_PORT_PSM = 'ville_a';
const REPARTITION_PORT_DEFAUT = { capitale: 100 / 3, ville_a: 100 / 3, ville_b: 100 / 3 };
const NB_ARRIVAGES_CONSERVES = 10; // historique court pour le Commandant/Marcel Ancre, pas de croissance illimitee

// Exportations validees (arbitrage) : la reference "1 ville" reutilise le plafond deja existant
// de chaque ressource (RESSOURCES_ECONOMIE_SERVEUR[x].plafond) -- pas un chiffre invente, c'est
// la seule notion de "capacite d'une ville" deja presente dans l'architecture actuelle
// (identique pour les 3 villes). cereales.plafond=150 -> 1.5 ville = 225 ; viande.plafond=125 ->
// 1 ville = 125. Destination fixe (Al-Khalija) pour ce lot uniquement.
const EXPORTATIONS_PORT = {
  cereales: { equivalentVilles: 1.5, destination: 'khalija' },
  viande:   { equivalentVilles: 1,   destination: 'khalija' }
};

// Repartit un montant entre les 3 villes selon des pourcentages arbitraires, methode du plus
// fort reste (Hamilton) -- meme algorithme deja utilise et valide pour la repartition fiscale
// nationale (distribuerMontantParVilleAuProrataFiscal, plateau-justice-economie.js) : aucun FR/
// unite perdu par arrondi, deterministe, pas de nouvelle primitive.
function repartirSelonPourcentages(montantTotal, pourcentages, villes) {
  if (montantTotal <= 0) return villes.reduce((acc, v) => { acc[v] = 0; return acc; }, {});
  const parts = villes.map(v => montantTotal * ((pourcentages[v] || 0) / 100));
  const planchers = parts.map(p => Math.floor(p));
  let reliquat = montantTotal - planchers.reduce((s, p) => s + p, 0);
  const ordre = parts
    .map((p, i) => ({ i, frac: p - planchers[i] }))
    .sort((a, b) => b.frac - a.frac || a.i - b.i);
  const montants = [...planchers];
  for (let k = 0; k < ordre.length && reliquat > 0; k++) { montants[ordre[k].i]++; reliquat--; }
  const resultat = {};
  villes.forEach((v, i) => { resultat[v] = montants[i]; });
  return resultat;
}

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
  { buildingId: 'usine-pharmaceutique-luthecia', city: 'capitale', chaines: [{ matiere: 'plantes', produit: 'medicaments' }, { matiere: 'alcool', produit: 'desinfectant' }] },
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
  // Accumulateur national (lot logistique portuaire, 25 aout 2026) : sommme, sur les 3 tirages
  // INDEPENDANTS des 3 entrepots (inchanges, meme RNG qu'avant ce lot), la part de
  // bois/petrole/produits_exotiques desormais reroutee vers le port plutot que creditee
  // directement a l'entrepot d'origine du tirage. Ecrit une seule fois a la fin de cette
  // fonction, dans etat.port.stock du batiment 'port-sainte-marie'.
  const portAccumulation = {};
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
          let qteRestante = qteLivree - qteRedirigee;

          // Reroutage port (lot logistique portuaire, 25 aout 2026) : bois (50% seulement,
          // l'autre moitie "production interieure" suit le chemin normal ci-dessous sans
          // aucun changement) et petrole/produits_exotiques (100%, la redirection usine
          // ci-dessus reste prioritaire et inchangee pour petrole -> raffinerie) partent
          // desormais au port plutot que d'etre credites/payes directement par CET entrepot --
          // meme quantite qu'avant ce lot, seule la destination change, aucun cout entrepot
          // sur la part reroutee (ce n'est plus un achat local, c'est un import national).
          if (RESSOURCES_REROUTEES_PORT.includes(cle)) {
            let qtePort = qteRestante;
            if (cle === 'bois') {
              const qteDirecte = Math.round(qteRestante * 0.5);
              qtePort = qteRestante - qteDirecte;
              qteRestante = qteDirecte; // le reste suit le chemin normal ci-dessous, inchange
            } else {
              qteRestante = 0; // rien ne suit le chemin normal pour petrole/produits_exotiques
            }
            portAccumulation[cle] = (portAccumulation[cle] || 0) + qtePort;
          }
          if (qteRestante <= 0) return;

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

    // Credit + distribution du stock portuaire (lot logistique portuaire, 25 aout 2026).
    // Aucun cout : ce n'est pas un achat, c'est l'arrivee physique d'un import deja "paye" par
    // construction (aucune caisse n'existait pour cette part avant ce lot non plus -- voir
    // commentaire ORIGINE_IMPORTS_PORT). Respecte le plafond de chaque entrepot ; le reliquat
    // non distribuable (entrepot plein) reste dans etat.port.stock, jamais perdu ni detruit.
    const ressourcesArrivees = Object.entries(portAccumulation).filter(([, q]) => q > 0);
    if (ressourcesArrivees.length > 0) {
      const etatPort = await sbGetBatimentEtat('republic', VILLE_ID_PORT_PSM, BUILDING_ID_PORT_PSM).catch(() => ({}));
      const port = (etatPort && etatPort.port) || { stock: {}, repartition: {}, arrivages: [], exportations: {} };
      const stockPort = port.stock || {};
      const villesIds = ENTREPOTS_VILLES.map(e => e.city);
      const stocksEntrepots = {};
      for (const e of ENTREPOTS_VILLES) {
        const etatE = await sbGetBatimentEtat('republic', e.city, e.buildingId).catch(() => null);
        stocksEntrepots[e.city] = { etat: etatE, buildingId: e.buildingId };
      }

      const arrivagesJour = [];
      for (const [cle, qteArrivee] of ressourcesArrivees) {
        stockPort[cle] = (stockPort[cle] || 0) + qteArrivee;
        arrivagesJour.push({ jour: new Date().toISOString(), resource: cle, qte: qteArrivee });

        // Distribution immediate selon la repartition du Commandant (defaut 1/3-1/3-1/3),
        // plafonnee par entrepot -- le reliquat non distribuable reste dans stockPort.
        const pourcentages = (port.repartition && port.repartition[cle]) || REPARTITION_PORT_DEFAUT;
        const aDistribuer = stockPort[cle];
        const repartis = repartirSelonPourcentages(aDistribuer, pourcentages, villesIds);
        let totalReellementDistribue = 0;
        for (const ville of villesIds) {
          const vise = repartis[ville];
          if (vise <= 0) continue;
          const cible = stocksEntrepots[ville];
          if (!cible || !cible.etat) continue; // batiment pas encore accessible dans cette ville
          const entrepotCible = cible.etat.entrepot || { stock: {}, caisse: 8500 };
          const stockCible = entrepotCible.stock || {};
          const plafondRes = RESSOURCES_ECONOMIE_SERVEUR[cle].plafond;
          const placeRestante = Math.max(0, plafondRes - (stockCible[cle] || 0));
          const qteRecue = Math.min(vise, placeRestante);
          if (qteRecue > 0) {
            stockCible[cle] = (stockCible[cle] || 0) + qteRecue;
            cible.etat = { ...cible.etat, entrepot: { ...entrepotCible, stock: stockCible } };
            totalReellementDistribue += qteRecue;
          }
        }
        stockPort[cle] = Math.max(0, stockPort[cle] - totalReellementDistribue);
      }

      for (const e of ENTREPOTS_VILLES) {
        const cible = stocksEntrepots[e.city];
        if (cible && cible.etat) await sbSetBatimentEtat('republic', e.city, e.buildingId, cible.etat).catch(() => {});
      }

      const arrivagesConserves = [...arrivagesJour, ...(port.arrivages || [])].slice(0, NB_ARRIVAGES_CONSERVES);
      await sbSetBatimentEtat('republic', VILLE_ID_PORT_PSM, BUILDING_ID_PORT_PSM, {
        ...(etatPort || {}),
        port: { ...port, stock: stockPort, arrivages: arrivagesConserves }
      }).catch(() => {});
    }
  } catch(e) { console.error('livrerEntrepotsQuotidien error', e); }
  return resultats;
}

// Exportations institutionnelles Republia -> Al-Khalija (lot logistique portuaire, 25 aout
// 2026). Contrairement aux imports, prelevement REEL sur le stock physique existant des 3
// entrepots (jamais de matiere creee) : si le stock national est insuffisant, seule la
// quantite reellement disponible est exportee, le taux de satisfaction est trace pour le
// Commandant/Marcel Ancre, sans consequence diplomatique automatique (hors perimetre de ce lot).
async function traiterExportationsPortQuotidien() {
  const resultats = { exportations: {} };
  try {
    const etatPort = await sbGetBatimentEtat('republic', VILLE_ID_PORT_PSM, BUILDING_ID_PORT_PSM).catch(() => ({}));
    const port = (etatPort && etatPort.port) || { stock: {}, repartition: {}, arrivages: [], exportations: {} };
    const exportations = port.exportations || {};

    const stocksEntrepots = {};
    for (const e of ENTREPOTS_VILLES) {
      const etatE = await sbGetBatimentEtat('republic', e.city, e.buildingId).catch(() => null);
      stocksEntrepots[e.city] = { etat: etatE };
    }

    for (const [cle, cfg] of Object.entries(EXPORTATIONS_PORT)) {
      // "1 ville" reutilise le plafond deja existant de la ressource (RESSOURCES_ECONOMIE_
      // SERVEUR[cle].plafond) -- aucun chiffre invente, voir EXPORTATIONS_PORT plus haut.
      const plafondRes = RESSOURCES_ECONOMIE_SERVEUR[cle].plafond;
      const contrat = Math.round(plafondRes * cfg.equivalentVilles);

      const stocksActuels = {};
      let stockTotal = 0;
      for (const e of ENTREPOTS_VILLES) {
        const s = (stocksEntrepots[e.city].etat?.entrepot?.stock?.[cle]) || 0;
        stocksActuels[e.city] = s;
        stockTotal += s;
      }

      const aExporter = Math.min(contrat, stockTotal);
      // Repartition proportionnelle au stock REEL de chaque ville (pas aux pourcentages du
      // Commandant, qui pilotent les imports, pas les exports) -- arrondi Hamilton, jamais plus
      // preleve que ce qui existe reellement dans un entrepot donne.
      const preleves = {};
      if (aExporter > 0 && stockTotal > 0) {
        const villesIds = ENTREPOTS_VILLES.map(e => e.city);
        const parts = villesIds.map(v => aExporter * (stocksActuels[v] / stockTotal));
        const planchers = parts.map(p => Math.floor(p));
        let reliquat = aExporter - planchers.reduce((s, p) => s + p, 0);
        const ordre = parts.map((p, i) => ({ i, frac: p - planchers[i] })).sort((a, b) => b.frac - a.frac || a.i - b.i);
        const montants = [...planchers];
        for (let k = 0; k < ordre.length && reliquat > 0; k++) { montants[ordre[k].i]++; reliquat--; }
        villesIds.forEach((v, i) => { preleves[v] = montants[i]; });
      }

      for (const e of ENTREPOTS_VILLES) {
        const qte = preleves[e.city] || 0;
        if (qte <= 0) continue;
        const cible = stocksEntrepots[e.city];
        if (!cible.etat) continue;
        const entrepotCible = cible.etat.entrepot || { stock: {}, caisse: 8500 };
        const stockCible = entrepotCible.stock || {};
        stockCible[cle] = Math.max(0, (stockCible[cle] || 0) - qte);
        cible.etat = { ...cible.etat, entrepot: { ...entrepotCible, stock: stockCible } };
      }

      const satisfactionPct = contrat > 0 ? Math.round((aExporter / contrat) * 10000) / 100 : 100;
      exportations[cle] = { destination: cfg.destination, contrat, envoye: aExporter, satisfactionPct, jour: new Date().toISOString() };
      resultats.exportations[cle] = { contrat, envoye: aExporter, satisfactionPct };
    }

    for (const e of ENTREPOTS_VILLES) {
      const cible = stocksEntrepots[e.city];
      if (cible.etat) await sbSetBatimentEtat('republic', e.city, e.buildingId, cible.etat).catch(() => {});
    }
    await sbSetBatimentEtat('republic', VILLE_ID_PORT_PSM, BUILDING_ID_PORT_PSM, { ...(etatPort || {}), port: { ...port, exportations } }).catch(() => {});
  } catch(e) { console.error('traiterExportationsPortQuotidien error', e); }
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

// =====================
// COTISATIONS NON ETERNELLES — club de supporters + Syndicat des Dockers de PSM (lot logistique
// portuaire, 25 aout 2026, §13). Principe valide : adhesion = 50 FR pour les deux (rejoindre_
// club_supporters passe de 150 a 50 FR pour rester coherent avec ce meme principe, voir data.js).
// Renouvellement JAMAIS eternel : supporters = a chaque nouveau championnat (evenement reel, lu
// directement sur saison.numero, pas un decompte de jours approximatif) ; syndicat = tous les 3
// mois reels (calendaire, pas un nombre de jours de jeu -- state.day est un compteur PROPRE A
// CHAQUE PERSONNAGE cote client, inutilisable pour comparer des joueurs entre eux, voir
// formatDateHeureJeu/dateReelleParisStr, plateau-core.js). Execute cote serveur/cron (comme
// preleverLoyersLots ci-dessus, meme pattern exact pour debiter le FR PERSONNEL d'un joueur
// potentiellement deconnecte) : jamais depend d'un client connecte. Si le FR manque au moment du
// renouvellement : fin d'adhesion automatique, aucune dette creee (le membre est simplement
// retire de orga.membres).
const COTISATION_MONTANT = 50;
const COTISATION_SYNDICAT_MOIS = 3;
const ID_SYNDICAT_DOCKERS_PSM = 'orga_syndicat_dockers_republic_ville_a';
// Duplique minimal de CLUBS_SPORTIFS (data.js) -- seuls country/city/id sont necessaires ici
// pour retrouver la caisse du club (budgets_clubs) associee a un club de supporters local.
const CLUBS_SPORTIFS_SERVEUR = [
  { id:'olympique-luthecia',    country:'republic', city:'capitale' },
  { id:'brise-mariannaise',     country:'republic', city:'ville_a' },
  { id:'cheminote-montrouge',   country:'republic', city:'ville_b' },
  { id:'rojos-cartel',          country:'narco',    city:'capitale' },
  { id:'fronterizos-unidos',    country:'narco',    city:'ville_a' },
  { id:'jaguares-selva',        country:'narco',    city:'ville_b' },
  { id:'dynamo-novomirsk',      country:'soviet',   city:'capitale' },
  { id:'spartak-sibirsk',       country:'soviet',   city:'ville_a' },
  { id:'kolkhoze-ouvrier',      country:'soviet',   city:'ville_b' },
  { id:'nadi-al-madina',        country:'khalija',  city:'capitale' },
  { id:'al-baraka-fc',          country:'khalija',  city:'ville_a' },
  { id:'sharq-al-nour',         country:'khalija',  city:'ville_b' }
];

async function crediterBudgetClubServeur(clubId, montant, motif) {
  const rows = await sbGet('budgets_clubs', `id=eq.${encodeURIComponent(clubId)}`);
  let data = rows && rows[0] ? rows[0].data : null;
  if (!data) data = { clubId, caisse: 0, historique: [], derniereSubventionJour: null, salaires: { titulaire: 100, remplacant: 50, primeVictoire: 150 } };
  data.caisse = Math.max(0, (data.caisse || 0) + montant);
  data.historique = data.historique || [];
  data.historique.push({ jour: null, montant, motif });
  if (data.historique.length > 50) data.historique = data.historique.slice(-50);
  if (rows && rows[0]) await sbUpdate('budgets_clubs', `id=eq.${encodeURIComponent(clubId)}`, { data, updated_at: new Date().toISOString() }).catch(() => {});
  else await sbInsert('budgets_clubs', { id: clubId, data, updated_at: new Date().toISOString() }).catch(() => {});
}

async function renouvellerCotisationsOrganisations() {
  const resultats = { renouvellements: 0, resiliations: 0 };
  try {
    const rows = await sbGet('organisations', 'select=*');
    if (!rows) return resultats;
    const saisonRows = await sbGet('championnat', 'id=eq.1&select=data');
    let saisonActuelle = null;
    if (saisonRows && saisonRows[0]) {
      try { saisonActuelle = JSON.parse(saisonRows[0].data); } catch(e) { saisonActuelle = null; }
    }
    const maintenant = Date.now();

    for (const row of rows) {
      let orga;
      try { orga = JSON.parse(row.data); } catch(e) { continue; }
      // Perimetre de ce lot : le club de supporters (adhesion 150->50 FR, renouvellement par
      // saison) et le seul Syndicat des Dockers de PSM (renouvellement tous les 3 mois). Les
      // autres organisations 'syndicale' (moteur generique orga_*, fondees par des PJ) ne sont
      // pas concernees -- aucune mecanique de cotisation validee pour elles dans ce lot.
      const estSyndicatDockersPSM = orga.type === 'syndicale' && orga.id === ID_SYNDICAT_DOCKERS_PSM;
      if (orga.type !== 'supporters' && !estSyndicatDockersPSM) continue;
      if (!orga.membres || orga.membres.length === 0) continue;

      let modifie = false;
      const membresConserves = [];

      for (const membre of orga.membres) {
        let doitRenouveler = false;
        if (orga.type === 'supporters') {
          doitRenouveler = !!saisonActuelle && membre.derniereCotisationSaison !== saisonActuelle.numero;
        } else if (membre.derniereCotisationDate) {
          const echeance = new Date(membre.derniereCotisationDate);
          echeance.setMonth(echeance.getMonth() + COTISATION_SYNDICAT_MOIS);
          doitRenouveler = maintenant >= echeance.getTime();
        }

        if (!doitRenouveler) { membresConserves.push(membre); continue; }

        const persoRows = await sbGet('personnages', `name=eq.${encodeURIComponent(membre.nom)}`);
        const perso = persoRows && persoRows[0];
        const argActuel = perso ? (perso.arg || 0) : 0;

        if (perso && argActuel >= COTISATION_MONTANT) {
          await sbUpdate('personnages', `name=eq.${encodeURIComponent(membre.nom)}`, { arg: argActuel - COTISATION_MONTANT });
          if (orga.type === 'supporters') {
            membre.derniereCotisationSaison = saisonActuelle.numero;
            const club = CLUBS_SPORTIFS_SERVEUR.find(c => c.country === orga.country && c.city === orga.city);
            if (club) await crediterBudgetClubServeur(club.id, COTISATION_MONTANT, 'Cotisation supporter (renouvellement)').catch(() => {});
          } else {
            membre.derniereCotisationDate = new Date().toISOString();
          }
          membresConserves.push(membre);
          resultats.renouvellements++;
          modifie = true;
        } else {
          resultats.resiliations++;
          modifie = true;
          await sbInsert('mails', {
            destinataire: membre.nom, expediteur: orga.nom,
            sujet: "Fin d'adhésion — cotisation non renouvelée",
            corps: 'Votre adhésion à "' + orga.nom + '" a pris fin automatiquement : la cotisation de ' + COTISATION_MONTANT + " FR n'a pas pu être prélevée. Aucune dette n'est créée.",
            archived: false
          }).catch(() => {});
        }
      }

      if (modifie) {
        orga.membres = membresConserves;
        await sbUpdate('organisations', `id=eq.${encodeURIComponent(row.id)}`, { data: JSON.stringify(orga) }).catch(() => {});
      }
    }
  } catch(e) { console.error('renouvellerCotisationsOrganisations error', e); }
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
  directeur_raffinerie:    'Gustave Baril (PNJ)',
  // Chef des Douanes (lot du 24 aout 2026) : deja en poste dans data.js (persons de la room
  // douanes, port-sainte-marie), meme convention que commissaire/directeurs -- reutilise le nom
  // deja affiche plutot que d'en inventer un second.
  chef_douanes:            'Pascal Paguevite (PNJ)',
  // Commandant du Port (lot logistique portuaire, 25 aout 2026) : deja en poste dans data.js
  // (persons de administration_portuaire, port-sainte-marie), meme convention. A la difference
  // de chef_douanes, capitaine_port n'est PAS dans POSTES_UNIQUES_A_MASQUER (plateau-
  // multijoueur.js) : Marcel Ancre reste visible dans la room meme une fois qu'un PJ est nomme.
  capitaine_port:          'Marcel Ancre (PNJ)'
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
  { posteId: 'directeur_raffinerie',    nommePar: 'min_fin' },
  { posteId: 'chef_douanes',            nommePar: 'min_int' },
  { posteId: 'capitaine_port',          nommePar: 'min_fin' }
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

      // Retour du Commandant PNJ = reset des repartitions (regle precisee le 25 aout 2026,
      // apres le rapport initial du lot logistique portuaire) : la repartition 1/3-1/3-1/3 est
      // la DOCTRINE du PNJ, pas seulement une valeur initiale -- un ancien Commandant PJ ne doit
      // jamais pouvoir laisser une ville a 0% apres son depart. pourvoirPnj() n'est appelee pour
      // ce poste QUE lorsqu'il etait reellement vacant l'instant d'avant (ni PJ ni PNJ deja
      // titulaire, voir estOccupe() plus haut) : c'est le point de convergence UNIQUE de tous
      // les chemins de perte du poste (revocation, demission, mort/suppression du personnage,
      // arrestation, naturalisation...), donc cette regle les couvre tous sans avoir a patcher
      // chacun individuellement. Une succession PJ -> PJ directe (accepterNominationPosteNomme/
      // accepterCandidaturePoste, plateau-politique.js) installe le nouveau titulaire PJ sans
      // jamais repasser par une vacance ni par pourvoirPnj() : jamais resetee, comme demande.
      if (posteId === 'capitaine_port') {
        const etatPort = await sbGetBatimentEtat('republic', VILLE_ID_PORT_PSM, BUILDING_ID_PORT_PSM).catch(() => ({}));
        const port = (etatPort && etatPort.port) || {};
        if (port.repartition && Object.keys(port.repartition).length > 0) {
          await sbSetBatimentEtat('republic', VILLE_ID_PORT_PSM, BUILDING_ID_PORT_PSM, { ...(etatPort || {}), port: { ...port, repartition: {} } }).catch(() => {});
        }
      }
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

// =====================
// FRET MARITIME INTERNATIONAL (lot du 24 aout 2026) — passage en_transit -> arrivee
// =====================
// Le seul point qui doit faire arriver reellement une caisse a destination : ne depend d'aucun
// client, aucun doDormir(), aucun tick d'horloge navigateur (exigence explicite du lot). Le cron
// tourne 1x/jour de facon inconditionnelle (vercel.json, 23h UTC). quantite_arrivee est figee
// ici (somme du contenu reel au moment de l'arrivee), base fixe pour le calcul de la valeur
// administrative restante lors d'une eventuelle liquidation J15.
async function traiterArriveesCaissesFret() {
  const resultats = { arrivees: 0 };
  const caisses = await sbGet('caisses_fret', 'statut=eq.en_transit');
  if (!caisses) return resultats;

  const maintenant = new Date();
  for (const c of caisses) {
    if (!c.date_arrivee_prevue || maintenant.getTime() < new Date(c.date_arrivee_prevue).getTime()) continue;

    const contenu = await sbGet('contenu_caisses_fret', 'caisse_id=eq.' + encodeURIComponent(c.id));
    const quantiteArrivee = (contenu || []).reduce((s, l) => s + (l.quantite || 0), 0);

    await sbUpdate('caisses_fret', `id=eq.${encodeURIComponent(c.id)}`, {
      statut: 'arrivee',
      date_arrivee_reelle: maintenant.toISOString(),
      quantite_arrivee: quantiteArrivee
    });
    resultats.arrivees++;
  }
  return resultats;
}

// J15 (arbitrage valide) : caisse arrivee mais jamais entierement videe -> statut 'a_vendre'.
// Ne debite jamais l'ancien destinataire (il perd simplement son droit sur la caisse, aucune
// ecriture financiere ici) ; aucune recette n'est creee tant que personne n'achete le lot (voir
// acheterLotNonReclameeFret, cote client).
async function traiterMiseEnVenteCaissesFret() {
  const resultats = { misesEnVente: 0 };
  const caisses = await sbGet('caisses_fret', 'statut=eq.arrivee');
  if (!caisses) return resultats;

  const maintenant = new Date();
  for (const c of caisses) {
    if (!c.date_arrivee_reelle) continue;
    const joursEcoules = (maintenant.getTime() - new Date(c.date_arrivee_reelle).getTime()) / 86400000;
    if (joursEcoules < 15) continue;

    const contenu = await sbGet('contenu_caisses_fret', 'caisse_id=eq.' + encodeURIComponent(c.id));
    const quantiteRestante = (contenu || []).reduce((s, l) => s + (l.quantite || 0), 0);
    if (quantiteRestante <= 0) continue; // deja videe entre-temps (retrait synchrone cote client)

    await sbUpdate('caisses_fret', `id=eq.${encodeURIComponent(c.id)}`, {
      statut: 'a_vendre',
      date_mise_en_vente: maintenant.toISOString()
    });
    resultats.misesEnVente++;
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
  // Securite FAIL CLOSED (18 aout 2026, correctif suite a un declenchement accidentel reel en
  // production) : si CRON_SECRET n'est pas configure, aucune tache ne demarre -- l'ancien
  // comportement (if (process.env.CRON_SECRET && ...)) laissait cet endpoint totalement ouvert
  // tant que la variable n'existait pas. Vercel Cron envoie automatiquement CRON_SECRET dans
  // l'en-tete Authorization des que cette variable est configuree dans le projet -- aucune
  // modification supplementaire n'est necessaire cote appelant legitime.
  const authHeader = req.headers['authorization'];
  if (!process.env.CRON_SECRET || authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
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

    // 12b. Exportations institutionnelles du Port de PSM (lot logistique portuaire, 25 aout
    // 2026) : prelevement reel sur le stock des 3 entrepots, apres que les imports du jour ont
    // ete distribues ci-dessus.
    const exportationsPort = await traiterExportationsPortQuotidien();

    // 13. Production quotidienne des transformateurs (mode PNJ), redistribution 60/40
    const production = await produireTransformateursQuotidien();

    // 14. Conflits poste politique + emploi BNE (mail d'arbitrage, rien n'est tranche automatiquement)
    const conflitsBNE = await verifierConflitsEmploiBNE();

    // 15. Investissements arrives a echeance (J+7, chantier "refonte des ordres")
    const investissements = await resoudreInvestissementsExpires();

    // 16. Remboursement quotidien des prets de preemption d'Etat (Ministre des Finances)
    const preemptions = await preleverPreemptionsServeur();

    // 16b. Successions differees : avancement des convocations, cascade remplacant/conjoint,
    // reglement + degel des dossiers integralement resolus
    const successionsResolues = await resoudreSuccessionsExpirees();

    // 16c. Fret maritime international (lot du 24 aout 2026) : arrivee des caisses en transit
    // (en_transit -> arrivee, quantite_arrivee figee), independamment de tout client connecte
    const caissesFretArrivees = await traiterArriveesCaissesFret();

    // 16d. Fret maritime : mise en vente J15 des caisses jamais videes (arrivee -> a_vendre)
    const caissesFretMisesEnVente = await traiterMiseEnVenteCaissesFret();

    // 16e. Cotisations non eternelles (club de supporters + Syndicat des Dockers de PSM, lot
    // logistique portuaire du 25 aout 2026) : renouvellement tacite ou fin d'adhesion automatique
    const cotisationsOrganisations = await renouvellerCotisationsOrganisations();

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

    return res.status(200).json({ ok: true, traites: results.length, details: results, cascadeAutoPourvoi, mailsSupprimes: mailsSuppres, fuites, taxeFonciere, loyersLots, compromisResolus, compromisEntreprisesResolus, achatsDirectsManques, chantiers, prets, blocusExpires, effetsBlocus, livraisons, exportationsPort, production, conflitsBNE, investissements, preemptions, successionsResolues, caissesFretArrivees, caissesFretMisesEnVente, cotisationsOrganisations, journalDuJour });
  } catch (e) {
    console.error('Erreur cron-minuit', e);
    return res.status(500).json({ error: e.message });
  }
}
