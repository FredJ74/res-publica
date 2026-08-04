#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function doCambriolerCaisseCommissariat() {"""
new = """// Vol de materiel de chantier — meme principe que le cambriolage de caisse (formule DUP +
// indice + reputation), mais base 60% (plus facile, materiel non surveille comme une
// caisse). Le proprietaire lui-meme peut voler son propre chantier (auto-victimisation
// parodique) : l'argent se neutralise financierement, seul le bonus de sympathie publique
// et le RP restent un vrai gain. Toujours tracable sur enquete, meme en cas de reussite.
async function doVolerMaterielChantier() {
  const id = state.currentBuilding;
  await chargerTerrainState(id);
  const ts = getTerrainState(id);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const pays = state.country;
  const ville = state.currentCity || 'capitale';

  if (!ts.chantier) { showToast('Impossible', 'Aucun chantier en cours ici.', false); return; }

  document.getElementById('modal-postes')?.classList.remove('open');
  const dup = state.char?.stats?.DUP || 8;
  const isEmpire = (typeof INDICES_NATIONAUX !== 'undefined' && INDICES_NATIONAUX[pays]?.IS) || 45;
  const bonusReputation = typeof getBonusReputationCriminelle === 'function' ? getBonusReputationCriminelle() : 0;

  let taux = 60 + (dup - 10) * 2 - (isEmpire - 45) / 3 + bonusReputation;
  taux = Math.max(15, Math.min(90, Math.round(taux)));

  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    const montant = Math.floor(ts.chantier.montantTotal * 0.10);
    const estAutoVol = ts.proprietaire === state.char?.name;

    state.arg = (state.arg || 0) + montant;
    if (estAutoVol) {
      state.arg -= montant; // s'annule financierement : seul le bonus de sympathie compte
    } else if (typeof sbGet === 'function' && typeof sbUpdate === 'function') {
      const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(ts.proprietaire)}`).catch(() => null);
      const proprio = rows && rows[0];
      if (proprio) await sbUpdate('personnages', `name=eq.${encodeURIComponent(ts.proprietaire)}`, { arg: (proprio.arg || 0) - montant }).catch(() => {});
    }

    ts.chantier.dateFinPrevue += 2 * 86400000;
    if (typeof modifierIndiceVille === 'function') modifierIndiceVille(pays, ville, 'IS', -1);
    if (typeof INDICES_NATIONAUX !== 'undefined' && INDICES_NATIONAUX[pays]) {
      INDICES_NATIONAUX[pays].IS = Math.max(0, (INDICES_NATIONAUX[pays].IS || 45) - 1);
    }

    const nouvelEtat = setTerrainState(id, { chantier: ts.chantier });
    if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(pays, id, nouvelEtat).catch(() => {});

    // Toujours tracable, meme en cas de reussite (Fred : "reste detectable sur enquete")
    if (typeof sbTracerAction === 'function') {
      await sbTracerAction({
        id: 'vol-chantier-' + Date.now() + '-' + Math.floor(Math.random() * 1000),
        auteur: state.char?.name, cible: ts.proprietaire, type_action: 'vol_materiel_chantier',
        country: pays, city: ville,
        jour: state.day || 1, jour_expiration: (state.day || 1) + 15
      }).catch(() => {});
    }
    if (typeof addExternalEvent === 'function') {
      addExternalEvent('Du matériel a disparu sur un chantier de la ville. Les curieux s\\'interrogent sur qui a bien pu faire le coup.', 'local');
    }
    if (typeof sendMail === 'function' && !estAutoVol) {
      await sendMail(ts.proprietaire, 'Chef de Chantier', 'Vol de matériel !',
        'Du matériel a été volé sur votre chantier cette nuit. Perte estimée : ' + montant.toLocaleString('fr-FR') + ' ' + cur + '. Le chantier a pris 2 jours de retard. L\\'opinion publique semble vous soutenir face à cette épreuve.');
    }

    updateUI();
    showToast('Vol réussi !', '+' + montant.toLocaleString('fr-FR') + ' ' + cur + (estAutoVol ? ' (auto-annulé financièrement, mais sympathie publique gagnée)' : ''), true, true);
    addJournalEntry((estAutoVol ? 'Vous mettez en scène le vol de votre propre chantier' : 'Vol de matériel sur un chantier réussi') + '. +' + montant.toLocaleString('fr-FR') + ' ' + cur + '. Chantier retardé de 2 jours.', 'event-good');
    return;
  }

  const critique = (Math.floor(Math.random() * 100) + 1) <= 25;
  if (critique) {
    if (!state.recherche) state.recherche = [];
    state.recherche.push({ acte: 'vol_materiel_chantier', type: 'delit', jour: state.day || 1, peineMaxJours: 2 });
    if (typeof addExternalEvent === 'function') {
      addExternalEvent((state.char?.name || 'Quelqu\\'un') + ' a été pris en flagrant délit de vol de matériel sur un chantier !', 'local');
    }
    addJournalEntry('Vol raté et découvert immédiatement. Avis de recherche émis contre vous (peine max 2 jours).', 'event-bad');
    showToast('Démasqué !', 'Avis de recherche émis (peine max 2 jours).', false);
  } else {
    if (typeof sbTracerAction === 'function') {
      await sbTracerAction({
        id: 'voltentative-' + Date.now() + '-' + Math.floor(Math.random() * 1000),
        auteur: state.char?.name, cible: ts.proprietaire, type_action: 'tentative_vol_materiel_chantier',
        country: pays, city: ville,
        jour: state.day || 1, jour_expiration: (state.day || 1) + 15
      }).catch(() => {});
    }
    addJournalEntry('Tentative de vol de matériel ratée sur un chantier.', 'event-info');
    showToast('Vol échoué', "Vous avez échappé à la détection pour l'instant.", false);
  }
}

function doCambriolerCaisseCommissariat() {"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Vol de matériel de chantier créé (auto-vol possible, traçable même en cas de réussite, impact IS).")
