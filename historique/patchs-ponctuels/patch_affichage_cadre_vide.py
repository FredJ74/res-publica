#!/usr/bin/env python3
PATH = "plateau-enigme-portrait.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Rumeurs differenciees par variante (remplace le texte generique unique) ---
old_1 = """  if (e.etape === 'non_commencee' && joursEcoules >= ENIGME1_DELAI_DECLENCHEMENT_JOURS) {
    // Tirage aleatoire de la variante — fixe definitivement pour ce joueur. Determine
    // uniquement le point d'entree (quel PNJ/lieu le met sur la voie en premier) : les 4
    // salles du musee affichent de toute facon un cadre vide une fois l'enigme declenchee.
    const variante = ENIGME1_VARIANTES[Math.floor(Math.random() * ENIGME1_VARIANTES.length)];
    state.char.enigme1 = { etape: 'declenchee', variante: variante, dateDeclenchement: new Date().toISOString() };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    if (typeof addJournalEntry === 'function') {
      addJournalEntry("Une rumeur circule en ville : il paraît qu'il y a quelque chose d'étrange au musée de la ville...", 'event-secret');
    }
    return;
  }"""
new_1 = """  if (e.etape === 'non_commencee' && joursEcoules >= ENIGME1_DELAI_DECLENCHEMENT_JOURS) {
    // Tirage aleatoire de la variante — fixe definitivement pour ce joueur. Ne change RIEN
    // aux salles affichees (les 4 sont toujours vides pour un joueur concerne) : sert
    // uniquement a varier le texte de la rumeur/du journal, pour alimenter les echanges
    // entre joueurs sans changer la mecanique de jeu.
    const variante = ENIGME1_VARIANTES[Math.floor(Math.random() * ENIGME1_VARIANTES.length)];
    state.char.enigme1 = { etape: 'declenchee', variante: variante, dateDeclenchement: new Date().toISOString() };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    if (typeof addJournalEntry === 'function') {
      const rumeur = ENIGME1_RUMEURS[variante] || ENIGME1_RUMEURS.maire;
      addJournalEntry(rumeur, 'event-secret');
    }
    return;
  }"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- 2. Ajouter la donnee des rumeurs + tout le systeme d'affichage cadre vide ---
old_2 = """const ENIGME1_VARIANTES = ['maire', 'criminel', 'entrepreneur', 'plume'];"""
new_2 = """const ENIGME1_VARIANTES = ['maire', 'criminel', 'entrepreneur', 'plume'];

const ENIGME1_RUMEURS = {
  maire:        "Une rumeur circule en ville : il paraît qu'on chuchote des choses étranges sur d'anciens édiles, à la mairie...",
  criminel:     "Une rumeur circule en ville : un vieux fait divers refait surface, à ce qu'on raconte...",
  entrepreneur: "Une rumeur circule en ville : des rumeurs circulent sur les grandes fortunes d'autrefois...",
  plume:        "Une rumeur circule en ville : on dit que certains articles de presse cachaient bien des choses, jadis..."
};

// Une fois l'enigme declenchee (et tant qu'elle n'est pas resolue), les 4 salles du musee de
// la ville affichent un cadre vide — quel que soit le tirage de variante du joueur (qui ne
// sert qu'a varier le texte de la rumeur ci-dessus).
const ENIGME1_SALLES_CADRE_VIDE = {
  salle_maires: {
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-maires-cadre-vide-luthecia.png',
    personnage: 'Marcel Torcieu',
    dates: '1895–1958',
    texteAccroche: "Étrange qu'un portrait manque justement ici... Les archives de la Mairie permettraient sans doute d'en apprendre davantage sur cet homme."
  },
  salle_criminels: {
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-criminels-cadre-vide-luthecia.png',
    personnage: 'Maurice Caillon',
    dates: '1901–1954',
    texteAccroche: "Étrange qu'un portrait manque justement ici... Le Commissariat permettrait sans doute d'en apprendre davantage sur cet homme."
  },
  salle_entrepreneurs: {
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-entrepreneurs-cadre-vide-luthecia.png',
    personnage: 'Jacques Moulin',
    dates: '1897–1965',
    texteAccroche: "Étrange qu'un portrait manque justement ici... L'Étude Notariale permettrait sans doute d'en apprendre davantage sur cet homme."
  },
  salle_plumes: {
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-plumes-cadre-vide-luthecia.png',
    personnage: 'Étienne Tintabin',
    dates: '1898–1969',
    texteAccroche: "Étrange qu'un portrait manque justement ici... L'Imprimerie L'Autruche Entravée permettrait sans doute d'en apprendre davantage sur cet homme."
  }
};

// L'enigme est "active" (cadres vides visibles) tant qu'elle a ete declenchee et n'est pas
// encore marquee comme resolue (etape future, non geree ici).
function enigme1EtapeActive() {
  return typeof state !== 'undefined' && state.char && state.char.enigme1 &&
    (state.char.enigme1.etape === 'declenchee' || state.char.enigme1.etape === 'relancee');
}

// Renvoie l'image "cadre vide" a afficher pour cette piece, ou null si non concernee.
// Appelee depuis la chaine de priorite d'image dans enterRoom (plateau-navigation.js).
function enigme1ImageSalleVide(buildingId, roomId) {
  if (buildingId !== 'musee-ville-luthecia') return null;
  if (!enigme1EtapeActive()) return null;
  const info = ENIGME1_SALLES_CADRE_VIDE[roomId];
  return info ? info.imageUrl : null;
}

// Injecte (ou retire) une zone cliquable generreuse sur la bande des portraits, permettant
// d'examiner le cadre vide. Appelee juste apres l'affichage de l'image de la piece.
function enigme1InjecterZoneCliquable(buildingId, roomId) {
  const pieceImg = document.getElementById('piece-image');
  if (!pieceImg) return;
  pieceImg.querySelectorAll('.enigme1-zone-cadre').forEach(function(el) { el.remove(); });

  if (buildingId !== 'musee-ville-luthecia') return;
  if (!enigme1EtapeActive()) return;
  const info = ENIGME1_SALLES_CADRE_VIDE[roomId];
  if (!info) return;

  pieceImg.style.position = pieceImg.style.position || 'relative';
  const div = document.createElement('div');
  div.className = 'enigme1-zone-cadre';
  div.style.cssText = 'position:absolute;left:0;right:0;top:25%;height:45%;cursor:pointer;';
  div.title = 'Examiner les portraits';
  div.onclick = function() { enigme1AfficherPopupCadreVide(roomId); };
  pieceImg.appendChild(div);
}

// Affiche la pop-up du cadre vide (reutilise le modal generique #modal-postes).
function enigme1AfficherPopupCadreVide(roomId) {
  const info = ENIGME1_SALLES_CADRE_VIDE[roomId];
  if (!info) return;

  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.05em;margin-bottom:.3rem">Un cadre vide</div>';
  html += '<div style="font-size:.9rem;color:#e0d8c0;margin-bottom:.5rem">Seule la plaque subsiste : <strong>' + info.personnage + '</strong> (' + info.dates + ').</div>';
  html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic;line-height:1.5">' + info.texteAccroche + '</div>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Cadre vide';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Système complet d'affichage du cadre vide ajouté.")
