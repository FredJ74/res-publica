#!/usr/bin/env python3

# --- 1. Corriger etatCivilImprimerFiche : name/desc au lieu de nom/description ---
PATH_EC = "plateau-etat-civil.js"
with open(PATH_EC, "r", encoding="utf-8") as f:
    ec = f.read()

old_1 = """  const dejaImprimee = state.inventory.some(function(item) { return item.nom === 'Fiche d\\'état-civil — ' + fiche.nom; });
  if (dejaImprimee) {
    if (typeof showToast === 'function') showToast('Déjà en poche', 'Vous avez déjà cette fiche dans votre inventaire.', false);
    return;
  }

  const texteComplet = fiche.evenements.map(function(e) { return e.texte; }).join('\\n');
  state.inventory.push({
    nom: 'Fiche d\\'état-civil — ' + fiche.nom,
    icon: 'ti-file-text',
    description: texteComplet
  });
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(function() {});
  if (typeof showToast === 'function') showToast('Fiche imprimée', fiche.nom + ' ajouté(e) à votre inventaire.', true);
}"""

new_1 = """  const dejaImprimee = state.inventory.some(function(item) { return item.name === 'Fiche d\\'état-civil — ' + fiche.nom; });
  if (dejaImprimee) {
    if (typeof showToast === 'function') showToast('Déjà en poche', 'Vous avez déjà cette fiche dans votre inventaire.', false);
    return;
  }

  const texteComplet = fiche.evenements.map(function(e) { return e.texte; }).join('\\n');
  state.inventory.push({
    name: 'Fiche d\\'état-civil — ' + fiche.nom,
    icon: 'ti-file-text',
    desc: texteComplet
  });
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(function() {});
  if (typeof updateUI === 'function') updateUI();
  if (typeof renderInvItemsPanel === 'function') renderInvItemsPanel();
  if (typeof showToast === 'function') showToast('Fiche imprimée', fiche.nom + ' ajouté(e) à votre inventaire.', true);
}"""

assert ec.count(old_1) == 1, f"plateau-etat-civil.js : trouvé {ec.count(old_1)} fois (attendu 1)"
ec = ec.replace(old_1, new_1)

with open(PATH_EC, "w", encoding="utf-8") as f:
    f.write(ec)

# --- 2. Nouvelle fonction renderInvItemsPanel (plateau-personnage.js) ---
PATH_PP = "plateau-personnage.js"
with open(PATH_PP, "r", encoding="utf-8") as f:
    pp = f.read()

old_2 = """function toggleInventaire() {"""
new_2 = """// Rafraichit le petit panneau "Inventaire" de la barre laterale gauche (#inv-items), qui
// n'etait jusqu'ici jamais mis a jour dynamiquement (reste statique sur "Aucun objet").
function renderInvItemsPanel() {
  const el = document.getElementById('inv-items');
  if (!el) return;
  const items = state.inventory || [];
  if (items.length === 0) {
    el.innerHTML = '<div class="inv-item-empty">Aucun objet</div>';
    return;
  }
  el.innerHTML = items.map(function(item, i) {
    return '<div style="display:flex;align-items:center;gap:.4rem;padding:.3rem 0;cursor:pointer" onclick="ouvrirDetailObjet(' + i + ')">' +
      '<i class="ti ' + (item.icon || 'ti-package') + '" style="font-size:.85rem;color:#8a6a20"></i>' +
      '<span style="font-size:.78rem;color:#c0b090;flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">' + item.name + '</span>' +
      '</div>';
  }).join('');
}

function toggleInventaire() {"""

assert pp.count(old_2) == 1, f"plateau-personnage.js : trouvé {pp.count(old_2)} fois (attendu 1)"
pp = pp.replace(old_2, new_2)

with open(PATH_PP, "w", encoding="utf-8") as f:
    f.write(pp)

# --- 3. Appeler renderInvItemsPanel depuis updateUI (plateau-core.js), pour corriger le probleme partout, pas juste pour nous ---
PATH_PC = "plateau-core.js"
with open(PATH_PC, "r", encoding="utf-8") as f:
    pc = f.read()

old_3 = """  // Inventaire
  document.getElementById('inv-liquide').textContent = state.liquide.toLocaleString('fr-FR') + ' ' + cur;
  document.getElementById('inv-banque').textContent  = state.banque.toLocaleString('fr-FR') + ' ' + cur;
}"""
new_3 = """  // Inventaire
  document.getElementById('inv-liquide').textContent = state.liquide.toLocaleString('fr-FR') + ' ' + cur;
  document.getElementById('inv-banque').textContent  = state.banque.toLocaleString('fr-FR') + ' ' + cur;
  if (typeof renderInvItemsPanel === 'function') renderInvItemsPanel();
}"""
assert pc.count(old_3) == 1, f"plateau-core.js : trouvé {pc.count(old_3)} fois (attendu 1)"
pc = pc.replace(old_3, new_3)

with open(PATH_PC, "w", encoding="utf-8") as f:
    f.write(pc)

print("✅ Trois correctifs appliqués : champ item.name, item.desc, et rafraîchissement automatique du panneau Inventaire.")
