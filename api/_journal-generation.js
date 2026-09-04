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
function construireAiInput(paquet, dateEdition, dejaCouvert) {
  const indicateursPertinents = (paquet.INDICATORS || []).filter(i =>
    i.cle === 'population_totale' || i.cle === 'population_par_ville' || i.cle === 'classement_clubs_nationaux'
  );
  return {
    country: paquet.country,
    date_edition: dateEdition,
    periode: paquet.periode,
    FACTS: paquet.FACTS,
    PUBLIC_STATEMENTS: paquet.PUBLIC_STATEMENTS,
    INDICATORS: indicateursPertinents,
    DEJA_COUVERT: dejaCouvert || []
  };
}

// Copie ALLEGEE de aiInput pour le SEUL appel reel a l'IA (correctif du 4 septembre 2026, apres
// diagnostic d'une panne de generation en production) : photo_url (portrait d'un PJ, attache a
// chaque FACT/PUBLIC_STATEMENT par identifierActeur) peut etre une image encodee en base64 -- 200
// Ko releves sur un seul personnage -- qui n'apporte RIEN au modele (il ecrit du texte, il ne
// "voit" jamais l'image) mais avait fait gonfler le prompt jusqu'a 964k-1,1M tokens (limite reelle :
// 200k), en echec total depuis le 1er septembre. Ne JAMAIS utiliser cette version allegee pour
// indexerAiInput/validerEdition : validerImage() a besoin de savoir si un photo_url REEL existe pour
// valider qu'un choix d'image "personnage" fait par l'IA correspond a un PJ avec portrait connu --
// aiInput (complet, avec photo_url) reste donc l'unique source de verite pour la validation et
// l'archivage ; seul le texte effectivement envoye au modele est allege ici.
function retirerPhotosPourAppelIA(aiInput) {
  const alleger = items => (items || []).map(({ photo_url, ...reste }) => reste);
  return { ...aiInput, FACTS: alleger(aiInput.FACTS), PUBLIC_STATEMENTS: alleger(aiInput.PUBLIC_STATEMENTS) };
}

// Digest anti-repetition (chantier refonte, 4 septembre 2026) : resume, en donnees, ce qui a deja
// ete publie lors des editions RECENTES (par defaut les 5 dernieres) -- jamais laisse a la
// "memoire" de l'IA (un seul appel par jour, aucune memoire persistante reelle). Reconstruit a
// partir de faits_sources.FACTS des editions publiees, en ne retenant QUE les faits qui ont
// reellement ete cites dans un article (une simple presence dans FACTS, jamais citee, ne compte
// pas comme "deja couverte"). Cle de suivi = l'id du fait lui-meme (idSource, deja unique par
// ligne source) -- suffisant pour tout evenement "one-shot" (election, nomination, condamnation...
// une ligne = un evenement reel qui ne se reproduit jamais a l'identique). Le cas particulier de la
// greve generale (meme id qui reapparait plusieurs jours de suite tant qu'elle dure) est deja gere
// separement par le diff deterministe "evolution" du Lot A, jamais par ce digest generique.
async function chargerDigestDejaCouvert(pays, dateEditionActuelle) {
  const editions = await sbGet('journal_editions',
    `country=eq.${encodeURIComponent(pays)}&statut=eq.publiee&date_edition=lt.${encodeURIComponent(dateEditionActuelle)}&order=date_edition.desc&limit=5&select=date_edition,faits_sources,double_page_centrale`,
    SB_HEADERS_SERVICE
  ).catch(() => []);
  const digest = [];
  (editions || []).forEach(ed => {
    const facts = (ed.faits_sources && ed.faits_sources.FACTS) || [];
    const articles = (ed.double_page_centrale && ed.double_page_centrale.articles) || [];
    const idsCites = new Set();
    articles.forEach(a => (a.source_ids || []).forEach(id => idsCites.add(id)));
    facts.forEach(f => {
      if (f.type === 'greve_generale' || !idsCites.has(f.id)) return;
      digest.push({ id: f.id, resume: f.resume, date_edition: ed.date_edition });
    });
  });
  return digest;
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
    "sujets": [
      {
        "titre": "string",
        "chapeau": "string",
        "article_ref": "string|null (id d'un article existant et domestique ; null UNIQUEMENT si le tableau FACTS est entièrement vide, voir règle de Une)"
      }
    ],
    "appels": [ { "texte": "string", "article_ref": "string (id d'un article existant et domestique)" } ],
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
      "personnages_concernes": ["string", ...],
      "interview_suggeree": "boolean (true UNIQUEMENT si un PJ nommé dans cet article mériterait qu'on le sollicite pour une interview de suivi)",
      "source_ids": ["string", ...],
      "image": { "type": "personnage|lieu|generique|fallback", "ref_id": "string|null" }
    }
  ],
  "sujets_differes": [
    {
      "source_id": "string (id d'un FACT ou d'une PUBLIC_STATEMENT du paquet, jamais un id inventé)",
      "priorite": "chaude|differable",
      "raison": "string (pourquoi ce sujet mérite un traitement complet plus tard plutôt qu'aujourd'hui)"
    }
  ]
}`;

// Hierarchie editoriale validee (chantier refonte, 4 septembre 2026) -- un GUIDE de priorite pour
// l'IA, jamais une grille mecanique : elle sert a choisir la Une quand plusieurs domaines sont en
// concurrence, et a descendre dans la liste si les categories superieures sont vides.
const HIERARCHIE_EDITORIALE = [
  'Politique nationale', 'Crises sociales', 'Justice / criminalité', 'Politique locale',
  'Économie', 'Organisations', 'Sport', 'Société / état civil'
];

function construirePromptSysteme(pays, dateEdition, hasPJMaterial) {
  const nomPays = NOMS_PAYS[pays] || pays;
  return `Tu es la rédaction de "La Tribune de ${nomPays}", le quotidien national de ${nomPays}, un pays fictif du jeu Res Publica.

Cette édition porte la date du ${dateEdition} — c'est la date humaine officielle de ce numéro. Les données "periode" (debut/fin) sont des bornes techniques réelles qui peuvent parler d'un instant légèrement différent : tu peux évoquer "les dernières 24 heures", "la veille", mais ne présente jamais une autre date civile que le ${dateEdition} comme étant celle de ce numéro.

PRINCIPE ÉDITORIAL FONDAMENTAL : « Le journal doit raconter ce qui s'est passé dans Res Publica, pas réciter l'état de ses bases de données. » Un fait mérite un article parce qu'il s'est PASSÉ quelque chose, jamais parce qu'un chiffre existe.

RÈGLE ABSOLUE, NON NÉGOCIABLE : « Tu peux interpréter les faits à ta façon. Tu ne peux JAMAIS inventer les faits. » Tu reçois un paquet de données structurées (FACTS, PUBLIC_STATEMENTS, INDICATORS, DEJA_COUVERT). C'est la SEULE réalité que tu connais. N'utilise jamais une connaissance générale du monde réel au-delà de ce paquet.

TU PEUX : hiérarchiser l'information, choisir un angle, commenter, ironiser, adopter un ton partisan ou de mauvaise foi, dramatiser prudemment (jamais présenter une causalité comme certaine si elle n'est pas prouvée), rapprocher plusieurs faits réellement présents dans le paquet.

TU NE PEUX JAMAIS : inventer un événement, une personne, une déclaration, une citation, un chiffre, une causalité certaine non démontrée. Si les données sont pauvres, écris PLUS COURT — une édition honnête et courte vaut toujours mieux qu'une édition remplie artificiellement. Ne produis un article ou une rubrique QUE s'il existe un contenu réel derrière : ne crée jamais de rubrique pour combler un vide.

TON DE LA TRIBUNE : sérieux et journalistique par défaut. Tu peux être acerbe, mordante, ironique ou drôle lorsque le contexte réel s'y prête — mais JAMAIS en insérant un fait : l'ironie doit venir des faits eux-mêmes, de leur contradiction, de leur contextualisation, ou de leur juxtaposition. Ne force jamais l'humour.

HIÉRARCHIE ÉDITORIALE (guide de priorité pour la Une, pas une grille mécanique — tu restes rédactrice en chef à l'intérieur de ce cadre) :
${HIERARCHIE_EDITORIALE.map((h, i) => `${i + 1}. ${h}`).join('\n')}
S'il n'existe aucune actualité notable dans les catégories les plus hautes, descends dans cette liste jusqu'à trouver la meilleure information réellement disponible — une information sportive, économique ou de société peut parfaitement devenir la Une du jour si rien de plus fort n'existe au-dessus. Le champ "domaine" de chaque fait t'indique sa catégorie.

RÈGLE DE UNE — « Les personnages de Res Publica font l'actualité de Res Publica » (règle STRICTE, non négociable) :
${hasPJMaterial
    ? `Chaque fait et chaque déclaration du paquet porte un champ "estPJ". Il existe dans ce paquet AU MOINS un fait ou une déclaration impliquant un personnage joueur (PJ) — QUEL QUE SOIT SON POIDS, même "mineur". AU MOINS UN des 1 ou 2 sujets de la Une (voir "MAXIMUM DEUX SUJETS EN UNE" ci-dessous) DOIT donc s'ancrer sur un fait ou une déclaration où estPJ vaut true : ce n'est pas une préférence, c'est une obligation dès qu'une seule matière PJ existe, aussi mince soit-elle. Le champ "poids" ne sert QU'À choisir la MEILLEURE actualité PJ disponible parmi celles qui existent — il ne t'autorise jamais à laisser une actualité automatique ou non-PJ (un stock, un indicateur, un fait purement institutionnel sans PJ) occuper TOUS les sujets de Une à la place d'un fait PJ, même si ce fait PJ te semble mineur en comparaison. Un PJ peut faire la Une pour n'importe quelle raison : victorieux, humilié, arrêté, accusé, soupçonné, controversé, victime, auteur d'un exploit ou d'un scandale, ou même simplement un événement ordinaire qui le concerne s'il n'y a rien de plus fort — la Une n'est PAS un tableau d'honneur. Ne fabrique jamais un événement PJ qui n'existe pas dans le paquet : choisis parmi ceux qui existent réellement, aussi modestes soient-ils.`
    : `Aucun fait ni déclaration impliquant un personnage joueur n'existe nulle part dans ce paquet pour cette période (aucun "estPJ":true, à aucun poids). La Une reste alors libre parmi les faits non-PJ disponibles.`}

MAXIMUM DEUX SUJETS EN UNE : le tableau "une.sujets" contient AU PLUS 2 éléments. Un seul sujet suffit la plupart du temps ; deux sujets ne se justifient que si deux informations méritent réellement toutes les deux un traitement de Une le même jour (elles se "partagent" alors la Une). Ne remplis jamais un deuxième sujet artificiellement s'il n'y a qu'un seul vrai sujet de Une.

MAXIMUM TROIS APPELS DE UNE : le tableau "une.appels" contient AU PLUS 3 éléments (0 est parfaitement valide s'il n'y a rien d'autre à signaler). Ce sont de petits titres renvoyant vers un article de deuxième page qui ne fait pas partie des sujets principaux (ex. "Luthécia champion ! — p. 2"). N'en crée que pour des informations réellement notables.

"JOURNÉE CALME" — CONDITION STRICTE : une Une où tous les sujets ont "article_ref":null n'est autorisée QUE si le tableau FACTS transmis est ENTIÈREMENT VIDE. Dès qu'un seul FACT existe, quelle que soit sa catégorie ou son poids, tu DOIS choisir le meilleur d'entre eux pour au moins un sujet de Une — descends dans la hiérarchie éditoriale si besoin, mais ne déclare jamais une "journée calme" tant qu'un fait réel est disponible.

RÈGLES PAR TYPE D'ÉVÉNEMENT (destination éditoriale par défaut — un fait non cité dans un article part automatiquement en dernière page selon son type ; ces règles t'indiquent quand un fait mérite mieux) :
- Arrivée d'un nouveau PJ ("type":"arrivee") : jamais un article, part en "Journal des arrivées" en dernière page. Ne parle JAMAIS de "naissance" pour la création d'un personnage.
- Mariage : carnet par défaut ; article de deuxième page si les personnes concernées sont suffisamment importantes.
- Décès : carnet par défaut ; article si le défunt est une personnalité importante ; Une possible pour une personnalité majeure.
- Candidature électorale ("type":"candidature") : article de deuxième page SYSTÉMATIQUEMENT.
- Résultat d'élection ("type":"election_resultat") : article de deuxième page SYSTÉMATIQUEMENT ; Une possible selon l'importance.
- Nomination (Premier Ministre, ministre, ambassadeur — "type":"nomination") : article de deuxième page SYSTÉMATIQUEMENT, que la personne nommée soit un PJ ou un PNJ ; Une possible selon l'importance.
- Grève générale ("type":"greve_generale") : DOIT apparaître en Une. Le champ "evolution" du fait te dit si son statut/sa puissance ont changé depuis la dernière édition : "evolution":true → traitement fort (nouveau sujet développé) ; "evolution":false → elle reste en Une mais sous une forme visiblement plus réduite qu'un vrai sujet du jour (par exemple via un appel de Une plutôt qu'un sujet développé, ou une mention courte).
- Grève ordinaire, un seul syndicat ("type":"greve_ordinaire_debut" ou "greve_ordinaire_fin") : déclenchement et fin en article de deuxième page.
- Condamnation ("type":"condamnation") ou arrestation ("type":"arrestation") : article de deuxième page SYSTÉMATIQUEMENT ; Une si la personne est une personnalité importante.
- Tentative de fraude électorale déjouée sur le fait ("type":"fraude_electorale_dejouee") ou fraude électorale révélée par une contestation ("type":"fraude_electorale_revelee") : événement public prioritaire — traite-le comme un sujet de Une par défaut (appel de Une possible seulement si l'actualité du jour est manifestement plus forte), jamais relégué en deuxième page ou en brève. N'invente rien au-delà du fait fourni : le "resume" et "data" donnent le type de fraude, la personne impliquée et, pour une révélation, si le résultat officiel a été corrigé — reste strictement dans ces limites, sans supposer de mobile ou de complicité non mentionnés.
- Vente de terrain ("type":"vente_terrain") : brève par défaut ; article si l'opération est manifestement importante (montant élevé, acteur notable).
- Rachat/vente d'entreprise ou de commerce ("type":"entreprise_rachat") : brève par défaut ; article si la transaction ou le commerce est manifestement important.
- Création d'organisation publique ("type":"organisation_creation") : brève par défaut. Les organisations secrètes/criminelles n'existent JAMAIS dans ce paquet — si tu n'en vois aucune trace, c'est normal, ne les évoque jamais.
- Dissolution ou changement de chef d'une organisation publique ("type":"organisation_dissolution" ou "organisation_chef_change") : brève par défaut ; article si l'organisation est notable ou le changement disputé.
- Football, match ordinaire ("type":"resultat_match") : brève. Match important ou "performance_sportive" à 2+ buts : article. 3 buts ou plus (triplé), ou titre de champion : article, Une possible s'il n'existe pas d'actualité politique/sociale suffisamment forte.
- Succession résolue ("type":"succession") : brève par défaut.
- Indicateurs économiques ("type":"economie_remarquable") : brève par défaut ; article si l'impact est fort ; une crise véritablement majeure peut remonter dans la hiérarchie si l'actualité supérieure est faible.
- Déclaration publique sur le forum : ne devient un article QUE si elle présente un véritable intérêt journalistique (annonce politique, accusation, prise de position importante, réaction à une affaire...). Ne génère JAMAIS automatiquement un article pour chaque message du forum.
- Article favorable obtenu par lobbying ("type":"lobbying_article_favorable") : ce fait indique qu'une sollicitation éditoriale discrète a réussi — c'est un fait réel (la sollicitation a eu lieu), mais son contenu est une CONSIGNE D'ANGLE, jamais un fait supplémentaire établi. Rédige un article réellement favorable à la cible désignée, inspiré de l'angle indiqué dans le "resume", SANS jamais inventer de nouveau fait vérifiable (récompense, chiffre, exploit) au-delà de ce que tu sais déjà d'elle par ailleurs dans le paquet — un ton favorable, une mise en valeur de sa personnalité ou de son rôle restent permis. Article de deuxième page par défaut, jamais garanti en Une (une couverture obtenue par lobbying reste plus faible qu'un vrai événement). Ne mentionne JAMAIS, sous aucune forme, que cet article a été sollicité, commandé ou obtenu par lobbying : il doit se lire comme un choix éditorial ordinaire de la rédaction, et le champ "personnages_concernes" ne doit jamais inclure de commanditaire (aucun n'est de toute façon fourni dans ce fait).

PERSONNALITÉ « IMPORTANTE » : cette appréciation t'est laissée entièrement — fonction, importance politique, actualité récente, notoriété, rôle dans l'événement. Ne crée et n'invente jamais une notoriété ou des faits pour justifier ce choix ; base-toi uniquement sur ce que le paquet te montre réellement (poste occupé, présence répétée dans l'actualité récente via DEJA_COUVERT, etc.).

SUIVI DE L'ACTUALITÉ — NE PAS RÉPÉTER MÉCANIQUEMENT : le bloc "DEJA_COUVERT" liste les sujets déjà publiés lors des éditions récentes (avec leur "dedup_key" et leur ancienneté). Si un FACT ou une PUBLIC_STATEMENT correspond à un sujet déjà couvert, NE RÉÉCRIS PAS la même annonce comme une nouvelle ("X nommé ministre" ne doit pas être republié tel quel le lendemain). Tu peux en revanche chercher un PROLONGEMENT réel et présent dans le paquet (première action, déclaration, réaction, décision, conséquence, interview) et en faire un article de suivi — jamais un prolongement inventé. Exception validée : une grève générale déjà couverte reste normalement en Une chaque jour (voir règle dédiée ci-dessus), ce n'est pas une répétition interdite.

REPORT ÉDITORIAL : si l'actualité du jour est trop abondante pour rester lisible, tu peux choisir de ne PAS rédiger d'article pour un sujet pourtant réel et intéressant, et le lister dans "sujets_differes" avec son "source_id" (un id de FACT ou de PUBLIC_STATEMENT du paquet), une "priorite" ("chaude" si le sujet reste pertinent seulement 1 jour de plus, "differable" s'il reste pertinent jusqu'à 5 jours), et une "raison" courte. N'utilise ce mécanisme que pour des sujets réels que tu choisis sciemment de ne pas traiter aujourd'hui — jamais pour un sujet que tu as déjà traité dans un article.

DIVERSITÉ DES PJ EXPOSÉS : certains faits portent "expositionRecente":true (le même PJ a déjà eu un article "majeur" dans une des 2 dernières éditions). La vérité factuelle reste toujours prioritaire — si ce PJ produit réellement le plus gros événement aujourd'hui encore, il peut refaire la Une. Mais à intérêt éditorial comparable entre deux sujets secondaires, préfère celui qui n'a pas "expositionRecente":true.

FOOTBALL — PERFORMANCES INDIVIDUELLES : un fait "performance_sportive" indique le nombre de buts ("buts") inscrits par un même joueur dans un même match, déjà agrégé. 1 but est une information sportive mineure ; 2 buts (doublé) sont plus notables ; 3 buts (triplé) ou plus sont un événement sportif majeur, a fortiori si "estPJ" vaut true — un tel fait peut légitimement devenir la Une.

HIÉRARCHIE GÉOGRAPHIQUE : ce journal est celui de ${nomPays} (pays "${pays}"). Pour la Une et tout article dont la "rubrique" n'est pas explicitement internationale : priorité ABSOLUE aux faits dont le pays correspond à "${pays}". Une information étrangère va UNIQUEMENT dans un article de rubrique internationale, présentée clairement comme telle. Elle ne peut JAMAIS devenir un sujet de Une ni un appel, même si l'actualité intérieure est pauvre.

FAITS vs DÉCLARATIONS : FACTS est établi par le système lui-même. PUBLIC_STATEMENTS prouve seulement que son auteur a publiquement écrit quelque chose — JAMAIS que c'est vrai. Tout article de type "declaration" doit attribuer explicitement le contenu à son auteur avec un verbe déclaratif ("X affirme...", "X accuse..."), jamais le présenter comme un fait acquis. Une rumeur reste une rumeur : "selon une rumeur...", "une rumeur met en cause...", jamais présentée comme un fait établi. Si un PJ a publiquement répondu à une rumeur ou une accusation le concernant (present aussi dans PUBLIC_STATEMENTS), cette réponse est elle-même une information légitime, à attribuer de la même façon.

CITATIONS : n'utilise JAMAIS de guillemets sauf pour reproduire une sous-chaîne du champ "extrait" d'un PUBLIC_STATEMENT cité en source, CARACTÈRE POUR CARACTÈRE, sans aucune correction. Si tu veux reformuler ou résumer, fais-le sans guillemets, en paraphrase attribuée.

TRAÇABILITÉ OBLIGATOIRE ET COMPLÈTE : chaque article doit avoir "source_ids" non vide, contenant UNIQUEMENT des identifiants qui existent réellement dans le paquet fourni, et TOUS les identifiants réellement utilisés dans le texte (pas seulement celui qui a inspiré le titre). Le champ "personnages_concernes" doit lister tous les PJ/PNJ réellement nommés dans l'article, tels qu'ils apparaissent dans les faits sources — jamais un nom inventé.

INTERVIEW SUGGÉRÉE : mets "interview_suggeree":true sur un article UNIQUEMENT si un PJ qui y est nommé vient de vivre quelque chose d'assez marquant (victoire électorale, accession à une fonction, scandale, affaire judiciaire, événement majeur) pour justifier qu'on le sollicite pour un entretien de suivi. N'en abuse pas : ce doit rester rare et réellement justifié par l'article lui-même.

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

  // personnages_concernes / interview_suggeree (chantier refonte, 4 septembre 2026) : champs
  // additifs, absents = tableau vide / false, jamais une erreur bloquante en soi -- seule une
  // valeur de type incorrect ou un booleen manquant sont rejetes.
  if (art.personnages_concernes != null && !Array.isArray(art.personnages_concernes)) {
    erreurs.push(`article (${art.id}) : personnages_concernes doit être un tableau`);
  }
  if (art.interview_suggeree != null && typeof art.interview_suggeree !== 'boolean') {
    erreurs.push(`article (${art.id}) : interview_suggeree doit être un booléen`);
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

// "Journée calme" élargie (chantier refonte, 4 septembre 2026, arbitrage validé) : une Une "calme"
// n'est légitime QUE si le paquet FACTS est entièrement vide, quelle que soit la catégorie
// (politique, sport, économie, société...) -- plus seulement en l'absence de matière PJ. Les
// PUBLIC_STATEMENTS ne comptent volontairement PAS ici : leur intérêt journalistique reste un
// jugement de l'IA (règle 5 du cahier des charges), jamais une obligation déterministe.
function hasAnyExploitableFact(aiInput) {
  return (aiInput.FACTS || []).length > 0;
}

const PRIORITES_REPORT_VALIDES = ['chaude', 'differable'];

function validerEdition(reponseTexte, aiInput) {
  const erreurs = [];
  let json;
  try {
    json = JSON.parse(reponseTexte);
  } catch (e) {
    return { valide: false, erreurs: ['JSON invalide : ' + e.message] };
  }
  if (!json || typeof json !== 'object') return { valide: false, erreurs: ['Réponse JSON racine invalide'] };

  const { une, articles, sujets_differes } = json;
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

  // une.sujets : 1 a 2 elements (remplace titre_principal/chapeau/article_principal_ref).
  if (!Array.isArray(une.sujets) || une.sujets.length === 0) {
    erreurs.push('une.sujets doit être un tableau non vide');
  } else if (une.sujets.length > 2) {
    erreurs.push(`une.sujets : maximum 2 sujets autorisés, ${une.sujets.length} reçus`);
  } else {
    une.sujets.forEach((suj, i) => {
      if (!suj || typeof suj !== 'object') { erreurs.push(`une.sujets[${i}] invalide`); return; }
      if (typeof suj.titre !== 'string' || !suj.titre) erreurs.push(`une.sujets[${i}].titre manquant`);
      if (typeof suj.chapeau !== 'string') erreurs.push(`une.sujets[${i}].chapeau manquant`);
      if (suj.article_ref != null) {
        if (typeof suj.article_ref !== 'string') {
          erreurs.push(`une.sujets[${i}].article_ref doit être une chaîne ou null`);
        } else if (!idsVus.has(suj.article_ref)) {
          erreurs.push(`une.sujets[${i}].article_ref inconnu "${suj.article_ref}"`);
        } else if (articleEstEtranger(articlesParId[suj.article_ref], paysCible, index)) {
          erreurs.push(`une.sujets[${i}].article_ref "${suj.article_ref}" repose exclusivement sur une source étrangère`);
        }
      }
    });
  }

  const sujetsValides = Array.isArray(une.sujets) ? une.sujets : [];
  const sujetsAvecArticle = sujetsValides.filter(s => s && s.article_ref);

  // "Journée calme" élargie : tous les sujets à article_ref:null n'est légitime QUE si FACTS est
  // entièrement vide (voir hasAnyExploitableFact) -- plus seulement en l'absence de matière PJ.
  if (sujetsAvecArticle.length === 0 && hasAnyExploitableFact(aiInput)) {
    erreurs.push('une.sujets : aucun sujet ne s\'ancre sur un article alors que le paquet FACTS contient au moins un fait exploitable ("journée calme" non autorisée ici)');
  }

  // Règle de Une PJ — vérification déterministe du principe "les personnages font l'actualité".
  // Adaptée aux sujets multiples (4 septembre 2026) : AU MOINS UN sujet doit s'ancrer sur du PJ
  // dès que de la matière PJ existe -- pas nécessairement tous, un deuxième sujet partagé peut
  // rester non-PJ.
  if (hasPJMaterial(aiInput)) {
    const ancreSurPJ = sujetsAvecArticle.some(s => {
      const art = articlesParId[s.article_ref];
      return !!art && Array.isArray(art.source_ids) && art.source_ids.some(sid => index[sid] && index[sid].estPJ);
    });
    if (!ancreSurPJ) {
      erreurs.push('une.sujets : le paquet contient de la matière PJ exploitable mais aucun sujet de Une ne s\'ancre sur une source estPJ:true (règle de Une obligatoire)');
    }
  }

  // une.appels (renomme de "accroches", plafonne a 3).
  if (!Array.isArray(une.appels)) {
    erreurs.push('une.appels doit être un tableau');
  } else if (une.appels.length > 3) {
    erreurs.push(`une.appels : maximum 3 appels autorisés, ${une.appels.length} reçus`);
  } else {
    une.appels.forEach((acc, i) => {
      if (!acc || typeof acc.texte !== 'string' || typeof acc.article_ref !== 'string') { erreurs.push(`une.appels[${i}] invalide`); return; }
      if (!idsVus.has(acc.article_ref)) { erreurs.push(`une.appels[${i}] : article_ref inconnu "${acc.article_ref}"`); return; }
      if (articleEstEtranger(articlesParId[acc.article_ref], paysCible, index)) {
        erreurs.push(`une.appels[${i}] : article_ref "${acc.article_ref}" repose exclusivement sur une source étrangère`);
      }
    });
  }

  // L'image de Une cite un source_id de FAIT (comme une image d'article), jamais un id d'article :
  // on rassemble donc les source_ids de tous les sujets ET de chaque appel, pas leurs ids.
  const sourceIdsAccessiblesUne = [
    ...sujetsAvecArticle.reduce((acc, s) => {
      const art = articlesParId[s.article_ref];
      return art ? acc.concat(art.source_ids) : acc;
    }, []),
    ...((une.appels || []).reduce((acc, a) => {
      const art = a && articlesParId[a.article_ref];
      return art ? acc.concat(art.source_ids) : acc;
    }, []))
  ];
  validerImage(une.image, 'une', sourceIdsAccessiblesUne, index, erreurs);

  // sujets_differes (report editorial, 4 septembre 2026) : optionnel, chaque entree doit referencer
  // un id REEL du paquet envoye a l'IA (jamais un id invente), avec une priorite valide.
  if (sujets_differes != null) {
    if (!Array.isArray(sujets_differes)) {
      erreurs.push('sujets_differes doit être un tableau');
    } else {
      sujets_differes.forEach((sd, i) => {
        if (!sd || typeof sd.source_id !== 'string' || !sd.source_id) { erreurs.push(`sujets_differes[${i}] : source_id manquant`); return; }
        if (!index[sd.source_id]) { erreurs.push(`sujets_differes[${i}] : source_id inconnu "${sd.source_id}"`); return; }
        if (!PRIORITES_REPORT_VALIDES.includes(sd.priorite)) { erreurs.push(`sujets_differes[${i}] : priorite invalide "${sd.priorite}"`); }
      });
    }
  }

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
  (une.sujets || []).forEach(s => s && s.article_ref && cites.add(s.article_ref));
  (une.appels || []).forEach(a => a && a.article_ref && cites.add(a.article_ref));
  return cites;
}

// Types systematiquement ranges en dernière page (arrivées/carnet) quand non cités dans un
// article -- jamais transformes en article par ce code, seul le choix editorial de l'IA (via une
// citation reelle dans articles[]) peut les faire remonter en 2e page/Une (regles par type,
// chantier refonte, 4 septembre 2026).
const TYPES_ARRIVEE = ['arrivee'];
const TYPES_CARNET = ['mariage', 'deces'];

function assemblerDernierePage(paquet, une, articles) {
  const cites = collecterSourceIdsCites(une, articles);

  const indices_economiques = (paquet.INDICATORS || [])
    .filter(i => i.cle.indexOf('stock_') === 0 && i.disponible)
    .map(i => {
      const ressource = i.cle.replace('stock_', '');
      const prix = (paquet.INDICATORS || []).find(p => p.cle === `prix_${ressource}` && p.ville === i.ville);
      return { ressource, ville: i.ville, stock: i.valeur, prix: prix ? prix.valeur : null };
    });

  // Journal des arrivées (chantier refonte, 4 septembre 2026) : jamais "naissance", toujours sa
  // propre rubrique, distincte du carnet -- une arrivee n'est par construction jamais citee dans
  // un article (poids toujours "mineur", voir Lot A), mais le filtre reste explicite par securite.
  const arrivees = (paquet.FACTS || [])
    .filter(f => TYPES_ARRIVEE.includes(f.type) && !cites.has(f.id))
    .map(f => f.resume);

  const carnet = (paquet.FACTS || [])
    .filter(f => TYPES_CARNET.includes(f.type) && !cites.has(f.id))
    .map(f => f.resume);

  const chiens_ecrases = (paquet.FACTS || [])
    .filter(f => !cites.has(f.id) && !TYPES_ARRIVEE.includes(f.type) && !TYPES_CARNET.includes(f.type) && f.domaine !== 'economie')
    .filter(f => f.poids === 'mineur' || f.poids === 'secondaire')
    .slice(0, LIMITE_CHIENS_ECRASES)
    .map(f => f.resume);

  // Petites annonces (31 aout 2026) : lecture pure de paquet.PETITES_ANNONCES (Lot A,
  // collecterPetitesAnnoncesActives) -- jamais vues par l'IA, jamais reformulées, aucune
  // invention possible.
  const petites_annonces = (paquet.PETITES_ANNONCES || []).map(a =>
    (a.categorie ? `[${a.categorie}] ` : '') + a.texte + (a.ville ? ` — ${a.ville}` : '')
  );

  return { indices_economiques, arrivees, carnet, chiens_ecrases, petites_annonces };
}

// Refonte "4 dernieres interviews" (4 septembre 2026) : recalculee a CHAQUE generation par lecture
// directe de interviews_jodie (jamais reportee depuis une edition precedente ni depuis une file --
// voir api/journal-interview.js, qui persiste desormais article_titre/article_texte/publie_le sur
// la ligne elle-meme). Remplace l'ancienne page a interview unique (paquet.INTERVIEW_JODIE, systeme
// "Un jour, un portrait" par mail -- laisse intact, continue de publier sur le forum "presse", mais
// ne double plus jamais dans le Journal a partir de cette refonte).
const MAX_INTERVIEWS_AVANT_DERNIERE_PAGE = 4;

async function assemblerAvantDernierePage(pays) {
  if (!SUPABASE_SERVICE_ROLE) return { interviews: [] };
  const rows = await sbGet(
    'interviews_jodie',
    `country=eq.${encodeURIComponent(pays)}&publie=eq.true&article_texte=not.is.null&order=publie_le.desc.nullslast&limit=${MAX_INTERVIEWS_AVANT_DERNIERE_PAGE}`,
    SB_HEADERS_SERVICE
  ).catch(() => []);
  if (!rows || rows.length === 0) return { interviews: [] };
  const noms = [...new Set(rows.map(r => r.personnage))];
  const persos = await sbGet('personnages', `name=in.(${noms.map(encodeURIComponent).join(',')})&select=name,photo_url`).catch(() => []);
  const photoParNom = {};
  (persos || []).forEach(p => { photoParNom[p.name] = p.photo_url || null; });
  const interviews = rows.map(r => ({
    nom: r.personnage, titre: r.article_titre || null, texte: r.article_texte,
    photo_url: photoParNom[r.personnage] || null, publie_le: r.publie_le || null
  }));
  return { interviews };
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

// =====================
// REPORT ÉDITORIAL (chantier refonte, 4 septembre 2026) — réutilise journal_articles_en_attente
// avec origine='report_ia' : stocke un SNAPSHOT du FAIT (fait_json), jamais un article pré-rédigé
// -- réinjecté tel quel dans le paquet d'une génération ultérieure pour que l'IA écrive un article
// à jour ce jour-là, jamais un texte figé republié tel quel plusieurs jours plus tard. Une ligne
// périmée passe à statut='expire', jamais supprimée : aucune perte silencieuse.
// =====================
const JOURS_REPORT = { chaude: 1, differable: 5 };

async function chargerFaitsDifferesEnAttente(pays, maintenant) {
  if (!SUPABASE_SERVICE_ROLE) return [];
  const rows = await sbGet(
    'journal_articles_en_attente',
    `country=eq.${encodeURIComponent(pays)}&origine=eq.report_ia&statut=eq.attente&order=created_at.asc`,
    SB_HEADERS_SERVICE
  );
  const actifs = [];
  const perimes = [];
  (rows || []).forEach(r => {
    if (r.expire_le && new Date(r.expire_le).getTime() <= maintenant.getTime()) { perimes.push(r); return; }
    if (!r.fait_json) return;
    const jours = Math.max(0, Math.round((maintenant.getTime() - new Date(r.created_at).getTime()) / 86400000));
    actifs.push({ ...r.fait_json, report_differe: true, jours_depuis_fait: jours, _report_row_id: r.id });
  });
  if (perimes.length > 0) {
    await Promise.all(perimes.map(r =>
      sbUpdate('journal_articles_en_attente', `id=eq.${encodeURIComponent(r.id)}`, { statut: 'expire' }, SB_HEADERS_SERVICE).catch(() => {})
    ));
  }
  return actifs;
}

// Id deterministe (jamais Date.now()) : re-soumettre le meme fait different (IA qui le re-differe
// un jour de plus) ne cree jamais de doublon, echoue silencieusement sur la contrainte PRIMARY KEY
// (409, deja en file -- comportement attendu, jamais une erreur a traiter).
async function mettreEnAttenteSujetsDifferes(pays, sujetsDifferes, index, maintenant) {
  if (!sujetsDifferes || sujetsDifferes.length === 0 || !SUPABASE_SERVICE_ROLE) return;
  for (const sd of sujetsDifferes) {
    const fait = index[sd.source_id];
    if (!fait) continue;
    const dureeJours = JOURS_REPORT[sd.priorite] || JOURS_REPORT.differable;
    const expireLe = new Date(maintenant.getTime() + dureeJours * 86400000);
    const id = `report-${fait.id}`;
    await sbInsert('journal_articles_en_attente', {
      id, country: pays, rubrique: fait.domaine || 'Suivi',
      titre: sd.raison || fait.resume, texte: fait.resume,
      statut: 'attente', priorite: sd.priorite, origine: 'report_ia',
      expire_le: expireLe.toISOString(), fait_json: fait
    }, SB_HEADERS_SERVICE);
  }
}

async function marquerReportsIntegres(faitsDifferes, cites) {
  const aMarquer = (faitsDifferes || []).filter(f => f._report_row_id && cites.has(f.id));
  if (aMarquer.length === 0) return;
  await Promise.all(aMarquer.map(f =>
    sbUpdate('journal_articles_en_attente', `id=eq.${encodeURIComponent(f._report_row_id)}`, { statut: 'integre' }, SB_HEADERS_SERVICE).catch(() => {})
  ));
}

// =====================
// JODIE PROACTIVE (chantier refonte, 4 septembre 2026) — réutilise intégralement l'ordre "Donner
// une interview" existant (aucun nouveau mécanisme joueur) : le cron envoie seulement un mail de
// sollicitation quand un article fraîchement publié porte "interview_suggeree":true pour un PJ.
// Garde-fous anti-spam : cooldown réel (10 jours, même règle que l'ordre manuel), aucune interview
// déjà en cours pour ce PJ, et pas de mail de sollicitation déjà envoyé dans les 3 derniers jours
// réels (évite une relance quotidienne si le joueur ignore Jodie).
// =====================
const JODIE_COOLDOWN_JOURS = 10;
const JODIE_RELANCE_MIN_JOURS = 3;
const JODIE_SUJET_SOLLICITATION = 'Jodie Moitout aimerait vous interviewer';

async function solliciterInterviewsProactives(pays, contenu, index, maintenant) {
  if (!SUPABASE_SERVICE_ROLE) return;
  const candidats = new Set();
  (contenu.articles || []).forEach(art => {
    if (!art || !art.interview_suggeree) return;
    const source = (art.source_ids || []).map(sid => index[sid]).find(s => s && s.estPJ && s.acteur);
    if (source) candidats.add(source.acteur);
  });
  for (const nom of candidats) {
    const derniereRows = await sbGet('interviews_jodie', `personnage=eq.${encodeURIComponent(nom)}&order=created_at.desc&limit=1`, SB_HEADERS_SERVICE).catch(() => []);
    const derniere = derniereRows && derniereRows[0];
    if (derniere && !derniere.publie) continue; // interview deja en cours pour ce PJ
    if (derniere && (maintenant.getTime() - new Date(derniere.created_at).getTime()) < JODIE_COOLDOWN_JOURS * 86400000) continue; // cooldown reel non ecoule

    const seuilRelance = new Date(maintenant.getTime() - JODIE_RELANCE_MIN_JOURS * 86400000).toISOString();
    const relanceRecente = await sbGet('mails',
      `from_player=eq.${encodeURIComponent('Jodie Moitout')}&to_player=eq.${encodeURIComponent(nom)}&subject=eq.${encodeURIComponent(JODIE_SUJET_SOLLICITATION)}&created_at=gt.${encodeURIComponent(seuilRelance)}`,
      SB_HEADERS_SERVICE
    ).catch(() => []);
    if (relanceRecente && relanceRecente.length > 0) continue; // deja sollicite recemment

    await sbInsert('mails', {
      id: 'mail-jodie-' + Date.now() + '-' + Math.floor(Math.random() * 1000000),
      from_player: 'Jodie Moitout', to_player: nom,
      subject: JODIE_SUJET_SOLLICITATION,
      body: "Jodie Moitout de L'Autruche Entravée aimerait vous interviewer suite à l'actualité récente vous concernant. Rendez-vous auprès d'elle pour « Donner une interview » si vous acceptez.",
      time: dateEditionPourPays(pays, maintenant), read: false
    }, SB_HEADERS_SERVICE).catch(() => {});
  }
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

    // Sujets differes des jours precedents : reinjectes tels quels dans FACTS (memes ids, meme
    // forme) pour que l'IA puisse leur ecrire un vrai article aujourd'hui si elle le souhaite --
    // jamais un texte fige republie, toujours une nouvelle redaction a partir du meme fait reel.
    const faitsDifferesEnAttente = await chargerFaitsDifferesEnAttente(pays, maintenant);
    if (faitsDifferesEnAttente.length > 0) paquet.FACTS = [...paquet.FACTS, ...faitsDifferesEnAttente];

    const dejaCouvert = await chargerDigestDejaCouvert(pays, dateEdition);
    const aiInput = construireAiInput(paquet, dateEdition, dejaCouvert);
    // AI_INPUT n'est archive nulle part ici (correctif du 4 septembre 2026) : jamais lu par aucun
    // mecanisme (renderer client, digest anti-repetition, validation) -- confirme par recherche
    // exhaustive avant suppression -- c'etait un doublon integral de FACTS/PUBLIC_STATEMENTS
    // (avec leurs photo_url), doublant inutilement la taille de chaque ligne journal_editions.
    // paquet.FACTS/PUBLIC_STATEMENTS (avec photo_url intact) restent archives normalement ci-dessous
    // pour le rendu client (construireIndexFaitsJournal) et l'anti-repetition (chargerDigestDejaCouvert).
    const faitsSourcesArchive = { ...paquet };

    const systemPrompt = construirePromptSysteme(pays, dateEdition, hasPJMaterial(aiInput));
    const appel = await appelAnthropic(systemPrompt, retirerPhotosPourAppelIA(aiInput), ANTHROPIC_TIMEOUT_MS);

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
    const avant_derniere_page = await assemblerAvantDernierePage(pays);

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

    // Report editorial : nouveaux sujets differes mis en file, anciens sujets differes desormais
    // cites dans un article marques integres (jamais avant la publication reussie, meme doctrine
    // que les articles Jodie ci-dessus).
    const index = indexerAiInput(aiInput);
    await mettreEnAttenteSujetsDifferes(pays, contenu.sujets_differes, index, maintenant);
    const citesFinal = collecterSourceIdsCites(contenu.une, contenu.articles);
    await marquerReportsIntegres(faitsDifferesEnAttente, citesFinal);

    // Best-effort, jamais bloquant pour la publication elle-meme : une sollicitation Jodie ratee
    // ne doit jamais faire echouer une edition par ailleurs valide et deja publiee.
    await solliciterInterviewsProactives(pays, contenu, index, maintenant).catch(() => {});

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
  hasAnyExploitableFact,
  articleEstEtranger,
  assemblerDernierePage,
  assemblerAvantDernierePage,
  collecterSourceIdsCites,
  chargerDigestDejaCouvert,
  chargerFaitsDifferesEnAttente,
  mettreEnAttenteSujetsDifferes,
  marquerReportsIntegres,
  solliciterInterviewsProactives,
  appelAnthropic
};
