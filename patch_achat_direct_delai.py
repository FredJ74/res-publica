#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function doAcheterTerrain() {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const b = BUILDINGS[id];
  const localName = b?.shortName || b?.name || id;

  const dispo = terrainOrdreDisponible('acheter_terrain', id);
  if (!dispo.ok) { showToast('Impossible', dispo.raison, false); return; }

  const surface = SURFACE_TERRAINS[id] || 2000;
  const prix = surface * PRIX_AU_M2_TERRAIN;
  if (state.arg < prix) { showToast('Fonds insuffisants', prix.toLocaleString('fr-FR') + ' ' + cur + ' requis. Pensez au prêt bancaire.', false); return; }

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
  if (!aPermis) {"""

new = """const ACOMPTE_ACHAT_DIRECT = 1000;

// Achat direct (sans compromis) : depot de garantie immediat, rendez-vous chez le notaire
// fixe a une date aleatoire (2 a 7 jours), avec 24h de rattrapage si le jour venu le joueur
// n'est pas passe finaliser. Le solde du prix (moins l'acompte) est paye au notaire, pas ici.
async function doAcheterTerrain() {
  const id = state.currentBuilding;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  const dispo = terrainOrdreDisponible('acheter_terrain', id);
  if (!dispo.ok) { showToast('Impossible', dispo.raison, false); return; }
  if (state.arg < ACOMPTE_ACHAT_DIRECT) {
    showToast('Fonds insuffisants', ACOMPTE_ACHAT_DIRECT + ' ' + cur + ' requis pour le dépôt de garantie.', false);
    return;
  }

  const surface = SURFACE_TERRAINS[id] || 2000;
  const prix = surface * PRIX_AU_M2_TERRAIN;
  const delaiJours = 2 + Math.floor(Math.random() * 6); // 2 a 7 jours
  const dateAchat = Date.now() + delaiJours * 86400000;
  const dateLimite = dateAchat + 24 * 3600000;

  state.arg -= ACOMPTE_ACHAT_DIRECT;

  const nouvelEtat = setTerrainState(id, {
    achatDirect: {
      demandeur: state.char?.name,
      acompte: ACOMPTE_ACHAT_DIRECT,
      prix: prix,
      surface: surface,
      dateAchat: dateAchat,
      dateLimite: dateLimite
    }
  });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(() => {});

  const dateTxt = new Date(dateAchat).toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' });
  updateUI();
  addJournalEntry('Dépôt de garantie versé (' + ACOMPTE_ACHAT_DIRECT + ' ' + cur + '). Rendez-vous chez le notaire fixé au ' + dateTxt + ' pour finaliser l\\'achat.', 'event-good');
  showToast('Dépôt versé !', 'Rendez-vous chez le notaire le ' + dateTxt + '. -' + ACOMPTE_ACHAT_DIRECT + ' ' + cur, true);
  if (typeof sendMail === 'function') {
    await sendMail(state.char?.name, 'Office Notarial', 'Rendez-vous fixé — achat de terrain',
      'Votre rendez-vous pour la signature de l\\'acte de vente est fixé au ' + dateTxt + '. Présentez-vous à l\\'Office Notarial ce jour-là (une tolérance de 24h est accordée en cas d\\'absence). Passé ce délai, le dépôt de garantie sera perdu et le terrain remis en vente.');
  }
}

async function doAcheterTerrainOld_DEAD(id) {
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
  if (!aPermis) {"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Achat direct refondu : dépôt de garantie + délai aléatoire 2-7 jours + notification. Ancienne logique conservée temporairement (finalisation notaire à construire ensuite).")
