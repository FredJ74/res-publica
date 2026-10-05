#!/usr/bin/env python3

# --- 1. confirmerDonObjetPj (plateau-justice-economie.js) ---
PATH1 = "plateau-justice-economie.js"
with open(PATH1, "r", encoding="utf-8") as f:
    content1 = f.read()

old_1 = """async function confirmerDonObjetPj(encodedPnj, idx) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); } catch(e) { return; }
  const item = state.inventory[idx];
  if (!item || !pnj.isPJ) return;

  const cible = pnj.name.replace(' (PNJ)', '');
  state.inventory.splice(idx, 1);
  renderInventory();
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Objet donné', '"' + item.name + '" donné à ' + cible + '.', true, true);
  addJournalEntry('Vous avez donné "' + item.name + '" à ' + cible + '.', 'event-info');
}"""

new_1 = """async function confirmerDonObjetPj(encodedPnj, idx) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); } catch(e) { return; }
  const item = state.inventory[idx];
  if (!item || !pnj.isPJ) return;

  const cible = pnj.name.replace(' (PNJ)', '');
  state.inventory.splice(idx, 1);
  renderInventory();
  document.getElementById('modal-postes')?.classList.remove('open');

  // Persistance reelle cote destinataire (corrige un trou : l'objet disparaissait avant
  // sans jamais vraiment arriver chez l'autre joueur). Recupere a sa prochaine connexion.
  if (typeof sbDonnerObjetJoueur === 'function') {
    await sbDonnerObjetJoueur(item, cible, state.char?.name || 'Anonyme').catch(() => {});
  }

  showToast('Objet donné', '"' + item.name + '" donné à ' + cible + '.', true, true);
  addJournalEntry('Vous avez donné "' + item.name + '" à ' + cible + '.', 'event-info');
}"""

assert content1.count(old_1) == 1, f"justice-economie.js : trouvé {content1.count(old_1)}"
content1 = content1.replace(old_1, new_1)

with open(PATH1, "w", encoding="utf-8") as f:
    f.write(content1)
print("✅ confirmerDonObjetPj corrigée (persistance réelle).")

# --- 2. donnerObjetAJoueur (plateau-personnage.js) ---
PATH2 = "plateau-personnage.js"
with open(PATH2, "r", encoding="utf-8") as f:
    content2 = f.read()

old_2 = """function donnerObjetAJoueur(idx) {
  const item = state.inventory[idx];
  const cible = document.getElementById('donner-objet-cible')?.value;
  if (!item || !cible) return;

  state.inventory.splice(idx, 1);
  renderInventory();
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Objet donné', 'Vous avez donné "' + item.name + '" à ' + cible + '.', true, true);
  addJournalEntry('Vous avez donné "' + item.name + '" à ' + cible + '.', 'event-info');

  // Notifier le destinataire par mail reel
  if (typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    sbSendMail(state.char?.name || 'Anonyme', cible, 'Objet reçu',
      (state.char?.name || 'Quelqu\\'un') + ' vous a remis : "' + item.name + '". ' + (item.desc || ''), time).catch(() => {});
  }
}"""

new_2 = """async function donnerObjetAJoueur(idx) {
  const item = state.inventory[idx];
  const cible = document.getElementById('donner-objet-cible')?.value;
  if (!item || !cible) return;

  state.inventory.splice(idx, 1);
  renderInventory();
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Objet donné', 'Vous avez donné "' + item.name + '" à ' + cible + '.', true, true);
  addJournalEntry('Vous avez donné "' + item.name + '" à ' + cible + '.', 'event-info');

  // Persistance reelle cote destinataire (corrige un trou : l'objet disparaissait avant
  // sans jamais vraiment arriver chez l'autre joueur — seul le mail etait reel).
  if (typeof sbDonnerObjetJoueur === 'function') {
    await sbDonnerObjetJoueur(item, cible, state.char?.name || 'Anonyme').catch(() => {});
  }

  // Notifier le destinataire par mail reel
  if (typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    sbSendMail(state.char?.name || 'Anonyme', cible, 'Objet reçu',
      (state.char?.name || 'Quelqu\\'un') + ' vous a remis : "' + item.name + '". ' + (item.desc || ''), time).catch(() => {});
  }
}"""

assert content2.count(old_2) == 1, f"personnage.js : trouvé {content2.count(old_2)}"
content2 = content2.replace(old_2, new_2)

with open(PATH2, "w", encoding="utf-8") as f:
    f.write(content2)
print("✅ donnerObjetAJoueur corrigée (persistance réelle).")
