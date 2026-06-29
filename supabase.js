
// =====================
// PRETS BANCAIRES
// =====================
async function sbCreerPret(pret) {
  return sbInsert('prets_bancaires', pret);
}

async function sbGetPretsEnCours(emprunteur) {
  return sbGet('prets_bancaires', `emprunteur=eq.${encodeURIComponent(emprunteur)}&statut=eq.en_cours`) || [];
}

async function sbUpdatePret(pretId, data) {
  return sbUpdate('prets_bancaires', `id=eq.${encodeURIComponent(pretId)}`, data);
}

// =====================
// MARIAGE
// =====================
async function sbCreerDemandeMariage(demande) {
  return sbInsert('demandes_mariage', demande);
}

async function sbGetDemandesMariagePour(destinataire) {
  return sbGet('demandes_mariage', `destinataire=eq.${encodeURIComponent(destinataire)}&statut=eq.en_attente`) || [];
}

async function sbUpdateDemandeMariage(id, statut) {
  return sbUpdate('demandes_mariage', `id=eq.${encodeURIComponent(id)}`, { statut });
}

async function sbCreerMariage(mariage) {
  return sbInsert('mariages', mariage);
}

async function sbGetMariageActif(nomJoueur) {
  const rows = await sbGet('mariages', `statut=eq.actif&or=(conjoint1.eq.${encodeURIComponent(nomJoueur)},conjoint2.eq.${encodeURIComponent(nomJoueur)})`);
  return (rows && rows.length > 0) ? rows[0] : null;
}

async function sbDissoudreMariage(id) {
  return sbUpdate('mariages', `id=eq.${encodeURIComponent(id)}`, { statut: 'dissous' });
}

// =====================
// TERRAINS — biens partages (coproprietaire pour le mariage)
// =====================
async function sbGetTousLesBiensDe(nomProprietaire) {
  const rows = await sbGet('terrains_etat', `proprietaire=eq.${encodeURIComponent(nomProprietaire)}`);
  return rows || [];
}
