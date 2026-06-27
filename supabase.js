
// =====================
// VOLS EN ATTENTE (vol effectif sur un vrai joueur, applique a sa prochaine connexion)
// =====================
async function sbDeposerVol(vol) {
  return sbInsert('vols_en_attente', vol);
}

async function sbRecupererVolsEnAttente(victime) {
  const filtre = `victime=eq.${encodeURIComponent(victime)}&traite=eq.false`;
  return sbGet('vols_en_attente', filtre) || [];
}

async function sbMarquerVolTraite(volId) {
  return sbUpdate('vols_en_attente', `id=eq.${encodeURIComponent(volId)}`, { traite: true });
}
