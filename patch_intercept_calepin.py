#!/usr/bin/env python3
PATH = "plateau-personnage.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """async function ouvrirDetailObjetInventaire(idx) {
  const item = state.inventory[idx];
  if (!item) return;

  document.getElementById('postes-modal-title').textContent = item.name;"""
new = """async function ouvrirDetailObjetInventaire(idx) {
  const item = state.inventory[idx];
  if (!item) return;

  if (item.calepinEnigme1 && typeof enigme1AfficherCalepin === 'function') {
    enigme1AfficherCalepin(idx);
    return;
  }

  document.getElementById('postes-modal-title').textContent = item.name;"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Interception du calepin ajoutée.")
