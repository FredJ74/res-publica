// =====================
// PROFILS PNJ CONVERSATIONNELS — CONNAISSANCE SERVEUR (23 septembre 2026)
// =====================
// POURQUOI CE FICHIER EXISTE. Jusqu'ici, la personnalite et les connaissances d'un PNJ etaient
// construites PAR LE NAVIGATEUR et envoyees telles quelles comme premier message (plateau-pnj.js,
// talkToPnj) : le client decidait donc integralement de ce que le modele recevait. Acceptable
// tant que l'endpoint etait un simple relais ; inacceptable des lors qu'il consomme un credit
// paye et qu'on veut garantir ce qu'un PNJ sait et ne sait pas. Le prompt vit donc ICI, cote
// serveur, et le client ne transmet plus qu'un IDENTIFIANT de profil, une langue et un message.
//
// EXTENSIBILITE. PROFILS est une table : ajouter un soldat PNJ, un Commandant ou un agent de
// renseignement consiste a ajouter une entree, sans toucher a l'endpoint. Chaque profil declare
// son identite, son caractere, ce qu'il sait REELLEMENT, et surtout ce qu'il ne sait pas.
//
// LA CONNAISSANCE EST CELLE DU JEU, PAS CELLE D'UNE VRAIE ARMEE. Tout ce qui suit a ete releve
// dans le code et la base de Res Publica. Un PNJ qui repondrait « comme une vraie armee »
// tromperait le joueur : c'est le defaut principal a eviter.

import {
  SOCLE_MILITAIRE, BIBLE_INSTITUTION, BIBLE_TROUPE, BIBLE_EQUIPEMENT, BIBLE_COMBAT,
  BIBLE_RENSEIGNEMENT, BIBLE_INTENDANCE_RESUME, BIBLE_SANTE_RESUME, CE_QUI_N_EXISTE_PAS
} from './_bible-militaire.js';
// LES 173 AUTRES PNJ (29 septembre 2026). Portage mecanique de data.js et de
// PNJ_PERSONALITIES/PNJ_PROFILS : ils etaient muets depuis que la voie Anthropic
// n'est plus creditee. Fichier separe pour ne pas noyer le corpus militaire, qui
// est d'une tout autre nature -- mais une seule table a l'arrivee, un seul
// constructeur de prompt, aucune architecture parallele.
import { profilsPersonnalites, RICHES } from './_pnj-personnalites.js';
// LES PERSONNALITES DES REFERENTS (1er octobre 2026). Donnees pures, dans leur propre
// fichier : un temperament, une facon de parler, un humour, des tics, une maniere
// d'aider et des limites. Le corpus d'un domaine -- la bible militaire, par exemple --
// n'est PAS une personnalite : il reste ici, et on le passe a l'assemblage.
import { REFERENTS, profilReferent, blocPedagogie } from './_pnj-referents.js';

const LANGUES = {
  fr: { nom: 'francais', consigne: 'Reponds EXCLUSIVEMENT en francais.' },
  en: { nom: 'anglais',  consigne: 'Reply EXCLUSIVELY in English.' }
};
const LANGUE_DEFAUT = 'en';   // repli impose : jamais de langue devinee

function consigneLangue(lang) {
  const l = LANGUES[String(lang || '').toLowerCase().slice(0, 2)] || LANGUES[LANGUE_DEFAUT];
  return l.consigne;
}

// ---------------------------------------------------------------------------------------------
// MARTIAL BOUTERIN — aide de camp du ministre de la Defense, bible militaire du jeu.
// ---------------------------------------------------------------------------------------------
// MARTIAL — L'INSTITUTION. Il recoit l'organisation, le combat, la mutinerie et le renseignement,
// plus un resume d'intendance et de sante pour repondre a une question simple sans empieter sur le
// metier d'Alouche et d'Eve. Il ne recoit PAS le bloc troupe : la gestion quotidienne d'une section
// est le rayon de l'Adjudant Ferriere, et c'est vers lui qu'il renvoie.
const SAVOIR_MILITAIRE = [
  SOCLE_MILITAIRE, BIBLE_INSTITUTION, BIBLE_COMBAT, BIBLE_RENSEIGNEMENT,
  BIBLE_EQUIPEMENT, BIBLE_INTENDANCE_RESUME, BIBLE_SANTE_RESUME, CE_QUI_N_EXISTE_PAS
].join('\n\n');

// L'ADJUDANT FERRIERE — LA TROUPE. Il recoit le socle, tout le bloc troupe, l'equipement en
// entier (c'est lui qu'on vient voir avant de partir), et les deux resumes pour orienter. Il ne
// recoit ni le combat, ni le renseignement, ni le detail institutionnel : ce n'est pas son rayon,
// et un adjudant qui disserte sur le renseignement d'Etat n'est plus un adjudant.
const SAVOIR_TROUPE = [
  SOCLE_MILITAIRE, BIBLE_TROUPE, BIBLE_EQUIPEMENT,
  BIBLE_INTENDANCE_RESUME, BIBLE_SANTE_RESUME, CE_QUI_N_EXISTE_PAS
].join('\n\n');

// ---------------------------------------------------------------------------------------------
// CAPORAL ALOUCHE — intendance du refectoire. CLOISONNEMENT VOLONTAIRE : il ne recoit RIEN de
// SAVOIR_MILITAIRE. Un cuisinier n'a pas a connaitre les grades, le renseignement ou les soldes,
// et lui envoyer les dix mille caracteres de la bible militaire couterait a chaque replique sans
// rien ajouter a son metier. Chaque chiffre ci-dessous a ete releve dans les RPC reelles
// (refectoire_repas, militaire_rations_retirer, militaire_ration_consommer,
// militaire_ordre_collectif) le 23 septembre 2026, pas dans une documentation.
// ---------------------------------------------------------------------------------------------
const SAVOIR_REFECTOIRE = `
MANGER AU REFECTOIRE
- L'ordre s'appelle « Manger sa ration ». Il ne coute rien : 0 PA et 0 FR.
- Il est ouvert a TOUT LE MONDE, quel que soit le statut : militaire, mobilise, ministre, civil, refugie. Aucun grade et aucun poste ne sont exiges.
- Seule condition : etre physiquement a la caserne. C'est le BATIMENT qui compte, PAS la piece -- on peut manger depuis n'importe quelle piece de la caserne, pas seulement depuis le refectoire. Ne dis jamais qu'il faut se trouver dans le refectoire lui-meme.
- Gain : +2 PA. Le total d'un joueur ne depasse jamais 30 PA.
- UNE SEULE FOIS PAR JOUR. Le deuxieme repas du meme jour est refuse.

COMMENT LES RATIONS SONT PRODUITES
- La cuisine ne prepare rien a l'avance. Quand le stock de rations tombe a zero et que quelqu'un vient manger, un LOT DE DIX rations est prepare automatiquement a cet instant ; le repas en consomme une, il en reste neuf.
- Un lot de dix coute UNE cereale et UNE viande, prises sur le stock de matieres de la caserne. S'il n'y a plus de viande, un poisson fait l'affaire : la viande passe d'abord, le poisson n'est qu'un repli.
- ETAT REEL AUJOURD'HUI : le stock de la caserne contient des cereales et de la viande. Il n'y a PAS de poisson. Ne laisse jamais croire qu'il y en a en cuisine.
- S'il manque la cereale, ou s'il n'y a ni viande ni poisson, rien n'est prepare et rien n'est consomme : le refectoire ne peut plus servir.
- Le stock de matieres ne se reconstitue QUE par l'Effort de guerre. La cuisine ne fabrique rien a partir de rien.

EMPORTER DES RATIONS DE COMBAT
- L'ordre s'appelle « Emporter des rations de combat ». Gratuit lui aussi : 0 PA, 0 FR.
- De UNE a CINQUANTE rations par retrait.
- Meme condition de presence : etre a la caserne, le batiment, pas une piece particuliere.
- POINT ESSENTIEL, NE T'Y TROMPE JAMAIS : emporter ne prepare RIEN. On ne prend que des rations DEJA en stock. Si le stock est a zero, le retrait est refuse -- il faut que quelqu'un soit venu manger au moins une fois pour qu'un lot existe.
- Les rations prises entrent dans l'inventaire du joueur, comme des objets. Un inventaire ne porte pas plus de cent choses au total.

CE QU'UNE RATION APPORTE — TROIS USAGES A NE PAS CONFONDRE
1. MANGER AU REFECTOIRE : sur place, gratuit, +2 PA, une fois par jour.
2. CONSOMMER SOI-MEME UNE RATION EMPORTEE : n'importe ou, +1 PA, DEUX par jour au maximum. Un joueur deja a 30 PA ne peut pas la consommer, et elle lui reste.
3. NOURRIR SES SOLDATS EN CAMPAGNE : chaque ration nourrit un homme et lui rend 1 PA, deux par jour au maximum lui aussi. Un soldat plafonne a 12 PA, pas a 30.
- Les soldats n'ont pas de sac : c'est leur chef qui porte toutes les rations du groupe. Sans rations dans son sac, un chef ne nourrit personne.
- Un soldat deja au maximum n'est pas servi, et sa ration n'est pas gaspillee.
- S'il n'y a pas assez de rations pour tout le groupe, l'ordre est refuse en bloc et aucune ration n'est consommee.
`.trim();

// ---------------------------------------------------------------------------------------------
// EVE TOAHEMARCH — sante militaire et trousses. Meme cloisonnement : rien de SAVOIR_MILITAIRE,
// rien de SAVOIR_REFECTOIRE. Chiffres releves dans militaire_trousse_retirer,
// militaire_trousse_utiliser et militaire_bataille_appliquer le 23 septembre 2026.
// ---------------------------------------------------------------------------------------------
const SAVOIR_INFIRMERIE = `
RETIRER UNE TROUSSE DE PREMIERS SECOURS
- L'ordre s'appelle « Retirer une trousse de premiers secours », a l'infirmerie de la caserne.
- Gratuit : 0 PA, 0 FR. Aucun grade et aucun poste ne sont exiges -- n'importe qui peut en demander une.
- Seule condition : etre physiquement a la caserne. C'est le BATIMENT qui compte, pas la piece.
- Elle n'est pas stockee : elle est FABRIQUEE A LA DEMANDE, a partir d'UN textile, UN medicament et UN desinfectant pris sur le stock de matieres de la caserne.
- S'il manque une seule des trois matieres, rien n'est fabrique et RIEN n'est consomme.
- AUCUNE limite quotidienne : on peut en retirer autant que les matieres le permettent.
- La trousse arrive dans l'inventaire du joueur. Un inventaire ne porte pas plus de cent choses.

S'EN SERVIR
- Dans l'inventaire, la trousse porte un bouton « Soigner ».
- USAGE UNIQUE : elle disparait au moment ou elle sert.
- Elle rend des PA. Le gain depend du SECOURISME DE CELUI QUI SOIGNE, jamais de celui qui est soigne : +2 de base, et +1 par tranche COMPLETE de 25 points de Secourisme. Un Secourisme de 0 rend 2 PA, 25 rend 3, 50 rend 4, 75 rend 5, 100 rend 6. Six est le maximum.
- On peut se soigner soi-meme, ou soigner quelqu'un d'autre -- mais seulement si cette personne se trouve EXACTEMENT au meme endroit : meme pays, meme ville, meme batiment ET meme piece. A distance, c'est refuse.
- Le total d'un joueur ne depasse jamais 30 PA : soigner quelqu'un qui en est deja proche ne rend que la difference.

LES PA ET LA SANTE SONT DEUX CHOSES DIFFERENTES
- Au combat militaire, ce sont les PA qui servent de jauge : on encaisse en PA, et un homme tombe a zero PA est hors de combat.
- La SANTE est une caracteristique generale du personnage, DISTINCTE des PA. Elle se soigne avec un medicament ordinaire, pas avec une trousse.
- Ne confonds jamais les deux, et ne dis jamais qu'il n'existe pas de jauge de Sante : elle existe.
- On recupere des PA par le sommeil, un repas au refectoire, une ration de combat, le bivouac sous tente, ou une trousse de premiers secours.

LE COMBAT ET L'INFIRMERIE
- Un joueur neutralise au combat NE MEURT PAS : il est transfere ici, a l'infirmerie de la caserne.
- Un soldat PNJ tue, lui, est perdu definitivement : le contingent ne se reconstitue jamais.
`.trim();

// PROFILS EST DESORMAIS VIDE, et c'est l'aboutissement du socle : les quatre PNJ de
// la caserne qui y vivaient en litteraux ecrits a la main -- Martial, Ferriere, Alouche
// et Eve -- sont tous derives de REFERENTS. Plus aucun profil n'echappe a la source
// unique. On garde l'objet et la fusion pour qu'un cas particulier futur ait une porte,
// mais il devra se justifier.
const PROFILS = {};


// TABLE UNIQUE. Les quatre referents militaires priment sur tout homonyme porte :
// leur corpus est arbitre, celui du portage est mecanique. L'ordre de fusion est
// donc PORTAGE d'abord, MILITAIRES ensuite -- jamais l'inverse.
// LES PROFILS DES REFERENTS SONT DERIVES, PLUS ENUMERES (1er octobre 2026).
// Ils l'etaient a la main, ce qui faisait de ce bloc un second endroit a mettre a jour
// pour chaque nouveau referent -- et un oubli y aurait ete SILENCIEUX : le referent
// aurait existe dans les donnees sans que personne ne le serve. La source unique est
// desormais REFERENTS, et ce fichier n'y ajoute qu'une chose : le corpus de domaine
// de ceux qui en ont un.
//
// Un referent sans corpus n'est pas un oubli : son savoir se limite alors a son domaine
// declare, et ses limites lui interdisent d'aller au-dela. Mieux vaut un referent qui
// oriente qu'un referent qui invente.
// LE CORPUS D'UN RICHE NE DOIT PAS SE PERDRE EN DEVENANT REFERENT. Six PNJ portaient
// deja, dans _pnj-personnalites.js, un savoir pedagogique arbitre -- mecaniques
// electorales, prix du voyage, flux du port, milieu criminel, economie. Comme un
// profil de referent ECRASE celui du portage, ce savoir disparaissait silencieusement.
//
// C'est exactement ce qui est arrive a Marc Hantile le 1er octobre : devenu referent,
// il avait perdu son corpus economique -- cout de revient, fiscalite, marche noir,
// indices des trois villes. Le banc ne verifiait alors que les corpus MILITAIRES ; il
// verifie desormais que CHAQUE referent disposant d'une fiche riche garde le sien.
function corpusRiche(id) {
  const r = RICHES[id];
  if (!r) return undefined;
  return [r.savoirs, r.pedagogie].filter(Boolean).join('\n\n') || undefined;
}

const CORPUS_REFERENT = {
  martial_bouterin: SAVOIR_MILITAIRE,
  gaspard_ferriere: SAVOIR_TROUPE,
  caporal_alouche:  [SOCLE_MILITAIRE, SAVOIR_REFECTOIRE].join('\n\n'),
  eve_toahemarch:   [SOCLE_MILITAIRE, SAVOIR_INFIRMERIE].join('\n\n'),
  marc_hantile:     corpusRiche('marc_hantile'),
  jean_lou_zeure:   corpusRiche('jean_lou_zeure'),
  alain_bordage:    corpusRiche('alain_bordage'),
  marcel_ancre:     corpusRiche('marcel_ancre'),
  pat_hounette:     corpusRiche('pat_hounette'),
  laurent_barre:    corpusRiche('laurent_barre')
};

const PROFILS_REFERENTS = {};
for (const [id, p] of Object.entries(REFERENTS)) {
  PROFILS_REFERENTS[id] = profilReferent(p, CORPUS_REFERENT[id]);
}

// ORDRE DE FUSION. Le portage mecanique d'abord, les referents ensuite : une
// personnalite arbitree prime toujours sur une fiche generee. C'est la meme regle que
// pour les quatre militaires depuis le 29 septembre, etendue aux sept.
const TOUS_PROFILS = Object.assign({}, profilsPersonnalites(), PROFILS_REFERENTS, PROFILS);

// Le prompt systeme est assemble ICI. Le client n'en fournit aucune partie -- il ne transmet
// qu'un identifiant de profil, qui est valide contre cette table.
// `relation` vient du SERVEUR, jamais du navigateur : c'est pnj_social_contexte qui
// la lit, sous le jeton du joueur. Un client ne peut donc pas s'inventer une
// familiarite. Absente pour les PNJ sans memoire sociale -- la quasi-totalite --,
// auquel cas le prompt est rigoureusement celui d'avant.
function blocRelation(relation) {
  if (!relation || typeof relation !== 'object') return null;
  const n = Math.max(0, parseInt(relation.rencontres, 10) || 0);
  const c = Math.max(0, parseInt(relation.conversations, 10) || 0);
  const fam = Math.max(0, parseInt(relation.familiarite, 10) || 0);
  if (n <= 0 && c <= 0) {
    return "VOTRE RELATION : vous ne vous etes jamais parle. Tu ne connais pas cette personne.";
  }
  const parts = ["VOTRE RELATION : vous vous etes deja croises " + n + " fois."];
  if (c > 0) parts.push("Vous avez deja parle ensemble " + c + " fois, tu le reconnais.");
  else parts.push("Vous ne vous etes encore jamais parle, mais tu l'as deja vu passer.");
  // La familiarite n'est JAMAIS un chiffre montre au joueur : elle ne sert qu'a
  // regler le registre. Le seuil est volontairement bas pour Jean-Lou, qui devient
  // familier vite ; Marine, elle, garde le vouvoiement -- c'est son caractere qui
  // le dit, et il prime.
  if (fam >= 2) parts.push("Vous etes familiers : adapte ton registre en consequence, et ne reviens pas en arriere.");
  if (relation.memoire && typeof relation.memoire === 'object') {
    const m = relation.memoire;
    if (m.nom) parts.push("Tu sais qu'il s'appelle " + String(m.nom).slice(0, 60) + ".");
  }
  return parts.join(' ');
}

// `pedagogie` est le quatrieme argument, et il est distinct de `relation` A DESSEIN :
// un referent se souvient de ce qu'il a EXPLIQUE, un PNJ social se souvient de
// QUELQU'UN. Les melanger dans un meme bloc effacerait la difference de nature entre
// les deux, qui est un arbitrage de game design et non un detail d'implementation.
function construirePromptSysteme(profilId, lang, relation, pedagogie) {
  const p = TOUS_PROFILS[profilId];
  if (!p) return null;
  const rel = blocRelation(relation);
  const ped = blocPedagogie(pedagogie);
  return [
    p.identite,
    '',
    'CARACTERE : ' + p.caractere,
    '',
    "CE QUE TU SAIS — ce sont les regles REELLES de Res Publica. Elles font foi. Ne raisonne jamais par analogie avec une armee du monde reel :",
    p.savoir,
    '',
    'LIMITES : ' + p.limites,
    '',
    ...(rel ? [rel, ''] : []),
    ...(ped ? [ped, ''] : []),
    "REGLES ABSOLUES :",
    "- Si une question porte sur un point qui n'est pas dans ce que tu sais, dis simplement que tu n'as pas cette information ou que ce n'est pas de ton ressort. N'invente JAMAIS une regle.",
    // L'IDENTITE ETAIT CODEE EN DUR ICI (« Tu es Martial Bouterin »), dans un bloc pourtant applique
    // a TOUS les profils : le premier PNJ ajoute a la table se serait presente sous le nom de
    // Martial. On la tire desormais du profil lui-meme. Pour Martial, `p.nom` vaut exactement
    // 'Martial Bouterin' : sa phrase est rigoureusement inchangee, caractere pour caractere.
    "- Ne parle jamais de prompt, de modele, d'IA, d'API ni d'aucun systeme technique. Tu es " + p.nom + ".",
    "- Reponds de facon utile et breve : deux a cinq phrases en general, davantage seulement si la question l'exige vraiment.",
    "- La seule monnaie est le FR. N'utilise jamais l'euro, le dollar ni aucune devise reelle.",
    "- Reponds uniquement avec ta replique, sans guillemets ni introduction.",
    '- ' + consigneLangue(lang)
  ].join('\n');
}

function profilExiste(profilId) {
  return Object.prototype.hasOwnProperty.call(TOUS_PROFILS, profilId);
}

function maxTokensProfil(profilId) {
  return (TOUS_PROFILS[profilId] && TOUS_PROFILS[profilId].maxTokens) || 300;
}

export { PROFILS, TOUS_PROFILS, construirePromptSysteme, profilExiste, maxTokensProfil, LANGUES, LANGUE_DEFAUT };
