
// =====================
// QUETES ACTIVES (animation plateau)
// =====================
async function sbGetQueteActive(country) {
  const rows = await sbGet('quetes_actives', `country=eq.${encodeURIComponent(country)}&statut=eq.active`);
  return (rows && rows.length > 0) ? rows[0] : null;
}

async function sbCreerQuete(quete) {
  return sbInsert('quetes_actives', quete);
}

async function sbMettreAJourQuete(queteId, data) {
  return sbUpdate('quetes_actives', `id=eq.${encodeURIComponent(queteId)}`, data);
}

async function sbGetDerniereQueteResolue(country) {
  const rows = await sbGet('quetes_actives', `country=eq.${encodeURIComponent(country)}&statut=eq.resolue&order=created_at.desc&limit=1`);
  return (rows && rows.length > 0) ? rows[0] : null;
}
