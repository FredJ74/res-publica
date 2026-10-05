#!/usr/bin/env python3
PATH = "plateau-politique.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function ouvrirModalNommerJuge() {"""
new = """function ouvrirModalNommerDirecteurPharma() {
  if (state.poste?.id !== 'min_fin') {
    showToast('Accès refusé', 'Seul le Ministre des Finances peut nommer un directeur.', false);
    return;
  }
  ouvrirNominerPosteNomme('directeur_pharma');
}

function ouvrirModalNommerDirecteurTabacAlcools() {
  if (state.poste?.id !== 'min_fin') {
    showToast('Accès refusé', 'Seul le Ministre des Finances peut nommer un directeur.', false);
    return;
  }
  ouvrirNominerPosteNomme('directeur_tabac_alcools');
}

function ouvrirModalNommerDirecteurRaffinerie() {
  if (state.poste?.id !== 'min_fin') {
    showToast('Accès refusé', 'Seul le Ministre des Finances peut nommer un directeur.', false);
    return;
  }
  ouvrirNominerPosteNomme('directeur_raffinerie');
}

function ouvrirModalNommerJuge() {"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ 3 fonctions relais créées (nomination des directeurs, réservée au Ministre des Finances).")
