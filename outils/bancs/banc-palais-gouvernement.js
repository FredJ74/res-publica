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

var SECRETAIRES = [
  ['min_int',  'le_ministre_de_l_interieur',           "PNJ - Secrétaire ministériel de l'Intérieur",        'BIBLE_MIN_INT'],
  ['min_fin',  'le_ministre_des_finances',             'PNJ - Secrétaire ministériel des Finances',          'BIBLE_MIN_FIN'],
  ['min_just', 'le_ministre_de_la_justice',            'PNJ - Secrétaire ministériel de la Justice',         'BIBLE_MIN_JUST'],
  ['min_info', 'le_ministre_de_l_information',         "PNJ - Secrétaire ministériel de l'Information",      'BIBLE_MIN_INFO'],
  ['min_ae',   'le_ministre_des_affaires_etrangeres',  'PNJ - Secrétaire ministériel des Affaires Étrangères','BIBLE_MIN_AE']
];

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
  var job = s[0], id = s[1], titre = s[2];
  var m = qui('bureau_' + job, job);
  att(job + ' : le PNJ est toujours dans son bureau', !!m);
  att(job + ' : il reste en place quand un joueur prend le poste', m && m.resteApresPourvoi === true);
  att(job + ' : son titre de secretaire est declare', m && m.roleSiPjTitulaire === titre,
      m && m.roleSiPjTitulaire);
  att(job + ' : son titre de secretaire ne pretend PAS au ministere',
      m && m.roleSiPjTitulaire.indexOf('Ministre') < 0);
  att(job + ' : il a un profil serveur', profilExiste(id));
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
