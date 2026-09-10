// =====================================================================
// CRON DE L'ASSEMBLEE NATIONALE — cloture des scrutins du mercredi 22:00
// Chantier du 10 septembre 2026.
// =====================================================================
//
// POURQUOI UN ENDPOINT SEPARE DE cron-minuit.js
// cron-minuit tourne une fois par jour, a minuit. La cloture parlementaire tombe le mercredi a
// 22:00 Europe/Paris (§26) : c'est une autre heure ET un autre jour de la semaine. Vercel ne
// permet qu'une planification par entree de crons, d'ou un second endpoint plutot qu'un
// detournement du premier -- qui aurait oblige a faire tourner tout le traitement de minuit
// (elections, loyers, prets, detentions) une seconde fois chaque mercredi soir.
//
// PLANIFICATION — voir vercel.json :
//     { "path": "/api/cron-assemblee", "schedule": "0 21 * * 3" }
// Vercel Cron planifie en UTC. 21:00 UTC = 22:00 Paris en heure d'HIVER (CET, UTC+1) et 23:00
// Paris en heure d'ETE (CEST, UTC+2). C'est exactement la meme approximation que celle deja
// retenue par cron-minuit.js ("0 23 * * *", cale sur minuit d'hiver) : le projet assume une
// derive d'une heure sur la moitie de l'annee plutot que deux planifications concurrentes.
// L'IMPRECISION EST SANS CONSEQUENCE SUR L'EQUITE : c'est la RPC qui compare now() a cloture_ts,
// donc un declenchement tardif ne fait que retarder le depouillement, jamais fausser le resultat.
// Un vote arrive apres cloture_ts est refuse par assemblee_voter meme si le cron n'a pas encore
// tourne (§53).
//
// AUTORITE
// Ce fichier ne CALCULE aucun resultat. Il appelle assemblee_cloturer_echues, qui fait tout le
// depouillement dans une transaction Postgres : comptage, archive nominative, changement de
// statut, entree en vigueur d'une loi mecanique, extinction d'une loi abrogee. La fonction est
// idempotente -- un scrutin deja clos renvoie son archive sans rien remodifier.
//
// Depend de migration_assemblee_nationale.sql et migration_assemblee_securisation_droits.sql
// (appliquees le 10 septembre 2026).
//
// IDENTITE SERVEUR (correctif de securite du 10 septembre 2026). La cloture et l'ouverture des
// sessions sont des operations SYSTEME : leurs RPC n'accordent EXECUTE qu'au service_role
// (migration_assemblee_securisation_droits.sql). Avec la cle anon -- publique, lisible dans
// supabase.js -- n'importe quel joueur pouvait les declencher lui-meme. Meme convention que
// prelever_loyer_bail dans cron-minuit.js : variable d'environnement Vercel, jamais exposee au
// navigateur. Les ecritures de publication (forum, evenements, chronique) restent sur la cle anon,
// inchangees : ce sont des tables que le client ecrit deja.
//
// L'echeance des sessions n'est plus calculee ici : la base la fixe elle-meme (mercredi 22:00
// Europe/Paris) et refuse toute ouverture hors de la fenetre du mercredi soir, meme pour ce cron.

const SUPABASE_URL = 'https://jxpwoosmmhohoihxpbuc.supabase.co';
const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw';
const SUPABASE_SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY || null;

const HEADERS = {
  'Content-Type': 'application/json',
  'apikey': SUPABASE_ANON,
  'Authorization': `Bearer ${SUPABASE_ANON}`
};
const HEADERS_SERVICE = {
  'Content-Type': 'application/json',
  'apikey': SUPABASE_SERVICE_ROLE,
  'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE}`
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

// Toujours sous identite serveur : ce fichier n'appelle que des RPC systeme.
async function sbRpc(fn, params) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: { ...HEADERS_SERVICE, 'Prefer': 'return=representation' },
    body: JSON.stringify(params || {})
  });
  if (!res.ok) { console.error('sbRpc error', fn, await res.text()); return null; }
  return res.json();
}

function horodatageJeu() {
  return new Date().toLocaleDateString('fr-FR');
}

// §30 : publication du resultat dans LE MEME topic forum que le debat, jamais un nouveau sujet.
// L'historique des resultats successifs est ainsi preserve pour un projet renvoye plusieurs fois.
async function publierResultatForum(topicId, scrutin) {
  if (!topicId) return;
  const lignes = [];
  lignes.push('— — — RÉSULTAT DU SCRUTIN — — —');
  lignes.push('');
  lignes.push('**' + scrutin.resultat + '** — ' + scrutin.score_pour + ' POUR / ' + scrutin.score_contre + ' CONTRE');
  lignes.push('');
  const liste = (t, a) => lignes.push(t + ' : ' + ((Array.isArray(a) && a.length) ? a.join(', ') : '—'));
  liste('POUR', scrutin.pour);
  liste('CONTRE', scrutin.contre);
  liste('ABSTENTION', scrutin.abstention);
  liste("N'A PAS VOTÉ", scrutin.non_votants);
  liste('ENDORMIS', scrutin.endormis);
  if (scrutin.resultat === 'RENVOYEE') {
    lignes.push('');
    lignes.push('Égalité : le projet n\'est pas rejeté. Il sera réexaminé lors de la prochaine session, avec de nouveaux votes et de nouvelles intentions.');
  } else if (scrutin.resultat === 'ADOPTEE') {
    lignes.push('');
    lignes.push('La loi entre en vigueur immédiatement.');
  }

  const time = horodatageJeu();
  const postId = 'post-' + Date.now() + '-' + Math.floor(Math.random() * 1000);
  await sbInsert('forum_posts', {
    id: postId, topic_id: topicId,
    author: "Secrétariat de l'Assemblée",
    content: lignes.join('\n'),
    time, author_is_org: false, author_secret: false,
    content_blocks: [], content_layout: null
  }).catch(() => {});
}

export default async function handler(req, res) {
  // Meme securite FAIL CLOSED que cron-minuit.js : sans CRON_SECRET configure, rien ne demarre.
  const authHeader = req.headers['authorization'];
  if (!process.env.CRON_SECRET || authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const now = new Date();
  const resultats = { clotures: [], sessions_ouvertes: [], erreurs: [] };

  // Sans cle serveur, les RPC systeme refuseraient l'appel : on le dit clairement plutot que de
  // laisser croire a une semaine sans scrutin echu.
  if (!SUPABASE_SERVICE_ROLE) {
    console.error('cron-assemblee : SUPABASE_SERVICE_ROLE_KEY absente, aucune cloture ni ouverture');
    return res.status(500).json({ ok: false, error: 'SUPABASE_SERVICE_ROLE_KEY absente', ...resultats });
  }

  try {
    // ---- 1. CLOTURE DES SCRUTINS ECHUS (§26) ----
    const brut = await sbRpc('assemblee_cloturer_echues', { p_country: 'republic' });
    const clotures = Array.isArray(brut) ? (Array.isArray(brut[0]) ? brut[0] : brut) : [];

    for (const c of (clotures || [])) {
      if (!c || !c.ok || c.deja_cloture) continue;
      resultats.clotures.push({
        id: c.id, titre: c.titre, resultat: c.resultat,
        pour: c.score_pour, contre: c.score_contre
      });

      // §30 — forum, dans le topic du debat.
      await publierResultatForum(c.forum_topic_id, c).catch(() => {});

      // §29 — Journal du jour / La Tribune. On reutilise evenements_globaux et
      // chronique_nationale, les deux canaux que la collecte de presse lit deja : aucune
      // structure de presse n'est modifiee.
      const verdict = c.resultat === 'ADOPTEE' ? 'ADOPTÉE'
                    : c.resultat === 'REJETEE' ? 'REJETÉE'
                    : 'RENVOYÉE À LA PROCHAINE SESSION';
      await sbInsert('evenements_globaux', {
        country: 'republic', city: null,
        texte: '🏛 ASSEMBLÉE NATIONALE — « ' + c.titre + ' » : ' + verdict
             + ' (' + c.score_pour + ' pour / ' + c.score_contre + ' contre).',
        jour: null
      }).catch(() => {});

      await sbInsert('chronique_nationale', {
        id: 'scrutin-' + c.id + '-' + Date.now(),
        country: 'republic', city: null,
        type: 'scrutin_assemblee',
        personnages: [].concat(c.pour || [], c.contre || []),
        libelle: 'L\'Assemblée nationale a ' + (c.resultat === 'ADOPTEE' ? 'adopté' : c.resultat === 'REJETEE' ? 'rejeté' : 'renvoyé')
               + ' « ' + c.titre + ' » par ' + c.score_pour + ' voix contre ' + c.score_contre + '.',
        data: {
          proposition_id: c.id, resultat: c.resultat,
          score_pour: c.score_pour, score_contre: c.score_contre,
          type: c.type, categorie: c.categorie || null, auteur: c.auteur || null
        },
        source_ref: c.id
      }).catch(() => {});
    }

    // ---- 2. OUVERTURE DES SESSIONS ELIGIBLES ----
    // Apres la cloture, et non avant : un projet renvoye pour egalite repart ainsi immediatement
    // pour une nouvelle bataille, sans attendre une semaine de plus (§27). L'echeance est fixee
    // par la base ; hors de la fenetre du mercredi soir, elle refuse (raison hors_fenetre_ouverture).
    const ouvertes = await sbRpc('assemblee_ouvrir_sessions_eligibles', { p_country: 'republic' });
    const listeOuvertes = Array.isArray(ouvertes) ? (Array.isArray(ouvertes[0]) ? ouvertes[0] : ouvertes) : [];

    let clotureSuivante = null;
    for (const o of (listeOuvertes || [])) {
      if (!o || !o.ok) {
        if (o && o.raison) resultats.erreurs.push({ id: o.id || null, raison: o.raison });
        continue;
      }
      const p = o.proposition || {};
      clotureSuivante = clotureSuivante || p.cloture_ts || null;
      resultats.sessions_ouvertes.push({ id: o.id, titre: p.titre, session_num: o.session_num });

      if (p.forum_topic_id) {
        const time = horodatageJeu();
        await sbInsert('forum_posts', {
          id: 'post-' + Date.now() + '-' + Math.floor(Math.random() * 1000),
          topic_id: p.forum_topic_id,
          author: "Secrétariat de l'Assemblée",
          content: '— — — SESSION OUVERTE — — —\n\nLe texte est désormais figé et soumis au vote. '
                 + 'Clôture le mercredi suivant à 22h00.'
                 + (o.session_num > 1 ? '\n\nNouvelle session : les votes précédents sont effacés et les intentions des députés PNJ ont été retirées au sort.' : ''),
          time, author_is_org: false, author_secret: false,
          content_blocks: [], content_layout: null
        }).catch(() => {});
      }

      await sbInsert('evenements_globaux', {
        country: 'republic', city: null,
        texte: '🏛 L\'Assemblée nationale examine « ' + (p.titre || 'un projet de loi') + ' ». Vote jusqu\'à mercredi 22h.',
        jour: null
      }).catch(() => {});
    }

    return res.status(200).json({
      ok: true,
      horodatage: now.toISOString(),
      cloture_suivante: clotureSuivante,
      nb_clotures: resultats.clotures.length,
      nb_sessions_ouvertes: resultats.sessions_ouvertes.length,
      ...resultats
    });

  } catch (e) {
    console.error('cron-assemblee error', e);
    return res.status(500).json({ ok: false, error: String(e && e.message || e), ...resultats });
  }
}
