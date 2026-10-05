#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """// =====================
// SUBDIVISION DES COMMERCES PREMIUM / BUILDING
// ====================="""

new = """// =====================
// VENTE DIRECTE DU TRANSFORMATEUR — mini-stock propre a l'usine (les 40% de production non
// redistribues aux entrepots), meme mecanique de prix dynamique. Revenu credite a la caisse
// de l'usine, pas a celle de l'entrepot.
// =====================

async function doOuvrirVenteDirecteUsine() {
  const buildingId = state.currentBuilding;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const etat = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(state.country, state.currentCity, buildingId) : {};
  const venteDirecte = etat.usine?.venteDirecte || {};
  const produits = Object.keys(venteDirecte);

  if (produits.length === 0) {
    showToast('Rien à vendre', "Aucune production locale disponible pour l'instant.", false);
    return;
  }

  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:.95rem;color:#8a8060;margin-bottom:1rem">Vente directe sur place. Indiquez la quantité souhaitée (laissez vide pour ne rien acheter).</div>';
  html += '<table style="width:100%;font-size:1rem;border-collapse:collapse">';
  html += '<tr style="color:#8a6a20;font-family:Bebas Neue,sans-serif;font-size:.85rem;letter-spacing:.05em;text-align:left"><th style="padding:.3rem 0">Produit</th><th>Stock</th><th>Prix mini-maxi</th><th>Prix actuel</th><th>Quantité</th></tr>';

  produits.forEach(cle => {
    const res = RESSOURCES_ECONOMIE[cle];
    if (!res) return;
    const enStock = venteDirecte[cle] || 0;
    const prixActuel = getPrixRessource(cle, enStock);
    const prixMin = Math.round(res.prixBase * 0.6 * 100) / 100;
    const prixMax = Math.round(res.prixBase * 1.4 * 100) / 100;
    html += '<tr style="border-top:1px solid #2a2010">';
    html += '<td style="padding:.55rem 0"><i class="ti ' + res.icon + '" style="margin-right:.4rem;font-size:1.1rem"></i>' + res.label + '</td>';
    html += '<td style="color:' + (enStock === 0 ? '#cc5540' : '#8a8060') + '">' + enStock + '</td>';
    html += '<td style="color:#6a5a30">' + prixMin + '-' + prixMax + ' ' + cur + '</td>';
    html += '<td style="color:#C9A84C;font-weight:bold">' + prixActuel + ' ' + cur + '</td>';
    html += '<td><input type="number" min="0" max="' + enStock + '" id="vente-usine-' + cle + '" style="width:90px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:1rem" ' + (enStock === 0 ? 'disabled' : '') + ' /></td>';
    html += '</tr>';
  });
  html += '</table>';
  html += '<button class="pnj-action-btn" onclick="confirmerVenteDirecteUsine(\\'' + buildingId + '\\')" style="margin-top:1.2rem;font-size:1rem;padding:.7rem">Valider l\\'achat</button>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Vente Directe';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerVenteDirecteUsine(buildingId) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const etat = await sbGetBatimentEtat(state.country, state.currentCity, buildingId);
  const venteDirecte = etat.usine?.venteDirecte || {};

  const achats = {};
  let total = 0;
  for (const cle of Object.keys(venteDirecte)) {
    const qte = parseInt(document.getElementById('vente-usine-' + cle)?.value || 0);
    if (!qte || qte <= 0) continue;
    const enStock = venteDirecte[cle] || 0;
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

  let totalReellementPaye = 0;
  for (const [cle, { prix }] of Object.entries(achats)) {
    const res = RESSOURCES_ECONOMIE[cle];
    const qteAjoutee = addToInventory({
      name: res.label, icon: res.icon, stackable: true, stackKey: cle, qty: achats[cle].qte,
      desc: 'Produit acheté en vente directe.'
    });
    if (qteAjoutee > 0) {
      venteDirecte[cle] = (venteDirecte[cle] || 0) - qteAjoutee;
      totalReellementPaye += qteAjoutee * prix;
    }
  }
  state.arg -= totalReellementPaye;

  const nouvelEtat = { ...etat, usine: { ...(etat.usine || {}), venteDirecte, caisse: (etat.usine?.caisse || 0) + totalReellementPaye } };
  if (typeof sbSetBatimentEtat === 'function') await sbSetBatimentEtat(state.country, state.currentCity, buildingId, nouvelEtat).catch(() => {});

  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  showToast('Achat effectué !', '-' + Math.round(totalReellementPaye) + ' ' + cur + '.', true, true);
  addJournalEntry('Achat en vente directe : ' + Object.entries(achats).map(([cle, a]) => a.qte + ' ' + RESSOURCES_ECONOMIE[cle].label).join(', ') + '.', 'event-good');
}

// =====================
// SUBDIVISION DES COMMERCES PREMIUM / BUILDING
// ====================="""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Vente directe de l'usine créée (mini-stock propre, revenu vers la caisse de l'usine).")
