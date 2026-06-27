
// =====================
// IMPACTS D'INDICES EN ATTENTE (generique, applique a la victime a sa prochaine connexion)
// =====================
async function sbDeposerImpactIndice(impact) {
  return sbInsert('impacts_indices_attente', impact);
}

async function sbRecupererImpactsEnAttente(victime) {
  const filtre = `victime=eq.${encodeURIComponent(victime)}&traite=eq.false`;
  return sbGet('impacts_indices_attente', filtre) || [];
}

async function sbMarquerImpactTraite(impactId) {
  return sbUpdate('impacts_indices_attente', `id=eq.${encodeURIComponent(impactId)}`, { traite: true });
}
