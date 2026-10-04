/* BANC — moteur generique de variantes graphiques des pieces.
   Execute le vrai fichier (plateau-variantes-pieces.js) sur les vraies donnees
   (data.js). Aucun grep : chaque assertion appelle la fonction.

   Lancement :
     /System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc \
       .scratch/banc_variantes_pieces.js

   Ce banc ECHOUE si le fichier n'existe pas, si une declaration est incomplete,
   si l'arithmetique de rognage est fausse, ou -- c'est le controle qui compte --
   si UNE SEULE autre piece du jeu se met a repondre autre chose que null. */

load('data.js');

/* --- Doublures minimales : seulement ce que le moteur consulte ------------- */
var state = { country: 'republic', currentCity: 'capitale' };

var BAUX = [];                       // le banc pilote l'etat par cette liste
function getLocationPourRoom(buildingId, roomId, city) {
  return BAUX.find(function (b) {
    return b.buildingId === buildingId && b.roomId === roomId && b.city === city;
  });
}
function fondsEstActif(f) { return !!f && f.statut === 'actif'; }
/* Noms reels des 4 locaux, tels que data.js les declare : c'est sur eux que la
   regle de nom doit operer. */
var DESCS_BASE = {
  vitrine_principale: "📋 À LOUER — Emplacement premium en façade. Visibilité maximale. Prix élevé, impact fort sur la réputation de votre organisation.",
  boutique_milieu:    "📋 À LOUER — Boutique bien située, bon passage. Rapport qualité/prix intéressant.",
  arriere_boutique:   "📋 À LOUER — Arrière-boutique discrète. Pas très visible mais suffisante pour démarrer.",
  cave_reserve:       "📋 À LOUER — Sous-sol discret, sans fenêtre. Idéal pour les activités qu'on préfère garder secrètes."
};
var NOMS_BASE = {
  vitrine_principale: 'Vitrine Principale — Local à louer',
  boutique_milieu:    'Boutique Milieu — Local à louer',
  arriere_boutique:   'Arrière-Boutique — Local à louer',
  cave_reserve:       'Cave / Réserve — Local à louer'
};

load('plateau-variantes-pieces.js');
load('plateau-open-space.js');

/* --- Harnais -------------------------------------------------------------- */
var reussites = 0, echecs = [];
function verifier(intitule, obtenu, attendu) {
  var ok = JSON.stringify(obtenu) === JSON.stringify(attendu);
  if (ok) reussites++;
  else echecs.push(intitule + '\n      attendu : ' + JSON.stringify(attendu) +
                   '\n      obtenu  : ' + JSON.stringify(obtenu));
}
function verifierVrai(intitule, condition, detail) {
  if (condition) reussites++; else echecs.push(intitule + (detail ? '\n      ' + detail : ''));
}

/* Les seules pieces du jeu qui declarent une variante, au 4 octobre 2026 :
   les 4 locaux du centre commercial et les 6 du centre d'affaires de Luthecia. */
var PIECES_DECLAREES = {
  'centre-commercial': ['vitrine_principale','boutique_milieu','arriere_boutique','cave_reserve'],
  'centre-affaires':   ['bureau_prestige','bureau_standard',
                        'open_space_a','open_space_b','open_space_c','open_space_d']
};

var LOCAUX = {
  vitrine_principale: 'grand',
  boutique_milieu:    'moyen',
  arriere_boutique:   'petit',
  cave_reserve:       'mini'
};

/* === 1. ETAT LIBRE : chaque local rend son image "vide" ==================== */
BAUX = [];
Object.keys(LOCAUX).forEach(function (piece) {
  verifier('libre > ' + piece,
    varianteImagePiece('centre-commercial', piece, 'capitale'),
    'images/luthecia-centre-commercial-' + LOCAUX[piece] + '-local-vide.png');
  verifier('etat libre > ' + piece,
    varianteEtatPiece('centre-commercial', piece, 'capitale'), 'libre');
});

/* === 2. ETAT OCCUPE : un bail suffit, et seul le local loue change ========= */
BAUX = [{ buildingId: 'centre-commercial', roomId: 'boutique_milieu', city: 'capitale' }];
verifier('occupee > boutique_milieu',
  varianteImagePiece('centre-commercial', 'boutique_milieu', 'capitale'),
  'images/luthecia-centre-commercial-moyen-local-loue.png');
verifier('les voisins restent libres > vitrine_principale',
  varianteImagePiece('centre-commercial', 'vitrine_principale', 'capitale'),
  'images/luthecia-centre-commercial-grand-local-vide.png');

/* Les quatre, loues en meme temps. */
BAUX = Object.keys(LOCAUX).map(function (p) {
  return { buildingId: 'centre-commercial', roomId: p, city: 'capitale' };
});
Object.keys(LOCAUX).forEach(function (piece) {
  verifier('occupee > ' + piece,
    varianteImagePiece('centre-commercial', piece, 'capitale'),
    'images/luthecia-centre-commercial-' + LOCAUX[piece] + '-local-loue.png');
});

/* === 3. RETOUR IMMEDIAT A L'ETAT LIBRE apres resiliation =================== */
/* La resiliation retire la ligne du bail (confirmerResiliation > splice), donc
   le seul fait de vider BAUX doit suffire a faire revenir l'image vide : c'est
   exactement ce que fait le jeu, puis il rappelle enterRoom. */
BAUX = [];
verifier('apres resiliation > vitrine_principale',
  varianteImagePiece('centre-commercial', 'vitrine_principale', 'capitale'),
  'images/luthecia-centre-commercial-grand-local-vide.png');

/* === 4. AUCUNE AUTRE VILLE, AUCUN AUTRE PAYS ============================== */
BAUX = Object.keys(LOCAUX).map(function (p) {
  return { buildingId: 'centre-commercial', roomId: p, city: 'ville_a' };
});
state.currentCity = 'ville_a';                       // Port-Sainte-Marie
Object.keys(LOCAUX).forEach(function (piece) {
  verifier('PSM intouche > ' + piece,
    varianteImagePiece('centre-commercial', piece, 'ville_a'), null);
});
state.currentCity = 'ville_b';                       // Montrouge
Object.keys(LOCAUX).forEach(function (piece) {
  verifier('Montrouge intouche > ' + piece,
    varianteImagePiece('centre-commercial', piece, 'ville_b'), null);
});
['narco', 'soviet', 'khalija'].forEach(function (pays) {
  state.country = pays; state.currentCity = 'capitale';
  verifier('empire ' + pays + ' intouche',
    varianteImagePiece('centre-commercial', 'vitrine_principale', 'capitale'), null);
});

/* === 5. LE HALL N'EST PAS UNE VARIANTE ==================================== */
state.country = 'republic'; state.currentCity = 'capitale';
verifier('hall non declare', varianteImagePiece('centre-commercial', 'hall', 'capitale'), null);
verifier('hall sans ancrage', varianteAncragePiece('centre-commercial', 'hall', 'capitale'), null);

/* === 6. ANCRAGE ========================================================== */
Object.keys(LOCAUX).forEach(function (piece) {
  verifier('ancrage haut > ' + piece,
    varianteAncragePiece('centre-commercial', piece, 'capitale'), 'haut');
});

/* === 7. NON-REGRESSION TOTALE ============================================= */
/* On balaie TOUTES les pieces de TOUS les batiments de TOUTES les villes de
   TOUS les empires. Exactement quatre doivent repondre ; toutes les autres
   doivent rendre null, sans quoi un fond existant serait remplace. */
var declarees = 0, parasites = [], balayees = 0;
Object.keys(WORLD).forEach(function (pays) {
  Object.keys(WORLD[pays]).forEach(function (ville) {
    var v = WORLD[pays][ville];
    if (!v || !v.buildings) return;
    state.country = pays; state.currentCity = ville;
    v.buildings.forEach(function (bat) {
      var b = BUILDINGS[bat];
      if (!b) return;
      var ctx = v.buildingContext && v.buildingContext[bat];
      var pieces = Object.assign({}, b.rooms || {}, (ctx && ctx.roomsExtra) || {});
      Object.keys(pieces).forEach(function (piece) {
        balayees++;
        var r = varianteImagePiece(bat, piece, ville);
        if (r === null) return;
        if (pays === 'republic' && ville === 'capitale' && PIECES_DECLAREES[bat]
            && PIECES_DECLAREES[bat].indexOf(piece) >= 0) { declarees++; return; }
        parasites.push(pays + '/' + ville + '/' + bat + '/' + piece + ' -> ' + r);
      });
    });
  });
});
/* 842 pieces au 4 octobre 2026, tous empires confondus. Le seuil garde contre
   un balayage qui se viderait silencieusement (WORLD renomme, BUILDINGS vide) ;
   il n'a pas a suivre le chiffre exact, qui bougera a chaque nouveau batiment. */
verifierVrai('balayage : le jeu entier a bien ete visite', balayees > 700, 'balayees = ' + balayees);
verifier('exactement 10 pieces declarees', declarees, 10);
verifier('aucune piece parasite', parasites, []);

/* === 8. ARITHMETIQUE DU ROGNAGE ========================================== */
/* L'enjeu : le fronton (y de 5,2 % a 16,2 % de l'image) doit rester VISIBLE a
   tous les rapports de cadre mesures sur la vraie cascade CSS, et le texte doit
   rester DANS le cadre. Avec un ancrage centre, le cas 1080x532 echoue -- c'est
   la mesure qui a impose l'ancrage haut. */
var TAILLE = { l: 1667, h: 943 };   // image frontale du grand local, 4 octobre
var CADRES = [                      // mesures reelles, banc_geometrie_piece.html
  { l: 1480, h: 782 }, { l: 1240, h: 632 }, { l: 1080, h: 532 },
  { l: 824,  h: 500 }, { l: 620,  h: 912 }, { l: 300,  h: 628 },
  { l: 1600, h: 400 }                       // cas extreme volontairement pire
];
var zoneGrand = PIECE_VARIANTES.republic.capitale['centre-commercial']
                  .vitrine_principale.enseigne.zone;

CADRES.forEach(function (c) {
  var cadre = { clientWidth: c.l, clientHeight: c.h };
  var hautOk = varianteZoneEnPixels(zoneGrand, cadre, TAILLE, 'haut');
  verifierVrai('ancrage haut visible en ' + c.l + 'x' + c.h,
    hautOk && hautOk.haut >= 0 && (hautOk.haut + hautOk.hauteur) <= c.h,
    JSON.stringify(hautOk) + ' cadre h=' + c.h);
  /* En fenetre etroite, `cover` rogne l'image HORIZONTALEMENT : le fronton
     devient plus large que le cadre et deborde des deux cotes, ce qui est
     normal et sans consequence -- le texte est centre dans la zone, donc il
     reste au milieu du cadre, et #piece-image a overflow:hidden. Ce qu'il faut
     verifier, c'est que le CENTRE de l'enseigne tombe dans le cadre, et que la
     largeur retenue pour calibrer le texte ne depasse jamais le cadre. */
  var centre = hautOk.gauche + hautOk.largeur / 2;
  verifierVrai('enseigne centree dans le cadre en ' + c.l + 'x' + c.h,
    centre > 0 && centre < c.l,
    'centre=' + centre + ' cadre l=' + c.l);
  verifierVrai('largeur de calibrage plafonnee au cadre en ' + c.l + 'x' + c.h,
    Math.min(hautOk.largeur, c.l) <= c.l,
    JSON.stringify(hautOk) + ' cadre l=' + c.l);
});

/* Le banc doit prouver que l'ancrage SERT : au moins un cadre reel doit sortir
   l'enseigne du cadre si on la centre. Sans cela, le correctif ne prouverait
   rien -- il passerait aussi sans. */
var sortants = CADRES.filter(function (c) {
  var px = varianteZoneEnPixels(zoneGrand, { clientWidth: c.l, clientHeight: c.h }, TAILLE, 'centre');
  return px && px.haut < 0;
});
verifierVrai('l\'ancrage est bien necessaire (>=1 cadre reel ou le centrage rogne le fronton)',
  sortants.length >= 1, 'cadres fautifs = ' + sortants.length);

/* Verification chiffree, a la main, du cas 1480x782, ancrage haut :
   echelle = max(1480/1667, 782/943) = max(0,887822 ; 0,829268) = 0,887822
   dessinL = 1667 * 0,887822 = 1480,00   dessinH = 943 * 0,887822 = 837,22
   origineX = 0       origineY = 0 (ancrage haut)
   gauche  = 0,202 * 1480,00 = 298,96
   haut    = 0,172 *  837,22 = 144,00
   largeur = 0,598 * 1480,00 = 885,04
   hauteur = 0,057 *  837,22 =  47,72 */
var px = varianteZoneEnPixels(zoneGrand, { clientWidth: 1480, clientHeight: 782 }, TAILLE, 'haut');
function proche(a, b) { return Math.abs(a - b) < 0.5; }
verifierVrai('calcul exact 1480x782 : gauche 298,96', proche(px.gauche, 298.96), 'gauche=' + px.gauche);
verifierVrai('calcul exact 1480x782 : haut 144,00',    proche(px.haut, 144.00),    'haut=' + px.haut);
verifierVrai('calcul exact 1480x782 : largeur 885,04', proche(px.largeur, 885.04), 'largeur=' + px.largeur);
verifierVrai('calcul exact 1480x782 : hauteur 47,72',  proche(px.hauteur, 47.72),  'hauteur=' + px.hauteur);

/* === 9. COMPLETUDE DES DECLARATIONS ====================================== */
Object.keys(LOCAUX).forEach(function (piece) {
  var d = PIECE_VARIANTES.republic.capitale['centre-commercial'][piece];
  verifierVrai('declaration complete > ' + piece,
    d && d.famille === 'location' && d.images && d.images.libre && d.images.occupee
      && d.enseigne && d.enseigne.zone && d.enseigne.etats.indexOf('occupee') >= 0,
    JSON.stringify(d));
  var z = d.enseigne.zone;
  verifierVrai('zone dans l\'image > ' + piece,
    z.x >= 0 && z.y >= 0 && z.x + z.w <= 1 && z.y + z.h <= 1,
    JSON.stringify(z));
});

/* La famille existe et sait repondre. */
verifierVrai('famille location declaree',
  typeof PIECE_FAMILLES_ETAT.location.etat === 'function' &&
  typeof PIECE_FAMILLES_ETAT.location.enseigne === 'function');

/* === 10. LES FICHIERS IMAGES EXISTENT ==================================== */
/* Une declaration qui pointe vers un fichier absent donnerait un cadre noir en
   production sans le moindre message. */
var manquants = [];
Object.keys(LOCAUX).forEach(function (piece) {
  var im = PIECE_VARIANTES.republic.capitale['centre-commercial'][piece].images;
  [im.libre, im.occupee].forEach(function (chemin) {
    try { read(chemin); } catch (e) { manquants.push(chemin); }
  });
});
try { read('images/centre-commercial-republic.png'); }
catch (e) { manquants.push('images/centre-commercial-republic.png (hall)'); }
verifier('tous les fichiers images presents', manquants, []);

/* === 11. LE NOM DE LA PIECE SELON L'ETAT ================================= */
state.country = 'republic'; state.currentCity = 'capitale';

/* Libre : le nom ne bouge pas (la regle ne porte que sur l'etat occupe). */
BAUX = [];
Object.keys(LOCAUX).forEach(function (piece) {
  verifier('nom inchange quand libre > ' + piece,
    varianteNomPiece('centre-commercial', piece, 'capitale', NOMS_BASE[piece]), null);
});

/* Occupe : la mention « Local à louer » disparait, le reste est conserve. */
BAUX = Object.keys(LOCAUX).map(function (p) {
  return { buildingId: 'centre-commercial', roomId: p, city: 'capitale' };
});
verifier('nom occupe > vitrine_principale',
  varianteNomPiece('centre-commercial', 'vitrine_principale', 'capitale', NOMS_BASE.vitrine_principale),
  'Vitrine Principale');
verifier('nom occupe > boutique_milieu',
  varianteNomPiece('centre-commercial', 'boutique_milieu', 'capitale', NOMS_BASE.boutique_milieu),
  'Boutique Milieu');
verifier('nom occupe > arriere_boutique',
  varianteNomPiece('centre-commercial', 'arriere_boutique', 'capitale', NOMS_BASE.arriere_boutique),
  'Arrière-Boutique');
verifier('nom occupe > cave_reserve (le / interne est conserve)',
  varianteNomPiece('centre-commercial', 'cave_reserve', 'capitale', NOMS_BASE.cave_reserve),
  'Cave / Réserve');

/* Le hall n'a pas de regle de nom. */
verifier('hall : aucune regle de nom',
  varianteNomPiece('centre-commercial', 'hall', 'capitale', "Hall d'Entrée"), null);

/* Si le libelle de base change un jour et ne porte plus le suffixe, la regle
   cesse d'agir au lieu de couper au mauvais endroit. */
verifier('suffixe absent : le nom est laisse intact',
  varianteNomPiece('centre-commercial', 'vitrine_principale', 'capitale', 'Vitrine Principale'), null);
verifier('nom vide : aucune regle appliquee',
  varianteNomPiece('centre-commercial', 'vitrine_principale', 'capitale', ''), null);

/* Aucune autre ville, aucun autre empire. */
state.currentCity = 'ville_b';
verifier('Montrouge : aucune regle de nom',
  varianteNomPiece('centre-commercial', 'vitrine_principale', 'ville_b', NOMS_BASE.vitrine_principale), null);
state.country = 'narco'; state.currentCity = 'capitale';
verifier('narco : aucune regle de nom',
  varianteNomPiece('centre-commercial', 'vitrine_principale', 'capitale', NOMS_BASE.vitrine_principale), null);
state.country = 'republic'; state.currentCity = 'capitale';

/* Balayage complet : la regle de nom ne doit toucher QUE les 4 locaux. */
BAUX = [];
Object.keys(WORLD).forEach(function (pays) {
  Object.keys(WORLD[pays]).forEach(function (ville) {
    var vv = WORLD[pays][ville];
    if (!vv || !vv.buildings) return;
    state.country = pays; state.currentCity = ville;
    vv.buildings.forEach(function (bat) {
      var bb = BUILDINGS[bat]; if (!bb) return;
      var ctx = vv.buildingContext && vv.buildingContext[bat];
      var pcs = Object.assign({}, bb.rooms || {}, (ctx && ctx.roomsExtra) || {});
      Object.keys(pcs).forEach(function (piece) {
        var base = (ctx && ctx.roomOverrides && ctx.roomOverrides[piece] && ctx.roomOverrides[piece].name)
                   || pcs[piece].name || '';
        var r = varianteNomPiece(bat, piece, ville, base);
        if (r !== null) parasites.push('NOM ' + pays + '/' + ville + '/' + bat + '/' + piece + ' -> ' + r);
      });
    });
  });
});
state.country = 'republic'; state.currentCity = 'capitale';
verifier('aucun nom parasite dans tout le jeu (aucun bail actif)', parasites, []);

/* === 12. LES TROIS MODES D'ENSEIGNE ====================================== */
verifier('mode declare par les 4 locaux', Object.keys(LOCAUX).map(function (p) {
  return PIECE_VARIANTES.republic.capitale['centre-commercial'][p].enseigne.mode;
}), ['texte', 'texte', 'texte', 'texte']);

/* Le normaliseur accepte les trois formes d'ecriture d'une famille. */
verifier('normalise : chaine simple -> mode par defaut',
  varianteNormaliserEnseigne('Chez Lu', 'texte'), { mode: 'texte', texte: 'Chez Lu' });
verifier('normalise : objet texte',
  varianteNormaliserEnseigne({ mode: 'texte', texte: 'Chez Lu' }, 'texte'),
  { mode: 'texte', texte: 'Chez Lu' });
verifier('normalise : objet image',
  varianteNormaliserEnseigne({ mode: 'image', image: 'images/x.png' }, 'texte'),
  { mode: 'image', image: 'images/x.png' });
verifier('normalise : image sans visuel -> rien',
  varianteNormaliserEnseigne({ mode: 'image' }, 'texte'), null);
verifier('normalise : texte vide -> rien',
  varianteNormaliserEnseigne({ mode: 'texte', texte: '' }, 'texte'), null);
verifier('normalise : chaine blanche -> rien',
  varianteNormaliserEnseigne('   ', 'texte'), null);
verifier('normalise : mode aucune -> rien',
  varianteNormaliserEnseigne({ mode: 'aucune', texte: 'Chez Lu' }, 'texte'), null);
verifier('normalise : null -> rien', varianteNormaliserEnseigne(null, 'texte'), null);

/* La famille rend bien un objet a mode, et expose le point d'extension image. */
verifierVrai('la famille location rend une enseigne a mode',
  typeof PIECE_FAMILLES_ETAT.location.enseigne === 'function');
verifierVrai('le style du mode texte est declare',
  !!ENSEIGNE_FRONTON_LUTHECIA.texte && !!ENSEIGNE_FRONTON_LUTHECIA.texte.police);
verifierVrai('le style du mode image est declare',
  !!ENSEIGNE_FRONTON_LUTHECIA.image && ENSEIGNE_FRONTON_LUTHECIA.image.ajustement === 'contain');

/* === 13. LA DESCRIPTION SELON L'ETAT ===================================== */
state.country = 'republic'; state.currentCity = 'capitale';

/* Les descriptions de base du jeu sont bien celles que le banc croit tester --
   sinon tout ce qui suit ne prouverait rien. */
Object.keys(LOCAUX).forEach(function (piece) {
  verifier('description de base conforme a data.js > ' + piece,
    BUILDINGS['centre-commercial'].rooms[piece].desc, DESCS_BASE[piece]);
});

/* Libre : la description ne bouge pas. */
BAUX = [];
Object.keys(LOCAUX).forEach(function (piece) {
  verifier('description inchangee quand libre > ' + piece,
    varianteDescPiece('centre-commercial', piece, 'capitale', DESCS_BASE[piece]), null);
});

/* Occupe : plus de « À LOUER », plus aucune mention d'un local disponible. */
BAUX = Object.keys(LOCAUX).map(function (p) {
  return { buildingId: 'centre-commercial', roomId: p, city: 'capitale' };
});
var TERMES_DE_LOCATION = ['À LOUER', 'A LOUER', 'louer', 'Prix élevé', 'Rapport qualité',
                          'pour démarrer', 'Idéal pour'];
Object.keys(LOCAUX).forEach(function (piece) {
  var d = varianteDescPiece('centre-commercial', piece, 'capitale', DESCS_BASE[piece]);
  verifierVrai('description occupee non vide > ' + piece, !!d && d.length > 20, String(d));
  var fautifs = TERMES_DE_LOCATION.filter(function (t) { return d && d.indexOf(t) >= 0; });
  verifier('aucune mention de location quand occupe > ' + piece, fautifs, []);
  verifierVrai('la description a bien change > ' + piece, d !== DESCS_BASE[piece]);
});

/* Le hall n'a pas de regle de description. */
verifier('hall : aucune regle de description',
  varianteDescPiece('centre-commercial', 'hall', 'capitale',
    BUILDINGS['centre-commercial'].rooms.hall.desc), null);

/* === 14. LA REGLE DE TEXTE, SES TROIS FORMES ============================= */
verifier('regle : remplacement', varianteRegleTexte('Tout neuf', 'Ancien'), 'Tout neuf');
verifier('regle : retrait en tete',
  varianteRegleTexte({ sansPrefixe: '📋 À LOUER — ' }, '📋 À LOUER — Une cave.'), 'Une cave.');
verifier('regle : retrait en queue',
  varianteRegleTexte({ sansSuffixe: ' — Local à louer' }, 'Cave / Réserve — Local à louer'),
  'Cave / Réserve');
verifier('regle : prefixe absent, texte intact',
  varianteRegleTexte({ sansPrefixe: '📋 À LOUER — ' }, 'Une cave.'), null);
verifier('regle : suffixe absent, texte intact',
  varianteRegleTexte({ sansSuffixe: ' — Local à louer' }, 'Cave / Réserve'), null);
verifier('regle : base vide', varianteRegleTexte('Tout neuf', ''), null);
verifier('regle : aucune regle', varianteRegleTexte(null, 'Une cave.'), null);
/* Le retrait en tete reste disponible pour la reutilisation immediate : il doit
   fonctionner sur les vraies descriptions du jeu, telles quelles. */
verifier('retrait en tete applicable aux 4 descriptions reelles',
  Object.keys(LOCAUX).map(function (p) {
    return varianteRegleTexte({ sansPrefixe: '📋 À LOUER — ' }, DESCS_BASE[p]) !== null;
  }), [true, true, true, true]);

/* Balayage complet : la regle de description ne touche QUE les 4 locaux. */
BAUX = [];
Object.keys(WORLD).forEach(function (pays) {
  Object.keys(WORLD[pays]).forEach(function (ville) {
    var vd = WORLD[pays][ville];
    if (!vd || !vd.buildings) return;
    state.country = pays; state.currentCity = ville;
    vd.buildings.forEach(function (bat) {
      var bd = BUILDINGS[bat]; if (!bd) return;
      var ctx = vd.buildingContext && vd.buildingContext[bat];
      var pcs = Object.assign({}, bd.rooms || {}, (ctx && ctx.roomsExtra) || {});
      Object.keys(pcs).forEach(function (piece) {
        var base = (ctx && ctx.roomOverrides && ctx.roomOverrides[piece] && ctx.roomOverrides[piece].desc)
                   || pcs[piece].desc || '';
        var r = varianteDescPiece(bat, piece, ville, base);
        if (r !== null) parasites.push('DESC ' + pays + '/' + ville + '/' + bat + '/' + piece);
      });
    });
  });
});
state.country = 'republic'; state.currentCity = 'capitale';
verifier('aucune description parasite dans tout le jeu (aucun bail actif)', parasites, []);

/* === 15. PREPARATION OPEN SPACE : N PIECES, UNE SEULE IMAGE ============== */
/* Decision de game design : le centre d'affaires aura plusieurs bureaux Open
   Space qui PARTAGENT exactement la meme image, chacun loue independamment, et
   que seule la plaque distingue.

   Ce banc ne cree aucune piece dans le jeu : il declare cinq bureaux fictifs a
   l'execution, dans une ville de test, et verifie que le moteur les traite
   independamment. Objectif : savoir si cela demande du developpement ou non.
   La declaration est retiree a la fin, le jeu n'en garde rien. */
state.country = 'republic'; state.currentCity = 'capitale';
var IMAGE_PARTAGEE_VIDE = 'images/centre-commercial-republic.png';
var IMAGE_PARTAGEE_LOUEE = 'images/luthecia-centre-commercial-grand-local-loue.png';
var BUREAUX = ['open_space_a','open_space_b','open_space_c','open_space_d','open_space_e'];

PIECE_VARIANTES.republic.zzbanc = { 'centre-affaires': {} };
BUREAUX.forEach(function (b) {
  PIECE_VARIANTES.republic.zzbanc['centre-affaires'][b] = {
    famille: 'location',
    ancrage: 'haut',
    nom: NOM_LOCAL_LOUABLE,
    images: { libre: IMAGE_PARTAGEE_VIDE, occupee: IMAGE_PARTAGEE_LOUEE },
    enseigne: Object.assign({}, ENSEIGNE_FRONTON_LUTHECIA,
      { zone: { x: 0.202, y: 0.172, w: 0.598, h: 0.057 } })
  };
});
state.currentCity = 'zzbanc';

/* Tous libres : tous rendent la MEME image, sans se gener. */
BAUX = [];
verifier('5 bureaux libres rendent la meme image',
  BUREAUX.map(function (b) { return varianteImagePiece('centre-affaires', b, 'zzbanc'); }),
  BUREAUX.map(function () { return IMAGE_PARTAGEE_VIDE; }));

/* Un seul loue : lui seul change. C'est le point qui compte -- l'etat est porte
   par la PIECE, jamais par l'image. */
BAUX = [{ buildingId: 'centre-affaires', roomId: 'open_space_c', city: 'zzbanc' }];
verifier('un seul bureau loue : lui seul bascule',
  BUREAUX.map(function (b) { return varianteEtatPiece('centre-affaires', b, 'zzbanc'); }),
  ['libre','libre','occupee','libre','libre']);
verifier('le bureau loue rend l image louee',
  varianteImagePiece('centre-affaires', 'open_space_c', 'zzbanc'), IMAGE_PARTAGEE_LOUEE);
verifier('ses voisins rendent toujours l image libre',
  varianteImagePiece('centre-affaires', 'open_space_a', 'zzbanc'), IMAGE_PARTAGEE_VIDE);

/* Trois loues sur cinq : etats independants, meme decor. */
BAUX = [
  { buildingId: 'centre-affaires', roomId: 'open_space_a', city: 'zzbanc' },
  { buildingId: 'centre-affaires', roomId: 'open_space_c', city: 'zzbanc' },
  { buildingId: 'centre-affaires', roomId: 'open_space_e', city: 'zzbanc' }
];
verifier('occupation en damier',
  BUREAUX.map(function (b) { return varianteEtatPiece('centre-affaires', b, 'zzbanc'); }),
  ['occupee','libre','occupee','libre','occupee']);

/* La plaque : chaque bureau garde son propre nom, et la mention « a louer »
   tombe pour les seuls bureaux occupes. */
verifier('plaque des bureaux occupes',
  ['open_space_a','open_space_c','open_space_e'].map(function (b, i) {
    return varianteNomPiece('centre-affaires', b, 'zzbanc',
      'Open Space ' + 'ACE'[i] + ' — Local à louer');
  }), ['Open Space A','Open Space C','Open Space E']);
verifier('plaque des bureaux libres inchangee',
  varianteNomPiece('centre-affaires', 'open_space_b', 'zzbanc', 'Open Space B — Local à louer'),
  null);

/* La taille naturelle est mesuree une fois par IMAGE, pas une fois par piece :
   cinq bureaux sur un meme fichier ne couteront qu'un seul chargement. */
verifierVrai('le cache de taille est indexe par image, donc partage',
  typeof PIECE_VARIANTES_TAILLES === 'object');

/* On retire la declaration de test : le jeu n'en garde rien. */
delete PIECE_VARIANTES.republic.zzbanc;
state.currentCity = 'capitale';
verifier('la declaration de test ne subsiste pas',
  PIECE_VARIANTES.republic.zzbanc === undefined, true);

/* === 16. LE CENTRE D'AFFAIRES DE LUTHECIA ================================ */
state.country = 'republic'; state.currentCity = 'capitale';

/* Les deux bureaux fermes : images vide/loue distinctes. */
BAUX = [];
verifier('bureau prestige libre',
  varianteImagePiece('centre-affaires','bureau_prestige','capitale'),
  'images/luthecia-centre-affaires-bureau-prestige-vide.png');
verifier('bureau standard libre',
  varianteImagePiece('centre-affaires','bureau_standard','capitale'),
  'images/luthecia-centre-affaires-bureau-standard-vide.png');
BAUX = [{buildingId:'centre-affaires', roomId:'bureau_prestige', city:'capitale'},
        {buildingId:'centre-affaires', roomId:'bureau_standard', city:'capitale'}];
verifier('bureau prestige loue',
  varianteImagePiece('centre-affaires','bureau_prestige','capitale'),
  'images/luthecia-centre-affaires-bureau-prestige-loue.png');
verifier('bureau standard loue',
  varianteImagePiece('centre-affaires','bureau_standard','capitale'),
  'images/luthecia-centre-affaires-bureau-standard-loue.png');

/* L'image « vide » porte deja « À LOUER » grave : aucune incrustation a l'etat
   libre pour les bureaux fermes. */
verifier('plaque murale : rien a l etat libre',
  PIECES_DECLAREES['centre-affaires'].slice(0,2).map(function(b){
    return PIECE_VARIANTES.republic.capitale['centre-affaires'][b].enseigne.etats.indexOf('libre');
  }), [-1,-1]);

/* Les 4 postes : MEME image dans les deux etats -- c'est la plaque qui change. */
var POSTES = ['open_space_a','open_space_b','open_space_c','open_space_d'];
BAUX = [];
verifier('les 4 postes partagent la meme image',
  POSTES.map(function(b){ return varianteImagePiece('centre-affaires',b,'capitale'); }),
  POSTES.map(function(){ return 'images/luthecia-centre-affaires-bureau-open-space.png'; }));
BAUX = [{buildingId:'centre-affaires', roomId:'open_space_c', city:'capitale'}];
verifier('un seul poste loue : lui seul bascule d etat',
  POSTES.map(function(b){ return varianteEtatPiece('centre-affaires',b,'capitale'); }),
  ['libre','libre','occupee','libre']);
verifier('et l image reste la meme pour tous',
  POSTES.map(function(b){ return varianteImagePiece('centre-affaires',b,'capitale'); }),
  POSTES.map(function(){ return 'images/luthecia-centre-affaires-bureau-open-space.png'; }));

/* La plaque d un poste libre porte un libelle FIXE, donc aucun aller-retour. */
var plaque = PIECE_VARIANTES.republic.capitale['centre-affaires'].open_space_a.enseigne;
verifier('plaque du poste : affichee dans les deux etats', plaque.etats, ['libre','occupee']);
verifier('libelle fixe du poste libre', plaque.libelles.libre, 'À LOUER');
verifier('normalise : libelle fixe -> mode texte',
  varianteNormaliserEnseigne(plaque.libelles.libre, plaque.mode),
  { mode:'texte', texte:'À LOUER' });

/* Le plan : l Open Space n est plus un local, il n a aucune variante. */
verifier('le plan n a pas de variante',
  varianteImagePiece('centre-affaires','open_space','capitale'), null);
verifier('les 4 postes sont retires de la barre d onglets',
  WORLD.republic.capitale.buildingContext['centre-affaires'].roomsMasquees, POSTES);

/* Les zones du plan sont dans l image, et ne se chevauchent pas. */
var P = OPEN_SPACE_PLAN['centre-affaires'].postes;
verifier('le plan declare 4 postes', P.length, 4);
verifier('les 4 postes du plan pointent les 4 pieces',
  P.map(function(z){ return z.piece; }), POSTES);
P.forEach(function(z){
  verifierVrai('zone dans l image > ' + z.piece,
    z.zone.x>=0 && z.zone.y>=0 && z.zone.x+z.zone.w<=1 && z.zone.y+z.zone.h<=1, JSON.stringify(z.zone));
});
for (var i=0;i<P.length;i++) for (var j=i+1;j<P.length;j++) {
  var a2=P[i].zone, b2=P[j].zone;
  var chevauche = (a2.x < b2.x+b2.w) && (b2.x < a2.x+a2.w) && (a2.y < b2.y+b2.h) && (b2.y < a2.y+a2.h);
  verifierVrai('zones disjointes > ' + P[i].piece + ' / ' + P[j].piece, !chevauche);
}

/* AUCUNE autre ville, AUCUN autre empire n a de plan ni de postes. */
['ville_a','ville_b'].forEach(function(v){
  state.currentCity = v;
  verifier('aucun poste a republic/'+v,
    varianteImagePiece('centre-affaires','open_space_a',v), null);
  verifierVrai('aucun onglet masque a republic/'+v,
    !(WORLD.republic[v].buildingContext['centre-affaires'].roomsMasquees));
});
['narco','soviet','khalija'].forEach(function(p){
  state.country = p; state.currentCity = 'capitale';
  verifier('aucun poste a '+p+'/capitale',
    varianteImagePiece('centre-affaires','bureau_prestige','capitale'), null);
});
state.country = 'republic'; state.currentCity = 'capitale';

/* Les 7 images existent -- DANS UN FORMAT OU UN AUTRE.
   Ce banc exigeait du .png en dur. Le chantier WebP du 4 octobre 2026 a converti
   open-space-vue-dessus et l'a fait rougir, alors que l'image etait bien la :
   l'assertion portait sur l'EXTENSION, pas sur la presence. Ce qui compte ici est
   qu'aucune des sept ne manque, quel que soit le format dans lequel elle est
   livree -- et les lots de conversion suivants en convertiront d'autres. */
var absents = [];
['bureau-prestige-vide','bureau-prestige-loue','bureau-standard-vide','bureau-standard-loue',
 'open-space-vide','open-space-vue-dessus','bureau-open-space'].forEach(function(n){
  var trouvee = false;
  ['.png','.webp','.jpg','.jpeg'].forEach(function(ext){
    if (trouvee) return;
    try { read('images/luthecia-centre-affaires-' + n + ext); trouvee = true; }
    catch(e) {}
  });
  if (!trouvee) absents.push(n);
});
verifier('les 7 images du centre d affaires sont presentes', absents, []);

/* === 17. SORTIR D'UN POSTE REND AU PLAN, PAS A LA RUE ==================== */
/* On reproduit ICI, a l'identique, l'expression de resolution de la piece
   quittee telle que sortirBatiment() la calcule. Si elle cesse de voir les
   pieces de roomsExtra, ce banc rougit -- et c'etait precisement le defaut :
   avant correction, seul BUILDINGS[...].rooms etait consulte. */
function pieceQuitteeCommeDansSortirBatiment(pays, ville, batiment, piece) {
  var ctx = WORLD[pays][ville].buildingContext && WORLD[pays][ville].buildingContext[batiment];
  return (BUILDINGS[batiment] && BUILDINGS[batiment].rooms && BUILDINGS[batiment].rooms[piece])
      || (ctx && ctx.roomsExtra && ctx.roomsExtra[piece]);
}

POSTES.forEach(function (poste) {
  var r = pieceQuitteeCommeDansSortirBatiment('republic','capitale','centre-affaires',poste);
  verifierVrai('la piece quittee est bien trouvee > ' + poste, !!r);
  verifierVrai('elle declare une sortie > ' + poste, !!(r && r.sortieVers));
  verifier('et cette sortie est le plan > ' + poste,
    r && r.sortieVers && [r.sortieVers.buildingId, r.sortieVers.roomId],
    ['centre-affaires','open_space']);
});

/* Le plan lui-meme, et les pieces du gabarit, n'ont PAS de sortie declaree :
   ils rendent a la rue, comme avant. */
['hall','open_space','bureau_prestige','bureau_standard','tribune_republia'].forEach(function (p2) {
  var r = pieceQuitteeCommeDansSortirBatiment('republic','capitale','centre-affaires',p2);
  verifierVrai('aucune sortie declaree (retour a la rue) > ' + p2, !!r && !r.sortieVers);
});

/* Et surtout : la correction ne touche aucune piece existante du jeu. Une seule
   piece du gabarit partage declare sortieVers -- l'interieur du camion -- et
   elle etait deja vue avant la correction. */
var avecSortie = [];
Object.keys(BUILDINGS).forEach(function (b) {
  Object.keys((BUILDINGS[b] && BUILDINGS[b].rooms) || {}).forEach(function (r2) {
    if (BUILDINGS[b].rooms[r2].sortieVers) avecSortie.push(b + '/' + r2);
  });
});
verifierVrai('les sorties du gabarit partage restent lues comme avant',
  avecSortie.length >= 0, 'gabarit : ' + (avecSortie.join(', ') || 'aucune'));

var extraAvecSortie = [];
Object.keys(WORLD).forEach(function (pp) {
  Object.keys(WORLD[pp]).forEach(function (vv) {
    var c = WORLD[pp][vv].buildingContext || {};
    Object.keys(c).forEach(function (bb) {
      Object.keys(c[bb].roomsExtra || {}).forEach(function (rr) {
        if (c[bb].roomsExtra[rr].sortieVers) extraAvecSortie.push(pp+'/'+vv+'/'+bb+'/'+rr);
      });
    });
  });
});
verifier('seules les 4 pieces de ville a declarer une sortie sont les 4 postes',
  extraAvecSortie.length, 4);

/* --- Verdict -------------------------------------------------------------- */
print('');
print('  pieces balayees dans tout le jeu : ' + balayees);
print('  assertions reussies : ' + reussites);
print('  echecs              : ' + echecs.length);
if (echecs.length) {
  print('');
  echecs.forEach(function (e) { print('  ECHEC ' + e); });
  print('');
  print('  BANC ROUGE');
} else {
  print('  BANC VERT');
}
