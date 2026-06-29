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

async function cloturerVotesConfiance() {
  const resultats = [];
  try {
    const now = Date.now();
    const votes = await sbGet('votes_confiance', 'statut=eq.en_cours');
    if (!votes) return resultats;

    // jour_cloture est exprime en "jour de jeu", pas en timestamp -- on se base plutot
    // sur le delai de 48h reel depuis la creation, plus fiable pour un cron externe
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

      const INDICES_NATIONAUX = {
        republic: 30, narco: 15, soviet: 70, khalija: 60
      };
      const isn = INDICES_NATIONAUX[vote.country] || 30;
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

    // 4. Cloturer les votes de confiance arrives a echeance (48h)
    const votesConfianceTraites = await cloturerVotesConfiance();

    return res.status(200).json({ ok: true, traites: results.length, details: results, mailsSupprimes: mailsSuppres, fuites, votesConfianceTraites });
  } catch (e) {
    console.error('Erreur cron-minuit', e);
    return res.status(500).json({ error: e.message });
  }
}
