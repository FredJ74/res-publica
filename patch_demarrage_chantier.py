#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """async function confirmerConstruction(niveauKey) {
  const id = state.currentBuilding;
  const niveau = NIVEAUX_CONSTRUCTION[niveauKey];
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (!niveau) return;

  if (state.arg < niveau.cout) {
    showToast('Fonds insuffisants', niveau.cout.toLocaleString('fr-FR') + ' ' + cur + ' requis. Pensez au prêt bancaire.', false);
    return;
  }

  state.arg -= niveau.cout;
  const nouvelEtat = setTerrainState(id, {
    niveau_construction: niveauKey,
    valeur_totale: PRIX_TERRAIN + niveau.cout
  });

  if (typeof sbSetTerrainState === 'function') {
    await sbSetTerrainState(state.country, id, nouvelEtat).catch(() => {});
  }

  document.getElementById('modal-postes').classList.remove('open');
  updateUI();
  showToast('Construction achevée !', 'Vous avez construit : ' + niveau.label + '.', true, true);
  addJournalEntry('Construction de "' + niveau.label + '" achevée. -' + niveau.cout.toLocaleString('fr-FR') + ' ' + cur + '.', 'event-good');
}"""

new = """// Duree de chantier (jours) par niveau — nombres pairs pour un vrai palier de mi-chantier.
const DUREE_CHANTIER_JOURS = { hangar: 6, commerce_standard: 12, commerce_premium: 18, building: 24 };

async function confirmerConstruction(niveauKey) {
  const id = state.currentBuilding;
  const niveau = NIVEAUX_CONSTRUCTION[niveauKey];
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (!niveau) return;

  const dureeJours = DUREE_CHANTIER_JOURS[niveauKey] || 6;
  const montant35 = Math.round(niveau.cout * 0.35);
  const montant30 = niveau.cout - 2 * montant35; // reste, evite les arrondis qui derapent

  if (state.arg < montant35) {
    showToast('Fonds insuffisants', montant35.toLocaleString('fr-FR') + ' ' + cur + ' requis pour le premier versement (35%). Pensez au prêt de construction.', false);
    return;
  }

  state.arg -= montant35;
  const maintenant = Date.now();
  const dateFinTheorique = maintenant + dureeJours * 86400000;

  const nouvelEtat = setTerrainState(id, {
    chantier: {
      niveau: niveauKey,
      dureeJours: dureeJours,
      dateDebut: maintenant,
      dateFinTheorique: dateFinTheorique, // fixe — reference pour le demarrage du remboursement du pret
      dateFinPrevue: dateFinTheorique,     // evolue avec les aleas/corruption
      montantTotal: niveau.cout,
      montant35: montant35,
      montant30: montant30,
      palierPaye: 1,
      enAttentePaiement: false,
      joursImpayes: 0,
      evenements: []
    }
  });

  if (typeof sbSetTerrainState === 'function') {
    await sbSetTerrainState(state.country, id, nouvelEtat).catch(() => {});
  }

  document.getElementById('modal-postes').classList.remove('open');
  updateUI();
  const dateTxt = new Date(dateFinTheorique).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long' });
  addJournalEntry('Chantier démarré : ' + niveau.label + '. Premier versement (35%, ' + montant35.toLocaleString('fr-FR') + ' ' + cur + ') payé. Livraison prévue le ' + dateTxt + '.', 'event-good');
  showToast('Chantier démarré !', 'Livraison prévue le ' + dateTxt + '.', true, true);
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Démarrage du chantier créé : premier versement (35%), état chantier initialisé.")
