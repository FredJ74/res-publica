// BANC DE L'ELECTION DU PRESIDENT DE L'ASSEMBLEE — COTE ECRAN (11 octobre 2026)
// SOURCES: outils/bancs/decor-window.js data.js plateau-assemblee.js
// Les quatre autres fichiers sont lus comme du TEXTE (readFile), jamais executes : les
// charger reclamerait la moitie du plateau, et ce banc n'a besoin que de leur source.
//
// CE QUE CE BANC TIENT. Le serveur de l'election est couvert par deux bancs SQL. Ce qui n'y est
// pas couvert, c'est ce que l'ECRAN propose et ce qu'il raconte -- et c'est la que les interdits
// de l'arbitrage se violent le plus facilement sans s'en apercevoir :
//
//   . IL N'Y A AUCUNE CANDIDATURE. Les neuf deputes sont eligibles d'office : un bouton « se
//     porter candidat », une liste de candidats, un formulaire -- tout cela serait une regle
//     inventee, et ce banc le refuse.
//   . L'ECRAN NE TIRE JAMAIS LA COURTE PAILLE. Quand l'animation commence, le vainqueur est en
//     base depuis 23 heures. Le halo atterrit sur l'index de l'elu ; il n'y a pas un seul tirage
//     local dans le fichier.
//   . NEUF SIEGES, PAS VINGT-CINQ. L'annuaire listait 25 sieges decoratifs ; il lit desormais la
//     composition reelle.
//   . AUCUN NOM CODE EN DUR. Les pouvoirs suivent le titulaire du registre, jamais « Laroche ».
//
// Usage : python3 outils/bancs/lancer-banc.py outils/bancs/banc-presidence-client.js
var ok = 0, ko = 0;
function att(n, c, d) { if (c) { print('  ok  ' + n); ok++; } else { print('  *** ' + n + (d !== undefined ? ' -- ' + d : '')); ko++; } }
var RACINE = '/Users/fredericjasseron/ResPublica/';
function lire(f) { return readFile(RACINE + f); }
var PRES = lire('plateau-assemblee-presidence.js');
var SEANCE = lire('plateau-assemblee-seance.js');
var ASSEM = lire('plateau-assemblee.js');
var NAV = lire('plateau-navigation.js');
var POLI = lire('plateau-politique.js');
// LE CODE SEUL. Un interdit nomme dans un commentaire ne doit faire ni passer ni echouer une
// contre-epreuve : c'est le piege classique de ces bancs.
function codeSeul(s) {
  return String(s).split('\n').filter(function (l) { return !/^\s*(\/\/|\*|\/\*)/.test(l); }).join('\n');
}
var PRES_CODE = codeSeul(PRES);
var SEANCE_CODE = codeSeul(SEANCE);
var POLI_CODE = codeSeul(POLI);
function dans(s, f) { return String(s).indexOf(f) >= 0; }

print('');
print("AUCUNE CANDIDATURE : LES NEUF SONT ELIGIBLES D'OFFICE");
print('============================================================');
att("aucun bouton « se porter candidat » dans le code de l'ecran",
    !/se porter candidat|deposer.{0,15}candidature|ouvrirCandidature/i.test(PRES_CODE));
// LE MOT « CANDIDATURE » A LE DROIT D'APPARAITRE DANS UNE SEULE PHRASE : celle qui dit qu'il n'y
// en a pas. Le banc compte donc les occurrences, au lieu de les interdire -- interdire le mot
// aurait empeche l'ecran d'expliquer la regle.
att("le mot « candidat » n'apparait que dans la phrase qui le NIE", (function () {
  var m = PRES_CODE.match(/candidat\w*/gi) || [];
  return m.length === 1 && dans(PRES_CODE, "aucune candidature à déposer");
})(), (PRES_CODE.match(/candidat\w*/gi) || []).join(','));
att("aucune porte ni fonction de candidature n'existe",
    !/function\s+\w*andidat|sb\w*Candidat|_candidat\w*\(/.test(PRES_CODE));
// L'APOSTROPHE EST ECHAPPEE DANS LA SOURCE : chercher « d'office » tel quel ne trouverait rien.
// Piege deja rencontre sur ce depot, deux fois.
att("l'ecran dit explicitement que les neuf sont eligibles d'office",
    dans(PRES, 'éligibles d') && dans(PRES, 'office'));
att("le vote se fait sur la liste du SERVEUR, pas sur une liste locale",
    dans(PRES_CODE, 's.decompte') && dans(PRES_CODE, 's.eligibles'));

print('');
print("L'ECRAN NE TIRE JAMAIS LA COURTE PAILLE");
print('============================================================');
// LE POINT CENTRAL DE L'ARBITRAGE. Un seul Math.random dans ce fichier, et le resultat
// deviendrait local -- donc different a chaque rafraichissement.
att("aucun tirage local : pas un seul Math.random dans le fichier",
    !/Math\.random/.test(PRES));
att("le vainqueur vient de la base (`scrutin.elu`)", dans(PRES_CODE, 'scrutin.elu'));
att("le halo atterrit sur l'index de l'elu, calcule et non tire",
    dans(PRES_CODE, 'pailles.indexOf(gagnant)'));
att("le nombre de pailles est celui des ex aequo rendus par le serveur",
    dans(PRES_CODE, 'scrutin.egalite'));
att("une egalite de moins de deux noms n'anime rien",
    dans(PRES_CODE, 'scrutin.egalite.length < 2'));
att("une incoherence annonce sans animer, plutot que de mentir",
    dans(PRES_CODE, 'iGagnant < 0'));
att("le halo RALENTIT : le pas s'allonge a l'approche",
    dans(PRES_CODE, 'PRESIDENCE_PAS_MAX_MS') && dans(PRES_CODE, 'Math.pow(t'));
att("la paille gagnante se revele COURTE a la fin, et pas avant",
    dans(PRES_CODE, "classList.add('pr-courte')"));

print('');
print('AUCUN ASSET GRAPHIQUE INVENTE');
print('============================================================');
att("la main et les pailles sont dessinees en CSS, sans image",
    dans(PRES, '.pr-poing') && dans(PRES, '.pr-brin')
    && !/\.png|\.jpg|\.webp|background-image/i.test(PRES));

print('');
print("LA REVELATION DIFFEREE, ET L'ETAT « DEJA VU » EST SERVEUR");
print('============================================================');
att("le crochet d'entree est branche sur declencherEntreeZone",
    dans(NAV, 'presidenceEntreeZone(buildingId, roomId)'));
att("il est le SIXIEME consommateur du meme evenement, pas un crochet de plus",
    dans(NAV, '6. L\'ELECTION DU PRESIDENT'));
att("no-op immediat hors de l'Assemblee", dans(PRES_CODE, "buildingId !== 'assemblee'"));
att("et hors de ses deux pieces", dans(PRES_CODE, "roomId !== 'hemicycle'")
    && dans(PRES_CODE, "roomId !== 'accueil_assemblee'"));
att("le bouton propose d'assister au tirage", dans(PRES, 'Assister au tirage'));
att("le tirage rejoue le resultat HISTORIQUE, sans nouvelle randomisation",
    dans(PRES_CODE, 'presidenceTirageOuvrir(a,'));
att("l'etat « vu » est note AU SERVEUR", dans(PRES_CODE, 'sbAssembleePresidenceTirageVu'));
att("l'etat « vu » n'est jamais un drapeau de navigateur",
    !/localStorage|sessionStorage/.test(PRES));

print('');
print('LA FERMETURE FAIT LES TROIS CHOSES DEMANDEES');
print('============================================================');
att("fermer la seconde popup ferme aussi l'animation",
    dans(PRES_CODE, 'presidenceTirageFermer()'));
att("la piece est rafraichie", dans(PRES_CODE, "enterRoom('assemblee'"));
att("la liste laterale et les titres sont rafraichis", dans(PRES_CODE, 'updateUI()'));
att("le minuteur est arrete, jamais laisse courir",
    dans(PRES_CODE, 'clearTimeout(RP_PRESIDENCE_ANIMATION)'));

print('');
print('LE VOTE PASSE PAR LE SOCLE EXISTANT');
print('============================================================');
att('le vote passe par assembleeActionServeur', dans(PRES_CODE, 'assembleeActionServeur('));
att('et par assembleeIssueAction', dans(PRES_CODE, 'assembleeIssueAction('));
att("il recoit la clef de requete", /sbAssembleePresidenceVoter\(pour, rq\)/.test(PRES_CODE));
att("l'ecran ne construit jamais sa propre clef", !/rq-/.test(PRES_CODE));
att("l'ecran ne compte pas les voix lui-meme",
    !/voix\s*\+\+|voix\s*\+=|reduce\(/.test(PRES_CODE));

print('');
print('AUCUNE QUALIFICATION, AUCUN SCORE');
print('============================================================');
['illegitime', 'usurpateur', 'scandaleux', 'contestable', 'douteux', 'abusif', 'score']
  .forEach(function (m) {
    att("l'ecran n'affiche jamais le mot « " + m + " »", !new RegExp(m, 'i').test(PRES_CODE), m);
  });

print('');
print('LES TEXTES DES JOUEURS NE SONT JAMAIS INTERPRETES');
print('============================================================');
att("le nom de l'elu est pose en textContent", dans(PRES_CODE, 'nom.textContent = scrutin.elu'));
att("les etiquettes des pailles aussi", dans(PRES_CODE, 'etiquette.textContent = nom'));
att("aucun innerHTML dans l'ecran de presidence", !/innerHTML/.test(PRES_CODE));

print('');
print('NEUF SIEGES, PAS VINGT-CINQ');
print('============================================================');
att("l'annuaire ne boucle plus sur 25 sieges", !/i <= 25|<= 25/.test(POLI_CODE));
att("il ne lit plus les cles decoratives depute_1..25", !/'depute_' \+ i/.test(POLI_CODE));
att("il lit la composition REELLE", dans(POLI_CODE, 'assembleeOccupation()'));
att("il nomme les trois villes", dans(POLI, 'Port-Sainte-Marie'));
att("il dit que la presidence est une fonction, pas un siege",
    dans(POLI, 'pas un siège'));
att("il echappe les noms de joueur", dans(POLI_CODE, 'escapeHtmlText(qui)'));
att("la description du batiment ne dit plus 25 sieges",
    !/25 sieges|25 sièges/.test(BUILDINGS['assemblee'].desc || ''));
att("elle annonce les neuf", /neuf sieges/i.test(BUILDINGS['assemblee'].desc || ''));
att("la table des sieges en declare exactement neuf",
    (typeof ASSEMBLEE_SIEGES !== 'undefined') && ASSEMBLEE_SIEGES.length === 9,
    typeof ASSEMBLEE_SIEGES !== 'undefined' ? ASSEMBLEE_SIEGES.length : '(absente)');
att("trois par ville", (function () {
  if (typeof ASSEMBLEE_SIEGES === 'undefined') return false;
  var parVille = {};
  ASSEMBLEE_SIEGES.forEach(function (s) { parVille[s.city] = (parVille[s.city] || 0) + 1; });
  var villes = Object.keys(parVille);
  return villes.length === 3 && villes.every(function (v) { return parVille[v] === 3; });
})());

print('');
print('LA DOUBLE QUALITE, ET AUCUN NOM CODE EN DUR');
print('============================================================');
att("la carte d'un depute PNJ President porte ses DEUX qualites",
    dans(ASSEM, 'Député de ') && dans(ASSEM, 'Président de l') && dans(ASSEM, 'suffixePresidence'));
att("le President est lu au SERVEUR, jamais devine",
    dans(ASSEM, 'RP_PRESIDENCE_ETAT.president'));
// LE NOM DE LAROCHE A LE DROIT D'EXISTER DANS UN SEUL ENDROIT : LA TABLE DES NEUF SIEGES.
// Depuis l'arbitrage du 11 octobre (§1), il EST l'un des neuf deputes PNJ, et son nom y figure
// comme ceux de ses huit collegues -- c'est une DONNEE. Ce qui reste interdit, c'est qu'une
// AUTORISATION en depende : le code de l'election et celui de la seance ne doivent jamais le
// nommer, et dans le module de l'Assemblee il ne doit apparaitre que sur les lignes de la table.
att("le nom de Laroche n'apparait que dans la table des sieges",
    codeSeul(ASSEM).split('\n')
      .filter(function (l) { return /Laroche/i.test(l); })
      .every(function (l) { return /pnjId:|photoUrl:/.test(l); }));
att("aucune autorisation ne repose sur un nom code en dur",
    !/Laroche/i.test(PRES_CODE) && !/Laroche/i.test(SEANCE_CODE));
att("et il est bien l'un des neuf, depute de la capitale",
    ASSEMBLEE_SIEGES.filter(function (s) {
      return s.nom === 'President Laroche' && s.city === 'capitale';
    }).length === 1);
att("il n'existe plus comme carte statique de l'hemicycle",
    (function () {
      var h = BUILDINGS.assemblee.rooms.hemicycle;
      return Array.isArray(h.persons) && h.persons.length === 0;
    })());
att("le titre est adopte depuis le registre, et retire quand il tombe",
    dans(PRES_CODE, 'presidenceAdopterLeTitre'));
att("perdre la presidence ne touche jamais au mandat de depute",
    !/state\.posteDepute\s*=/.test(PRES_CODE));
// L'ADOPTION N'ECRASE JAMAIS UN AUTRE POSTE NOMME, et elle ne se tait plus : le joueur apprend
// que ses pouvoirs sont actifs et que sa fiche, elle, ne porte qu'un titre a la fois (§6).
att("et l'adoption n'ecrase jamais un autre poste nomme",
    /if \(state\.poste\)\s*\{/.test(PRES_CODE)
    && PRES_CODE.indexOf('state.poste = ') > PRES_CODE.indexOf('if (state.poste)'));
att("l'emplacement unique du titre est DIT, pas tranche en silence",
    dans(PRES_CODE, 'RP_PRESIDENCE_TITRE_DIT')
    && /ne porte qu|qu'un titre nomm/.test(PRES));
att("et aucune incompatibilite n'est creee : le mandat de depute n'est pas touche",
    !/state\.posteDepute\s*=/.test(PRES_CODE));

print('');
print('SUSPENDRE ET REPRENDRE');
print('============================================================');
att("« Reprendre la séance » existe", dans(SEANCE, 'Reprendre la séance'));
att("la reprise passe par la porte serveur", dans(SEANCE_CODE, 'sbAssembleeReprendreSeance'));
att("l'ecran dit que la reprise ne coute rien", dans(SEANCE, 'ne coûte rien'));
att("suspendre et reprendre ne sont jamais proposes ensemble",
    dans(SEANCE_CODE, 'if (e.suspendue_par_la_presidence) {'));
att("une seance suspendue ne propose pas la parole",
    dans(SEANCE_CODE, '!e.suspendue_par_la_presidence'));
att("les deux suspensions sont annoncees separement",
    dans(SEANCE, 'SUSPENDUE PAR LA PRÉSIDENCE') && dans(SEANCE, 'SUSPENDUE PAR BOYCOTT'));
att("l'election due est annoncee comme un fait",
    dans(SEANCE, 'remise en jeu'));

print('');
print('============================================================');
if (ko === 0) print('LES ' + ok + ' EPREUVES SONT VERTES.');
else print(ko + ' EPREUVES ROUGES SUR ' + (ok + ko) + '.');
