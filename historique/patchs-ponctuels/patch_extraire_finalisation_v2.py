#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """async function doAcheterTerrainOld_DEAD(id) {
  const ts = getTerrainState(id);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const b = BUILDINGS[id];
  const localName = b?.shortName || b?.name || id;

  const surface = SURFACE_TERRAINS[id] || 2000;
  const prix = surface * PRIX_AU_M2_TERRAIN;

  state.arg -= prix;

  // Synchroniser aussi avec Supabase pour que le terrain soit reellement marque "occupe"
  // Si le joueur est marie, son conjoint devient automatiquement coproprietaire a 50%
  (async () => {
    let coproprietaire = null;
    if (typeof sbGetMariageActif === 'function') {
      try {
        const mariage = await sbGetMariageActif(state.char?.name);
        if (mariage) {
          coproprietaire = mariage.conjoint1 === state.char?.name ? mariage.conjoint2 : mariage.conjoint1;
        }
      } catch(e) {}
    }
    if (typeof sbSetTerrainState === 'function') {
      await sbSetTerrainState(state.country, id, { proprietaire: state.char?.name, coproprietaire, surface, valeur_totale: prix, dette_fonciere: 0, city: state.currentCity || 'capitale' }).catch(() => {});
    }
    if (typeof sbEnregistrerVenteTerrain === 'function') {
      await sbEnregistrerVenteTerrain(state.country, id, state.char?.name, prix).catch(() => {});
    }
    if (coproprietaire) {
      showToast('Bien partagé', coproprietaire + ' devient copropriétaire à 50% de ce terrain.', true);
      addJournalEntry('Terrain acheté en copropriété avec ' + coproprietaire + ' (50/50).', 'event-good');
    }
  })();

  const aPermis = ts.permis;
  setTerrainState(id, {
    proprietaire: state.char?.name,
    acheteAt: Date.now(),
    constructionAutorisee: !!aPermis,
    surface: surface,
    valeur_totale: prix,
    dette_fonciere: 0,
    city: state.currentCity || 'capitale'
  });

  updateUI();
  if (!aPermis) {
    addJournalEntry('Terrain ' + localName + ' acheté pour ' + prix + ' ' + cur + '. SANS permis — construction bloquée jusqu\\'autorisation du maire.', 'event-info');
    showToast('Terrain acheté !', 'Sans permis : construction bloquée. Demandez l\\'autorisation au maire.', true);
  } else {
    addJournalEntry('Terrain ' + localName + ' acheté pour ' + prix + ' ' + cur + '. Permis valide.', 'event-good');
    showToast('Terrain acheté !', 'Avec permis. Construction autorisée.', true);
  }
}"""

new = """// Finalise reellement l'acquisition d'un terrain (proprietaire, surface, valeur, Supabase,
// copropriete du conjoint). Reutilisee par la signature chez le notaire, que ce soit a
// l'issue d'un compromis ou d'un achat direct avec rendez-vous.
async function finaliserAchatTerrain(id, prix, surface, aPermis) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const b = BUILDINGS[id];
  const localName = b?.shortName || b?.name || id;

  let coproprietaire = null;
  if (typeof sbGetMariageActif === 'function') {
    try {
      const mariage = await sbGetMariageActif(state.char?.name);
      if (mariage) {
        coproprietaire = mariage.conjoint1 === state.char?.name ? mariage.conjoint2 : mariage.conjoint1;
      }
    } catch(e) {}
  }

  const nouvelEtat = setTerrainState(id, {
    proprietaire: state.char?.name,
    coproprietaire: coproprietaire,
    acheteAt: Date.now(),
    constructionAutorisee: !!aPermis,
    surface: surface,
    valeur_totale: prix,
    dette_fonciere: 0,
    city: state.currentCity || 'capitale'
  });
  if (typeof sbSetTerrainState === 'function') {
    await sbSetTerrainState(state.country, id, nouvelEtat).catch(() => {});
  }
  if (typeof sbEnregistrerVenteTerrain === 'function') {
    await sbEnregistrerVenteTerrain(state.country, id, state.char?.name, prix).catch(() => {});
  }

  updateUI();
  if (coproprietaire) {
    showToast('Bien partagé', coproprietaire + ' devient copropriétaire à 50% de ce terrain.', true);
    addJournalEntry('Terrain acheté en copropriété avec ' + coproprietaire + ' (50/50).', 'event-good');
  }
  if (!aPermis) {
    addJournalEntry('Terrain ' + localName + ' acheté pour ' + prix + ' ' + cur + '. SANS permis — construction bloquée jusqu\\'autorisation du maire.', 'event-info');
    showToast('Terrain acheté !', 'Sans permis : construction bloquée. Demandez l\\'autorisation au maire.', true);
  } else {
    addJournalEntry('Terrain ' + localName + ' acheté pour ' + prix + ' ' + cur + '. Permis valide.', 'event-good');
    showToast('Terrain acheté !', 'Avec permis. Construction autorisée.', true);
  }
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ finaliserAchatTerrain() créée proprement (plus de code mort).")
