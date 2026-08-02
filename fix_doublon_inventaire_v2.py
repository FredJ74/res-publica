#!/usr/bin/env python3
PATH_PP = "plateau-personnage.js"
with open(PATH_PP, "r", encoding="utf-8") as f:
    pp = f.read()

old_1 = """function renderInvItemsPanel() {
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

"""
assert pp.count(old_1) == 1, f"plateau-personnage.js : trouvé {pp.count(old_1)} fois (attendu 1)"
pp = pp.replace(old_1, "")

with open(PATH_PP, "w", encoding="utf-8") as f:
    f.write(pp)
print("✅ Fonction redondante retirée de plateau-personnage.js")
