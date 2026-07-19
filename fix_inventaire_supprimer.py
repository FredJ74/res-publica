#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif inventaire : le bouton "Supprimer (destruction definitive)" appelait
supprimerItemInventaire(), une fonction jamais ecrite (meme type de bug que
openRumeurModal / doRecruterInfo vus precedemment). Ajout de la fonction :
detruit l'objet sans le laisser dans la piece (contrairement a
jeterObjetInventaire, qui l'abandonne pour que d'autres joueurs le trouvent).
"""
import sys

def apply_patch(path, old, new, label):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    count = content.count(old)
    if count == 0:
        print(f"[ECHEC] {label} : ancre introuvable dans {path}")
        return False
    if count > 1:
        print(f"[ECHEC] {label} : ancre trouvee {count} fois dans {path} (doit etre unique)")
        return False
    content = content.replace(old, new, 1)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"[OK] {label}")
    return True

ok = True

old = """async function jeterObjetInventaire(idx) {"""
new = """function supprimerItemInventaire(idx) {
  const item = state.inventory[idx];
  if (!item) return;
  state.inventory.splice(idx, 1);
  renderInventory();
  showToast('Objet détruit', '"' + item.name + '" a été détruit définitivement. Aucune trace.', true);
  addJournalEntry('Vous avez détruit "' + item.name + '" définitivement.', 'event-info');
}

async function jeterObjetInventaire(idx) {"""

ok &= apply_patch('plateau-personnage.js', old, new, "plateau-personnage.js - ajout supprimerItemInventaire")

print()
if ok:
    print("TOUT EST OK.")
else:
    print("ECHEC. Ne rien committer, colle le detail a Claude.")
    sys.exit(1)
