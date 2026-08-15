// =====================
// PLATEAU-CORE.JS
// Fondations : state global, initialisation, horloge, mise a jour UI, toast/journal
// =====================

// Constantes partagees (utilisees par plateau-divers.js, plateau-politique.js, plateau-pnj.js)
const PNJ_PERSONALITIES = {
  // RÉPUBLIA
  'Gaston Retard': { trait: "Fonctionnaire depuis 34 ans. N'a jamais annoncé un train à l'heure. Le considère comme une forme d'art. Parle de lui-même à la troisième personne quand il est stressé.", style: "bureaucratique épuisé, cynique poli, fier de son inefficacité" },
  'Mireille Guichet': { trait: "Sourit en permanence sans raison. Répond à tout par 'C'est noté' sans jamais noter quoi que ce soit.", style: "serviable de façade, passive-agressive, adore les formulaires" },
  'Raoul Toufaud': { trait: "Commissaire qui pointe toujours dans la mauvaise direction. Confond régulièrement les suspects et les témoins. A résolu exactement 0 affaire.", style: "autoritaire incompétent, se vexe facilement, cite le règlement sans le connaître" },
  'Brigitte Menottes': { trait: "Inspectrice qui menotterait sa propre ombre si elle pouvait. Zèle inversement proportionnel à son efficacité.", style: "zélée et inutile, parle en jargon policier inventé" },
  'Honoré Cozetoujours': { trait: "Juge qui condamne avant d'écouter. A condamné son greffier par erreur trois fois.", style: "sentencieux, cite des lois inventées, tape du marteau de façon aléatoire" },
  'Bernard Coffre-Fort': { trait: "Directeur de banque qui n'a jamais ouvert un compte de sa vie. Confond les débits et les crédits.", style: "solennel et incompétent, parle en chiffres qui ne correspondent à rien" },
  'Hans Von Discret': { trait: "Banquier suisse qui confirme uniquement par un silence pesant. Sa discrétion est telle qu'il nie son propre nom.", style: "mutisme calculé, réponses en non-dits, accent suisse exagéré" },
  'Frère Jacques D\'Equerre': { trait: "Grand Maître qui parle uniquement en métaphores géométriques. Le triangle est sa réponse à tout.", style: "énigmatique pompeux, métaphores maçonniques absurdes, clin d'œil permanent" },

  // EL ESTADO
  'Pedro Tequila': { trait: "Barman philosophe qui mélange les cocktails et les théories politiques. Chaque verre est une leçon de vie qu'on ne demandait pas.", style: "jovial menaçant, proverbes inventés en espagnol approximatif, toujours un couteau sur le comptoir" },
  'Lupe Cantina': { trait: "Serveuse armée qui prend les commandes avec un revolver à la ceinture. Le pourboire est obligatoire.", style: "souriante dangereuse, mélange espagnol et français au hasard, mentionne El Don sans raison" },
  'El Capitan Gordo': { trait: "Incorruptible jusqu'à 500 pesos. Après, tout est négociable. A un portrait d'El Don derrière lui en permanence.", style: "autoritaire jovial, corruption assumée, cite El Don à tout moment" },
  'Consuela Silencio': { trait: "Inspectrice qui tire sa force du silence absolu. Peut rester immobile 4 heures en vous fixant.", style: "intimidation par le silence, parle rare et percutant, regard qui tue" },
  'El Juez Manchado': { trait: "Juge dont les verdicts se vendent au kilo. Propose une grille tarifaire officieuse après chaque audience.", style: "corruption institutionnalisée, formules juridiques espagnoles inventées, sourire gras" },
  'Carlos Retraso': { trait: "Chef de gare qui annonce des horaires purement décoratifs. Les trains partent quand El Don le décide.", style: "bureaucrate tropical, délais assumés, chaleur étouffante dans chaque phrase" },
  'Juanita Soborno': { trait: "Agente des douanes qui fait passer les colis avec un sourire si on glisse un billet dans le passeport.", style: "corruption charmante, regard complice, formules douanières inventées" },

  // SOVARKA
  'Olga Soupe': { trait: "Cantinière qui sert la même soupe depuis 1952. Considère la variété culinaire comme une déviation bourgeoise.", style: "stoïcisme soviétique, fierté de la betterave, citations du Parti dans chaque phrase" },
  'Boris Betterave': { trait: "Cuisinier qui n'a jamais vu une épice. La betterave est son seul ingrédient et il en est fier.", style: "enthousiasme soviétique pour le vide, compare tout à la betterave" },
  'Camarade Borodine': { trait: "Commissaire du Peuple qui remplit des rapports en triple sur les rapports qu'il vient de remplir. Voit des contre-révolutionnaires partout.", style: "paranoïa douce, camarade à tout bout de champ, formulaires comme religion" },
  'Nadejda Formulaire': { trait: "Secrétaire qui sourit uniquement en remplissant des formulaires. Considère la joie comme contre-révolutionnaire.", style: "robotique administrative, formulaires en quadruple, bonheur dans la paperasse" },
  'Camarade Horaire': { trait: "Chef de gare qui pense que les trains arrivent à l'heure parce que le Parti l'a décrété. La réalité est un détail.", style: "idéologique inflexible, nie l'évidence, cite des statistiques inventées" },
  'Nadejda Contrôle': { trait: "Inspectrice des douanes qui fouille les bagages méthodiquement en enregistrant tout en triple. A trouvé une fois un livre non approuvé. C'est son plus grand fait d'armes.", style: "zèle procédurier, méfiance systématique, fierté du protocole" },

  // AL-KHALIJA
  'Hassan Marchandage': { trait: "Marchand dont le premier prix affiché est une insulte à la négociation. Le vrai prix n'apparaît qu'après 40 minutes de marchandage rituel.", style: "protocole du marchandage sacré, bénédictions du Loukoum Divin entre chaque offre" },
  'Yasmine Épices': { trait: "Marchande qui connaît le prix de chaque secret de la ville. Les épices sont son prétexte, les informations son commerce.", style: "mystérieuse parfumée, double sens permanent, cite le Loukoum Divin en cas de doute" },
  'Chambellan Ibn Protocole': { trait: "Chef de la Garde qui ne parle qu'en troisième personne. Considère le tutoiement comme un crime de lèse-majesté.", style: "protocole excessif, troisième personne, bénédictions du Sheikh imbriquées" },
  'Fatima Al-Secret': { trait: "Inspectrice dont les interrogatoires consistent à servir du thé en silence jusqu'à ce que l'interlocuteur avoue spontanément.", style: "douceur menaçante, thé comme arme, patience infinie" },
  'Chambellan Al-Transit': { trait: "Directeur du Hub Royal qui accueille selon le rang. Un visa en or pour les notables, une heure d'attente pour les autres.", style: "protocole hiérarchique absolu, bénédictions Royal, troisième personne" },
  'Yasmine Embarquement': { trait: "Hôtesse royale qui sourit avec une précision chirurgicale calculée au millimètre par le protocole.", style: "perfection froide, formules royales mémorisées, sourire mécanique parfait" },
  'Cheikh Al-Verdict': { trait: "Grand Juge dont les verdicts s'inspirent des textes sacrés et des instructions discrètes du Palais. Le Loukoum Divin guide sa main.", style: "sentences solennelles, citations du Loukoum Divin, justice royale assumée" },

  // Escorts
  'Roxane Velours':    { trait: "Escort de luxe dont le carnet d'adresses vaut plus que celui du Premier Ministre. Chaque confidence lui appartient. Elle sourit toujours — c'est inclus dans le tarif.", style: "charme discret, double sens constant, connait tous les secrets des couloirs du pouvoir" },
  'Lola Discreta':     { trait: "Informatrice double jeu a Ciudad Roja. Travaille officiellement pour El Don. Et pour deux autres personnes. Elle-meme ne sait plus tres bien pour qui.", style: "mysterieuse enjouee, proverbes espagnols inventes, revele toujours un peu plus qu'elle ne devrait" },
  'Natasha Privilege': { trait: "Reservee aux cadres du Parti. Tres bien informee sur les deliberations internes. Ce qu'elle entend reste confidentiel — sauf si on lui demande poliment.", style: "distinction sovietique, formules du Parti recyclees, discretion absolue sur demande express" },

  // Reporters
  'Jodie Moitout':     { trait: "Journaliste micro-trottoir de L'Autruche Entravee. Tend son micro a n'importe qui, n'importe ou, n'importe quand. Les gens lui disent tout sans savoir pourquoi. Son sourire est une arme.", style: "enthousiasme journalistique communicatif, questions anodines aux reponses explosives, micro tendu en permanence" }
};

// Fiches PNJ enrichies (audit du 8 aout 2026) — table separee de PNJ_PERSONALITIES,
// meme cle (nom du PNJ, sans le suffixe "(PNJ)"). Remplissage partiel assume : la grande
// majorite des PNJ n'ont AUCUNE entree ici, seuls quelques PNJ centraux sont enrichis.
// Chaque colonne est facultative. "notes" est un usage interne (jamais envoye a l'IA).
// Consommee uniquement par talkToPnj() pour l'instant (plateau-pnj.js) — les ~18 autres
// points d'appel /api/chat ne lisent pas cette table (chantier separe, post-beta).
const PNJ_PROFILS = {
  'Gérard Poinçon': {
    traits: ['nostalgique', 'bavard', 'méfiant des touristes pressés'],
    savoirs: "Connaît par cœur l'histoire de chaque salle et de chaque objet exposé au musée. Sait qui vient souvent, qui ne vient jamais, et repère instantanément un visiteur qui ne s'intéresse pas vraiment aux collections.",
    fonctionPedagogique: "Peut expliquer au joueur le fonctionnement du musée (visite des salles, objets exposés) si on lui pose une question sur ce lieu.",
    secrets: "Rallonge discrètement ses pauses de dix bonnes minutes chaque jour, persuadé que personne ne s'en aperçoit. A aussi un faible inavoué pour la salle des minéraux, qu'il trouve bien plus fascinante que les collections officielles — mais ne l'admettra jamais devant sa hiérarchie.",
    objectifs: "Veut partir à la retraite dans deux ans avec sa pension complète — évite tout scandale qui pourrait la compromettre.",
    rumeurs: "Colporte volontiers les ragots qu'il entend des visiteurs habitués, sans toujours vérifier s'ils sont exacts.",
    notes: "Premier cas d'enrichissement complet (audit PNJ, 8 aout 2026) — sert d'exemple de remplissage pour les prochains PNJ centraux."
  },
  // Referent permanent de l'illegalite apres la branche criminelle de la quete d'accueil
  // (15 aout 2026). savoirs limite volontairement aux mecaniques reelles et deja presentes
  // dans le code (DUP=data.js, organisations criminelles=TYPES_ORGANISATIONS/plateau-
  // organisations-quetes.js, actions illegales=plateau-actions-illegales-rumeurs.js/data.js
  // orders type:'illegal') -- pas de chiffre invente, pas de mecanique fabriquee pour la
  // conversation. Ne connait rien de la carriere/nature profonde/origine/scolarite/stats
  // privees du joueur (jamais transmises dans le contexte generique, voir talkToPnj) : ce
  // qu'il "sait" du joueur se limite a la mission du colis qu'il lui a lui-meme confiee.
  'Pat Hounette': {
    traits: ['prudent', 'peu bavard', 'jamais deux fois au meme endroit'],
    savoirs: "Connaît le milieu criminel de Luthécia sans en être le chef. Sait qu'on peut rejoindre une organisation criminelle déjà existante, ou en fonder une soi-même à condition de disposer d'un local pour y installer son siège — sinon, on peut aussi travailler en solo. Sait que la Duplicité (DUP) est la caractéristique clé de tout ce qui touche à l'illégalité : mentir, dissimuler, corrompre. Connaît l'existence de pratiques comme la contrebande portuaire, le vol, le recel de kompromats, ou la corruption de fonctionnaires (douaniers, policiers, juges...), sans en détailler les chances de réussite exactes — chacun apprend ça sur le terrain.",
    fonctionPedagogique: "Peut orienter un joueur intéressé par le milieu criminel vers les organisations criminelles, ou vers le travail en solo, et expliquer pourquoi la Duplicité compte tant dans ce métier. Si on lui pose une question précise dont il n'est pas sûr de la réponse, il le dit franchement dans son personnage (prudence, méfiance) plutôt que d'inventer une règle ou un chiffre.",
    secrets: "Ne révèle jamais l'identité de ses propres commanditaires ni le détail de ses activités en cours.",
    objectifs: "Rester en dehors des radars. Évite d'être vu trop souvent avec la même personne.",
    notes: "Ajouté au lot de la branche criminelle (15 aout 2026) — référent illégalité une fois la quête Pat Hounette/Brigitte Menottes terminée."
  }
  // la grande majorite des PNJ n'ont pas d'entree ici — c'est attendu
};

const PNJ_AVATAR = {
  commissaire:   { icon: 'ti-shield-lock',       color: '#4a6aaa' },
  inspecteur:    { icon: 'ti-search',             color: '#4a6aaa' },
  policier:      { icon: 'ti-shield',             color: '#4a6aaa' },
  gardien:       { icon: 'ti-lock',               color: '#6a6060' },
  juge:          { icon: 'ti-gavel',              color: '#C9A84C' },
  avocat:        { icon: 'ti-scale',              color: '#8a8060' },
  journaliste:   { icon: 'ti-news',               color: '#8a4a20' },
  redacteur:     { icon: 'ti-pencil',             color: '#8a4a20' },
  banquier:      { icon: 'ti-building-bank',      color: '#4a8a4a' },
  medecin:       { icon: 'ti-stethoscope',        color: '#4a9a9a' },
  infirmier:     { icon: 'ti-heart-rate-monitor', color: '#4a9a9a' },
  serveur:       { icon: 'ti-bowl',               color: '#8a6a40' },
  hotelier:      { icon: 'ti-building-castle',    color: '#8a6a40' },
  barman:        { icon: 'ti-glass',              color: '#8a6a40' },
  militaire:     { icon: 'ti-military-rank',      color: '#4a6a4a' },
  general:       { icon: 'ti-medal',              color: '#C9A84C' },
  maire:         { icon: 'ti-building-community', color: '#C9A84C' },
  secretaire:    { icon: 'ti-file-certificate',   color: '#8a8060' },
  professeur:    { icon: 'ti-school',             color: '#6a4a8a' },
  loge:          { icon: 'ti-hexagon',            color: '#8a2020' },
  armurier:      { icon: 'ti-shield',             color: '#6a6060' },
  commercant:    { icon: 'ti-building-store',     color: '#8a6a40' },
  syndicaliste:  { icon: 'ti-users-group',        color: '#8a2020' },
  douanier:      { icon: 'ti-clipboard-check',    color: '#4a6aaa' },
  chef_gare:     { icon: 'ti-train',              color: '#6a6060' },
  hotesse:       { icon: 'ti-user-heart',         color: '#8a4a6a' },
  grand_pretre:  { icon: 'ti-star',               color: '#C9A84C' },
  escort:        { icon: 'ti-heart',              color: '#aa4a6a' },
  capitaine_port:{ icon: 'ti-anchor',             color: '#4a6aaa' },
  protocole:     { icon: 'ti-crown',              color: '#C9A84C' },
  garde:         { icon: 'ti-shield',             color: '#4a6aaa' },
  porteparole:   { icon: 'ti-speakerphone',       color: '#8a4a20' },
  archiviste:    { icon: 'ti-archive',            color: '#8a8060' },
  directeur:     { icon: 'ti-briefcase',          color: '#C9A84C' },
  citoyen:       { icon: 'ti-user',               color: '#6a6060' },
  depute:        { icon: 'ti-building-arch',      color: '#C9A84C' },
  default:       { icon: 'ti-user',               color: '#6a6060' }
};

const BONUS_ARCHETYPE_FAUSSE_RUMEUR = {
  shadow: 15, criminal: 15, informer: 5
  // tous les autres archetypes : 0
};

const PEINES = {
  delit_mineur:   { jours: 2,  label: 'Delit mineur',   amendeBase: 500  },
  delit_grave:    { jours: 4,  label: 'Delit grave',     amendeBase: 1500 },
  crime:          { jours: 8,  label: 'Crime',           amendeBase: 5000 },
  crime_etat:     { jours: 30, label: "Crime d'Etat",    amendeBase: 0    }
};

// Baremes specifiques par acte et par empire — remplacent PEINES/ACTES_ILLEGAUX quand presents.
// Valeurs "echec" (flagrant delit / recherche). Si demasque (decouvert apres coup via enquete), doublees automatiquement.
// Batiments consideres comme centres de pouvoir : malus important a l'incendie et aux explosifs
const BATIMENTS_CENTRES_POUVOIR = [
  'palais-presidentiel', 'palais-gouvernement', 'assemblee', 'tribunal',
  'commissariat', 'banque-nationale', 'banque-privee', 'mairie-capitale', 'mairie'
];
const MALUS_CENTRE_POUVOIR = 30;

const PEINES_ACTES = {
  republic: {
    violation_couvre_feu:     { jours: 1, amende: 200,  label: 'Violation du couvre-feu' },
    vol:                      { jours: 1, amende: 500,  label: 'Vol' },
    achat_arme_illegal:       { jours: 1, amende: 500,  label: "Achat d'arme non enregistree" },
    possession_illegale_douane: { jours: 1, amende: 500, label: "Possession d'objets prohibes au controle douanier" },
    diffamation:              { jours: 1, amende: 500,  label: 'Diffamation' },
    tentative_assassinat:     { jours: 2, amende: 1500, label: "Tentative d'assassinat" },
    assassinat:               { jours: 2, amende: 1500, label: 'Assassinat' },
    tentative_empoisonnement: { jours: 2, amende: 2000, label: "Tentative d'empoisonnement" },
    empoisonnement:           { jours: 2, amende: 2000, label: 'Empoisonnement' },
    acheter_bombe_illegale:   { jours: 2, amende: 2000, label: "Achat d'explosifs non enregistres" },
    utiliser_explosifs:       { jours: 2, amende: 2000, label: "Usage d'explosifs" },
    incendier:                { jours: 2, amende: 2000, label: 'Incendie volontaire' },
    hooliganisme:             { jours: 1, amende: 500,  label: 'Trouble a l\'ordre public (hooliganisme)' },
    corruption_fonctionnaire: { jours: 1, amende: 1000, label: 'Corruption de fonctionnaire' }
  }
};

// Calcule la peine applicable pour un acte donne. demasque=true double jours et amende
// (acte reussi et decouvert apres coup, plutot qu'un echec immediat).
function getPeineParActe(acte, demasque) {
  const pays = state.country || 'republic';
  const specifique = PEINES_ACTES[pays]?.[acte];
  if (specifique) {
    const mult = demasque ? 2 : 1;
    return { jours: specifique.jours * mult, amende: specifique.amende * mult, label: specifique.label };
  }
  const type = ACTES_ILLEGAUX[acte]?.type || acte || 'delit_mineur';
  const peine = PEINES[type] || PEINES.delit_mineur;
  return { jours: peine.jours, amende: peine.amendeBase, label: peine.label };
}

const ACTES_ILLEGAUX = {
  corrompre_fonct:    { type: 'delit_mineur',  detectRate: 30 },
  corrompre_police:   { type: 'delit_mineur',  detectRate: 35 },
  corrompre_juge:     { type: 'delit_grave',   detectRate: 40 },
  corrompre_journaliste:{ type: 'delit_mineur',detectRate: 25 },
  blanchiment:        { type: 'delit_grave',   detectRate: 35 },
  societe_ecran:      { type: 'delit_mineur',  detectRate: 25 },
  falsifier_document: { type: 'delit_grave',   detectRate: 40 },
  acheter_arme_illegale:{ type: 'delit_mineur',detectRate: 20 },
  acheter_bombe_illegale:{ type: 'crime',      detectRate: 55 },
  fabriquer_bombe:    { type: 'crime',         detectRate: 60 },
  incendier:          { type: 'crime',         detectRate: 70 },
  utiliser_explosifs: { type: 'crime',         detectRate: 65 },
  arreter:            { type: 'delit_grave',   detectRate: 40 },
  fabriquer_scandale: { type: 'delit_grave',   detectRate: 45 },
  fuite_info:         { type: 'delit_grave',   detectRate: 40 },
  imprimer_clandestin:{ type: 'delit_mineur',  detectRate: 30 },
  tentative_evasion:  { type: 'crime',         detectRate: 90 },
  se_rebeller:        { type: 'delit_mineur',  detectRate: 60 },
  fausse_rumeur:      { type: 'delit_mineur',  detectRate: 35 },
  vol:                { type: 'delit_mineur',  detectRate: 30 },
  assassiner_mains:   { type: 'crime',         detectRate: 30 },
  assassiner_arme:    { type: 'crime',         detectRate: 40 },
  assassiner_feu:     { type: 'crime',         detectRate: 60 },
  empoisonnement:     { type: 'crime',         detectRate: 25 }
};

const BUDGET_DEFAULT = {
  presidence: { solde: 50000, coutOrdre: 500 },
  min_int:    { solde: 30000, coutOrdre: 400 },
  min_fin:    { solde: 25000, coutOrdre: 300 },
  min_just:   { solde: 20000, coutOrdre: 350 },
  min_def:    { solde: 40000, coutOrdre: 600 },
  min_info:   { solde: 15000, coutOrdre: 250 },
  min_ae:     { solde: 20000, coutOrdre: 300 },
  assemblee:  { solde: 35000, coutOrdre: 200 },
  tribunal:   { solde: 20000, coutOrdre: 400 },
  commissariat:{ solde: 25000, coutOrdre: 350 },
  mairie:     { solde: 30000, coutOrdre: 250 }
};

const REPARTITION_DEFAULT = {
  presidence: 15, pm: 8, min_int: 8, min_fin: 6, min_just: 6,
  min_def: 10, min_info: 5, min_ae: 6,
  assemblee: 8, tribunal: 6, commissariat: 8, mairie: 12, reserve: 2
};

const EMPIRE_STYLES = {
  republic: { tone: "bureaucratique français épuisé, cynique poli", religion: "le Papyrusisme", currency: "FR", leader: "le Président" },
  narco:    { tone: "jovial menaçant, corruption assumée, espagnol de bazar", religion: "le Laboratoire de Prière", currency: "PS", leader: "El Don" },
  soviet:   { tone: "idéologique soviétique, formulaires sacrés, Camarade partout", religion: "le Kolkhoze Spirituel", currency: "RP", leader: "le Parti" },
  khalija:  { tone: "protocole royal excessif, Loukoum Divin omniprésent, bénédictions imbriquées", religion: "la Pâtisserie Sacrée", currency: "DR", leader: "le Sheikh" }
};

const JOURNALISTES_PNJ = {
  republic: {
    name: 'Gustave Encre',
    journal: "L'Autruche Entravée",
    trait: "Journaliste d'investigation alcoolique. Déterre les scandales par accident en cherchant ses clés. A une source dans chaque ministère mais ne sait plus lequel.",
    style: "cynique désabusé, métaphores journalistiques épuisées, boit du café tiède depuis 1987"
  },
  narco: {
    name: 'El Editor',
    journal: 'El Narco Times',
    trait: "Rédacteur en chef qui blanchit les nouvelles comme El Don blanchit l'argent. Chaque article est une œuvre de fiction assumée.",
    style: "propagandiste jovial, español aproximativo, cite El Don dans chaque paragraphe"
  },
  soviet: {
    name: 'Rédacteur Vérité',
    journal: 'La Pravdovka',
    trait: "Journaliste du Parti qui vérifie trois fois si une information est approuvée avant de la publier. A publié le même article depuis 1973 avec des noms différents.",
    style: "zèle idéologique mécanique, vérité = ce que dit le Parti, enthousiasme performatif"
  },
  khalija: {
    name: 'Rédacteur Al-Vérité',
    journal: 'Le Minaret Doré',
    trait: "Journaliste royal qui ne publie que ce que le Palais approuve. Ses éditoriaux commencent tous par une bénédiction du Sheikh et finissent par une autre.",
    style: "déférence royale absolue, Loukoum Divin dans chaque titre, vérité = volonté du Sheikh"
  }
};

/* ===========================
   RES PUBLICA — PLATEAU.JS v2
   =========================== */

// =====================
// STATE
// =====================
const TEST_MODE = true; // PA illimites

let state = {
  pa: 999, paMax: 999,
  arg: 4250, liquide: 500, banque: 3750,
  inf: 25, pop: 30, dis: 85, hp: 92, moral: 78,
  day: 1, hour: 8,
  country: 'republic',
  currentCity: 'capitale',
  currentBuilding: null,
  currentRoom: null,
  char: null,
  inventory: [],
  poste: null,
  employees: [],
  employes: [],
  escortActive: [],
  tracesEnquete: [],
  dernierDormir: 0
};

// =====================
// INIT
// =====================
// Encode un objet PNJ en toute securite pour l'injection dans des attributs HTML —
// encodeURIComponent seul ne touche pas aux apostrophes, ce qui casse les onclick="...('...')"
// quand un nom de PNJ contient une apostrophe (ex: "Agent d'Entretien")
function encodePnjSafe(obj) {
  return encodeURIComponent(JSON.stringify(obj)).replace(/'/g, '%27');
}

window.addEventListener('DOMContentLoaded', () => {
  loadCharacter();
  // Restaurer dernierDormir depuis localStorage
  try {
    const dormirData = JSON.parse(localStorage.getItem('respublica_dormir_' + (state.char?.name || 'default')) || '{}');
    if (dormirData.dernierDormir) state.dernierDormir = dormirData.dernierDormir;
    if (dormirData.day) state.day = Math.max(state.day, dormirData.day);
  } catch(e) {}
  if (!state.currentCity) state.currentCity = 'capitale';
  if (!state.country) state.country = 'republic';

  // Ancien repli "nouveau personnage -> hall de la mairie" retire le 31 juillet 2026 :
  // obsolete et en conflit avec la quete d'accueil, qui place desormais le nouveau
  // personnage dans la rue devant le Palais Presidentiel (voir plateau-quete-accueil.js).

  applyEmpireTheme(state.country);
  // Sauvegarder la position courante
  if (state.char) {
    state.char.country = state.country;
    state.char.currentCity = state.currentCity;
    // Inclure poste et données importantes dans state.char avant sauvegarde
    if (state.char) {
      state.char.poste = state.poste || null;
      state.char.currentCity = state.currentCity || 'capitale';
      state.char.arg = state.arg || 0;
      state.char.resources = { inf: state.inf||0, pop: state.pop||0, dis: state.dis||50 };
      state.char.currentBuilding = state.currentBuilding || null;
      state.char.currentRoom = state.currentRoom || null;
    }
    try {
      localStorage.setItem('respublica_char_' + (state.char?.name || 'default'), JSON.stringify(state.char));
      localStorage.setItem('respublica_char', JSON.stringify(state.char));
    } catch (e) {
      console.warn('Cache local personnage non sauvegarde (quota depasse) :', e);
    }
  }
  buildCityTabs();
  updateUI();
  updateLocationDisplay();
  startClock();
  // Init Supabase
  if (typeof sbInit === 'function') sbInit();

  // Synchroniser les cycles électoraux depuis Supabase
  setTimeout(() => {
    syncCyclesDepuisSupabase().then(() => verifierPostesVacants());
  }, 2000);

  // Vérification mails toutes les 2 minutes
  verifierNouveauxMails();
  setInterval(verifierNouveauxMails, 120000);

  // Vérification des objets reçus (dons d'un autre joueur) toutes les 2 minutes
  verifierObjetsRecus();
  setInterval(verifierObjetsRecus, 120000);

  // Batiments fermes (incendie/explosifs) — au chargement puis toutes les 2 minutes
  setTimeout(() => chargerBatimentsFermes(), 1000);
  setInterval(chargerBatimentsFermes, 120000);

  // Championnat sportif — verifie/avance la saison au chargement puis toutes les 5 minutes
  // (n'importe quel joueur connecte peut declencher le rattrapage, l'etat est partage sur Supabase)
  setTimeout(() => { if (typeof verifierEtJouerJournees === 'function') verifierEtJouerJournees(); }, 2500);
  setInterval(() => { if (typeof verifierEtJouerJournees === 'function') verifierEtJouerJournees(); }, 300000);
  setTimeout(() => { if (typeof verifierElectionsOrganisations === 'function') verifierElectionsOrganisations(); }, 3000);
  setInterval(() => { if (typeof verifierElectionsOrganisations === 'function') verifierElectionsOrganisations(); }, 300000);

  // Événements partagés (journal global) — au chargement puis toutes les 90 secondes
  setTimeout(() => chargerEvenementsPartages(), 1500);
  setTimeout(() => chargerOrganisations(), 1800);
  setTimeout(() => { if (typeof chargerLocations === 'function') chargerLocations(); }, 1900);
  setTimeout(() => { if (typeof demarrerPollingNotificationChat === 'function') demarrerPollingNotificationChat(); }, 2000);
  setTimeout(() => { if (typeof demarrerPollingInvitationsDiner === 'function') demarrerPollingInvitationsDiner(); }, 2000);
  setTimeout(() => appliquerNaturalisationAcceptee(), 2100);
  setTimeout(() => { if (typeof appliquerVictoireElectorale === 'function') appliquerVictoireElectorale(); }, 2350);
  setTimeout(() => recupererDonsEnAttente(), 2000);
  setTimeout(() => recupererVolsEnAttente(), 2200);
  setTimeout(() => recupererImpactsEnAttente(), 2400);
  setTimeout(() => verifierLancementQuete(), 2600);
  setInterval(chargerEvenementsPartages, 90000);
  setInterval(recupererDonsEnAttente, 90000);
  setInterval(recupererVolsEnAttente, 90000);
  setInterval(recupererImpactsEnAttente, 90000);

  // Présence en pièce — re-publier + rafraîchir les joueurs visibles toutes les 30 secondes
  setInterval(() => {
    if (typeof sbUpdatePresence === 'function' && state.char?.name && state.currentBuilding && state.currentRoom) {
      sbUpdatePresence(state.char.name, state.country, state.currentCity, state.currentBuilding, state.currentRoom, typeof getMonGroupePNJ === 'function' ? getMonGroupePNJ() : []).catch(() => {});
    }
    if (typeof chargerVraisJoueursPresents === 'function') chargerVraisJoueursPresents();
    if (typeof rafraichirTitulairesPostesElectifs === 'function') rafraichirTitulairesPostesElectifs();
    // Sauvegarde automatique periodique -- filet de securite pour rattraper tout gain
    // (INF, HP, etc.) qu'une fonction particuliere aurait omis de sauvegarder elle-meme.
    if (typeof sbSavePersonnage === 'function' && state.char?.name) {
      sbSavePersonnage(state).catch(() => {});
    }
  }, 30000);
  if (typeof rafraichirTitulairesPostesElectifs === 'function') rafraichirTitulairesPostesElectifs();

  // Séquence de chargement espacée pour éviter les conflits de modaux
  setTimeout(() => genererMeteoPolitique(), 1000);
  setTimeout(() => genererEvenementAleatoire(), 3000);
  setTimeout(() => {
    if (!sessionStorage.getItem('journaliste_done')) {
      afficherReactionJournaliste();
      sessionStorage.setItem('journaliste_done', '1');
    }
  }, 5000);
  // Journal du matin en dernier — après tous les autres
  setTimeout(() => afficherJournalDuMatin(), 8000);

  // Forcer le rendu complet au chargement
  setTimeout(() => {
    forceRenderCity(state.currentCity || 'capitale');
  }, 300);
});

async function chargerBatimentsFermes() {
  if (typeof sbChargerBatimentsFermes !== 'function') return;
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  try {
    const rows = await sbChargerBatimentsFermes(pays, ville);
    state.batimentsFermesCache = (rows || []).filter(r => r.jour_fin > (state.day || 1));
  } catch(e) {}
}

function batimentEstFerme(buildingId) {
  const ferme = (state.batimentsFermesCache || []).find(r =>
    r.batiment_id === buildingId && r.pays === (state.country||'republic') && r.ville === (state.currentCity||'capitale') && r.jour_fin > (state.day||1)
  );
  return ferme || null;
}

function loadCharacter() {
  try {
    // Lire le dernier personnage actif, puis sa clé propre
    const lastName = localStorage.getItem('respublica_last_char');
    const saved = lastName
      ? (localStorage.getItem('respublica_char_' + lastName) || localStorage.getItem('respublica_char'))
      : localStorage.getItem('respublica_char');
    if (saved) {
      const char = JSON.parse(saved);
      applyCharToState(char);
      console.log('Personnage charge (local):', char.name, '| Pays:', state.country);
      // Precharge le cache des indices de ville de Republia (chantier "refonte des ordres") --
      // fire-and-forget, les lecteurs (getIndiceVille etc.) ont deja des valeurs par defaut
      // en attendant que ca revienne.
      if (typeof chargerIndicesRepublia === 'function') chargerIndicesRepublia().catch(() => {});
      // Restaurer la position exacte (piece) ou la personne se trouvait avant le rafraichissement
      restaurerPositionApresChargement(char);
      // Reinjecter le journal personnel persiste (rapide, depuis le cache local)
      restaurerJournal(char);
      // Synchroniser depuis Supabase en arrière-plan
      if (char.name && typeof sbLoadPersonnage === 'function') {
        sbLoadPersonnage(char.name).then(sbState => {
          if (sbState) {
            // La position (bâtiment/pièce) locale est toujours écrite immédiatement et de façon fiable
            // dès qu'on change de pièce (voir enterRoom). La sauvegarde Supabase, elle, est asynchrone :
            // un rafraîchissement rapide après un déplacement peut arriver avant qu'elle n'ait fini de
            // se propager. On garde donc toujours la position locale plutôt que celle de Supabase.
            const positionLocaleBuilding = state.char?.currentBuilding;
            const positionLocaleRoom = state.char?.currentRoom;

            // Fusionner les données Supabase (plus récentes pour tout le reste : argent, inventaire, etc.)
            Object.assign(state, sbState);

            // applyCharToState() ci-dessous recalcule inf/pop/dis (et arg) a partir de char.resources/char.arg --
            // il faut donc synchroniser char.resources/char.arg avec les valeurs fraiches qu'on vient de
            // fusionner, sinon le second appel ecraserait silencieusement ces valeurs avec les
            // anciennes valeurs restees sur l'objet char (c'etait le bug : gains perdus au F5,
            // et pour arg specifiquement, l'objet char de sbLoadPersonnage n'a meme jamais de champ
            // arg du tout -> reset systematique au defaut 4250 code en dur, trouve le 9 aout 2026).
            if (state.char) {
              state.char.resources = { inf: state.inf, pop: state.pop, dis: state.dis };
              state.char.arg = state.arg;
            }

            if (positionLocaleBuilding) {
              state.currentBuilding = positionLocaleBuilding;
              if (state.char) state.char.currentBuilding = positionLocaleBuilding;
            }
            if (positionLocaleRoom) {
              state.currentRoom = positionLocaleRoom;
              if (state.char) state.char.currentRoom = positionLocaleRoom;
            }

            applyCharToState(state.char);
            updateUI();
            restaurerPositionApresChargement(state.char);
            // Reconcilie avec la version Supabase (potentiellement plus a jour, ex. joueur
            // actif sur un autre appareil) -- vide et repeuple #journal en consequence.
            restaurerJournal(state.char);
            if (typeof enigme1VerifierDeclenchement === 'function') enigme1VerifierDeclenchement();
            // Emploi BNE : pas de colonne dediee sur personnages (voir plateau-justice-economie.js),
            // le cache local state.emploiBNE doit etre rafraichi explicitement depuis Supabase.
            if (typeof rafraichirCacheEmploiBNE === 'function') rafraichirCacheEmploiBNE();
            console.log('Personnage synchronisé depuis Supabase:', char.name);
          }
        }).catch(() => {});
      }
    }
  } catch(e) { console.warn('Erreur chargement personnage', e); }
}

// Si le joueur etait dans un batiment/piece avant de rafraichir, on l'y replace directement
function restaurerPositionApresChargement(char) {
  if (!char.currentBuilding || !char.currentRoom) return;
  if (!BUILDINGS[char.currentBuilding] || !BUILDINGS[char.currentBuilding].rooms?.[char.currentRoom]) return;
  setTimeout(() => {
    try {
      enterBuilding(char.currentBuilding, true);
      enterRoom(char.currentBuilding, char.currentRoom, null);
    } catch(e) { console.warn('Erreur restauration position', e); }
  }, 300);
}

// Migration des anciens id de carrière (18 -> 10, bêta) -- voir MIGRATION_CAREER_IDS (data.js)
// pour la table complète et le raisonnement de chaque mappage. Mutation en mémoire uniquement
// (jamais d'écriture directe en base) : la prochaine sauvegarde normale du personnage (au
// premier appel de sbSavePersonnage, qui se produit tres vite en jeu) persiste naturellement
// l'id corrige, sans backfill explicite necessaire.
function migrerCareerId(char) {
  if (!char || !char.career) return;
  if (typeof MIGRATION_CAREER_IDS === 'undefined') return;
  const nouvelId = MIGRATION_CAREER_IDS[char.career];
  if (nouvelId) char.career = nouvelId;
}

function applyCharToState(char) {
  if (!char) return;
  migrerCareerId(char);
  state.char = char;
  state.country = char.country || 'republic';
  state.currentCity = char.currentCity || 'capitale';
  state.arg = char.arg || 4250;
  if (char.poste) state.poste = char.poste;
  if (char.posteDepute) state.posteDepute = char.posteDepute;
  state.liquide = Math.floor(state.arg * 0.15);
  state.banque = state.arg - state.liquide;
  state.inf = char.resources?.inf || 25;
  state.pop = char.resources?.pop || 30;
  state.dis = char.resources?.dis || 85;

  // UI
  const nameEl = document.getElementById('char-name-display');
  if (nameEl) nameEl.textContent = char.name || 'Mon Personnage';
  const ar = ARCHETYPES.find(x => x.id === char.archetype);
  const ca = CAREERS.find(x => x.id === char.career);
  const roleEl = document.getElementById('char-role-display');
  const posteLabel = state.poste?.name || null;
  if (roleEl) roleEl.textContent = posteLabel
    ? `${posteLabel} · ${ar?.name||'?'}`
    : `${ar?.name||'?'} · ${ca?.name||'?'}`;
  const fullnameEl = document.getElementById('char-fullname-left');
  if (fullnameEl) fullnameEl.textContent = char.name || 'Mon Personnage';
  const co = COUNTRIES[char.country];
  const archEl = document.getElementById('char-arch-left');
  const posteStr = state.poste?.name ? `${state.poste.name} · ` : '';
  if (archEl) archEl.textContent = `${posteStr}${ar?.name||'?'} · ${co?.n||'?'}`;

  // Photo
  try {
    const photoSaved = localStorage.getItem('respublica_photo_' + (state.char?.name || 'default')) || localStorage.getItem('respublica_photo');
    const photoUrl = photoSaved || char.photoUrl;
    if (photoUrl && photoUrl.length > 10) {
      const imgTag = `<img src="${photoUrl}" alt="Photo" style="width:100%;height:100%;object-fit:cover;border-radius:50%"/>`;
      const photoEl = document.getElementById('char-photo-left');
      const avatarEl = document.getElementById('char-avatar-top');
      if (photoEl) photoEl.innerHTML = imgTag;
      if (avatarEl) avatarEl.innerHTML = imgTag;
    }
  } catch(photoErr) { console.warn('Photo non chargee:', photoErr); }

  if (char.stats) {
    const statGrid = document.getElementById('stat-mini-grid');
    if (statGrid) statGrid.innerHTML = STAT_DEFS.map(({k}) => `
      <div class="stat-mini">
        <div class="stat-mini-name">${k}</div>
        <div class="stat-mini-val">${char.stats[k]||8}</div>
      </div>`).join('');
  }

  const cur = co?.cur || 'FR';
  const argEl = document.getElementById('r-arg');
  if (argEl) argEl.textContent = state.arg.toLocaleString('fr-FR') + ' ' + cur;
}

// =====================
// CLOCK
// =====================
function startClock() {
  syncRealTime();
  updateClock();
  // Mise a jour toutes les minutes
  setInterval(() => {
    syncRealTime();
    updateClock();
    checkMidnight();
  }, 60000);
}

// Date/heure reelle formatee, a utiliser partout a la place de "Jour X" (peu parlant pour le joueur)
function formatDateHeureJeu() {
  const now = new Date();
  const frNow = new Date(now.toLocaleString('en-US', { timeZone: 'Europe/Paris' }));
  const dateStr = frNow.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' });
  const h = String(state.hour ?? frNow.getHours()).padStart(2, '0');
  const m = String(state.minute ?? frNow.getMinutes()).padStart(2, '0');
  return `${dateStr} · ${h}h${m}`;
}

// Affiche "Aujourd'hui" a la place de la date si elle correspond a la date du jour.
// Les anciens messages au format "Jour X" restent affiches tels quels (retrocompatibilite).
function formatDateAffichage(dateHeureStr) {
  if (!dateHeureStr) return '';
  const sep = ' · ';
  const idx = dateHeureStr.indexOf(sep);
  const datePart = idx >= 0 ? dateHeureStr.substring(0, idx) : dateHeureStr;
  const restePart = idx >= 0 ? dateHeureStr.substring(idx) : '';
  const now = new Date();
  const frNow = new Date(now.toLocaleString('en-US', { timeZone: 'Europe/Paris' }));
  const todayStr = frNow.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' });
  if (datePart === todayStr) return "Aujourd'hui" + restePart;
  return dateHeureStr;
}

function syncRealTime() {
  // Calage sur l'heure reelle francaise
  const now = new Date();
  const frTime = new Date(now.toLocaleString('en-US', { timeZone: 'Europe/Paris' }));
  state.hour = frTime.getHours();
  state.minute = frTime.getMinutes();
  state.day = state.day || 1; // Le jour de jeu est incremente a minuit
}

function updateClock() {
  const h = String(state.hour).padStart(2,'0');
  const m = String(state.minute||0).padStart(2,'0');
  const el = document.getElementById('game-time');
  if (el) el.textContent = `Jour ${state.day} · ${h}h${m}`;
}

function advanceTime(pa) {
  // Chaque PA consomme environ 30 minutes de temps de jeu
  if (!TEST_MODE && pa > 0) {
    state.minute = (state.minute || 0) + (pa * 30);
    while (state.minute >= 60) {
      state.minute -= 60;
      state.hour = (state.hour + 1) % 24;
      if (state.hour === 0) {
        state.day = (state.day || 1) + 1;
        state.midnightDone = false;
      }
    }
    updateClock();
  }
}

// =====================
// PRIMITIVE CENTRALISEE DE DEDUCTION PA / COUT (Phase K, 13/08/2026)
// =====================
// Prealable a toute deduction dans un handler dedie (route par un cas special de doOrder, voir
// plateau-router.js) : ces handlers ne beneficient PAS de la deduction generique de doOrder(),
// qui ne s'applique qu'aux ordres sans cas special. Audit complet : .scratch/audit-pa-couts-phase-j.csv
//
// Separation stricte des responsabilites (valable pour toutes les phases de migration a venir) :
//   - deduireCoutOrdre() ne connait AUCUNE regle metier (reussite/echec/acceptation/refus).
//     Elle verifie et preleve, point final. C'est au handler de decider QUAND l'appeler :
//     avant un jet si le cout est du meme en cas d'echec, a l'interieur de la branche succes
//     si le cout n'est du qu'en cas de reussite/acceptation, etc.
//   - advanceTime() reste totalement independante : elle avance l'horloge de jeu, jamais les
//     ressources. Un ordre qui doit faire les deux appelle les deux fonctions explicitement.
//   - Les PA restent TOUJOURS personnels (state.pa), meme quand le cout financier est
//     institutionnel (caisse d'un batiment). Le parametre `payeur` ne concerne que l'argent.
//
// Retour :
//   succes : { ok: true, paPreleves, montantPreleve }
//     (paPreleves vaut 0 si TEST_MODE, puisque state.pa n'est alors pas touche -- valeur
//     honnete refletant ce qui a reellement ete preleve, pas la valeur declarative de l'ordre)
//   echec  : { ok: false, raison: 'pa_insuffisants' | 'fonds_insuffisants' | 'caisse_institution_insuffisante' }
//     aucune ressource n'est modifiee en cas d'echec.
async function deduireCoutOrdre({ pa = 0, cost = 0, payeur = 'joueur' } = {}) {
  // A. PA : toujours personnels, ignores sous TEST_MODE (comme partout ailleurs dans le jeu)
  if (!TEST_MODE && (state.pa || 0) < pa) {
    return { ok: false, raison: 'pa_insuffisants' };
  }

  // B. Cout financier : jamais ignore par TEST_MODE (convention existante de doOrder())
  if (cost > 0) {
    if (payeur === 'joueur') {
      if ((state.arg || 0) < cost) {
        return { ok: false, raison: 'fonds_insuffisants' };
      }
    } else if (payeur && payeur.type === 'institution') {
      // Verification + prelevement atomique en un seul appel : si la caisse ne couvre pas le
      // montant en entier, rien n'est preleve (voir diagnostic Phase K sur
      // debiterCaisseBatimentPlafonne, qui elle tolere le partiel pour d'autres usages).
      const montantVerse = typeof debiterCaisseBatimentAtomique === 'function'
        ? await debiterCaisseBatimentAtomique(payeur.pays, payeur.buildingId, cost)
        : 0;
      if (montantVerse < cost) {
        return { ok: false, raison: 'caisse_institution_insuffisante' };
      }
    }
  }

  // D. Deduction des PA (apres verification ET apres prelevement institutionnel reussi, pour
  // qu'un echec du prelevement financier ne laisse jamais les PA ampute pour rien)
  let paPreleves = 0;
  if (!TEST_MODE) {
    state.pa = Math.max(0, (state.pa || 0) - pa);
    paPreleves = pa;
  }

  // E. Deduction du cout personnel (le cas institutionnel a deja ete preleve atomiquement en B)
  if (cost > 0 && payeur === 'joueur') {
    state.arg = Math.max(0, (state.arg || 0) - cost);
  }

  return { ok: true, paPreleves, montantPreleve: cost };
}

function checkMidnight() {
  if (state.hour === 0 && state.minute < 2) {
    if (!state.midnightDone) {
      state.midnightDone = true;
      runMidnightUpdate();
    }
  } else {
    state.midnightDone = false;
  }
}

async function runMidnightUpdate() {
  state.day++;
  state.salaireTouche = false;
  // Traiter les plaintes et enquetes en cours
  traiterPlaintes();
  traiterEnquetes();
  traiterConvocations();
  verifierLiberationPrisonniers();
  verifierDecouverteCrimesPasses();
  // Budget institutions et population
  mettreAJourBudgets();
  mettreAJourPopulation();
  await alimenterBudgets();
  if (typeof verifierEffetsEtDistributionFiscale === 'function') await verifierEffetsEtDistributionFiscale();
  if (typeof traiterVirementJournalierCaserne === 'function') await traiterVirementJournalierCaserne(state.country || 'republic').catch(() => {});
  if (typeof payerSoldeQuotidienne === 'function') await payerSoldeQuotidienne(state.country || 'republic').catch(() => {});
  if (typeof verifierEffetsCouvreFeuQuotidien === 'function') await verifierEffetsCouvreFeuQuotidien(state.country || 'republic').catch(() => {});
  if (typeof verifierRechercheMilitaireQuotidien === 'function') await verifierRechercheMilitaireQuotidien(state.country || 'republic').catch(() => {});
  if (typeof verifierDesertionsQuotidien === 'function') await verifierDesertionsQuotidien(state.country || 'republic').catch(() => {});
  checkScandale();
  checkEffacementCrimes();
  payerInformateurs();
  // Revenus fiscaux
  const pop = CITY_POPULATION[state.country]?.[state.currentCity];
  if (pop) {
    const taxRevenue = pop.dailyTaxRevenue || 0;
    const oilRevenue = pop.oilRevenue || 0;
    const totalRevenue = taxRevenue + oilRevenue;
    if (totalRevenue > 0 && state.poste && ['president','pm','min_fin'].includes(state.poste.id)) {
      addJournalEntry(`Mise a jour minuit : recettes fiscales de ${totalRevenue.toLocaleString('fr-FR')} versees au tresor national.`, 'event-info');
    }
  }
  // Regeneration naturelle des PV si le joueur a ete agresse
  addJournalEntry(`Nouveau jour : Jour ${state.day}. La ville s'eveille.`, 'event-info');
  updateClock();
}

// =====================

// =====================
// UI UPDATE
// =====================
function updateUI() {
  verifierObjectifs();
  const cur = state.char ? (COUNTRIES[state.char.country]?.cur || 'FR') : 'FR';
  // Sauvegarde auto Supabase
  if (typeof sbAutoSave === 'function' && state?.char?.name) sbAutoSave();
  renderEmployesPanel();
  if (typeof renderInventory === 'function') renderInventory();
  // Sauvegarde localStorage — sync état complet
  if (state.char?.name) {
    state.char.poste       = state.poste || null;
    state.char.currentCity = state.currentCity || 'capitale';
    // IMPORTANT : state.currentBuilding est toujours la verite vivante (mise a jour a
    // chaque entree/sortie de batiment ou changement de ville). Le repli vers l'ancienne
    // valeur cachee de char.currentBuilding empechait null (= dans la rue) d'etre jamais
    // reellement sauvegarde, ce qui faisait ressurgir un ancien batiment (parfois d'une
    // autre ville) au moindre rafraichissement de page.
    state.char.currentBuilding = state.currentBuilding || null;
    state.char.currentRoom     = state.currentRoom || null;
    state.char.arg         = state.arg || 0;
    state.char.resources   = { inf: state.inf||0, pop: state.pop||0, dis: state.dis||50 };
    state.char.hp          = state.hp || 100;
    state.char.pa          = state.pa || 10;
    state.char.moral       = state.moral || 75;
    try {
      localStorage.setItem('respublica_char_' + state.char.name, JSON.stringify(state.char));
      localStorage.setItem('respublica_char', JSON.stringify(state.char));
    } catch(e) {}
  }
  document.getElementById('r-pa').textContent   = TEST_MODE ? '∞' : state.pa;
  document.getElementById('b-pa').style.width   = TEST_MODE ? '100%' : (state.pa / state.paMax * 100) + '%';
  document.getElementById('r-arg').textContent  = state.arg.toLocaleString('fr-FR') + ' ' + cur;
  document.getElementById('r-inf').textContent  = state.inf;
  document.getElementById('b-inf').style.width  = state.inf + '%';
  document.getElementById('r-pop').textContent  = state.pop;
  document.getElementById('b-pop').style.width  = state.pop + '%';
  document.getElementById('r-dis').textContent  = state.dis;
  document.getElementById('b-dis').style.width  = state.dis + '%';
  document.getElementById('r-hp').textContent   = state.hp;
  document.getElementById('b-hp').style.width   = state.hp + '%';
  document.getElementById('r-moral').textContent = state.moral;
  document.getElementById('b-moral').style.width  = state.moral + '%';

  // Badge mail
  const unread = (state.mails || []).filter(m => !m.read).length;
  const badge = document.getElementById('mail-badge');
  if (badge) {
    badge.textContent = unread;
    badge.style.display = unread > 0 ? 'inline' : 'none';
  }

  // Indices nationaux dans topbar (calcules -- moyenne des villes pour Republia)
  const pays = state.country || 'republic';
  const idx = (typeof getIndiceNationalCalcule === 'function')
    ? { ISN: getIndiceNationalCalcule(pays,'isn'), IE: getIndiceNationalCalcule(pays,'ie'), ID: INDICES_NATIONAUX?.[pays]?.ID ?? 40 }
    : ((typeof INDICES_NATIONAUX !== 'undefined') ? (INDICES_NATIONAUX[pays] || {ISN:30,IE:50,ID:40,IS:45}) : {ISN:30,IE:50,ID:40,IS:45});
  const setIdx = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = val; };
  setIdx('idx-isn', idx.ISN);
  setIdx('idx-ie',  idx.IE);
  setIdx('idx-id',  idx.ID);
  setIdx('idx-is',  idx.IS);
  // Nom de l'empire
  const indicesBar = document.getElementById('indices-bar');
  if (indicesBar) {
    const nomSpan = indicesBar.querySelector('span');
    if (nomSpan) nomSpan.textContent = COUNTRIES[pays]?.n || 'Republia';
    indicesBar.title = 'Indices de ' + (COUNTRIES[pays]?.n || 'Republia') + ' — cliquer pour details';
  }

  // Inventaire
  document.getElementById('inv-liquide').textContent = state.liquide.toLocaleString('fr-FR') + ' ' + cur;
  document.getElementById('inv-banque').textContent  = state.banque.toLocaleString('fr-FR') + ' ' + cur;
  if (typeof renderInventory === 'function') renderInventory();
}

function updateLocationDisplay() {
  const world = WORLD[state.country];
  const city = world?.[state.currentCity];
  const co = COUNTRIES[state.country];

  document.getElementById('loc-city').textContent = `${city?.name || ''}, ${co?.n || ''}`;

  if (!state.currentBuilding) {
    document.getElementById('loc-name').textContent = 'Dans la rue';
    document.getElementById('loc-sub').textContent = 'Selectionnez un batiment';
  }
}

// =====================
// TOAST & JOURNAL
// =====================
function showToast(result, msg, success, isCrit) {
  const t = document.getElementById('result-toast');
  t.className = isCrit ? 'toast-crit' : success ? 'toast-success' : 'toast-fail';
  document.getElementById('toast-result').textContent = result;
  document.getElementById('toast-sub').textContent = msg;
  t.style.display = 'block';
  clearTimeout(window._toastTimer);
  window._toastTimer = setTimeout(() => { t.style.display = 'none'; }, 3800);
}

function addJournalEntry(text, cls) {
  const j = document.getElementById('journal');
  const h = String(state.hour).padStart(2,'0');
  const div = document.createElement('div');
  div.className = 'journal-entry';
  div.innerHTML = `<span class="journal-time">Jour ${state.day} · ${h}h00</span>
    <span class="journal-text ${cls||''}">${text}</span>`;
  j.insertBefore(div, j.firstChild);

  // Persistance (10 aout 2026) : conserve les 120 dernieres entrees, la plus recente en tete
  // (unshift). Vit uniquement sur state.char.journal, jamais de miroir state.journal separe --
  // deliberement, pour ne pas reproduire le bug de state.arg (valeur correcte ecrasee par un
  // defaut faute d'etre resynchronisee vers state.char avant sauvegarde).
  if (state.char) {
    if (!Array.isArray(state.char.journal)) state.char.journal = [];
    state.char.journal.unshift({ day: state.day, hour: state.hour, text, cls: cls || '' });
    if (state.char.journal.length > 120) state.char.journal.length = 120;
  }

  // Signaler les evenements importants (mauvaises nouvelles, événements externes)
  const important = ['event-bad', 'event-secret', 'event-external'];
  if (important.includes(cls) && typeof signalerEvenementJournal === 'function') {
    signalerEvenementJournal();
  }
}

// Reinjecte les entrees de journal personnel persistees (state.char.journal, jusqu'a 120)
// dans le panneau #journal au chargement -- appelee a la fois apres la restauration rapide
// depuis localStorage et apres la fusion Supabase (voir loadCharacter), pour refleter la
// version la plus a jour dans les deux cas.
function restaurerJournal(char) {
  const j = document.getElementById('journal');
  if (!j || !Array.isArray(char?.journal)) return;
  j.innerHTML = '';
  char.journal.forEach(entry => {
    const h = String(entry.hour ?? 0).padStart(2, '0');
    const div = document.createElement('div');
    div.className = 'journal-entry';
    div.innerHTML = `<span class="journal-time">Jour ${entry.day} · ${h}h00</span>
      <span class="journal-text ${entry.cls || ''}">${entry.text}</span>`;
    j.appendChild(div);
  });
}

// Close modals on overlay click
