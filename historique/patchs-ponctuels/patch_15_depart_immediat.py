#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function addContact(pnj) {
  if (!state.contacts) state.contacts = [];"""
new = """function addContact(pnj) {
  if ((pnj.name || '').replace(' (PNJ)', '').trim() === 'Jérémy' && typeof queteAccueilVerifierDepartJeremy === 'function') {
    // Depart immediat de Jeremy des qu'il est ajoute au repertoire, plutot que d'attendre
    // le prochain deplacement du joueur.
    queteAccueilVerifierDepartJeremy();
  }
  if (!state.contacts) state.contacts = [];"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Jérémy quitte le groupe immédiatement une fois ajouté aux contacts.")
