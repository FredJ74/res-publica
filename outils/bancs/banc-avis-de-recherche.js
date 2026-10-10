// Banc de L'AVIS DE RECHERCHE -- chaine 14 du chantier 5 (10 octobre 2026).
// SOURCES: aucune -- ce banc lit les cinq fichiers de production lui-meme, par readFile.
//
// CE QUE CE BANC ETABLIT. L'inventaire nommait UN site. Le releve exhaustif en a trouve
// DIX-HUIT, et ils formaient un seul mecanisme : treize `state.recherche.push(...)` purement
// locaux dans cinq fichiers, une lecture-modification-ecriture serveur avalee, quatre retraits
// par `filter` cote client, et une troisieme instance dans le cron. Tous comptaient sur
// `sbSavePersonnage`, qui republie `recherche` EN BLOC parmi 48 colonnes.
//
// LE DEFAUT N'ETAIT PAS « une ecriture directe » : c'etait un DERNIER-ECRIVAIN-GAGNANT. Le
// tableau n'a aucune cle, donc rien ne permet de fusionner deux versions.
//
// Le banc prouve les deux moities : plus aucun site ne pousse ni ne filtre le tableau lui-meme,
// et les deux helpers recopient l'etat ARRETE PAR LE SERVEUR au lieu de le recalculer. Le
// comportement de la porte, lui, est eprouve en transaction annulee cote base (19 epreuves),
// dont une qui REPRODUIT le defaut a l'ancienne pour montrer qu'il perdait bien une entree.
var RACINE = '/Users/fredericjasseron/ResPublica/';
var FICHIERS = ['plateau-justice-economie.js', 'plateau-politique.js', 'plateau-pnj.js',
                'plateau-actions-illegales-rumeurs.js', 'plateau-communication.js',
                'api/cron-minuit.js'];
var SRC = {};
for (var f = 0; f < FICHIERS.length; f++) {
  SRC[FICHIERS[f]] = readFile((typeof CHEMIN_SOURCE === 'string' && FICHIERS[f] === 'plateau-justice-economie.js')
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
print('BANC DE L AVIS DE RECHERCHE (chaine 14)');
print('============================================================================');

print('1. PLUS AUCUN SITE N ECRIT LE TABLEAU LUI-MEME');
att('aucun state.recherche.push dans les six fichiers',
    partout(/state\.recherche\.push/g) === 0, partout(/state\.recherche\.push/g) + ' occurrence(s)');
att('aucun state.recherche = ... .filter',
    partout(/state\.recherche\s*=\s*\(?state\.recherche/g) === 0,
    partout(/state\.recherche\s*=\s*\(?state\.recherche/g) + ' occurrence(s)');
att("aucun sbUpdate('personnages', ..., { recherche",
    partout(/\{\s*recherche:\s*/g) === 0, partout(/\{\s*recherche:\s*/g) + ' occurrence(s)');
// IL RESTE UNE RELECTURE, ET ELLE EST LEGITIME : verifierArrestationRecherchePolice lit la
// colonne pour decider si une condamnation en attente rattrape le joueur. Lire l'etat
// AUTORITAIRE plutot que le cache local est exactement ce qu'on veut. Ce qu'on refuse, c'est
// une relecture SUIVIE D'UNE REECRITURE -- et cette fonction n'ecrit pas la colonne.
att('la seule relecture restante ne reecrit pas la colonne',
    partout(/select=recherche/g) === 1
    && bloc('plateau-justice-economie.js', 'verifierArrestationRecherchePolice')
         .indexOf('recherche:') < 0,
    partout(/select=recherche/g) + ' relecture(s)');

print('');
print('2. LES DEUX PORTES SONT LES SEULS CHEMINS, ET ELLES SONT NOMMEES');
att("un seul appel a sbRpc('recherche_inscrire') cote client",
    compte(CODE['plateau-justice-economie.js'], /sbRpc\('recherche_inscrire'/g) === 1);
att("un seul appel a sbRpc('recherche_retirer') cote client",
    compte(CODE['plateau-justice-economie.js'], /sbRpc\('recherche_retirer'/g) === 1);
att('le cron a son propre appel, avec sa cible nommee',
    compte(CODE['api/cron-minuit.js'], /sbRpc\('recherche_inscrire'/g) === 1
    && CODE['api/cron-minuit.js'].indexOf('p_cible: entree.nom') >= 0);
att('les treize inscriptions passent par le helper',
    partout(/inscrireRecherche\(/g) >= 12, partout(/inscrireRecherche\(/g) + ' appel(s)');
att('les quatre retraits passent par le helper',
    partout(/retirerRecherche\(/g) >= 5, partout(/retirerRecherche\(/g) + ' appel(s)');

print('');
print('3. LES HELPERS RECOPIENT L ETAT DU SERVEUR, ILS NE LE RECALCULENT PAS');
var hInscrire = bloc('plateau-justice-economie.js', 'inscrireRecherche');
var hRetirer = bloc('plateau-justice-economie.js', 'retirerRecherche');
att("inscrireRecherche lit le verdict", hInscrire.indexOf('v.ok !== true') >= 0);
att("inscrireRecherche recopie le tableau du serveur",
    hInscrire.indexOf('state.recherche = v.recherche') >= 0);
att("inscrireRecherche ne pousse rien localement",
    hInscrire.indexOf('.push(') < 0);
att("retirerRecherche lit le verdict", hRetirer.indexOf('v.ok !== true') >= 0);
att("retirerRecherche recopie le tableau du serveur",
    hRetirer.indexOf('state.recherche = v.recherche') >= 0);
att("retirerRecherche ne filtre rien localement",
    hRetirer.indexOf('.filter(') < 0);
att('un appel qui n aboutit pas rend false, et ne touche pas l etat',
    hInscrire.indexOf('return false') >= 0 && hRetirer.indexOf('return false') >= 0);

print('');
print('4. LA RUSTINE QUI DISAIT LE DEFAUT A DISPARU');
att("le reflet local « obligatoire » n'existe plus",
    SRC['plateau-justice-economie.js'].indexOf('REFLET LOCAL OBLIGATOIRE') < 0);
att("ajouterCondamnationRechercheLocale ne relit plus la colonne",
    bloc('plateau-justice-economie.js', 'ajouterCondamnationRechercheLocale').indexOf('sbGet') < 0);
att("le reflet du mandat calomnieux recopie le verdict au lieu de pousser",
    CODE['plateau-communication.js'].indexOf('await inscrireRecherche(res.mandat)') >= 0);

print('');
print('5. LES TROIS FONCTIONS QUI ONT DU PASSER EN ASYNC L ONT FAIT');
att('checkDetection est async',
    SRC['plateau-justice-economie.js'].indexOf('async function checkDetection(') >= 0);
att('procederArrestation est async',
    SRC['plateau-justice-economie.js'].indexOf('async function procederArrestation(') >= 0);
att('tenterResistance est async',
    SRC['plateau-justice-economie.js'].indexOf('async function tenterResistance(') >= 0);

// ET L'ORDRE COMPTE : dans procederArrestation, l'attente est en DERNIER. Deux de ses onze
// appelants lisent `state.estEmprisonne` juste apres leur appel ; une attente placee avant leur
// rendrait la main sur un etat incomplet.
var bArr = bloc('plateau-justice-economie.js', 'procederArrestation');
att("dans procederArrestation, l'attente de la porte est la DERNIERE instruction",
    bArr.lastIndexOf('await retirerRecherche(') > bArr.lastIndexOf('state.estEmprisonne.motifDesertionSeul')
    && bArr.lastIndexOf('await retirerRecherche(') > bArr.lastIndexOf('teleporterVersCellule('),
    'retrait a ' + bArr.lastIndexOf('await retirerRecherche(')
    + ', drapeau a ' + bArr.lastIndexOf('state.estEmprisonne.motifDesertionSeul')
    + ', teleportation a ' + bArr.lastIndexOf('teleporterVersCellule('));
att("une seule attente de retrait dans procederArrestation",
    compte(sansCommentaires(bArr), /await retirerRecherche\(/g) === 1,
    compte(sansCommentaires(bArr), /await retirerRecherche\(/g) + ' occurrence(s)');

print('');
print('6. LE CRON NE FAIT PLUS DE LECTURE-MODIFICATION-ECRITURE');
var bCron = sansCommentaires(bloc('api/cron-minuit.js', 'traiterDesertionsServeur'));
att("plus aucune relecture de recherche dans le cron", bCron.indexOf('select=recherche') < 0);
att("plus aucun push dans le cron", bCron.indexOf('recherche.push') < 0);
att("l'echec de l'inscription est SIGNALE, jamais avale",
    bCron.indexOf("signalerEchec('desertion_recherche:") >= 0);

print('');
print('7. CHAINE 15 : PLUS AUCUNE ECRITURE EN COURSE SUR LA MEME LIGNE');
// L'inventaire decrivait la chaine 15 comme « sbSavePersonnage (48 colonnes) immediatement suivi
// d'un sbUpdate('personnages', ...) cible, les deux avales ». Les deux sites etaient dans les
// deux chemins de desertion -- donc exactement les memes fonctions que la chaine 14.
var dPol = CODE['plateau-politique.js'];
// La portee est les DEUX chemins de desertion. Les cinq autres sbUpdate('personnages') du
// fichier relevent d'autres chaines (17 et 18 pour la revocation d'un titulaire et des deputes)
// ou d'autres mecanismes : les compter ici ferait rougir ce banc pour un defaut qui n'est pas le
// sien.
att("plus aucun sbUpdate('personnages') dans les deux chemins de desertion",
    compte(sansCommentaires(bloc('plateau-politique.js', 'eteindrePoursuitesDesertion')),
           /sbUpdate\('personnages'/g) === 0
    && compte(sansCommentaires(bloc('plateau-politique.js', 'doAccepterIncorporation')),
           /sbUpdate\('personnages'/g) === 0);
att("plus aucune requisition serialisee en chaine avant d'etre ecrite",
    dPol.indexOf('JSON.stringify(state.char.requisition)') < 0);
att("sbSavePersonnage reste le seul ecrivain du blob dans ces deux chemins",
    compte(sansCommentaires(bloc('plateau-politique.js', 'eteindrePoursuitesDesertion')),
           /sbSavePersonnage\(/g) === 1
    && compte(sansCommentaires(bloc('plateau-politique.js', 'doAccepterIncorporation')),
           /sbSavePersonnage\(/g) === 1);

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
