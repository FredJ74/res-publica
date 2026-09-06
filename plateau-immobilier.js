// =====================
// PLATEAU-IMMOBILIER.JS — PIECES DYNAMIQUES DES LOTS (Lot 1.1, 6 septembre 2026)
// =====================
// Point central UNIQUE de l'hydratation des lots immobiliers en vraies pieces visitables.
// Chaine cible du chantier : MURS -> LOT -> BAIL -> FONDS. Ce lot ne traite que MURS -> LOT ->
// PIECE : aucun droit, aucun bail, aucun fonds de commerce, aucune action metier.
//
// PRINCIPE : un lot n'est PAS une navigation parallele. Il devient une entree ordinaire de
// BUILDINGS[<terrainId>].rooms, donc automatiquement un onglet (enterBuilding), une piece
// ouvrable (enterRoom), une position persistee (current_room), une presence publiee
// (sbUpdatePresence) et un lieu d'objets abandonnes -- sans qu'aucun de ces mecanismes n'ait a
// connaitre l'existence des lots.
//
// SOURCE DE VERITE : terrains_etat.data.subdivisions[]. Rien n'est duplique ici : les rooms
// generees sont une VUE, reconstruite a chaque hydratation, jamais persistee.
//
// IDENTITE : lot.id ('lot-<timestamp>', pose a la creation du lot et jamais reecrit) est la
// seule base de l'identifiant de piece. Ni le label, ni le locataire, ni le loyer, ni l'ordre
// d'affichage, ni l'index de tableau n'y participent : renommer un lot, changer son locataire ou
// son loyer ne produit jamais une piece techniquement differente.

const PIECE_LOT_PREFIXE = 'lot_dyn_';

// Registre des pieces reellement injectees, par batiment -- seule base de la purge. On ne devine
// jamais quelles rooms retirer en relisant BUILDINGS : on retire exactement ce qu'on a ajoute.
const _piecesLotsInjectees = {};

function estPieceDynamiqueLot(roomId) {
  return typeof roomId === 'string' && roomId.slice(0, PIECE_LOT_PREFIXE.length) === PIECE_LOT_PREFIXE;
}

// roomId derive de l'identifiant persistant du lot. Assainissement strict : le roomId finit dans
// un attribut onclick HTML (enterBuilding) et dans une cle d'objet, donc aucun caractere autre
// que [A-Za-z0-9_-] ne doit survivre.
function roomIdDepuisLot(lotId) {
  if (typeof lotId !== 'string') return null;
  const brut = lotId.trim();
  if (!brut) return null;
  const sain = brut.replace(/[^A-Za-z0-9_-]/g, '_');
  return sain ? PIECE_LOT_PREFIXE + sain : null;
}

function lotIdDepuisRoomId(roomId) {
  if (!estPieceDynamiqueLot(roomId)) return null;
  return roomId.slice(PIECE_LOT_PREFIXE.length) || null;
}

// Un lot n'est hydratable que s'il porte un identifiant exploitable. Tout le reste (label,
// surface) est facultatif : un lot historique incomplet doit s'afficher, jamais faire echouer
// l'hydratation de ses voisins.
function lotHydratable(lot) {
  return !!(lot && typeof lot === 'object' && roomIdDepuisLot(lot.id));
}

// Lots du terrain, lus dans le cache synchrone deja tenu par getTerrainState (plateau-justice-
// economie.js). Aucun appel reseau ici : l'hydratation doit pouvoir s'executer dans le chemin
// synchrone de enterBuilding.
function lotsDuTerrain(buildingId) {
  if (typeof getTerrainState !== 'function' || !buildingId) return [];
  let ts = null;
  try { ts = getTerrainState(buildingId); } catch (e) { return []; }
  const subdivisions = (ts && Array.isArray(ts.subdivisions)) ? ts.subdivisions : [];
  return subdivisions.filter(lotHydratable);
}

// Fabrique la room. Forme volontairement identique a celle d'une room statique de data.js --
// aucun champ inventé, aucune structure paralelle.
//   _lotId       : rattachement au lot persistant (marqueur interne, ignore par le moteur)
//   _buildingId  : batiment porteur, pour un diagnostic sans ambiguite
// orders vide : le Lot 1.1 ne cree AUCUNE action metier (droits murs/locataire/fonds = Lot 1.2).
// persons vide : jamais de PNJ dans un lot a ce stade.
// Image : aucun asset dedie, aucune logique premium/freemium. enterRoom retombe deja sur
// l'image du niveau de construction du terrain porteur (chantierImg) ; imageBg est le dernier
// filet pour que la piece soit toujours affichable sans requete.
function construireRoomLot(lot, buildingId) {
  const surface = (typeof lot.surface === 'number' && isFinite(lot.surface) && lot.surface > 0) ? lot.surface : null;
  const label = (typeof lot.label === 'string' && lot.label.trim()) ? lot.label.trim() : 'Lot sans nom';
  const nom = surface ? (label + ' — ' + surface + ' m²') : label;
  const desc = surface
    ? ('Local de ' + surface + ' m² situé dans ce bâtiment.')
    : 'Local situé dans ce bâtiment.';
  return {
    name: nom,
    desc: desc,
    imageBg: 'linear-gradient(135deg,#0a0a07,#14120c)',
    persons: [],
    orders: [],
    _lotId: lot.id,
    _buildingId: buildingId
  };
}

// Retire les pieces dynamiques deja injectees. Sans argument : toutes, quel que soit le batiment
// -- c'est ce que fait l'hydratation avant chaque injection, ce qui couvre d'un seul mecanisme le
// changement de ville, d'empire et de batiment sans avoir a s'y accrocher separement (un joueur
// n'est jamais dans deux batiments a la fois). Ne touche JAMAIS une room statique : seules les
// cles reellement enregistrees dans le registre sont supprimees.
function purgerPiecesDynamiques(buildingId) {
  const cibles = buildingId ? [buildingId] : Object.keys(_piecesLotsInjectees);
  let retirees = 0;
  cibles.forEach(function (bId) {
    const roomIds = _piecesLotsInjectees[bId] || [];
    const rooms = (typeof BUILDINGS !== 'undefined' && BUILDINGS[bId]) ? BUILDINGS[bId].rooms : null;
    roomIds.forEach(function (roomId) {
      if (rooms && Object.prototype.hasOwnProperty.call(rooms, roomId)) { delete rooms[roomId]; retirees++; }
    });
    delete _piecesLotsInjectees[bId];
  });
  return retirees;
}

// Purge globale puis injection des lots du batiment demande. Idempotente : deux appels successifs
// produisent exactement le meme resultat, jamais de doublon. Les rooms statiques du batiment sont
// conservees et restent EN TETE de l'objet rooms -- important, enterRoom deduit isFirstRoom du
// premier ordre d'insertion (plateau-navigation.js) et l'accueil d'un terrain doit le rester.
function hydraterPiecesDynamiques(buildingId) {
  purgerPiecesDynamiques();
  if (!buildingId || typeof BUILDINGS === 'undefined') return 0;
  const b = BUILDINGS[buildingId];
  if (!b) return 0;
  const lots = lotsDuTerrain(buildingId);
  if (lots.length === 0) return 0;
  if (!b.rooms) b.rooms = {};
  const injectees = [];
  lots.forEach(function (lot) {
    const roomId = roomIdDepuisLot(lot.id);
    // Ne jamais ecraser une room statique portant par accident le meme identifiant.
    if (!roomId || Object.prototype.hasOwnProperty.call(b.rooms, roomId)) return;
    b.rooms[roomId] = construireRoomLot(lot, buildingId);
    injectees.push(roomId);
  });
  if (injectees.length > 0) _piecesLotsInjectees[buildingId] = injectees;
  return injectees.length;
}

// Signature de l'ensemble des lots injectes -- sert uniquement a savoir s'il faut reconstruire
// les onglets apres un rafraichissement Supabase, sans le faire inutilement a chaque passage.
function signaturePiecesDynamiques(buildingId) {
  return lotsDuTerrain(buildingId)
    .map(function (l) { return l.id + '|' + (l.label || '') + '|' + (l.surface || ''); })
    .join(';');
}

// Rafraichissement apres arrivee de donnees fraiches (chargerTerrainState). Reconstruit les
// onglets UNIQUEMENT si l'ensemble des lots a reellement change et si le joueur est toujours dans
// ce batiment -- jamais de re-rendu gratuit sous les doigts du joueur.
function rafraichirPiecesDynamiques(buildingId) {
  if (!buildingId || typeof state === 'undefined' || state.currentBuilding !== buildingId) return false;
  const avant = (_piecesLotsInjectees[buildingId] || []).join(';');
  hydraterPiecesDynamiques(buildingId);
  const apres = (_piecesLotsInjectees[buildingId] || []).join(';');
  if (avant === apres) return false;
  // state.currentRoom est passe explicitement : la reconstruction a lieu alors que le joueur est
  // deja dans une piece, qui doit rester l'onglet actif (enterBuilding, lui, n'a pas encore de
  // piece courante et conserve son comportement d'origine).
  if (typeof renderOngletsPieces === 'function') renderOngletsPieces(buildingId, state.currentRoom);
  return true;
}

// Restauration differee (Lot 1.1, §8) : au demarrage, restaurerPositionApresChargement
// (plateau-core.js) s'execute a partir du seul localStorage, AVANT tout chargement Supabase --
// une piece de lot n'existe donc pas encore et la garde d'existence ferait retomber le joueur
// dans la rue. Une SEULE nouvelle tentative est faite ici, apres chargement reel de l'etat du
// terrain : jamais de boucle, jamais de re-essai permanent. Si la piece n'existe toujours pas
// (lot supprime entre-temps, terrain inaccessible), on n'insiste pas -- la navigation normale
// reprend la main.
let _restaurationLotTentee = false;

async function restaurerPieceDynamiqueDifferee(buildingId, roomId) {
  if (_restaurationLotTentee) return false;
  _restaurationLotTentee = true;
  if (!estPieceDynamiqueLot(roomId) || typeof chargerTerrainState !== 'function') return false;
  try {
    await chargerTerrainState(buildingId);
  } catch (e) { return false; }
  hydraterPiecesDynamiques(buildingId);
  const existe = !!(typeof BUILDINGS !== 'undefined' && BUILDINGS[buildingId] && BUILDINGS[buildingId].rooms
    && BUILDINGS[buildingId].rooms[roomId]);
  if (!existe) return false;
  if (typeof enterBuilding === 'function') enterBuilding(buildingId, true);
  if (typeof enterRoom === 'function') enterRoom(buildingId, roomId, null);
  return true;
}

// =====================
// DROITS GENERIQUES SUR UN LOCAL — murs / locataire / fonds (Lot 1.2, 6 septembre 2026)
// =====================
// Remplace la perspective "chaque ordre reverifie lui-meme si je suis le proprietaire" par trois
// roles nommes, resolus a UN SEUL endroit :
//   'murs'      : proprietaire du bien immobilier (terrains_etat.proprietaire du terrain porteur)
//   'locataire' : titulaire du bail/de la location rattache a CE local precis
//   'fonds'     : proprietaire/exploitant du fonds de commerce installe dans ce local
//
// Le role 'fonds' est PREPARE mais jamais attribue dans ce lot : aucun fonds de commerce
// generique n'existe encore (Lot 2.0). resoudreRoleFonds() renvoie donc toujours false, et
// n'essaie surtout pas de faire passer les commerces historiques (table 'entreprises') pour des
// fonds deja migres -- ils relevent d'une autre architecture, hors perimetre.
//
// Toute comparaison de titularite passe par estTitulaire() (Lot 1.0 bis), donc la compatibilite
// avec les proprietaires/locataires historiques stockes en nom brut est acquise, et aucune donnee
// n'est basculee vers 'pj:'/'orga:'.
//
// ORGANISATIONS : une reference 'orga:<id>' ne confere aucun role tant que
// peutAgirPourOrganisation() est ferme -- estTitulaire('orga:X') est faux pour un PJ, y compris
// le chef de cette organisation. Aucune gouvernance n'est inventee ici.

const ROLES_LOCAL = ['murs', 'locataire', 'fonds'];

// Proprietaire des murs. Aujourd'hui, seuls les terrains a batir portent une notion de propriete
// immobiliere (terrains_etat) : tout autre batiment n'a pas de "murs" attribuables, la reponse est
// donc negative, jamais inventee.
function resoudreRoleMurs(buildingId) {
  if (typeof buildingId !== 'string' || !buildingId.startsWith('terrain-a-batir')) return false;
  if (typeof getTerrainState !== 'function' || typeof estTitulaire !== 'function') return false;
  let ts = null;
  try { ts = getTerrainState(buildingId); } catch (e) { return false; }
  return !!(ts && estTitulaire(ts.proprietaire));
}

// Titulaire du bail sur CE local precis. Deux supports coexistent aujourd'hui, sans etre unifies
// (l'unification est le Lot 1.3) :
//   - piece de lot (Lot 1.1)  -> subdivisions[].locataire du terrain porteur, retrouve par _lotId
//   - piece de location statique -> locations_actives, via getLocationPourRoom (buildingId +
//     roomId + city, la cle exacte corrigee au Lot 1.0)
function resoudreRoleLocataire(buildingId, roomId, city) {
  if (typeof estTitulaire !== 'function') return false;
  // Lot 1.3 : source unique. Cette fonction ne choisit plus entre locations_actives et
  // subdivisions[].locataire -- elle interroge le resolveur de bail, qui fait seul autorite
  // (bailPourLocal, plus bas dans ce fichier).
  const bail = bailPourLocal(buildingId, roomId, city);
  return !!(bail && estTitulaire(bail.locataire));
}

// Fonds de commerce : volontairement toujours negatif dans ce lot. Point d'extension unique --
// c'est ici, et uniquement ici, que le Lot 2.0 branchera la resolution reelle.
function resoudreRoleFonds(buildingId, roomId, city) { // eslint-disable-line no-unused-vars
  return false;
}

// Roles reellement detenus par le joueur courant sur ce local. Retourne toujours un tableau,
// jamais null : un local sans propriete ni bail renvoie simplement [].
function roleSurLocal(buildingId, roomId, city) {
  const ville = city || (typeof state !== 'undefined' ? state.currentCity : null);
  const roles = [];
  if (resoudreRoleMurs(buildingId)) roles.push('murs');
  if (resoudreRoleLocataire(buildingId, roomId, ville)) roles.push('locataire');
  if (resoudreRoleFonds(buildingId, roomId, ville)) roles.push('fonds');
  return roles;
}

function aRoleSurLocal(role, buildingId, roomId, city) {
  if (ROLES_LOCAL.indexOf(role) === -1) return false;
  return roleSurLocal(buildingId, roomId, city).indexOf(role) !== -1;
}

// Retrouve la definition d'un ordre tel que le joueur le voit reellement. Reproduit EXACTEMENT la
// fusion de renderRoomActions (room.orders + ctx.orders + ctx.roomOverrides[roomId].orders, moins
// excludeOrders) : sans cela, un ordre declare dans un buildingContext echapperait a la garde
// d'execution alors qu'il serait bien filtre a l'affichage -- exactement le contournement que la
// defense en profondeur doit interdire.
function definitionOrdreDansPiece(buildingId, roomId, fn) {
  if (typeof BUILDINGS === 'undefined' || !buildingId || !roomId || !fn) return null;
  const b = BUILDINGS[buildingId];
  if (!b) return null;
  const ctx = (typeof getBuildingContext === 'function') ? getBuildingContext(buildingId) : null;
  const room = (b.rooms && b.rooms[roomId]) || (ctx && ctx.roomsExtra && ctx.roomsExtra[roomId]);
  const exclus = (ctx && ctx.roomOverrides && ctx.roomOverrides[roomId] && ctx.roomOverrides[roomId].excludeOrders) || [];
  if (exclus.indexOf(fn) !== -1) return null;
  const sources = []
    .concat((room && room.orders) || [])
    .concat((ctx && ctx.orders) || [])
    .concat((ctx && ctx.roomOverrides && ctx.roomOverrides[roomId] && ctx.roomOverrides[roomId].orders) || []);
  return sources.find(function (o) { return o && o.fn === fn; }) || null;
}

// Libelles des refus, volontairement neutres : ils disent le role requis, jamais QUI le detient
// (ne jamais transformer une garde de droits en fuite d'information sur autrui).
const MESSAGES_ROLE_LOCAL = {
  murs:      'Action réservée au propriétaire de ce bien.',
  locataire: 'Action réservée au locataire de ce local.',
  fonds:     'Action réservée à l\'exploitant du commerce de ce local.'
};

function messageRoleLocal(role) {
  return MESSAGES_ROLE_LOCAL[role] || 'Vous n\'avez pas le rôle requis pour cette action ici.';
}

// Verdict unique, partage par le rendu (grisage + infobulle) et par doOrder (blocage reel).
// { bloque:false } des qu'un ordre ne declare aucun requiresRole -- heritage strict : tout ordre
// existant continue de se comporter exactement comme avant ce lot.
function verdictRoleOrdre(buildingId, roomId, fn, ordreDef) {
  const def = ordreDef || definitionOrdreDansPiece(buildingId, roomId, fn);
  const role = def && def.requiresRole;
  if (!role || ROLES_LOCAL.indexOf(role) === -1) return { bloque: false, role: null, message: '' };
  if (aRoleSurLocal(role, buildingId, roomId)) return { bloque: false, role: role, message: '' };
  return { bloque: true, role: role, message: messageRoleLocal(role) };
}

// =====================
// BAIL UNIFIE — locations_actives comme source unique (Lot 1.3, 6 septembre 2026)
// =====================
// AVANT ce lot, deux systemes locatifs coexistaient reellement :
//   A. locations_actives                          -> pieces statiques louables (centres, suites,
//      box portuaires, logements sociaux, chambres de clinique)
//   B. terrains_etat.data.subdivisions[].locataire -> lots issus d'une division de batiment
// resoudreRoleLocataire (Lot 1.2) devait donc choisir entre deux verites. Ce lot fait de
// locations_actives LA source unique : un lot loue est desormais un bail comme un autre.
//
// MIROIR TRANSITOIRE, assume et documente : subdivision.locataire/loyer continuent d'etre ECRITS
// mais ne sont plus LUS comme verite metier. Motif verifie a l'audit : preleverLoyersLots
// (api/cron-minuit.js) preleve encore les loyers de lots depuis ces champs, et le cron est
// explicitement hors perimetre (Lot 1.4). Supprimer le miroir maintenant arreterait les loyers.
// Le Lot 1.4 lira le bail et le miroir disparaitra.
//
// ETAT REEL DE LA PRODUCTION AU MOMENT DE CE LOT (releve en lecture seule) : 4 lignes
// terrains_etat, ZERO subdivision, donc AUCUN bail de lot a migrer ; et 7 baux statiques, tous
// dans des locaux de centres, sans les nouveaux champs. Ces 7 baux ne sont pas migres : les
// champs manquants sont DERIVES a la lecture (meme doctrine que la compatibilite titulaires du
// Lot 1.0 bis), donc aucune migration n'est requise pour que ce lot fonctionne.

// Identite canonique d'un local, unique dans tout le jeu. Couvre le pays, la ville, le batiment
// et la piece -- et donc le lot, puisque la piece d'un lot porte deja son _lotId dans son roomId
// ('lot_dyn_<lotId>', Lot 1.1). Ne depend JAMAIS du label visible du lot ni du locataire.
function localKeyDe(country, city, buildingId, roomId) {
  if (!buildingId || !roomId) return null;
  return (country || 'republic') + '|' + (city || 'capitale') + '|' + buildingId + '|' + roomId;
}

function decomposerLocalKey(localKey) {
  if (typeof localKey !== 'string') return null;
  const p = localKey.split('|');
  if (p.length !== 4 || !p[2] || !p[3]) return null;
  return { country: p[0], city: p[1], buildingId: p[2], roomId: p[3] };
}

// localKey d'un bail : lu s'il est present, DERIVE sinon. C'est ce qui permet aux 7 baux
// historiques de fonctionner sans migration.
function localKeyDuBail(bail) {
  if (!bail) return null;
  if (typeof bail.localKey === 'string' && bail.localKey) return bail.localKey;
  return localKeyDe(bail.country, bail.city, bail.buildingId, bail.roomId);
}

// DESTINATION DU LOYER (Lot 1.3 : le bail la PORTE ; le versement reel reste au Lot 1.4).
// Trois valeurs, volontairement explicites plutot que deduites plus tard d'un test de type :
//   'municipal'      -> budgets_municipaux[<pays>_<ville>].data.caisse, la Caisse municipale
//                       disponible et depensable par le pouvoir municipal (arbitrage valide).
//                       JAMAIS caisses_batiments. C'est le cas des locaux de centres
//                       (commercial/artisanal/affaires) et des autres locaux publics existants.
//   'titulaire_murs' -> le proprietaire du bien, porte par terrains_etat.proprietaire du terrain.
//                       C'est le cas d'un lot issu de la division d'un batiment prive.
//                       Lot 1.5.0 : le champ `titulaire` n'est PLUS ecrit pour ces lots. Il l'etait,
//                       et figeait donc le proprietaire au jour de la signature du bail : apres une
//                       vente des murs, les loyers continuaient d'aller a l'ANCIEN proprietaire,
//                       indefiniment. Le loyer appartient au proprietaire ACTUEL. On laisse donc la
//                       destination vide de titulaire et c'est prelever_loyer_bail (autorite
//                       transactionnelle, Lot 1.4) qui resout terrains_etat.proprietaire au moment
//                       du prelevement -- chemin de repli qui existe deja et qui est deja teste.
//                       Fonctionne a l'identique pour un proprietaire organisation ('orga:<id>'),
//                       la RPC lisant la meme reference typee du Lot 1.0 bis. Aucun format
//                       persistant nouveau, aucune migration : les baux existants qui portent
//                       encore un `titulaire` restent lus en priorite par la RPC.
//   'caisse_batiment'-> caisse institutionnelle du batiment. Uniquement le box portuaire, seul
//                       bail dont le loyer alimente deja reellement une caisse (celle du port) --
//                       valeur ajoutee pour DECRIRE l'existant, pas pour le changer.
// Un bail sans loyer reel (chambre de clinique, prix 0) n'a pas de destination : null.
function destinationLoyerPourLocal(buildingId, roomId, city, country, options) {
  const opt = options || {};
  if (opt.chambreClinique) return null;
  if (opt.isBox) return { type: 'caisse_batiment', buildingId: buildingId };
  if (estPieceDynamiqueLot(roomId)) return { type: 'titulaire_murs' };
  return { type: 'municipal', pays: country || 'republic', ville: city || 'capitale' };
}

function destinationLoyerDuBail(bail) {
  if (!bail) return null;
  if (bail.destinationLoyer && bail.destinationLoyer.type) return bail.destinationLoyer;
  return destinationLoyerPourLocal(bail.buildingId, bail.roomId, bail.city, bail.country,
    { isBox: bail.isBox === true, chambreClinique: bail.chambreClinique === true });
}

// DOMICILIATION. Decision metier : un appartement prive peut heberger le siege d'une
// organisation, un logement social ne le peut pas. La source de verite reste la definition
// statique de la piece (locationData.orgaAutorisee), deja utilisee par ouvrirModalGererLocal --
// le bail ne fait que la porter, jamais l'inventer. Un lot est un local prive : autorise.
function orgaAutoriseePourLocal(buildingId, roomId) {
  if (estPieceDynamiqueLot(roomId)) return true;
  const room = (typeof BUILDINGS !== 'undefined' && BUILDINGS[buildingId] && BUILDINGS[buildingId].rooms)
    ? BUILDINGS[buildingId].rooms[roomId] : null;
  return !(room && room.locationData && room.locationData.orgaAutorisee === false);
}

function orgaAutoriseeDuBail(bail) {
  if (!bail) return false;
  if (typeof bail.orgaAutorisee === 'boolean') return bail.orgaAutorisee;
  return orgaAutoriseePourLocal(bail.buildingId, bail.roomId);
}

// RESOLVEUR UNIQUE. Tous les consommateurs passent par ici : il n'existe plus qu'un seul chemin
// pour repondre a "ce local est-il loue, et par qui ?".
//
// L'adaptateur legacy ci-dessous n'est PAS une deuxieme verite active : c'est une vue en lecture
// seule d'un lot historique encore porteur d'un locataire mais pas encore de bail (cas
// aujourd'hui inexistant en production, conserve pour qu'aucun locataire ne puisse disparaitre si
// un lot etait loue entre ce lot et l'execution de la migration). Il disparait des que le bail
// existe, et le drapeau _legacy le rend identifiable partout.
function bailPourLocal(buildingId, roomId, city) {
  const ville = (city === undefined) ? (typeof state !== 'undefined' ? state.currentCity : null) : city;
  if (typeof getLocationPourRoom === 'function') {
    let bail = null;
    try { bail = getLocationPourRoom(buildingId, roomId, ville); } catch (e) { bail = null; }
    if (bail) return bail;
  }
  if (!estPieceDynamiqueLot(roomId)) return null;
  const lotId = lotIdDepuisRoomId(roomId);
  const lot = lotsDuTerrain(buildingId).find(function (l) { return roomIdDepuisLot(l.id) === roomId || l.id === lotId; });
  if (!lot || !lot.locataire) return null;
  return {
    buildingId: buildingId, roomId: roomId, city: ville,
    country: (typeof state !== 'undefined' ? state.country : 'republic'),
    localKey: localKeyDe(typeof state !== 'undefined' ? state.country : 'republic', ville, buildingId, roomId),
    lotId: lot.id, locataire: lot.locataire, prix: lot.loyer || 0,
    localLabel: lot.label || 'Lot', orgaId: '',
    _legacy: true
  };
}

// Un lot est-il loue ? Question posee partout dans l'UI de division/location. Passe par le
// resolveur unique, donc le bail fait foi et le champ subdivision.locataire n'est plus consulte
// comme verite (il ne sert plus que d'entree a l'adaptateur legacy ci-dessus).
function lotEstLoue(buildingId, lot) {
  if (!lot || !lot.id) return false;
  const roomId = roomIdDepuisLot(lot.id);
  return !!(roomId && bailPourLocal(buildingId, roomId));
}

function locataireDuLot(buildingId, lot) {
  if (!lot || !lot.id) return null;
  const roomId = roomIdDepuisLot(lot.id);
  const bail = roomId ? bailPourLocal(buildingId, roomId) : null;
  return bail ? (bail.locataire || null) : null;
}

// Construit l'entree de bail canonique. Meme forme que celle de confirmerLocation (schema
// historique integralement conserve : prix, bonus*, orgaId, depuis, visible...), plus les trois
// champs du modele unifie.
function construireBailLot(buildingId, lot, city, country) {
  const roomId = roomIdDepuisLot(lot.id);
  const ville = city || (typeof state !== 'undefined' ? state.currentCity : 'capitale');
  const pays = country || (typeof state !== 'undefined' ? state.country : 'republic');
  return {
    buildingId: buildingId, roomId: roomId, city: ville, country: pays,
    localKey: localKeyDe(pays, ville, buildingId, roomId),
    lotId: lot.id,
    localLabel: lot.label || 'Lot',
    batimentLabel: (typeof BUILDINGS !== 'undefined' && BUILDINGS[buildingId])
      ? (BUILDINGS[buildingId].shortName || BUILDINGS[buildingId].name || buildingId) : buildingId,
    prix: lot.loyer || 0,
    bonusPOP: 0, bonusINF: 0, bonusDIS: 0,
    orgaId: '',
    orgaAutorisee: orgaAutoriseePourLocal(buildingId, roomId),
    destinationLoyer: destinationLoyerPourLocal(buildingId, roomId, ville, pays, {}),
    locataire: (typeof state !== 'undefined' ? state.char && state.char.name : null),
    depuis: (typeof state !== 'undefined' ? state.day : 1) || 1,
    visible: true
  };
}

// Libere le miroir subdivision.locataire quand un bail de lot prend fin (resiliation volontaire
// ou expulsion pour impaye). Sans cela, le cron continuerait a prelever un loyer sur un bail
// resilie et le proprietaire des murs verrait son lot eternellement "occupe" -- exactement le
// locataire fantome que ce lot doit rendre impossible. No-op pour un bail de piece statique.
function libererMiroirLot(bail) {
  if (!bail || !estPieceDynamiqueLot(bail.roomId)) return false;
  if (typeof getTerrainState !== 'function' || typeof setTerrainState !== 'function') return false;
  const buildingId = bail.buildingId;
  let ts = null;
  try { ts = getTerrainState(buildingId); } catch (e) { return false; }
  const subdivisions = (ts && Array.isArray(ts.subdivisions)) ? ts.subdivisions : [];
  const lotId = bail.lotId || lotIdDepuisRoomId(bail.roomId);
  const lot = subdivisions.find(function (l) { return l && (l.id === lotId || roomIdDepuisLot(l.id) === bail.roomId); });
  if (!lot || !lot.locataire) return false;
  lot.locataire = null;
  const nouvelEtat = setTerrainState(buildingId, { subdivisions: subdivisions });
  if (typeof sbSetTerrainState === 'function') {
    sbSetTerrainState(bail.country || (typeof state !== 'undefined' ? state.country : 'republic'), buildingId, nouvelEtat).catch(function () {});
  }
  return true;
}

// Supprime le bail attache a un lot que l'on s'apprete a retirer. Garantit l'invariant "jamais de
// bail actif sans local" -- symetrique de libererMiroirLot, qui garantit "jamais de local occupe
// sans bail".
async function supprimerBailDuLot(buildingId, lot) {
  if (!lot || !lot.id) return false;
  const roomId = roomIdDepuisLot(lot.id);
  if (!roomId) return false;
  const bail = bailPourLocal(buildingId, roomId);
  if (!bail || bail._legacy) return false;
  if (typeof state !== 'undefined' && Array.isArray(state.locationsActives)) {
    const idx = state.locationsActives.indexOf(bail);
    if (idx > -1) state.locationsActives.splice(idx, 1);
  }
  if (typeof sbSupprimerLocation === 'function') {
    await sbSupprimerLocation(bail.country || (typeof state !== 'undefined' ? state.country : 'republic'),
      bail.buildingId, bail.roomId, bail.city).catch(function () {});
  }
  return true;
}
