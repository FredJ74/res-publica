/* Calcule, pour CHAQUE piece de CHAQUE ville de CHAQUE empire, l'image de fond
   que enterRoom() finirait par poser. Deux modes :
     avant  -> chaine historique, sans moteur de variantes
     apres  -> chaine actuelle, moteur compris
   La sortie est comparee par resolution_diff.sh : tout ecart non voulu est une
   regression graphique. */
var MODE = arguments[0];
load(MODE === 'avant' ? '.scratch/avant/data.js' : 'data.js');

var state = { country: 'republic', currentCity: 'capitale' };
/* En mode 'occupe', TOUTE piece du jeu est reputee louee : c'est le controle le
   plus severe, celui qui montre si une regle d'etat deborde sur une piece qui ne
   la declare pas. */
var TOUT_LOUE = (MODE === 'occupe');
function getLocationPourRoom(b, r, c) {
  return TOUT_LOUE ? { buildingId: b, roomId: r, city: c, fondsId: 'f' } : undefined;
}
function fondsEstActif() { return true; }
if (MODE !== 'avant') load('plateau-variantes-pieces.js');

var sortie = {};
Object.keys(WORLD).forEach(function (pays) {
  Object.keys(WORLD[pays]).forEach(function (ville) {
    var v = WORLD[pays][ville];
    if (!v || !v.buildings) return;
    state.country = pays; state.currentCity = ville;
    v.buildings.forEach(function (bat) {
      var b = BUILDINGS[bat]; if (!b) return;
      var ctx = v.buildingContext && v.buildingContext[bat];
      var pieces = Object.assign({}, b.rooms || {}, (ctx && ctx.roomsExtra) || {});
      Object.keys(pieces).forEach(function (piece) {
        var room = pieces[piece];
        var ro = ctx && ctx.roomOverrides && ctx.roomOverrides[piece];
        var emp = ROOM_IMAGES_EMPIRE[pays] && ROOM_IMAGES_EMPIRE[pays][bat]
                  && ROOM_IMAGES_EMPIRE[pays][bat][piece];
        var varImg = (MODE !== 'avant' && typeof varianteImagePiece === 'function')
          ? varianteImagePiece(bat, piece, ville) : null;
        var url = varImg || (ro && ro.imageUrl) || emp || room.imageUrl || null;
        var anc = (MODE !== 'avant' && typeof varianteAncragePiece === 'function')
          ? varianteAncragePiece(bat, piece, ville) : null;

        // Nom et description, resolus comme enterRoom le fait.
        var nomBase = (ro && ro.name) || room.name || '';
        var nom = (MODE !== 'avant' && typeof varianteNomPiece === 'function')
          ? (varianteNomPiece(bat, piece, ville, nomBase) || nomBase) : nomBase;
        var descBase = (ro && ro.desc) || room.desc || '';
        var desc = (MODE !== 'avant' && typeof varianteDescPiece === 'function')
          ? (varianteDescPiece(bat, piece, ville, descBase) || descBase) : descBase;

        sortie[pays + '/' + ville + '/' + bat + '/' + piece] = {
          fond: (anc ? '[' + anc + '] ' : '') + url,
          nom: nom,
          desc: desc
        };
      });
    });
  });
});
print(JSON.stringify(sortie, null, 1));
