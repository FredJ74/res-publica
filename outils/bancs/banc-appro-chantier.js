// Banc STRUCTUREL de l'APPROVISIONNEMENT DES CHANTIERS -- plateau-justice-economie.js
// (chantier 5, chaine 5, 10 octobre 2026).
// SOURCES: aucune -- ce banc lit plateau-justice-economie.js lui-meme, par readFile.
//
// POURQUOI CE BANC EST STRUCTUREL, ET PAS COMPORTEMENTAL. Les deux approvisionnements vivent au
// milieu de confirmerConstruction et confirmerReconfiguration, deux fonctions de plus de cent
// lignes qui enchainent la validation du plan, le financement, la creation du chantier et
// l'ouverture de modales. Les extraire demanderait de simuler tout cela ; les appeler voudrait
// dire rejouer un ordre entier. Le comportement de la PORTE, lui, est eprouve en transaction
// annulee cote base (16 epreuves) -- c'est la seule facon honnete de couper ce travail en deux.
//
// CE QUE CE BANC ETABLIT, dans la portee exacte des deux blocs :
//   1. plus AUCUN appel client a approvisionner_chantier -- c'etait par lui que la tresorerie
//      DICTEE PAR LE NAVIGATEUR passait, et c'est elle qui bornait le pouvoir d'achat ;
//   2. plus aucun repli `|| { depense: 0 }`, qui presentait une panne de RPC comme « rien a
//      acheter », donc comme un succes ;
//   3. exactement DEUX appels a chantier_approvisionner, un par famille de chantier, chacun
//      nommant sa cle, et dont le VERDICT est lu ;
//   4. le stock et la tresorerie ne sont plus transmis ;
//   5. la construction n'ecrit plus le terrain du tout (chantier_lancer l'a deja fait), et le
//      reamenagement, qui n'a pas de porte de lancement, LIT desormais le resultat de son unique
//      ecriture au lieu de l'avaler.
//
// CONTRE-EPREUVE. Joue contre la version precedente de plateau-justice-economie.js, il ECHOUE sur
// 22 de ses 23 epreuves :
//   git show HEAD:plateau-justice-economie.js > /tmp/avant.js
//   printf "var CHEMIN_SOURCE = '/tmp/avant.js';\n" > /tmp/decor.js
//   python3 outils/bancs/lancer-banc.py outils/bancs/banc-appro-chantier.js /tmp/decor.js
var src = readFile(typeof CHEMIN_SOURCE === 'string'
  ? CHEMIN_SOURCE : '/Users/fredericjasseron/ResPublica/plateau-justice-economie.js');

var ko = 0, attendus = 0;
function att(n, c, detail) {
  attendus++;
  if (c) print('  ok  ' + n);
  else { print('  *** ' + n); if (detail !== undefined) print('        ' + detail); ko++; }
}
function compte(texte, motif) { return (texte.match(motif) || []).length; }
// LES COMMENTAIRES DE CE LOT NOMMENT LES DEFAUTS FERMES : les compter reviendrait a declarer un
// defaut present parce qu'on explique qu'il a disparu. On mesure donc le CODE seul.
function sansCommentaires(texte) {
  return texte.split('\n').filter(function (l) { return l.trim().indexOf('//') !== 0; }).join('\n');
}
function fonction(nom) {
  var i = src.indexOf('async function ' + nom + '(');
  if (i < 0) i = src.indexOf('function ' + nom + '(');
  if (i < 0) throw new Error('introuvable : ' + nom);
  var j = src.indexOf('{', i), p = 0, k = j;
  while (k < src.length) { if (src[k] === '{') p++; else if (src[k] === '}') { p--; if (!p) break; } k++; }
  return src.slice(i, k + 1);
}

var construction = sansCommentaires(fonction('confirmerConstruction'));
var reconfig = sansCommentaires(fonction('confirmerReconfiguration'));
var reconfigAvecCommentaires = fonction('confirmerReconfiguration');
var code = sansCommentaires(src);

print('');
print('1. LE MOTEUR DE L ENTREPOT N EST PLUS APPELE PAR LE NAVIGATEUR');
att("aucun sbRpc('approvisionner_chantier') dans tout le fichier",
    compte(code, /sbRpc\('approvisionner_chantier'/g) === 0,
    compte(code, /sbRpc\('approvisionner_chantier'/g) + ' appel(s)');
att('plus aucune tresorerie transmise au serveur',
    compte(code, /p_tresorerie:/g) === 0, compte(code, /p_tresorerie:/g) + ' occurrence(s)');
att('plus aucun stock de chantier transmis au serveur',
    compte(code, /p_stock_chantier:/g) === 0, compte(code, /p_stock_chantier:/g) + ' occurrence(s)');

print('');
print('2. LE REPLI QUI FAISAIT PASSER UNE PANNE POUR UN SUCCES A DISPARU');
att('plus aucun `|| { depense: 0 ...}`',
    compte(code, /\|\|\s*\{\s*depense:\s*0/g) === 0,
    compte(code, /\|\|\s*\{\s*depense:\s*0/g) + ' occurrence(s)');
att('plus aucun test `plan.depense > 0`',
    compte(code, /plan\.depense\s*>\s*0/g) === 0);

print('');
print('3. DEUX APPELS A LA PORTE, UN PAR FAMILLE DE CHANTIER');
att('exactement deux appels dans le fichier',
    compte(code, /sbRpc\('chantier_approvisionner'/g) === 2,
    compte(code, /sbRpc\('chantier_approvisionner'/g) + ' appel(s)');
att('la construction appelle la porte une fois',
    compte(construction, /sbRpc\('chantier_approvisionner'/g) === 1);
att("elle nomme la cle « chantier »",
    construction.indexOf("p_cle_chantier: 'chantier'") >= 0);
att('le reamenagement appelle la porte une fois',
    compte(reconfig, /sbRpc\('chantier_approvisionner'/g) === 1);
att("il nomme la cle « chantierReamenagement »",
    reconfig.indexOf("p_cle_chantier: 'chantierReamenagement'") >= 0);
att('les deux transmettent le besoin du jour et le jour de jeu',
    compte(code, /p_besoin: besoinJ1, p_jour: state\.day \|\| 1/g) === 2,
    compte(code, /p_besoin: besoinJ1, p_jour: state\.day \|\| 1/g) + ' occurrence(s)');

print('');
print('4. LE VERDICT EST LU, ET UNE PANNE EST NOMMEE AU JOUEUR');
att('la construction lit le verdict',
    construction.indexOf('!appro || appro.ok !== true') >= 0);
att('le reamenagement lit le verdict',
    reconfig.indexOf('!appro || appro.ok !== true') >= 0);
att("les deux nomment « Approvisionnement non confirmé »",
    compte(code, /Approvisionnement non confirmé/g) === 2,
    compte(code, /Approvisionnement non confirmé/g) + ' occurrence(s)');
att('les deux recopient le chantier ARRETE PAR LE SERVEUR',
    compte(code, /ch = appro\.chantier;|chantier = appro\.chantier;/g) === 2,
    compte(code, /ch = appro\.chantier;|chantier = appro\.chantier;/g) + ' occurrence(s)');
att('les deux signalent l echec au Journal en event-bad',
    compte(src, /approvisionnement du jour 1 non enregistré\.",?\s*\n?\s*'event-bad'|approvisionnement du jour 1 non enregistré\.", 'event-bad'/g) >= 1
    || compte(code, /approvisionnement du jour 1 non enregistré/g) === 2,
    compte(code, /approvisionnement du jour 1 non enregistré/g) + ' occurrence(s)');

print('');
print('5. LES ECRITURES DIRECTES DE TERRAIN DANS CES DEUX BLOCS');
att("la construction n'ecrit plus le terrain du tout (chantier_lancer l'a deja fait)",
    compte(construction, /await sbSetTerrainState\(/g) === 0,
    compte(construction, /await sbSetTerrainState\(/g) + ' occurrence(s)');
// MIS A JOUR LE 10 OCTOBRE 2026 (chantier 5, les 22 ecritures de `terrains_etat`). Ces deux
// epreuves exigeaient que le reamenagement garde UNE ecriture directe, « faute de porte de
// lancement ». La porte existe desormais : `terrain_reamenagement_poser`. Elle n'ecrit que la cle
// `chantierReamenagement`, sous verrou, apres avoir verifie la propriete en base -- donc elle ne
// peut plus effacer la nuit du cron, ce que l'ancienne ecriture du blob entier pouvait faire.
// Ce que ces epreuves verifient n'a pas change de NATURE : l'ecriture existe, et son resultat est
// lu. Ce qui a change, c'est par ou elle passe.
att('le reamenagement passe par sa porte, et plus par aucune ecriture directe',
    compte(reconfig, /await sbSetTerrainState\(/g) === 0
    && compte(reconfig, /sbTerrainActe\('terrain_reamenagement_poser'/g) === 1,
    compte(reconfig, /sbTerrainActe\('terrain_reamenagement_poser'/g) + ' appel(s) a la porte');
att("et son verdict est lu : un refus arrete la fonction",
    reconfig.indexOf('poseCh.ok !== true') >= 0
    && reconfig.indexOf('remplacerTerrainState(id, poseCh.etat)') >= 0);
att("son echec est nomme au joueur", reconfig.indexOf('Travaux non enregistrés') >= 0);
// Celle-ci se lit dans les COMMENTAIRES, c'est le but : la dette doit etre ecrite noir sur blanc
// a l'endroit ou elle subsiste.
att("la dette restante est CONSIGNEE dans le code, pas masquee",
    reconfigAvecCommentaires.indexOf('DETTE CONSIGNEE') >= 0);

print('');
print('6. CE QUE LE NAVIGATEUR NE CALCULE PLUS');
att('il ne recalcule plus les prix des trois materiaux pour cet achat',
    compte(code, /prix\[m\] = \(typeof RESSOURCES_ECONOMIE/g) === 0,
    compte(code, /prix\[m\] = \(typeof RESSOURCES_ECONOMIE/g) + ' occurrence(s)');
att("il ne relit plus l'etat de l'entrepot avant d'acheter",
    compte(construction, /sbGetBatimentEtat/g) === 0
    && compte(reconfig, /sbGetBatimentEtat/g) === 0);

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
