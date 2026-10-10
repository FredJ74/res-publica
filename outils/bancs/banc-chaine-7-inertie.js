// Banc de L'INERTIE DE LA CHAINE 7 -- budgets de clubs (chantier 5, 10 octobre 2026).
// SOURCES: aucune -- ce banc lit plateau-organisations-quetes.js lui-meme, par readFile.
//
// POURQUOI UN BANC POUR UNE CHAINE QU'ON NE FERME PAS. La chaine 7 est GELEE : elle attend un
// arbitrage de game design -- « une commune subventionne-t-elle les clubs sportifs de son
// territoire, et si oui par quelle ligne de repartitions_budgetaires ? ». Tant qu'il n'est pas
// rendu, on n'invente pas la regle, et on ne construit pas une porte pour un acte que le jeu ne
// produit pas.
//
// Mais « gele » ne veut rien dire si personne ne verifie que c'est encore vrai. Ce banc tient
// l'inertie : le jour ou quelqu'un remplacera le `0` ecrit en dur par un vrai montant sans
// fermer la chaine, il ROUGIRA. C'est la difference entre une dette consignee et une dette
// oubliee.
//
// L'INERTIE A CINQ NIVEAUX, dont trois sont mesurables ici et deux en base :
//   1. `const montantTotal = 0;` est ecrit en dur             <- epreuves 1 et 2
//   2. le credit est garde par `if (montantTotal > 0)`        <- epreuve 3
//   3. la fonction n'a qu'un seul appelant, un ecran de consultation <- epreuves 4 et 5
//   4. `repartitions_budgetaires` ne porte aucune ligne associative   (en base, voir l'audit)
//   5. les 12 clubs ont `caisse: 0` et aucun historique ne porte
//      « Subvention municipale » -- alors que `derniereSubventionJour` est pose :
//      le chemin a ete PARCOURU, et il n'a rien verse            (en base, voir l'audit)
//
// Les niveaux 4 et 5 sont dans `baseline/arbitrages/AUDIT-CHANTIER-5-ECRITURES-PLATEAU.md` §7.3 :
// un banc hors ligne ne peut pas les porter, et les recopier ici en dur serait les figer.
var RACINE = '/Users/fredericjasseron/ResPublica/';
var F = 'plateau-organisations-quetes.js';
var SRC = readFile((typeof CHEMIN_SOURCE === 'string') ? CHEMIN_SOURCE : RACINE + F);
function sansCommentaires(texte) {
  return texte.split('\n').filter(function (l) { return l.trim().indexOf('//') !== 0; }).join('\n');
}
var CODE = sansCommentaires(SRC);

var ko = 0, attendus = 0;
function att(n, c, detail) {
  attendus++;
  if (c) print('  ok  ' + n);
  else { print('  *** ' + n); if (detail !== undefined) print('        ' + detail); ko++; }
}
function compte(texte, motif) { return (texte.match(motif) || []).length; }
function bloc(nom) {
  var i = SRC.indexOf('async function ' + nom + '(');
  if (i < 0) i = SRC.indexOf('function ' + nom + '(');
  if (i < 0) throw new Error('introuvable : ' + nom);
  var j = SRC.indexOf('{', i), p = 0, k = j;
  while (k < SRC.length) { if (SRC[k] === '{') p++; else if (SRC[k] === '}') { p--; if (!p) break; } k++; }
  return SRC.slice(i, k + 1);
}

print('');
print('BANC DE L INERTIE DE LA CHAINE 7 -- BUDGETS DE CLUBS (GELEE)');
print('============================================================================');

var b = sansCommentaires(bloc('verifierSubventionMairie'));
att('le montant de la subvention est le litteral 0, ecrit en dur',
    b.indexOf('const montantTotal = 0;') >= 0);
att('il n est calcule a partir de RIEN -- ni allocation, ni repartition, ni blob',
    b.indexOf('allocation') < 0 && b.indexOf('repartition') < 0,
    'si cette epreuve tombe, la chaine n est plus inerte : il faut la FERMER');
att('le credit est garde par une condition que 0 ne franchit pas',
    b.indexOf('if (montantTotal > 0)') >= 0
    && b.indexOf('if (montantTotal > 0)') < b.indexOf('crediterBudgetClub('));
att('crediterBudgetClub n est appele qu une fois dans ce chemin',
    compte(b, /crediterBudgetClub\(/g) === 1, compte(b, /crediterBudgetClub\(/g) + ' appel(s)');

// LE PERIMETRE DU CHEMIN : un seul appelant, et c'est un ecran de consultation. Si un second
// appelant apparait -- le cron, par exemple -- le gel ne tient plus par la seule inertie du
// montant, et cette epreuve le dira.
att('verifierSubventionMairie n a qu UN SEUL appelant dans tout le fichier',
    compte(CODE, /verifierSubventionMairie\(/g) === 2,
    compte(CODE, /verifierSubventionMairie\(/g) + ' occurrence(s) -- definition comprise');
att('et cet appelant est doConsulterBudgetClub, un ecran de consultation',
    sansCommentaires(bloc('doConsulterBudgetClub')).indexOf('verifierSubventionMairie(') >= 0);

// LA DETTE EST ECRITE A L'ENDROIT OU ELLE SUBSISTE. Un gel qui ne se lit pas dans le code est un
// oubli deguise : le commentaire doit nommer l'arbitrage et dire qu'il n'est pas pris ici.
att("l arbitrage de game design est NOMME dans le code, a l endroit du gel",
    bloc('verifierSubventionMairie').indexOf('decision de game design') >= 0
    && bloc('verifierSubventionMairie').indexOf('repartitions_budgetaires') >= 0);

print('');
if (ko === 0) print('LES ' + attendus + ' EPREUVES SONT VERTES.');
else print('ECHEC : ' + ko + ' epreuve(s) sur ' + attendus + ' en defaut.');
