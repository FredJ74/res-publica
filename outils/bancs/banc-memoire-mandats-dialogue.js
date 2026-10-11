// BANC DU QUATRIEME CANAL : LA MEMOIRE DES MANDATS (11 octobre 2026)
// SOURCES: api/_bible-assemblee.js api/_bible-gouvernement.js api/_bible-militaire.js api/_bible-presidence.js api/_pnj-personnalites.js api/_pnj-referents.js api/_pnj-profils.js
//
// CE QU'IL PROUVE. Le serveur garde une memoire des presidences ; ce banc verifie ce que le
// DIALOGUE en fait, et surtout ce qu'il refuse d'en faire :
//   . sans memoire, le prompt est RIGOUREUSEMENT celui d'avant, caractere pour caractere ;
//   . une memoire VIDE n'est pas un silence : Huguette recoit la consigne explicite de ne pas
//     inventer de predecesseur -- sans elle, un modele en invente un ;
//   . un contexte SUIVI d'une reaction se raconte comme un enchainement ;
//   . un contexte SANS suite se raconte comme « je n'ai rien vu venir », JAMAIS comme une faute ;
//   . aucun score, aucun classement, aucun bilan, nulle part ;
//   . elle ne raconte QUE ce qu'elle a vu, et le bloc le lui dit ;
//   . et le CANAL EST ETROIT : un seul profil le demande au serveur, les 210 autres non.
//
// Usage : python3 outils/bancs/lancer-banc.py outils/bancs/banc-memoire-mandats-dialogue.js
var ok = 0, ko = 0;
function att(n, c, d) { if (c) { print('  ok  ' + n); ok++; } else { print('  *** ' + n + (d !== undefined ? ' -- ' + d : '')); ko++; } }
function contient(s, frag) { return s.indexOf(frag) >= 0; }

var VIDE   = { ok: true, mandats: [], vide: true };
var UN     = { ok: true, vide: false, mandats: [
  { president: 'Lee Capene', depuis: '2026-10-01T00:00:00Z', en_cours: true, faits: [
    { genre: 'contexte', sujet: 'la guerre declaree par narco', jour: 3, suivi_de: 'un dementi officiel' },
    { genre: 'contexte', sujet: 'un scandale au ministere des Finances', jour: 5, suivi_de: null },
    { genre: 'reaction', sujet: 'une grace examinee', jour: 6, suivi_de: null }
  ]}
]};
var DEUX   = { ok: true, vide: false, mandats: [
  { president: 'Lee Capene', depuis: '2026-10-09T00:00:00Z', en_cours: true, faits: [
    { genre: 'reaction', sujet: 'une conference de presse', jour: 9, suivi_de: null }]},
  { president: 'Bartesto Chevara', depuis: '2026-09-01T00:00:00Z', en_cours: false, faits: [
    { genre: 'contexte', sujet: 'une greve generale', jour: 1, suivi_de: null }]}
]};

print('');
print('SANS MEMOIRE, RIEN NE CHANGE');
print('============================================================');
var base = construirePromptSysteme('huguette_papier', 'fr', null, null, null);
att('le prompt sans memoire est inchange, caractere pour caractere',
    construirePromptSysteme('huguette_papier', 'fr', null, null, null, null) === base);
att('une memoire en echec ne pose rien',
    construirePromptSysteme('huguette_papier', 'fr', null, null, null, { ok: false }) === base);
att('une memoire qui n est pas un objet ne pose rien',
    construirePromptSysteme('huguette_papier', 'fr', null, null, null, 'rien') === base);
att('aucun bloc de memoire dans le prompt nu', !contient(base, 'LA MEMOIRE DES MANDATS'));

print('');
print('UNE MEMOIRE VIDE EST UNE CONSIGNE, PAS UN SILENCE');
print('============================================================');
var pv = construirePromptSysteme('huguette_papier', 'fr', null, null, null, VIDE);
att('le bloc est pose', contient(pv, 'LA MEMOIRE DES MANDATS'));
att('elle sait n avoir vu AUCUNE presidence', contient(pv, 'AUCUNE presidence tenue par une'));
att('et il lui est interdit d inventer un predecesseur',
    contient(pv, "N'invente aucun predecesseur"));

print('');
print('CE QU ELLE RACONTE D UN MANDAT');
print('============================================================');
var p1 = construirePromptSysteme('huguette_papier', 'fr', null, null, null, UN);
att('le mandat en cours est marque comme tel', contient(p1, 'MANDAT EN COURS de Lee Capene'));
att('un contexte suivi d une reaction se raconte comme un enchainement',
    contient(p1, 'il a fallu faire face a la guerre declaree par narco, et ce qui a suivi a ete un dementi officiel.'));
att('une reaction se raconte comme un acte',
    contient(p1, 'il a accompli une grace examinee.'));

print('');
print("L'ABSENCE DE SUITE EST UNE OBSERVATION, PAS UN REPROCHE");
print('============================================================');
att('un contexte sans suite se dit « rien vu venir »',
    contient(p1, "un scandale au ministere des Finances, et tu n'as rien vu venir ensuite"));
att('et la consigne interdit d en tirer une conclusion',
    contient(p1, "sans en tirer de conclusion"));
// LE POINT CENTRAL DE L'ARBITRAGE : l'inaction est une information, jamais un verdict.
['a failli', 'negligen', 'mauvais President', 'bon President', 'echec du mandat'].forEach(function (v) {
  att('le bloc ne contient pas : ' + v, !contient(p1, v));
});

print('');
print('AUCUNE QUALIFICATION, NULLE PART');
print('============================================================');
att('elle ne note pas les presidences', contient(p1, 'TU NE NOTES PAS LES PRESIDENCES'));
att('aucun classement ni score annonce',
    contient(p1, "aucun classement, aucun score, aucun bilan chiffre"));
['score :', 'classement :', 'note de', '/10', '/20'].forEach(function (v) {
  att('le bloc ne chiffre pas : ' + v, !contient(p1, v));
});
att('elle ne raconte QUE ce qu elle a vu',
    contient(p1, "tu ne racontes QUE ce qui est ci-dessus"));

print('');
print('LA SEPARATION DES MANDATS SE VOIT DANS LE PROMPT');
print('============================================================');
var p2 = construirePromptSysteme('huguette_papier', 'fr', null, null, null, DEUX);
att('les deux presidences sont nommees separement',
    contient(p2, 'MANDAT EN COURS de Lee Capene') && contient(p2, 'mandat de Bartesto Chevara'));
att('le mandat termine n est PAS marque en cours',
    !contient(p2, 'MANDAT EN COURS de Bartesto Chevara'));

print('');
print("L'ORDRE DES QUATRE CANAUX");
print('============================================================');
var po = construirePromptSysteme('huguette_papier', 'fr',
  { rencontres: 3, conversations: 1, familiarite: 1 }, null,
  { ok: true, nom: 'Arnie', fonctions: ['Ministre de la Defense'] }, UN);
var iPub = po.indexOf('A QUI TU PARLES'), iRel = po.indexOf('VOTRE RELATION'),
    iMem = po.indexOf('LA MEMOIRE DES MANDATS');
att('les trois blocs coexistent sans se melanger', iPub > 0 && iRel > 0 && iMem > 0);
att('le contexte public precede la relation, qui precede la memoire nationale',
    iPub < iRel && iRel < iMem, iPub + ' < ' + iRel + ' < ' + iMem);

print('');
print('LE CANAL EST ETROIT : UN SEUL PROFIL LE DEMANDE');
print('============================================================');
// STRUCTUREL, et volontairement : le filtrage vit dans api/chat.js, pas dans l'assemblage du
// prompt. Verifier le prompt ne dirait rien de l'appel qui n'est pas emis.
var CHAT = readFile('/Users/fredericjasseron/ResPublica/api/chat.js');
att('le canal est nomme par une constante dediee',
    contient(CHAT, "const MEMOIRE_DES_MANDATS = 'huguette_papier'"));
att('et il conditionne reellement l appel',
    contient(CHAT, 'profilId === MEMOIRE_DES_MANDATS'));
att('les autres profils ne declenchent aucun appel',
    contient(CHAT, ': Promise.resolve(null)'));
att('la porte appelee ne prend AUCUN pays',
    contient(CHAT, 'presidence_memoire_mon_pays:  () => ({})'));
att('la memoire est bien le QUATRIEME argument de contexte, apres le contexte public',
    contient(CHAT, 'relation, pedagogie, contextePublic, mandats'));

print('');
print('============================================================');
if (ko === 0) print('LES ' + ok + ' EPREUVES SONT VERTES.');
else print(ko + ' EPREUVES ROUGES SUR ' + (ok + ko) + '.');
