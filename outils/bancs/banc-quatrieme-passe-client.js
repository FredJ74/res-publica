// BANC DE LA QUATRIEME PASSE — COTE ECRAN (11 octobre 2026)
// SOURCES: outils/bancs/decor-window.js data.js plateau-assemblee.js
// Les autres fichiers sont lus comme du TEXTE (readFile), jamais executes : les charger
// reclamerait la moitie du plateau, et ce banc n'a besoin que de leur source.
//
// CE QUE CE BANC TIENT. Le serveur de la quatrieme passe est couvert par banc-quatrieme-passe.sql
// (53 epreuves). Ce qui n'y est pas couvert, c'est ce que l'ECRAN montre et ce qu'il raconte :
//
//   . LAROCHE N'EST PLUS UNE DIXIEME CARTE. L'hemicycle ne contient AUCUNE personne statique ;
//     les neuf deputes arrivent par injection, lui compris, et sa photo voyage avec son siege.
//   . LA DOUBLE QUALITE S'AFFICHE VRAIMENT. Le nom compare au titulaire du registre doit etre le
//     nom NU du serveur, pas le nom affiche avec son suffixe « (PNJ) » -- sinon le suffixe de
//     presidence ne pourrait jamais apparaitre sur une carte PNJ. C'est un defaut reel de la
//     troisieme passe, et cette epreuve est la pour qu'il ne revienne pas.
//   . AUCUN MINUTEUR CLIENT DANS LA REGLE DU SEUIL. L'ecran lit un FAIT serveur ; il ne compte
//     pas l'heure, et une page fermee ne change rien a la regle.
//   . LE BOYCOTT ET LA SUSPENSION NE DISENT PAS LA MEME CHOSE. L'un laisse le debat continuer,
//     l'autre arrete la seance. Les deux phrases doivent exister, et etre differentes.
//   . ON EXPLIQUE AVANT DE REFUSER. Un depute hors de l'hemicycle doit lire pourquoi il ne peut
//     pas voter, sans avoir a essuyer le refus du serveur.
//
// Usage : python3 outils/bancs/lancer-banc.py outils/bancs/banc-quatrieme-passe-client.js
var ok = 0, ko = 0;
function att(n, c, d) { if (c) { print('  ok  ' + n); ok++; } else { print('  *** ' + n + (d !== undefined ? ' -- ' + d : '')); ko++; } }
var RACINE = '/Users/fredericjasseron/ResPublica/';
function lire(f) { return readFile(RACINE + f); }
var ASSEM  = lire('plateau-assemblee.js');
var PRES   = lire('plateau-assemblee-presidence.js');
var SEANCE = lire('plateau-assemblee-seance.js');
var CRONA  = lire('api/cron-assemblee.js');
var CRONM  = lire('api/cron-minuit.js');
// LE CODE SEUL. Un interdit nomme dans un commentaire ne doit ni faire passer ni faire echouer
// une epreuve : on retire donc les lignes de commentaire avant de chercher.
function codeSeul(s) {
  return String(s).split('\n').filter(function (l) { return !/^\s*(\/\/|\*|\/\*)/.test(l); }).join('\n');
}
var ASSEM_CODE = codeSeul(ASSEM);
var PRES_CODE  = codeSeul(PRES);
var SEANCE_CODE = codeSeul(SEANCE);
function dans(s, f) { return String(s).indexOf(f) >= 0; }
// LE PIEGE DE L'APOSTROPHE ECHAPPEE. Dans la source, « l'hemicycle » s'ecrit « l\'hemicycle » :
// entre le « l » et le « h » il y a DEUX caracteres, une barre et une apostrophe. Une recherche
// qui n'en prevoit qu'un echoue sur du code parfaitement correct -- le depot s'y est deja fait
// prendre deux fois. On lit donc le texte APOSTROPHES RECOLLEES, une fois pour toutes.
function texteLisible(s) { return String(s).replace(/\\'/g, "'"); }
var SEANCE_T = texteLisible(SEANCE);
var PRES_T   = texteLisible(PRES);

print('');
print('§1 — NEUF DEPUTES, ET AUCUN DIXIEME PARLEMENTAIRE');
print('============================================================');

att('les neuf sieges sont neuf, trois par ville', (function () {
  if (ASSEMBLEE_SIEGES.length !== 9 || ASSEMBLEE_NB_SIEGES !== 9) return false;
  var parVille = {};
  ASSEMBLEE_SIEGES.forEach(function (s) { parVille[s.city] = (parVille[s.city] || 0) + 1; });
  var v = Object.keys(parVille);
  return v.length === 3 && v.every(function (c) { return parVille[c] === 3; });
})());

att('Laroche est l un des trois de la capitale', ASSEMBLEE_SIEGES.filter(function (s) {
  return s.nom === 'President Laroche' && s.city === 'capitale';
}).length === 1);

att('le PNJ qu il remplace a disparu de la table', !ASSEMBLEE_SIEGES.some(function (s) {
  return s.pnjId === 'dep_delorme' || s.nom === 'Benoît Delorme';
}));

att('aucun identifiant de PNJ n est en double', (function () {
  var vus = {};
  return ASSEMBLEE_SIEGES.every(function (s) {
    if (vus[s.pnjId] || vus[s.nom]) return false;
    vus[s.pnjId] = true; vus[s.nom] = true; return true;
  });
})());

att("l hemicycle ne contient AUCUNE carte statique", (function () {
  var h = BUILDINGS.assemblee.rooms.hemicycle;
  return Array.isArray(h.persons) && h.persons.length === 0;
})());

att('et il n y a nulle part ailleurs de carte de President de l Assemblee', (function () {
  var trouve = 0;
  Object.keys(BUILDINGS).forEach(function (b) {
    var rooms = BUILDINGS[b].rooms || {};
    Object.keys(rooms).forEach(function (r) {
      (rooms[r].persons || []).forEach(function (p) {
        if (/Laroche/i.test(p.name || '') || (p.job === 'president_assemblee')) trouve++;
      });
    });
  });
  return trouve === 0;
})(), 'cartes trouvees');

att('sa photo voyage avec son siege, et lui seul en a une', (function () {
  var avec = ASSEMBLEE_SIEGES.filter(function (s) { return !!s.photoUrl; });
  return avec.length === 1 && avec[0].nom === 'President Laroche'
    && avec[0].photoUrl === 'images/president-assemblee-laroche.webp';
})());

att('et il a la ligne de statistiques des neuf, a l identique', (function () {
  var l = PNJ_STATS_NOMMES['President Laroche'];
  var v = PNJ_STATS_NOMMES['Étienne Vauclerc'];
  if (!l || !v) return false;
  return Object.keys(v).every(function (k) { return l[k] === v[k]; })
      && Object.keys(l).length === Object.keys(v).length;
})());

print('');
print('§1 — LA DOUBLE QUALITE S AFFICHE VRAIMENT');
print('============================================================');

att('le nom compare au registre est le nom NU du serveur, pas le nom affiche',
    dans(ASSEM_CODE, 'const nomServeur = estPnj ? s.nom : o.pjNom')
    && dans(ASSEM_CODE, 'presidentReel === nomServeur'));

att("et le nom affiche garde bien son suffixe « (PNJ) »",
    dans(ASSEM_CODE, "name: s.nom + ' (PNJ)'"));

att('la carte porte les deux qualites, dans cet ordre',
    dans(ASSEM, 'Député de ') && dans(ASSEM, 'suffixePresidence')
    && ASSEM.indexOf('suffixePresidence') < ASSEM.indexOf("role = 'Assistant parlementaire"));

att('le President est lu au SERVEUR, jamais devine',
    dans(ASSEM_CODE, 'RP_PRESIDENCE_ETAT.president'));

print('');
print('CORRECTIF — LE RENOUVELLEMENT EST INTEGRAL, ET LE RANG NE PROTEGE PERSONNE');
print('============================================================');

// LA JUSTIFICATION FAUSSE NE DOIT PAS REVENIR. « Le President reste assis aussi longtemps qu il
// reste un siege PNJ dans sa ville » etait une erreur de game design : le renouvellement de
// l Assemblee est INTEGRAL, et la presidence ne survit pas au mandat qui la porte.
att("le module ne pretend plus que le President reste assis le plus longtemps",
    !/reste donc assis aussi\s*\n?\s*\/\/ longtemps|reste assis aussi longtemps/.test(ASSEM)
    && !/dernier PNJ (de [A-Za-z]+ )?a ceder/i.test(ASSEM));

att("il dit au contraire que le renouvellement est INTEGRAL",
    /RENOUVELLEMENT DE\s*\n?\s*\/\/ L.ASSEMBLEE EST INTEGRAL|RENOUVELLEMENT DE L.ASSEMBLEE EST\s*\n?\s*\/\/ INTEGRAL/.test(ASSEM)
    || /renouvellement de l.Assemblee est\s*\n?\s*\/\/\s*INTEGRAL/i.test(ASSEM)
    || dans(ASSEM, 'EST INTEGRAL'));

att("et que la presidence ne survit jamais au mandat",
    /ne survit jamais au mandat/.test(ASSEM));

att("le rang reste une donnee de la table, pas une regle de code",
    ASSEMBLEE_SIEGES.every(function (s) { return typeof s.rang === 'number'; })
    && !/rang\s*===?\s*3/.test(ASSEM_CODE));

print('');
print('CORRECTIF — LE CRON CONSIGNE LA SORTIE AVANT DE CONVOQUER');
print('============================================================');

att("cron-minuit consigne la fin de la presidence sortante",
    dans(CRONM, 'assemblee_presidence_fin_de_legislature'));

// L'ORDRE EST UNE INFORMATION : on constate la sortie de l'ancien President, PUIS on convoque les
// neuf entrants. L'invariant tient sans cela -- la presidence est derivee -- mais la fiche de
// l'ancien President doit cesser d'afficher son titre avant qu'un autre soit elu.
att("et il le fait AVANT de convoquer l election du lundi",
    CRONM.indexOf("sbRpc('assemblee_presidence_fin_de_legislature'")
      < CRONM.indexOf("sbRpc('assemblee_presidence_convoquer'"));

// LA PORTEE EST LE BLOC, PAS LE FICHIER. Scanner les 6 000 lignes de cron-minuit pour y
// chercher « autoritaire » rendait cette epreuve rouge sur deux commentaires sans rapport, qui
// parlent d'autorite SERVEUR -- un faux positif, et la lecon de l'epreuve « candidat » de la
// troisieme passe. On n'examine donc que le texte de l'annonce ecrite par ce bloc.
att("le cron n enregistre un fait, et ne le qualifie pas", (function () {
  var i = CRONM.indexOf("sbRpc('assemblee_presidence_fin_de_legislature'");
  if (i < 0) return false;
  var bloc = CRONM.slice(i, CRONM.indexOf("sbRpc('assemblee_presidence_convoquer'"));
  // ET LE CODE SEUL, DANS LE BLOC AUSSI. Le commentaire qui INTERDIT la qualification emploie le
  // mot « regrettable » pour dire qu'il n'appartient pas au serveur : le garder dans la portee
  // rendait l'epreuve rouge sur sa propre doctrine. Troisieme fois que ce piege se presente.
  var blocCode = codeSeul(bloc);
  return /fin de l[ée]gislature/.test(blocCode)
      && !/abusi|scandaleu|ill[ée]gitim|autoritair|regrettab/i.test(blocCode);
})());

print('');
print('§4 — LE SEUIL EST UN FAIT SERVEUR, PAS UN MINUTEUR');
print('============================================================');

att("l ecran lit le fait, il ne le calcule pas",
    dans(SEANCE_CODE, 'suspension_presidence_depassee'));

att("aucun minuteur ne mesure la suspension cote client", (function () {
  // Le seul setInterval/setTimeout tolere dans l'ecran de seance est la VEILLE de
  // rafraichissement (SEANCE_VEILLE_MS) : rien ne doit compter la duree d'une suspension.
  var suspects = SEANCE_CODE.split('\n').filter(function (l) {
    return /setInterval|setTimeout/.test(l) && !/SEANCE_VEILLE|seanceVeille/.test(l);
  });
  return suspects.length === 0;
})(), SEANCE_CODE.split('\n').filter(function (l) {
  return /setInterval|setTimeout/.test(l) && !/SEANCE_VEILLE|seanceVeille/.test(l);
}).join(' | '));

att("le seuil n est pas recopie en dur dans l ecran",
    !/60\s*\*\s*60\s*\*\s*1000|3600000/.test(SEANCE_CODE)
    && !/60\s*\*\s*60\s*\*\s*1000|3600000/.test(PRES_CODE));

att("l ecran annonce la consequence AVANT qu elle arrive",
    /Au-del[àa] d'une heure, les scrutins en cours seront renvoy[ée]s/.test(SEANCE_T));

att('et il nomme les renvois pour suspension, distincts des reports volontaires',
    dans(SEANCE_CODE, 'renvois_pour_suspension') && dans(SEANCE_CODE, 'textes_reportes'));

att("la reprise lit ce que le serveur a fait, elle ne le recalcule pas",
    dans(SEANCE_CODE, "r.res.renvois") && !/renvois\s*=\s*\d/.test(SEANCE_CODE));

print('');
print('§4 — LES DEUX CRONS DONNENT AU SERVEUR SES OCCASIONS');
print('============================================================');

att("cron-assemblee applique le seuil",
    dans(CRONA, 'assemblee_suspension_appliquer_seuil'));

// ON COMPARE LES APPELS, PAS LES MENTIONS. L'en-tete du cron nomme assemblee_cloturer_echues
// dans un commentaire bien avant de l'appeler : comparer les premieres occurrences du NOM
// aurait rendu cette epreuve fausse dans les deux sens.
att("et il l applique AVANT de depouiller : c est l ordre qui EST la regle",
    CRONA.indexOf("sbRpc('assemblee_suspension_appliquer_seuil'")
      < CRONA.indexOf("sbRpc('assemblee_cloturer_echues'"));

att("et avant le report pour boycott, qui ne doit pas masquer le renvoi",
    CRONA.indexOf("sbRpc('assemblee_suspension_appliquer_seuil'")
      < CRONA.indexOf("sbRpc('assemblee_reporter_si_suspendue'"));

att("cron-minuit l applique aussi, pour les jours ou cron-assemblee ne passe pas",
    dans(CRONM, 'assemblee_suspension_appliquer_seuil'));

print('');
print('§3 — LE BOYCOTT ET LA SUSPENSION NE DISENT PAS LA MEME CHOSE');
print('============================================================');

att("le boycott annonce que le debat continue",
    /le d[ée]bat, lui, continue/.test(SEANCE));

att("la suspension presidentielle annonce qu on n y prend pas la parole",
    /on n'y prend pas la parole/.test(SEANCE_T));

att("et les deux annonces sont bien deux phrases distinctes",
    SEANCE.indexOf('SUSPENDUE PAR BOYCOTT') >= 0
    && SEANCE.indexOf('SUSPENDUE PAR LA PRÉSIDENCE') >= 0
    && SEANCE.indexOf('SUSPENDUE PAR BOYCOTT') !== SEANCE.indexOf('SUSPENDUE PAR LA PRÉSIDENCE'));

att("seule la suspension presidentielle ferme la parole dans le code de l ecran",
    dans(SEANCE_CODE, 'const jeParle = !e.suspendue_par_la_presidence')
    && !/jeParle[^;]*e\.suspendue[^_]/.test(SEANCE_CODE));

print('');
print('§5 — ON EXPLIQUE AVANT DE REFUSER');
print('============================================================');

att("l ecran de presidence lit la presence au serveur",
    dans(PRES_CODE, 'e.je_suis_dans_hemicycle'));

att("le bouton Voter n est pas propose hors de l hemicycle",
    dans(PRES_CODE, 'const peutVoter = e.je_suis_depute && e.je_suis_dans_hemicycle'));

att("et le joueur lit pourquoi, au lieu d essuyer un refus",
    /pas dans l'h[ée]micycle/.test(PRES_T));

att("le refus serveur a sa phrase, pour le cas ou il arrive quand meme",
    dans(PRES, 'hors_hemicycle'));

att("l ecran n autorise rien : la verite reste la porte",
    /n'autorise rien/.test(PRES_T));

print('');
print('§6 — LE CUMUL N INVENTE AUCUNE INCOMPATIBILITE');
print('============================================================');

att("le mandat de depute n est jamais ecrit par l ecran de presidence",
    !/state\.posteDepute\s*=/.test(PRES_CODE));

att("un autre poste nomme n est jamais ecrase",
    /if \(state\.poste\)\s*\{/.test(PRES_CODE)
    && PRES_CODE.indexOf('state.poste = ') > PRES_CODE.indexOf('if (state.poste)'));

att("et le joueur l apprend, au lieu de voir son titre disparaitre en silence",
    dans(PRES_CODE, 'RP_PRESIDENCE_TITRE_DIT'));

att("l emplacement unique de state.poste est dit une seule fois par session",
    (PRES_CODE.match(/RP_PRESIDENCE_TITRE_DIT/g) || []).length >= 2);

print('');
print('============================================================');
if (ko > 0) { print(ko + ' EPREUVES ROUGES SUR ' + (ok + ko) + '.'); }
else { print('LES ' + ok + ' EPREUVES SONT VERTES.'); }
