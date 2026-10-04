/* ===========================================================================
   PLAN DE L'OPEN SPACE — zones cliquables sur la vue du dessus
   ===========================================================================

   La piece `open_space` du centre d'affaires n'est plus un local : c'est le PLAN
   du plateau, vu de dessus. Quatre postes y sont dessines, et ce fichier les
   rend cliquables.

   CE FICHIER N'INVENTE NI MOTEUR NI REGLE. Il assemble trois mecanismes qui
   existaient deja :

     1. la GEOMETRIE vient de plateau-variantes-pieces.js. Le fond est affiche en
        `cover` : une zone posee en pourcentage du CADRE se decalerait des qu'on
        redimensionne. varianteZoneEnPixels() refait le calcul de `cover` pour
        convertir une zone exprimee en fractions de l'IMAGE en pixels du cadre --
        c'est deja ce qui tient les enseignes sur leur fronton ;
     2. le SURVOL reprend l'infobulle flottante des scenes de rue (.rc-tooltip,
        plateau-rue-centrale.js), qui suit le curseur et existe deja dans le CSS ;
     3. l'ETAT de chaque poste se lit par getLocationPourRoom, comme partout
        ailleurs -- aucun second registre, aucune seconde verite.

   Entrer dans un poste appelle simplement enterRoom() sur une piece reelle :
   les quatre postes sont de vraies pieces louables, declarees dans data.js, et
   simplement retirees de la barre d'onglets (roomsMasquees). C'est le patron
   des chambres de la clinique, qu'on atteint par un point d'entree dedie.
   =========================================================================== */


/* Les quatre postes, en fractions de l'IMAGE de la vue du dessus. Mesures sur
   luthecia-centre-affaires-open-space-vue-dessus.png : quatre ilots en 2x2,
   tapis compris -- on vise l'ilot entier, pas le seul bureau, pour que la cible
   soit confortable a la souris. */
const OPEN_SPACE_PLAN = {
  'centre-affaires': {
    image: 'images/luthecia-centre-affaires-open-space-vue-dessus.webp',
    postes: [
      { piece: 'open_space_a', nom: 'Open Space A', zone: { x: 0.222, y: 0.185, w: 0.263, h: 0.300 } },
      { piece: 'open_space_b', nom: 'Open Space B', zone: { x: 0.555, y: 0.170, w: 0.263, h: 0.300 } },
      { piece: 'open_space_c', nom: 'Open Space C', zone: { x: 0.222, y: 0.485, w: 0.263, h: 0.300 } },
      { piece: 'open_space_d', nom: 'Open Space D', zone: { x: 0.555, y: 0.485, w: 0.263, h: 0.300 } }
    ]
  }
};


/* Ce qu'il faut afficher au survol d'un poste : son nom, puis sa situation.
   Libre -> « À louer ». Occupe -> le nom du cabinet, qu'on lit sans reseau
   quand il a deja ete vu (le moteur d'enseignes le memorise par fonds), et
   sinon le nom du locataire, qui lui est toujours en memoire. */
function openSpaceSituationPoste(buildingId, piece, ville) {
  const bail = (typeof getLocationPourRoom === 'function')
    ? getLocationPourRoom(buildingId, piece, ville) : null;
  if (!bail) return { libre: true, texte: 'À louer' };

  if (bail.fondsId && typeof PIECE_VARIANTES_MEMO_ENSEIGNE !== 'undefined') {
    const memo = PIECE_VARIANTES_MEMO_ENSEIGNE[bail.fondsId];
    if (memo && memo.texte) return { libre: false, texte: memo.texte };
  }
  // Pas encore de commerce installe, ou enseigne pas encore lue : le locataire
  // fait foi, et il est toujours en memoire.
  const qui = (bail.locataire || '').replace(/^pj:/, '');
  return { libre: false, texte: qui || 'Occupé' };
}


/* Pose (ou retire) les zones cliquables. Appelee par enterRoom pour TOUTE piece,
   y compris celles qui n'ont pas de plan : c'est elle qui retire les zones de la
   piece precedente, exactement comme la zone cliquable de l'enigme du musee. */
function openSpaceInjecterZones(buildingId, roomId, ville) {
  const cadre = document.getElementById('piece-image');
  if (!cadre) return;
  cadre.querySelectorAll('.os-zone').forEach(function (el) { el.remove(); });
  openSpaceMasquerInfobulle();

  const plan = OPEN_SPACE_PLAN[buildingId];
  if (!plan || roomId !== 'open_space') return;
  // Le plan n'existe qu'a Luthecia : les autres villes gardent leur Open Space
  // unique, et ce fichier n'y pose rien.
  if (typeof varianteDePiece === 'function'
      && !varianteDePiece('centre-affaires', 'open_space_a', ville)) return;

  const cite = ville || (typeof state !== 'undefined' ? state.currentCity : null);

  plan.postes.forEach(function (poste) {
    const div = document.createElement('div');
    div.className = 'os-zone';
    div.dataset.piece = poste.piece;
    div.style.cssText = 'position:absolute;z-index:2;cursor:pointer;';
    div.addEventListener('mousemove', function (e) {
      const s = openSpaceSituationPoste(buildingId, poste.piece, cite);
      openSpaceAfficherInfobulle(e, poste.nom, s.texte);
    });
    div.addEventListener('mouseleave', openSpaceMasquerInfobulle);
    div.addEventListener('click', function () {
      openSpaceMasquerInfobulle();
      if (typeof enterRoom === 'function') enterRoom(buildingId, poste.piece, null);
    });
    cadre.appendChild(div);
  });

  openSpacePositionnerZones(cadre, plan);
  openSpaceInstallerObservateur(cadre);
}


/* Place les quatre zones en pixels, d'apres le meme calcul de rognage que les
   enseignes. Sans cela elles glisseraient sur le plan au redimensionnement. */
function openSpacePositionnerZones(cadre, plan) {
  if (typeof varianteTailleNaturelle !== 'function') return;
  varianteTailleNaturelle(plan.image).then(function (taille) {
    plan.postes.forEach(function (poste) {
      const div = cadre.querySelector('.os-zone[data-piece="' + poste.piece + '"]');
      if (!div) return;
      const px = varianteZoneEnPixels(poste.zone, cadre, taille, null);
      if (!px) { div.style.display = 'none'; return; }
      div.style.display = 'block';
      div.style.left   = px.gauche + 'px';
      div.style.top    = px.haut + 'px';
      div.style.width  = px.largeur + 'px';
      div.style.height = px.hauteur + 'px';
    });
  });
}

let openSpaceObservateur = null;

function openSpaceInstallerObservateur(cadre) {
  if (openSpaceObservateur || typeof ResizeObserver === 'undefined') return;
  openSpaceObservateur = new ResizeObserver(function () {
    if (!cadre.querySelector('.os-zone')) return;
    const plan = OPEN_SPACE_PLAN[cadre.dataset.varBat];
    if (plan) openSpacePositionnerZones(cadre, plan);
  });
  openSpaceObservateur.observe(cadre);
}


/* --- L'infobulle ----------------------------------------------------------
   Reprend la .rc-tooltip des scenes de rue : meme classe, meme CSS, meme
   comportement (creee paresseusement, attachee au body, suit le curseur).
   Seul le contenu change -- deux lignes au lieu d'une, habillees en ligne pour
   qu'aucune feuille de style n'ait a etre modifiee par ce lot. */
function openSpaceAfficherInfobulle(e, titre, situation) {
  let tip = document.getElementById('os-tooltip');
  if (!tip) {
    tip = document.createElement('div');
    tip.id = 'os-tooltip';
    tip.className = 'rc-tooltip';
    document.body.appendChild(tip);
  }
  // Habillage EN LIGNE, volontairement : aucune feuille de style n'est touchee
  // par ce lot. Le cadre, la couleur et la police viennent de .rc-tooltip.
  tip.innerHTML = '';
  const l1 = document.createElement('div');
  l1.textContent = titre;
  l1.style.cssText = 'color:#C9A84C;letter-spacing:.08em';
  const l2 = document.createElement('div');
  l2.textContent = situation;
  l2.style.cssText = 'color:#f0ead6;font-size:.92em;margin-top:.15rem';
  tip.appendChild(l1); tip.appendChild(l2);
  tip.style.left = (e.pageX + 16) + 'px';
  tip.style.top  = (e.pageY - 10) + 'px';
  tip.classList.add('visible');
}

function openSpaceMasquerInfobulle() {
  document.getElementById('os-tooltip')?.classList.remove('visible');
}
