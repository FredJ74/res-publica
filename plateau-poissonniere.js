// =====================================================================
// MARCHANDE DE POISSONS DE NOVOMIRSK (decisions de Fred, 06/11/2026)
// =====================================================================
// Galina Karpova vend le poisson de riviere peche par son mari (12 par jour pour toute la ville) et,
// sous l'etal, l'alcool et les medicaments de Republia qu'il fait passer par la riviere (illegal).
// Tout est decide par le serveur (poissonniere_etat, poissonniere_acheter_poisson,
// poissonniere_acheter_contrebande, migration 20261106172000) : presence, prix, reste du jour,
// fonds, place, PA, detection. L'ecran n'affiche que ce que le serveur renvoie.

const MOTIFS_POISSONNIERE = {
  quota_epuise: '« Désolé, il faut que mon mari relève les filets, on a tout vendu la précédente pêche. »',
  quota_insuffisant: '« Il ne m\'en reste pas autant, mon mari n\'a pas encore relevé les filets. »',
  arrivage_epuise: '« Rien aujourd\'hui. La rivière est surveillée, mon mari attend la nuit. »',
  arrivage_insuffisant: '« Je n\'en ai pas autant sous l\'étal. »',
  etal_repris: 'Galina ne tient plus cet étal.',
  quantite_invalide: 'Indiquez une quantité entière, au moins 1.',
  ressource_inconnue: 'Cette marchandise n\'est pas proposée.',
  acteur_indisponible: 'Vous n\'êtes pas en état de le faire.'
};

function refusPoissonniere(v) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  let m = MOTIFS_POISSONNIERE[v?.raison];
  if (v?.raison === 'fonds_insuffisants') m = Math.round(v.requis || 0) + ' ' + cur + ' requis, vous avez ' + Math.round(v.disponible || 0) + ' ' + cur + '.';
  if (!m) return false;
  if (v?.restant != null && /insuffisant/.test(v.raison)) m += ' (reste : ' + v.restant + ')';
  showToast('Galina Karpova', m, false);
  return true;
}

function fermerPoissonniere() { document.getElementById('modal-postes')?.classList.remove('open'); }

async function ouvrirPoissonniere(mode) {
  let e = null;
  try {
    const r = await sbRpc('poissonniere_etat', {});
    e = Array.isArray(r) ? r[0] : r;
    if (e && e.poissonniere_etat) e = e.poissonniere_etat;
  } catch (_) {}
  if (!e) { showToast('Étal indisponible', 'Impossible de lire l\'étal pour l\'instant.', false); return; }
  if (e.etal_pnj === false) { refusPoissonniere({ raison: 'etal_repris' }); return; }
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const reste = mode === 'poisson' ? e.poisson_restant : e.contrebande_restant;
  if (reste <= 0) { refusPoissonniere({ raison: mode === 'poisson' ? 'quota_epuise' : 'arrivage_epuise' }); return; }

  document.getElementById('postes-modal-title').textContent = mode === 'poisson' ? 'Poisson de rivière' : 'Poisson « de l\'autre rive »';
  let html = '<div class="cpj-dialogue" style="padding:1rem">';
  if (mode === 'poisson') {
    html += '<div class="cpj-note" style="margin-bottom:.8rem">« Pêché ce matin par mon mari. Moins cher qu\'à l\'entrepôt, mais quand il n\'y en a plus, il n\'y en a plus. »</div>';
    html += '<div class="cpj-note" style="margin-bottom:.8rem">Prix : ' + e.prix_poisson + ' ' + cur + ' le poisson. Il en reste ' + reste + ' aujourd\'hui.</div>';
  } else {
    html += '<div class="cpj-note" style="margin-bottom:.8rem">Galina baisse la voix : « Ça vient de l\'autre rive. Pas de facture, pas de tampon, et vous ne m\'avez rien acheté. »</div>';
    html += '<select id="poissonniere-cle" class="cpj-champ" style="width:100%;margin-bottom:.6rem">'
      + '<option value="alcool">Alcool — ' + e.prix_alcool + ' ' + cur + ' l\'unité</option>'
      + '<option value="medicaments">Médicaments — ' + e.prix_medicaments + ' ' + cur + ' l\'unité</option></select>';
    html += '<div class="cpj-note" style="margin-bottom:.8rem">Sous l\'étal aujourd\'hui : ' + reste + ' unité(s). 1 PA. Achat illégal : vous pouvez être repéré(e).</div>';
  }
  html += '<input id="poissonniere-qte" class="cpj-champ" type="number" min="1" max="' + reste + '" step="1" value="1" style="width:100%;margin-bottom:.8rem">';
  html += '<div style="display:flex;gap:.5rem">';
  html += '<button class="cpj-touche cpj-primaire" style="flex:1" onclick="confirmerPoissonniere(\'' + mode + '\')">Acheter</button>';
  html += '<button class="cpj-touche" style="flex:1" onclick="fermerPoissonniere()">Renoncer</button>';
  html += '</div></div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

let achatPoissonniereEnCours = false;
async function confirmerPoissonniere(mode) {
  if (achatPoissonniereEnCours) return;
  const qte = Number(document.getElementById('poissonniere-qte')?.value);
  if (!Number.isSafeInteger(qte) || qte < 1) { refusPoissonniere({ raison: 'quantite_invalide' }); return; }
  const cle = mode === 'contrebande' ? (document.getElementById('poissonniere-cle')?.value || 'alcool') : null;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  achatPoissonniereEnCours = true;
  try {
    const v = mode === 'poisson'
      ? await executerReceptionInventaire('poissonniere_acheter_poisson', { p_qte: qte }, { surRefus: refusPoissonniere })
      : await executerReceptionInventaire('poissonniere_acheter_contrebande', { p_cle: cle, p_qte: qte }, { surRefus: refusPoissonniere });
    if (!v) return;
    fermerPoissonniere();
    if (Array.isArray(v.recherche)) state.recherche = v.recherche;
    if (typeof renderInventory === 'function') renderInventory();
    updateUI();
    if (mode === 'poisson') {
      showToast('Galina Karpova', v.quantite + ' poisson(s) de rivière pour ' + Math.round(v.paye) + ' ' + cur + '.', true);
      addJournalEntry('Achat de ' + v.quantite + ' poisson(s) de rivière à l\'étal de Galina Karpova (' + Math.round(v.paye) + ' ' + cur + ').', 'event-good');
    } else {
      const libelle = v.cle === 'alcool' ? 'alcool' : 'médicaments';
      addJournalEntry('Contrebande : ' + v.quantite + ' unité(s) de ' + libelle + ' achetées sous l\'étal de Galina Karpova (' + Math.round(v.paye) + ' ' + cur + ').', v.detecte ? 'event-bad' : 'event-info');
      if (v.detecte) showToast('Repéré(e) !', 'Quelqu\'un vous a vu sortir un paquet de sous l\'étal. Vous êtes recherché(e).', false, true);
      else showToast('Marché conclu', v.quantite + ' unité(s) de ' + libelle + ', ' + Math.round(v.paye) + ' ' + cur + '. Personne n\'a rien vu.', true);
    }
  } finally { achatPoissonniereEnCours = false; }
}
