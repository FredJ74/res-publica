// Banc STRUCTUREL du cote navigateur de la tranche TRIBUNAL (12 octobre 2026, nuit).
// SOURCES: aucune -- ce banc lit les fichiers de production eux-memes, par readFile.
//
// POURQUOI STRUCTUREL. Ce que cette tranche ajoute cote navigateur est un ECRAN et deux
// FILTRES : il n'y a aucun calcul a appeler. Le comportement des portes est eprouve en base par
// outils/bancs/banc-tribunal-pv-et-delai.sql (24 epreuves, transaction annulee). Ici on mesure
// que l'ecran existe, qu'il ne decide rien, et surtout qu'il ne PROPOSE RIEN QUE LE SERVEUR
// REFUSERA -- un ordre payant pour un refus certain est un defaut a part entiere.
var justice   = readFile('/Users/fredericjasseron/ResPublica/plateau-justice-economie.js');
var perso     = readFile('/Users/fredericjasseron/ResPublica/plateau-personnage.js');
var multi     = readFile('/Users/fredericjasseron/ResPublica/plateau-multijoueur.js');
var cron      = readFile('/Users/fredericjasseron/ResPublica/api/cron-minuit.js');
var pnj       = readFile('/Users/fredericjasseron/ResPublica/plateau-pnj.js');
var donnees   = readFile('/Users/fredericjasseron/ResPublica/data.js');

var ko = 0, attendus = 0;
function att(n, c, detail) {
  attendus++;
  if (c) print('  ok  ' + n);
  else { print('  *** ' + n); if (detail !== undefined) print('        ' + detail); ko++; }
}
// LE PIEGE DU COMMENTAIRE QUI NOMME CE QU'IL INTERDIT. La mesure porte sur le CODE.
function codeSeul(t) {
  return t.split('\n').filter(function (l) { return !/^\s*\/\//.test(l); }).join('\n');
}
function bloc(t, debut, fin) {
  var i = t.indexOf(debut); if (i < 0) return '';
  var j = t.indexOf(fin, i); return j < 0 ? t.slice(i) : t.slice(i, j);
}

print('BANC TRIBUNAL -- COTE NAVIGATEUR');
print('');

// ---------------------------------------------------------------- LE PV D'AUDITION
att('l ecran du PV existe',
    justice.indexOf('function ouvrirPvAudition(') >= 0);
att('et il appelle la porte, sans rien decider',
    justice.indexOf("sbRpc('pv_audition_realiser'") >= 0);
att('le refus de repondre est un BOUTON a part entiere, pas une case a cocher oubliee',
    justice.indexOf('function soumettrePvAudition(') >= 0
    && codeSeul(justice).indexOf('Refuser de repondre') >= 0);
att('le refus n envoie aucun texte : on n enregistre pas deux reponses contradictoires',
    bloc(justice, 'async function soumettrePvAudition(', 'showToast(\'Audition consignee\'')
      .indexOf('const texte = refus ? null :') >= 0);
att('l ecran n invente pas le delai : il affiche celui que le serveur a rendu',
    bloc(justice, 'async function soumettrePvAudition(', 'updateUI();')
      .indexOf('v.delai_jugement_jour') >= 0
    && bloc(justice, 'async function soumettrePvAudition(', 'updateUI();').indexOf('+ 15') < 0);
att('les refus de la porte sont tous nommes',
    ['acteur_non_authentifie','reponse_absente','affaire_absente','pas_mon_affaire',
     'affaire_close','audition_deja_realisee','statut_a_change']
      .every(function (r) { return justice.indexOf(r + ':') >= 0 || justice.indexOf(r) >= 0; }));
att('la situation judiciaire est offerte sur la fiche du personnage -- la seule porte qu un detenu puisse encore ouvrir',
    perso.indexOf('justiceSituationHtml()') >= 0
    && justice.indexOf('function justiceSituationHtml(') >= 0);
att('le bloc ne s affiche QUE s il y a quelque chose a dire au joueur',
    bloc(justice, 'function justiceSituationHtml(', 'function mesAffairesAppelables(')
      .indexOf("appelables.length === 0 && indemnites === '') return ''") >= 0);
att('et il n affiche le bouton que si l audition n a pas eu lieu',
    bloc(justice, 'function justiceSituationHtml(', 'function ouvrirPvAudition(')
      .indexOf('const aPv = !!a.pv_le;') >= 0);

// ---------------------------------------------------------------- LA PROCEDURE SIMPLIFIEE
att('« Se defendre » ne propose plus une affaire sans infraction retenue',
    bloc(justice, 'async function doDefense(', 'const cur =').indexOf('if (!inf') >= 0);
att('elle borne au seuil de 2 jours de reference',
    bloc(justice, 'async function doDefense(', 'const cur =').indexOf('ref.jours > 2') >= 0);
att('elle lit la reference par le canon de plateau-core.js, elle ne la recopie pas',
    bloc(justice, 'async function doDefense(', 'const cur =').indexOf('getPeineParActe(inf') >= 0);
att('elle ecarte une affaire deja plaidee : la procedure est definitive',
    bloc(justice, 'async function doDefense(', 'const cur =').indexOf('!p.defense_le') >= 0);
att('et les trois refus neufs de la porte sont dits au joueur',
    justice.indexOf('procedure_simplifiee_reservee_aux_peines_courtes') >= 0
    && justice.indexOf('infraction_non_determinee') >= 0
    && justice.indexOf('defense_deja_plaidee') >= 0);
att('l ecran ne compose AUCUNE peine : la resolution automatique est arretee, pas a moitie ecrite',
    bloc(justice, 'async function doDefense(', 'updateUI();').indexOf('appliquerSentence') < 0
    && bloc(justice, 'async function doDefense(', 'updateUI();').indexOf('detention') < 0);

// ---------------------------------------------------------------- LES STATUTS DANS LA PIECE
att('les statuts publics sont lus par la porte sans parametre',
    multi.indexOf("sbRpc('justice_statuts_publics', {})") >= 0);
att('ils sont relus EN MEME TEMPS que la presence',
    bloc(multi, 'async function chargerVraisJoueursPresents(', 'const autres =')
      .indexOf('await rafraichirStatutsJudiciaires();') >= 0);
att('la carte d un autre joueur porte ses mentions',
    bloc(multi, 'const cartePlayer = (p) =>', 'const pnjParPorteur')
      .indexOf('marqueursJudiciairesHtml(p.name)') >= 0);
att('la carte du joueur courant aussi, et par la MEME source',
    bloc(multi, 'const selfCard = char ?', 'const carteDePersonne')
      .indexOf('marqueursJudiciairesHtml(char.name)') >= 0);
att('les deux mentions sont cumulables : aucune n exclut l autre',
    bloc(multi, 'function marqueursJudiciairesHtml(', 'function renderPersonsList(')
      .indexOf('else') < 0);
att('aucune reaction automatique n est codee : ni popularite, ni influence, ni rumeur',
    bloc(multi, 'function marqueursJudiciairesHtml(', 'function renderPersonsList(')
      .indexOf('pop') < 0
    && bloc(multi, 'function marqueursJudiciairesHtml(', 'function renderPersonsList(')
      .indexOf('inf +') < 0);

// ---------------------------------------------------------------- LA PASSE DE MINUIT
att('la passe de minuit fait expirer les delais',
    cron.indexOf("sbRpc('justice_delais_echus'") >= 0);
att('elle le fait en identite SERVEUR',
    bloc(cron, "tacheQuotidienne('delais_judiciaires'", 'return r ||').indexOf('HEADERS_SERVICE') >= 0);
att('son verdict est consomme, jamais suppose',
    bloc(cron, "tacheQuotidienne('delais_judiciaires'", 'return r ||')
      .indexOf("signalerEchec('delais_judiciaires'") >= 0);
// Mesure la PRESENCE dans le corps, pas l'adjacence a son voisin : la passe des convocations de
// temoins s'est inseree entre les deux le 12 octobre, et l'adjacence n'a jamais rien prouve.
att('et il remonte dans le corps de la reponse',
    /const corps = \{[^;]*\bdelaisJudiciaires\b/.test(cron));

// ---------------------------------------------------------------- §A : AUCUN CRIME
att('« Se defendre » exclut les crimes, et pas seulement les peines longues',
    bloc(justice, 'async function doDefense(', 'const cur =').indexOf("cat !== 'crime'") >= 0);
att('la categorie vient du canon de plateau-core.js, pas d une liste locale',
    bloc(justice, 'async function doDefense(', 'const cur =').indexOf('ACTES_ILLEGAUX[inf]') >= 0);
att('une categorie absente ferme la porte : on n affirme pas qu un acte sans categorie est benin',
    bloc(justice, 'async function doDefense(', 'const cur =').indexOf('!!cat &&') >= 0);
att('et le refus serveur correspondant est dit au joueur',
    justice.indexOf('procedure_simplifiee_exclut_les_crimes') >= 0);

// ---------------------------------------------------------------- §H : LE SIGNALEMENT
att('le bouton « Signaler a la police » existe',
    pnj.indexOf('signalerALaPolice(') >= 0);
att('il n apparait que sur un joueur que le SERVEUR a dit recherche',
    bloc(pnj, 'if (isPJ) {', '// « AJOUTER AU REPERTOIRE »')
      .indexOf("RP_STATUTS_JUDICIAIRES[pnj.name].recherche === true") >= 0);
att('et seulement en Republia : l arrestation citoyenne appartient a un autre empire',
    bloc(pnj, 'if (isPJ) {', '// « AJOUTER AU REPERTOIRE »')
      .indexOf("state.country === 'republic'") >= 0);
att('le verrou anti-double-clic est pose AVANT l appel, pas apres',
    bloc(justice, 'async function signalerALaPolice(', 'function compteARebonsSignalement(')
      .indexOf('RP_SIGNALEMENT_EN_COURS = nom;') <
    bloc(justice, 'async function signalerALaPolice(', 'function compteARebonsSignalement(')
      .indexOf("sbRpc('police_signaler'"));
att('le compte a rebours part de la valeur que le SERVEUR annonce',
    justice.indexOf('compteARebonsSignalement(v.id, v.delai_secondes || 10)') >= 0);
att('il affiche la phrase exacte, avec les secondes restantes',
    codeSeul(justice).indexOf('Vous avez alerté la police. Elle arrive dans ') >= 0);
att('a zero, c est le SERVEUR qui decide -- l ecran ne conclut rien lui-meme',
    bloc(justice, 'function compteARebonsSignalement(', 'const APPEL_REFUS')
      .indexOf("sbRpc('police_signalement_resoudre'") >= 0);
att('et la page se rafraichit',
    bloc(justice, 'function compteARebonsSignalement(', 'const APPEL_REFUS')
      .indexOf('location.reload()') >= 0);
att('la cible n est prevenue de rien : aucun toast, aucun courrier a son nom',
    bloc(justice, 'async function signalerALaPolice(', 'const APPEL_REFUS')
      .indexOf('sbSendMail') < 0);

// ---------------------------------------------------------------- §E : L'APPEL
att('le condamne peut interjeter appel depuis sa fiche',
    justice.indexOf('function interjeterAppel(') >= 0
    && justice.indexOf("sbRpc('justice_appel_ouvrir'") >= 0);
att('l ecran dit que l appel N EST PAS suspensif -- c est la regle la plus contre-intuitive',
    codeSeul(justice).indexOf("l\\'appel n\\'est pas ") >= 0
    || codeSeul(justice).indexOf('pas suspensif') >= 0);
att('la fenetre offerte est celle que le serveur a inscrite, jamais recalculee',
    bloc(justice, 'function mesAffairesAppelables(', 'function ouvrirPvAudition(')
      .indexOf('p.appel_jusqu_au_jour') >= 0
    && bloc(justice, 'function mesAffairesAppelables(', 'function ouvrirPvAudition(')
      .indexOf('+ 2') < 0);
att('un dossier de procedure simplifiee n est jamais offert a l appel',
    bloc(justice, 'function mesAffairesAppelables(', 'function ouvrirPvAudition(')
      .indexOf('p.procedure_simplifiee !== true') >= 0);
att('le juge voit les dossiers en appel et peut les juger',
    bloc(justice, 'async function ouvrirDossiersJuge(', 'async function ouvrirQualificationSentence(')
      .indexOf("if (st === 'appel')") >= 0);
att('les bornes de l appel sont DEMANDEES au serveur, pas recalculees',
    bloc(justice, 'async function ouvrirModulationAppel(', 'const APPEL_JUGE_REFUS')
      .indexOf("sbRpc('justice_peine_proposer'") >= 0
    && bloc(justice, 'async function ouvrirModulationAppel(', 'const APPEL_JUGE_REFUS')
      .indexOf('* 0.5') < 0);
att('l ecran annonce l indemnite telle que le serveur l a calculee',
    bloc(justice, 'async function appliquerJugementAppel(', 'function prononcerJugementAppel(')
      .indexOf('v.jours_indus') >= 0);
att('et il ne compte aucun jour purge lui-meme',
    bloc(justice, 'async function appliquerJugementAppel(', 'function prononcerJugementAppel(')
      .indexOf('jour_debut') < 0);

// ---------------------------------------------------------------- §F : LES INDEMNITES
att('le joueur voit ce que l Etat lui doit',
    justice.indexOf('function justiceIndemnitesHtml(') >= 0
    && justice.indexOf("sbRpc('justice_mes_indemnites'") >= 0);
att('du, paye et reste viennent du serveur',
    bloc(justice, 'function justiceIndemnitesHtml(', 'async function doDefense(')
      .indexOf('i.reste') >= 0);
att('et l ecran dit qu aucune demarche n est possible -- le prelevement est automatique',
    codeSeul(justice).indexOf('versement est automatique') >= 0);
att('le repeint de la fiche ne se rappelle pas lui-meme',
    perso.indexOf('window._indemnitesRelues') >= 0
    && perso.indexOf('window._indemnitesRelues = false;') >= 0);

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
