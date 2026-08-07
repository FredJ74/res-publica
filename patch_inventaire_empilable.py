#!/usr/bin/env python3
PATH = "plateau-divers.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function addToInventory(item) {
  state.inventory.push(item);
  renderInventory();
}
function renderInventory() {
  const el = document.getElementById('inv-items');
  if (!el) return;
  if (state.inventory.length === 0) {
    el.innerHTML = '<div class="inv-item-empty">Aucun objet</div>';
    return;
  }
  el.innerHTML = state.inventory.map((item, idx) => {
    const legal = item.legal === false ? '<span style="color:#cc4444;font-size:.8rem"> ⚠ Illégal</span>' : '';
    const expiry = item.expireDay ? '<div style="font-size:.8rem;color:#6a5030">Expire jour ' + item.expireDay + '</div>' : '';
    return '<div class="inv-item" style="display:flex;align-items:center;justify-content:space-between;gap:.4rem">' +
      '<div style="display:flex;align-items:center;gap:.4rem;flex:1;min-width:0;cursor:pointer" onclick="ouvrirDetailObjetInventaire(' + idx + ')">' +
        '<i class="ti ' + (item.icon||'ti-package') + '" style="font-size:.85rem;color:#8a6a20;flex-shrink:0"></i>' +
        '<div style="min-width:0">' +
          '<div style="font-size:.78rem;color:#c0b090;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">' + item.name + legal + '</div>' +
          (item.desc ? '<div style="font-size:.82rem;color:#9a8a68;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">' + item.desc.substring(0,60) + (item.desc.length>60?'...':'') + '</div>' : '') +
          expiry +
        '</div>' +
      '</div>' +
      '<button onclick="jeterObjetInventaire(' + idx + ')" title="Déposer ici (visible par les autres joueurs)" style="flex-shrink:0;background:none;border:1px solid #4a3010;color:#a0905a;cursor:pointer;padding:.15rem .35rem;font-size:.85rem;font-family:Bebas Neue,sans-serif"><i class="ti ti-map-pin"></i></button>' +
      '<button onclick="supprimerItemInventaire(' + idx + ')" title="Supprimer" style="flex-shrink:0;background:none;border:1px solid #3a1a1a;color:#cc5540;cursor:pointer;padding:.15rem .35rem;font-size:.85rem;font-family:Bebas Neue,sans-serif">✕</button>' +
    '</div>';
  }).join('');
}"""

new = """// Plafond total (toutes ressources empilables confondues) transportable par un joueur —
// cree une vraie tension logistique sur les approvisionnements, decision prise avec Fred
// le 7 aout 2026. Les objets uniques (non empilables : cles de quete, calepins...) ne
// comptent pas dans ce plafond.
const PLAFOND_INVENTAIRE_EMPILABLE = 100;

function getTotalRessourcesEmpilables() {
  return (state.inventory || []).filter(i => i.stackable).reduce((s, i) => s + (i.qty || 1), 0);
}

// Ajoute un objet a l'inventaire. Si item.stackable et item.stackKey correspondent a une
// ligne deja presente, incremente sa quantite (plafonnee a PLAFOND_INVENTAIRE_EMPILABLE au
// total, tous types empilables confondus) plutot que de dupliquer une ligne par unite.
function addToInventory(item) {
  if (item.stackable && item.stackKey) {
    const dejaEnStock = getTotalRessourcesEmpilables();
    const qteVoulue = item.qty || 1;
    const placeDisponible = Math.max(0, PLAFOND_INVENTAIRE_EMPILABLE - dejaEnStock);
    const qteReelle = Math.min(qteVoulue, placeDisponible);
    if (qteReelle <= 0) {
      if (typeof showToast === 'function') showToast('Inventaire plein', 'Plafond de ' + PLAFOND_INVENTAIRE_EMPILABLE + ' unités atteint.', false);
      renderInventory();
      return 0;
    }
    const existant = (state.inventory || []).find(i => i.stackable && i.stackKey === item.stackKey);
    if (existant) {
      existant.qty = (existant.qty || 1) + qteReelle;
    } else {
      state.inventory.push({ ...item, qty: qteReelle });
    }
    renderInventory();
    return qteReelle;
  }

  state.inventory.push(item);
  renderInventory();
  return 1;
}

function renderInventory() {
  const el = document.getElementById('inv-items');
  if (!el) return;
  if (state.inventory.length === 0) {
    el.innerHTML = '<div class="inv-item-empty">Aucun objet</div>';
    return;
  }
  el.innerHTML = state.inventory.map((item, idx) => {
    const legal = item.legal === false ? '<span style="color:#cc4444;font-size:.8rem"> ⚠ Illégal</span>' : '';
    const expiry = item.expireDay ? '<div style="font-size:.8rem;color:#6a5030">Expire jour ' + item.expireDay + '</div>' : '';
    const qtyBadge = (item.stackable && item.qty > 1) ? '<span style="color:#C9A84C;font-weight:bold"> ×' + item.qty + '</span>' : '';
    return '<div class="inv-item" style="display:flex;align-items:center;justify-content:space-between;gap:.4rem">' +
      '<div style="display:flex;align-items:center;gap:.4rem;flex:1;min-width:0;cursor:pointer" onclick="ouvrirDetailObjetInventaire(' + idx + ')">' +
        '<i class="ti ' + (item.icon||'ti-package') + '" style="font-size:.85rem;color:#8a6a20;flex-shrink:0"></i>' +
        '<div style="min-width:0">' +
          '<div style="font-size:.78rem;color:#c0b090;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">' + item.name + qtyBadge + legal + '</div>' +
          (item.desc ? '<div style="font-size:.82rem;color:#9a8a68;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">' + item.desc.substring(0,60) + (item.desc.length>60?'...':'') + '</div>' : '') +
          expiry +
        '</div>' +
      '</div>' +
      '<button onclick="jeterObjetInventaire(' + idx + ')" title="Déposer ici (visible par les autres joueurs)" style="flex-shrink:0;background:none;border:1px solid #4a3010;color:#a0905a;cursor:pointer;padding:.15rem .35rem;font-size:.85rem;font-family:Bebas Neue,sans-serif"><i class="ti ti-map-pin"></i></button>' +
      '<button onclick="supprimerItemInventaire(' + idx + ')" title="Supprimer" style="flex-shrink:0;background:none;border:1px solid #3a1a1a;color:#cc5540;cursor:pointer;padding:.15rem .35rem;font-size:.85rem;font-family:Bebas Neue,sans-serif">✕</button>' +
    '</div>';
  }).join('');
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Inventaire empilable créé : plafond de 100 unités (objets empilables uniquement), lignes groupées avec quantité affichée.")
