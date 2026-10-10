// Banc STRUCTUREL du CYCLE DE VIE D'UNE AFFAIRE -- chantier 5, les trois `sbSavePlainte` (10 oct. 2026).
// SOURCES: aucune -- ce banc lit supabase.js, plateau-justice-economie.js et plateau-politique.js
// lui-meme, par readFile.
//
// POURQUOI CE BANC EST STRUCTUREL. Les trois sites vivent au milieu de fonctions d'interface qui
// ouvrent des modales, composent du HTML, prelevent des PA et publient sur deux forums. Le
// COMPORTEMENT des trois portes, lui, est eprouve en transaction annulee cote base --
// `banc-cycle-plaintes-1/2/3.sql`, 51 epreuves dont CINQ contre-epreuves qui reintroduisent
// exactement les defauts fermes. C'est la seule facon honnete de couper ce travail en deux.
//
// CE QUE CE BANC ETABLIT, site par site.
//
//   TRANSMISSION. `'affaire-' + Date.now()` : la meme conclusion d'enquete rejouee creait DEUX
//   affaires contre la meme personne, et l'accuse devait se defendre deux fois. Le forum du
//   tribunal annoncait « AFFAIRE TRANSMISE » sans condition, meme quand l'ecriture echouait.
//
//   DEFENSE. Mesure faite en base : cette ecriture n'a JAMAIS rien inscrit. Le trigger
//   `plaintes_epingler_verdict` restaure `status`, `circonstanceAttenuante` et `aggravation` des
//   que l'auteur n'est pas l'autorite judiciaire de la ville -- et l'accuse n'en est jamais une.
//   2 PA et 300 FR pour rien, systematiquement, pour tout le monde.
//
//   CLASSEMENT MINISTERIEL. La policy d'UPDATE n'a que deux branches, et le Ministre de la
//   Justice n'en remplit aucune : l'ecriture touchait ZERO ligne. Les 250 FR partaient quand meme.
//   Et la liste de l'ecran filtrait `'pending'`, un statut que plus aucune affaire ne porte depuis
//   le 15 septembre 2026 : l'ecran etait STRUCTURELLEMENT VIDE.
var RACINE = '/Users/fredericjasseron/ResPublica/';
var FICHIERS = ['supabase.js', 'plateau-justice-economie.js', 'plateau-politique.js'];
// LE BANC LIT TROIS FICHIERS, DONC LA CONTRE-EPREUVE DOIT DIRE LEQUEL ELLE PATCHE. Les bancs
// precedents n'en lisaient qu'un et `CHEMIN_SOURCE` suffisait ; ici il faut aussi `CHEMIN_FICHIER`,
// sans quoi une copie patchee de plateau-politique.js serait lue a la place de supabase.js et la
// contre-epreuve prouverait n'importe quoi.
var CIBLE = (typeof CHEMIN_FICHIER === 'string') ? CHEMIN_FICHIER : null;
var SRC = {};
for (var f = 0; f < FICHIERS.length; f++) {
  SRC[FICHIERS[f]] = readFile((CIBLE === FICHIERS[f] && typeof CHEMIN_SOURCE === 'string')
    ? CHEMIN_SOURCE : RACINE + FICHIERS[f]);
}
// LES COMMENTAIRES DE CE LOT NOMMENT LES DEFAUTS FERMES : les compter reviendrait a declarer un
// defaut present parce qu'on explique qu'il a disparu. On mesure donc le CODE seul.
function sansCommentaires(texte) {
  return texte.split('\n').filter(function (l) { return l.trim().indexOf('//') !== 0; }).join('\n');
}
var CODE = {};
for (var g = 0; g < FICHIERS.length; g++) CODE[FICHIERS[g]] = sansCommentaires(SRC[FICHIERS[g]]);

var ko = 0, attendus = 0;
function att(n, c, detail) {
  attendus++;
  if (c) print('  ok  ' + n);
  else { print('  *** ' + n); if (detail !== undefined) print('        ' + detail); ko++; }
}
function compte(texte, motif) { return (texte.match(motif) || []).length; }
function partout(motif) {
  var n = 0;
  for (var i = 0; i < FICHIERS.length; i++) n += compte(CODE[FICHIERS[i]], motif);
  return n;
}
function bloc(fichier, nom) {
  var src = SRC[fichier];
  var i = src.indexOf('async function ' + nom + '(');
  if (i < 0) i = src.indexOf('function ' + nom + '(');
  if (i < 0) throw new Error('introuvable : ' + nom + ' dans ' + fichier);
  var j = src.indexOf('{', i), p = 0, k = j;
  while (k < src.length) { if (src[k] === '{') p++; else if (src[k] === '}') { p--; if (!p) break; } k++; }
  return src.slice(i, k + 1);
}

print('');
print('BANC DU CYCLE DE VIE D UNE AFFAIRE');
print('============================================================================');

print('1. L ECRIVAIN CLIENT DU CYCLE A DISPARU');
att('sbSavePlainte n existe plus dans supabase.js',
    CODE['supabase.js'].indexOf('async function sbSavePlainte(') < 0);
att('sbDeletePlainte, qui n avait aucun appelant, a disparu avec elle',
    CODE['supabase.js'].indexOf('async function sbDeletePlainte(') < 0);
att('sbLoadPlaintes, qui ne fait que lire, est conservee',
    CODE['supabase.js'].indexOf('async function sbLoadPlaintes(') >= 0);
att('plus aucun appel a sbSavePlainte dans les trois fichiers',
    partout(/sbSavePlainte\(/g) === 0, partout(/sbSavePlainte\(/g) + ' appel(s)');
att('plus aucun appel a sbDeletePlainte',
    partout(/sbDeletePlainte\(/g) === 0, partout(/sbDeletePlainte\(/g) + ' appel(s)');

print('');
print('2. TRANSMISSION AU TRIBUNAL : UN IDENTIFIANT DERIVE, UNE ANNONCE SUBORDONNEE');
var bTrans = sansCommentaires(bloc('plateau-justice-economie.js', 'transmettreAffaireAuTribunal'));
att('transmettreAffaireAuTribunal est async',
    SRC['plateau-justice-economie.js'].indexOf('async function transmettreAffaireAuTribunal(') >= 0);
att('la porte est appelee une fois',
    compte(bTrans, /sbRpc\('affaire_transmettre'/g) === 1,
    compte(bTrans, /sbRpc\('affaire_transmettre'/g) + ' appel(s)');
att("l'identifiant ne vient plus d'une horloge",
    bTrans.indexOf("'affaire-' + Date.now()") < 0);
att('ni le pays ni le jour ne sont transmis a la porte',
    bTrans.indexOf('p_country') < 0 && bTrans.indexOf('p_jour') < 0);
att("l'etat local recopie l'affaire arretee par le serveur",
    bTrans.indexOf('vAff.affaire') >= 0);
att('un refus ARRETE la fonction avant toute publication',
    bTrans.indexOf('return false;') >= 0
    && bTrans.indexOf('return false;') < bTrans.indexOf('FORUM_TOPICS[forumKey]'));
att("le refus d'autorite est NOMME a part d'une panne",
    bTrans.indexOf("vAff.raison === 'autorite_refusee'") >= 0);
att('un rejeu ne republie rien sur le forum',
    bTrans.indexOf('vAff.deja_transmise === true') >= 0
    && bTrans.indexOf('vAff.deja_transmise === true') < bTrans.indexOf('FORUM_TOPICS[forumKey]'));
// SES DEUX APPELANTS L'ATTENDENT, ET LISENT SON RESULTAT. Sans cela la fonction serait async pour
// rien et les deux annonces publiques resteraient inconditionnelles.
var bEnq = sansCommentaires(bloc('plateau-justice-economie.js', 'traiterEnquetes'));
var bDem = sansCommentaires(bloc('plateau-justice-economie.js', 'confirmerMenerEnquete'));
att("l'appelant « enquete conclue » attend la transmission",
    bEnq.indexOf('await transmettreAffaireAuTribunal(') >= 0);
att('et son evenement public dit la verite',
    bEnq.indexOf('transmise ?') >= 0);
att("l'appelant « demasquage » attend la transmission",
    bDem.indexOf('await transmettreAffaireAuTribunal(') >= 0);
att('et son journal dit la verite',
    bDem.indexOf('transmiseDemasquage ?') >= 0);

print('');
print('3. DEFENSE DE L ACCUSE : QUATRE ISSUES NOMMEES, AUCUNE POSE LOCALE');
var bDef = sansCommentaires(bloc('plateau-justice-economie.js', 'doDefense'));
att('la porte est appelee une fois',
    compte(bDef, /sbRpc\('plainte_defendre'/g) === 1,
    compte(bDef, /sbRpc\('plainte_defendre'/g) + ' appel(s)');
att('les quatre issues de la liste close sont nommees',
    bDef.indexOf("issue = 'reussite_critique'") >= 0 && bDef.indexOf("issue = 'attenuante'") >= 0
    && bDef.indexOf("issue = 'aggravation'") >= 0 && bDef.indexOf("issue = 'infructueuse'") >= 0);
att("plus aucune pose locale du statut de l'affaire",
    bDef.indexOf("affaire.status =") < 0);
att('plus aucune pose locale de la circonstance attenuante ni de l aggravation',
    bDef.indexOf('affaire.circonstanceAttenuante =') < 0 && bDef.indexOf('affaire.aggravation =') < 0
    && bDef.indexOf('affaire.resultatDefense =') < 0);
att('le verdict est lu AVANT toute annonce',
    bDef.indexOf('vDef.ok !== true') >= 0
    && bDef.indexOf('vDef.ok !== true') < bDef.lastIndexOf('showToast(titre'));
att("l'affaire recopie l'etat arrete par le serveur",
    bDef.indexOf('state.plaintesEnCours[i] = vDef.affaire') >= 0);
att('les quatre motifs de refus de la porte sont nommes au joueur',
    bDef.indexOf("'affaire_non_defendable'") >= 0 && bDef.indexOf("'pas_mon_affaire'") >= 0
    && bDef.indexOf("'affaire_absente'") >= 0 && bDef.indexOf('frais ont été prélevés') >= 0);
// LE JET RESTE AU CLIENT, ET C'EST ASSUME : son taux depend de getStatEffective('CHA'), qui
// additionne bonusFormation -- un bonus temporaire persiste dans AUCUNE colonne. Le serveur ne
// peut pas le connaitre. Cette epreuve verifie que la raison est ECRITE a cote du jet, pour que
// personne ne prenne cette frontiere pour un oubli.
att('et la raison pour laquelle le jet reste ici est ECRITE a cote du jet',
    bloc('plateau-justice-economie.js', 'doDefense').indexOf('bonusFormation') >= 0);

print('');
print('4. CLASSEMENT MINISTERIEL : UNE PORTE, ET UN ECRAN QUI N EST PLUS VIDE');
var bAnn = sansCommentaires(bloc('plateau-politique.js', 'annulerAffaire'));
att('la porte est appelee une fois',
    compte(bAnn, /sbRpc\('plainte_classer_ministere'/g) === 1,
    compte(bAnn, /sbRpc\('plainte_classer_ministere'/g) + ' appel(s)');
att("plus aucune pose locale du statut « annulee »",
    bAnn.indexOf("affaire.status = 'annulee'") < 0);
att("l'etat local recopie l'affaire arretee par le serveur",
    bAnn.indexOf('state.plaintesEnCours[iAff] = vClass.affaire') >= 0);
att('le verdict est lu, et un refus ARRETE la fonction',
    bAnn.indexOf('vClass.ok !== true') >= 0
    && bAnn.indexOf('vClass.ok !== true') < bAnn.indexOf("showToast('Plainte classée'"));
att('un refus DIT que les frais ont deja ete preleves',
    bAnn.indexOf('ont déjà été prélevés') >= 0);
// L'ORDRE DES DEUX ACTES EST CONSERVE A DESSEIN : le mouvement de caisse porte DEJA la
// verification d'autorite ministerielle. Le deplacer apres le classement permettrait a un
// ministre de classer gratuitement quand la caisse est vide.
att('le mouvement de caisse precede toujours la porte',
    bAnn.indexOf('sbCaisseMinistereMouvement(') >= 0
    && bAnn.indexOf('sbCaisseMinistereMouvement(') < bAnn.indexOf("sbRpc('plainte_classer_ministere'"));
var bModal = sansCommentaires(bloc('plateau-politique.js', 'ouvrirModalAffaires'));
att("la liste ne filtre plus un statut que plus aucune affaire ne porte",
    bModal.indexOf("p.status === 'pending'") < 0);
att('elle filtre le statut reel d une affaire en cours avant jugement',
    bModal.indexOf("p.status === 'deposee'") >= 0);

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
