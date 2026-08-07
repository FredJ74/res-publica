#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """// =====================
// SUBDIVISION DES COMMERCES PREMIUM / BUILDING
// ====================="""

new = """// =====================
// ENTREPOT LOGISTIQUE — achat direct par le joueur (fenetre unique, quantites saisies par
// ressource, validation en bloc). Theorie complete validee avec Fred le 6-7 aout 2026.
// Ressources achetees creditees sur state.ressourcesPersonnelles (compteurs empilables,
// distincts de l'inventaire d'objets uniques). NOTE POUR FRED : a confirmer que ce choix
// (nouvelle reserve dediee plutot que l'inventaire classique) te convient avant de brancher
// ceci a un vrai ordre de salle.
// =====================

async function doOuvrirAchatEntrepot() {
  const buildingId = state.currentBuilding;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const etat = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(state.country, state.currentCity, buildingId) : {};
  const stock = etat.entrepot?.stock || {};

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.75rem;color:#8a8060;margin-bottom:.8rem">Indiquez la quantité souhaitée pour chaque produit (laissez vide pour ne rien acheter). Le prix affiché varie selon le niveau du stock.</div>';
  html += '<table style="width:100%;font-size:.78rem;border-collapse:collapse">';
  html += '<tr style="color:#8a6a20;font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.05em;text-align:left"><th>Produit</th><th>Stock</th><th>Prix mini-maxi</th><th>Prix actuel</th><th>Quantité</th></tr>';

  Object.entries(RESSOURCES_ECONOMIE).forEach(([cle, res]) => {
    const enStock = stock[cle] || 0;
    const prixActuel = typeof getPrixRessource === 'function' ? getPrixRessource(cle, enStock) : res.prixBase;
    const prixMin = Math.round(res.prixBase * 0.6 * 100) / 100;
    const prixMax = Math.round(res.prixBase * 1.4 * 100) / 100;
    html += '<tr style="border-top:1px solid #2a2010">';
    html += '<td style="padding:.35rem 0"><i class="ti ' + res.icon + '" style="margin-right:.3rem"></i>' + res.label + '</td>';
    html += '<td style="color:' + (enStock === 0 ? '#cc5540' : '#8a8060') + '">' + enStock + '</td>';
    html += '<td style="color:#6a5a30">' + prixMin + '-' + prixMax + ' ' + cur + '</td>';
    html += '<td style="color:#C9A84C">' + prixActuel + ' ' + cur + '</td>';
    html += '<td><input type="number" min="0" max="' + enStock + '" id="achat-entrepot-' + cle + '" style="width:70px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.25rem" ' + (enStock === 0 ? 'disabled' : '') + ' /></td>';
    html += '</tr>';
  });
  html += '</table>';
  html += '<button class="pnj-action-btn" onclick="confirmerAchatEntrepot(\\'' + buildingId + '\\')" style="margin-top:1rem">Valider l\\'achat</button>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Salle des Ventes';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerAchatEntrepot(buildingId) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const etat = await sbGetBatimentEtat(state.country, state.currentCity, buildingId);
  const stock = etat.entrepot?.stock || {};

  // Premiere passe : lire les quantites demandees, calculer le total, verifier stock+argent
  const achats = {};
  let total = 0;
  for (const cle of Object.keys(RESSOURCES_ECONOMIE)) {
    const qte = parseInt(document.getElementById('achat-entrepot-' + cle)?.value || 0);
    if (!qte || qte <= 0) continue;
    const enStock = stock[cle] || 0;
    if (qte > enStock) {
      showToast('Stock insuffisant', 'Il ne reste que ' + enStock + ' unité(s) de ' + RESSOURCES_ECONOMIE[cle].label + '.', false);
      return;
    }
    const prix = getPrixRessource(cle, enStock);
    achats[cle] = { qte, prix };
    total += qte * prix;
  }

  if (Object.keys(achats).length === 0) {
    showToast('Rien à acheter', 'Indiquez au moins une quantité.', false);
    return;
  }
  if (state.arg < total) {
    showToast('Fonds insuffisants', Math.round(total) + ' ' + cur + ' requis, vous avez ' + Math.round(state.arg) + ' ' + cur + '.', false);
    return;
  }

  // Deuxieme passe : appliquer (deduire argent+stock, crediter la reserve du joueur)
  state.arg -= total;
  if (!state.ressourcesPersonnelles) state.ressourcesPersonnelles = {};
  for (const [cle, { qte }] of Object.entries(achats)) {
    stock[cle] = (stock[cle] || 0) - qte;
    state.ressourcesPersonnelles[cle] = (state.ressourcesPersonnelles[cle] || 0) + qte;
  }

  etat.entrepot = { ...(etat.entrepot || {}), stock };
  if (typeof sbSetBatimentEtat === 'function') await sbSetBatimentEtat(state.country, state.currentCity, buildingId, etat).catch(() => {});

  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  showToast('Achat effectué !', '-' + Math.round(total) + ' ' + cur + '.', true, true);
  addJournalEntry('Achat à l\\'entrepôt logistique : ' + Object.entries(achats).map(([cle, a]) => a.qte + ' ' + RESSOURCES_ECONOMIE[cle].label).join(', ') + '.', 'event-good');
}

// =====================
// SUBDIVISION DES COMMERCES PREMIUM / BUILDING
// ====================="""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Fenêtre d'achat de l'entrepôt créée (préparation, pas encore routée à un ordre).")
