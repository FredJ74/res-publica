#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Verrouillage du terrain pour les autres joueurs si compromis actif ---
old_1 = """  // Compromis requis avant permis
  if (fn === 'permis_construire' || fn === 'permis_corrompu') {
    if (!ts.compromis) return { ok: false, raison: 'Signez d\\'abord un compromis de vente.' };
  }

  return { ok: true };
}"""
new_1 = """  // Terrain verrouille pour les autres joueurs tant qu'un compromis est actif (non expire)
  const compromisActif = ts.compromis && ts.compromisExpireAt && Date.now() < ts.compromisExpireAt;
  if (compromisActif && ts.compromisPar !== state.char?.name) {
    if (fn === 'acheter_terrain' || fn === 'signer_compromis') {
      return { ok: false, raison: 'Un compromis de vente est déjà en cours sur ce terrain (détenu par ' + ts.compromisPar + ').' };
    }
  }

  return { ok: true };
}"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- 2. Acompte 1000 FR + qui detient le compromis ---
old_2 = """function doSignerCompromis() {
  const id = state.currentBuilding;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  const dispo = terrainOrdreDisponible('signer_compromis', id);
  if (!dispo.ok) { showToast('Impossible', dispo.raison, false); return; }

  setTerrainState(id, {
    compromis: true,
    compromisAt: Date.now(),
    compromisExpireAt: Date.now() + 7 * 86400000
  });
  state.arg -= 500;
  updateUI();
  addJournalEntry('Compromis de vente signé pour 500 ' + cur + '. Valable 7 jours.', 'event-good');
  showToast('Compromis signé !', 'Terrain réservé 7 jours. -500 ' + cur, true);
}"""
new_2 = """const ACOMPTE_COMPROMIS = 1000;

async function doSignerCompromis() {
  const id = state.currentBuilding;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  const dispo = terrainOrdreDisponible('signer_compromis', id);
  if (!dispo.ok) { showToast('Impossible', dispo.raison, false); return; }
  if (state.arg < ACOMPTE_COMPROMIS) {
    showToast('Fonds insuffisants', ACOMPTE_COMPROMIS + ' ' + cur + ' requis pour l\\'acompte.', false);
    return;
  }

  const nouvelEtat = setTerrainState(id, {
    compromis: true,
    compromisPar: state.char?.name,
    acompte: ACOMPTE_COMPROMIS,
    compromisAt: Date.now(),
    compromisExpireAt: Date.now() + 7 * 86400000
  });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(() => {});

  state.arg -= ACOMPTE_COMPROMIS;
  updateUI();
  addJournalEntry('Compromis de vente signé pour ' + ACOMPTE_COMPROMIS + ' ' + cur + '. Valable 7 jours.', 'event-good');
  showToast('Compromis signé !', 'Terrain réservé 7 jours. -' + ACOMPTE_COMPROMIS + ' ' + cur, true);
}"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Fondations du compromis : verrouillage du terrain, acompte à 1000 FR, détenteur identifié.")
