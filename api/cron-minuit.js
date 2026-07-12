// =====================
// CRON VERCEL — Traitement quotidien (élections, mails, souvenirs, votes de confiance, distribution fiscale)
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

async function sbUpsert(table, row) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?on_conflict=id`, {
    method: 'POST',
    headers: { ...HEADERS, 'Prefer': 'resolution=merge-duplicates' },
    body: JSON.stringify(row)
  });
  if (!res.ok) { console.error('sbUpsert error', table, await res.text()); return null; }
  return true;
}

// ===========================================================
// PARTIE 1 — ELECTIONS (existant, inchangé)
// ===========================================================

const POSTE_NOMS = {
  president: 'Président de la République',
  maire: 'Maire',
  depute: 'Député',
};

const POSTE_SCOPE = {
  president: 'national',
  maire: 'local',
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

async function traiterElections(now) {
  const results = [];
  const cycles = await sbGet('cycles_electoraux', 'select=*');
  if (!cycles) return results;

  for (const row of cycles) {
    let cycle;
    try { cycle = JSON.parse(row.data); } catch(e) { continue; }

    const dateResultats = cycle.dateResultats;
    if (!dateResultats || now.getTime() < dateResultats) continue;
    if (cycle.resultatsTraites) continue;

    const posteId = row.poste_id;
    const country = row.country;
    const posteNom = POSTE_NOMS[posteId] || posteId;
    const scope = POSTE_SCOPE[posteId] || 'national';

    const resultat = calculerResultatsServer(cycle);
    if (!resultat) continue;

    if (resultat.elu) {
      cycle.eluId = resultat.elu;
      cycle.resultatsTraites = true;
      cycle.phase = 'vacant';

      const villeLabel = row.city ? ` (${row.city})` : '';
      const texte = `🗳️ RÉSULTATS : ${resultat.elu} est élu(e) ${posteNom}${villeLabel} avec ${Math.round((resultat.scores[resultat.elu]/resultat.totalVoix)*100)}% des voix.`;
      await sbInsert('evenements_globaux', {
        country, city: scope === 'local' ? (row.city || null) : null,
        texte, jour: null
      });
      results.push({ poste: posteId, country, city: row.city || null, statut: 'elu', gagnant: resultat.elu });
    } else if (resultat.secondTour.length >= 2) {
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
      cycle.resultatsTraites = true;
      cycle.phase = 'vacant';
      results.push({ poste: posteId, country, statut: 'vacant' });
    }

    await sbUpdate('cycles_electoraux', `id=eq.${row.id}`, {
      data: JSON.stringify(cycle),
      updated_at: now.toISOString()
    });
  }
  return results;
}

// ===========================================================
// PARTIE 2 — PURGE DES VIEUX MAILS (existant, inchangé)
// ===========================================================

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

// ===========================================================
// PARTIE 3 — SOUVENIRS ACCUEIL (existant, inchangé)
// ===========================================================

async function traiterSouvenirsAccueil() {
  const resultats = { fuites: 0, expires: 0 };
  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/souvenirs_accueil?revele=eq.false`, { headers: HEADERS });
    if (!res.ok) return resultats;
    const souvenirs = await res.json();

    for (const s of souvenirs) {
      const chanceFuite = 0.05 + Math.random() * 0.05;
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

// ===========================================================
// PARTIE 4 — VOTES DE CONFIANCE (existant, inchangé)
// ===========================================================

async function cloturerVotesConfiance() {
  const resultats = [];
  try {
    const now = Date.now();
    const votes = await sbGet('votes_confiance', 'statut=eq.en_cours');
    if (!votes) return resultats;

    for (const vote of votes) {
      const creeLe = new Date(vote.created_at).getTime();
      const delaiEcoule = now - creeLe >= 48 * 60 * 60 * 1000;
      if (!delaiEcoule) continue;

      const joueurs = await sbGet('personnages', 'select=name,country,poste,current_city') || [];
      const deputesPJ = joueurs.filter(j => {
        let poste = null;
        try { poste = typeof j.poste === 'string' ? JSON.parse(j.poste) : j.poste; } catch(e) {}
        return j.country === vote.country && poste?.id?.startsWith('depute_');
      });

      const bulletins = await sbGet('votes_confiance_bulletins', `vote_id=eq.${vote.id}`) || [];

      const INDICES_NATIONAUX_APPROX = {
        republic: 30, narco: 15, soviet: 70, khalija: 60
      };
      const isn = INDICES_NATIONAUX_APPROX[vote.country] || 30;
      const chanceContrePnj = Math.min(85, 30 + isn / 2);

      let pour = 0, contre = 0;
      const votantsPJ = new Set(bulletins.map(b => b.votant));
      bulletins.forEach(b => { if (b.choix === 'pour') pour++; else contre++; });

      const siegesRestants = Math.max(0, 25 - votantsPJ.size);
      for (let i = 0; i < siegesRestants; i++) {
        if (Math.random() * 100 < chanceContrePnj) contre++; else pour++;
      }

      const confianceAccordee = pour > contre;
      const resultatTexte = confianceAccordee ? 'confiance' : 'censure';

      await sbUpdate('votes_confiance', `id=eq.${vote.id}`, { statut: 'termine', resultat: resultatTexte });

      const texte = `🏛 Vote de confiance : ${pour} POUR / ${contre} CONTRE. ` +
        (confianceAccordee
          ? `Le gouvernement de ${vote.pm_nom} obtient la confiance.`
          : `Le gouvernement de ${vote.pm_nom} est CENSURÉ et doit démissionner.`);
      await sbInsert('evenements_globaux', { country: vote.country, city: null, texte, jour: null });

      if (!confianceAccordee) {
        await sbInsert('mails', {
          id: 'mail-' + Date.now(),
          from_player: 'Assemblée Nationale', to_player: vote.pm_nom,
          subject: 'Motion de censure adoptée',
          body: `L'Assemblée Nationale a retiré sa confiance à votre gouvernement (${pour} pour / ${contre} contre). Vous devez démissionner immédiatement.`,
          time: 'Résultat du vote',
          read: false
        });
        await sbInsert('nominations_poste_attente', {
          id: 'censure-' + Date.now(),
          destinataire: vote.pm_nom,
          poste_id: 'DEMISSION_FORCEE',
          poste_name: '',
          country: vote.country,
          traite: false
        });
      }

      resultats.push({ vote_id: vote.id, pm: vote.pm_nom, pour, contre, resultat: resultatTexte });
    }
  } catch(e) { console.error('cloturerVotesConfiance error', e); }
  return resultats;
}

// ===========================================================
// PARTIE 5 — DISTRIBUTION FISCALE (nouveau)
// Ne s'execute vraiment qu'une fois par jour, a minuit heure de Paris
// ===========================================================

const PAYS_LISTE = ['republic', 'narco', 'soviet', 'khalija'];

const DAILY_TAX_REVENUE = {
  republic: { capitale: 42000, ville_a: 6000, ville_b: 4200 },
  narco:    { capitale: 18000, ville_a: 2400, ville_b: 1800 },
  soviet:   { capitale: 28000, ville_a: 4200, ville_b: 3500 },
  khalija:  { capitale: 0,     ville_a: 0,    ville_b: 0 }
};

const REPARTITION_DEFAULT = {
  presidence: 15, pm: 8, min_int: 8, min_fin: 6, min_just: 6,
  min_def: 10, min_info: 5, min_ae: 6,
  assemblee: 8, tribunal: 6, commissariat: 8, mairie: 12, reserve: 2
};

const CAISSE_PAR_POSTE_BUDGET = {
  presidence: 'palais-presidentiel', pm: 'gouvernement-pm',
  min_int: 'gouvernement-min_int', min_fin: 'gouvernement-min_fin', min_just: 'gouvernement-min_just',
  min_def: 'gouvernement-min_def', min_info: 'gouvernement-min_info', min_ae: 'gouvernement-min_ae',
  mairie: 'mairie-capitale'
};

async function getBudgetNational(pays) {
  const rows = await sbGet('budgets_nationaux', `id=eq.${pays}`);
  if (rows && rows[0]) return rows[0].data;
  return { tauxNational: 5, reserveJour: 0 };
}

async function getCaisseBatiment(pays, buildingId) {
  const key = `${pays}_${buildingId}`;
  const rows = await sbGet('caisses_batiments', `id=eq.${key}`);
  if (rows && rows[0]) return rows[0].data;
  return { solde: 0 };
}

async function crediterCaisse(pays, buildingId, montant) {
  const key = `${pays}_${buildingId}`;
  const actuelle = await getCaisseBatiment(pays, buildingId);
  const nouveauSolde = Math.max(0, (actuelle.solde || 0) + montant);
  await sbUpsert('caisses_batiments', { id: key, data: { solde: nouveauSolde }, updated_at: new Date().toISOString() });
}

async function distribuerPays(pays, jourStr) {
  const budgetNat = await getBudgetNational(pays);
  if (budgetNat.derniereDistribJourReel === jourStr) return { pays, statut: "deja fait aujourd'hui" };

  const dailyBase = Object.values(DAILY_TAX_REVENUE[pays] || {}).reduce((s, v) => s + v, 0);
  const totalDisponible = dailyBase + (budgetNat.reserveJour || 0);
  const repartition = budgetNat.repartition || REPARTITION_DEFAULT;

  for (const [posteId, buildingId] of Object.entries(CAISSE_PAR_POSTE_BUDGET)) {
    const part = (repartition[posteId] || 0) / 100;
    await crediterCaisse(pays, buildingId, Math.floor(totalDisponible * part));
  }

  budgetNat.reserveJour = 0;
  budgetNat.derniereDistribJourReel = jourStr;
  await sbUpsert('budgets_nationaux', { id: pays, data: budgetNat, updated_at: new Date().toISOString() });
  return { pays, statut: 'distribue', total: totalDisponible };
}

async function traiterDistributionFiscale() {
  const nowParis = new Date(new Date().toLocaleString('en-US', { timeZone: 'Europe/Paris' }));
  const heureParis = nowParis.getHours();
  const jourStr = nowParis.toLocaleDateString('fr-CA');

  if (heureParis !== 0) {
    return { skip: true, raison: 'Pas minuit a Paris actuellement', heureParis };
  }

  const resultats = [];
  for (const pays of PAYS_LISTE) {
    try {
      resultats.push(await distribuerPays(pays, jourStr));
    } catch (e) {
      resultats.push({ pays, statut: 'erreur', message: e.message });
    }
  }
  return { skip: false, resultats };
}

// ===========================================================
// HANDLER PRINCIPAL
// ===========================================================

export default async function handler(req, res) {
  const authHeader = req.headers['authorization'];
  if (process.env.CRON_SECRET && authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const now = new Date();

  try {
    const electionResults = await traiterElections(now);
    const mailsSuppres = await purgerVieuxMails();
    const fuites = await traiterSouvenirsAccueil();
    const votesConfianceTraites = await cloturerVotesConfiance();
    const fiscalResults = await traiterDistributionFiscale();

    return res.status(200).json({
      ok: true,
      elections: { traites: electionResults.length, details: electionResults },
      mailsSupprimes: mailsSuppres,
      fuites,
      votesConfianceTraites,
      fiscal: fiscalResults
    });
  } catch (e) {
    console.error('Erreur cron-minuit', e);
    return res.status(500).json({ error: e.message });
  }
}
