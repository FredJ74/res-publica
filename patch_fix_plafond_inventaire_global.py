#!/usr/bin/env python3
PATH = "plateau-divers.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """// Plafond total (toutes ressources empilables confondues) transportable par un joueur —
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
}"""

new = """// Plafond total transportable par un joueur, TOUT compris (ressources empilables et objets
// uniques comptent chacun pour leur quantite/1 vers le meme plafond) — a chacun de se
// debarrasser des objets qui ne servent plus a rien. Decision prise avec Fred le 7 aout 2026.
const PLAFOND_INVENTAIRE_EMPILABLE = 100;

function getTotalInventaire() {
  return (state.inventory || []).reduce((s, i) => s + (i.qty || 1), 0);
}

// Ajoute un objet a l'inventaire, plafonne globalement a PLAFOND_INVENTAIRE_EMPILABLE (tout
// type d'objet confondu). Si item.stackable et item.stackKey correspondent a une ligne deja
// presente, incremente sa quantite plutot que de dupliquer une ligne par unite ; sinon,
// pousse un objet unique classique (qty implicite 1).
function addToInventory(item) {
  const dejaEnStock = getTotalInventaire();
  const qteVoulue = item.qty || 1;
  const placeDisponible = Math.max(0, PLAFOND_INVENTAIRE_EMPILABLE - dejaEnStock);
  if (placeDisponible <= 0) {
    if (typeof showToast === 'function') showToast('Inventaire plein', 'Plafond de ' + PLAFOND_INVENTAIRE_EMPILABLE + ' objets atteint.', false);
    return 0;
  }

  if (item.stackable && item.stackKey) {
    const qteReelle = Math.min(qteVoulue, placeDisponible);
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
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Plafond corrigé : s'applique désormais à tout l'inventaire (objets uniques inclus), pas seulement aux ressources empilables.")
