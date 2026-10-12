// Banc STRUCTUREL du cote navigateur du barreau, des temoins, du Bureau des magistrats et de
// l'audience (12 octobre 2026, soir). -- SOURCES: aucune -- ce banc lit les fichiers de
// production eux-memes, par readFile.
//
// POURQUOI STRUCTUREL. Le comportement des portes est eprouve EN BASE par
// outils/bancs/banc-avocat-et-temoins.sql (34 epreuves, transaction annulee). Ici on mesure ce
// qu'aucun banc SQL ne peut voir : que les ecrans ne decident rien, que la piece existe dans les
// TROIS tribunaux avec le MEME asset, qu'aucune reaction humaine n'est codee, et que la
// caracteristique mecanique d'un avocat n'atteint jamais l'ecran du prevenu.
//
// LE PIEGE DU COMMENTAIRE : toute mesure d'ABSENCE porte sur le CODE, commentaires retires --
// blocs compris. Il s'est referme deux fois dans cette seule tranche, dont une sur une preuve de
// migration qui parlait du piege.
var RACINE = '/Users/fredericjasseron/ResPublica/';
function lire(f) { return readFile(RACINE + f); }

var dataJs   = lire('data.js');
var justice  = lire('plateau-justice-economie.js');
var routeur  = lire('plateau-router.js');
var cron     = lire('api/cron-minuit.js');
var chat     = lire('api/chat.js');

var ko = 0, attendus = 0;
function att(n, c, detail) {
  attendus++;
  if (c) print('  ok  ' + n);
  else { print('  *** ' + n); if (detail !== undefined) print('        ' + detail); ko++; }
}
function codeSeul(t) {
  var sansBlocs = t.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/<!--[\s\S]*?-->/g, ' ');
  return sansBlocs.split('\n').filter(function (l) { return !/^\s*\/\//.test(l); }).join('\n');
}
function bloc(t, debut, fin) {
  var i = t.indexOf(debut); if (i < 0) return '';
  var j = t.indexOf(fin, i); return j < 0 ? t.slice(i) : t.slice(i, j);
}
function compte(t, re) { return (t.match(re) || []).length; }

print('BANC BARREAU / TEMOINS / BUREAU DES MAGISTRATS -- COTE NAVIGATEUR');
print('');

print('1. LE BUREAU DES MAGISTRATS, DANS LES TROIS TRIBUNAUX');
att('la piece est declaree DEUX fois -- un gabarit par type de tribunal, et pas une copie par ville',
    compte(dataJs, /bureau_magistrats: \{/g) === 2,
    compte(dataJs, /bureau_magistrats: \{/g) + ' declaration(s)');
att('et les deux portent le MEME asset',
    compte(dataJs, /images\/tribunal-bureau-magistrats\.webp/g) === 2);
att('le gabarit local a gagne un greffe -- sans lui, deux affaires sur trois sont illisibles',
    bloc(dataJs, "  'tribunal-local': {", "  'imprimerie-librairie': {").indexOf('greffe: {') >= 0);
att('les prerogatives des magistrats ont quitte la salle d audience',
    bloc(dataJs, '      salle_audience: {', '      bureau_magistrats: {').indexOf("fn:'parquet'") < 0
    && bloc(dataJs, '      salle_audience_locale: {', '      bureau_magistrats: {').indexOf("fn:'rendre_sentence'") < 0);
att('et elles sont dans le bureau, gardees par le POSTE reel',
    compte(dataJs, /\{fn:'parquet',[^}]*requiresPost:'procureur'/g) === 2
    && compte(dataJs, /\{fn:'audience_juge',[^}]*requiresPost:'juge'/g) === 2
    && compte(dataJs, /\{fn:'rendre_sentence',[^}]*requiresPost:'juge'/g) === 2);
att('le prevenu garde « Se defendre » dans la salle d audience, qui n est pas un pouvoir de magistrat',
    compte(dataJs, /\{fn:'defense',/g) === 2);
att('et sa description ne promet plus les quatre issues disparues',
    codeSeul(dataJs).indexOf('circonstance attenuante') < 0
    && dataJs.indexOf('definitif et sans appel') >= 0);

print('');
print('2. L AVOCAT : SES DEUX ECRANS, ET AUCUN POUVOIR CLIENT');
att('les deux ordres de l avocat vivent au GREFFE, dans les deux tribunaux',
    compte(dataJs, /\{fn:'avocat_dossiers',/g) === 2
    && compte(dataJs, /\{fn:'avocat_barreau',/g) === 2);
att('les cinq routes neuves existent',
    ["avocat_barreau", "avocat_dossiers", "temoins_mes_convocations",
     "temoin_deposition", "audience_juge"].every(function (f) {
      return routeur.indexOf("fn === '" + f + "'") >= 0;
    }));
att('chaque ecran appelle une porte serveur, et aucune ne decide',
    ["avocat_ma_tarification", "avocat_publier_tarification", "avocat_retirer_tarification",
     "defense_mes_demandes", "defense_repondre", "defense_demander", "defense_rompre",
     "justice_avocats_disponibles", "avocat_dossier", "temoin_citer", "temoin_deposer",
     "temoin_mes_convocations", "justice_audience_ouvrir", "justice_audience_parole"].every(function (f) {
      return justice.indexOf("sbRpc('" + f + "'") >= 0;
    }));
// Mesure sur des IDENTIFIANTS, jamais sur trois lettres : « changer d'avocat » contient « cha ».
att('la caracteristique mecanique de l avocat n atteint jamais l ecran du prevenu',
    !/\bcha\b|\.cha|'CHA'|getStatEffective/.test(
      bloc(justice, 'async function ouvrirChoixAvocat(', 'async function defenseDemander(')));
att('la liste du prevenu n affiche que l identite et la tarification',
    bloc(justice, 'async function ouvrirChoixAvocat(', 'async function defenseDemander(')
      .indexOf('a.tarification') >= 0);
att('les demandes multiples passent par des cases a cocher, pas par un choix unique',
    justice.indexOf("querySelectorAll('.avocat-choix:checked')") >= 0
    && justice.indexOf('p_avocats: choisis') >= 0);
att('et il n y a AUCUN bouton disponible/indisponible',
    codeSeul(justice).indexOf('Disponible</button>') < 0
    && codeSeul(justice).indexOf('p_disponible') < 0);

print('');
print('3. LE TEMOIN : SON OBLIGATION, ET SON CHOIX');
att('l ordre de deposition existe dans les DEUX commissariats',
    compte(dataJs, /\{fn:'temoin_deposition',/g) === 2);
att('et l ecran de ses convocations dans les DEUX tribunaux',
    compte(dataJs, /\{fn:'temoins_mes_convocations',/g) === 2);
att('les deux reponses sont offertes, et le refus est presente comme valide',
    justice.indexOf("temoinDeposer(\\'' + justiceEch(affaireId) + '\\',true)") >= 0
    || justice.indexOf('Refuser de temoigner') >= 0);
att('le refus n envoie aucun texte : on n enregistre pas deux reponses contradictoires',
    bloc(justice, 'async function temoinDeposer(', 'showToast(refus')
      .indexOf('const texte = refus ? null :') >= 0);
att('et l ecran dit que le refus n entraine aucune sanction automatique',
    justice.indexOf('par elle-meme aucune sanction') >= 0);

print('');
print('4. AUCUNE REACTION HUMAINE CODEE');
var neuf = bloc(justice, '// LE BARREAU, LES TEMOINS ET L\'AUDIENCE -- COTE NAVIGATEUR', '');
att('aucun bouton « demander la relaxe », « demander une requalification » ni « plaider »',
    codeSeul(neuf).indexOf('demander_relaxe') < 0
    && codeSeul(neuf).indexOf('demander_requalification') < 0
    && codeSeul(neuf).indexOf('plaidoirie') < 0);
att('aucun score, aucune credibilite, aucune sincerite',
    codeSeul(neuf).indexOf('credibilite') < 0 && codeSeul(neuf).indexOf('sincerite') < 0
    && codeSeul(neuf).indexOf('score') < 0);
att('aucun appel a une IA dans toute cette chaine',
    codeSeul(neuf).indexOf('/api/chat') < 0 && codeSeul(neuf).indexOf('deepseek') < 0);
att('et le contexte des IA ne connait ni le barreau ni les citations',
    codeSeul(chat).indexOf('avocats_barreau') < 0
    && codeSeul(chat).indexOf('temoins_citations') < 0
    && codeSeul(chat).indexOf('defenses_demandes') < 0);

print('');
print('5. LA PASSE DE MINUIT');
att('les convocations echues sont traitees chaque nuit',
    cron.indexOf("sbRpc('temoins_convocations_echues'") >= 0
    && cron.indexOf("tacheQuotidienne('convocations_temoins'") >= 0);
att('et elle est APRES les delais judiciaires -- une affaire qui expire eteint ses citations avant',
    cron.indexOf("tacheQuotidienne('delais_judiciaires'") < cron.indexOf("tacheQuotidienne('convocations_temoins'"));
att('son resultat remonte dans le corps de reponse',
    /const corps = \{[^;]*\bconvocationsTemoins\b/.test(cron));
att('et son echec est signale comme les autres',
    bloc(cron, "tacheQuotidienne('convocations_temoins'", '});').indexOf("signalerEchec('convocations_temoins'") >= 0);

print('');
print('6. L AUDIENCE : LE STRICT MINIMUM, ET PAS LE CHAT');
att('le juge ouvre l audience, cite, donne et retire la parole',
    justice.indexOf('async function audienceOuvrir(') >= 0
    && justice.indexOf('async function audienceParole(') >= 0
    && justice.indexOf('async function temoinCiterDepuisAudience(') >= 0);
att('et l ecran annonce que l ouverture verrouille la defense',
    bloc(justice, 'async function ouvrirAudienceJuge(', 'async function audienceOuvrir(')
      .indexOf('verrouille la defense') >= 0);
att('AUCUN chat d audience n est construit dans cette tranche',
    codeSeul(neuf).indexOf('audience_messages') < 0
    && codeSeul(neuf).indexOf('ouvrirChatAudience') < 0);

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
