#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  // Deuxieme passe : appliquer (deduire argent+stock, crediter la reserve du joueur)
  state.arg -= total;
  if (!state.ressourcesPersonnelles) state.ressourcesPersonnelles = {};
  for (const [cle, { qte }] of Object.entries(achats)) {
    stock[cle] = (stock[cle] || 0) - qte;
    state.ressourcesPersonnelles[cle] = (state.ressourcesPersonnelles[cle] || 0) + qte;
  }"""

new = """  // Deuxieme passe : appliquer (deduire argent+stock, crediter l'inventaire du joueur —
  // plafonne globalement a 100 objets, voir addToInventory/plateau-divers.js). Si la place
  // manque en cours de route, le reste de l'achat est annule et rembourse au prorata.
  let totalReellementPaye = 0;
  for (const [cle, { qte, prix }] of Object.entries(achats)) {
    const res = RESSOURCES_ECONOMIE[cle];
    const qteAjoutee = addToInventory({
      name: res.label, icon: res.icon, stackable: true, stackKey: cle, qty: qte,
      desc: 'Ressource achetée à l\\'entrepôt logistique.'
    });
    if (qteAjoutee > 0) {
      stock[cle] = (stock[cle] || 0) - qteAjoutee;
      totalReellementPaye += qteAjoutee * prix;
    }
  }
  state.arg -= totalReellementPaye;
  total = totalReellementPaye;"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Achat de l'entrepôt corrigé : utilise désormais l'inventaire empilable plafonné, plutôt qu'une réserve séparée.")
