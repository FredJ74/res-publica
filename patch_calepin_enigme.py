#!/usr/bin/env python3
PATH = "plateau-enigme-portrait.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Creer le calepin dans l'inventaire au declenchement de l'enigme ---
old_1 = """    state.char.enigme1 = { etape: 'declenchee', variante: variante, dateDeclenchement: new Date().toISOString() };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    if (typeof addJournalEntry === 'function') {
      const rumeur = ENIGME1_RUMEURS[variante] || ENIGME1_RUMEURS.maire;
      addJournalEntry(rumeur, 'event-secret');
    }
    return;
  }"""
new_1 = """    state.char.enigme1 = { etape: 'declenchee', variante: variante, dateDeclenchement: new Date().toISOString() };
    if (!state.inventory) state.inventory = [];
    if (!state.inventory.some(function(it) { return it.calepinEnigme1; })) {
      state.inventory.push({
        id: 'calepin-enigme1',
        name: "Calepin de l'enquête",
        icon: 'ti-notebook',
        imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/calepin-enigme-musee.png',
        desc: "Un petit calepin. Chaque page se remplit au fil de ce que vous découvrez.",
        calepinEnigme1: true
      });
    }
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    if (typeof updateUI === 'function') updateUI();
    if (typeof renderInventory === 'function') renderInventory();
    if (typeof addJournalEntry === 'function') {
      const rumeur = ENIGME1_RUMEURS[variante] || ENIGME1_RUMEURS.maire;
      addJournalEntry(rumeur, 'event-secret');
    }
    return;
  }"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- 2. Affichage dynamique du calepin (titres reveles au fil du dossier) ---
old_2 = """function enigme1EtapeActive() {"""
new_2 = """// Ordre fixe des 7 cases du dossier, avec le titre revele une fois la case cochee.
const ENIGME1_ORDRE_CALEPIN = ['mairie', 'commissariat', 'notaire', 'presse', 'ehpad_dubois', 'ehpad_chevillard', 'ehpad_chauchay'];
const ENIGME1_TITRES_CALEPIN = {
  mairie: 'Marcel Torcieu',
  commissariat: 'Maurice Caillon',
  notaire: 'La parcelle B-127',
  presse: "L'Autruche Entravée",
  ehpad_dubois: 'Élise',
  ehpad_chevillard: 'Les témoins',
  ehpad_chauchay: 'Pierre Thibault'
};

function enigme1AfficherCalepin(idx) {
  const item = state.inventory[idx];
  const dossier = (state.char && state.char.enigme1 && state.char.enigme1.dossier) || {};

  let html = '<div style="padding:1rem">';
  if (item && item.imageUrl) {
    html += '<img src="' + item.imageUrl + '" style="width:100%;border-radius:4px;margin-bottom:.8rem;max-height:220px;object-fit:cover"/>';
  }
  html += '<div style="display:flex;flex-direction:column;gap:.5rem">';
  ENIGME1_ORDRE_CALEPIN.forEach(function(cle) {
    const rempli = !!dossier[cle];
    const titre = rempli ? ENIGME1_TITRES_CALEPIN[cle] : '...';
    html += '<div style="font-size:.85rem;color:' + (rempli ? '#e0d8c0' : '#5a5040') + ';font-style:' + (rempli ? 'normal' : 'italic') + '">Énigme du musée : ' + titre + '</div>';
  });
  html += '</div></div>';

  document.getElementById('postes-modal-title').textContent = "Calepin de l'enquête";
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function enigme1EtapeActive() {"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Calepin de l'enquête créé : apparaît à l'inventaire, pages révélées au fil du dossier.")
