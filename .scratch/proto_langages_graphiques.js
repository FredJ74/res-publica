// =====================================================================
// PROTOTYPE — QUATRE LANGAGES GRAPHIQUES POUR LE PLAN DE LUTHECIA
// =====================================================================
//
// Ce fichier NE FAIT PARTIE DU JEU D'AUCUNE MANIERE. Il lit la geometrie reelle du plan
// (PLAN_VILLES, PLAN_TERRAIN_STYLES, BUILDINGS, WORLD) et en produit quatre rendus differents,
// pour comparaison. Aucune coordonnee, aucune emprise, aucune rue n'est modifiee : les quatre
// variantes partagent exactement le meme viewBox et les memes rectangles au sol.
//
//   A — le plan actuel, rendu par le moteur lui-meme, inchange.
//   B — symboles plats : une silhouette geometrique et une couleur de famille, sans texture.
//   C — identique a B, avec une ombre portee uniforme tres discrete.
//   D — vue legerement plongeante : l'emprise au sol reste le rectangle d'origine, un toit est
//       dessine au-dessus et une facade sud relie les deux. Aucune perspective, aucune rotation.
//
// Les sept familles ci-dessous regroupent les 26 categories du jeu : 26 couleurs seraient
// illisibles, sept se distinguent d'un coup d'oeil. C'est une proposition de prototype, pas
// une donnee de jeu.

var FAMILLES = {
  pouvoir:   { nom:'Pouvoir',               couleur:'#9E3B30', forme:'fronton',
               batiments:['palais-presidentiel','palais-gouvernement','assemblee','tribunal','mairie-capitale'] },
  ordre:     { nom:'Ordre',                 couleur:'#3C6E8F', forme:'ecusson',
               batiments:['commissariat','armurerie'] },
  argent:    { nom:'Argent',                couleur:'#4F7A3A', forme:'cercle',
               batiments:['banque-nationale','banque-privee','centre-affaires','office-notarial','tabernacle-impots'] },
  savoir:    { nom:'Savoir & soin',         couleur:'#3E8A86', forme:'croix',
               batiments:['universite','dispensaire-public','clinique-privee','musee-ville-luthecia',
                          'musee-national-republia','la-tribune'] },
  commerce:  { nom:'Commerce & industrie',  couleur:'#B9762B', forme:'carre',
               batiments:['marche','centre-commercial','centre-artisanal','usine-pharmaceutique-luthecia',
                          'entrepot-logistique-luthecia','centre-multinodal-luthecia','bureau-national-emploi'] },
  publique:  { nom:'Vie publique',          couleur:'#7A5392', forme:'losange',
               batiments:['hotel-republica','stade','parc-botanique-national','place-formulaire-liberte',
                          'loge-maconnique','quartier-ambassades'] },
  terrain:   { nom:'Terrain libre',         couleur:'#4A4639', forme:'aucune',
               batiments:['terrain-a-batir-1','terrain-a-batir-2','terrain-a-batir-3',
                          'terrain-a-batir-4','terrain-a-batir-5'] }
};

// Elevation en pixels par famille, pour la seule variante D. Les batiments de pouvoir dominent
// la ville, les terrains libres sont au ras du sol.
var ELEVATION = { pouvoir:13, ordre:10, argent:11, savoir:10, commerce:9, publique:8, terrain:2 };

var FAMILLE_DE = {};
Object.keys(FAMILLES).forEach(function (f) {
  FAMILLES[f].batiments.forEach(function (b) { FAMILLE_DE[b] = f; });
});

// ---------------------------------------------------------------------------
// Outils
// ---------------------------------------------------------------------------
function eclaircir(hex, k) {
  var r = parseInt(hex.substr(1, 2), 16), v = parseInt(hex.substr(3, 2), 16), b = parseInt(hex.substr(5, 2), 16);
  function m(c) { return Math.min(255, Math.round(c + (255 - c) * k)); }
  function h(c) { return ('0' + m(c).toString(16)).slice(-2); }
  return '#' + h(r) + h(v) + h(b);
}
function assombrir(hex, k) {
  var r = parseInt(hex.substr(1, 2), 16), v = parseInt(hex.substr(3, 2), 16), b = parseInt(hex.substr(5, 2), 16);
  function h(c) { return ('0' + Math.round(c * (1 - k)).toString(16)).slice(-2); }
  return '#' + h(r) + h(v) + h(b);
}

// La silhouette, dessinee au centre du batiment, taille proportionnee a son emprise.
function silhouette(forme, cx, cy, t, couleur) {
  var c = ' fill="' + couleur + '"';
  switch (forme) {
    case 'fronton':
      return '<path d="M' + (cx - t) + ' ' + (cy + t * 0.55) + ' L' + cx + ' ' + (cy - t * 0.75) +
             ' L' + (cx + t) + ' ' + (cy + t * 0.55) + ' Z"' + c + '/>' +
             '<rect x="' + (cx - t * 0.8) + '" y="' + (cy + t * 0.55) + '" width="' + (t * 1.6) + '" height="' + (t * 0.35) + '"' + c + '/>';
    case 'ecusson':
      return '<path d="M' + cx + ' ' + (cy - t) + ' L' + (cx + t * 0.85) + ' ' + (cy - t * 0.45) +
             ' L' + (cx + t * 0.6) + ' ' + (cy + t * 0.9) + ' L' + cx + ' ' + (cy + t) +
             ' L' + (cx - t * 0.6) + ' ' + (cy + t * 0.9) + ' L' + (cx - t * 0.85) + ' ' + (cy - t * 0.45) + ' Z"' + c + '/>';
    case 'cercle':
      return '<circle cx="' + cx + '" cy="' + cy + '" r="' + (t * 0.85) + '"' + c + '/>';
    case 'croix':
      return '<path d="M' + (cx - t * 0.3) + ' ' + (cy - t) + ' h' + (t * 0.6) + ' v' + (t * 0.7) +
             ' h' + (t * 0.7) + ' v' + (t * 0.6) + ' h' + (-t * 0.7) + ' v' + (t * 0.7) +
             ' h' + (-t * 0.6) + ' v' + (-t * 0.7) + ' h' + (-t * 0.7) + ' v' + (-t * 0.6) +
             ' h' + (t * 0.7) + ' Z"' + c + '/>';
    case 'carre':
      return '<rect x="' + (cx - t * 0.8) + '" y="' + (cy - t * 0.8) + '" width="' + (t * 1.6) + '" height="' + (t * 1.6) + '"' + c + '/>';
    case 'losange':
      return '<path d="M' + cx + ' ' + (cy - t) + ' L' + (cx + t) + ' ' + cy +
             ' L' + cx + ' ' + (cy + t) + ' L' + (cx - t) + ' ' + cy + ' Z"' + c + '/>';
    default:
      return '';
  }
}

// ---------------------------------------------------------------------------
// Le rendu commun aux variantes B, C et D : meme geometrie que le moteur, lue chez lui.
// ---------------------------------------------------------------------------
function rendreVariante(mode) {
  var plan = PLAN_VILLES.republic.capitale;
  var ville = WORLD.republic.capitale;
  var layout = planLayoutDepuisGrille(plan);
  var ici = 'mairie-capitale';

  // Cadre : exactement celui du moteur.
  var pos = ville.buildings.map(function (id) { return layout[id]; }).filter(Boolean);
  var maxX = Math.max.apply(null, pos.map(function (p) { return p[0] + p[2]; }));
  var maxY = Math.max.apply(null, pos.map(function (p) { return p[1] + p[3]; }));
  var W = Math.max(952, Math.ceil(maxX) + 20), H = Math.max(840, Math.ceil(maxY) + 34);

  var s = '<svg viewBox="0 0 ' + W + ' ' + H + '" xmlns="http://www.w3.org/2000/svg" style="width:100%;height:auto;display:block">';
  if (mode === 'C') {
    s += '<defs><filter id="ombre" x="-30%" y="-30%" width="170%" height="170%">' +
         '<feDropShadow dx="0" dy="1.6" stdDeviation="1.4" flood-color="#000" flood-opacity="0.55"/>' +
         '</filter></defs>';
  }
  s += '<rect width="' + W + '" height="' + H + '" fill="#111008"/>';
  s += '<rect x="' + plan.cadre.x + '" y="' + plan.cadre.y + '" width="' + plan.cadre.largeur +
       '" height="' + plan.cadre.hauteur + '" rx="8" fill="none" stroke="#3a3418" stroke-width="2"/>';
  s += planSvgTerrain(plan);   // les rues, inchangees, lues chez le moteur

  // Du nord au sud : en variante D, un batiment plus au sud recouvre son voisin du nord.
  var ids = ville.buildings.filter(function (id) { return layout[id]; })
    .sort(function (a, b) { return (layout[a][1] + layout[a][3]) - (layout[b][1] + layout[b][3]); });

  ids.forEach(function (id) {
    var p = layout[id], x = p[0], y = p[1], w = p[2], h = p[3];
    var fam = FAMILLE_DE[id] || 'terrain';
    var F = FAMILLES[fam];
    var estIci = (id === ici);
    var cx = x + w / 2;
    var t = Math.max(3.2, Math.min(w, h) * 0.26);

    s += '<g>';
    if (mode === 'D') {
      var e = ELEVATION[fam];
      // L'EMPRISE AU SOL NE BOUGE PAS : elle reste le rectangle d'origine. Le toit est cette
      // meme emprise remontee de `e`, et la facade sud relie les deux. Aucune rotation.
      s += '<rect x="' + x + '" y="' + y + '" width="' + w + '" height="' + h + '" rx="2" fill="' +
           assombrir(F.couleur, 0.62) + '"/>';
      s += '<rect x="' + x + '" y="' + (y + h - e) + '" width="' + w + '" height="' + e + '" fill="' +
           assombrir(F.couleur, 0.45) + '"/>';
      s += '<rect x="' + x + '" y="' + (y - e) + '" width="' + w + '" height="' + h + '" rx="2" fill="' +
           F.couleur + '" stroke="' + (estIci ? '#ffffff' : eclaircir(F.couleur, 0.22)) +
           '" stroke-width="' + (estIci ? 2 : 0.8) + '"/>';
      s += silhouette(F.forme, cx, y - e + h / 2, t, eclaircir(F.couleur, 0.55));
    } else {
      var filtre = (mode === 'C') ? ' filter="url(#ombre)"' : '';
      var pointille = (fam === 'terrain') ? ' stroke-dasharray="4,3"' : '';
      s += '<rect x="' + x + '" y="' + y + '" width="' + w + '" height="' + h + '" rx="2"' + filtre +
           ' fill="' + F.couleur + '" stroke="' + (estIci ? '#ffffff' : eclaircir(F.couleur, 0.25)) +
           '" stroke-width="' + (estIci ? 2 : 0.8) + '"' + pointille + '/>';
      s += silhouette(F.forme, cx, y + h * 0.42, t, eclaircir(F.couleur, 0.55));
    }
    s += '</g>';
  });

  // Les noms, identiques au moteur : meme police, meme taille, meme troncature, meme position.
  ids.forEach(function (id) {
    var p = layout[id], x = p[0], y = p[1], w = p[2], h = p[3];
    var b = BUILDINGS[id] || {};
    var ctx = ville.buildingContext && ville.buildingContext[id];
    var nom = (ctx && ctx.name) || b.shortName || b.name || id;
    var aff = (nom.length > 14 && w < 100) ? nom.substring(0, 13) + '…' : nom;
    s += '<text x="' + (x + w / 2) + '" y="' + (y + h - 10) + '" text-anchor="middle" font-size="8" ' +
         'fill="#efe6cf" font-family="sans-serif" ' +
         'style="paint-order:stroke;stroke:#111008;stroke-width:2.4;stroke-linejoin:round">' + aff + '</text>';
  });

  // Le point rouge « vous etes ici », aux memes coordonnees que le moteur.
  var pi = layout[ici];
  var pcx = pi[0] + pi[2] - 8, pcy = pi[1] + 8;
  s += '<circle cx="' + pcx + '" cy="' + pcy + '" r="9" fill="#cc2020" opacity="0.25"/>';
  s += '<circle cx="' + pcx + '" cy="' + pcy + '" r="5" fill="#ff3333" stroke="#fff" stroke-width="1.2"/>';

  s += '<text x="' + (W / 2) + '" y="' + (H - 10) + '" text-anchor="middle" font-size="8" fill="#3a3520" ' +
       'font-family="sans-serif" letter-spacing="2">LUTHECIA — REPUBLIA</text>';
  s += '<circle cx="16" cy="' + (H - 5) + '" r="4" fill="#ff3333"/>';
  s += '<text x="26" y="' + (H - 1) + '" font-size="7.5" fill="#8a6a6a" font-family="sans-serif">Vous êtes ici</text>';
  s += '</svg>';
  return s;
}

// ---------------------------------------------------------------------------
// Sortie : A par le moteur lui-meme, B / C / D par le rendu ci-dessus.
// ---------------------------------------------------------------------------
Object.keys(PLAN_ILLUSTRATIONS).forEach(function (k) { delete PLAN_ILLUSTRATIONS[k]; });
state.country = 'republic'; state.currentCity = 'capitale'; state.currentBuilding = 'mairie-capitale';
ouvrirPlanVille('republic', 'capitale', true);
var A = document.getElementById('minimap-ville-body').innerHTML;
A = A.substring(A.indexOf('<svg'), A.lastIndexOf('</svg>') + 6);

print('__A__' + A);
print('__B__' + rendreVariante('B'));
print('__C__' + rendreVariante('C'));
print('__D__' + rendreVariante('D'));
print('__LEGENDE__' + JSON.stringify(Object.keys(FAMILLES).map(function (f) {
  return { nom: FAMILLES[f].nom, couleur: FAMILLES[f].couleur, forme: FAMILLES[f].forme,
           n: FAMILLES[f].batiments.length };
})));
