#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """// =====================
// PRET BANCAIRE
// ====================="""

new = """async function doPayerVersementChantier() {
  const id = state.currentBuilding;
  await chargerTerrainState(id);
  const ts = getTerrainState(id);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const ch = ts.chantier;

  if (!ch || !ch.enAttentePaiement) {
    showToast('Rien à payer', "Aucun versement n'est en attente sur ce chantier.", false);
    return;
  }

  const montantDu = ch.palierPaye === 1 ? ch.montant35 : ch.montant30;
  if (state.arg < montantDu) {
    showToast('Fonds insuffisants', montantDu.toLocaleString('fr-FR') + ' ' + cur + ' requis.', false);
    return;
  }

  state.arg -= montantDu;
  ch.palierPaye += 1;
  ch.enAttentePaiement = false;
  ch.joursImpayes = 0;

  const nouvelEtat = setTerrainState(id, { chantier: ch });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(() => {});

  updateUI();
  addJournalEntry('Versement de chantier payé (' + montantDu.toLocaleString('fr-FR') + ' ' + cur + '). Le chantier reprend.', 'event-good');
  showToast('Versement payé !', 'Le chantier reprend.', true);
}

async function doCorrompreChantier() {
  const id = state.currentBuilding;
  await chargerTerrainState(id);
  const ts = getTerrainState(id);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const ch = ts.chantier;

  if (!ch) { showToast('Impossible', "Aucun chantier en cours ici.", false); return; }
  if (ch.enAttentePaiement) { showToast('Impossible', 'Un versement est en attente — payez-le avant d\\'accélérer.', false); return; }

  const cout = 1500;
  if (state.arg < cout) { showToast('Fonds insuffisants', cout + ' ' + cur + ' requis.', false); return; }

  const maintenant = Date.now();
  const restant = ch.dateFinPrevue - maintenant;
  if (restant <= 0) { showToast('Inutile', 'Le chantier est déjà arrivé à échéance.', false); return; }

  state.arg -= cout;
  ch.dateFinPrevue = maintenant + Math.floor(restant / 2);

  const nouvelEtat = setTerrainState(id, { chantier: ch });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(() => {});

  const dateTxt = new Date(ch.dateFinPrevue).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long' });
  updateUI();
  addJournalEntry('Chantier accéléré par corruption (-' + cout + ' ' + cur + '). Nouvelle livraison prévue le ' + dateTxt + '.', 'event-info');
  showToast('Chantier accéléré', 'Nouvelle livraison : ' + dateTxt + '.', true);
}

// =====================
// PRET BANCAIRE
// ====================="""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Paiement des versements + accélération par corruption créés.")
