// Archive de test de #194 : jamais chargee par le jeu.
async function confirmerVolMateriaux(matiere, pa, cost) {
  const id = state.currentBuilding;
  if (typeof refuserSiGele === 'function' && await refuserSiGele('terrain', id, 'Voler du matériel')) return;
  const ts = getTerrainState(id);
  const ch = ts.chantier;
  if (!ch) { showToast('Impossible', 'Aucun chantier en cours ici.', false); return; }
  const pays = state.country, ville = state.currentCity || 'capitale';

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  document.getElementById('modal-postes')?.classList.remove('open');

  // Bonus/malus de discretion du voleur : exactement les termes deja utilises par l'ancien jet,
  // simplement rebases sur 50 au lieu de 60. Aucune formule de discretion nouvelle.
  const dup = getStatEffective('DUP');
  const isn = (typeof getIndiceVille === 'function') ? getIndiceVille(pays, ville, 'isn')
            : ((typeof INDICES_NATIONAUX !== 'undefined' && INDICES_NATIONAUX[pays]?.ISN) || 30);
  let bonus = (dup - 10) * 2 - (isn - 45) / 3
            + (typeof getBonusReputationCriminelle === 'function' ? getBonusReputationCriminelle() : 0);
  if (typeof consommerBonusBenediction === 'function') bonus = consommerBonusBenediction(50 + bonus) - 50;

  // UN SEUL JET. La detection decoule du meme score final, jamais d'un second tirage.
  const jet = (Math.floor(Math.random() * 100) + 1) - 50;
  const score = scoreVolMateriaux(bonus, vigilesDuChantier(ch), jet);
  const verdict = verdictVolMateriaux(score);

  if (verdict.reussite) {
    const jourNum = numeroJourChantier(ch);
    const stock = ch.stockMateriaux || { bois: 0, minerai: 0, metal: 0 };
    const quantiteDemandee = quantiteVolMateriaux(score, matiere, jourNum, stock[matiere]);
    if (quantiteDemandee <= 0) { showToast('Rien à emporter', "Le stock a été vidé entre-temps.", false); return; }

    // LE STOCK EST REPLAFONNE SUR L'ETAT REEL, SOUS VERROU (10 octobre 2026). `qte` etait
    // plafonnee par le stock que CE navigateur avait lu : deux voleurs simultanes emportaient donc
    // chacun tout le stock, et un cache perime pouvait RESSUSCITER un stock que le cron avait
    // consomme. La porte rend la quantite REELLEMENT emportee -- c'est elle, et non `qte`, que
    // l'inventaire credite ci-dessous. Elle consigne aussi l'evenement, sans l'identite du voleur.
    const vVol = await sbTerrainActe('terrain_chantier_acte', {
      p_terrain_id: id, p_acte: 'chantier_materiaux_voler',
      p_matiere: matiere, p_quantite: quantiteDemandee, p_jour: state.day || 1
    });
    if (!vVol || vVol.ok !== true) {
      signalerRefusTerrain(vVol, 'Le vol de matériaux');
      return;
    }
    remplacerTerrainState(id, vVol.etat);
    const qte = Number(vVol.quantite) || 0;
    if (qte <= 0) { showToast('Rien à emporter', "Le stock a été vidé entre-temps.", false); return; }

    const res = (typeof RESSOURCES_ECONOMIE !== 'undefined' && RESSOURCES_ECONOMIE[matiere]) || {};
    if (typeof addToInventory === 'function') {
      addToInventory({ name: res.label || matiere, icon: res.icon, stackable: true, stackKey: matiere,
                       qty: qte, desc: 'Dérobé sur un chantier.' });
    }
    if (typeof modifierIndiceVille === 'function') modifierIndiceVille(pays, ville, 'social', -1);
    // Toujours tracable sur enquete, meme reussi -- mecanique existante, inchangee.
    if (typeof sbTracerAction === 'function') {
      await sbTracerAction({ id: 'vol-chantier-' + Date.now() + '-' + Math.floor(Math.random() * 1000),
        auteur: state.char?.name, cible: ts.proprietaire, type_action: 'vol_materiel_chantier',
        country: pays, city: ville, jour: state.day || 1, jour_expiration: (state.day || 1) + 15 }).catch(() => {});
    }
    if (typeof addExternalEvent === 'function') {
      addExternalEvent('Des matériaux ont disparu sur un chantier de la ville.', 'local');
    }
    updateUI();
    showToast('Vol réussi !', '+' + qte + ' ' + (res.label || matiere) + '.', true, true);
    addJournalEntry('Vol de matériaux réussi sur un chantier : ' + qte + ' ' + (res.label || matiere) + '.', 'event-good');
    return;
  }

  // ECHEC. Detecte ou non selon le MEME score, sans second jet.
  if (verdict.detecte) {
    // Trace judiciaire existante, a l'identique : avis de recherche, jamais une sanction ad hoc.
    if (!state.recherche) state.recherche = [];
    // Trace generique, meme forme que les autres actes illegaux (cambriolage_caisse, etc.) :
    // { acte, type, jour }. AUCUNE peine ad hoc : peineMaxJours n'etait lu par personne et le
    // type 'delit' n'existait dans aucune typologie. getPeineParActe lit ACTES_ILLEGAUX puis
    // applique le bareme generique du type -- ici delit_mineur, comme le vol ordinaire.
    const typeActe = (typeof ACTES_ILLEGAUX !== 'undefined' && ACTES_ILLEGAUX.vol_materiel_chantier)
      ? ACTES_ILLEGAUX.vol_materiel_chantier.type : 'delit_mineur';
    await inscrireRecherche({ acte: 'vol_materiel_chantier', type: typeActe, jour: state.day || 1 });
    if (typeof addExternalEvent === 'function') {
      addExternalEvent((state.char?.name || 'Quelqu\'un') + ' a été pris en flagrant délit de vol de matériel sur un chantier !', 'local');
    }
    addJournalEntry('Vol raté et découvert immédiatement. Avis de recherche émis contre vous (peine max 2 jours).', 'event-bad');
    showToast('Démasqué !', 'Avis de recherche émis (peine max 2 jours).', false);
    return;
  }

  // Echec discret : aucun transfert, aucune identification. La tentative reste tracable sur
  // enquete, comme avant, mais rien ne designe le voleur.
  if (typeof sbTracerAction === 'function') {
    await sbTracerAction({ id: 'voltentative-' + Date.now() + '-' + Math.floor(Math.random() * 1000),
      auteur: state.char?.name, cible: ts.proprietaire, type_action: 'tentative_vol_materiel_chantier',
      country: pays, city: ville, jour: state.day || 1, jour_expiration: (state.day || 1) + 15 }).catch(() => {});
  }
  addJournalEntry('Tentative de vol de matériaux manquée. Personne ne vous a vu.', 'event-info');
  showToast('Échec', 'Vous repartez les mains vides, mais personne ne vous a repéré.', false);
}

