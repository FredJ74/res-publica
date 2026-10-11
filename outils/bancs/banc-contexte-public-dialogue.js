// BANC DU CONTEXTE PUBLIC DE DIALOGUE (11 octobre 2026)
// SOURCES: api/_bible-assemblee.js api/_bible-gouvernement.js api/_bible-militaire.js api/_bible-presidence.js api/_pnj-personnalites.js api/_pnj-referents.js api/_pnj-profils.js
//
// CE QU'IL PROUVE. L'audit du Palais presidentiel a etabli qu'AUCUN des PNJ ne recevait la
// fonction officielle de son interlocuteur : le President PNJ ne pouvait pas savoir qu'il parlait
// au ministre de la Defense. La correction est un TROISIEME CANAL, et ce banc verifie qu'elle est
// bien GENERIQUE -- pas un correctif reserve au Palais :
//   . TOUS les profils, sans exception, recoivent le bloc quand le contexte existe ;
//   . un PNJ ne recoit QUE le nom et la fonction : une clef supplementaire glissee dans l'objet
//     (argent, domicile, casier) n'atteint jamais le prompt -- contre-epreuve d'etancheite ;
//   . une fonction officielle est presentee comme un FAIT PUBLIC, sans rencontre prealable ;
//   . elle ne confere AUCUNE AUTORITE au joueur sur le PNJ -- c'est la frontiere que l'arbitrage
//     nommait « ne pas confondre referent et autorite » ;
//   . sans contexte, le prompt est RIGOUREUSEMENT celui d'avant, caractere pour caractere.
//
// Usage : python3 outils/bancs/lancer-banc.py outils/bancs/banc-contexte-public-dialogue.js
var ok = 0, ko = 0;
function att(n, c, d) { if (c) { print('  ok  ' + n); ok++; } else { print('  *** ' + n + (d !== undefined ? ' -- ' + d : '')); ko++; } }

var MINISTRE = { ok: true, nom: 'Arnie', fonctions: ['Ministre de la Defense'] };
var CIVIL    = { ok: true, nom: 'Lee Capene', fonctions: [] };
var CUMUL    = { ok: true, nom: 'Arnie', fonctions: ['Ministre de la Defense', 'Depute de la Capitale'] };

print('');
print('LE BLOC N EXISTE PAS SANS CONTEXTE');
print('============================================================');
var sansRien = construirePromptSysteme('martial_bouterin', 'fr', null, null);
var sansCinq = construirePromptSysteme('martial_bouterin', 'fr', null, null, null);
att('le prompt sans contexte est inchange, caractere pour caractere', sansRien === sansCinq);
att('il ne porte aucun bloc d interlocuteur', sansRien.indexOf('A QUI TU PARLES') < 0);
att('un contexte en echec (ok:false sans nom) ne pose rien',
    construirePromptSysteme('martial_bouterin', 'fr', null, null, { ok: false }) === sansRien);
att('un contexte qui n est pas un objet ne pose rien',
    construirePromptSysteme('martial_bouterin', 'fr', null, null, 'Arnie') === sansRien);

print('');
print('CE QUE LE PNJ APPREND');
print('============================================================');
var p = construirePromptSysteme('martial_bouterin', 'fr', null, null, MINISTRE);
att('le bloc est pose', p.indexOf('A QUI TU PARLES') >= 0);
att('le nom y est', p.indexOf("cette personne s'appelle Arnie") >= 0);
att('la fonction officielle y est', p.indexOf('la fonction de Ministre de la Defense') >= 0);
att('elle est presentee comme un fait PUBLIC', p.indexOf('fait PUBLIC') >= 0);
att('la rencontre prealable n est pas requise', p.indexOf('vous ne vous etes jamais parle') >= 0);
att('elle ne donne AUCUNE autorite sur le PNJ', p.indexOf('AUCUN pouvoir sur toi') >= 0);
att('le PNJ sait dire non a une demande inexistante', p.indexOf("qui n'existe pas, dis-le lui") >= 0);
att('le reste est explicitement hors champ', p.indexOf("RIEN D'AUTRE") >= 0);

var pc = construirePromptSysteme('martial_bouterin', 'fr', null, null, CIVIL);
att('un civil est nomme', pc.indexOf("cette personne s'appelle Lee Capene") >= 0);
att('un civil n a aucun titre', pc.indexOf('citoyen ordinaire') >= 0);
att('et aucune phrase de fonction ne lui est appliquee', pc.indexOf('la fonction de') < 0);

var pk = construirePromptSysteme('martial_bouterin', 'fr', null, null, CUMUL);
att('le cumul rend les deux fonctions',
    pk.indexOf('la fonction de Ministre de la Defense et de Depute de la Capitale') >= 0);

print('');
print('ETANCHEITE : CE QUI NE DOIT JAMAIS ATTEINDRE LE PROMPT');
print('============================================================');
// CONTRE-EPREUVE. On glisse dans l'objet tout ce que l'arbitrage exclut. Le bloc ne lit que deux
// champs : si l'une de ces valeurs ressort dans le prompt, c'est que le canal fuit.
var FUITE = { ok: true, nom: 'Arnie', fonctions: ['Ministre de la Defense'],
  argent: 987654, domicile: 'Luthecia-Nord', casier: 'condamne pour fraude',
  popularite: 73, influence: 24, carriere: 'ancien gangster', historique: ['A', 'B'] };
var pf = construirePromptSysteme('martial_bouterin', 'fr', null, null, FUITE);
['987654', 'Luthecia-Nord', 'condamne pour fraude', '73', 'ancien gangster'].forEach(function (v) {
  att('le prompt ne contient pas : ' + v, pf.indexOf(v) < 0);
});
att('mais il contient toujours le nom et la fonction',
    pf.indexOf('Arnie') >= 0 && pf.indexOf('Ministre de la Defense') >= 0);

// Un nom demesure est coupe : un PNJ ne recoit pas un roman en guise d identite.
var LONG = { ok: true, nom: new Array(500).join('x'), fonctions: [new Array(500).join('y')] };
var pl = construirePromptSysteme('martial_bouterin', 'fr', null, null, LONG);
att('un nom demesure est tronque a 60', pl.indexOf(new Array(62).join('x')) < 0);
att('une fonction demesuree est tronquee a 80', pl.indexOf(new Array(82).join('y')) < 0);
att('une liste de fonctions malformee ne casse rien',
    typeof construirePromptSysteme('martial_bouterin', 'fr', null, null,
      { ok: true, nom: 'Arnie', fonctions: 'ministre' }) === 'string');

print('');
print('L ORDRE DES TROIS CANAUX');
print('============================================================');
// On sait A QUI l on parle avant de se souvenir de lui : le fait du monde precede la relation.
var po = construirePromptSysteme('jean_lou_zeure', 'fr',
  { rencontres: 4, conversations: 2, familiarite: 2 }, null, MINISTRE);
var iPub = po.indexOf('A QUI TU PARLES'), iRel = po.indexOf('VOTRE RELATION');
att('la memoire sociale est bien la', iRel > 0);
att('le contexte public precede la relation', iPub > 0 && iPub < iRel, iPub + ' < ' + iRel);

print('');
print('LA CORRECTION EST GENERIQUE, PAS PROPRE AU PALAIS');
print('============================================================');
var noms = Object.keys(TOUS_PROFILS), manquants = [];
noms.forEach(function (id) {
  var s = construirePromptSysteme(id, 'fr', null, null, MINISTRE);
  if (!s || s.indexOf('A QUI TU PARLES') < 0 || s.indexOf('Ministre de la Defense') < 0) manquants.push(id);
});
att('les ' + noms.length + ' profils serveur recoivent tous le bloc',
    manquants.length === 0, manquants.slice(0, 6).join(', '));

print('');
print('============================================================');
if (ko === 0) print('LES ' + ok + ' EPREUVES SONT VERTES.');
else print(ko + ' EPREUVES ROUGES SUR ' + (ok + ko) + '.');
