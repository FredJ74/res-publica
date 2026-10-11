// BANC DE L'ECRAN DE SEANCE PARLEMENTAIRE (11 octobre 2026)
// SOURCES: data.js plateau-assemblee-seance.js
//
// CE QUE CE BANC PROUVE, ET POURQUOI IL EXISTE. Le serveur de la seance est couvert par deux bancs
// SQL. Ce qui n'y est PAS couvert, c'est ce que l'ECRAN dit et transmet -- or c'est la que les
// interdits de l'arbitrage sont les plus faciles a violer sans s'en apercevoir : il suffit d'une
// couleur accusatrice, d'un compteur d'incivilites, ou d'un bouton qui envoie le parti du joueur.
//
//   . L'ECRAN NE DECIDE RIEN. Il ne calcule ni la qualification d'une protestation, ni le parti,
//     ni la popularite : il transmet une intention et affiche ce que la base rend.
//   . IL NE QUALIFIE RIEN. Une intervention sans la parole est marquee « hors tour de parole » --
//     un FAIT -- et aucun mot de jugement n'apparait nulle part.
//   . IL ANNONCE LE PRIX AVANT LE CLIC. Les trois couts sont ecrits, une seule fois chacun.
//   . IL PASSE PAR LE SOCLE EXISTANT : assembleeActionServeur / assembleeIssueAction, donc clics
//     serialises, rejeu d'une reponse perdue, et recopie de l'etat serveur.
//   . ET LES TEXTES JOUEURS NE SONT JAMAIS INTERPRETES : textContent partout, innerHTML nulle part
//     sur un nom, un motif ou une intervention.
//
// Usage : python3 outils/bancs/lancer-banc.py outils/bancs/banc-seance-client.js
var ok = 0, ko = 0;
function att(n, c, d) { if (c) { print('  ok  ' + n); ok++; } else { print('  *** ' + n + (d !== undefined ? ' -- ' + d : '')); ko++; } }
var RACINE = '/Users/fredericjasseron/ResPublica/';
var SRC = readFile(RACINE + 'plateau-assemblee-seance.js');
// LE CODE SEUL, SANS LES COMMENTAIRES. Un interdit nomme dans un commentaire ne doit pas faire
// passer -- ni echouer -- une contre-epreuve : c'est le piege classique de ces bancs.
var CODE = SRC.split('\n').filter(function (l) { return !/^\s*(\/\/|\*|\/\*)/.test(l); }).join('\n');
function dans(s, f) { return String(s).indexOf(f) >= 0; }

print('');
print("L'ORDRE EXISTE DANS LES DEUX PIECES, ET NE COUTE RIEN");
print('============================================================');
var hemi = BUILDINGS['assemblee'].rooms['hemicycle'];
var hall = BUILDINGS['assemblee'].rooms['accueil_assemblee'];
function ordre(salle) {
  return (salle.orders || []).filter(function (o) { return o.fn === 'seance_parlementaire'; })[0];
}
var oh = ordre(hemi), oa = ordre(hall);
att("l'hemicycle porte l'ordre de seance", !!oh);
// LE HALL AUSSI, ET C'EST INDISPENSABLE : un depute sorti en protestation se trouve la, et c'est
// de la qu'il doit pouvoir revenir. Sans cet ordre, il serait bloque dehors.
att("le hall porte l'ordre de seance (retour du protestataire)", !!oa);
att("l'ecran ne coute aucun PA", oh && oh.pa === 0 && oa && oa.pa === 0);
att("l'ecran ne coute aucun argent", oh && oh.cost === 0 && oa && oa.cost === 0);
att("l'ecran n'exige aucun poste (le serveur decide des droits)",
    oh && !oh.requiresPost && oa && !oa.requiresPost);

print('');
print('AUCUNE DECISION DE JEU NE SE PREND DANS LE NAVIGATEUR');
print('============================================================');
// LA PROTESTATION NE TRANSMET RIEN. C'est la garantie la plus simple a verifier et la plus
// importante : s'il n'y a pas de parametre, il n'y a rien a mentir.
att('la protestation est appelee sans aucun argument',
    dans(CODE, 'sbAssembleeProtester()'));
att('le retour est appele sans aucun argument',
    dans(CODE, 'sbAssembleeRevenir()'));
att("l'ecran ne calcule jamais la qualification d'une protestation",
    !/qualifie\s*=/.test(CODE) && !/qualifie\s*:/.test(CODE));
att("l'ecran ne calcule jamais le parti d'un depute",
    !/parti\s*=\s*(?!=)/.test(CODE.replace(/mon_parti/g, '')));
att("l'ecran ne calcule aucune popularite",
    !/pop\s*[-+]?=/.test(CODE));
att("l'ecran ne decide pas qui a la parole : il lit l'etat serveur",
    dans(CODE, 'e.orateur') && !/a_la_parole\s*=/.test(CODE));
// LE PRESIDENT NE CHOISIT PAS SON ORATEUR : l'ecran ne propose que le premier de la file, et le
// serveur refuse tout autre nom de toute facon.
att('le bouton de parole ne propose que le PREMIER de la file',
    dans(CODE, 'RP_SEANCE_ETAT.file[0].depute'));

print('');
print('AUCUNE QUALIFICATION, AUCUN SCORE, AUCUN COMPTEUR MORAL');
print('============================================================');
var MOTS = ['abusif', 'abusive', 'justifie', 'injustifie', 'mensonger', 'autoritaire',
            'scandaleux', 'arbitraire', 'illegitime', 'incivilite', 'gravite'];
MOTS.forEach(function (m) {
  att("l'ecran n'affiche jamais le mot « " + m + " »",
      !new RegExp(m, 'i').test(CODE), m);
});
att("aucun score ni jauge de sympathie",
    !/score|sympathie|reputation|karma/i.test(CODE));
att("aucun compteur d'actes par depute",
    !/nbRappels|compteurRappels|totalSanctions/.test(CODE));

print('');
print('LE FAIT EST DIT, ET IL EST DIT COMME UN FAIT');
print('============================================================');
// « hors tour de parole » : la marque EXACTE. Elle dit ce qui s'est passe -- il a parle sans que
// la parole lui ait ete donnee -- et rien de plus.
att("une intervention sans la parole est marquee « hors tour de parole »",
    dans(SRC, 'hors tour de parole'));
att('la marque vient du fait serveur `autorise`, pas d\'un calcul local',
    dans(CODE, 'x.autorise') && dans(CODE, "sc-hors"));
att("le President, qui parle de droit, n'est jamais marque",
    dans(CODE, "x.fonction !== 'president_assemblee'"));
att("une sortie non qualifiee est annoncee comme telle, sans reproche",
    dans(SRC, 'elle ne compte pas dans le seuil de suspension'));
att("le seuil de suspension est affiche comme un fait, pas comme une menace",
    dans(CODE, 'e.seuil_suspension'));
att("le compteur d'episodes est affiche et ne declenche rien",
    dans(CODE, 'episodes_sous_cette_presidence')
    && !/nouvelleElection|declencherElection|vacance/i.test(CODE));

print('');
print('LE PRIX EST ANNONCE AVANT LE CLIC');
print('============================================================');
// LES CHAINES SONT ACCENTUEES, ET L'APOSTROPHE EST ECHAPPEE DANS LA SOURCE. Chercher
// « popularite » ou « d'une semaine » ne trouverait rien : piege deja rencontre sur ce depot.
att('le rappel annonce 15 points de popularite', dans(SRC, '15 points de popularité'));
att('la sanction annonce 20 points et 100 FR',
    dans(SRC, '20 points de popularité et 100 FR'));
att('la suspension annonce 20 points', dans(SRC, 'Vous perdez 20 points de popularité'));
att("le report annonce une semaine", dans(SRC, 'est repoussée d') && dans(SRC, 'une semaine'));
att('le motif est annonce OBLIGATOIRE pour un rappel et une sanction',
    dans(SRC, 'Motif (obligatoire)'));
att('et FACULTATIF pour une suspension', dans(SRC, 'Motif (facultatif)'));
att("l'ecran dit que le motif sera conserve mot pour mot",
    dans(SRC, 'conservé mot pour mot'));

print('');
print('TOUT PASSE PAR LE SOCLE EXISTANT');
print('============================================================');
att('les actions passent par assembleeActionServeur',
    dans(CODE, 'assembleeActionServeur('));
att('les retours passent par assembleeIssueAction',
    dans(CODE, 'assembleeIssueAction('));
// LES CINQ PORTES A EFFET RECOIVENT LA CLEF DE REQUETE. Sans elle, le serveur refuse -- et c'est
// ce qui rend le rejeu d'une reponse perdue sans danger.
['sbAssembleeDire', 'sbAssembleeRappeler', 'sbAssembleeSanctionner',
 'sbAssembleeSuspendreSeance', 'sbAssembleeReporterVote'].forEach(function (f) {
  att(f + ' recoit la clef de requete',
      new RegExp(f + '\\([^)]*\\b(rq|requete)\\b').test(CODE), f);
});
att("l'ecran ne construit JAMAIS sa propre clef de requete",
    !/rq-/.test(CODE));
att('le deplacement reel passe par enterRoom, le socle de navigation',
    dans(CODE, "enterRoom('assemblee'"));
att('la position affichee est celle que le serveur renvoie',
    dans(CODE, "res.piece"));

print('');
print("LES TEXTES DES JOUEURS NE SONT JAMAIS INTERPRETES");
print('============================================================');
// textContent partout. Un motif de rappel est ecrit par un joueur : en innerHTML, il injecterait
// du balisage dans l'ecran de tous les autres.
att('le texte du debat est pose en textContent', dans(CODE, 'txt.textContent = x.texte'));
att("le nom de l'auteur est pose en textContent", dans(CODE, 'qui.textContent = x.auteur'));
att('les lignes laterales sont posees en textContent', dans(CODE, 'd.textContent = texte'));
att("les options de liste sont posees en textContent", dans(CODE, 'o.textContent = l'));
// innerHTML n'existe que pour le squelette fixe du cadre, qui ne contient aucune donnee joueur.
var innerHtml = (CODE.match(/innerHTML/g) || []).length;
att("innerHTML n'est utilise qu'une fois, pour le squelette fixe", innerHtml === 1, innerHtml);
att('le squelette ne contient aucune interpolation', !/innerHTML\s*=\s*[^;]*\$\{/.test(CODE));

print('');
print("L'ECRAN SE RAFRAICHIT SANS EFFACER CE QUE LE JOUEUR ECRIT");
print('============================================================');
att('un brouillon de discours survit au rafraichissement',
    dans(CODE, 'RP_SEANCE_BROUILLON'));
att('la veille est arretee a la fermeture', dans(CODE, 'seanceArreterVeille'));
att("la veille s'arrete aussi si l'ecran disparait", dans(CODE, "cadre.style.display === 'none'"));

print('');
print('============================================================');
if (ko === 0) print('LES ' + ok + ' EPREUVES SONT VERTES.');
else print(ko + ' EPREUVES ROUGES SUR ' + (ok + ko) + '.');
