// ===========================================================================
// BANC CLIENT — CAMION MILITAIRE (29 septembre 2026)
// Verifie les seules decisions prises COTE NAVIGATEUR : quels ordres sont
// affiches, comment la piece est injectee, et que le registre des sources
// d'ordres dynamiques accueille bien deux mecaniques sans que l'une efface
// l'autre. Tout le reste (capacite, PA, priorite) est serveur et se teste
// dans banc_camion_militaire.sql.
// Lancement : jsc .scratch/banc_camion_client.js
// ===========================================================================
var OK = 0, KO = 0, LIGNES = [];
function verifier(nom, condition, detail) {
  if (condition) { OK++; LIGNES.push('  [OK]    ' + nom); }
  else { KO++; LIGNES.push('  [ECHEC] ' + nom + (detail ? ' -> ' + detail : '')); }
}

// ---------- ENVIRONNEMENT MINIMAL ----------
var window = this;
var BUILDINGS = {};
var COUNTRIES = { republic: { cur: 'FR', col: '#C9A84C', n: 'Republia' } };
var WORLD = { republic: { caserne: { name: 'Caserne' }, capitale: { name: 'Luthécia' } } };
var state = {
  char: { name: 'Vince Kubrick' }, country: 'republic',
  currentCity: 'caserne', currentBuilding: 'caserne-militaire', currentRoom: 'corps_garde',
  pa: 12
};
function escapeHtmlText(s) { return String(s); }
function setInterval() { return 1; }
function clearInterval() {}
function showToast() {}
function addJournalEntry() {}
function updateUI() {}

load('plateau-camion-militaire.js');

var CAM = { id: 'camion-1', libelle: 'Camion militaire', image_url: 'images/x.png',
            ville: 'caserne', building_id: 'caserne-militaire', room_id: 'corps_garde',
            capacite: 25 };

// ---------- 1. LE BATIMENT EXISTE, SANS AUCUNE PIECE AU DEPART ----------
verifier('1  batiment synthetique declare, zero piece au chargement',
  !!BUILDINGS['camion-militaire'] && Object.keys(BUILDINGS['camion-militaire'].rooms).length === 0);

// ---------- 2. AUCUN CAMION ICI = AUCUN BOUTON ----------
RP_CAMIONS_ICI = [];
RP_CAMION_ETAT = null;
verifier('2  aucun camion stationne ici : aucun ordre (U)',
  ordresCamionDuLieu('caserne-militaire', 'corps_garde').length === 0);

// ---------- 3. UN CAMION ICI = UN BOUTON ----------
RP_CAMIONS_ICI = [{ id: 'camion-1', libelle: 'Camion militaire', occupants: 0, capacite: 25 }];
var ext = ordresCamionDuLieu('caserne-militaire', 'corps_garde');
verifier('3  un camion stationne : un ordre « Camion militaire », 0 PA / 0 FR',
  ext.length === 1 && ext[0].fn === 'camion_militaire' && ext[0].label === 'Camion militaire'
  && ext[0].pa === 0 && ext[0].cost === 0,
  JSON.stringify(ext));

// ---------- 4. DEUX CAMIONS = UN SEUL BOUTON, COMPTE ----------
RP_CAMIONS_ICI = [{ id: 'a', libelle: 'A', occupants: 0, capacite: 25 },
                  { id: 'b', libelle: 'B', occupants: 3, capacite: 25 }];
var ext2 = ordresCamionDuLieu('caserne-militaire', 'corps_garde');
verifier('4  deux camions : un seul ordre, qui les compte',
  ext2.length === 1 && ext2[0].label === 'Camions militaires (2)', JSON.stringify(ext2));

// ---------- 5. INJECTION DE LA PIECE ----------
var piece = camionInjecterPiece(CAM);
var rooms = Object.keys(BUILDINGS['camion-militaire'].rooms);
verifier('5  une piece, portant l\'id du camion, avec son image et sa sortie',
  rooms.length === 1 && rooms[0] === 'camion-1'
  && piece.imageUrl === 'images/x.png'
  && piece.sortieVers.buildingId === 'caserne-militaire'
  && piece.sortieVers.roomId === 'corps_garde'
  && piece.sortieVers.handler === 'camionSortieDeleguee',
  JSON.stringify(rooms));

// ---------- 6. UN SECOND CAMION REMPLACE LE PREMIER, JAMAIS DE FANTOME ----
camionInjecterPiece({ id: 'camion-2', libelle: 'Autre', ville: 'capitale',
  building_id: 'centre-multinodal-luthecia', room_id: 'hall_gare' });
verifier('6  changer de camion ne laisse aucun onglet fantome (V22)',
  Object.keys(BUILDINGS['camion-militaire'].rooms).join(',') === 'camion-2');

// ---------- 7. INTERIEUR, CIVIL : UNE SEULE COMMANDE ----------
camionInjecterPiece(CAM);
RP_CAMIONS_ICI = [];
RP_CAMION_ETAT = { ok: true, camion: CAM, dedans: true, grade: null,
                   peut_commander: false, destinations: [{ cle: 'x', libelle: 'X' }] };
var civ = ordresCamionDuLieu('camion-militaire', 'camion-1');
verifier('7  civil a bord : il voit l\'interieur et peut descendre, rien d\'autre (C, 23)',
  civ.length === 1 && civ[0].fn === 'camion_descendre' && civ[0].pa === 0,
  JSON.stringify(civ.map(function (o) { return o.fn; })));

// ---------- 8. INTERIEUR, LIEUTENANT ----------
RP_CAMION_ETAT.grade = 'lieutenant';
RP_CAMION_ETAT.peut_commander = true;
var lt = ordresCamionDuLieu('camion-militaire', 'camion-1').map(function (o) { return o.fn + '|' + o.label; });
verifier('8  Lieutenant : descendre, conduire, et « Retour a vide a la caserne » (15)',
  lt.length === 3 && lt[0].indexOf('camion_descendre') === 0
  && lt[1].indexOf('camion_conduire') === 0
  && lt[2] === 'camion_a_vide|Retour à vide à la caserne', lt.join(' ; '));

// ---------- 9. INTERIEUR, CAPITAINE ----------
RP_CAMION_ETAT.grade = 'capitaine';
var cap = ordresCamionDuLieu('camion-militaire', 'camion-1').map(function (o) { return o.fn + '|' + o.label; });
verifier('9  Capitaine : meme trio, mais « Envoyer a vide vers… » (16)',
  cap.length === 3 && cap[2] === 'camion_a_vide|Envoyer à vide vers…', cap.join(' ; '));

// ---------- 10. LA PIECE D'UN AUTRE CAMION NE REND RIEN ----------
verifier('10 l\'etat d\'un camion ne pilote jamais l\'interieur d\'un autre',
  ordresCamionDuLieu('camion-militaire', 'camion-2').length === 0);

// ---------- 11. AUCUN ORDRE NE COUTE DE PA NI DE FR ----------
RP_CAMIONS_ICI = [{ id: 'a', libelle: 'A', occupants: 0, capacite: 25 }];
var tous = ordresCamionDuLieu('camion-militaire', 'camion-1')
  .concat(ordresCamionDuLieu('caserne-militaire', 'corps_garde'));
verifier('11 aucun des ordres du camion ne declare un cout (X, 11)',
  tous.length === 4 && tous.every(function (o) { return o.pa === 0 && o.cost === 0; }));

// ---------- 12. LE REGISTRE ACCUEILLE PLUSIEURS SOURCES ----------
verifier('12 le camion s\'est inscrit au registre des ordres dynamiques',
  Array.isArray(window.RP_ORDRES_DYNAMIQUES)
  && window.RP_ORDRES_DYNAMIQUES.indexOf(ordresCamionDuLieu) >= 0);

// Deux sources, fusionnees exactement comme le fait renderRoomActions.
window.RP_ORDRES_DYNAMIQUES.push(function () {
  return [{ fn: 'commerce_pj', label: 'Gestion de ce commerce', pa: 0, cost: 0 }];
});
RP_CAMION_ETAT = null;
var fusion = [];
window.RP_ORDRES_DYNAMIQUES.forEach(function (f) {
  try { fusion = fusion.concat(f('caserne-militaire', 'corps_garde', 'caserne') || []); } catch (e) {}
});
verifier('13 deux mecaniques coexistent sans qu\'aucune efface l\'autre',
  fusion.length === 2
  && fusion.some(function (o) { return o.fn === 'camion_militaire'; })
  && fusion.some(function (o) { return o.fn === 'commerce_pj'; }),
  JSON.stringify(fusion.map(function (o) { return o.fn; })));

// Une source qui explose ne doit pas emporter les autres.
window.RP_ORDRES_DYNAMIQUES.push(function () { throw new Error('source cassee'); });
var fusion2 = [];
window.RP_ORDRES_DYNAMIQUES.forEach(function (f) {
  try { fusion2 = fusion2.concat(f('caserne-militaire', 'corps_garde', 'caserne') || []); } catch (e) {}
});
verifier('14 une source defaillante n\'emporte pas les autres', fusion2.length === 2);

// ---------- 15. LES RAISONS DE REFUS SONT TOUTES TRADUITES ----------
var raisonsServeur = ['acteur_non_authentifie','camion_introuvable','camion_hors_service',
  'pas_sur_place','pas_a_bord','hors_de_mon_pays','camion_complet','section_trop_nombreuse',
  'capacite_insuffisante','capacite_depassee','officier_absent_du_camion','grade_insuffisant',
  'destination_refusee','envoi_a_vide_hors_caserne','pa_insuffisants_section',
  'cle_requete_absente','personnage_introuvable'];
var manquantes = raisonsServeur.filter(function (r) { return !RP_CAMION_RAISONS[r]; });
verifier('15 chaque refus du serveur a une phrase en francais', manquantes.length === 0,
  manquantes.join(','));

print('\n===== BANC CLIENT CAMION MILITAIRE =====');
print(LIGNES.join('\n'));
print('\n  ' + OK + '/' + (OK + KO) + ' reussis, ' + KO + ' echec(s).');
