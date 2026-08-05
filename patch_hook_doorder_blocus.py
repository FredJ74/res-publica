#!/usr/bin/env python3
PATH = "plateau-router.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function doOrder(fn, pa, cost, label, desc, successRate) {
  if (typeof queteAccueilNotifierOrdre === 'function') queteAccueilNotifierOrdre(fn);
  successRate = successRate || 70;
  const cur = COUNTRIES[state.char?.country || 'republic']?.cur || 'FR';"""
new = """function doOrder(fn, pa, cost, label, desc, successRate) {
  if (typeof queteAccueilNotifierOrdre === 'function') queteAccueilNotifierOrdre(fn);
  successRate = successRate || 70;
  const cur = COUNTRIES[state.char?.country || 'republic']?.cur || 'FR';

  // Blocus syndical : lecture SYNCHRONE d'un cache pose a l'entree dans la piece
  // (verifierBlocusEntree, plateau-organisations-quetes.js) — doOrder ne peut pas attendre
  // un appel reseau, donc on ne consulte jamais Supabase ici directement.
  if (typeof state !== 'undefined' && state.blocusActifIci && state.currentBuilding) {
    const roomBlocus = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
    const ordreDefBlocus = roomBlocus?.orders?.find(o => o.fn === fn);
    const entreeForceeBlocus = state.blocusEntreeResolueBuildingId === state.currentBuilding;

    if (ordreDefBlocus?.type === 'legal' && !entreeForceeBlocus) {
      showToast('Bloqué', 'Un blocus syndical empêche cette démarche ici. Forcez le passage pour continuer.', false);
      return;
    }
    if (ordreDefBlocus?.type === 'legal' && entreeForceeBlocus) {
      successRate = Math.min(95, successRate + (state.blocusModificateurLegal || 0));
    }
    if (ordreDefBlocus?.type === 'illegal') {
      successRate = Math.min(95, successRate + Math.round((state.blocusActifIci.intensite || 40) / 4));
    }
  }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Crochet blocus branché dans doOrder : legal bloqué (sauf passage forcé), illegal boosté.")
