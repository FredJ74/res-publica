// =====================
// JOURNAL DU JOUR — LOT B : GÉNÉRATION IA + VALIDATION DÉTERMINISTE + PUBLICATION
// =====================
// Module serveur interne, PAS un endpoint Vercel (préfixe "_", même convention que
// _journal-collecte.js, Lot A). Orchestré depuis api/cron-minuit.js, en toute dernière étape,
// dans son propre try/catch — jamais appelé par le navigateur du joueur.
//
// Consomme _journal-collecte.js (Lot A) tel quel, SANS AUCUNE MODIFICATION de ce fichier.
//
// Doctrine éditoriale absolue : « Le journal peut interpréter les faits à sa façon. Il ne peut
// pas inventer les faits. » Toute violation détectable déterministiquement (voir validerEdition)
// invalide l'édition ENTIÈRE — jamais de publication partielle, jamais de suppression silencieuse
// du seul bloc fautif (décision explicitement validée).

import {
  determinerPaysEligibles,
  calculerPeriode,
  construirePaquetFactuel
} from './_journal-collecte.js';

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://jxpwoosmmhohoihxpbuc.supabase.co';
const SUPABASE_ANON = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw';
const SB_HEADERS = {
  'Content-Type': 'application/json',
  'apikey': SUPABASE_ANON,
  'Authorization': `Bearer ${SUPABASE_ANON}`
};

async function sbInsert(table, data) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
    method: 'POST',
    headers: { ...SB_HEADERS, 'Prefer': 'return=representation' },
    body: JSON.stringify(data)
  });
  if (!res.ok) {
    const detail = await res.text().catch(() => '');
    return { ok: false, status: res.status, detail };
  }
  return { ok: true };
}

async function sbUpdate(table, filtre, data) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${filtre}`, {
    method: 'PATCH',
    headers: { ...SB_HEADERS, 'Prefer': 'return=representation' },
    body: JSON.stringify(data)
  });
  if (!res.ok) {
    const detail = await res.text().catch(() => '');
    return { ok: false, status: res.status, detail };
  }
  return { ok: true };
}

const PROMPT_VERSION = 'v1';

// Fuseau éditorial par pays (nom IANA explicite, jamais un décalage fixe — l'heure d'été/hiver
// est gérée nativement par Intl). Les 4 pays pointent aujourd'hui vers la même valeur ; cette
// table (plutôt qu'une constante unique) laisse la porte ouverte à une convention distincte par
// pays plus tard, sans réécrire le mécanisme.
const TIMEZONE_PAR_PAYS = {
  republic: 'Europe/Paris',
  narco: 'Europe/Paris',
  soviet: 'Europe/Paris',
  khalija: 'Europe/Paris'
};

// Budget interne par appel Anthropic (indépendant du maxDuration global du cron, 120s) : assez
// large pour une génération normale de 4 pages, assez borné pour qu'un pays lent ne puisse
// jamais, même avec les 4 pays en parallèle (Promise.allSettled), épuiser le budget des tâches
// déjà exécutées avant le Journal dans le cron. Point de départ 60s (18 août 2026) après mesure
// réelle : le paquet non compacté de Républia (85 indicateurs prix/stock) dépassait déjà 30s
// sans même parler de sortie complète — voir construireAiInput ci-dessous pour la compaction
// qui vise justement à ne pas avoir besoin d'aller plus loin que cette valeur.
const ANTHROPIC_TIMEOUT_MS = 60000;
const ANTHROPIC_MODEL = 'claude-sonnet-4-5'; // cohérent avec tous les appels IA déjà existants du projet (api/chat.js et ses appelants)

function dateEditionPourPays(pays, momentDate) {
  const tz = TIMEZONE_PAR_PAYS[pays] || 'Europe/Paris';
  const fmt = new Intl.DateTimeFormat('en-CA', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit' });
  return fmt.format(momentDate); // locale 'en-CA' -> format YYYY-MM-DD directement
}

// =====================
// COMPACTION DU PAQUET ENVOYÉ À L'IA — 100% déterministe, aucune perte d'information.
// =====================
// Le paquet complet du Lot A (_journal-collecte.js, INCHANGÉ) reste la source d'archive/
// historique/comparaisons — voir genererEditionPays plus bas, faits_sources conserve toujours
// le paquet Lot A intact à sa racine. AI_INPUT est un DEUXIÈME niveau, dérivé du premier par
// pure restructuration de FORME (regroupement par ville/bâtiment, suppression de clés
// redondantes), jamais un résumé interprétatif : chaque prix, chaque stock, chaque identifiant
// source reste présent, seulement organisé différemment. Motif mesuré en production (18 août
// 2026) : le paquet plat de Républia (85 indicateurs prix/stock, un objet verbeux par valeur)
// dépassait 30s de traitement côté Anthropic avant même de générer la moindre sortie.
function construireAiInput(paquet) {
  const nonEco = [];
  const ecoParVille = {};

  (paquet.INDICATORS || []).forEach(ind => {
    const cle = ind.cle || '';
    const estPrix = cle.indexOf('prix_') === 0 && ind.disponible === true && ind.ville;
    const estStock = cle.indexOf('stock_') === 0 && ind.disponible === true && ind.ville;
    if (!estPrix && !estStock) { nonEco.push(ind); return; }
    const ville = ind.ville;
    const ressource = cle.replace(/^prix_|^stock_/, '');
    ecoParVille[ville] = ecoParVille[ville] || {};
    ecoParVille[ville][ressource] = ecoParVille[ville][ressource] || { ressource };
    if (estPrix) {
      ecoParVille[ville][ressource].prix = ind.valeur;
      ecoParVille[ville][ressource].prix_id = ind.id;
      if (ind.prix_manuel === true) ecoParVille[ville][ressource].prix_manuel = true;
    } else {
      ecoParVille[ville][ressource].stock = ind.valeur;
      ecoParVille[ville][ressource].stock_id = ind.id;
    }
  });

  const INDICATORS_ECO_PAR_VILLE = Object.keys(ecoParVille).map(ville => ({
    ville,
    ressources: Object.values(ecoParVille[ville])
  }));

  return {
    periode: paquet.periode,
    FACTS: paquet.FACTS,
    PUBLIC_STATEMENTS: paquet.PUBLIC_STATEMENTS,
    INDICATORS: nonEco,
    INDICATORS_ECO_PAR_VILLE,
    COMPARISONS: paquet.COMPARISONS,
    EDUCATIONAL_REFERENCE: paquet.EDUCATIONAL_REFERENCE
  };
}

// Index id -> {disponible, valeur, extrait, ...} construit à partir de EXACTEMENT ce qui a été
// envoyé à l'IA (aiInput) — jamais à partir du paquet complet Lot A. C'est la garantie demandée :
// un source_id n'est validé que s'il était réellement accessible dans ce que l'IA a reçu.
function indexerAiInput(aiInput) {
  const index = {};
  (aiInput.FACTS || []).forEach(f => { index[f.id] = f; });
  (aiInput.PUBLIC_STATEMENTS || []).forEach(s => { index[s.id] = s; });
  (aiInput.INDICATORS || []).forEach(i => { index[i.id] = i; });
  (aiInput.COMPARISONS || []).forEach(c => { index[c.id] = c; });
  (aiInput.INDICATORS_ECO_PAR_VILLE || []).forEach(bloc => {
    (bloc.ressources || []).forEach(r => {
      if (r.prix_id) index[r.prix_id] = { id: r.prix_id, disponible: true, valeur: r.prix, ville: bloc.ville };
      if (r.stock_id) index[r.stock_id] = { id: r.stock_id, disponible: true, valeur: r.stock, ville: bloc.ville };
    });
  });
  return index;
}

// =====================
// SCHÉMA + PROMPT SYSTÈME
// =====================
const SCHEMA_JSON_TEXTE = `{
  "une": {
    "titre_principal": "string",
    "chapeau": "string",
    "accroches": [ { "texte": "string", "article_ref": "string (id d'un article existant)" } ],
    "image": { "type": "personnage|lieu|generique|fallback", "ref_id": "string|null" }
  },
  "double_page_centrale": {
    "villes": [ article ],
    "nationale": [ article ],
    "internationale": [ article ]
  },
  "page_economie_societe": {
    "statistiques": [ article ],
    "absences_notables": [ article ],
    "rubrique_pedagogique": { "fiche_id": "string|null", "titre": "string|null", "texte": "string|null" }
  }
}
// article = { "id": "string", "type": "actualite|declaration|statistique|absence_remarquable",
//   "titre": "string", "texte": "string", "ville": "string|null", "pays_source": "string|null",
//   "source_ids": ["string", ...] }`;

function construirePromptSysteme() {
  return `Tu es la rédaction du "Journal du jour", un quotidien national fictif du jeu Res Publica.

RÈGLE ABSOLUE, NON NÉGOCIABLE : « Tu peux interpréter les faits à ta façon. Tu ne peux JAMAIS inventer les faits. »

Tu reçois un paquet de données structurées (FACTS, PUBLIC_STATEMENTS, INDICATORS, COMPARISONS, EDUCATIONAL_REFERENCE). C'est la SEULE réalité que tu connais. N'utilise jamais une connaissance générale du monde réel, ni des mécaniques de jeu, au-delà de ce paquet.

TU PEUX : hiérarchiser l'information, choisir un angle, commenter, ironiser, adopter un ton partisan ou de mauvaise foi, dramatiser prudemment (jamais présenter une causalité comme certaine si elle n'est pas prouvée par les données), rapprocher plusieurs faits réellement présents dans le paquet.

TU NE PEUX JAMAIS : inventer un événement, une personne, une déclaration, une citation, un chiffre, une transaction, une causalité certaine non démontrée, une comparaison/série historique non fournie, ou une règle de fonctionnement du jeu. Si les données sont pauvres, écris PLUS COURT — ne remplis jamais artificiellement une rubrique. Une rubrique peut légitimement être courte ou signaler qu'il ne s'est rien passé.

FAITS vs DÉCLARATIONS : FACTS est établi par le système lui-même. PUBLIC_STATEMENTS prouve seulement que son auteur a publiquement écrit quelque chose — JAMAIS que c'est vrai. Tout contenu tiré de PUBLIC_STATEMENTS doit être attribué explicitement à son auteur avec un verbe déclaratif ("X affirme...", "X accuse...", "X annonce..."), jamais présenté comme un fait acquis.

CITATIONS : n'utilise JAMAIS de guillemets (« » ou " ") sauf pour reproduire une sous-chaîne du champ "extrait" d'un PUBLIC_STATEMENT que tu cites en source, CARACTÈRE POUR CARACTÈRE — même casse (y compris la toute première lettre de la citation), mêmes accents, même ponctuation, sans aucun ajout ni suppression, et SANS JAMAIS corriger une faute d'orthographe, de frappe ou d'accent présente dans l'original, même si tu es certain qu'il s'agit d'une coquille. Une citation entre guillemets n'est jamais "améliorée" : soit elle est recopiée à l'identique, caractère pour caractère, soit ce n'est pas une citation. Si tu veux reformuler, résumer, adapter la casse pour l'intégrer dans ta phrase, ou corriger une coquille apparente : fais-le SANS guillemets, en paraphrase attribuée ("X affirme que...", sans guillemets).

CHIFFRES : dans un bloc de type "statistique", le chiffre écrit doit être la valeur EXACTE de l'unique indicateur cité, recopiée telle quelle dans le texte. N'utilise JAMAIS un indicateur dont "disponible" vaut false comme s'il te donnait une valeur connue — "indisponible" ne signifie jamais "zéro" ou "aucun".

ABSENCES ET COMPARAISONS : tu ne peux écrire "aucun/aucune...", "pour la Xème fois consécutive", "en hausse/baisse par rapport à..." QUE si une entrée COMPARISONS te le fournit déjà calculée — tu ne calcules jamais toi-même une série ou une tendance historique. Un bloc "absence_remarquable" doit citer exactement une comparaison.

RUBRIQUE PÉDAGOGIQUE : ne produis du contenu dans "rubrique_pedagogique" QUE si EDUCATIONAL_REFERENCE.fiche_id n'est pas null — vulgarise alors "contenu_valide" dans ton ton éditorial, sans ajouter la moindre information technique de ton cru. Si EDUCATIONAL_REFERENCE.fiche_id est null, "rubrique_pedagogique" doit être exactement {"fiche_id":null,"titre":null,"texte":null}.

IMAGE DE UNE : choisis "type":"personnage" ou "lieu" UNIQUEMENT si "ref_id" correspond à une entité réellement nommée dans une source que tu cites en Une. Le type "organisation" est actuellement INTERDIT (aucune source fiable n'existe). Sinon utilise "generique" ou "fallback", avec "ref_id":null.

TRAÇABILITÉ OBLIGATOIRE : chaque article (type "actualite", "declaration", "statistique" ou "absence_remarquable") doit avoir "source_ids" non vide, contenant UNIQUEMENT des identifiants qui existent réellement dans le paquet fourni — jamais un identifiant inventé, jamais un identifiant approximatif. Un bloc "statistique" cite exactement un identifiant "indicateur:...". Un bloc "absence_remarquable" cite exactement un identifiant "comparaison:...".

TRAÇABILITÉ COMPLÈTE, PAS SEULEMENT PARTIELLE : "source_ids" doit contenir l'identifiant de CHAQUE fait, déclaration, indicateur ou comparaison que tu utilises RÉELLEMENT dans le texte de l'article — pas seulement celui qui a inspiré le titre. Si un article mentionne plusieurs faits (par exemple une déclaration ET un chiffre économique, ou plusieurs événements), TOUS leurs identifiants doivent apparaître dans "source_ids". N'utilise jamais, même dans une phrase secondaire ou une remarque en passant, un fait ou un chiffre du paquet sans citer son identifiant correspondant.

INDICATEURS ÉCONOMIQUES REGROUPÉS : les prix et stocks de matières premières te sont fournis dans "INDICATORS_ECO_PAR_VILLE" (un bloc par ville, une entrée par ressource avec son prix actuel et son stock actuel) plutôt qu'en longue liste plate — c'est la même donnée, seulement regroupée. Chaque valeur y porte son propre identifiant ("prix_id"/"stock_id", même format "indicateur:...") : cite-le exactement comme n'importe quel autre identifiant "indicateur:..." dans "source_ids".

FORMAT DE SORTIE STRICT — réponds UNIQUEMENT avec un objet JSON valide respectant EXACTEMENT ce schéma, sans aucun texte avant/après, sans balises markdown, sans commentaire :
${SCHEMA_JSON_TEXTE}

Toute violation de ces règles rendra l'édition entière rejetée et non publiée. Une édition honnête et courte vaut toujours mieux qu'une édition inventée ou remplie artificiellement.`;
}

// =====================
// APPEL ANTHROPIC — direct, jamais via api/chat.js (ce proxy existe pour le navigateur, pas
// pour un appel serveur-à-serveur). Clé jamais loggée, jamais stockée dans journal_editions.
// Préremplissage de la réponse par "{" (technique standard Anthropic) pour maximiser la fiabilité
// du JSON, avec repli défensif (retrait d'éventuelles balises markdown) avant parsing.
// =====================
async function appelAnthropic(systemPrompt, paquetFactuel, timeoutMs) {
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
        model: ANTHROPIC_MODEL,
        max_tokens: 4000,
        system: systemPrompt,
        messages: [
          { role: 'user', content: JSON.stringify(paquetFactuel) },
          { role: 'assistant', content: '{' }
        ]
      }),
      signal: controller.signal
    });
    if (!res.ok) {
      const detail = await res.text().catch(() => '');
      return { ok: false, erreur: `Anthropic HTTP ${res.status} : ${detail.slice(0, 300)}` };
    }
    const data = await res.json();
    const texte = data.content && data.content[0] && data.content[0].text;
    if (!texte) return { ok: false, erreur: 'Réponse Anthropic sans contenu texte' };
    let brut = ('{' + texte).trim();
    // Repli defensif si l'IA a malgre tout entoure sa reponse de balises markdown.
    brut = brut.replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/i, '');
    return { ok: true, texte: brut };
  } catch (e) {
    if (e.name === 'AbortError') return { ok: false, erreur: `Timeout Anthropic dépassé (${timeoutMs}ms)` };
    return { ok: false, erreur: 'Erreur réseau Anthropic : ' + e.message };
  } finally {
    clearTimeout(timer);
  }
}

// =====================
// VALIDATION DÉTERMINISTE — voir doctrine en tête de fichier. Toute violation -> rejet total.
// =====================
const TYPES_ARTICLE_VALIDES = ['actualite', 'declaration', 'statistique', 'absence_remarquable'];
const TYPES_IMAGE_VALIDES = ['personnage', 'lieu', 'generique', 'fallback'];

function extraireCitations(texte) {
  const citations = [];
  const reFr = /«([^»]+)»/g;
  const reDroit = /"([^"]+)"/g;
  let m;
  while ((m = reFr.exec(texte))) citations.push(m[1].trim());
  while ((m = reDroit.exec(texte))) citations.push(m[1].trim());
  return citations;
}

function validerArticle(art, index, erreurs, contexte, idsVus) {
  if (!art || typeof art !== 'object') { erreurs.push(`${contexte} : article invalide (non objet)`); return; }
  if (typeof art.id !== 'string' || !art.id) { erreurs.push(`${contexte} : id manquant`); return; }
  if (idsVus.has(art.id)) erreurs.push(`id d'article dupliqué : "${art.id}"`);
  idsVus.add(art.id);
  if (!TYPES_ARTICLE_VALIDES.includes(art.type)) { erreurs.push(`${contexte} (${art.id}) : type invalide "${art.type}"`); return; }
  if (typeof art.titre !== 'string' || !art.titre) { erreurs.push(`${contexte} (${art.id}) : titre manquant`); return; }
  if (typeof art.texte !== 'string' || !art.texte) { erreurs.push(`${contexte} (${art.id}) : texte manquant`); return; }
  if (!Array.isArray(art.source_ids) || art.source_ids.length === 0) { erreurs.push(`${contexte} (${art.id}) : source_ids vide ou absent`); return; }

  const sourcesResolues = [];
  for (const sid of art.source_ids) {
    if (typeof sid !== 'string') { erreurs.push(`${contexte} (${art.id}) : source_id non-chaîne`); return; }
    const source = index[sid];
    if (!source) { erreurs.push(`${contexte} (${art.id}) : source_id inconnu ou absent de AI_INPUT "${sid}"`); return; }
    sourcesResolues.push({ id: sid, source });
  }

  if (art.type === 'statistique') {
    const indicateurs = art.source_ids.filter(id => id.indexOf('indicateur:') === 0);
    if (indicateurs.length === 0) { erreurs.push(`${contexte} (${art.id}) : "statistique" doit citer au moins un indicateur (trouvé 0)`); return; }
    indicateurs.forEach(sid => {
      const indic = sourcesResolues.find(s => s.id === sid).source;
      if (indic.disponible !== true) { erreurs.push(`${contexte} (${art.id}) : indicateur cité non disponible (${sid}, disponible=${indic.disponible})`); return; }
      if (indic.valeur != null && typeof indic.valeur !== 'object') {
        const valeurStr = String(indic.valeur);
        if (art.texte.indexOf(valeurStr) === -1) erreurs.push(`${contexte} (${art.id}) : la valeur de l'indicateur ${sid} (${valeurStr}) n'apparaît pas telle quelle dans le texte`);
      }
    });
  }

  if (art.type === 'absence_remarquable') {
    const comparaisons = art.source_ids.filter(id => id.indexOf('comparaison:') === 0);
    if (comparaisons.length !== 1) erreurs.push(`${contexte} (${art.id}) : "absence_remarquable" doit citer exactement une comparaison (trouvé ${comparaisons.length})`);
  }

  // Interdiction transversale : un indicateur indisponible ne peut jamais fonder un contenu,
  // quel que soit le type de bloc qui le cite.
  sourcesResolues.forEach(({ id, source }) => {
    if (id.indexOf('indicateur:') === 0 && source.disponible === false) {
      erreurs.push(`${contexte} (${art.id}) : cite un indicateur indisponible (${id}) comme s'il était connu`);
    }
  });

  // Citations : verifiees UNIQUEMENT contre les extraits des PUBLIC_STATEMENTS cites par CET
  // article (jamais contre l'ensemble du paquet) — coherent avec l'attribution exigee.
  const extraitsAutorises = sourcesResolues
    .filter(s => s.id.indexOf('forum_topics:') === 0 || s.id.indexOf('forum_posts:') === 0)
    .map(s => s.source.extrait || '');
  extraireCitations(art.texte).forEach(cit => {
    const trouve = extraitsAutorises.some(ex => ex.indexOf(cit) !== -1);
    if (!trouve) erreurs.push(`${contexte} (${art.id}) : citation non retrouvée telle quelle dans un extrait autorisé -> "${cit.slice(0, 60)}"`);
  });
}

function validerEdition(reponseTexte, aiInput) {
  const erreurs = [];
  let json;
  try {
    json = JSON.parse(reponseTexte);
  } catch (e) {
    return { valide: false, erreurs: ['JSON invalide : ' + e.message] };
  }
  if (!json || typeof json !== 'object') return { valide: false, erreurs: ['Réponse JSON racine invalide'] };

  const { une, double_page_centrale, page_economie_societe } = json;
  if (!une || typeof une !== 'object') erreurs.push('une manquante');
  if (!double_page_centrale || typeof double_page_centrale !== 'object') erreurs.push('double_page_centrale manquante');
  if (!page_economie_societe || typeof page_economie_societe !== 'object') erreurs.push('page_economie_societe manquante');
  if (erreurs.length) return { valide: false, erreurs };

  const index = indexerAiInput(aiInput);
  const idsVus = new Set();

  ['villes', 'nationale', 'internationale'].forEach(rubrique => {
    const liste = double_page_centrale[rubrique];
    if (!Array.isArray(liste)) { erreurs.push(`double_page_centrale.${rubrique} doit être un tableau`); return; }
    liste.forEach(art => validerArticle(art, index, erreurs, `double_page_centrale.${rubrique}`, idsVus));
  });

  ['statistiques', 'absences_notables'].forEach(rubrique => {
    const liste = page_economie_societe[rubrique];
    if (!Array.isArray(liste)) { erreurs.push(`page_economie_societe.${rubrique} doit être un tableau`); return; }
    const typeAttendu = rubrique === 'statistiques' ? 'statistique' : 'absence_remarquable';
    liste.forEach(art => {
      validerArticle(art, index, erreurs, `page_economie_societe.${rubrique}`, idsVus);
      if (art && art.type && art.type !== typeAttendu) erreurs.push(`page_economie_societe.${rubrique} (${art.id}) : type "${art.type}" incohérent avec la rubrique (attendu "${typeAttendu}")`);
    });
  });

  // Rubrique pédagogique — vide obligatoire tant qu'aucune EDUCATIONAL_REFERENCE n'est autorisée.
  const rp = page_economie_societe.rubrique_pedagogique;
  const ficheAutorisee = aiInput.EDUCATIONAL_REFERENCE && aiInput.EDUCATIONAL_REFERENCE.fiche_id;
  if (!rp || typeof rp !== 'object') {
    erreurs.push('rubrique_pedagogique manquante');
  } else if (!ficheAutorisee) {
    if (rp.fiche_id !== null || rp.titre !== null || rp.texte !== null) {
      erreurs.push('rubrique_pedagogique non vide alors qu\'aucune EDUCATIONAL_REFERENCE n\'est autorisée');
    }
  } else if (rp.fiche_id !== ficheAutorisee) {
    erreurs.push('rubrique_pedagogique.fiche_id ne correspond pas à EDUCATIONAL_REFERENCE.fiche_id');
  }

  // Une : titre/chapeau/accroches/image.
  if (typeof une.titre_principal !== 'string' || !une.titre_principal) erreurs.push('une.titre_principal manquant');
  if (typeof une.chapeau !== 'string') erreurs.push('une.chapeau manquant');
  if (!Array.isArray(une.accroches)) {
    erreurs.push('une.accroches doit être un tableau');
  } else {
    une.accroches.forEach((acc, i) => {
      if (!acc || typeof acc.texte !== 'string' || typeof acc.article_ref !== 'string') { erreurs.push(`une.accroches[${i}] invalide`); return; }
      if (!idsVus.has(acc.article_ref)) erreurs.push(`une.accroches[${i}] : article_ref inconnu "${acc.article_ref}"`);
    });
  }
  if (!une.image || typeof une.image !== 'object') {
    erreurs.push('une.image manquante');
  } else {
    if (!TYPES_IMAGE_VALIDES.includes(une.image.type)) erreurs.push(`une.image.type invalide ou interdit "${une.image.type}"`);
    if ((une.image.type === 'generique' || une.image.type === 'fallback') && une.image.ref_id != null) erreurs.push('une.image.ref_id doit être null pour generique/fallback');
    if ((une.image.type === 'personnage' || une.image.type === 'lieu') && !une.image.ref_id) erreurs.push('une.image.ref_id manquant pour ce type d\'image');
  }

  return { valide: erreurs.length === 0, erreurs };
}

// =====================
// ORCHESTRATION PAR PAYS — INSERT (verrou) -> collecte -> IA -> validation -> publication/echec.
// Cycle de vie strictement limité à en_cours -> publiee OU en_cours -> echec (décision validée) :
// aucune ligne déjà terminée (publiee/echec) n'est jamais relue ni réécrite ici.
// =====================
async function genererEditionPays(pays) {
  const maintenant = new Date();
  const dateEdition = dateEditionPourPays(pays, maintenant);
  const id = `${pays}_${dateEdition}`;

  const reservation = await sbInsert('journal_editions', {
    id, country: pays, date_edition: dateEdition, statut: 'en_cours'
  });
  if (!reservation.ok) {
    const dejaExistante = reservation.status === 409;
    return { pays, dateEdition, statut: dejaExistante ? 'ignoree_deja_existante' : 'echec_reservation', detail: reservation.detail };
  }

  try {
    const periode = await calculerPeriode(pays);
    const paquet = await construirePaquetFactuel(pays, periode);
    // AI_INPUT : restructuration purement formelle du paquet Lot A (regroupement des
    // indicateurs prix/stock par ville, voir construireAiInput) — le paquet Lot A complet reste
    // intact ci-dessus pour l'archive/historique/comparaisons, jamais modifié ni raccourci.
    const aiInput = construireAiInput(paquet);
    const faitsSourcesArchive = { ...paquet, AI_INPUT: aiInput };

    const systemPrompt = construirePromptSysteme();
    const appel = await appelAnthropic(systemPrompt, aiInput, ANTHROPIC_TIMEOUT_MS);

    if (!appel.ok) {
      await sbUpdate('journal_editions', `id=eq.${encodeURIComponent(id)}`, {
        statut: 'echec', validation_erreurs: [appel.erreur], generated_at: maintenant.toISOString(), prompt_version: PROMPT_VERSION, faits_sources: faitsSourcesArchive
      });
      return { pays, dateEdition, statut: 'echec', raison: appel.erreur };
    }

    // Validation contre EXACTEMENT ce qui a été envoyé (aiInput), jamais contre le paquet
    // complet Lot A -- un source_id n'est valide que s'il était réellement accessible par l'IA.
    const validation = validerEdition(appel.texte, aiInput);
    if (!validation.valide) {
      await sbUpdate('journal_editions', `id=eq.${encodeURIComponent(id)}`, {
        statut: 'echec', validation_erreurs: validation.erreurs, generated_at: maintenant.toISOString(), prompt_version: PROMPT_VERSION, faits_sources: faitsSourcesArchive
      });
      return { pays, dateEdition, statut: 'echec', raison: validation.erreurs };
    }

    const contenu = JSON.parse(appel.texte);
    await sbUpdate('journal_editions', `id=eq.${encodeURIComponent(id)}`, {
      statut: 'publiee',
      une: contenu.une,
      double_page_centrale: contenu.double_page_centrale,
      page_economie_societe: contenu.page_economie_societe,
      faits_sources: faitsSourcesArchive,
      prompt_version: PROMPT_VERSION,
      generated_at: maintenant.toISOString()
    });
    return { pays, dateEdition, statut: 'publiee' };
  } catch (e) {
    // Filet de sécurité local (couvre toute exception JS interceptable) : marque l'édition en
    // échec plutôt que de la laisser bloquée en_cours indéfiniment. Le seul cas non couvrable
    // est un arrêt brutal de la fonction par la plateforme (dépassement du budget global) —
    // documenté dans le rapport, aucune tentative de le "réparer" ici.
    await sbUpdate('journal_editions', `id=eq.${encodeURIComponent(id)}`, {
      statut: 'echec', validation_erreurs: ['Exception inattendue : ' + e.message], generated_at: maintenant.toISOString(), prompt_version: PROMPT_VERSION
    }).catch(() => {});
    return { pays, dateEdition, statut: 'echec', raison: e.message };
  }
}

async function genererToutesLesEditions() {
  const pays = await determinerPaysEligibles();
  const resultats = await Promise.allSettled(pays.map(p => genererEditionPays(p)));
  return resultats.map((r, i) => (r.status === 'fulfilled' ? r.value : { pays: pays[i], statut: 'exception', raison: String(r.reason) }));
}

export {
  genererToutesLesEditions,
  genererEditionPays,
  PROMPT_VERSION,
  TIMEZONE_PAR_PAYS,
  dateEditionPourPays,
  construirePromptSysteme,
  construireAiInput,
  indexerAiInput,
  validerEdition,
  appelAnthropic
};
