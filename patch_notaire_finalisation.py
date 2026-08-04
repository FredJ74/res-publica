#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """// =====================
// SUBDIVISION DES COMMERCES PREMIUM / BUILDING
// ====================="""

new = """// =====================
// ACTE DE VENTE — NOTAIRE (finalisation d'un compromis ou d'un achat direct avec rendez-vous)
// =====================
const TERRAINS_LUTHECIA = ['terrain-a-batir-1', 'terrain-a-batir-2', 'terrain-a-batir-3', 'terrain-a-batir-4', 'terrain-a-batir-5'];

async function doActeVenteTerrain() {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const nom = state.char?.name;

  // Trouver les terrains ou ce joueur a une reservation active (compromis ou achat direct)
  const candidats = [];
  for (const id of TERRAINS_LUTHECIA) {
    await chargerTerrainState(id);
    const ts = getTerrainState(id);
    if (ts.compromis && ts.compromisPar === nom) candidats.push({ id, type: 'compromis', ts });
    else if (ts.achatDirect && ts.achatDirect.demandeur === nom) candidats.push({ id, type: 'achatDirect', ts });
  }

  if (candidats.length === 0) {
    showToast('Aucune réservation', "Vous n'avez ni compromis ni rendez-vous d'achat en cours sur un terrain.", false);
    return;
  }

  if (candidats.length === 1) { traiterActeVente(candidats[0]); return; }

  let html = '<div style="padding:1rem"><div style="display:flex;flex-direction:column;gap:.4rem">';
  candidats.forEach(function(c, i) {
    const nomBatiment = BUILDINGS[c.id]?.shortName || c.id;
    html += '<div onclick="traiterActeVenteParIndex(' + i + ')" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05">' + nomBatiment + ' (' + (c.type === 'compromis' ? 'compromis' : 'rendez-vous notarial') + ')</div>';
  });
  html += '</div></div>';
  window._candidatsActeVente = candidats;
  document.getElementById('postes-modal-title').textContent = 'Quel terrain ?';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function traiterActeVenteParIndex(i) {
  traiterActeVente(window._candidatsActeVente[i]);
}

async function traiterActeVente(candidat) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const id = candidat.id;
  const ts = candidat.ts;

  if (candidat.type === 'achatDirect') {
    const ad = ts.achatDirect;
    if (Date.now() < ad.dateAchat) {
      showToast('Trop tôt', 'Votre rendez-vous n\\'est pas encore arrivé.', false);
      return;
    }
    if (Date.now() > ad.dateLimite) {
      showToast('Rendez-vous manqué', 'Le délai de rattrapage de 24h est dépassé. Le dépôt est perdu.', false);
      return;
    }
    const solde = ad.prix - ad.acompte;
    if (state.arg < solde) {
      showToast('Fonds insuffisants', solde.toLocaleString('fr-FR') + ' ' + cur + ' restants à payer.', false);
      return;
    }
    state.arg -= solde;
    await finaliserAchatTerrain(id, ad.prix, ad.surface, false);
    setTerrainState(id, { achatDirect: null });
    if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, { achatDirect: null }).catch(() => {});
    document.getElementById('modal-postes')?.classList.remove('open');
    showToast('Acte signé !', 'Propriétaire de ' + (BUILDINGS[id]?.shortName || id) + '.', true, true);
    return;
  }

  // Compromis
  const permisOk = !ts.permis || ts.permis.statut === 'valide';
  const pretOk = !ts.pretDemande || ts.pretDemande.statut === 'accorde' || ts.pretDemande.statut === undefined;
  const pretEnAttente = ts.pretDemande && ts.pretDemande.statut === 'attente_validation';
  const permisEnAttente = ts.permis && ts.permis.statut === 'attente_validation';
  const refuse = (ts.permis && ts.permis.statut === 'refuse') || (ts.pretDemande && ts.pretDemande.statut === 'refuse');

  if (refuse) {
    showToast('Compromis caduc', 'Une clause a été refusée. Votre acompte a normalement déjà été remboursé.', false);
    return;
  }
  if (permisEnAttente || pretEnAttente) {
    showToast('Clauses en attente', 'Le permis et/ou le prêt ne sont pas encore tranchés. Revenez après leur décision.', false);
    return;
  }

  const solde = ts.valeur_totale - (ts.acompte || 0);
  if (state.arg < solde) {
    showToast('Fonds insuffisants', solde.toLocaleString('fr-FR') + ' ' + cur + ' restants à payer.', false);
    return;
  }
  state.arg -= solde;
  await finaliserAchatTerrain(id, ts.valeur_totale, ts.surface, ts.constructionAutorisee);
  const clear = { compromis: null, compromisPar: null, acompte: null, compromisAt: null, compromisExpireAt: null };
  setTerrainState(id, clear);
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, clear).catch(() => {});
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Acte signé !', 'Propriétaire de ' + (BUILDINGS[id]?.shortName || id) + '. Acompte déduit du prix.', true, true);
}

// =====================
// SUBDIVISION DES COMMERCES PREMIUM / BUILDING
// ====================="""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Finalisation notariale créée (achat direct avec rendez-vous, compromis avec clauses levées).")
