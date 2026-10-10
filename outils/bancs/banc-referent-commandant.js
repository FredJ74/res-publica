// BANC DU REFERENT MILITAIRE DE LA CASERNE (10 octobre 2026)
// SOURCES: api/_bible-militaire.js api/_pnj-personnalites.js api/_pnj-referents.js api/_pnj-profils.js
//
// CE QU'IL PROUVE. Le Commandant Tom Hawak etait le titulaire PNJ du poste `commandant` depuis
// le 10 aout 2026 et n'existait que comme chaine de caracteres dans le cron : ni fiche, ni voix.
// Ce banc verifie qu'il a desormais un profil servi par la MEME voie que les autres referents,
// que son corpus couvre REELLEMENT la chaine que l'arbitrage lui confie -- du recrutement d'un
// soldat au financement de la caserne -- et qu'il ne recoit pas ce qui n'est pas son rayon.
//
// Il verifie aussi que « General Faure » n'a plus de profil : un referent retire de la piece mais
// laisse dans la table resterait adressable, donc vivant.
//
// Usage : python3 outils/bancs/lancer-banc.py outils/bancs/banc-referent-commandant.js
var ok = 0, ko = 0;
function att(n, c, d) { if (c) { print('  ok  ' + n); ok++; } else { print('  *** ' + n + (d !== undefined ? ' -- ' + d : '')); ko++; } }
print('');
print('PROFIL DU COMMANDANT TOM HAWAK');
print('============================================================');
att('le profil existe cote serveur', profilExiste('commandant_tom_hawak'));
att('general_faure n a plus de profil', !profilExiste('general_faure'));
att('les quatre autres referents militaires sont intacts',
    profilExiste('martial_bouterin') && profilExiste('gaspard_ferriere')
    && profilExiste('caporal_alouche') && profilExiste('eve_toahemarch'));
var sys = construirePromptSysteme('commandant_tom_hawak', 'fr', null, null);
att('son prompt est assemble', typeof sys === 'string' && sys.length > 2000, 'longueur=' + (sys || '').length);
att('il porte son identite', sys.indexOf('Commandant Tom Hawak') >= 0);
['Commandant de la caserne, Capitaine, Lieutenant, soldat',
 'IL N EXISTE AUCUN GRADE DE GENERAL'.replace(' N ', " N'"),
 'Le Commandant cree les compagnies et recrute les Capitaines',
 'Le Capitaine peut demettre un Lieutenant',
 'Chaque Lieutenant installe fait entrer jusqu',
 'LE MINISTRE NE PEUT PLUS Y TOUCHER',
 'REVERSER de l',
 'INSPECTION DES TROUPES',
 'Lieutenant, Capitaine, Commandant, ministre de la Defense',
 '400 pour un Commandant',
 'S\'ENGAGER',
 'ARMURERIE',
 'ENTRAINEMENT'].forEach(function (frag) {
  att('son corpus contient : ' + frag.slice(0, 44), sys.indexOf(frag) >= 0);
});
att('il ne recoit PAS le renseignement', sys.indexOf('RENSEIGNEMENT MILITAIRE -- ce que') < 0);
att('maxTokens est bien le sien', maxTokensProfil('commandant_tom_hawak') === 380,
    String(maxTokensProfil('commandant_tom_hawak')));
print('');
if (ko === 0) print('LES ' + ok + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + (ok + ko) + '.');
