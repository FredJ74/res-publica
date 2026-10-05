#!/usr/bin/env python3

# --- 1. Retirer notre fonction redondante renderInvItemsPanel de plateau-personnage.js ---
PATH_PP = "plateau-personnage.js"
with open(PATH_PP, "r", encoding="utf-8") as f:
    pp = f.read()

old_1 = """// Rafraichit le petit panneau "Inventaire" de la barre laterale gauche (#inv-items), qui
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
new_1 = """function toggleInventaire() {"""
assert pp.count(old_1) == 1, f"plateau-personnage.js : trouvé {pp.count(old_1)} fois (attendu 1)"
pp = pp.replace(old_1, new_1)

with open(PATH_PP, "w", encoding="utf-8") as f:
    f.write(pp)
print("✅ Fonction redondante retirée de plateau-personnage.js")

# --- 2. plateau-core.js : appeler la vraie fonction renderInventory, pas la notre ---
PATH_PC = "plateau-core.js"
with open(PATH_PC, "r", encoding="utf-8") as f:
    pc = f.read()

old_2 = "  if (typeof renderInvItemsPanel === 'function') renderInvItemsPanel();"
assert pc.count(old_2) == 1, f"plateau-core.js : trouvé {pc.count(old_2)} fois (attendu 1)"
new_2 = "  if (typeof renderInventory === 'function') renderInventory();"
pc = pc.replace(old_2, new_2)

with open(PATH_PC, "w", encoding="utf-8") as f:
    f.write(pc)
print("✅ updateUI appelle désormais la vraie renderInventory dans plateau-core.js")

# --- 3. plateau-etat-civil.js : idem ---
PATH_EC = "plateau-etat-civil.js"
with open(PATH_EC, "r", encoding="utf-8") as f:
    ec = f.read()

old_3 = "  if (typeof renderInvItemsPanel === 'function') renderInvItemsPanel();"
assert ec.count(old_3) == 1, f"plateau-etat-civil.js : trouvé {ec.count(old_3)} fois (attendu 1)"
new_3 = "  if (typeof renderInventory === 'function') renderInventory();"
ec = ec.replace(old_3, new_3)

with open(PATH_EC, "w", encoding="utf-8") as f:
    f.write(ec)
print("✅ etatCivilImprimerFiche appelle désormais la vraie renderInventory")
