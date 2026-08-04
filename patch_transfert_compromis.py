#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """// =====================
// SUBDIVISION DES COMMERCES PREMIUM / BUILDING
// ====================="""

new = """// =====================
// TRANSFERT DE COMPROMIS — validé chez le notaire, presence des deux parties requise (le
// detenteur initie, le destinataire doit lui-meme venir valider). Le delai restant se
// poursuit (pas de remise a 7 jours). L'acompte suit le compromis ; le remboursement entre
// joueurs se negocie hors mecanique automatique.
// =====================

async function doOuvrirTransfertCompromis() {
  const nom = state.char?.name;
  const candidats = [];
  for (const id of TERRAINS_LUTHECIA) {
    await chargerTerrainState(id);
    const ts = getTerrainState(id);
    if (ts.compromis && ts.compromisPar === nom) candidats.push({ id, ts });
  }

  if (candidats.length === 0) {
    showToast('Aucun compromis', "Vous ne détenez aucun compromis à transférer.", false);
    return;
  }

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem">Le délai restant se poursuit chez le nouveau détenteur (pas de remise à 7 jours). Réglez le remboursement de l\\'acompte entre vous.</div>';
  candidats.forEach(function(c) {
    const nomBatiment = BUILDINGS[c.id]?.shortName || c.id;
    const joursRestants = Math.ceil((c.ts.compromisExpireAt - Date.now()) / 86400000);
    html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.5rem">';
    html += '<div style="font-size:.85rem;color:#c0b090;margin-bottom:.4rem">' + nomBatiment + ' — ' + joursRestants + ' jour(s) restant(s)</div>';
    html += '<input id="transfert-nom-' + c.id + '" type="text" placeholder="Nom du nouveau détenteur..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-size:.78rem;outline:none;margin-bottom:.4rem" />';
    html += '<button class="pnj-action-btn" onclick="doInitierTransfertCompromis(\\'' + c.id + '\\')">Proposer le transfert</button>';
    html += '</div>';
  });
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Transférer un compromis';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function doInitierTransfertCompromis(id) {
  const destinataire = (document.getElementById('transfert-nom-' + id)?.value || '').trim();
  if (!destinataire) { showToast('Nom manquant', 'Indiquez le nom du nouveau détenteur.', false); return; }
  if (destinataire === state.char?.name) { showToast('Impossible', 'Vous ne pouvez pas vous transférer un compromis à vous-même.', false); return; }

  const ts = getTerrainState(id);
  const nouvelEtat = setTerrainState(id, { transfertPropose: destinataire, transfertProposePar: state.char?.name });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(() => {});

  if (typeof sendMail === 'function') {
    await sendMail(destinataire, 'Office Notarial', 'Transfert de compromis proposé',
      state.char?.name + ' vous propose de reprendre son compromis de vente sur ' + (BUILDINGS[id]?.shortName || id) + '. Rendez-vous à l\\'Office Notarial (Bureau des Contrats) pour valider le transfert. Le remboursement éventuel de l\\'acompte est à régler entre vous.');
  }

  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Transfert proposé', destinataire + ' doit se présenter chez le notaire pour valider.', true);
}

async function doValiderTransfertCompromis() {
  const nom = state.char?.name;
  const candidats = [];
  for (const id of TERRAINS_LUTHECIA) {
    await chargerTerrainState(id);
    const ts = getTerrainState(id);
    if (ts.transfertPropose === nom) candidats.push({ id, ts });
  }

  if (candidats.length === 0) {
    showToast('Aucune proposition', "Aucun transfert de compromis ne vous est proposé.", false);
    return;
  }

  let html = '<div style="padding:1rem">';
  candidats.forEach(function(c) {
    const nomBatiment = BUILDINGS[c.id]?.shortName || c.id;
    html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.5rem">';
    html += '<div style="font-size:.85rem;color:#c0b090;margin-bottom:.4rem">' + nomBatiment + ' — proposé par ' + c.ts.transfertProposePar + '</div>';
    html += '<button class="pnj-action-btn" onclick="doAccepterTransfertCompromis(\\'' + c.id + '\\')">Accepter le transfert</button>';
    html += '</div>';
  });
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Compromis proposé';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function doAccepterTransfertCompromis(id) {
  const ts = getTerrainState(id);
  const nouveauDetenteur = state.char?.name;
  const ancienDetenteur = ts.compromisPar;

  const patch = {
    compromisPar: nouveauDetenteur,
    transfertPropose: null,
    transfertProposePar: null
  };
  // Le permis et le pret, s'ils existent, suivent le nouveau detenteur (c'est lui qui achetera)
  if (ts.permis) patch.permis = { ...ts.permis, demandeur: nouveauDetenteur };
  if (ts.pretDemande) patch.pretDemande = { ...ts.pretDemande, demandeur: nouveauDetenteur };

  const nouvelEtat = setTerrainState(id, patch);
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(() => {});

  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Transfert validé !', 'Vous détenez désormais le compromis sur ' + (BUILDINGS[id]?.shortName || id) + '.', true, true);
  addJournalEntry('Compromis repris de ' + ancienDetenteur + ' sur ' + (BUILDINGS[id]?.shortName || id) + '.', 'event-good');
}

// =====================
// SUBDIVISION DES COMMERCES PREMIUM / BUILDING
// ====================="""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Transfert de compromis créé : proposition, validation chez le notaire, délai poursuivi.")
