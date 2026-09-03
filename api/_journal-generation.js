// =====================
// LA TRIBUNE DE RÉPUBLIA — LOT B : GÉNÉRATION IA + VALIDATION DÉTERMINISTE + PUBLICATION
// =====================
// Module serveur interne, PAS un endpoint Vercel (prefixe "_", même convention que
// _journal-collecte.js, Lot A). Orchestré depuis api/cron-minuit.js, en toute dernière étape,
// dans son propre try/catch — jamais appelé par le navigateur du joueur.
//
// Consomme _journal-collecte.js (Lot A) tel quel.
//
// Doctrine éditoriale absolue, inchangée par la refonte : « Le journal peut interpréter les faits
// à sa façon. Il ne peut pas inventer les faits. » Toute violation détectable déterministiquement
// (voir validerEdition) invalide l'édition ENTIÈRE — jamais de publication partielle.
//
// REFONTE (31 aout 2026, "La Tribune de Republia") — ce que ce lot change par rapport à l'ancien
// Journal du jour, et pourquoi (voir audit complet de la même date pour le détail) :
//   1. Une PJ obligatoire : si le paquet contient ne serait-ce qu'un fait/déclaration estPJ:true
//      (n'importe quel poids, même "mineur" — décision explicite, 31 aout 2026 : le poids choisit
//      la MEILLEURE actualité PJ, il n'autorise jamais une actualité non-PJ à prendre la Une), la
//      Une DOIT s'ancrer sur une source PJ — voir hasPJMaterial() et la vérification dédiée dans
//      validerEdition(). Sinon (aucune matière PJ du tout), la Une reste libre (y compris "journée
//      calme"), jamais fabriquée artificiellement.
//   2. Schéma de sortie radicalement allégé : l'IA ne produit plus que "une" + "articles" (liste
//      plate, rubrique libre). La "dernière page" (indices économiques, carnet, chiens écrasés) et
//      l'interview de Jodie Moitout sont assemblées ICI, par du code déterministe, JAMAIS par
//      l'IA : zéro risque d'invention sur ces sections, zéro appel IA supplémentaire (voir §20 du
//      cahier des charges : un seul appel IA par pays et par jour, non négociable).
//   3. Économie ordinaire : les indicateurs prix/stock bruts ne sont plus envoyés à l'IA du tout
//      (seuls les événements "economie_remarquable" qualifiés par le Lot A le sont) — l'IA ne peut
//      donc plus transformer un stock banal en article, par construction, pas par consigne.
//   4. Mécanisme "absence = actualité" supprimé : plus aucune fabrication de "zéro naissance,
//      pour la Neme édition consécutive" (voir Lot A, calculerComparaisons entièrement retiré).
//
// import { genererToutesLesEditions } from './_journal-generation.js';

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

// SERVICE_ROLE (securisation journal_editions, 3 septembre 2026, voir migration_journal_editions_
// securisation.sql) : journal_editions n'accepte plus d'ecriture anon une fois cette migration
// executee (RLS active, seule une policy SELECT publique existe) -- le cron doit desormais ecrire
// avec la cle privilegiee, UNIQUEMENT via cette variable d'environnement Vercel, jamais exposee au
// client, meme convention que api/upload-org-avatar.js/api/renseignements.js. La lecture des
// AUTRES tables (personnages, forum_topics, etc., via _journal-collecte.js) reste sur la cle anon,
// deja publique -- seules les 4 ecritures sur journal_editions basculent ici.
const SUPABASE_SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY || null;
const SB_HEADERS_SERVICE = {
  'Content-Type': 'application/json',
  'apikey': SUPABASE_SERVICE_ROLE,
  'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE}`
};

async function sbInsert(table, data, headers) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
    method: 'POST',
    headers: { ...(headers || SB_HEADERS), 'Prefer': 'return=representation' },
    body: JSON.stringify(data)
  });
  if (!res.ok) {
    const detail = await res.text().catch(() => '');
    return { ok: false, status: res.status, detail };
  }
  return { ok: true };
}

async function sbUpdate(table, filtre, data, headers) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${filtre}`, {
    method: 'PATCH',
    headers: { ...(headers || SB_HEADERS), 'Prefer': 'return=representation' },
    body: JSON.stringify(data)
  });
  if (!res.ok) {
    const detail = await res.text().catch(() => '');
    return { ok: false, status: res.status, detail };
  }
  return { ok: true };
}

async function sbGet(table, filtre, headers) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${filtre}`, {
    headers: (headers || SB_HEADERS)
  });
  if (!res.ok) return [];
  return res.json();
}

const PROMPT_VERSION = 'v2-la-tribune';

const TIMEZONE_PAR_PAYS = {
  republic: 'Europe/Paris',
  narco: 'Europe/Paris',
  soviet: 'Europe/Paris',
  khalija: 'Europe/Paris'
};

const NOMS_PAYS = {
  republic: 'Républia',
  narco: 'El Estado',
  soviet: 'Sovarka',
  khalija: 'Al-Khalija'
};

// Budget interne par appel Anthropic (indépendant du maxDuration global du cron, 120s).
const ANTHROPIC_TIMEOUT_MS = 60000;
const ANTHROPIC_MODEL = 'claude-sonnet-4-5'; // cohérent avec tous les appels IA existants du projet

function dateEditionPourPays(pays, momentDate) {
  const tz = TIMEZONE_PAR_PAYS[pays] || 'Europe/Paris';
  const fmt = new Intl.DateTimeFormat('en-CA', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit' });
  return fmt.format(momentDate);
}

// =====================
// CONSTRUCTION DE L'ENTRÉE IA — allégée par rapport à l'ancien Journal (voir en-tête de fichier,
// point 3) : les indicateurs économiques ordinaires ne sont PLUS transmis du tout ; seuls les
// FACTS "economie_remarquable" qualifiés par le Lot A (pénurie, rupture, variation forte, caisse
// dans le rouge) peuvent devenir un article. Les indicateurs population/classement restent
// transmis : un franchissement de seuil démographique ou une place au classement restent des
// informations légitimes, jamais un prétexte à "réciter une base de données".
// =====================
function construireAiInput(paquet, dateEdition) {
  const indicateursPertinents = (paquet.INDICATORS || []).filter(i =>
    i.cle === 'population_totale' || i.cle === 'population_par_ville' || i.cle === 'classement_clubs_nationaux'
  );
  return {
    country: paquet.country,
    date_edition: dateEdition,
    periode: paquet.periode,
    FACTS: paquet.FACTS,
    PUBLIC_STATEMENTS: paquet.PUBLIC_STATEMENTS,
    INDICATORS: indicateursPertinents
  };
}

// Index id -> fait/déclaration/indicateur, construit à partir d'EXACTEMENT ce qui a été envoyé à
// l'IA (aiInput) — jamais à partir du paquet complet Lot A.
function indexerAiInput(aiInput) {
  const index = {};
  (aiInput.FACTS || []).forEach(f => { index[f.id] = f; });
  (aiInput.PUBLIC_STATEMENTS || []).forEach(s => { index[s.id] = s; });
  (aiInput.INDICATORS || []).forEach(i => { index[i.id] = i; });
  return index;
}

// =====================
// SCHÉMA + PROMPT SYSTÈME
// =====================
const SCHEMA_JSON_TEXTE = `{
  "une": {
    "titre_principal": "string",
    "chapeau": "string",
    "article_principal_ref": "string|null (id d'un article existant et domestique ; null UNIQUEMENT si aucune matière PJ n'existe nulle part dans le paquet, voir règle de Une)",
    "accroches": [ { "texte": "string", "article_ref": "string (id d'un article existant et domestique)" } ],
    "image": { "type": "personnage|lieu|generique|fallback", "ref_id": "string|null" }
  },
  "articles": [
    {
      "id": "string",
      "rubrique": "string (libre : Politique, Justice, Société, Économie, Sport, Vie locale, International, ou toute autre étiquette pertinente — n'en crée que si tu as un article à y mettre)",
      "type": "actualite|declaration",
      "titre": "string",
      "texte": "string",
      "ville": "string|null",
      "pays_source": "string|null",
      "source_ids": ["string", ...],
      "image": { "type": "personnage|lieu|generique|fallback", "ref_id": "string|null" }
    }
  ]
}`;

function construirePromptSysteme(pays, dateEdition, hasPJMaterial) {
  const nomPays = NOMS_PAYS[pays] || pays;
  return `Tu es la rédaction de "La Tribune de ${nomPays}", le quotidien national de ${nomPays}, un pays fictif du jeu Res Publica.

Cette édition porte la date du ${dateEdition} — c'est la date humaine officielle de ce numéro. Les données "periode" (debut/fin) sont des bornes techniques réelles qui peuvent parler d'un instant légèrement différent : tu peux évoquer "les dernières 24 heures", "la veille", mais ne présente jamais une autre date civile que le ${dateEdition} comme étant celle de ce numéro.

PRINCIPE ÉDITORIAL FONDAMENTAL : « Le journal doit raconter ce qui s'est passé dans Res Publica, pas réciter l'état de ses bases de données. » Un fait mérite un article parce qu'il s'est PASSÉ quelque chose, jamais parce qu'un chiffre existe.

RÈGLE ABSOLUE, NON NÉGOCIABLE : « Tu peux interpréter les faits à ta façon. Tu ne peux JAMAIS inventer les faits. » Tu reçois un paquet de données structurées (FACTS, PUBLIC_STATEMENTS, INDICATORS). C'est la SEULE réalité que tu connais. N'utilise jamais une connaissance générale du monde réel au-delà de ce paquet.

TU PEUX : hiérarchiser l'information, choisir un angle, commenter, ironiser, adopter un ton partisan ou de mauvaise foi, dramatiser prudemment (jamais présenter une causalité comme certaine si elle n'est pas prouvée), rapprocher plusieurs faits réellement présents dans le paquet.

TU NE PEUX JAMAIS : inventer un événement, une personne, une déclaration, une citation, un chiffre, une causalité certaine non démontrée. Si les données sont pauvres, écris PLUS COURT — une édition honnête et courte vaut toujours mieux qu'une édition remplie artificiellement. Ne produis un article ou une rubrique QUE s'il existe un contenu réel derrière : ne crée jamais de rubrique pour combler un vide.

RÈGLE DE UNE — « Les personnages de Res Publica font l'actualité de Res Publica » (règle STRICTE, non négociable) :
${hasPJMaterial
    ? `Chaque fait et chaque déclaration du paquet porte un champ "estPJ". Il existe dans ce paquet AU MOINS un fait ou une déclaration impliquant un personnage joueur (PJ) — QUEL QUE SOIT SON POIDS, même "mineur". La grande Une (titre_principal, chapeau, article_principal_ref) DOIT donc s'ancrer sur un fait ou une déclaration où estPJ vaut true : ce n'est pas une préférence, c'est une obligation dès qu'une seule matière PJ existe, aussi mince soit-elle. Le champ "poids" ne sert QU'À choisir la MEILLEURE actualité PJ disponible parmi celles qui existent — il ne t'autorise jamais à laisser une actualité automatique ou non-PJ (un stock, un indicateur, un fait purement institutionnel sans PJ) prendre la Une à la place d'un fait PJ, même si ce fait PJ te semble mineur en comparaison. Un PJ peut faire la Une pour n'importe quelle raison : victorieux, humilié, arrêté, accusé, soupçonné, controversé, victime, auteur d'un exploit ou d'un scandale, ou même simplement un événement ordinaire qui le concerne s'il n'y a rien de plus fort — la Une n'est PAS un tableau d'honneur. Ne fabrique jamais un événement PJ qui n'existe pas dans le paquet : choisis parmi ceux qui existent réellement, aussi modestes soient-ils.`
    : `Aucun fait ni déclaration impliquant un personnage joueur n'existe nulle part dans ce paquet pour cette période (aucun "estPJ":true, à aucun poids). C'est SEULEMENT dans ce cas que la Une reste libre : un fait national notable, ou une Une "journée calme" honnête (article_principal_ref:null) si rien de notable ne s'est produit. Ne fabrique jamais un événement PJ qui n'existe pas.`}

PRIORITÉ ÉDITORIALE GÉNÉRALE (à l'intérieur de ce cadre, c'est toi qui hiérarchises) :
1. événements significatifs impliquant des PJ (champ "estPJ":true, poids "important" ou "majeur") ;
2. événements nationaux importants ;
3. événements locaux significatifs ;
4. informations institutionnelles, sociales, économiques ou sportives réellement notables (déjà pré-qualifiées "economie_remarquable" ou "performance_sportive" par le système — les indicateurs économiques ordinaires ne te sont volontairement PAS transmis, ils n'ont pas leur place ici) ;
5. informations secondaires.
Le champ "poids" (mineur/secondaire/important/majeur) sur chaque fait reflète déjà cette hiérarchie telle que le système la calcule — sers-t'en, mais l'angle et la mise en récit restent les tiens.

DIVERSITÉ DES PJ EXPOSÉS : certains faits portent "expositionRecente":true (le même PJ a déjà eu un article "majeur" dans une des 2 dernières éditions). La vérité factuelle reste toujours prioritaire — si ce PJ produit réellement le plus gros événement aujourd'hui encore, il peut refaire la Une. Mais à intérêt éditorial comparable entre deux sujets secondaires, préfère celui qui n'a pas "expositionRecente":true.

FOOTBALL — PERFORMANCES INDIVIDUELLES : un fait "performance_sportive" indique le nombre de buts ("buts") inscrits par un même joueur dans un même match, déjà agrégé. 1 but est une information sportive mineure ; 2 buts (doublé) sont plus notables ; 3 buts (triplé) ou plus sont un événement sportif majeur, a fortiori si "estPJ" vaut true — un tel fait peut légitimement devenir la Une.

HIÉRARCHIE GÉOGRAPHIQUE : ce journal est celui de ${nomPays} (pays "${pays}"). Pour la Une et tout article dont la "rubrique" n'est pas explicitement internationale : priorité ABSOLUE aux faits dont le pays correspond à "${pays}". Une information étrangère va UNIQUEMENT dans un article de rubrique internationale, présentée clairement comme telle. Elle ne peut JAMAIS devenir le titre principal de la Une ni une accroche, même si l'actualité intérieure est pauvre.

FAITS vs DÉCLARATIONS : FACTS est établi par le système lui-même. PUBLIC_STATEMENTS prouve seulement que son auteur a publiquement écrit quelque chose — JAMAIS que c'est vrai. Tout article de type "declaration" doit attribuer explicitement le contenu à son auteur avec un verbe déclaratif ("X affirme...", "X accuse..."), jamais le présenter comme un fait acquis. Une rumeur reste une rumeur : "selon une rumeur...", "une rumeur met en cause...", jamais présentée comme un fait établi. Si un PJ a publiquement répondu à une rumeur ou une accusation le concernant (present aussi dans PUBLIC_STATEMENTS), cette réponse est elle-même une information légitime, à attribuer de la même façon.

CITATIONS : n'utilise JAMAIS de guillemets sauf pour reproduire une sous-chaîne du champ "extrait" d'un PUBLIC_STATEMENT cité en source, CARACTÈRE POUR CARACTÈRE, sans aucune correction. Si tu veux reformuler ou résumer, fais-le sans guillemets, en paraphrase attribuée.

TRAÇABILITÉ OBLIGATOIRE ET COMPLÈTE : chaque article doit avoir "source_ids" non vide, contenant UNIQUEMENT des identifiants qui existent réellement dans le paquet fourni, et TOUS les identifiants réellement utilisés dans le texte (pas seulement celui qui a inspiré le titre).

IMAGES : choisis "type":"personnage" UNIQUEMENT si "ref_id" est l'identifiant (déjà présent dans tes "source_ids") d'un fait ou d'une déclaration où "estPJ" vaut true — ce sera alors le portrait de ce PJ. Choisis "type":"lieu" UNIQUEMENT si "ref_id" est l'identifiant d'un fait de football déjà cité (ce sera l'image du stade concerné). Sinon utilise "generique" ou "fallback", avec "ref_id":null. N'invente jamais un ref_id qui ne serait pas déjà dans tes source_ids.

FORMAT DE SORTIE STRICT — réponds UNIQUEMENT avec un objet JSON valide respectant EXACTEMENT ce schéma, sans aucun texte avant/après, sans balises markdown, sans commentaire :
${SCHEMA_JSON_TEXTE}

Toute violation de ces règles rendra l'édition entière rejetée et non publiée.`;
}

// =====================
// APPEL ANTHROPIC — direct, jamais via api/chat.js. Préremplissage de la réponse par "{" pour
// maximiser la fiabilité du JSON, avec repli défensif avant parsing.
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
// VALIDATION DÉTERMINISTE
// =====================
const TYPES_ARTICLE_VALIDES = ['actualite', 'declaration'];
const TYPES_IMAGE_VALIDES = ['personnage', 'lieu', 'generique', 'fallback'];

const MOTS_ZERO = ['aucun', 'aucune', 'aucuns', 'aucunes', 'zéro', 'zero', 'pas de'];
function valeurRepresenteeDansTexte(valeur, texte) {
  if (valeur === 0) {
    if (texte.indexOf('0') !== -1) return true;
    const texteMinuscule = texte.toLowerCase();
    return MOTS_ZERO.some(mot => texteMinuscule.indexOf(mot) !== -1);
  }
  const formePoint = String(valeur);
  if (texte.indexOf(formePoint) !== -1) return true;
  if (formePoint.indexOf('.') !== -1) {
    const formeVirgule = formePoint.replace('.', ',');
    if (texte.indexOf(formeVirgule) !== -1) return true;
  }
  return false;
}

function extraireCitations(texte) {
  const citations = [];
  const reFr = /«([^»]+)»/g;
  const reDroit = /"([^"]+)"/g;
  let m;
  while ((m = reFr.exec(texte))) citations.push(m[1].trim());
  while ((m = reDroit.exec(texte))) citations.push(m[1].trim());
  return citations;
}

// Hiérarchie géographique : un article est étranger si TOUTES ses sources ont un pays différent
// du pays cible (un match de championnat peut concerner deux pays à la fois : jamais de faux
// positif si l'un des deux est le pays cible).
function paysDeSource(source) {
  if (!source) return [];
  if (Array.isArray(source.pays)) return source.pays;
  return source.pays != null ? [source.pays] : [];
}
function articleEstEtranger(article, paysCible, index) {
  if (!article) return false;
  if (!Array.isArray(article.source_ids) || article.source_ids.length === 0) return false;
  const paysCites = article.source_ids.reduce((acc, sid) => acc.concat(paysDeSource(index[sid])), []);
  if (paysCites.length === 0) return false;
  return !paysCites.includes(paysCible);
}

function validerImage(image, contexte, sourceIdsArticle, index, erreurs) {
  if (!image || typeof image !== 'object') { erreurs.push(`${contexte} : image manquante`); return; }
  if (!TYPES_IMAGE_VALIDES.includes(image.type)) { erreurs.push(`${contexte} : image.type invalide "${image.type}"`); return; }
  if ((image.type === 'generique' || image.type === 'fallback')) {
    if (image.ref_id != null) erreurs.push(`${contexte} : image.ref_id doit être null pour generique/fallback`);
    return;
  }
  if (!image.ref_id || !sourceIdsArticle.includes(image.ref_id)) {
    erreurs.push(`${contexte} : image.ref_id "${image.ref_id}" doit être un des source_ids déjà cités`);
    return;
  }
  const source = index[image.ref_id];
  if (image.type === 'personnage' && (!source || !source.estPJ || !source.photo_url)) {
    erreurs.push(`${contexte} : image "personnage" (${image.ref_id}) ne correspond pas à un PJ avec portrait connu`);
  }
  if (image.type === 'lieu' && (!source || !source.club_image)) {
    erreurs.push(`${contexte} : image "lieu" (${image.ref_id}) ne correspond à aucun lieu identifiable`);
  }
}

function validerArticle(art, index, erreurs, idsVus, articlesParId) {
  if (!art || typeof art !== 'object') { erreurs.push('article invalide (non objet)'); return; }
  if (typeof art.id !== 'string' || !art.id) { erreurs.push('id manquant sur un article'); return; }
  if (idsVus.has(art.id)) erreurs.push(`id d'article dupliqué : "${art.id}"`);
  idsVus.add(art.id);
  articlesParId[art.id] = art;
  if (typeof art.rubrique !== 'string' || !art.rubrique) { erreurs.push(`article (${art.id}) : rubrique manquante`); return; }
  if (!TYPES_ARTICLE_VALIDES.includes(art.type)) { erreurs.push(`article (${art.id}) : type invalide "${art.type}"`); return; }
  if (typeof art.titre !== 'string' || !art.titre) { erreurs.push(`article (${art.id}) : titre manquant`); return; }
  if (typeof art.texte !== 'string' || !art.texte) { erreurs.push(`article (${art.id}) : texte manquant`); return; }
  if (!Array.isArray(art.source_ids) || art.source_ids.length === 0) { erreurs.push(`article (${art.id}) : source_ids vide ou absent`); return; }

  const sourcesResolues = [];
  for (const sid of art.source_ids) {
    if (typeof sid !== 'string') { erreurs.push(`article (${art.id}) : source_id non-chaîne`); return; }
    const source = index[sid];
    if (!source) { erreurs.push(`article (${art.id}) : source_id inconnu ou absent de l'entrée IA "${sid}"`); return; }
    sourcesResolues.push({ id: sid, source });
  }

  if (art.type === 'declaration') {
    const declarations = art.source_ids.filter(id => id.indexOf('forum_topics:') === 0 || id.indexOf('forum_posts:') === 0);
    if (declarations.length === 0) erreurs.push(`article (${art.id}) : type "declaration" doit citer au moins une déclaration publique`);
  }

  // Anti-invention chiffrée : tout indicateur numérique cité doit voir sa valeur reproduite
  // fidèlement dans le texte (jamais un chiffre modifié ou arrondi différemment).
  sourcesResolues.forEach(({ id, source }) => {
    if (id.indexOf('indicateur:') === 0) {
      if (source.disponible === false) { erreurs.push(`article (${art.id}) : cite un indicateur indisponible (${id}) comme s'il était connu`); return; }
      if (source.valeur != null && typeof source.valeur !== 'object' && !valeurRepresenteeDansTexte(source.valeur, art.texte)) {
        erreurs.push(`article (${art.id}) : la valeur de l'indicateur ${id} (${source.valeur}) n'apparaît pas dans le texte`);
      }
    }
  });

  // Citations : vérifiées uniquement contre les extraits des PUBLIC_STATEMENTS cités par CET article.
  const extraitsAutorises = sourcesResolues
    .filter(s => s.id.indexOf('forum_topics:') === 0 || s.id.indexOf('forum_posts:') === 0)
    .map(s => s.source.extrait || '');
  extraireCitations(art.texte).forEach(cit => {
    const trouve = extraitsAutorises.some(ex => ex.indexOf(cit) !== -1);
    if (!trouve) erreurs.push(`article (${art.id}) : citation non retrouvée telle quelle dans un extrait autorisé -> "${cit.slice(0, 60)}"`);
  });

  validerImage(art.image, `article (${art.id})`, art.source_ids, index, erreurs);
}

// Règle de Une PJ (voir en-tête de fichier et prompt) : si le paquet contient de la matière PJ
// exploitable, la Une doit s'ancrer sur une source estPJ:true.
//
// CORRECTIF ÉDITORIAL (31 aout 2026, décision explicite de Fred) : AUCUN seuil de poids ici. Dès
// qu'un seul fait ou déclaration porte estPJ:true, quel que soit son poids (même "mineur"), la
// règle de Une s'applique. Le poids ne sert qu'à choisir la MEILLEURE actualité PJ parmi celles
// disponibles (voir prompt) -- il ne sert JAMAIS à autoriser une actualité non-PJ à prendre la
// Une. Une Une non-PJ / "journée calme" n'est légitime que si aucune matière PJ n'existe DU TOUT
// dans le paquet, pas seulement si elle est jugée trop faible.
function hasPJMaterial(aiInput) {
  const check = f => f.estPJ === true;
  return (aiInput.FACTS || []).some(check) || (aiInput.PUBLIC_STATEMENTS || []).some(check);
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

  const { une, articles } = json;
  if (!une || typeof une !== 'object') erreurs.push('une manquante');
  if (!Array.isArray(articles)) erreurs.push('articles doit être un tableau');
  if (erreurs.length) return { valide: false, erreurs };

  const index = indexerAiInput(aiInput);
  const idsVus = new Set();
  const articlesParId = {};
  const paysCible = aiInput.country;

  articles.forEach(art => validerArticle(art, index, erreurs, idsVus, articlesParId));

  articles.forEach(art => {
    if (!art || !art.rubrique) return;
    const estInternational = /international/i.test(art.rubrique);
    if (!estInternational && articleEstEtranger(art, paysCible, index)) {
      erreurs.push(`article (${art.id}) : entièrement fondé sur des sources étrangères mais rubrique "${art.rubrique}" non internationale`);
    }
  });

  if (typeof une.titre_principal !== 'string' || !une.titre_principal) erreurs.push('une.titre_principal manquant');
  if (typeof une.chapeau !== 'string') erreurs.push('une.chapeau manquant');

  if (une.article_principal_ref != null) {
    if (typeof une.article_principal_ref !== 'string') {
      erreurs.push('une.article_principal_ref doit être une chaîne ou null');
    } else if (!idsVus.has(une.article_principal_ref)) {
      erreurs.push(`une.article_principal_ref inconnu "${une.article_principal_ref}"`);
    } else if (articleEstEtranger(articlesParId[une.article_principal_ref], paysCible, index)) {
      erreurs.push(`une.article_principal_ref "${une.article_principal_ref}" repose exclusivement sur une source étrangère`);
    }
  }

  // Règle de Une PJ — vérification déterministe du principe "les personnages font l'actualité".
  if (hasPJMaterial(aiInput)) {
    const principal = une.article_principal_ref && articlesParId[une.article_principal_ref];
    const ancreSurPJ = !!principal && Array.isArray(principal.source_ids) &&
      principal.source_ids.some(sid => index[sid] && index[sid].estPJ);
    if (!ancreSurPJ) {
      erreurs.push('une.article_principal_ref : le paquet contient de la matière PJ exploitable mais la Une ne s\'ancre sur aucune source estPJ:true (règle de Une obligatoire)');
    }
  }

  if (!Array.isArray(une.accroches)) {
    erreurs.push('une.accroches doit être un tableau');
  } else {
    une.accroches.forEach((acc, i) => {
      if (!acc || typeof acc.texte !== 'string' || typeof acc.article_ref !== 'string') { erreurs.push(`une.accroches[${i}] invalide`); return; }
      if (!idsVus.has(acc.article_ref)) { erreurs.push(`une.accroches[${i}] : article_ref inconnu "${acc.article_ref}"`); return; }
      if (articleEstEtranger(articlesParId[acc.article_ref], paysCible, index)) {
        erreurs.push(`une.accroches[${i}] : article_ref "${acc.article_ref}" repose exclusivement sur une source étrangère`);
      }
    });
  }

  // L'image de Une cite un source_id de FAIT (comme une image d'article), jamais un id d'article :
  // on rassemble donc les source_ids de l'article principal ET de chaque accroche, pas leurs ids.
  const sourceIdsAccessiblesUne = [
    ...(une.article_principal_ref && articlesParId[une.article_principal_ref] ? articlesParId[une.article_principal_ref].source_ids : []),
    ...((une.accroches || []).reduce((acc, a) => {
      const art = a && articlesParId[a.article_ref];
      return art ? acc.concat(art.source_ids) : acc;
    }, []))
  ];
  validerImage(une.image, 'une', sourceIdsAccessiblesUne, index, erreurs);

  return { valide: erreurs.length === 0, erreurs };
}

// =====================
// ASSEMBLAGE DÉTERMINISTE DE LA DERNIÈRE PAGE ET DE L'AVANT-DERNIÈRE PAGE — jamais par l'IA (voir
// en-tête de fichier, point 2). Le "carnet" et les "chiens écrasés" réutilisent verbatim le champ
// "resume" déjà écrit par le Lot A pour tout fait que l'IA n'a cité dans aucun article : aucune
// information n'est donc silencieusement perdue, sans coût IA supplémentaire.
// =====================
const LIMITE_CHIENS_ECRASES = 15;

function collecterSourceIdsCites(une, articles) {
  const cites = new Set();
  articles.forEach(a => (a.source_ids || []).forEach(id => cites.add(id)));
  if (une.article_principal_ref) cites.add(une.article_principal_ref);
  (une.accroches || []).forEach(a => a && a.article_ref && cites.add(a.article_ref));
  return cites;
}

function assemblerDernierePage(paquet, une, articles) {
  const cites = collecterSourceIdsCites(une, articles);

  const indices_economiques = (paquet.INDICATORS || [])
    .filter(i => i.cle.indexOf('stock_') === 0 && i.disponible)
    .map(i => {
      const ressource = i.cle.replace('stock_', '');
      const prix = (paquet.INDICATORS || []).find(p => p.cle === `prix_${ressource}` && p.ville === i.ville);
      return { ressource, ville: i.ville, stock: i.valeur, prix: prix ? prix.valeur : null };
    });

  const carnet = (paquet.FACTS || [])
    .filter(f => f.type === 'deces' && !cites.has(f.id))
    .map(f => f.resume);

  const chiens_ecrases = (paquet.FACTS || [])
    .filter(f => !cites.has(f.id) && f.type !== 'deces' && f.domaine !== 'economie')
    .filter(f => f.poids === 'mineur' || f.poids === 'secondaire')
    .slice(0, LIMITE_CHIENS_ECRASES)
    .map(f => f.resume);

  // Petites annonces (31 aout 2026) : lecture pure de paquet.PETITES_ANNONCES (Lot A,
  // collecterPetitesAnnoncesActives) -- jamais vues par l'IA, jamais reformulées, aucune
  // invention possible.
  const petites_annonces = (paquet.PETITES_ANNONCES || []).map(a =>
    (a.categorie ? `[${a.categorie}] ` : '') + a.texte + (a.ville ? ` — ${a.ville}` : '')
  );

  return { indices_economiques, carnet, chiens_ecrases, petites_annonces };
}

function assemblerAvantDernierePage(paquet) {
  if (!paquet.INTERVIEW_JODIE) return null;
  return {
    nom: paquet.INTERVIEW_JODIE.nom,
    texte: paquet.INTERVIEW_JODIE.texte,
    photo_url: paquet.INTERVIEW_JODIE.photo_url || null
  };
}

// =====================
// ORCHESTRATION PAR PAYS — INSERT (verrou) -> collecte -> IA -> validation -> publication/echec.
// =====================
// Articles deja rediges par api/journal-interview.js (interview de Jodie Moitout terminee AVANT
// qu'une edition du jour n'existe), en attente d'integration -- assemblage deterministe, ZERO
// appel IA ici, meme doctrine que assemblerAvantDernierePage/assemblerDernierePage. Retourne les
// articles au format attendu par double_page_centrale.articles ET les lignes source (pour les
// marquer integrees apres publication reussie, jamais avant).
async function recupererArticlesEnAttente(pays) {
  if (!SUPABASE_SERVICE_ROLE) return { articles: [], lignes: [] };
  const rows = await sbGet(
    'journal_articles_en_attente',
    `country=eq.${encodeURIComponent(pays)}&integree_le=is.null&order=created_at.asc`,
    SB_HEADERS_SERVICE
  );
  const lignes = rows || [];
  const articles = lignes.map(r => {
    const art = { rubrique: r.rubrique || 'Portraits', titre: r.titre, texte: r.texte };
    if (r.ville) art.ville = r.ville;
    if (r.image_url) art.image = { type: 'url', url: r.image_url };
    return art;
  });
  return { articles, lignes };
}

async function marquerArticlesEnAttenteIntegres(lignes, maintenant) {
  if (!lignes || lignes.length === 0) return;
  await Promise.all(lignes.map(l =>
    sbUpdate('journal_articles_en_attente', `id=eq.${encodeURIComponent(l.id)}`, { integree_le: maintenant.toISOString() }, SB_HEADERS_SERVICE).catch(() => {})
  ));
}

async function genererEditionPays(pays) {
  const maintenant = new Date();
  const dateEdition = dateEditionPourPays(pays, maintenant);
  const id = `${pays}_${dateEdition}`;

  const reservation = await sbInsert('journal_editions', {
    id, country: pays, date_edition: dateEdition, statut: 'en_cours'
  }, SB_HEADERS_SERVICE);
  if (!reservation.ok) {
    const dejaExistante = reservation.status === 409;
    return { pays, dateEdition, statut: dejaExistante ? 'ignoree_deja_existante' : 'echec_reservation', detail: reservation.detail };
  }

  try {
    const periode = await calculerPeriode(pays);
    const paquet = await construirePaquetFactuel(pays, periode);
    const aiInput = construireAiInput(paquet, dateEdition);
    const faitsSourcesArchive = { ...paquet, AI_INPUT: aiInput };

    const systemPrompt = construirePromptSysteme(pays, dateEdition, hasPJMaterial(aiInput));
    const appel = await appelAnthropic(systemPrompt, aiInput, ANTHROPIC_TIMEOUT_MS);

    if (!appel.ok) {
      await sbUpdate('journal_editions', `id=eq.${encodeURIComponent(id)}`, {
        statut: 'echec', validation_erreurs: [appel.erreur], generated_at: maintenant.toISOString(), prompt_version: PROMPT_VERSION, faits_sources: faitsSourcesArchive
      }, SB_HEADERS_SERVICE);
      return { pays, dateEdition, statut: 'echec', raison: appel.erreur };
    }

    const validation = validerEdition(appel.texte, aiInput);
    if (!validation.valide) {
      await sbUpdate('journal_editions', `id=eq.${encodeURIComponent(id)}`, {
        statut: 'echec', validation_erreurs: validation.erreurs, generated_at: maintenant.toISOString(), prompt_version: PROMPT_VERSION, faits_sources: faitsSourcesArchive
      }, SB_HEADERS_SERVICE);
      return { pays, dateEdition, statut: 'echec', raison: validation.erreurs };
    }

    const contenu = JSON.parse(appel.texte);
    const derniere_page = assemblerDernierePage(paquet, contenu.une, contenu.articles);
    const avant_derniere_page = assemblerAvantDernierePage(paquet);

    // Interviews de Jodie terminees avant que cette edition n'existe (voir api/journal-
    // interview.js) : integrees ICI, deterministe, sans nouvel appel IA -- jamais une 2e base
    // d'articles ni un 2e systeme de journal, simplement ajoutees a la MEME liste que l'IA vient
    // de rediger.
    const { articles: articlesEnAttente, lignes: lignesEnAttente } = await recupererArticlesEnAttente(pays);
    const tousLesArticles = [...contenu.articles, ...articlesEnAttente];

    // Aucune colonne Supabase nouvelle (doctrine "pas de migration si évitable", validée pour ce
    // chantier) : les deux colonnes jsonb existantes de journal_editions (double_page_centrale,
    // page_economie_societe) sont réutilisées telles quelles, avec un contenu interne restructuré
    // -- un jsonb accepte n'importe quelle forme, seul le NOM de colonne est figé par le schéma.
    // Lecture cote client : edition.double_page_centrale.articles / edition.page_economie_societe.
    // {avant_derniere_page, derniere_page}. Voir plateau-politique.js, construireHtmlJournalDuJour().
    await sbUpdate('journal_editions', `id=eq.${encodeURIComponent(id)}`, {
      statut: 'publiee',
      une: contenu.une,
      double_page_centrale: { articles: tousLesArticles },
      page_economie_societe: { avant_derniere_page, derniere_page },
      faits_sources: faitsSourcesArchive,
      prompt_version: PROMPT_VERSION,
      generated_at: maintenant.toISOString()
    }, SB_HEADERS_SERVICE);
    // Marquage APRES la publication reussie seulement (jamais avant) : si l'ecriture ci-dessus
    // echouait, ces lignes resteraient en_attente pour la prochaine tentative -- aucune perte.
    await marquerArticlesEnAttenteIntegres(lignesEnAttente, maintenant);
    return { pays, dateEdition, statut: 'publiee' };
  } catch (e) {
    await sbUpdate('journal_editions', `id=eq.${encodeURIComponent(id)}`, {
      statut: 'echec', validation_erreurs: ['Exception inattendue : ' + e.message], generated_at: maintenant.toISOString(), prompt_version: PROMPT_VERSION
    }, SB_HEADERS_SERVICE).catch(() => {});
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
  NOMS_PAYS,
  dateEditionPourPays,
  construirePromptSysteme,
  construireAiInput,
  indexerAiInput,
  validerEdition,
  hasPJMaterial,
  articleEstEtranger,
  assemblerDernierePage,
  assemblerAvantDernierePage,
  appelAnthropic
};
