#!/usr/bin/env python3

PATH_PP = "plateau-personnage.js"
with open(PATH_PP, "r", encoding="utf-8") as f:
    pp = f.read()

old_2 = "function toggleInventaire() {"
assert pp.count(old_2) == 1, f"plateau-personnage.js : trouvé {pp.count(old_2)} fois (attendu 1)"
new_2 = """function renderInvItemsPanel() {
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
pp = pp.replace(old_2, new_2)
with open(PATH_PP, "w", encoding="utf-8") as f:
    f.write(pp)
print("✅ renderInvItemsPanel ajouté dans plateau-personnage.js")

PATH_PC = "plateau-core.js"
with open(PATH_PC, "r", encoding="utf-8") as f:
    pc = f.read()

old_3 = "  document.getElementById('inv-banque').textContent  = state.banque.toLocaleString('fr-FR') + ' ' + cur;"
assert pc.count(old_3) == 1, f"plateau-core.js : trouvé {pc.count(old_3)} fois (attendu 1)"
new_3 = old_3 + "\n  if (typeof renderInvItemsPanel === 'function') renderInvItemsPanel();"
pc = pc.replace(old_3, new_3)
with open(PATH_PC, "w", encoding="utf-8") as f:
    f.write(pc)
print("✅ Appel ajouté dans updateUI (plateau-core.js)")
