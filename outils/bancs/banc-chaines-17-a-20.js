// Banc STRUCTUREL des CHAINES 17 A 20 du chantier 5 (10 octobre 2026).
// SOURCES: aucune -- ce banc lit plateau-politique.js, plateau-justice-economie.js et supabase.js
// lui-meme, par readFile.
//
// POURQUOI CE BANC EST STRUCTUREL. Les quatre chaines vivent au milieu de fonctions d'interface
// qui ouvrent des modales, lisent `document`, composent du HTML et enchainent cinq a dix appels
// reseau. Les extraire demanderait de simuler tout cela ; le comportement des PORTES, lui, est
// eprouve en transaction annulee cote base -- 21 epreuves pour les chaines 18 et 20, 16 pour la
// 19. C'est la seule facon honnete de couper ce travail en deux.
//
// CE QUE CE BANC ETABLIT, chaine par chaine.
//
//   17 -- NOMINATION. La revocation de l'ancien titulaire etait une ecriture CLIENTE SUR LA FICHE
//   D'AUTRUI, donc une ecriture qui LEVE `personnage_non_possede` et dont le catch avalait
//   l'exception : elle n'a jamais deloge personne. Elle etait de plus REDONDANTE --
//   `poste_attribuer_interne` fait `SET poste = NULL` sur l'ancien titulaire dans la meme
//   transaction que l'attribution. Code mort, supprime.
//
//   18 -- DISSOLUTION. Trois vagues, aucune preuve. La revocation des deputes etait elle aussi
//   une ecriture sur la fiche d'autrui : LA DISSOLUTION N'A JAMAIS REVOQUE PERSONNE, alors que le
//   drapeau `dissolutionUtilisee` etait consomme et les scrutins relances. Les deux premieres
//   vagues sont desormais une seule transaction, avec compare-and-swap sur le drapeau ; la
//   troisieme reste au client mais son echec est NOMME.
//
//   19 -- CANDIDATURE. Le code affirmait que le blob du cycle etait « un cache best-effort ». Le
//   depouillement de minuit ne lit QUE lui. Un candidat qui avait paye ses 2 PA pouvait etre
//   absent du bulletin.
//
//   20 -- BUREAU DE L'EMPLOI. Quatre lectures-modifications-ecritures d'un blob PARTAGE, et un
//   plafond de places verifie sur une lecture perimee -- deux joueurs pouvaient prendre la meme
//   derniere place.
var RACINE = '/Users/fredericjasseron/ResPublica/';
var FICHIERS = ['plateau-politique.js', 'plateau-justice-economie.js', 'supabase.js'];
var SRC = {};
for (var f = 0; f < FICHIERS.length; f++) SRC[FICHIERS[f]] = readFile(RACINE + FICHIERS[f]);
// Les commentaires de ce lot NOMMENT les defauts fermes : les compter reviendrait a declarer un
// defaut present parce qu'on explique qu'il a disparu.
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
print('BANC DES CHAINES 17 A 20');
print('============================================================================');

print('17. NOMINATION : LA REVOCATION MORTE A DISPARU');
var bNom = sansCommentaires(bloc('plateau-politique.js', 'accepterCandidaturePoste'));
att("plus aucune ecriture cliente sur la fiche de l'ancien titulaire",
    compte(bNom, /sbUpdate\('personnages'/g) === 0,
    compte(bNom, /sbUpdate\('personnages'/g) + ' occurrence(s)');
att("la porte d'attribution est toujours appelee",
    bNom.indexOf("sbRpc('poste_attribuer_candidature'") >= 0);
att('la protection de sept jours est conservee',
    bNom.indexOf('estPosteProtege(') >= 0);
att('et son refus precede tout effet de bord',
    bNom.indexOf('estPosteProtege(') < bNom.indexOf("sbRpc('poste_attribuer_candidature'"));

print('');
print('18. DISSOLUTION : LES TROIS VAGUES');
var bDis = sansCommentaires(bloc('plateau-politique.js', 'doDissoudreAssemblee'));
att('la porte de dissolution est appelee une fois',
    compte(bDis, /sbRpc\('assemblee_dissoudre'/g) === 1,
    compte(bDis, /sbRpc\('assemblee_dissoudre'/g) + ' appel(s)');
att('plus aucune boucle de revocation cliente',
    compte(bDis, /sbUpdate\('personnages'/g) === 0,
    compte(bDis, /sbUpdate\('personnages'/g) + ' occurrence(s)');
att('plus aucune pose cliente du drapeau de dissolution',
    bDis.indexOf('dissolutionUtilisee: true') < 0);
att("le verdict est lu, et un refus ARRETE la dissolution",
    bDis.indexOf('!vRevoc || vRevoc.ok !== true') >= 0 && bDis.indexOf('return;') >= 0);
att("« deja utilisee » est nomme a part d'une panne",
    bDis.indexOf("vRevoc.raison === 'dissolution_deja_utilisee'") >= 0);
att('le nombre de revoques vient du SERVEUR, jamais du compteur de boucle',
    bDis.indexOf('Number(vRevoc.revoques)') >= 0);
att("le drapeau recopie l'etat arrete par le serveur",
    bDis.indexOf("CYCLES_ELECTORAUX[pays]['president'] = vRevoc.cycle_president") >= 0);
att('la troisieme vague LIT desormais son resultat',
    bDis.indexOf('const posee = (typeof sbSaveCycleElectoral') >= 0
    && bDis.indexOf('if (!posee) {') >= 0);
att('et une circonscription non relancee est NOMMEE au joueur',
    bDis.indexOf('circonscriptionsNonRelancees.join') >= 0);
att('le compteur ne compte plus les tours de boucle mais les ecritures reussies',
    bDis.indexOf('circonscriptionsNonRelancees.push(ville)') >= 0);

// SANS CE CORRECTIF, LA TROISIEME VAGUE ETAIT INVERIFIABLE PAR CONSTRUCTION.
var bSave = sansCommentaires(bloc('plateau-politique.js', 'sbSaveCycleElectoral'));
att('sbSaveCycleElectoral rend enfin un verdict',
    compte(bSave, /return await sb(Update|Insert)\(/g) === 2,
    compte(bSave, /return await sb(Update|Insert)\(/g) + ' retour(s)');
att("et son catch rend null au lieu de rien", bSave.indexOf('catch(e) { return null; }') >= 0);

print('');
print('19. CANDIDATURE : LES DEUX REPRESENTATIONS DANS UNE TRANSACTION');
var bCand = sansCommentaires(bloc('plateau-politique.js', 'confirmerCandidature'));
att('la porte est appelee une fois',
    compte(bCand, /sbRpc\('candidature_deposer'/g) === 1,
    compte(bCand, /sbRpc\('candidature_deposer'/g) + ' appel(s)');
att('plus aucune ecriture avalee du blob du cycle',
    compte(bCand, /sbSaveCycleElectoral\(/g) === 0,
    compte(bCand, /sbSaveCycleElectoral\(/g) + ' occurrence(s)');
att('plus aucun push local au bulletin', bCand.indexOf('cycle.candidats.push(') < 0);
att("le bulletin recopie l'etat arrete par le serveur",
    bCand.indexOf('vCand.cycle') >= 0);
att('le verdict est lu avant toute annonce',
    bCand.indexOf('vCand && vCand.ok === true') >= 0);
att('le remboursement atteste des PA est conserve',
    bCand.indexOf("sbRpc('pa_crediter_atteste'") >= 0);
att('sbDeposerCandidature, qui n ecrivait qu une moitie, a disparu',
    SRC['plateau-politique.js'].indexOf('async function sbDeposerCandidature(') < 0);
att('sbGetCandidatures, qui ne fait que lire, est conservee',
    SRC['plateau-politique.js'].indexOf('async function sbGetCandidatures(') >= 0);

print('');
print('20. BUREAU DE L EMPLOI : UNE PORTE POUR LES QUATRE ACTES');
var dJE = CODE['plateau-justice-economie.js'];
// TROIS SITES D'APPEL POUR CINQ ACTES, et c'est volontaire : la prise de poste et la reservation
// sont le MEME site (l'acte depend de l'emploi en cours), et les deux issues de l'arbitrage aussi.
// Les quatre chemins du navigateur avaient quatre fois la meme lecture-modification-ecriture ;
// ils ont desormais trois appels et une seule porte.
att('trois sites d appel pour les cinq actes',
    compte(dJE, /sbRpc\('bne_agir'/g) === 3, compte(dJE, /sbRpc\('bne_agir'/g) + ' appel(s)');
att('les cinq actes sont nommes dans les appels',
    dJE.indexOf("'reserver' : 'prendre'") >= 0
    && dJE.indexOf("'trancher_garder' : 'trancher_prendre'") >= 0
    && dJE.indexOf("p_acte: 'demissionner'") >= 0);
att('plus aucune ecriture du blob partage',
    compte(dJE, /sbSetEtatBNE\(/g) === 0, compte(dJE, /sbSetEtatBNE\(/g) + ' occurrence(s)');
att('sbSetEtatBNE a disparu de supabase.js',
    CODE['supabase.js'].indexOf('async function sbSetEtatBNE(') < 0);
att('sbGetEtatBNE, qui ne fait que lire, est conservee',
    CODE['supabase.js'].indexOf('async function sbGetEtatBNE(') >= 0);
att('le plafond de places n est plus verifie dans le navigateur',
    dJE.indexOf('placesPrises >= offre.places') < 0);
att("le plafond n'est jamais transmis a la porte",
    compte(dJE, /p_places/g) === 0, compte(dJE, /p_places/g) + ' occurrence(s)');
att("l'emploi actuel recopie celui que le serveur a arrete",
    compte(dJE, /vBne\.emploi_actuel/g) >= 3,
    compte(dJE, /vBne\.emploi_actuel/g) + ' occurrence(s)');
att('chaque refus de la porte est NOMME au joueur',
    dJE.indexOf('function signalerRefusBNE(') >= 0
    && compte(dJE, /signalerRefusBNE\(/g) >= 4,
    compte(dJE, /signalerRefusBNE\(/g) + ' appel(s)');
att('les quatre motifs metier du BNE sont nommes',
    dJE.indexOf('poste_complet:') >= 0 && dJE.indexOf('arbitrage_en_attente:') >= 0
    && dJE.indexOf('aucun_emploi:') >= 0 && dJE.indexOf('offre_inconnue:') >= 0);

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
