// ===========================================================================
// BANC — « PERSONNES PRESENTES » : PRESENCES AUTONOMES ET GROUPES RATTACHES
// 29 septembre 2026.  jsc .scratch/banc_presences_groupe.js
// Aucun reseau, aucun DOM reel : on lit le HTML compose par renderPersonsList.
// ===========================================================================

var SORTIE = {}, SELECTEURS_VUS = [], ORPHELINS_RETIRES = [], DERNIER_INSERT = '';
function noeud() {
  return {
    innerHTML: '',
    insertAdjacentHTML: function (ou, html) { this.innerHTML += html; DERNIER_INSERT = html; },
    querySelectorAll: function () { return []; },
    querySelector: function (sel) {
      SELECTEURS_VUS.push(sel);
      var self = this;
      // On simule la presence du conteneur en attente : il est dans innerHTML.
      if (self.innerHTML.indexOf(sel.replace('[', '').replace(']', '')) >= 0) {
        return { remove: function () { ORPHELINS_RETIRES.push(sel); } };
      }
      return null;
    }
  };
}
var document = {
  getElementById: function (id) { if (!SORTIE[id]) SORTIE[id] = noeud(); return SORTIE[id]; },
  querySelectorAll: function () { return []; }
};
var localStorage = { getItem: function () { return null; }, setItem: function () {}, removeItem: function () {} };
var sessionStorage = { getItem: function () { return null; } };
var console = { error: function () {}, warn: function () {}, log: function () {} };
var window = {};

var state = { char: { name: 'Vince Kubrick', archetype: 'militaire' }, country: 'republic',
              currentCity: 'caserne', currentBuilding: 'caserne-militaire', currentRoom: 'corps_garde',
              poste: { id: 'lieutenant' }, inventory: [], employes: [] };
var COUNTRIES = { republic: { col: '#C9A84C', cur: 'FR' } };
var ARCHETYPES = [{ id: 'militaire', name: 'Militaire' }];
var PNJ_AVATAR = { default: 'ti-user', militaire: 'ti-shield', policier: 'ti-shield-star' };

// Stubs neutres du pipeline : on teste la COMPOSITION, pas ces filtres.
function appliquerRemplacantesEscort(p) { return p; }
function appliquerRemplacantCodetenu(p) { return p; }
function filtrerPnjPostesPourvus(p) { return p; }
function appliquerDeputesAssemblee(p) { return p; }
function getSimulesPresents() { return []; }
function encodePnjSafe(o) { return 'enc'; }
function marqueurMutinHtml() { return ''; }
function escapeHtmlText(s) { return String(s == null ? '' : s); }
function chargerVraisJoueursPresents() {}
function chargerObjetsAbandonnesDansPiece() {}
function openPnjModal() {} function openSelfView() {} function ouvrirInfoDetachement() {}
function doGererDetachement() {}

load('plateau-multijoueur.js');

// --- outillage -------------------------------------------------------------
var CAS = [], n_ok = 0, n_ko = 0;
function cas(nom, ok, detail) {
  if (ok) { n_ok++; CAS.push('  [OK]    ' + nom); }
  else { n_ko++; CAS.push('  [ECHEC] ' + nom + (detail ? ' -> ' + detail : '')); }
}
function rendre(persons, cible) {
  SORTIE['persons-list'] = noeud();
  SORTIE['persons-list-rue'] = noeud();
  renderPersonsList(persons, cible);
  return SORTIE[cible || 'persons-list'].innerHTML;
}
// Le bloc de groupe, s'il existe : tout ce qui suit <div class="presence-groupe"> jusqu'a sa fin.
function blocGroupe(html) {
  var i = html.indexOf('<div class="presence-groupe">');
  if (i < 0) return null;
  var reste = html.slice(i + 29), prof = 1, j = 0;
  while (j < reste.length && prof > 0) {
    if (reste.substr(j, 4) === '<div') prof++;
    else if (reste.substr(j, 6) === '</div>') prof--;
    j++;
  }
  return reste.slice(0, j);
}
function compte(html, aiguille) {
  var n = 0, i = 0;
  while ((i = html.indexOf(aiguille, i)) >= 0) { n++; i += aiguille.length; }
  return n;
}

var DETACHEMENT = { name: 'Soldats section "Vince Kubrick"', role: '24 soldats — Sans consigne',
                    rel: 'neutral', job: 'militaire', detachement: true,
                    lieutenantNom: 'Vince Kubrick', estAccompagnement: true, leader: 'Vince Kubrick' };
var PNJ_A = { name: 'Adjudant Gaspard Ferrière (PNJ)', role: 'PNJ - Aide de camp', rel: 'friendly', job: 'aide_de_camp' };
var PNJ_B = { name: 'Caporal Alouche (PNJ)', role: 'PNJ - Intendance', rel: 'neutral', job: 'militaire' };

// --- 1. LEADER SEUL --------------------------------------------------------
var h = rendre([]);
cas('1. leader seul : sa carte, et aucun bloc de groupe',
    h.indexOf('(Vous)') >= 0 && blocGroupe(h) === null, h.slice(0, 80));

// --- 2. LEADER + GROUPE MILITAIRE -----------------------------------------
h = rendre([DETACHEMENT]);
var bloc = blocGroupe(h);
cas('2. leader + section : la section est DANS le bloc rattache',
    bloc !== null && bloc.indexOf('24 soldats') >= 0, bloc === null ? 'aucun bloc' : bloc.slice(0, 60));
cas('2b. la section n\'est pas une presence autonome',
    h.indexOf('24 soldats') > h.indexOf('presence-groupe'));
cas('2c. aucun doublon de la section', compte(h, '24 soldats') === 1, 'trouvee ' + compte(h, '24 soldats') + ' fois');

// --- 3. PNJ AUTONOMES AUTOUR DU GROUPE ------------------------------------
h = rendre([PNJ_A, DETACHEMENT, PNJ_B]);
bloc = blocGroupe(h);
cas('3. les PNJ autonomes restent hors du bloc',
    bloc !== null && bloc.indexOf('Ferrière') < 0 && bloc.indexOf('Alouche') < 0);
cas('3b. les PNJ autonomes reprennent APRES le groupe',
    h.indexOf('Ferrière') > h.indexOf('presence-groupe') && h.indexOf('Alouche') > h.indexOf('presence-groupe'));
cas('3c. les deux PNJ sont bien affiches',
    h.indexOf('Ferrière') >= 0 && h.indexOf('Alouche') >= 0);

// --- 4. EMPLOYES / AGENTS DANS LE MEME BLOC -------------------------------
// On alimente la VRAIE source : plateau-multijoueur.js declare sa propre
// getGroupeHtmlPourPiece, qui remplace tout stub au chargement. Tant mieux : le cas
// teste alors le vrai chemin des employes du groupe.
state.employes = [{ nom: 'Jérémy', inGroupe: true, job: 'informateur' }];
h = rendre([DETACHEMENT]);
bloc = blocGroupe(h);
cas('4. employes et section partagent le meme bloc rattache',
    bloc !== null && bloc.indexOf('Jérémy') >= 0 && bloc.indexOf('24 soldats') >= 0);
state.employes = [];

// --- 5. ACCOMPAGNANT D'UN AUTRE CHEF --------------------------------------
var AUTRE = { name: 'Soldats section "Marsault"', role: '12 soldats — Sans consigne', rel: 'neutral',
              job: 'militaire', detachement: true, lieutenantNom: 'Marsault',
              estAccompagnement: true, leader: 'Marsault' };
h = rendre([AUTRE, PNJ_A]);
cas('5. groupe d\'un autre chef : affiche, hors du bloc du joueur',
    h.indexOf('12 soldats') >= 0 && blocGroupe(h) === null);

// --- 6. DEUX GROUPES, DEUX CHEFS ------------------------------------------
h = rendre([DETACHEMENT, AUTRE, PNJ_A]);
bloc = blocGroupe(h);
cas('6. deux chefs : le mien est rattache, l\'autre non',
    bloc !== null && bloc.indexOf('24 soldats') >= 0 && bloc.indexOf('12 soldats') < 0);
cas('6b. aucun des deux n\'est perdu',
    h.indexOf('24 soldats') >= 0 && h.indexOf('12 soldats') >= 0);

// --- 7. ACCOMPAGNANT SANS CHEF NOMME --------------------------------------
var SANS_CHEF = { name: 'Escorte', role: 'accompagne', rel: 'neutral', job: 'escort',
                  estAccompagnement: true, leader: null };
h = rendre([SANS_CHEF]);
bloc = blocGroupe(h);
cas('7. accompagnant sans chef nomme : rattache au joueur',
    bloc !== null && bloc.indexOf('Escorte') >= 0);

// --- 8. EXTERIEUR : MEME COMPOSITION DANS LA LISTE DE RUE ------------------
state.currentBuilding = null; state.currentRoom = null;
h = rendre([DETACHEMENT], 'persons-list-rue');
bloc = blocGroupe(h);
cas('8. dehors : la section reste rattachee au joueur',
    bloc !== null && bloc.indexOf('24 soldats') >= 0);
cas('8b. dehors : aucun doublon', compte(h, '24 soldats') === 1);
state.currentBuilding = 'caserne-militaire'; state.currentRoom = 'corps_garde';

// --- 9. RETOUR A L'INTERIEUR ----------------------------------------------
h = rendre([DETACHEMENT, PNJ_A]);
bloc = blocGroupe(h);
cas('9. retour dedans : rattachement intact, PNJ du lieu revenus',
    bloc !== null && bloc.indexOf('24 soldats') >= 0 && h.indexOf('Ferrière') >= 0);

// --- 10. LISTE VIDE --------------------------------------------------------
h = rendre([]);
cas('10. liste sans personne : la carte du joueur suffit, pas de bloc vide',
    h.indexOf('presence-groupe') < 0);

// --- 11 a 15 : LE GROUPE D'UN AUTRE JOUEUR ------------------------------------
// On simule le pipeline multijoueur : deux joueurs presents, chacun accompagne.
var PRESENTS = [];
function sbGetPresencesInRoom() { return Promise.resolve(PRESENTS); }
function rafraichirCachePhotosJoueurs() { return Promise.resolve({}); }
function ouvrirFichePnjAutreJoueur() {}

var SECTION_VINCE = { name: 'Soldats section "Vince Kubrick"', role: '24 soldats — Sans consigne',
                      rel: 'neutral', job: 'militaire', detachement: true,
                      lieutenantNom: 'Vince Kubrick', estAccompagnement: true, leader: 'Vince Kubrick' };
var SECTION_MARSAULT = { name: 'Soldats section "Marsault"', role: '12 soldats — Sans consigne',
                         rel: 'neutral', job: 'militaire', detachement: true,
                         lieutenantNom: 'Marsault', estAccompagnement: true, leader: 'Marsault' };

// Le joueur courant devient Arnie : il OBSERVE Vince et Marsault.
state.char = { name: 'Arnie', archetype: 'militaire' };

function observer(persons, cible, fait) {
  rendre(persons, cible);
  return chargerVraisJoueursPresents(
    cible === 'persons-list-rue' ? 'rue-centrale' : state.currentBuilding,
    cible === 'persons-list-rue' ? 'noeud' : state.currentRoom, cible
  ).then(function () { fait(DERNIER_INSERT); });
}

var suite = Promise.resolve();

// 11. Arnie voit Vince, sa section COLLEE a sa carte
suite = suite.then(function () {
  PRESENTS = [{ name: 'Vince Kubrick', groupe_pnj: [] }];
  return observer([SECTION_VINCE], 'persons-list', function (h) {
    var i = h.indexOf('Vince Kubrick');
    var j = h.indexOf('presence-groupe', i);
    var k = h.indexOf('24 soldats', i);
    cas('11. Arnie voit la section COLLEE a la carte de Vince',
        i >= 0 && j > i && k > j && h.indexOf('bloc-joueur-autre') >= 0,
        'i=' + i + ' j=' + j + ' k=' + k);
    cas('11b. aucun doublon de la section', compte(h, '24 soldats') === 1,
        compte(h, '24 soldats') + ' fois');
    cas('11c. le conteneur en attente a ete repris', ORPHELINS_RETIRES.length > 0);
  });
});

// 12. Dehors, meme rattachement
suite = suite.then(function () {
  ORPHELINS_RETIRES = [];
  state.currentBuilding = null; state.currentRoom = null;
  PRESENTS = [{ name: 'Vince Kubrick', groupe_pnj: [] }];
  return observer([SECTION_VINCE], 'persons-list-rue', function (h) {
    var i = h.indexOf('Vince Kubrick'), j = h.indexOf('presence-groupe', i);
    cas('12. dehors : la section reste collee a Vince', i >= 0 && j > i && h.indexOf('24 soldats') > j);
    state.currentBuilding = 'caserne-militaire'; state.currentRoom = 'corps_garde';
  });
});

// 13. Deux leaders, deux groupes : aucun rattachement croise
suite = suite.then(function () {
  PRESENTS = [{ name: 'Vince Kubrick', groupe_pnj: [] }, { name: 'Marsault', groupe_pnj: [] }];
  return observer([SECTION_VINCE, SECTION_MARSAULT], 'persons-list', function (h) {
    var blocs = h.split('bloc-joueur-autre');
    var blocVince = blocs.filter(function (b) { return b.indexOf('Vince Kubrick') >= 0; })[0] || '';
    var blocMars  = blocs.filter(function (b) { return b.indexOf('Marsault') >= 0 && b.indexOf('Vince') < 0; })[0] || '';
    cas('13. le groupe de Vince est sous Vince', blocVince.indexOf('24 soldats') >= 0);
    cas('13b. aucun rattachement croise', blocVince.indexOf('12 soldats') < 0);
    cas('13c. les deux groupes sont presents',
        h.indexOf('24 soldats') >= 0 && h.indexOf('12 soldats') >= 0);
    cas('13d. aucun doublon',
        compte(h, '24 soldats') === 1 && compte(h, '12 soldats') === 1);
  });
});

// 14. Employes/escortes publies dans la presence d'un autre joueur
suite = suite.then(function () {
  PRESENTS = [{ name: 'Vince Kubrick', groupe_pnj: [{ nom: 'Jérémy', role: 'Informateur', job: 'informateur' }] }];
  return observer([], 'persons-list', function (h) {
    var i = h.indexOf('Vince Kubrick'), j = h.indexOf('presence-groupe', i);
    cas('14. les PNJ publies par un autre joueur sont rattaches a lui',
        i >= 0 && j > i && h.indexOf('Jérémy') > j);
  });
});

// 15. Un chef absent : son groupe n'est pas cache
suite = suite.then(function () {
  PRESENTS = [];
  return observer([SECTION_MARSAULT], 'persons-list', function () {
    // Aucun joueur present : rien n'est insere, et c'est exactement le point du test --
    // le groupe doit rester dans la liste deja rendue, jamais disparaitre.
    var liste = SORTIE['persons-list'].innerHTML;
    cas('15. chef absent : le groupe reste affiche, jamais masque',
        liste.indexOf('12 soldats') >= 0 && liste.indexOf('data-accompagnant-de') >= 0);
  });
});

suite.then(function () {

// --- rapport ---------------------------------------------------------------
print('');
print('=====================================================');
print('  BANC PRESENCES / GROUPES — ' + n_ok + '/' + (n_ok + n_ko) + ' cas verts');
print('=====================================================');
CAS.forEach(function (c) { print(c); });
print('');
});
