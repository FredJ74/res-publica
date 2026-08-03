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

    return res.status(200).json({ ok: true, traites: results.length, details: results, mailsSupprimes: mailsSuppres, fuites, taxeFonciere, loyersLots });
  } catch (e) {
    console.error('Erreur cron-minuit', e);
    return res.status(500).json({ error: e.message });
  }
}
