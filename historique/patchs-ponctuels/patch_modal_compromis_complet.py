#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """const ACOMPTE_COMPROMIS = 1000;

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

new = """const ACOMPTE_COMPROMIS = 1000;
const PLAFOND_PRET_COMPROMIS = 150000;

// Ouvre une seule fenetre combinant les 3 clauses du compromis : acompte (obligatoire),
// demande de pret (optionnelle), demande de permis (optionnelle). Tout est lance en un clic,
// resolu de facon atomique a J+7 (voir resoudreCompromisExpires, cote cron).
async function doSignerCompromis() {
  const id = state.currentBuilding;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  const dispo = terrainOrdreDisponible('signer_compromis', id);
  if (!dispo.ok) { showToast('Impossible', dispo.raison, false); return; }
  if (state.arg < ACOMPTE_COMPROMIS) {
    showToast('Fonds insuffisants', ACOMPTE_COMPROMIS + ' ' + cur + ' requis pour l\\'acompte.', false);
    return;
  }

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem">Le compromis réserve ce terrain 7 jours. À l\\'échéance, les clauses ci-dessous sont tranchées automatiquement (banque, mairie).</div>';

  html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.6rem">';
  html += '<div style="font-size:.85rem;color:#c0b090">✓ Versement de l\\'acompte</div>';
  html += '<div style="font-size:.72rem;color:#6a5a30">' + ACOMPTE_COMPROMIS + ' ' + cur + ' — déduits du prix final à la vente, ou remboursés/perdus selon l\\'issue.</div>';
  html += '</div>';

  html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.6rem">';
  html += '<label style="display:flex;align-items:center;gap:.4rem;font-size:.85rem;color:#c0b090;cursor:pointer"><input type="checkbox" id="compromis-pret-check" onchange="document.getElementById(\\'compromis-pret-champs\\').style.display=this.checked?\\'block\\':\\'none\\'" /> Demander un prêt à la Banque Nationale</label>';
  html += '<div id="compromis-pret-champs" style="display:none;margin-top:.5rem">';
  html += '<div style="display:flex;gap:.4rem">';
  html += '<input id="compromis-pret-montant" type="number" placeholder="Montant (max ' + PLAFOND_PRET_COMPROMIS.toLocaleString('fr-FR') + ')" style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-size:.78rem;outline:none" />';
  html += '<input id="compromis-pret-duree" type="number" placeholder="Durée (jours)" value="30" style="width:120px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-size:.78rem;outline:none" />';
  html += '</div>';
  html += '</div>';
  html += '</div>';

  html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.8rem">';
  html += '<label style="display:flex;align-items:center;gap:.4rem;font-size:.85rem;color:#c0b090;cursor:pointer"><input type="checkbox" id="compromis-permis-check" onchange="document.getElementById(\\'compromis-permis-champs\\').style.display=this.checked?\\'block\\':\\'none\\'" /> Demander un permis de construire</label>';
  html += '<div id="compromis-permis-champs" style="display:none;margin-top:.5rem">';
  html += '<select id="compromis-permis-type" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-size:.78rem;outline:none">';
  Object.entries(NIVEAUX_CONSTRUCTION || {}).forEach(function([key, niv]) {
    html += '<option value="' + key + '">' + niv.label + ' (' + niv.cout.toLocaleString('fr-FR') + ' ' + cur + ')</option>';
  });
  html += '</select>';
  html += '</div>';
  html += '</div>';

  html += '<button class="pnj-action-btn" onclick="doConfirmerCompromis()">Signer le compromis</button>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Compromis de vente';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function doConfirmerCompromis() {
  const id = state.currentBuilding;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  const demandePret = document.getElementById('compromis-pret-check')?.checked;
  const montantPret = parseInt(document.getElementById('compromis-pret-montant')?.value || 0);
  const dureePret = parseInt(document.getElementById('compromis-pret-duree')?.value || 30);
  const demandePermis = document.getElementById('compromis-permis-check')?.checked;
  const typePermis = document.getElementById('compromis-permis-type')?.value;

  if (demandePret && (!montantPret || montantPret < 1000 || montantPret > PLAFOND_PRET_COMPROMIS)) {
    showToast('Montant invalide', 'Entre 1000 et ' + PLAFOND_PRET_COMPROMIS.toLocaleString('fr-FR') + ' ' + cur + '.', false);
    return;
  }

  const patch = {
    compromis: true,
    compromisPar: state.char?.name,
    acompte: ACOMPTE_COMPROMIS,
    compromisAt: Date.now(),
    compromisExpireAt: Date.now() + 7 * 86400000
  };

  if (demandePret) {
    const taux = typeof getTauxPret === 'function' ? getTauxPret('nationale') : 5;
    const montantTotal = Math.round(montantPret * (1 + taux / 100));
    patch.pretDemande = {
      demandeur: state.char?.name,
      montant: montantPret,
      montantTotal: montantTotal,
      duree: dureePret,
      mensualite: Math.ceil(montantTotal / dureePret),
      statut: 'attente_validation'
    };
  }
  if (demandePermis && typePermis) {
    patch.permis = {
      demandeur: state.char?.name,
      palierDemande: typePermis,
      statut: 'attente_validation',
      dateEntreeAttente: Date.now()
    };
  }

  const nouvelEtat = setTerrainState(id, patch);
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(() => {});

  state.arg -= ACOMPTE_COMPROMIS;
  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  addJournalEntry('Compromis de vente signé pour ' + ACOMPTE_COMPROMIS + ' ' + cur + '. Valable 7 jours.' + (demandePret ? ' Prêt demandé.' : '') + (demandePermis ? ' Permis demandé.' : ''), 'event-good');
  showToast('Compromis signé !', 'Terrain réservé 7 jours. -' + ACOMPTE_COMPROMIS + ' ' + cur, true);
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Fenêtre unifiée du compromis créée (acompte + prêt optionnel + permis optionnel, en un clic).")
