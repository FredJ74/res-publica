// BANC DU PALAIS DU GOUVERNEMENT (11 octobre 2026)
// SOURCES: data.js api/_bible-gouvernement.js api/_bible-militaire.js api/_bible-presidence.js api/_pnj-personnalites.js api/_pnj-referents.js api/_pnj-profils.js
//
// CE QU'IL PROUVE. Le Palais du Gouvernement comptait huit PNJ muets, un faux Premier ministre
// assis dans la Salle du Conseil, et des ministres PNJ qui disparaissaient des qu'un joueur
// prenait le poste. Ce banc verifie :
//   . que le PNJ « Premier Ministre » a disparu DE LA PIECE ET DE LA TABLE -- un profil laisse
//     derriere resterait adressable, donc vivant (lecon du General Faure) ;
//   . qu'Eric Stricted est le referent de la fonction, sans en detenir aucun pouvoir ;
//   . que les CINQ ministres PNJ restent en place sous un titre de secretaire ministeriel, par la
//     mecanique GENERIQUE et non par un correctif par ministere ;
//   . que chaque secretaire ne connait QUE son ministere -- sinon les quatre autres seraient
//     decoratifs ;
//   . que Corinne Tite-Declaz et les Journalistes accredites sont en salle de presse ;
//   . que les huit images WebP sont reellement referencees ET reellement presentes sur le disque ;
//   . et qu'AUCUN de ces PNJ ne recoit un pouvoir de ministre.
//
// Usage : python3 outils/bancs/lancer-banc.py outils/bancs/banc-palais-gouvernement.js
var ok = 0, ko = 0;
function att(n, c, d) { if (c) { print('  ok  ' + n); ok++; } else { print('  *** ' + n + (d !== undefined ? ' -- ' + d : '')); ko++; } }
function contient(s, frag) { return s.indexOf(frag) >= 0; }
function piece(salle) { return BUILDINGS['palais-gouvernement'].rooms[salle]; }
function qui(salle, job) {
  return (piece(salle).persons || []).filter(function (p) { return p.job === job; })[0];
}
var RACINE = '/Users/fredericjasseron/ResPublica/';
function existe(chemin) { try { return readFile(RACINE + chemin).length > 0; } catch (e) { return false; } }

// LES CINQ SONT INCARNES DEPUIS LE 11 OCTOBRE 2026 AU SOIR. Chaque entree porte le poste, le
// nouvel identifiant de profil, le titre de secretaire, le nom AFFICHE, le fichier d'image et
// l'ANCIEN identifiant generique -- ce dernier pour la contre-epreuve : il ne doit plus repondre.
var SECRETAIRES = [
  ['min_int',  'yvan_danltat',        "PNJ - Secrétaire ministériel de l'Intérieur",         'Yvan Danltat (PNJ)',        'yvan-danltat',        'le_ministre_de_l_interieur'],
  ['min_fin',  'alain_theret',        'PNJ - Secrétaire ministériel des Finances',           'Alain Théret (PNJ)',        'alain-theret',        'le_ministre_des_finances'],
  ['min_just', 'mathilde_garde',      'PNJ - Secrétaire ministériel de la Justice',          'Mathilde Garde (PNJ)',      'mathilde-garde',      'le_ministre_de_la_justice'],
  ['min_info', 'marie_eve_beaulieu',  "PNJ - Secrétaire ministériel de l'Information",       'Marie-Eve Beaulieu (PNJ)',  'marie-eve-beaulieu',  'le_ministre_de_l_information'],
  ['min_ae',   'jean_jacques_carlin', 'PNJ - Secrétaire ministériel des Affaires Étrangères','Jean-Jacques Carlin (PNJ)', 'jean-jacques-carlin', 'le_ministre_des_affaires_etrangeres']
];

// LA MEME NORMALISATION QUE slugPnj (plateau-pnj.js), reproduite ici expres. C'est elle qui relie
// le NOM AFFICHE dans data.js a l'IDENTIFIANT du profil serveur : si les deux divergent d'un
// accent, le PNJ devient muet sans qu'aucune autre epreuve ne le voie.
function slugDeNom(nom) {
  return String(nom || '').replace(' (PNJ)', '').trim()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
}

print('');
print('LE FAUX PREMIER MINISTRE A DISPARU, DE LA PIECE ET DE LA TABLE');
print('============================================================');
att('la Salle du Conseil n a plus aucun occupant',
    (piece('salle_conseil').persons || []).length === 0,
    JSON.stringify((piece('salle_conseil').persons || []).map(function (p) { return p.name; })));
att('aucun PNJ ne porte plus le job `pm` dans le Palais',
    Object.keys(BUILDINGS['palais-gouvernement'].rooms).every(function (r) {
      return (piece(r).persons || []).every(function (p) { return p.job !== 'pm'; }); }));
att('et son profil serveur a ete retire -- il n est plus adressable',
    !profilExiste('premier_ministre'));

print('');
print('ERIC STRICTED, REFERENT DE LA FONCTION');
print('============================================================');
var es = qui('bureaux', 'chef_cabinet');
att('il est dans le bureau du Premier ministre', !!es, es && es.name);
att('il porte son nom', es.name === 'Éric Stricted (PNJ)', es && es.name);
att('son image est referencee', es.photoUrl === 'images/luthecia-palais-gouvernement-chef-cabinet.webp');
att('son profil serveur existe', profilExiste('eric_stricted'));
var pES = construirePromptSysteme('eric_stricted', 'fr', null, null);
att('il connait les couts reels de la fonction',
    contient(pES, 'NOMMER DES MINISTRES -- 2 PA') && contient(pES, 'REVOQUER UN MINISTRE -- 1 PA')
    && contient(pES, 'VOTE DE CONFIANCE -- 3 PA'));
att("il sait que le Premier ministre est NOMME et revocable", contient(pES, 'IL EST NOMME, PAS ELU'));
att("il n'a aucun pouvoir du poste", contient(pES, "TU N'ES PAS LE PREMIER MINISTRE"));
att("il sait qu'il n'existe aucun Premier ministre PNJ",
    contient(pES, "IL N'EXISTE AUCUN PREMIER MINISTRE PNJ"));

print('');
print('LES CINQ SECRETAIRES MINISTERIELS, PAR LA MECANIQUE GENERIQUE');
print('============================================================');
SECRETAIRES.forEach(function (s) {
  var job = s[0], id = s[1], titre = s[2], nom = s[3], img = s[4], ancien = s[5];
  var m = qui('bureau_' + job, job);
  att(job + ' : le PNJ est toujours dans son bureau', !!m);
  att(job + ' : il reste en place quand un joueur prend le poste', m && m.resteApresPourvoi === true);
  att(job + ' : son titre de secretaire est declare', m && m.roleSiPjTitulaire === titre,
      m && m.roleSiPjTitulaire);
  att(job + ' : son titre de secretaire ne pretend PAS au ministere',
      m && m.roleSiPjTitulaire.indexOf('Ministre') < 0);
  att(job + ' : il a un profil serveur', profilExiste(id));
  // INCARNATION (11 octobre 2026 au soir)
  att(job + ' : il porte un NOM, plus un intitule de fonction', m && m.name === nom, m && m.name);
  att(job + ' : le nom affiche se normalise EXACTEMENT en son identifiant de profil',
      m && slugDeNom(m.name) === id, m && (slugDeNom(m.name) + ' vs ' + id));
  att(job + ' : son portrait est reference',
      m && m.photoUrl === 'images/luthecia-palais-gouvernement-' + img + '.webp', m && m.photoUrl);
  att(job + ' : et le fichier existe reellement sur le disque',
      existe('images/luthecia-palais-gouvernement-' + img + '.webp'));
  // CONTRE-EPREUVE : L'ANCIEN IDENTIFIANT GENERIQUE NE REPOND PLUS. C'est la lecon du General
  // Faure et du faux Premier ministre : un profil laisse derriere reste adressable, donc vivant --
  // ici avec un nom generique et un savoir vide, c'est-a-dire pire que rien.
  att(job + ' : son ancien identifiant generique n est plus adressable', !profilExiste(ancien), ancien);
});
// MARTIAL BOUTERIN N'EST PAS TOUCHE : son cas etait deja arbitre et livre.
var mart = qui('bureau_min_def', 'min_def');
att('Martial Bouterin garde ses libelles d origine, au caractere pres',
    mart && mart.roleSiPjTitulaire === 'PNJ - Attaché ministériel — Spécialiste des forces armées');

print('');
print('CHAQUE SECRETAIRE NE CONNAIT QUE SON MINISTERE');
print('============================================================');
var CLEFS = {
  min_int:  'INSTAURER UN COUVRE-FEU -- 2 PA',
  min_fin:  'DROIT DE PREEMPTION SUR UNE ENTREPRISE -- 2 PA',
  min_just: 'PROPOSER UNE GRACE -- 2 PA',
  min_info: 'CENSURER UN MEDIA -- 2 PA',
  min_ae:   'AMBASSADES ET AMBASSADEURS -- 2 PA'
};
SECRETAIRES.forEach(function (s) {
  var job = s[0], id = s[1];
  var p = construirePromptSysteme(id, 'fr', null, null);
  att(job + ' : il connait SON ordre caracteristique', contient(p, CLEFS[job]));
  var intrus = Object.keys(CLEFS).filter(function (autre) {
    return autre !== job && contient(p, CLEFS[autre]); });
  att(job + ' : il ne connait AUCUN ordre des autres ministeres', intrus.length === 0, intrus.join(','));
  att(job + ' : il sait qu il n a aucune autorite',
      contient(p, "TU N'AS AUCUNE AUTORITE SUR CE MINISTERE"));
  att(job + ' : il connait le socle de la maison', contient(p, 'LE PALAIS DU GOUVERNEMENT DE REPUBLIA'));
  att(job + ' : il porte la frontiere du Palais',
      contient(p, "IL N'Y A PAS DE PREMIER MINISTRE PNJ"));
});

print('');
print('LA SALLE DE PRESSE');
print('============================================================');
var co = qui('salle_presse', 'porteparole');
att('Corinne Tite-Declaz y est', co && co.name === 'Corinne Tite-Déclaz (PNJ)', co && co.name);
att('son image est referencee', co && co.photoUrl === 'images/luthecia-palais-gouvernement-corinne-tite-declaz.webp');
att('son profil serveur existe', profilExiste('corinne_tite_declaz'));
var pCO = construirePromptSysteme('corinne_tite_declaz', 'fr', null, null);
att('elle chiffre les trois ordres',
    contient(pCO, 'LA CONFERENCE DE PRESSE : 2 PA')
    && contient(pCO, 'LA CAMPAGNE DE PROPAGANDE : 3 PA et 500 FR')
    && contient(pCO, 'LE DEMENTI OFFICIEL : 2 PA'));
att("elle sait que cette salle n'est PAS celle du President",
    contient(pCO, "Ce n'est pas la salle du President"));
att('elle ne prononce rien elle-meme', contient(pCO, 'TU NE PRONONCES RIEN'));
att('elle ne juge jamais la verite d une declaration',
    contient(pCO, "TU NE DIS JAMAIS si une declaration etait vraie ou fausse"));
att('elle previent sur les journalistes', contient(pCO, 'LES JOURNALISTES ACCREDITES SONT DANS LA SALLE'));

var jo = qui('salle_presse', 'journaliste');
att('les Journalistes accredites y sont, au PLURIEL',
    jo && jo.name === 'Journalistes accrédités (PNJ)', jo && jo.name);
att('leur image est referencee', jo && jo.photoUrl === 'images/luthecia-palais-gouvernement-journalistes-accredites.webp');

print('');
print('LE HALL ET LES ARCHIVES');
print('============================================================');
var ga = qui('hall', 'garde');
att('le garde du hall est le Garde republicain de la couche generique',
    ga && ga.name === 'Garde Republicain (PNJ)', ga && ga.name);
att('son image est referencee', ga && ga.photoUrl === 'images/luthecia-palais-gouvernement-garde.webp');
var du = qui('hall', 'secretaire');
att('le Secretaire Dupuis est a l accueil', !!du);
att('son image est referencee', du && du.photoUrl === 'images/luthecia-palais-gouvernement-secretaire-dupuis.webp');
att('son profil serveur existe', profilExiste('secretaire_dupuis'));
var pDU = construirePromptSysteme('secretaire_dupuis', 'fr', null, null);
att('il sait ou l on postule', contient(pDU, 'Postuler a un poste'));
att("il sait que le President n'est pas ici", contient(pDU, "ce n'est pas ici"));
att("il n'usurpe pas les autres referents", contient(pDU, "TU N'USURPES PAS LE ROLE DES AUTRES REFERENTS"));
att('le hall porte sa nouvelle image', piece('hall').imageUrl === 'images/luthecia-palais-gouvernement-hall.webp');
var le = qui('archives_gouv', 'archiviste');
att("l'Archiviste Legrand a son portrait",
    le && le.photoUrl === 'images/luthecia-palais-gouvernement-archiviste-legrand.webp');
att("le ministere de l'Information a son visuel",
    piece('bureau_min_info').imageUrl === 'images/luthecia-palais-gouvernement-ministere-information.webp');

print('');
print('LES HUIT IMAGES EXISTENT REELLEMENT SUR LE DISQUE');
print('============================================================');
// UNE REFERENCE N'EST PAS UNE IMAGE. Un WebP cite mais absent est un 404 silencieux en
// production -- c'est exactement ce que la convention d'assets existe pour eviter.
['hall', 'garde', 'secretaire-dupuis', 'chef-cabinet', 'corinne-tite-declaz',
 'journalistes-accredites', 'archiviste-legrand', 'ministere-information'].forEach(function (n) {
  att('images/luthecia-palais-gouvernement-' + n + '.webp',
      existe('images/luthecia-palais-gouvernement-' + n + '.webp'));
});
// ET AUCUN PNG NE RESTE : le depot ne garde pas deux versions actives du meme asset.
['hall', 'garde', 'chef-cabinet'].forEach(function (n) {
  att('le PNG de ' + n + ' a bien quitte le depot',
      !existe('images/luthecia-palais-gouvernement-' + n + '.png'));
});

print('');
print('CHACUN A UN DEHORS, ET IL S ARRETE NET');
print('============================================================');
// LA CLEF DE CHAQUE DEHORS, et la phrase qui en marque la BORNE. Un domaine personnel sans borne
// ferait de son porteur le referent d'un rayon qui appartient a quelqu'un d'autre.
var DEHORS = {
  yvan_danltat:        ['LE PORT DE PLAISANCE DE PORT-SAINTE-MARIE', "TU N'ES PAS POUR AUTANT LE REFERENT DE PORT-SAINTE-MARIE"],
  alain_theret:        ["L'INVESTISSEMENT LOCATIF",                  "TU N'ANNONCES AUCUN RENDEMENT"],
  mathilde_garde:      ['BIEN MANGER, ET OU TROUVER DE QUOI',        "TU N'ES NI MEDECIN NI NUTRITIONNISTE"],
  jean_jacques_carlin: ["L'UNION CHEMINOTE DE MONTROUGE",            'TU NE CONNAIS PAS MONTROUGE POUR AUTANT'],
  marie_eve_beaulieu:  ["CE QUI PASSE D'UNE GENERATION A L'AUTRE",   "TU N'ES REFERENTE NI DE L'"]
};
Object.keys(DEHORS).forEach(function (id) {
  var p = construirePromptSysteme(id, 'fr', null, null);
  att(id + ' : il a son dehors a lui', contient(p, DEHORS[id][0]));
  att(id + ' : et ce dehors porte sa borne', contient(p, DEHORS[id][1]));
  // CONTRE-EPREUVE DE NON-OMNISCIENCE : aucun des quatre autres dehors ne lui est donne. Sans
  // elle, cinq corpus fusionnes rendraient les cinq personnages interchangeables.
  var intrus = Object.keys(DEHORS).filter(function (autre) {
    return autre !== id && contient(p, DEHORS[autre][0]); });
  att(id + ' : il ignore les quatre autres dehors', intrus.length === 0, intrus.join(','));
});

print('');
print('LES DEHORS DISENT CE QUI N EXISTE PAS, AU LIEU DE L INVENTER');
print('============================================================');
var pDan = construirePromptSysteme('yvan_danltat', 'fr', null, null);
// LE PORT DE PLAISANCE N'A AUCUNE MECANIQUE : `orders: []` dans ses deux pieces, et data.js le dit
// explicitement. Danltat doit donc refuser d'inventer un reglement et une sortie en mer.
att('Danltat sait qu aucune sortie en mer n est possible',
    contient(pDan, 'AUCUNE SORTIE EN MER POSSIBLE'));
att('il sait qu il n y a ni anneau, ni taxe, ni formalite',
    contient(pDan, 'aucun anneau a louer, aucune taxe de mouillage'));
att('et il oriente le voyage par bateau vers le port INDUSTRIEL',
    contient(pDan, 'port INDUSTRIEL') && contient(pDan, 'Alain Bordage'));
att('il connait le chef de la capitainerie, qui existe vraiment',
    contient(pDan, 'Patrice Lecap'));

var pThe = construirePromptSysteme('alain_theret', 'fr', null, null);
att('Theret connait la chaine locative reelle, etape par etape',
    contient(pThe, 'ACHETER UN TERRAIN A BATIR -- 2 PA')
    && contient(pThe, 'DEPOSER UNE DEMANDE DE PERMIS -- 2 PA')
    && contient(pThe, 'DECOUPER EN LOTS'));
att('il sait que le loyer est preleve chaque nuit par le serveur',
    contient(pThe, 'preleve CHAQUE NUIT'));
att('il sait que le loyer suit le titulaire ACTUEL des murs',
    contient(pThe, 'titulaire ACTUEL DES MURS'));
att('il sait qu un impaye ouvre une ardoise et n expulse PERSONNE',
    contient(pThe, 'ARDOISE') && contient(pThe, "N'EST PAS EXPULSE"));
att('il sait qu aucun lot sous bail ne peut etre redecoupe',
    contient(pThe, 'AUCUN LOCAL SOUS BAIL NE PEUT ETRE TOUCHE'));
att('et il n invente aucun rendement garanti',
    contient(pThe, 'aucun taux de rentabilite, aucun rendement garanti'));

var pGar = construirePromptSysteme('mathilde_garde', 'fr', null, null);
att('Garde ne prete AUCUN effet de sante a l article du marche',
    contient(pGar, "ne porte AUCUN effet declare sur la sante"));
att('elle connait le seul bareme etabli, et son plafond non arbitre',
    contient(pGar, 'de 5 a 10 FR') && contient(pGar, "rien n'a jamais ete arbitre"));
att('elle nomme les deux seules stats reelles',
    contient(pGar, 'la SANTE et le MORAL')
    && contient(pGar, 'aucun indicateur de nutrition'));
att('et elle nomme les vrais commercants du marche',
    contient(pGar, 'Jean-Pierre Bidoche') && contient(pGar, 'Ginette Legume'));

var pCar = construirePromptSysteme('jean_jacques_carlin', 'fr', null, null);
att('Carlin nomme le vrai club et le vrai stade',
    contient(pCar, 'UNION CHEMINOTE DE MONTROUGE') && contient(pCar, 'STADE MARCEL CAZENAVE'));
att('il connait le cout reel pour rejoindre les supporters',
    contient(pCar, 'REJOINDRE LE CLUB DE SUPPORTERS (1 PA et 50 FR'));
// ECART CONSIGNE : il n'existe AUCUN PNJ « ancien joueur de football » a Montrouge. Le referent
// social du club y est Lucas Tenaire, chef des supporters. Le banc verifie qu'on oriente vers
// l'homme qui existe, sous son vrai titre.
att('il oriente vers Lucas Tenaire, le referent social qui existe vraiment',
    contient(pCar, 'LUCAS TENAIRE') && contient(pCar, 'chef des supporters'));

var pBea = construirePromptSysteme('marie_eve_beaulieu', 'fr', null, null);
att('Beaulieu nomme l EHPAD et ses trois pensionnaires reels',
    contient(pBea, 'RESIDENCE LES TILLEULS') && contient(pBea, 'JEANINE DUBOIS')
    && contient(pBea, 'LOUIS CHEVILLARD') && contient(pBea, 'NOEL CHAUCHAY'));
att('elle sait qu il n y a RIEN a y faire, et que c est le point',
    contient(pBea, "IL N'Y A RIEN A FAIRE LA-BAS"));
att('elle connait les deux seules mecaniques reelles de l Universite',
    contient(pBea, 'recruter des militants pour une organisation (2 PA') && contient(pBea, '180 FR par jour'));

print('');
print('LEURS PERSONNALITES SONT DANS LE PROMPT, PAS DANS UNE REPONSE TOUTE FAITE');
print('============================================================');
// CE QU'ON VERIFIE ICI : que le TRAIT est ecrit comme un caractere, et que la consigne de mesure
// l'accompagne. Un trait sans garde-fou devient un gimmick repete a chaque phrase.
att('Danltat : la contrainte est son premier reflexe',
    contient(pDan, 'TA PREMIERE IDEE EST LA CONTRAINTE'));
att('Danltat : et ce reflexe est borne, pour ne pas devenir une caricature',
    contient(pDan, 'UNE FOIS DE TEMPS EN TEMPS') && contient(pDan, "Tu n'es pas une caricature"));
att('Theret : il parle la langue des economistes sans chercher a impressionner',
    contient(pThe, 'rouler la dette') && contient(pThe, "pas pour impressionner"));
att('Theret : il rit d une plaisanterie et revient a son raisonnement',
    contient(pThe, "TU AIMES BEAUCOUP L'HUMOUR") && contient(pThe, 'va-et-vient est ta signature'));
att('Garde : son austerite est une inquietude, pas une froideur',
    contient(pGar, "c'est une INQUIETUDE") && contient(pGar, 'grand-mere'));
att('Garde : sa famille n est pas un refrain',
    contient(pGar, "TA FAMILLE N'EST PAS UN REFRAIN"));
att('Carlin : diplomate sans etre seducteur',
    contient(pCar, "TU N'ES PAS SEDUCTEUR"));
att('Carlin : il sait dire non a un ministre, sans manquer de respect',
    contient(pCar, 'TU SAIS DIRE NON') && contient(pCar, 'sans manquer de respect'));
att('Carlin : il n est pas pacifiste par principe',
    contient(pCar, "TU N'ES PAS PACIFISTE PAR PRINCIPE"));
att('Beaulieu : elle rejette la seduction et recadre sur la fonction',
    contient(pBea, 'TU LA REJETTES') && contient(pBea, 'TU NE SEDUIS JAMAIS'));
att('Beaulieu : ses enfants sont sa faiblesse, et ne sont pas un refrain',
    contient(pBea, 'tes enfants') && contient(pBea, "CE N'EST PAS UN REFRAIN"));

print('');
print('UNE OPINION N EST JAMAIS UNE REGLE DU JEU');
print('============================================================');
att('Danltat : son opinion n est pas une recommandation du jeu',
    contient(pDan, 'TES OPINIONS NE SONT PAS DES REGLES'));
att('Theret : son gout pour le locatif est un AVIS, pas une recommandation',
    contient(pThe, 'est un AVIS, pas une recommandation du jeu'));
att('Carlin : son desaccord est un avis, pas un veto',
    contient(pCar, 'TON DESACCORD EST UN AVIS, PAS UN VETO'));
// CONTRE-EPREUVE : aucun des cinq ne porte de score, de note ni de jauge de sympathie. Le joueur
// n'est pas evalue pour ce qu'il repond a un PNJ.
['yvan_danltat','alain_theret','mathilde_garde','marie_eve_beaulieu','jean_jacques_carlin'].forEach(function (id) {
  var p = construirePromptSysteme(id, 'fr', null, null);
  att(id + ' : aucun score, aucune note, aucune jauge de sympathie',
      !/score de sympathie|note de sympathie|jauge de sympathie|points de sympathie/i.test(p));
});

print('');
print('AUCUN DE CES PNJ NE RECOIT UN POUVOIR');
print('============================================================');
['secretaire_dupuis', 'eric_stricted', 'corinne_tite_declaz'].concat(
  SECRETAIRES.map(function (s) { return s[1]; })).forEach(function (id) {
  var p = construirePromptSysteme(id, 'fr', null, null);
  att(id + ' : porte la frontiere du Palais',
      contient(p, "AUCUN PNJ DE CE PALAIS N'A D'AUTORITE"));
  att(id + ' : sait que le Gouvernement ne fait pas la loi',
      contient(p, 'LE GOUVERNEMENT NE FAIT PAS LA LOI'));
  att(id + ' : aucun score de performance ministerielle',
      contient(p, "IL N'Y A AUCUN SCORE DE PERFORMANCE MINISTERIELLE"));
});

print('');
print('============================================================');
if (ko === 0) print('LES ' + ok + ' EPREUVES SONT VERTES.');
else print(ko + ' EPREUVES ROUGES SUR ' + (ok + ko) + '.');
