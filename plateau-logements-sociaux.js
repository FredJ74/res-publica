// =====================================================================================
// LOGEMENTS SOCIAUX DU SOCLE (29/10/2026, décisions de Fred)
// -------------------------------------------------------------------------------------
// - La demande existe dans les trois mairies. S'il n'y a aucun logement social dans la ville,
//   le serveur répond « aucun_logement_social » avant tout prélèvement.
// - Les logements construits par la commune (petit bâtiment, bâtiment moyen, barre d'immeuble)
//   sont attribués par l'adjoint au maire, qui fixe aussi le loyer appartement par appartement.
// - Tout passe par le serveur : logements_sociaux_offre, logement_social_demander,
//   logements_sociaux_tableau, logement_social_attribuer, logement_social_loyer_fixer.
//   Les quatre appartements historiques de Montrouge gardent leur écran
//   (traiterDemandesLogementSocial, plateau-logements-montrouge.js), ouvert depuis ce tableau.
// =====================================================================================

function logementsSociauxEchapper(t) {
  return String(t == null ? '' : t).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

const LOGEMENTS_SOCIAUX_MOTIFS = {
  aucun_logement_social: "Il n'y a pas de logements sociaux dans la ville.",
  residence_requise: 'Seul un résident officiel de cette ville (domicile officiel) peut demander un logement social ici.',
  demande_deja_en_cours: 'Vous avez déjà une demande en attente dans cette ville.',
  pas_a_la_mairie: 'La demande se dépose à la mairie.',
  pa_insuffisants: 'Points d’action insuffisants.',
  reserve_adjoint: 'Réservé à l’adjoint au maire de la ville.',
  hors_commune: 'Ce logement n’appartient pas à votre commune.',
  logement_introuvable: 'Logement introuvable.',
  demande_introuvable: 'Cette demande n’est plus en attente.',
  local_occupe: 'Ce logement est déjà occupé.',
  premier_loyer_refuse: 'Le demandeur ne peut pas payer le premier loyer.',
  demandeur_non_resident: 'Le demandeur n\u2019est plus domicilié dans la ville.',
  loyer_invalide: 'Le loyer doit être un nombre entier positif.',
  attribution_refusee: 'Le serveur a refusé l’attribution.'
};
function logementsSociauxMotif(v) {
  if (!v || v.transport) return 'Réponse incertaine. Réessayez.';
  return LOGEMENTS_SOCIAUX_MOTIFS[v.raison] || ('Refus du serveur (' + v.raison + ').');
}

// Ordre « Déposer une demande de logement social » (trois mairies).
async function demanderLogementSocialCommun(pa, cost) {
  const offre = await sbRpcVerdict('logements_sociaux_offre', {}).catch(() => null);
  if (offre && offre.ok === true && offre.offre === false) {
    showToast('Logements sociaux', LOGEMENTS_SOCIAUX_MOTIFS.aucun_logement_social, false);
    return;
  }
  const bouton = (type, texte) => '<button onclick="confirmerDemandeLogementSocialCommun(' + (type ? '\'' + type + '\'' : 'null') + ')" style="padding:.6rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;text-align:left">' + texte + '</button>';
  document.getElementById('postes-modal-title').textContent = 'Demande de logement social';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem">'
    + '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem">Votre demande sera examinée par l’adjoint au maire. Vous pouvez indiquer une préférence.</div>'
    + '<div style="display:flex;flex-direction:column;gap:.4rem">'
    + bouton('petit', 'Petit appartement') + bouton('grand', 'Grand appartement') + bouton(null, 'Sans préférence')
    + '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerDemandeLogementSocialCommun(type) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const v = await sbRpcVerdict('logement_social_demander', { p_type: type || null }).catch(() => null);
  if (!v || v.ok !== true) { showToast('Demande non enregistrée', logementsSociauxMotif(v), false); return; }
  if (typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur(v);
  updateUI();
  showToast('Demande enregistrée', 'L’adjoint au maire examinera votre demande de logement social.', true, true);
  addJournalEntry('Demande de logement social déposée.', 'event-info');
}

// Tableau de bord de l'adjoint au maire.
async function ouvrirTableauLogementsSociaux() {
  document.getElementById('postes-modal-title').textContent = 'Logements sociaux';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');
  const v = await sbRpcVerdict('logements_sociaux_tableau', {}).catch(() => null);
  if (!v || v.ok !== true) {
    document.getElementById('modal-postes')?.classList.remove('open');
    showToast('Logements sociaux', logementsSociauxMotif(v), false);
    return;
  }
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const nomVille = (typeof WORLD !== 'undefined' && WORLD[v.pays]?.[v.ville]?.name) || v.ville;
  const appartements = Array.isArray(v.appartements) ? v.appartements : [];
  const demandes = Array.isArray(v.demandes) ? v.demandes : [];
  const libres = appartements.filter(a => !a.locataire);
  const nomBatiment = t => (typeof BUILDINGS !== 'undefined' && BUILDINGS[t]?.name) || t;
  const e = logementsSociauxEchapper;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.8rem">Logements de la commune de ' + e(nomVille) + '. Les loyers sont versés à la caisse de la mairie ; chaque changement de loyer est inscrit dans l’historique du bâtiment.</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;color:#C9A84C;margin:.4rem 0">Appartements (' + appartements.length + ')</div>';
  if (appartements.length === 0) {
    html += '<div style="font-size:.8rem;color:#6a6040;font-style:italic;margin-bottom:.6rem">Aucun logement social construit par la commune pour l’instant.</div>';
  }
  appartements.forEach(a => {
    const cle = e(a.terrain) + '|' + e(a.lot);
    html += '<div style="display:flex;justify-content:space-between;align-items:center;gap:.4rem;padding:.4rem .5rem;border:1px solid #2a2010;margin-bottom:.3rem;font-size:.78rem;color:#c0b090">'
      + '<div><div>' + e(a.label) + ' <span style="color:#6a6040">— ' + e(nomBatiment(a.terrain)) + '</span></div>'
      + '<div style="color:' + (a.locataire ? '#8a8060' : '#6a8a50') + '">' + (a.locataire ? 'Occupé par ' + e(a.locataire) : 'Libre') + '</div></div>'
      + '<div style="display:flex;align-items:center;gap:.3rem;white-space:nowrap"><input id="loyer-social-' + cle + '" type="number" min="1" step="1" value="' + Number(a.loyer || 0) + '" style="width:4.5rem;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.2rem .3rem">'
      + '<span style="color:#6a6040">' + cur + '</span>'
      + '<button onclick="fixerLoyerLogementSocial(\'' + e(a.terrain) + '\',\'' + e(a.lot) + '\')" style="font-size:.7rem;padding:.2rem .5rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Fixer</button></div></div>';
  });
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;color:#C9A84C;margin:.8rem 0 .4rem">Demandes en attente (' + demandes.length + ')</div>';
  if (demandes.length === 0) html += '<div style="font-size:.8rem;color:#6a6040;font-style:italic">Aucune demande en attente.</div>';
  demandes.forEach(d => {
    const options = libres.map(a => '<option value="' + e(a.terrain) + '|' + e(a.lot) + '">' + e(a.label) + ' — ' + e(nomBatiment(a.terrain)) + ' (' + Number(a.loyer || 0) + ' ' + cur + ')</option>').join('');
    html += '<div style="padding:.4rem .5rem;border:1px solid #2a2010;margin-bottom:.3rem;font-size:.78rem;color:#c0b090">'
      + '<div>' + e(d.demandeur) + ' <span style="color:#6a6040">— souhaite : ' + (d.type === 'petit' ? 'petit' : d.type === 'grand' ? 'grand' : 'sans préférence') + '</span></div>'
      + (libres.length
        ? '<div style="display:flex;gap:.3rem;margin-top:.3rem"><select id="attrib-social-' + e(d.id) + '" style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.2rem">' + options + '</select>'
          + '<button onclick="attribuerLogementSocialCommun(\'' + e(d.id) + '\')" style="font-size:.7rem;padding:.2rem .5rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Attribuer</button></div>'
        : '<div style="color:#6a6040;font-style:italic;margin-top:.2rem">Aucun appartement libre.</div>')
      + '</div>';
  });
  if (v.logementsMontrouge && typeof traiterDemandesLogementSocial === 'function') {
    html += '<button onclick="traiterDemandesLogementSocial(0,0)" style="width:100%;margin-top:.8rem;padding:.5rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer">Logements historiques de Montrouge</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function fixerLoyerLogementSocial(terrain, lot) {
  const brut = document.getElementById('loyer-social-' + terrain + '|' + lot)?.value;
  const loyer = Number(brut);
  if (!Number.isSafeInteger(loyer) || loyer < 1) { showToast('Loyer invalide', LOGEMENTS_SOCIAUX_MOTIFS.loyer_invalide, false); return; }
  const v = await sbRpcVerdict('logement_social_loyer_fixer', { p_terrain: terrain, p_lot: lot, p_loyer: loyer }).catch(() => null);
  if (!v || v.ok !== true) { showToast('Loyer non modifié', logementsSociauxMotif(v), false); return; }
  showToast('Loyer fixé', v.ancien + ' → ' + v.loyer + (v.occupe ? ' (bail en cours mis à jour)' : ''), true);
  addJournalEntry('Loyer social modifié (' + lot + ') : ' + v.ancien + ' → ' + v.loyer + '.', 'event-info');
  ouvrirTableauLogementsSociaux();
}

async function attribuerLogementSocialCommun(demandeId) {
  const choix = document.getElementById('attrib-social-' + demandeId)?.value || '';
  const [terrain, lot] = choix.split('|');
  if (!terrain || !lot) return;
  const v = await sbRpcVerdict('logement_social_attribuer', { p_terrain: terrain, p_lot: lot, p_demande: demandeId }).catch(() => null);
  if (!v || v.ok !== true) { showToast('Attribution refusée', logementsSociauxMotif(v), false); return; }
  showToast('Logement attribué', v.beneficiaire + ' est informé par courrier.', true, true);
  addJournalEntry('Logement social attribué à ' + v.beneficiaire + '.', 'event-good');
  ouvrirTableauLogementsSociaux();
}
