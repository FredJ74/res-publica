// =====================
// API VERCEL — MEMOIRE DES RENSEIGNEMENTS CONNUS (Phase 1, 22 aout 2026)
// =====================
// renseignements_connus est volontairement inaccessible au role anon (RLS active, aucune
// policy -- voir migration_renseignements_connus.sql, execute en production le 22 aout 2026,
// confirme par un test direct : SELECT anon -> 200 [] ; INSERT anon -> 401 42501 "new row
// violates row-level security policy"). PJ et PNJ (ex. escorts de l'agence Roxanne Velours)
// n'ont pas tous de session propre -- seul un endpoint serveur, avec SUPABASE_SERVICE_ROLE_KEY
// (contourne RLS par nature, jamais exposee au client), peut lire/ecrire cette table. Meme
// patron que api/upload-org-avatar.js.
//
// Limite assumee (deja documentee dans upload-org-avatar.js et dans l'audit de securite dedie
// a ce chantier) : aucune authentification joueur reelle n'existe dans ce projet -- titulaire/
// source restent des declarations du client, non verifiees cryptographiquement. Ce que cet
// endpoint garantit reellement : la lecture/ecriture de renseignements_connus ne peut plus se
// faire par un appel direct trivial (SELECT * via la cle anon publique copiee du bundle JS).
// Refonte generale de l'authentification explicitement HORS PERIMETRE de ce lot.
//
// Phase 1 : UNE SEULE operation exposee -- 'enregistrer'. 'lister' et 'reactiver' ont ete
// retirees (revue de securite du 22 aout 2026, avant tout commit) : ce projet n'a AUCUNE
// authentification permettant de verifier que l'appelant est reellement le "titulaire" qu'il
// declare. Un endpoint 'lister(titulaire)' accessible depuis le navigateur aurait recree,
// via service_role, exactement le SELECT arbitraire que RLS etait cense empecher -- CORS ne
// protege en rien contre un appel direct curl/Postman. Meme raisonnement pour 'reactiver',
// qui aurait permis de designer arbitrairement une ligne appartenant a un autre titulaire.
// Elles reviendront dans un lot ulterieur, une fois un mecanisme de controle d'acces reel
// defini (hors perimetre de ce lot).
//
// 'enregistrer' reste seule exposee car elle ne permet AUCUNE lecture ni modification d'une
// ligne existante : id genere ici (jamais accepte du client), operation INSERT uniquement
// (aucun GET/PATCH dans ce fichier), la reponse ne contient que la ligne qui vient d'etre
// creee par CET appel -- aucun moyen de recuperer une ligne appartenant a quelqu'un d'autre
// via cette action. Limite globale assumee et non traitee ici (chantier securite separe) :
// sans authentification, un appelant determine peut toujours forger une ecriture au nom d'un
// titulaire arbitraire -- mais il ne peut RIEN lire en retour qu'il n'a pas lui-meme ecrit a
// l'instant, ce qui est l'objectif minimal de ce lot.
//
// id/jour_derniere_reactivation/jour_expiration sont TOUJOURS calcules ici, jamais acceptes
// du client (jour_expiration manipulable donnerait un souvenir immortel ou deja perime a
// volonte). DUREE_MEMOIRE_JOURS = 90 : seule valeur reellement validee par le game design
// (audit dedie, ~90 jours REELS, state.day avance de 1 par jour reel).
//
// Phase 2 (22 aout 2026) : ajoute UNE operation metier supplementaire, 'tirer_confidence_escort'
// -- PAS un 'lister' generique reintroduit par la bande. Difference essentielle : la liste des
// renseignements eligibles du client est chargee ICI, cote serveur, pour executer le tirage
// pondere, mais n'est JAMAIS renvoyee a l'appelant HTTP -- la reponse ne contient au maximum
// que {confidenceObtenue:true|false}, jamais le contenu tire ni aucune metadonnee dessus (pas
// meme la categorie). Consequence directe : meme un appelant qui forge client/escort/chaEscort
// ne peut RIEN lire en retour au-dela d'un booleen -- il peut au pire forcer une ECRITURE
// (limite globale deja acceptee ailleurs dans ce projet, non un nouveau probleme), jamais une
// LECTURE. Le roll (Math.random()) est TOUJOURS execute ici. Correctif du 22 aout 2026 (revue
// avant GO) : le TAUX COMPLET est desormais calcule ici, jamais accepte du client. CHA_client/
// pays/ville/jour sont lus directement dans personnages (colonnes stats/country/current_city/
// day, jamais dans le corps de la requete) ; la piete passe par indices_villes (Republia) avec
// repli neutre pour les autres empires (voir tirerConfidenceEscort). Seul chaEscort reste
// transmis par le client -- aucune source serveur pour les stats des PNJ (escorts sans ligne
// personnages, PNJ_STATS_PAR_JOB/PNJ_STATS_NOMMES vivent uniquement dans data.js, cote client,
// jamais charge par cette fonction Vercel) ; c'est une donnee PUBLIQUE et non secrete (visible
// de tous dans le bundle JS), et le taux final reste de toute facon reborne [5,90] quelle que
// soit la valeur recue -- dupliquer ici la table PNJ_STATS_PAR_JOB introduirait une deuxieme
// source de verite pour une constante de design (risque de derive silencieuse si data.js
// change), sans reduire le plafond de securite deja garanti par le bornage final.
//
// Phase 3 (22 aout 2026) : ajoute 'secret_contre_secret' -- echange VOLONTAIRE, explicite
// (bouton dedie, jamais une ecoute automatique des dialogues). Le PJ declare librement un
// "secret" en texte libre ; l'IA (Anthropic, meme cle ANTHROPIC_API_KEY qu'api/chat.js, appel
// direct depuis ce fichier -- jamais via api/chat.js, dont l'allowlist de payload n'est pas
// concue pour une instruction d'extraction structuree) sert UNIQUEMENT a juger si la
// declaration est exploitable et a l'extraire en JSON strict -- jamais a inventer un
// evenement, jamais a en verifier la veracite. fait_objectif_ref reste TOUJOURS null pour ce
// qu'un PJ declare de cette facon (regle de design validee : une declaration libre n'est
// jamais une preuve). Le jugement de validite (l'IA a-t-elle vraiment trouve un renseignement
// exploitable) est TOUJOURS fait ici, jamais cote client -- sinon un appelant pourrait forcer
// la contrepartie en pretendant simplement "valide:true" sans jamais appeler l'IA.
//
// Reponse : {ok, declarationValide, contrepartie}. contrepartie contient le TEXTE du
// renseignement rendu par l'escort (decision produit du 22 aout 2026 : contrairement a
// tirer_confidence_escort, cet echange est volontaire et "paye" par le PJ avec son propre
// secret -- le reveler narrativement est le coeur du gameplay, pas une fuite). Reste borne :
// jamais la liste complete de la memoire de l'escort, un seul element precis resultant de CET
// echange precis, jamais consultable a nouveau ensuite.
//
// Phase 4 (22 aout 2026) : ajoute 'interroger_pnj_sujet' -- interrogatoire cible d'un PNJ par
// un enqueteur habilite (commissaire/juge). Mecanique ENTIEREMENT DISTINCTE de "Interroger un
// detenu" (data.js:4314, gain d'INF, commissariat) et de la torture du QHS (appliquerSentence
// 'torture', sanction judiciaire, juge) -- ni l'une ni l'autre n'est touchee par ce fichier.
//
// Ciblage du sujet : l'IA ne sert QUE a selectionner, parmi les renseignements REELLEMENT
// presents dans la memoire du PNJ (charges ici, jamais renvoyes au navigateur), les indices
// pertinents pour le sujet libre saisi par l'enqueteur -- jamais a inventer un renseignement,
// jamais a consulter une autre source. Si la liste retournee est vide (aucun renseignement
// pertinent), c'est l'IGNORANCE du PNJ, AVANT tout jet -- pas d'echec de jet a proprement
// parler. Le jet (40 + 3*(CHA_enqueteur - CHA_pnj), borne [5,90], AUCUN modificateur de piete)
// n'intervient qu'une fois qu'au moins un renseignement pertinent existe reellement. Reponse :
// {ok, statut:'ignorance'|'refus'|'revelation', revelation}.
//
// Revision du 22 aout 2026 (revue de securite, avant tout commit) : DEUX failles fermees.
// (1) Le poste de l'enqueteur etait verifie cote CLIENT uniquement -- un appel direct pouvait
// se declarer commissaire/juge et recevoir le contenu reel d'un renseignement. Le poste est
// desormais relu ICI depuis personnages.poste (jamais depuis le corps de la requete) ; si ce
// n'est ni 'commissaire' ni 'juge', aucun souvenir du PNJ n'est meme charge. (2) chaPnj etait
// transmis par le client -- un appelant pouvait envoyer systematiquement la valeur la plus
// favorable (le terme est soustractif dans la formule) pour maximiser artificiellement son
// taux. Le client ne fixe plus cette valeur : voir CHA_PNJ_NEUTRE ci-dessous pour le compromis
// retenu. CHA_enqueteur reste lu depuis personnages (jamais du corps de la requete, inchange).
//
// Phase 5B (22 aout 2026) : ajoute 'enregistrer_evenement_escort' -- ecrit UN evenement
// commercial reel (embauche ou prestation) dans escort_evenements_commerciaux (RLS activee,
// aucune policy anon -- meme migration/doctrine que renseignements_connus, execute
// manuellement en production). Aucune consommation branchee dans ce lot (ni Secret contre
// secret, ni interrogatoire) -- uniquement l'ecriture.
//
// jour est TOUJOURS lu depuis personnages.day (jamais du corps de la requete), meme principe
// que le reste de ce fichier. id/jour_expiration TOUJOURS calcules ici. Limite assumee et
// documentee (aucune authentification par personnage dans ce projet, deja documentee
// partout ailleurs dans ce fichier) : "client"/"escort"/"type_evenement" restent des
// declarations non verifiees de l'appelant -- ce que cet appel garantit reellement, c'est que
// le jour utilise est le jour REEL persiste de ce personnage, jamais un jour arbitraire.
//
// Verification volontairement NON ajoutee : une correlation avec personnages.escort_active
// (le client a-t-il reellement cet escort dans son groupe ?) a ete envisagee puis ecartee --
// son ecriture n'est pas garantie synchrone au moment de cet appel (l'evenement 'embauche' se
// produit dans la MEME action cote client que la mise a jour d'escort_active elle-meme, sans
// sauvegarde forcee entre les deux) : une telle verification risquerait de rejeter a tort des
// evenements pourtant reels, plutot que d'apporter une securite fiable. Limite acceptee, dans
// la meme famille que les autres limites deja documentees de ce chantier (ex. chaEscort en
// Phase 2) -- aucune refonte d'authentification, comme demande.

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://jxpwoosmmhohoihxpbuc.supabase.co';
const SUPABASE_SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY || null;
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY || null;

const TABLE = 'renseignements_connus';
const TABLE_EVENEMENTS_ESCORT = 'escort_evenements_commerciaux';
const DUREE_MEMOIRE_JOURS = 90;

const MODES_ACQUISITION = [
  'action_personnelle', 'observation', 'document_consulte', 'confidence', 'transmission',
  'interrogatoire'
];

// Meme taxonomie que la table (categorie n'a pas de CHECK, voir migration_renseignements_
// connus.sql) -- utilisee ici uniquement pour valider/reborner la sortie de l'IA, jamais pour
// contraindre la colonne elle-meme.
const CATEGORIES_CONNUES = [
  'acte_illegal', 'achat_arme', 'escort_frequentation', 'recrutement_pnj',
  'achat_terrain', 'achat_commerce', 'gros_achat', 'autre'
];

const ALLOWED_ORIGIN = 'https://res-publica.vercel.app';

function serviceHeaders() {
  return {
    'Content-Type': 'application/json',
    'apikey': SUPABASE_SERVICE_ROLE,
    'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE}`
  };
}

function texteValide(v, maxLen) {
  return typeof v === 'string' && v.trim().length > 0 && v.length <= maxLen;
}

function jourValide(v) {
  return Number.isInteger(v) && v >= 1 && v <= 100000;
}

async function enregistrer(body, res) {
  const { titulaire, contenu, cible, categorie, source, mode_acquisition, fait_objectif_ref, jour_acquisition } = body;
  if (!texteValide(titulaire, 200) || !texteValide(contenu, 2000) || !texteValide(source, 200)) {
    return res.status(400).json({ error: 'Champs obligatoires invalides.' });
  }
  if (cible !== undefined && cible !== null && !texteValide(cible, 200)) {
    return res.status(400).json({ error: 'cible invalide.' });
  }
  if (!texteValide(categorie, 100)) {
    return res.status(400).json({ error: 'categorie invalide.' });
  }
  if (!MODES_ACQUISITION.includes(mode_acquisition)) {
    return res.status(400).json({ error: 'mode_acquisition invalide.' });
  }
  if (fait_objectif_ref !== undefined && fait_objectif_ref !== null && !texteValide(fait_objectif_ref, 200)) {
    return res.status(400).json({ error: 'fait_objectif_ref invalide.' });
  }
  if (!jourValide(jour_acquisition)) {
    return res.status(400).json({ error: 'jour_acquisition invalide.' });
  }

  // id genere ici, jamais fourni par le client -- meme principe que le chemin Storage de
  // upload-org-avatar.js (namespace serveur, aucune collision possible).
  const row = {
    id: 'rc_' + Date.now() + '_' + Math.floor(Math.random() * 1000000),
    titulaire,
    contenu,
    cible: cible || null,
    categorie,
    source,
    mode_acquisition,
    fait_objectif_ref: fait_objectif_ref || null,
    jour_acquisition,
    jour_derniere_reactivation: jour_acquisition,
    jour_expiration: jour_acquisition + DUREE_MEMOIRE_JOURS
  };

  const r = await fetch(`${SUPABASE_URL}/rest/v1/${TABLE}`, {
    method: 'POST',
    headers: { ...serviceHeaders(), 'Prefer': 'return=representation' },
    body: JSON.stringify(row)
  }).catch(() => null);
  if (!r || !r.ok) return res.status(502).json({ error: "Le renseignement n'a pas pu être enregistré." });
  const rows = await r.json();
  return res.status(200).json({ ok: true, id: row.id, row: rows?.[0] || row });
}

// Poids d'importance par categorie -- deterministe, pas une estimation IA. Table volontairement
// courte (8 valeurs), coherente avec les categories deja cadrees par le game design (audit
// dedie). Toute categorie non listee (taxonomie ouverte, voir migration_renseignements_
// connus.sql -- "categorie" n'a pas de CHECK) retombe sur le poids minimal 'autre', jamais 0.
const POIDS_IMPORTANCE_CATEGORIE = {
  acte_illegal: 5,
  escort_frequentation: 4,
  achat_arme: 3,
  achat_terrain: 3,
  achat_commerce: 3,
  gros_achat: 3,
  recrutement_pnj: 2,
  autre: 1
};
function poidsImportance(categorie) {
  return POIDS_IMPORTANCE_CATEGORIE[categorie] ?? POIDS_IMPORTANCE_CATEGORIE.autre;
}

// Poids de recence -- lineaire sur jour_derniere_reactivation, jamais nul meme au bord de
// l'expiration (0.2 minimum a age=DUREE_MEMOIRE_JOURS, 1.0 a age=0) : "un renseignement encore
// vivant dans les 90 jours ne doit jamais avoir un poids nul" (regle de design validee).
function poidsRecence(jourDerniereReactivation, jourActuel) {
  const age = Math.max(0, Math.min(DUREE_MEMOIRE_JOURS, jourActuel - (jourDerniereReactivation || jourActuel)));
  return 1 - 0.8 * (age / DUREE_MEMOIRE_JOURS);
}

async function tirerConfidenceEscort(body, res) {
  const { client, escort, chaEscort } = body;
  if (!texteValide(client, 200) || !texteValide(escort, 200)) {
    return res.status(400).json({ error: 'Paramètres invalides.' });
  }
  // Borne large mais reelle (echelle CHA confirmee 1-20, voir audit dedie) -- valeur publique
  // et non secrete (data.js), simple garde-fou contre NaN/Infinity/valeurs absurdes.
  const chaEscortSur = Math.max(1, Math.min(20, Number.isFinite(chaEscort) ? chaEscort : 10));

  // Etat REELLEMENT persiste du client, lu ici, jamais accepte du corps de la requete --
  // seul le nom "client" reste une declaration non authentifiee (limite globale acceptee,
  // voir en-tete de fichier). Tout ce qui suit vient de personnages, jamais du client HTTP.
  const rPerso = await fetch(
    `${SUPABASE_URL}/rest/v1/personnages?name=eq.${encodeURIComponent(client)}&select=stats,country,current_city,day`,
    { headers: serviceHeaders() }
  ).catch(() => null);
  if (!rPerso || !rPerso.ok) return res.status(200).json({ ok: true, confidenceObtenue: false });
  const lignesPerso = await rPerso.json();
  const perso = Array.isArray(lignesPerso) ? lignesPerso[0] : null;
  if (!perso) return res.status(200).json({ ok: true, confidenceObtenue: false });

  const chaClient = (perso.stats && Number.isFinite(perso.stats.CHA)) ? perso.stats.CHA : 8;
  const pays = perso.country || 'republic';
  const ville = perso.current_city || 'capitale';
  const jourActuel = Number.isInteger(perso.day) ? perso.day : 1;

  // Piete : Republia -> indices_villes (Supabase, source reelle, meme table que le client
  // utilise deja via getIndiceVille). Autres empires -> INDICES_NATIONAUX n'existe que cote
  // client (data.js, constante statique) -- repli neutre (40, meme valeur par defaut que
  // INDICE_VILLE_DEFAUT.piete cote client) plutot que dupliquer cette table ici. Le Bar/
  // Roxanne Velours n'existant aujourd'hui qu'a Republia, ce repli n'affecte aucun cas reel.
  let pieteVille = 40;
  if (pays === 'republic') {
    const rIndices = await fetch(
      `${SUPABASE_URL}/rest/v1/indices_villes?id=eq.${encodeURIComponent('republic_' + ville)}&select=data`,
      { headers: serviceHeaders() }
    ).catch(() => null);
    if (rIndices && rIndices.ok) {
      const lignesIndices = await rIndices.json();
      const d = Array.isArray(lignesIndices) && lignesIndices[0] ? lignesIndices[0].data : null;
      if (d && Number.isFinite(d.piete)) pieteVille = d.piete;
    }
  }

  const modPiete = Math.max(-5, Math.min(5, (pieteVille - 50) / 10));
  const taux = Math.max(5, Math.min(90, Math.round(40 + 3 * (chaEscortSur - chaClient) + modPiete)));

  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll > taux) {
    return res.status(200).json({ ok: true, confidenceObtenue: false });
  }

  // Renseignements ENCORE valides du client -- charges ICI uniquement pour le tirage, jamais
  // renvoyes a l'appelant (voir commentaire d'en-tete du fichier). jourActuel vient de
  // personnages.day (ci-dessus), jamais du corps de la requete.
  const filtre = `titulaire=eq.${encodeURIComponent(client)}&jour_expiration=gte.${jourActuel}&limit=200`;
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${TABLE}?${filtre}`, { headers: serviceHeaders() }).catch(() => null);
  if (!r || !r.ok) return res.status(200).json({ ok: true, confidenceObtenue: false });
  const eligibles = await r.json();
  if (!Array.isArray(eligibles) || eligibles.length === 0) {
    return res.status(200).json({ ok: true, confidenceObtenue: false });
  }

  const poids = eligibles.map(row => poidsRecence(row.jour_derniere_reactivation, jourActuel) * poidsImportance(row.categorie));
  const total = poids.reduce((s, p) => s + p, 0);
  let tirage = Math.random() * total;
  let choisi = eligibles[eligibles.length - 1];
  for (let i = 0; i < eligibles.length; i++) {
    tirage -= poids[i];
    if (tirage <= 0) { choisi = eligibles[i]; break; }
  }

  // Provenance : Rita ne memorise jamais "Bernard a achete une arme" comme verite objective --
  // uniquement "<client> a confie : « ... »", source = client (transmetteur immediat), jamais
  // la chaine complete si le client lui-meme le tenait d'un tiers (regle de design validee,
  // meme doctrine que le reste de ce chantier). fait_objectif_ref est copiee telle quelle
  // (simple pointeur optionnel deja non-probant, voir migration) -- jamais transformee en
  // preuve pour l'escort.
  const nouvelleLigne = {
    id: 'rc_' + Date.now() + '_' + Math.floor(Math.random() * 1000000),
    titulaire: escort,
    contenu: client + ' a confié : « ' + choisi.contenu + ' »',
    cible: choisi.cible || null,
    categorie: choisi.categorie,
    source: client,
    mode_acquisition: 'confidence',
    fait_objectif_ref: choisi.fait_objectif_ref || null,
    jour_acquisition: jourActuel,
    jour_derniere_reactivation: jourActuel,
    jour_expiration: jourActuel + DUREE_MEMOIRE_JOURS
  };

  const rInsert = await fetch(`${SUPABASE_URL}/rest/v1/${TABLE}`, {
    method: 'POST',
    headers: { ...serviceHeaders(), 'Prefer': 'return=representation' },
    body: JSON.stringify(nouvelleLigne)
  }).catch(() => null);
  if (!rInsert || !rInsert.ok) return res.status(200).json({ ok: true, confidenceObtenue: false });

  return res.status(200).json({ ok: true, confidenceObtenue: true });
}

// Extraction IA d'une declaration libre (Phase 3) -- UNIQUEMENT structuration, jamais
// invention ni verification de verite. Retourne null en cas d'echec technique (cle absente,
// appel Anthropic en echec, JSON non parsable) -- traite comme "non valide" par l'appelant,
// jamais comme une erreur bloquante (echec silencieux, meme doctrine que le reste du fichier).
async function extraireDeclarationSecret(declarationBrute) {
  if (!ANTHROPIC_API_KEY) return null;

  const instructions = 'Tu analyses une declaration libre faite par un personnage de jeu de role a une autre personne, dans le cadre d\'un echange volontaire de confidences ("secret contre secret"). Determine si cette declaration contient une information exploitable : un fait ou evenement concret que ce personnage affirme avoir vecu, commis ou observe (ex. acte illegal, achat d\'arme, frequentation d\'un escort, recrutement d\'un employe, achat de terrain ou de commerce, gros achat economique, ou tout autre evenement comparable). Une banalite, un refus, une phrase vide de sens ou une simple politesse ne compte PAS comme une information exploitable.\n\nIMPORTANT : ne juge JAMAIS si la declaration est vraie ou fausse. Contente-toi d\'extraire ce qui est AFFIRME, tel quel, meme si cela te semble improbable ou invente -- ce n\'est jamais a toi de verifier.\n\nReponds UNIQUEMENT avec un objet JSON strict, sans aucun texte ni markdown autour, au format exact :\n{"valide": true ou false, "resume": "resume concis de l\'affirmation, une phrase, a la troisieme personne, sans dire qui l\'affirme" ou null, "cible": "nom de la personne concernee si mentionnee" ou null, "categorie": "une valeur EXACTEMENT parmi acte_illegal, achat_arme, escort_frequentation, recrutement_pnj, achat_terrain, achat_commerce, gros_achat, autre" ou null}\n\nSi valide est false, resume/cible/categorie doivent etre null.';
  const promptComplet = instructions + '\n\nDeclaration du personnage :\n' + declarationBrute;

  const resp = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-api-key': ANTHROPIC_API_KEY, 'anthropic-version': '2023-06-01' },
    body: JSON.stringify({ model: 'claude-haiku-4-5-20251001', max_tokens: 200, messages: [{ role: 'user', content: promptComplet }] })
  }).catch(() => null);
  if (!resp || !resp.ok) return null;

  const data = await resp.json().catch(() => null);
  let texte = data?.content?.[0]?.text?.trim() || '';
  // Retire d'eventuelles balises markdown de bloc de code, si le modele en ajoute malgre la
  // consigne "sans markdown autour".
  texte = texte.replace(/^```json\s*/i, '').replace(/^```\s*/, '').replace(/```\s*$/, '').trim();

  let parsed;
  try { parsed = JSON.parse(texte); } catch (e) { return null; }
  if (!parsed || typeof parsed !== 'object') return null;

  if (parsed.valide !== true) return { valide: false, resume: null, cible: null, categorie: null };
  if (typeof parsed.resume !== 'string' || parsed.resume.trim().length === 0) {
    return { valide: false, resume: null, cible: null, categorie: null };
  }

  const categorie = CATEGORIES_CONNUES.includes(parsed.categorie) ? parsed.categorie : 'autre';
  const cible = (typeof parsed.cible === 'string' && parsed.cible.trim().length > 0) ? parsed.cible.trim().slice(0, 200) : null;
  return { valide: true, resume: parsed.resume.trim().slice(0, 2000), cible, categorie };
}

async function secretContreSecret(body, res) {
  const { client, escort, declaration } = body;
  if (!texteValide(client, 200) || !texteValide(escort, 200) || !texteValide(declaration, 1000)) {
    return res.status(400).json({ error: 'Paramètres invalides.' });
  }

  // jourActuel lu depuis personnages.day, jamais accepte du corps de la requete -- meme
  // principe que tirer_confidence_escort.
  const rPerso = await fetch(
    `${SUPABASE_URL}/rest/v1/personnages?name=eq.${encodeURIComponent(client)}&select=day`,
    { headers: serviceHeaders() }
  ).catch(() => null);
  if (!rPerso || !rPerso.ok) return res.status(200).json({ ok: true, declarationValide: false, contrepartie: null });
  const lignesPerso = await rPerso.json();
  const perso = Array.isArray(lignesPerso) ? lignesPerso[0] : null;
  if (!perso) return res.status(200).json({ ok: true, declarationValide: false, contrepartie: null });
  const jourActuel = Number.isInteger(perso.day) ? perso.day : 1;

  const extraction = await extraireDeclarationSecret(declaration);
  if (!extraction || !extraction.valide) {
    return res.status(200).json({ ok: true, declarationValide: false, contrepartie: null });
  }

  // Memoire de l'escort : une declaration libre reste une DECLARATION, jamais une verite
  // objective -- fait_objectif_ref TOUJOURS null (regle de design validee). "affirme" marque
  // explicitement le caractere non verifie, distinct de "a confie" (Phase 2, confidence
  // extraite pendant Faire l'amour).
  const ligneEscort = {
    id: 'rc_' + Date.now() + '_' + Math.floor(Math.random() * 1000000),
    titulaire: escort,
    contenu: client + ' affirme : « ' + extraction.resume + ' »',
    cible: extraction.cible,
    categorie: extraction.categorie,
    source: client,
    mode_acquisition: 'transmission',
    fait_objectif_ref: null,
    jour_acquisition: jourActuel,
    jour_derniere_reactivation: jourActuel,
    jour_expiration: jourActuel + DUREE_MEMOIRE_JOURS
  };
  const rEcritureEscort = await fetch(`${SUPABASE_URL}/rest/v1/${TABLE}`, {
    method: 'POST',
    headers: { ...serviceHeaders(), 'Prefer': 'return=representation' },
    body: JSON.stringify(ligneEscort)
  }).catch(() => null);
  if (!rEcritureEscort || !rEcritureEscort.ok) {
    return res.status(200).json({ ok: true, declarationValide: false, contrepartie: null });
  }

  // Contrepartie : tirage pondere dans la memoire REELLE de l'escort, memes fonctions que
  // tirer_confidence_escort. Exclut explicitement la ligne qui vient d'etre creee (le secret
  // du PJ lui-meme) -- elle ne doit jamais pouvoir se retourner comme contrepartie au meme
  // echange. Aucune liste renvoyee au navigateur, un seul element si disponible.
  const filtreEscort = `titulaire=eq.${encodeURIComponent(escort)}&jour_expiration=gte.${jourActuel}&limit=200`;
  const rMemoireEscort = await fetch(`${SUPABASE_URL}/rest/v1/${TABLE}?${filtreEscort}`, { headers: serviceHeaders() }).catch(() => null);
  let contrepartieTexte = null;
  if (rMemoireEscort && rMemoireEscort.ok) {
    const eligibles = await rMemoireEscort.json();
    const candidats = Array.isArray(eligibles) ? eligibles.filter(row => row.id !== ligneEscort.id) : [];
    if (candidats.length > 0) {
      const poids = candidats.map(row => poidsRecence(row.jour_derniere_reactivation, jourActuel) * poidsImportance(row.categorie));
      const total = poids.reduce((s, p) => s + p, 0);
      let tirage = Math.random() * total;
      let choisi = candidats[candidats.length - 1];
      for (let i = 0; i < candidats.length; i++) {
        tirage -= poids[i];
        if (tirage <= 0) { choisi = candidats[i]; break; }
      }

      const texteContrepartie = escort + ' a confié : « ' + choisi.contenu + ' »';
      const lignePj = {
        id: 'rc_' + Date.now() + '_' + Math.floor(Math.random() * 1000000),
        titulaire: client,
        contenu: texteContrepartie,
        cible: choisi.cible || null,
        categorie: choisi.categorie,
        source: escort,
        mode_acquisition: 'transmission',
        fait_objectif_ref: choisi.fait_objectif_ref || null,
        jour_acquisition: jourActuel,
        jour_derniere_reactivation: jourActuel,
        jour_expiration: jourActuel + DUREE_MEMOIRE_JOURS
      };
      const rEcriturePj = await fetch(`${SUPABASE_URL}/rest/v1/${TABLE}`, {
        method: 'POST',
        headers: { ...serviceHeaders(), 'Prefer': 'return=representation' },
        body: JSON.stringify(lignePj)
      }).catch(() => null);
      // N'annonce une contrepartie que si elle a reellement ete persistee -- jamais une
      // recompense fictive si l'ecriture echoue.
      if (rEcriturePj && rEcriturePj.ok) contrepartieTexte = texteContrepartie;
    }
  }

  return res.status(200).json({ ok: true, declarationValide: true, contrepartie: contrepartieTexte });
}

// Selection IA des renseignements pertinents (Phase 4) -- role STRICTEMENT limite : choisir
// parmi les index d'une liste FOURNIE, jamais generer ni inventer. Retourne [] en cas d'echec
// technique (cle absente, appel en echec, JSON non parsable) -- traite comme "aucun renseignement
// pertinent" par l'appelant (ignorance), jamais comme une erreur bloquante.
async function selectionnerRenseignementsPertinents(sujet, memoire) {
  if (!ANTHROPIC_API_KEY) return [];
  const candidatsTronques = memoire.slice(0, 50);
  const liste = candidatsTronques
    .map((row, i) => i + ': cible=' + (row.cible || 'aucune') + ' / categorie=' + row.categorie + ' / resume=' + String(row.contenu || '').slice(0, 150))
    .join('\n');

  const instructions = 'Tu dois determiner, parmi une liste de renseignements reellement connus par un personnage, lesquels sont raisonnablement pertinents pour repondre au sujet suivant, pose par un enqueteur. Ne juge JAMAIS la veracite des renseignements. Ne genere ni n\'invente AUCUN nouveau renseignement -- choisis UNIQUEMENT parmi les index fournis ci-dessous. Si aucun n\'est pertinent, renvoie une liste vide.\n\nSujet de l\'enqueteur :\n' + sujet + '\n\nRenseignements connus (index: cible / categorie / resume) :\n' + liste + '\n\nReponds UNIQUEMENT avec un JSON strict, sans texte ni markdown autour, au format exact :\n{"indices_pertinents": [liste d\'entiers parmi les index ci-dessus, vide si aucun]}';

  const resp = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-api-key': ANTHROPIC_API_KEY, 'anthropic-version': '2023-06-01' },
    body: JSON.stringify({ model: 'claude-haiku-4-5-20251001', max_tokens: 200, messages: [{ role: 'user', content: instructions }] })
  }).catch(() => null);
  if (!resp || !resp.ok) return [];

  const data = await resp.json().catch(() => null);
  let texte = data?.content?.[0]?.text?.trim() || '';
  texte = texte.replace(/^```json\s*/i, '').replace(/^```\s*/, '').replace(/```\s*$/, '').trim();

  let parsed;
  try { parsed = JSON.parse(texte); } catch (e) { return []; }
  if (!parsed || !Array.isArray(parsed.indices_pertinents)) return [];
  return parsed.indices_pertinents.filter(i => Number.isInteger(i) && i >= 0 && i < candidatsTronques.length);
}

// Valeur neutre de CHA pour un PNJ generique interroge (Phase 4, revue de securite du 22 aout
// 2026, avant GO) : le client ne fixe plus JAMAIS cette valeur -- un appelant direct pouvait
// sinon envoyer chaPnj:1 systematiquement pour maximiser artificiellement son taux (le terme
// est soustractif dans la formule). Aucune source serveur fiable n'existe pour la CHA reelle
// d'un PNJ generique (PNJ_STATS_PAR_JOB/PNJ_STATS_NOMMES ne vivent que dans data.js, cote
// client) -- dupliquer cette table ici introduirait une seconde source de verite pour une
// donnee de design, pour un gain de precision marginal. Compromis assume et documente : TOUS
// les PNJ interroges via cette action utilisent desormais la meme CHA neutre, reprise telle
// quelle du profil "default" de PNJ_STATS_PAR_JOB (data.js) -- pas une valeur inventee ici,
// la meme valeur de repli deja utilisee par le jeu pour tout PNJ sans job specifique. Un PNJ
// reellement plus charismatique (ex. une escort, CHA 10) n'est plus favorise/defavorise par
// sa vraie CHA dans ce jet precis -- perte de nuance ponctuelle, mais aucune valeur ne peut
// plus etre choisie par l'appelant pour biaiser le taux.
const CHA_PNJ_NEUTRE = 5;

async function interrogerPnjSurSujet(body, res) {
  const { enqueteur, pnj, sujet } = body;
  if (!texteValide(enqueteur, 200) || !texteValide(pnj, 200) || !texteValide(sujet, 300)) {
    return res.status(400).json({ error: 'Paramètres invalides.' });
  }

  // CHA_enqueteur, jourActuel ET poste lus depuis personnages, jamais acceptes du corps de la
  // requete -- meme principe que tirer_confidence_escort/secret_contre_secret. Le poste declare
  // par le client N'EST PLUS jamais fait confiance (revue de securite du 22 aout 2026) : seul
  // le poste REELLEMENT persiste ici fait foi.
  const rPerso = await fetch(
    `${SUPABASE_URL}/rest/v1/personnages?name=eq.${encodeURIComponent(enqueteur)}&select=stats,day,poste`,
    { headers: serviceHeaders() }
  ).catch(() => null);
  if (!rPerso || !rPerso.ok) return res.status(200).json({ ok: true, statut: 'ignorance', revelation: null });
  const lignesPerso = await rPerso.json();
  const perso = Array.isArray(lignesPerso) ? lignesPerso[0] : null;
  if (!perso) return res.status(200).json({ ok: true, statut: 'ignorance', revelation: null });

  // Habilitation : seuls commissaire/juge (V1 validee), verifie exclusivement sur cette
  // lecture fraiche -- si l'appelant n'est pas reellement habilite, aucun souvenir du PNJ
  // n'est meme charge (return immediat, avant toute requete sur renseignements_connus).
  const posteReel = perso.poste?.id;
  if (posteReel !== 'commissaire' && posteReel !== 'juge') {
    return res.status(200).json({ ok: true, statut: 'ignorance', revelation: null });
  }

  const chaEnqueteur = (perso.stats && Number.isFinite(perso.stats.CHA)) ? perso.stats.CHA : 8;
  const jourActuel = Number.isInteger(perso.day) ? perso.day : 1;
  const chaPnjSur = CHA_PNJ_NEUTRE;

  // Memoire ENCORE valide du PNJ -- chargee ici uniquement pour le ciblage/tirage, jamais
  // renvoyee au navigateur (voir en-tete de fichier).
  const filtre = `titulaire=eq.${encodeURIComponent(pnj)}&jour_expiration=gte.${jourActuel}&limit=200`;
  const rMemoire = await fetch(`${SUPABASE_URL}/rest/v1/${TABLE}?${filtre}`, { headers: serviceHeaders() }).catch(() => null);
  if (!rMemoire || !rMemoire.ok) return res.status(200).json({ ok: true, statut: 'ignorance', revelation: null });
  const memoire = await rMemoire.json();
  if (!Array.isArray(memoire) || memoire.length === 0) {
    return res.status(200).json({ ok: true, statut: 'ignorance', revelation: null });
  }

  // Ciblage AVANT le jet : le PNJ n'a rien a "refuser" s'il ne sait rien sur le sujet -- voir
  // en-tete de fichier (ignorance != echec de jet).
  const indicesPertinents = await selectionnerRenseignementsPertinents(sujet, memoire);
  const candidats = indicesPertinents.map(i => memoire[i]).filter(Boolean);
  if (candidats.length === 0) {
    return res.status(200).json({ ok: true, statut: 'ignorance', revelation: null });
  }

  const taux = Math.max(5, Math.min(90, Math.round(40 + 3 * (chaEnqueteur - chaPnjSur))));
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll > taux) {
    return res.status(200).json({ ok: true, statut: 'refus', revelation: null });
  }

  const poids = candidats.map(row => poidsRecence(row.jour_derniere_reactivation, jourActuel) * poidsImportance(row.categorie));
  const total = poids.reduce((s, p) => s + p, 0);
  let tirage = Math.random() * total;
  let choisi = candidats[candidats.length - 1];
  for (let i = 0; i < candidats.length; i++) {
    tirage -= poids[i];
    if (tirage <= 0) { choisi = candidats[i]; break; }
  }

  // Provenance : le PNJ reste la source IMMEDIATE, jamais la chaine complete simplifiee --
  // "<pnj> vous dit : « <contenu deja attribue du souvenir source> »" preserve l'attribution
  // deja presente dans choisi.contenu (qui peut elle-meme deja contenir "X affirme..."/"X a
  // confie...", voir Phases 2/3).
  const texteRevele = pnj + ' vous dit : « ' + choisi.contenu + ' »';
  const ligneEnqueteur = {
    id: 'rc_' + Date.now() + '_' + Math.floor(Math.random() * 1000000),
    titulaire: enqueteur,
    contenu: texteRevele,
    cible: choisi.cible || null,
    categorie: choisi.categorie,
    source: pnj,
    mode_acquisition: 'interrogatoire',
    fait_objectif_ref: choisi.fait_objectif_ref || null,
    jour_acquisition: jourActuel,
    jour_derniere_reactivation: jourActuel,
    jour_expiration: jourActuel + DUREE_MEMOIRE_JOURS
  };
  const rEcriture = await fetch(`${SUPABASE_URL}/rest/v1/${TABLE}`, {
    method: 'POST',
    headers: { ...serviceHeaders(), 'Prefer': 'return=representation' },
    body: JSON.stringify(ligneEnqueteur)
  }).catch(() => null);
  if (!rEcriture || !rEcriture.ok) {
    // Ecriture cote enqueteur echouee -- aucune revelation annoncee, et donc AUCUNE
    // reactivation du souvenir source non plus (voir juste en dessous, jamais atteint ici).
    return res.status(200).json({ ok: true, statut: 'refus', revelation: null });
  }

  // Reactivation du souvenir SOURCE du PNJ -- uniquement maintenant que la revelation a
  // reellement ete persistee cote enqueteur (jamais si le jet a echoue, jamais si le PNJ ne
  // savait rien, jamais si l'ecriture ci-dessus a echoue).
  await fetch(`${SUPABASE_URL}/rest/v1/${TABLE}?id=eq.${encodeURIComponent(choisi.id)}`, {
    method: 'PATCH',
    headers: serviceHeaders(),
    body: JSON.stringify({ jour_derniere_reactivation: jourActuel, jour_expiration: jourActuel + DUREE_MEMOIRE_JOURS })
  }).catch(() => {});

  return res.status(200).json({ ok: true, statut: 'revelation', revelation: texteRevele });
}

// Phase 5B : ecriture d'UN evenement commercial escort reel. Fire-and-forget cote appelant --
// cette fonction ne fait jamais planter/annuler l'action de jeu qui l'a declenchee (deja
// terminee avec succes avant cet appel), se contente d'echouer silencieusement (voir
// commentaire d'en-tete de fichier pour les limites assumees de verification).
async function enregistrerEvenementEscort(body, res) {
  const { client, escort, type_evenement } = body;
  if (!texteValide(client, 200) || !texteValide(escort, 200) || !['embauche', 'prestation'].includes(type_evenement)) {
    return res.status(400).json({ error: 'Paramètres invalides.' });
  }

  // jour REEL persiste du personnage -- jamais accepte du corps de la requete.
  const rPerso = await fetch(
    `${SUPABASE_URL}/rest/v1/personnages?name=eq.${encodeURIComponent(client)}&select=day`,
    { headers: serviceHeaders() }
  ).catch(() => null);
  if (!rPerso || !rPerso.ok) return res.status(200).json({ ok: false });
  const lignesPerso = await rPerso.json();
  const perso = Array.isArray(lignesPerso) ? lignesPerso[0] : null;
  if (!perso) return res.status(200).json({ ok: false });
  const jourActuel = Number.isInteger(perso.day) ? perso.day : 1;

  // id/jour_expiration TOUJOURS calcules ici, jamais acceptes du client. INSERT uniquement --
  // aucun upsert, un evenement reel de plus est toujours une nouvelle ligne (voir migration).
  const row = {
    id: 'eec_' + Date.now() + '_' + Math.floor(Math.random() * 1000000),
    client,
    escort,
    type_evenement,
    jour: jourActuel,
    jour_expiration: jourActuel + DUREE_MEMOIRE_JOURS
  };

  const r = await fetch(`${SUPABASE_URL}/rest/v1/${TABLE_EVENEMENTS_ESCORT}`, {
    method: 'POST',
    headers: { ...serviceHeaders(), 'Prefer': 'return=representation' },
    body: JSON.stringify(row)
  }).catch(() => null);
  if (!r || !r.ok) return res.status(200).json({ ok: false });

  return res.status(200).json({ ok: true });
}

export default async function handler(req, res) {
  const origin = req.headers.origin;
  if (origin === ALLOWED_ORIGIN) {
    res.setHeader('Access-Control-Allow-Origin', ALLOWED_ORIGIN);
  }
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  if (!SUPABASE_SERVICE_ROLE) {
    // Configuration Vercel pas encore terminee -- echec propre et explicite, jamais une
    // tentative d'ecriture avec une cle absente (meme discipline que upload-org-avatar.js).
    return res.status(503).json({ error: 'Mémoire indisponible : configuration serveur incomplète.' });
  }

  const body = req.body || {};
  if (body.action === 'enregistrer') return enregistrer(body, res);
  if (body.action === 'tirer_confidence_escort') return tirerConfidenceEscort(body, res);
  if (body.action === 'secret_contre_secret') return secretContreSecret(body, res);
  if (body.action === 'interroger_pnj_sujet') return interrogerPnjSurSujet(body, res);
  if (body.action === 'enregistrer_evenement_escort') return enregistrerEvenementEscort(body, res);
  return res.status(400).json({ error: 'action invalide.' });
}
