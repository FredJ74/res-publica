// BANC DU TITRE D'UN PNJ PORTEUR DE POSTE (10 octobre 2026, cloture de la caserne)
// SOURCES: data.js plateau-navigation.js
//
// CE QU'IL PROUVE. Deux PNJ portent un poste et doivent changer de TITRE -- jamais de place --
// selon qui detient reellement ce poste : Martial Bouterin au ministere de la Defense, et le
// Commandant Tom Hawak a la caserne. La regle etait ecrite en dur pour le seul ministere, avec
// ses deux libelles dans plateau-navigation.js ; elle est desormais GENERIQUE et les libelles
// appartiennent au PNJ, dans data.js.
//
// LES DEUX MOITIES SONT VERIFIEES : le titulaire PNJ donne le titre plein, un titulaire PJ donne
// le titre d'adjoint. Et la troisieme, la plus importante : il n'y a JAMAIS deux Commandants dans
// la piece -- Tom Hawak ne disparait pas, il change de nom de fonction.
//
// L'autorite n'est jamais lue dans state.poste : getTitulaireActuel interroge le registre
// serveur. Le banc le remplace par un espion, ce qui est exactement le point de mesure.
//
// Usage : python3 outils/bancs/lancer-banc.py outils/bancs/banc-titre-pnj-de-poste.js

var ok = 0, ko = 0;
function att(n, c, d) {
  if (c) { print('  ok  ' + n); ok++; }
  else { print('  *** ' + n + (d !== undefined ? ' -- ' + d : '')); ko++; }
}

// DECOR MINIMAL : ce que la fonction touche, et rien de plus.
var rendus = 0;
state = { currentBuilding: null, currentRoom: null };
renderPersonsList = function () { rendus++; };

var demandes = [];
var titulaireRendu = null;
getTitulaireActuel = function (posteId, ville) {
  demandes.push(posteId + '/' + String(ville));
  return Promise.resolve(titulaireRendu);
};

function piece(batiment, salle) {
  state.currentBuilding = batiment; state.currentRoom = salle;
  return BUILDINGS[batiment].rooms[salle];
}
function porteur(p) { return (p.persons || []).filter(function (x) { return x.job; })[0]; }

print('');
print("TITRE D'UN PNJ PORTEUR DE POSTE");
print('============================================================================');

// --- LA DECLARATION EST DANS LES DONNEES, PAS DANS LE CODE -------------------
var cmd = porteur(piece('caserne-militaire', 'salle_commandement'));
att('la Salle de Commandement porte un PNJ de poste `commandant`', cmd && cmd.job === 'commandant',
    cmd ? cmd.job : '(aucun)');
att('ce PNJ est le titulaire du registre, au caractere pres', cmd.name === 'Commandant Tom Hawak',
    cmd.name);
att('il declare ses DEUX libelles',
    cmd.roleSiPnjTitulaire === 'PNJ - Commandant de la Caserne'
    && cmd.roleSiPjTitulaire === 'PNJ - Commandant adjoint',
    cmd.roleSiPnjTitulaire + ' | ' + cmd.roleSiPjTitulaire);
att('il reste en place quand un PJ prend le poste', cmd.resteApresPourvoi === true);
att("aucun General ne figure plus dans la piece",
    (piece('caserne-militaire', 'salle_commandement').persons || [])
      .every(function (p) { return p.job !== 'general'; }));
att("la Salle de Commandement n'est plus declaree reservee au ministre",
    piece('caserne-militaire', 'salle_commandement').requiresPostId === undefined,
    String(piece('caserne-militaire', 'salle_commandement').requiresPostId));

var mart = porteur(piece('palais-gouvernement', 'bureau_min_def'));
att('Martial Bouterin declare aussi ses deux libelles, inchanges',
    mart.roleSiPnjTitulaire === 'PNJ - Ministre de la Defense'
    && mart.roleSiPjTitulaire === 'PNJ - Attaché ministériel — Spécialiste des forces armées',
    mart.roleSiPnjTitulaire + ' | ' + mart.roleSiPjTitulaire);

// --- LE RECALCUL, LES DEUX CAS ----------------------------------------------
function essai(etiquette, batiment, salle, titulaire, attendu, posteAttendu) {
  var p = piece(batiment, salle);
  titulaireRendu = titulaire;
  demandes = []; rendus = 0;
  return ajusterTitrePnjDePoste(batiment, salle).then(function () {
    var x = porteur(p);
    att(etiquette + ' : titre = ' + attendu, x.role === attendu, x.role);
    att(etiquette + " : l'autorite est demandee au registre pour " + posteAttendu,
        demandes.length === 1 && demandes[0] === posteAttendu + '/null', demandes.join(','));
    att(etiquette + ' : la liste des presents est redessinee', rendus === 1, String(rendus));
    att(etiquette + ' : le PNJ est toujours la', !!x && !!x.name, x && x.name);
  });
}

essai('poste tenu par le PNJ', 'caserne-militaire', 'salle_commandement',
      { nom: 'Commandant Tom Hawak', estPJ: false }, 'PNJ - Commandant de la Caserne', 'commandant')
 .then(function () {
   return essai('poste pris par un joueur', 'caserne-militaire', 'salle_commandement',
      { nom: 'Ben', estPJ: true }, 'PNJ - Commandant adjoint', 'commandant');
 })
 .then(function () {
   // IL N'Y A JAMAIS DEUX COMMANDANTS : un seul PNJ dans la piece, et son titre a change.
   var p = piece('caserne-militaire', 'salle_commandement');
   var cmds = (p.persons || []).filter(function (x) { return x.job === 'commandant'; });
   att('un seul PNJ de poste dans la piece, jamais deux', cmds.length === 1, String(cmds.length));
   att("son titre d'adjoint ne pretend plus au poste",
       cmds[0].role.indexOf('adjoint') > 0);
 })
 .then(function () {
   return essai('ministere tenu par le PNJ', 'palais-gouvernement', 'bureau_min_def',
      { nom: 'Martial Bouterin (PNJ)', estPJ: false }, 'PNJ - Ministre de la Defense', 'min_def');
 })
 .then(function () {
   return essai('ministere pris par un joueur', 'palais-gouvernement', 'bureau_min_def',
      { nom: 'Arnie', estPJ: true },
      'PNJ - Attaché ministériel — Spécialiste des forces armées', 'min_def');
 })
 .then(function () {
   // UNE PIECE SANS PNJ DE POSTE NE DOIT RIEN DEMANDER AU SERVEUR : c'est le cas de presque
   // toutes les pieces du jeu, et la fonction est appelee a CHAQUE entree.
   demandes = []; rendus = 0;
   return ajusterTitrePnjDePoste('caserne-militaire', 'refectoire').then(function () {
     att('une piece sans PNJ de poste n interroge pas le registre', demandes.length === 0,
         demandes.join(','));
     att('et ne redessine rien', rendus === 0, String(rendus));
   });
 })
 .then(function () {
   // EN CAS DE DOUTE, ON NE TOUCHE A RIEN : un registre muet laisse le titre precedent.
   var p = piece('caserne-militaire', 'salle_commandement');
   porteur(p).role = 'PNJ - Commandant de la Caserne';
   titulaireRendu = null;
   return ajusterTitrePnjDePoste('caserne-militaire', 'salle_commandement').then(function () {
     att('un registre qui ne sait pas rend le titre plein (fail-soft, jamais adjoint)',
         porteur(p).role === 'PNJ - Commandant de la Caserne', porteur(p).role);
   });
 })
 .then(function () {
   print('');
   if (ko === 0) print('LES ' + ok + ' EPREUVES SONT VERTES.');
   else print('ECHEC : ' + ko + ' epreuve(s) sur ' + (ok + ko) + '.');
 })
 .catch(function (e) { print('ECHEC : exception -- ' + e + '\n' + (e && e.stack)); });
