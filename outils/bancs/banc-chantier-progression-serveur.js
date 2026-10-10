// PREUVE ANCIEN-CONTRE-NOUVEAU DE L'ACCELERATION DE CHANTIER
// SOURCES: plateau-chantiers.js
//
// POURQUOI CE BANC EXISTE. La porte serveur `terrain_chantier_acte` calcule desormais elle-meme
// la nouvelle progression d'un chantier accelere, parce qu'un nombre que le client dicte et qui
// BORNE un avancement est une faille. Mais recalculer une regle de jeu ailleurs, c'est en creer
// une SECONDE VERSION -- et deux versions divergent toujours un jour.
//
// Ce banc interdit la divergence : il execute le code de PRODUCTION (`progressionMaxFinancee`,
// `progressionAutorisee`, `peutProgresser`, `appliquerVerrouPlan`, tels qu'ils sont dans
// plateau-chantiers.js) sur une grille de 180 chantiers, et imprime le resultat attendu sous une
// forme que le banc SQL `banc-chantier-progression-serveur.sql` compare, cas par cas, a ce que la
// porte produit. Si une seule case differe, le banc SQL rougit en nommant le cas.
//
// LE PIEGE QUE CE BANC A DEJA SERVI A EVITER : l'arithmetique. Le client compare des flottants
// binaires (`d * 2 / 3`), Postgres comparerait des `numeric` exacts. Les seuils de tiers tombent
// precisement sur des tiers de duree -- c'est exactement la ou les deux arithmetiques basculent
// dans des sens opposes. La porte est donc ecrite en `double precision`, et c'est cette grille
// qui le prouve.
//
// Usage :
//   python3 outils/bancs/lancer-banc.py outils/bancs/banc-chantier-progression-serveur.js
// Il imprime le tableau de cas (a coller dans le banc SQL) puis son propre verdict de coherence.
// LE FICHIER DE PRODUCTION EST CONCATENE AVANT CE BANC par le lanceur (ligne SOURCES ci-dessus) :
// les formules eprouvees ici sont donc LES MEMES OBJETS que celles du jeu, pas une copie. Un
// `eval()` dans une fonction ne marcherait pas -- les `const` d'un eval restent dans sa portee.
var C = {
  progressionMaxFinancee: progressionMaxFinancee,
  progressionAutorisee: progressionAutorisee,
  peutProgresser: peutProgresser,
  appliquerVerrouPlan: appliquerVerrouPlan,
  seuils: SEUILS_FINANCEMENT_CONSTRUCTION
};

var ko = 0, attendus = 0;
function att(n, c, detail) {
  attendus++;
  if (c) print('  ok  ' + n);
  else { print('  *** ' + n); if (detail !== undefined) print('        ' + detail); ko++; }
}

print('');
print('PREUVE ANCIEN-CONTRE-NOUVEAU : ACCELERATION DE CHANTIER');
print('============================================================================');
att('les trois seuils du fichier de production sont bien 35 / 70 / 100',
    C.seuils.demarrage === 35 && C.seuils.premierTiers === 70 && C.seuils.deuxTiers === 100,
    JSON.stringify(C.seuils));

// LA GRILLE. Les durees incluent 6 (tiers exacts) et 7 (tiers non representables en binaire) ;
// les versements traversent les trois paliers de financement par le haut ET par le bas ; les
// progressions encadrent chaque tiers a la case pres.
var DUREES = [0, 1, 6, 7, 10, 30];
var COUTS = [0, 30000];
var FRACTIONS = [0, 0.34, 0.35, 0.36, 0.70, 0.71, 1];
var cas = [];
for (var a = 0; a < DUREES.length; a++) {
  var d = DUREES[a];
  var progs = (d === 0) ? [0] : [0, Math.floor(d / 3), Math.ceil(d / 3), Math.floor(2 * d / 3),
                                 Math.ceil(2 * d / 3), d];
  for (var b = 0; b < COUTS.length; b++) {
    var total = COUTS[b];
    for (var c = 0; c < FRACTIONS.length; c++) {
      var verse = Math.round(total * FRACTIONS[c]);
      for (var e = 0; e < progs.length; e++) {
        var p = progs[e];
        var peut = C.peutProgresser(verse, p, d, total);
        var gain = C.progressionAutorisee(p, Math.max(0, (d - p) / 2), verse, d, total);
        var neuf = Math.min(d, p + gain);
        var verrou = C.appliquerVerrouPlan({ dureeJours: d, progressionJours: neuf }, 9);
        cas.push([d, total, verse, p, peut ? 1 : 0,
                  C.progressionMaxFinancee(verse, d, total), gain, neuf,
                  verrou.planVerrouille === true ? 1 : 0]);
      }
    }
  }
}

// DEDOUBLONNAGE : plusieurs fractions donnent le meme versement quand le cout est nul.
var vus = {}, uniques = [];
for (var i = 0; i < cas.length; i++) {
  var cle = cas[i].slice(0, 4).join('|');
  if (vus[cle]) continue;
  vus[cle] = true; uniques.push(cas[i]);
}
att('la grille couvre au moins 60 chantiers distincts', uniques.length >= 60,
    uniques.length + ' cas');
att('elle contient une duree a tiers exacts (6) et une a tiers non binaires (7)',
    uniques.some(function (x) { return x[0] === 6; }) && uniques.some(function (x) { return x[0] === 7; }));
att('elle contient au moins un chantier plafonne (gain nul alors que le reste est non nul)',
    uniques.some(function (x) { return x[6] === 0 && x[0] - x[3] > 0; }));
att('et au moins un chantier qui franchit les deux tiers (verrou pose)',
    uniques.some(function (x) { return x[8] === 1; }));

print('');
print('--- GRILLE (duree, coutTotal, totalVerse, progression, peutProgresser, plafond, gain, nouvelle, verrou) ---');
print('ATTENDU_JSON=' + JSON.stringify(uniques));
print('--- fin de la grille ---');

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
