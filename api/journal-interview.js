// =====================
// API VERCEL — INTERVIEW DE JODIE MOITOUT, DE BOUT EN BOUT (La Tribune de Républia)
// =====================
// Chantier "sécurisation journal_editions" (3 septembre 2026), RÉVISÉ le même jour après un
// audit dédié identité/falsification : la première version acceptait {personnage, interviewId,
// questions, reponses} en un seul appel final. Deux failles réelles corrigées ici :
//
//   1. IDENTITÉ / VOL D'INTERVIEW : interviews_jodie n'avait aucune RLS -- n'importe qui pouvait
//      lister TOUTES les interviews en cours via la clé anon (GET sans filtre) et voler la paire
//      (personnage, interviewId) d'un autre joueur pour publier UN ARTICLE EN SON NOM. Corrigé :
//      interviews_jodie passe en RLS verrouillée (zéro policy, comme renseignements_connus) --
//      voir migration_interviews_jodie.sql. Seul ce endpoint (service_role) y accède désormais.
//      Limite assumée, déjà documentée ailleurs dans ce projet (api/upload-org-avatar.js, api/
//      renseignements.js) : "personnage" reste une déclaration du client, aucune authentification
//      joueur réelle n'existe ici -- ce que ce lot garantit réellement, c'est qu'on ne peut plus
//      DÉCOUVRIR l'identifiant d'une interview appartenant à quelqu'un d'autre par une simple
//      lecture, ni publier un contenu qui ne correspond pas à un échange réellement témoin.
//
//   2. FALSIFICATION DU CONTENU : le client envoyait questions/reponses directement au moment de
//      la publication, sans lien avec un échange réellement suivi côté serveur -- un client
//      pouvait remplacer l'entretien entier par des Q/R inventées. Corrigé : le dialogue
//      lui-même passe désormais par ce endpoint (action 'question'), qui construit CHAQUE
//      question et enregistre CHAQUE réponse dans interviews_jodie.transcript (colonne jsonb,
//      jamais modifiable par le client). La publication (action 'publier') ne lit plus JAMAIS de
//      Q/R fournies par le client : uniquement le transcript accumulé par ce serveur lui-même.
//
// 4 actions (même doctrine de dispatch que api/renseignements.js) :
//   - 'cooldown' { personnage } -> { ok, joursRestants }
//   - 'lancer'   { personnage } -> { ok, interviewId } | { error:'cooldown', joursRestants }
//   - 'question' { personnage, interviewId, reponse? } -> { ok, termine, question|clotureTexte }
//   - 'publier'  { personnage, interviewId } -> { ok, statut:'publiee'|'en_attente', titre, texte }
//
// Ce que le client fournit désormais, au total : son nom déclaré, l'identifiant d'interview
// (jamais devinable depuis l'extérieur, RLS verrouillée), et le texte brut de CHACUNE de ses
// réponses au moment où elle est réellement donnée -- jamais un entretien entier reconstitué a
// posteriori. Ce qu'il ne fournit JAMAIS : le pays, le dossier public, les questions de Jodie,
// l'avatar, ni le texte final de l'article.

const ALLOWED_ORIGIN = 'https://res-publica.vercel.app';

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://jxpwoosmmhohoihxpbuc.supabase.co';
const SUPABASE_ANON = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw';
const SUPABASE_SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY || null;

const SB_HEADERS_ANON = {
  'Content-Type': 'application/json',
  'apikey': SUPABASE_ANON,
  'Authorization': `Bearer ${SUPABASE_ANON}`
};
const SB_HEADERS_SERVICE = {
  'Content-Type': 'application/json',
  'apikey': SUPABASE_SERVICE_ROLE,
  'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE}`
};

async function sbGet(table, filtre, headers) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${filtre}`, { headers });
  if (!res.ok) return [];
  return res.json();
}
async function sbInsert(table, data, headers) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
    method: 'POST',
    headers: { ...headers, 'Prefer': 'return=representation' },
    body: JSON.stringify(data)
  });
  if (!res.ok) return { ok: false, status: res.status, detail: await res.text().catch(() => '') };
  return { ok: true, rows: await res.json().catch(() => []) };
}
async function sbUpdate(table, filtre, data, headers) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${filtre}`, {
    method: 'PATCH',
    headers: { ...headers, 'Prefer': 'return=representation' },
    body: JSON.stringify(data)
  });
  if (!res.ok) return { ok: false, status: res.status, detail: await res.text().catch(() => '') };
  return { ok: true, rows: await res.json().catch(() => []) };
}

const MIN_QUESTIONS = 5;
const MAX_QUESTIONS = 6;
const FIN_MARQUEUR = '[FIN]';
const COOLDOWN_JOURS = 10;
const MAX_LONGUEUR_CHAMP = 1000;
const MAX_LONGUEUR_NOM = 100;

function calculerCooldownRestant(derniereInterview) {
  if (!derniereInterview || !derniereInterview.created_at) return 0;
  const requisMs = COOLDOWN_JOURS * 24 * 60 * 60 * 1000;
  const ecouleMs = Date.now() - new Date(derniereInterview.created_at).getTime();
  if (ecouleMs >= requisMs) return 0;
  return Math.ceil((requisMs - ecouleMs) / (24 * 60 * 60 * 1000));
}

function validerChamp(v, max) {
  return typeof v === 'string' && v.trim().length > 0 && v.length <= max;
}

// =====================
// DOSSIER PUBLIC DU PJ — mêmes tables/filtres que api/_journal-collecte.js, jamais transmis par
// le client (état civil, justice déjà tranchée, candidatures, organisations publiques,
// déclarations sur un forum public).
// =====================
async function construireDossierPublicPJ(nom) {
  const LIMITE = 5;
  const enc = encodeURIComponent(nom);
  const lignes = [];

  const [mariagesA, mariagesB, detentions, jugements, candidatures, orgas, topics] = await Promise.all([
    sbGet('mariages', `conjoint1=eq.${enc}&order=created_at.desc&limit=${LIMITE}`, SB_HEADERS_ANON).catch(() => []),
    sbGet('mariages', `conjoint2=eq.${enc}&order=created_at.desc&limit=${LIMITE}`, SB_HEADERS_ANON).catch(() => []),
    sbGet('detentions', `nom=eq.${enc}&order=created_at.desc&limit=${LIMITE}`, SB_HEADERS_ANON).catch(() => []),
    sbGet('jugements', `accuse=eq.${enc}&order=created_at.desc&limit=${LIMITE}`, SB_HEADERS_ANON).catch(() => []),
    sbGet('candidatures', `nom=eq.${enc}&order=created_at.desc&limit=${LIMITE}`, SB_HEADERS_ANON).catch(() => []),
    sbGet('organisations', 'select=*', SB_HEADERS_ANON).catch(() => []),
    sbGet('forum_topics', `author=eq.${enc}&order=created_at.desc&limit=${LIMITE}&select=forum_id,title`, SB_HEADERS_ANON).catch(() => [])
  ]);

  [...(mariagesA || []), ...(mariagesB || [])].forEach(r => {
    const autre = r.conjoint1 === nom ? r.conjoint2 : r.conjoint1;
    lignes.push(`Marié(e) à ${autre}.`);
  });
  (detentions || []).forEach(r => lignes.push(`A été placé(e) en détention (${r.raison}).`));
  (jugements || []).forEach(r => lignes.push(`A été condamné(e) pour ${r.motif} : ${r.peine}.`));
  (candidatures || []).forEach(r => lignes.push(`A déposé sa candidature au poste de ${r.poste_id}.`));
  (orgas || []).forEach(row => {
    let orga = row.data;
    if (typeof orga === 'string') { try { orga = JSON.parse(orga); } catch (e) { orga = null; } }
    if (orga && orga.visible && Array.isArray(orga.membres) && orga.membres.some(m => m.nom === nom)) {
      lignes.push(`Est membre de l'organisation publique « ${orga.nom} ».`);
    }
  });
  (topics || [])
    .filter(t => t.forum_id !== 'gouvernement' && t.forum_id !== 'presse' && String(t.forum_id || '').indexOf('org_') !== 0)
    .forEach(t => lignes.push(`A publié sur un forum public un sujet intitulé « ${t.title} ».`));

  return lignes.length > 0 ? lignes.join('\n') : "Aucune information publique notable n'est disponible sur cette personne pour l'instant.";
}

// =====================
// VOIX DE JODIE — duplication volontaire et minimale de PNJ_PERSONALITIES['Jodie Moitout'] et
// EMPIRE_STYLES (plateau-core.js, client uniquement, jamais chargeable dans une fonction
// serverless Node) -- même doctrine que NOMS_PAYS dans api/_journal-generation.js.
// =====================
const JODIE_TRAIT = "Journaliste micro-trottoir de L'Autruche Entravee. Tend son micro a n'importe qui, n'importe ou, n'importe quand. Les gens lui disent tout sans savoir pourquoi. Son sourire est une arme.";
const JODIE_STYLE = "enthousiasme journalistique communicatif, questions anodines aux reponses explosives, micro tendu en permanence";
const EMPIRE_TONES = {
  republic: 'bureaucratique français épuisé, cynique poli',
  narco: 'jovial menaçant, corruption assumée, espagnol de bazar',
  soviet: 'idéologique soviétique, formulaires sacrés, Camarade partout',
  khalija: 'protocole royal excessif, Loukoum Divin omniprésent, bénédictions imbriquées'
};

function construirePreambule(nom, pays, dossierTexte) {
  let p = "Tu es Jodie Moitout, journaliste micro-trottoir pour le journal L'Autruche Entravee (groupe La Tribune de Republia), dans le jeu Res Publica. Le pays s'appelle Republia, avec un accent aigu sur le e (jamais \"Republia\" sans accent). ";
  p += "Ta personnalite : " + JODIE_TRAIT + " Ton style : " + JODIE_STYLE + ". ";
  if (EMPIRE_TONES[pays]) p += "Ambiance generale du pays : " + EMPIRE_TONES[pays] + ". ";
  p += "C'est TOI qui as sollicite " + nom + " pour cette interview (jamais l'inverse). ";
  p += "Voici ce que tu sais PUBLIQUEMENT sur cette personne -- n'utilise QUE ces informations, n'invente jamais un fait supplementaire qui n'y figure pas :\n" + dossierTexte + "\n\n";
  return p;
}

function construirePromptQuestion(nom, pays, dossierTexte, transcript, dejaPosees) {
  let p = construirePreambule(nom, pays, dossierTexte);
  if (dejaPosees === 0) {
    p += "C'est le tout début de l'entretien. Pose une première question d'accroche, pertinente et personnalisée à partir du dossier ci-dessus. Réponds UNIQUEMENT avec le texte de cette question, sans numéro, sans guillemets, sans commentaire.";
  } else {
    p += "Voici l'entretien mené jusqu'ici :\n";
    transcript.forEach((t, i) => {
      p += (i + 1) + ". Toi : " + t.question + "\n   Réponse : \"" + String(t.reponse).replace(/"/g, "'") + "\"\n";
    });
    if (dejaPosees < MIN_QUESTIONS) {
      p += "\nPose la question suivante (question " + (dejaPosees + 1) + " sur 5 à 6), en tenant compte intelligemment des réponses déjà données pour rebondir -- jamais une question générique interchangeable. Réponds UNIQUEMENT avec le texte de cette question, sans numéro, sans guillemets, sans commentaire.";
    } else {
      p += "\nTu as déjà posé " + dejaPosees + " questions. Décide maintenant : soit tu conclus naturellement l'entretien (une courte phrase de remerciement/clôture, rien d'autre), soit tu poses UNE dernière question (la 6e) si le contenu le justifie vraiment. Si tu CONCLUS, termine ta réponse par une ligne contenant EXACTEMENT " + FIN_MARQUEUR + " et rien d'autre sur cette ligne. Si tu poses une 6e question, ne mets JAMAIS " + FIN_MARQUEUR + ".";
    }
  }
  p += "\n\nTexte brut uniquement, sans mise en forme Markdown (pas d'astérisque, pas de dièse, pas de liste à puces).";
  return p;
}

function construirePromptArticle(nom, pays, dossierTexte, questions, reponses) {
  let p = construirePreambule(nom, pays, dossierTexte);
  p += "Voici l'intégralité de l'entretien que tu viens de mener :\n";
  questions.forEach((q, i) => {
    p += (i + 1) + ". Toi : " + q + "\n   Réponse : \"" + String(reponses[i]).replace(/"/g, "'") + "\"\n";
  });
  p += "\nRédige maintenant un ARTICLE JOURNALISTIQUE complet pour La Tribune de Républia à partir de cet entretien -- JAMAIS un simple enchaînement Question/Réponse. Tu peux synthétiser, reformuler, contextualiser et structurer, mais tu ne dois JAMAIS inventer une déclaration ou une citation qui ne correspond pas fidèlement à ce que " + nom + " a réellement répondu ci-dessus. " +
    "Format de réponse EXACT : la toute première ligne est le TITRE de l'article (court, accrocheur, sans guillemets), puis une ligne vide, puis le corps de l'article (200 à 350 mots, ton journalistique, troisième personne). Rien d'autre : pas d'introduction, pas de commentaire, texte brut sans markdown.";
  return p;
}

function nettoyerMarkdown(texte) {
  if (!texte) return texte;
  return texte
    .replace(/\*\*(.+?)\*\*/g, '$1')
    .replace(/\*(.+?)\*/g, '$1')
    .replace(/^#{1,6}\s+/gm, '')
    .replace(/^[-*+]\s+/gm, '')
    .replace(/[*#]/g, '')
    .trim();
}

async function appelAnthropic(prompt, maxTokens, timeoutMs) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': process.env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: maxTokens,
        messages: [{ role: 'user', content: prompt }]
      }),
      signal: controller.signal
    });
    if (!res.ok) return { ok: false, erreur: `Anthropic HTTP ${res.status}` };
    const data = await res.json();
    const texte = data.content && data.content[0] && data.content[0].text;
    if (!texte) return { ok: false, erreur: 'Réponse Anthropic sans contenu texte' };
    return { ok: true, texte };
  } catch (e) {
    if (e.name === 'AbortError') return { ok: false, erreur: 'Timeout Anthropic dépassé' };
    return { ok: false, erreur: 'Erreur réseau Anthropic : ' + e.message };
  } finally {
    clearTimeout(timer);
  }
}

function extraireTitreCorps(texteBrut, nom) {
  const nettoye = nettoyerMarkdown(texteBrut).trim();
  const premiereVide = nettoye.indexOf('\n\n');
  let titre, corps;
  if (premiereVide > -1) {
    titre = nettoye.slice(0, premiereVide).trim();
    corps = nettoye.slice(premiereVide + 2).trim();
  } else {
    const parties = nettoye.split('\n');
    titre = (parties[0] || '').trim();
    corps = parties.slice(1).join(' ').trim();
  }
  if (!titre) titre = 'Rencontre avec ' + nom;
  if (!corps) corps = nettoye;
  return { titre, corps };
}

async function tenterPublicationImmediate(pays, article, tentatives) {
  for (let i = 0; i < (tentatives || 3); i++) {
    const editions = await sbGet('journal_editions', `country=eq.${encodeURIComponent(pays)}&statut=eq.publiee&order=date_edition.desc&limit=1`, SB_HEADERS_SERVICE);
    const edition = editions && editions[0];
    if (!edition) return { ok: false, raison: 'aucune_edition' };

    const dpcActuelle = edition.double_page_centrale || { articles: [] };
    const articlesActuels = Array.isArray(dpcActuelle.articles) ? dpcActuelle.articles : [];
    const nouvelleDpc = { articles: [...articlesActuels, article] };
    const filtreCAS = `id=eq.${encodeURIComponent(edition.id)}&double_page_centrale=eq.${encodeURIComponent(JSON.stringify(dpcActuelle))}`;
    const res = await sbUpdate('journal_editions', filtreCAS, { double_page_centrale: nouvelleDpc }, SB_HEADERS_SERVICE);
    if (res.ok && res.rows && res.rows.length > 0) return { ok: true };
  }
  return { ok: false, raison: 'conflit_persistant' };
}

async function mettreEnAttente(pays, article) {
  const id = 'article_attente_' + Date.now() + '_' + Math.floor(Math.random() * 1000000);
  const data = { id, country: pays, rubrique: article.rubrique, titre: article.titre, texte: article.texte };
  if (article.ville) data.ville = article.ville;
  if (article.image && article.image.url) data.image_url = article.image.url;
  return sbInsert('journal_articles_en_attente', data, SB_HEADERS_SERVICE);
}

// =====================
// ACTIONS
// =====================
async function handleCooldown(body) {
  const clesAutorisees = ['action', 'personnage'];
  if (Object.keys(body).some(k => !clesAutorisees.includes(k))) return { status: 400, json: { error: 'Champ non autorisé.' } };
  if (!validerChamp(body.personnage, MAX_LONGUEUR_NOM)) return { status: 400, json: { error: 'Personnage invalide.' } };

  const rows = await sbGet('interviews_jodie', `personnage=eq.${encodeURIComponent(body.personnage)}&order=created_at.desc&limit=1`, SB_HEADERS_SERVICE);
  const joursRestants = calculerCooldownRestant(rows && rows[0]);
  return { status: 200, json: { ok: true, joursRestants } };
}

async function handleLancer(body) {
  const clesAutorisees = ['action', 'personnage'];
  if (Object.keys(body).some(k => !clesAutorisees.includes(k))) return { status: 400, json: { error: 'Champ non autorisé.' } };
  if (!validerChamp(body.personnage, MAX_LONGUEUR_NOM)) return { status: 400, json: { error: 'Personnage invalide.' } };
  const personnage = body.personnage;

  // Défense en profondeur : la vérification "officielle" a lieu via l'action 'cooldown' juste
  // avant côté client (aucun PA consommé si elle bloque) -- ceci empêche seulement qu'un appel
  // direct à 'lancer' sans passer par là ne contourne la règle.
  const rows = await sbGet('interviews_jodie', `personnage=eq.${encodeURIComponent(personnage)}&order=created_at.desc&limit=1`, SB_HEADERS_SERVICE);
  const joursRestants = calculerCooldownRestant(rows && rows[0]);
  if (joursRestants > 0) return { status: 409, json: { error: 'cooldown', joursRestants } };

  const persos = await sbGet('personnages', `name=eq.${encodeURIComponent(personnage)}&select=country`, SB_HEADERS_ANON);
  const perso = persos && persos[0];
  if (!perso || !perso.country) return { status: 404, json: { error: 'Personnage introuvable.' } };

  const id = 'interview_jodie_' + Date.now() + '_' + Math.floor(Math.random() * 1000000);
  const insertRes = await sbInsert('interviews_jodie', { id, personnage, country: perso.country, transcript: [] }, SB_HEADERS_SERVICE);
  if (!insertRes.ok) return { status: 502, json: { error: "Impossible de démarrer l'interview." } };
  return { status: 200, json: { ok: true, interviewId: id } };
}

async function handleQuestion(body) {
  const clesAutorisees = ['action', 'personnage', 'interviewId', 'reponse'];
  if (Object.keys(body).some(k => !clesAutorisees.includes(k))) return { status: 400, json: { error: 'Champ non autorisé.' } };
  if (!validerChamp(body.personnage, MAX_LONGUEUR_NOM)) return { status: 400, json: { error: 'Personnage invalide.' } };
  if (!validerChamp(body.interviewId, 200)) return { status: 400, json: { error: "Identifiant d'interview invalide." } };
  const { personnage, interviewId, reponse } = body;
  if (reponse !== undefined && reponse !== null && !validerChamp(reponse, MAX_LONGUEUR_CHAMP)) {
    return { status: 400, json: { error: 'Réponse invalide.' } };
  }

  const rows = await sbGet('interviews_jodie', `id=eq.${encodeURIComponent(interviewId)}&personnage=eq.${encodeURIComponent(personnage)}&publie=eq.false`, SB_HEADERS_SERVICE);
  const row = rows && rows[0];
  if (!row) return { status: 404, json: { error: 'Interview introuvable ou déjà terminée.' } };

  let transcript = Array.isArray(row.transcript) ? row.transcript.slice() : [];

  if (reponse !== undefined && reponse !== null) {
    if (transcript.length === 0 || transcript[transcript.length - 1].reponse !== null) {
      return { status: 409, json: { error: 'Aucune question en attente de réponse pour cette interview.' } };
    }
    transcript[transcript.length - 1] = { question: transcript[transcript.length - 1].question, reponse: String(reponse).trim() };
  } else if (transcript.length > 0 && transcript[transcript.length - 1].reponse === null) {
    return { status: 409, json: { error: 'Une question est déjà en attente de réponse pour cette interview.' } };
  }

  const dejaPosees = transcript.length;

  if (dejaPosees >= MAX_QUESTIONS) {
    await sbUpdate('interviews_jodie', `id=eq.${encodeURIComponent(interviewId)}`, { transcript }, SB_HEADERS_SERVICE);
    return { status: 200, json: { ok: true, termine: true, clotureTexte: "Merci beaucoup, j'ai largement de quoi faire un bel article." } };
  }

  const dossierTexte = await construireDossierPublicPJ(personnage).catch(() => "Aucune information publique notable n'est disponible sur cette personne pour l'instant.");
  const prompt = construirePromptQuestion(personnage, row.country, dossierTexte, transcript, dejaPosees);

  const appel = await appelAnthropic(prompt, 300, 20000);
  if (!appel.ok) return { status: 502, json: { error: appel.erreur } };

  const nettoye = nettoyerMarkdown(appel.texte).trim();

  if (dejaPosees >= MIN_QUESTIONS && nettoye.indexOf(FIN_MARQUEUR) !== -1) {
    const clotureTexte = nettoye.split(FIN_MARQUEUR)[0].trim() || "Merci beaucoup, c'est tout ce dont j'avais besoin.";
    await sbUpdate('interviews_jodie', `id=eq.${encodeURIComponent(interviewId)}`, { transcript }, SB_HEADERS_SERVICE);
    return { status: 200, json: { ok: true, termine: true, clotureTexte } };
  }

  transcript.push({ question: nettoye, reponse: null });
  await sbUpdate('interviews_jodie', `id=eq.${encodeURIComponent(interviewId)}`, { transcript }, SB_HEADERS_SERVICE);
  return { status: 200, json: { ok: true, termine: false, question: nettoye } };
}

async function handlePublier(body) {
  const clesAutorisees = ['action', 'personnage', 'interviewId'];
  if (Object.keys(body).some(k => !clesAutorisees.includes(k))) return { status: 400, json: { error: 'Champ non autorisé.' } };
  if (!validerChamp(body.personnage, MAX_LONGUEUR_NOM)) return { status: 400, json: { error: 'Personnage invalide.' } };
  if (!validerChamp(body.interviewId, 200)) return { status: 400, json: { error: "Identifiant d'interview invalide." } };
  const { personnage, interviewId } = body;

  // Réclamation exclusive -- SEULE protection anti-duplication (retry/double clic/requêtes
  // concurrentes pour la même interview). Le PATCH renvoie la ligne à jour, transcript inclus.
  const reclamation = await sbUpdate(
    'interviews_jodie',
    `id=eq.${encodeURIComponent(interviewId)}&personnage=eq.${encodeURIComponent(personnage)}&publie=eq.false`,
    { publie: true },
    SB_HEADERS_SERVICE
  );
  if (!reclamation.ok || !reclamation.rows || reclamation.rows.length === 0) {
    return { status: 409, json: { error: 'Cette interview a déjà été publiée ou est en cours de publication.' } };
  }
  const row = reclamation.rows[0];

  const relacherEtEchouer = async (status, message) => {
    await sbUpdate('interviews_jodie', `id=eq.${encodeURIComponent(interviewId)}`, { publie: false }, SB_HEADERS_SERVICE).catch(() => {});
    return { status, json: { error: message } };
  };

  // Le transcript est la SEULE source du contenu publié -- jamais une donnée fournie par le
  // client dans ce même appel (voir en-tête de fichier).
  const transcript = Array.isArray(row.transcript) ? row.transcript : [];
  const complet = transcript.filter(t => t && typeof t.question === 'string' && typeof t.reponse === 'string' && t.reponse.length > 0);
  if (complet.length < MIN_QUESTIONS || complet.length !== transcript.length) {
    return relacherEtEchouer(409, "L'entretien n'est pas complet.");
  }

  const persos = await sbGet('personnages', `name=eq.${encodeURIComponent(personnage)}&select=country,current_city,photo_url`, SB_HEADERS_ANON);
  const perso = persos && persos[0];
  if (!perso || !perso.country) return relacherEtEchouer(404, 'Personnage introuvable.');
  const pays = perso.country;

  const dossierTexte = await construireDossierPublicPJ(personnage).catch(() => "Aucune information publique notable n'est disponible sur cette personne pour l'instant.");
  const questions = complet.map(t => t.question);
  const reponses = complet.map(t => t.reponse);
  const prompt = construirePromptArticle(personnage, pays, dossierTexte, questions, reponses);

  const appel = await appelAnthropic(prompt, 700, 30000);
  if (!appel.ok) return relacherEtEchouer(502, appel.erreur);

  const { titre, corps } = extraireTitreCorps(appel.texte, personnage);
  const article = { rubrique: 'Portraits', titre, texte: corps };
  if (perso.current_city) article.ville = perso.current_city;
  if (perso.photo_url) article.image = { type: 'url', url: perso.photo_url };

  const publication = await tenterPublicationImmediate(pays, article, 3);
  if (publication.ok) return { status: 200, json: { ok: true, statut: 'publiee', titre, texte: corps } };

  const attente = await mettreEnAttente(pays, article);
  if (!attente.ok) return relacherEtEchouer(502, "L'article n'a pas pu être publié ni mis en attente.");

  return { status: 200, json: { ok: true, statut: 'en_attente', titre, texte: corps } };
}

export default async function handler(req, res) {
  const origin = req.headers.origin;
  if (origin === ALLOWED_ORIGIN) res.setHeader('Access-Control-Allow-Origin', ALLOWED_ORIGIN);
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  if (!SUPABASE_SERVICE_ROLE) {
    return res.status(503).json({ error: 'Service temporairement indisponible.' });
  }

  const body = req.body;
  if (!body || typeof body !== 'object' || Array.isArray(body)) return res.status(400).json({ error: 'Corps de requête invalide.' });

  let resultat;
  try {
    if (body.action === 'cooldown') resultat = await handleCooldown(body);
    else if (body.action === 'lancer') resultat = await handleLancer(body);
    else if (body.action === 'question') resultat = await handleQuestion(body);
    else if (body.action === 'publier') resultat = await handlePublier(body);
    else return res.status(400).json({ error: 'Action inconnue.' });
  } catch (e) {
    return res.status(500).json({ error: 'Erreur inattendue.' });
  }

  return res.status(resultat.status).json(resultat.json);
}
