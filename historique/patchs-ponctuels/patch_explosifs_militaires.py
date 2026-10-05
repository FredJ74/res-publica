#!/usr/bin/env python3
PATH = "plateau-actions-illegales-rumeurs.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function doAcheterExplosifs() {"""
new = """// Explosifs reglementaires, reserves au Ministre de la Defense — traçables (contrairement
// a la version marche noir), pas de risque ni de cout : ordre defini dans data.js
// (acheter_bombe_mil) mais jamais routee. Corrige le 5 aout 2026.
function doObtenirExplosifsMilitaires() {
  if (state.poste?.id !== 'min_def') {
    showToast('Accès refusé', 'Réservé au Ministre de la Défense.', false);
    return;
  }
  if (!state.inventory) state.inventory = [];
  state.inventory.push({
    type: 'explosif', name: 'Explosifs militaires réglementaires', icon: 'ti-bomb', legal: true,
    desc: 'Explosifs traçables, obtenus légalement par le Ministère de la Défense. Usage unique.',
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/explosifs-marche-noir.png'
  });
  updateUI();
  showToast('Explosifs obtenus', 'Explosifs réglementaires ajoutés à votre inventaire.', true, true);
  addJournalEntry('Explosifs militaires réglementaires obtenus (Ministère de la Défense).', 'event-info');
}

function doAcheterExplosifs() {"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ doObtenirExplosifsMilitaires créée (version légale, réservée au Ministre de la Défense).")
