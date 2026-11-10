// SOVARKA : LOT DES PROVINCES (10/11/2026, décisions de Fred, GAME-DESIGN-NOVOMIRSK.md,
// « Réponses de Fred »). Bons d'État, centres d'écoute, maisons, forêt de Krasnov.
// Le serveur décide tout ; l'écran n'affiche que ses réponses (règle « une seule réalité »).

const PROV_MOTIFS = {
  acteur_non_authentifie: 'Votre session doit être rétablie.',
  pas_sur_place: 'Présentez-vous sur place.',
  montant_invalide: 'Indiquez un montant entier positif.',
  fonds_insuffisants: 'Vous n’avez pas cette somme (liquide et Banque nationale).',
  requete_etrangere: 'Requête refusée.'
};
const provMotif = v => PROV_MOTIFS[v?.raison] || (v?.transport ? 'Réponse du serveur non reçue : réessayez, la même requête sera rejouée sans repayer.' : 'Refusé par le serveur.');
const provEchapper = s => (typeof sovEchapper === 'function') ? sovEchapper(s) : String(s == null ? '' : s);
let provActeEnCours = false;

// Un acte idempotent : clé de requête stable par geste, oubliée après une réponse du serveur.
async function provActe(rpc, params, geste) {
  if (provActeEnCours) return null;
  provActeEnCours = true;
  const cle = 'hg-sovarka:' + (state.char?.name || '') + ':' + rpc + ':' + geste;
  try {
    let requete = sessionStorage.getItem(cle);
    if (!requete) { requete = crypto.randomUUID(); sessionStorage.setItem(cle, requete); }
    const v = await sbRpcVerdict(rpc, Object.assign({ p_requete: requete }, params)).catch(() => null);
    if (v && !v.transport) sessionStorage.removeItem(cle);
    if (v && v.ok === true) {
      if (Array.isArray(v.inventory) && typeof sbAdopterInventaireServeur === 'function') sbAdopterInventaireServeur(v);
      if (typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur({ pa: v.pa, liquide: v.liquide, arg: v.arg });
      if (typeof renderInventory === 'function') renderInventory();
      if (typeof updateHeader === 'function') updateHeader();
      if (typeof updateUI === 'function') updateUI();
    }
    return v;
  } finally { provActeEnCours = false; }
}

// ---------- BONS D'ÉTAT ----------
async function ouvrirBonsEtat() {
  const v = await sbRpcVerdict('sovarka_bons_etat_lire', {}).catch(() => null);
  if (!v || v.ok !== true) { showToast('Bons d’État', provMotif(v), false); return; }
  const j = v.jour || {};
  let html = '<p>« Soutenez l’économie de Sovarka ! » Le bon d’État est un geste patriotique : il ne donne aucun ' +
    'avantage en jeu. Votre argent va au Trésor de Sovarka, qui vous le rend dans <strong>7 jours</strong>, ' +
    'augmenté ou diminué du rendement fixé aujourd’hui.</p>' +
    '<p class="cpj-note">Rendement du jour : <strong>' + j.taux + ' %</strong> (indice Économie moyen des trois villes : ' +
    j.indice + ' / 100 ; de −10 % au plus bas à +3 % au plus haut). Si le Trésor est vide à l’échéance, la Banque ' +
    'imprime les billets : vous êtes remboursé à −10 %, quel que soit le rendement prévu.</p>';
  html += vehSection('Souscrire', '<div style="margin-top:.4rem">' + vehChamp('bon-etat-montant', 100) + ' PSK' +
    vehBouton('Souscrire', 'souscrireBonEtat()', true) + '</div>');
  const bons = Array.isArray(v.bons) ? v.bons : [];
  if (bons.length) {
    html += vehSection('Mes bons', bons.map(b => '<div style="margin:.3rem 0">' + b.montant + ' PSK à ' + b.taux + ' % — ' +
      (b.statut === 'rembourse'
        ? 'remboursé ' + b.rembourse + ' PSK' + (b.planche_a_billets ? ' (planche à billets)' : '')
        : 'échéance le ' + new Date(b.echeance + 'T12:00:00').toLocaleDateString('fr-FR')) + '</div>').join(''));
  }
  vehModal('Bons d’État de Sovarka', html);
}

async function souscrireBonEtat() {
  const montant = vehLireChamp('bon-etat-montant');
  if (!(montant > 0)) { showToast('Bons d’État', PROV_MOTIFS.montant_invalide, false); return; }
  const v = await provActe('sovarka_bon_etat_souscrire', { p_montant: montant }, 'souscrire:' + montant);
  if (!v) return;
  if (v.ok !== true) { showToast('Bons d’État', provMotif(v), false); return; }
  showToast('Bon d’État souscrit', v.montant + ' PSK à ' + v.taux + ' %, rendus le ' +
    new Date(v.echeance + 'T12:00:00').toLocaleDateString('fr-FR') + '.', true, true);
  if (typeof addJournalEntry === 'function') addJournalEntry('Bon d’État souscrit : ' + v.montant + ' PSK à ' + v.taux + ' %.', 'event-good');
  await ouvrirBonsEtat();
}
