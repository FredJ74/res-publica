// Banc STRUCTUREL du bloc du CALENDRIER ELECTORAL -- api/cron-minuit.js (chantier 6, famille C,
// 10 octobre 2026).
// SOURCES: aucune -- ce banc lit api/cron-minuit.js lui-meme, par readFile.
//
// POURQUOI CE BANC EST STRUCTUREL, ET PAS COMPORTEMENTAL. Le depouillement du calendrier
// electoral n'est pas une fonction : c'est un bloc INLINE dans le gestionnaire du cron, entre la
// lecture des cycles et la cascade de nomination. On ne peut pas l'extraire comme on extrait
// `preleverTaxeFonciere` ; l'appeler voudrait dire executer la passe de minuit entiere. Le
// comportement de la PORTE, lui, est eprouve en transaction annulee cote base (6 epreuves) --
// c'est la seule facon honnete de couper ce travail en deux.
//
// CE QUE CE BANC ETABLIT. Dans la portee exacte du bloc electoral :
//   1. il n'y a plus AUCUNE ecriture directe de `evenements_globaux` ni de `chronique_nationale`
//      -- c'etait la source du defaut : l'annonce publique partait avant le drapeau du cycle, et
//      un rejeu la reproduisait ;
//   2. il y a EXACTEMENT UNE consignation, par election_resultats_consigner ;
//   3. les trois ecritures directes de `cycles_electoraux` qui subsistent dans le fichier sont
//      les trois TRANSITIONS D'ETAT documentees -- renouvellement de mandat, relance apres
//      vacance, cascade PNJ -- et chacune porte en commentaire la raison de rester directe.
//
// ET IL ETABLIT UN FAIT QUE L'AUDIT AVAIT FAUX : le depouillement est DETERMINISTE. Aucun
// `random()` dans resoudreScrutinSimple ni dans resoudreScrutinDepute. Un rejeu recalcule le meme
// vainqueur ; ce qu'il dupliquait, c'etait l'annonce.
var src = readFile(typeof CHEMIN_SOURCE === 'string'
  ? CHEMIN_SOURCE : '/Users/fredericjasseron/ResPublica/api/cron-minuit.js');

var ko = 0, attendus = 0;
function att(n, c, detail) {
  attendus++;
  if (c) print('  ok  ' + n);
  else { print('  *** ' + n); if (detail !== undefined) print('        ' + detail); ko++; }
}
function compte(texte, motif) { return (texte.match(motif) || []).length; }

// La portee du bloc electoral : de la lecture des cycles a la cascade de nomination.
var iDebut = src.indexOf("const dateResultats = cycle.dateResultats;");
var iFin   = src.indexOf("// 1b. Cascade de nomination automatique");
if (iDebut < 0 || iFin < 0 || iFin <= iDebut) {
  print('  *** le bloc electoral est introuvable : les ancres ont change');
  print('ECHEC : 1 epreuve sur 1 en defaut.');
} else {
var bloc = src.slice(iDebut, iFin);

print('');
print('1. PLUS AUCUNE ANNONCE ECRITE EN DIRECT DANS LE BLOC');
att("aucun sbInsert('evenements_globaux')",
    compte(bloc, /sbInsert\('evenements_globaux'/g) === 0,
    compte(bloc, /sbInsert\('evenements_globaux'/g) + ' occurrence(s)');
att("aucun sbInsert('chronique_nationale')",
    compte(bloc, /sbInsert\('chronique_nationale'/g) === 0,
    compte(bloc, /sbInsert\('chronique_nationale'/g) + ' occurrence(s)');
att("aucun sbUpdate('cycles_electoraux') dans la portee du depouillement",
    compte(bloc, /sbUpdate\('cycles_electoraux'/g) === 0,
    compte(bloc, /sbUpdate\('cycles_electoraux'/g) + ' occurrence(s)');

print('');
print('2. UNE SEULE CONSIGNATION, ET SON VERDICT EST LU');
// On compte l'APPEL, pas le nom : celui-ci apparait aussi dans le commentaire qui explique la
// consignation unique, et compter les occurrences nues rendait 2 pour un seul appel.
att('exactement un appel a election_resultats_consigner',
    compte(bloc, /sbRpc\('election_resultats_consigner'/g) === 1,
    compte(bloc, /sbRpc\('election_resultats_consigner'/g) + ' appel(s)');
att("il porte l'identite serveur", bloc.indexOf('HEADERS_SERVICE') >= 0);
att('les quatre arguments sont transmis',
    bloc.indexOf('p_cycle_id: row.id') >= 0 && bloc.indexOf('p_data: blobAEcrire || cycle') >= 0
    && bloc.indexOf('p_evenement: evenementAPoser') >= 0
    && bloc.indexOf('p_chronique: chroniqueAPoser') >= 0);
att('le verdict est lu', bloc.indexOf("vCons.ok !== true") >= 0);
att("« deja_traite » n'est pas compte comme un echec",
    bloc.indexOf("vCons.raison !== 'deja_traite'") >= 0);
att('tout autre refus est signale', bloc.indexOf("signalerEchec('election_resultats:") >= 0);

print('');
print('3. CHAQUE BRANCHE DECIDE, AUCUNE N ECRIT');
att('les trois variables de consignation sont declarees',
    src.indexOf('let blobAEcrire = null, evenementAPoser = null, chroniqueAPoser = null;') >= 0);
att('le vote blanc majoritaire depose son blob, il ne l ecrit pas',
    compte(bloc, /blobAEcrire = construireNouveauCycleElectoral/g) === 2,
    compte(bloc, /blobAEcrire = construireNouveauCycleElectoral/g) + ' branche(s)');
att('les deux proclamations deposent leur chronique',
    compte(bloc, /chroniqueAPoser = \{/g) === 2,
    compte(bloc, /chroniqueAPoser = \{/g) + ' chronique(s)');
att('les cinq annonces publiques sont deposees',
    compte(bloc, /evenementAPoser = \{/g) === 5,
    compte(bloc, /evenementAPoser = \{/g) + ' annonce(s)');
att("plus aucun `continue` ne saute la consignation",
    compte(bloc, /statut: 'invalide_vote_blanc' \}\);\s*\n\s*continue;/g) === 0);

print('');
print('4. LE DEPOUILLEMENT EST DETERMINISTE — CE QUE L AUDIT AVAIT FAUX');
var iSimple = src.indexOf('function resoudreScrutinSimple(');
var iDepute = src.indexOf('function resoudreScrutinDepute(');
var iApres  = src.indexOf('function departageCandidats(');
att('resoudreScrutinSimple ne tire rien au sort',
    iSimple >= 0 && compte(src.slice(iSimple, iDepute), /Math\.random/g) === 0);
att('resoudreScrutinDepute ne tire rien au sort',
    iDepute >= 0 && iApres > iDepute && compte(src.slice(iDepute, iApres), /Math\.random/g) === 0);
att("l'egalite est departagee par l'anciennete, pas par le hasard",
    src.indexOf('departageCandidats(candidats, a[0], b[0])') >= 0);

print('');
print('5. LES TROIS ECRITURES DIRECTES QUI RESTENT SONT LES TRANSITIONS DOCUMENTEES');
att('il en reste exactement trois dans le fichier',
    compte(src, /sbUpdate\('cycles_electoraux'/g) === 3,
    compte(src, /sbUpdate\('cycles_electoraux'/g) + ' occurrence(s)');
att('le renouvellement de mandat dit pourquoi il reste direct',
    src.indexOf("CETTE ECRITURE RESTE DIRECTE, ET C'EST LE BON CHOIX") >= 0);
att('la relance apres vacance dit pourquoi',
    src.indexOf('MEME RAISON QUE LE RENOUVELLEMENT CI-DESSUS') >= 0);
att('la cascade PNJ dit pourquoi',
    src.indexOf('ECRITURE DIRECTE ASSUMEE') >= 0);

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
}
