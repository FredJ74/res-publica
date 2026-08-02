// plateau-maxence.js
// Maxence Monfils, jeune criminel du Musee National (arracheur d'ailes de mouches, ne en
// 2017), egalement croise au Parc Botanique National. Running gag : insaisissable, jamais
// employable, se balade entre le Parc et la Serre — position propre a CHAQUE joueur (pas de
// synchronisation globale, trop lourde pour un simple gag). Limite de 2 questions avant qu'il
// ne detale vers l'autre lieu.

const MAXENCE_PHOTOS = {
  parc:  'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/maxence-monfils-parc.png',
  serre: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/maxence-monfils-criminel.png'
};

// Appelee a chaque entree dans une piece (hook dans enterRoom, plateau-navigation.js).
// N'agit que dans le Parc Botanique National ; tire au sort la position initiale de Maxence
// pour ce joueur la premiere fois, puis injecte sa carte dans Personnes Presentes si sa
// position actuelle correspond a la piece visitee.
function maxenceVerifierPresence(buildingId, roomId) {
  if (typeof state === 'undefined' || !state.char) return;
  if (buildingId !== 'parc-botanique-national') return;

  if (!state.char.maxence) {
    state.char.maxence = { lieu: (Math.random() < 0.5 ? 'parc' : 'serre'), questions: 0 };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  }

  const list = document.getElementById('persons-list');
  if (!list) return;
  list.querySelectorAll('.maxence-card').forEach(function(el) { el.remove(); });

  if (state.char.maxence.lieu !== roomId) return;

  const photo = MAXENCE_PHOTOS[roomId] || MAXENCE_PHOTOS.parc;
  const encMaxence = encodeURIComponent(JSON.stringify({
    name: 'Maxence Monfils (PNJ)',
    role: 'PNJ - Petit chenapan insaisissable',
    rel: 'neutral',
    job: 'gamin_curieux',
    photoUrl: photo,
    photoPos: '50% 15%'
  }));

  const html = '<div class="person-card maxence-card" onclick="openPnjModal(this.dataset.enc)" data-enc="' + encMaxence + '">' +
    '<div class="person-avatar"><img src="' + photo + '" style="width:100%;height:100%;object-fit:cover;object-position:50% 15%"></div>' +
    '<div style="flex:1"><div class="person-name">Maxence Monfils</div><div class="person-role">Petit chenapan insaisissable</div></div>' +
    '</div>';

  const empty = list.querySelector('.person-empty');
  if (empty) empty.remove();
  list.insertAdjacentHTML('beforeend', html);
}
