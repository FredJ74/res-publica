// PORTS ET COMMERCE INTERNATIONAL (Fred, 16/11/2026, GAME-DESIGN-REGULATION-PRODUCTION.md).
// Administration du port (lecture publique, balance commerciale comprise), réglages du Commandant du Port
// (fléchage, prix de cession et d'exportation, quotas, taux de douane) et dotation du ministre de
// l'Économie. Le serveur décide tout (port_lire, port_commandant_regler, port_dotation_ministre) ;
// l'écran n'affiche que ses réponses. Textes : i18n/port-commerce-resources.js (espace « portCommerce »).

const portT = (cle, francais, values) => (typeof ficheLibelleHtml === 'function')
  ? ficheLibelleHtml(cle, francais, values, 'portCommerce')
  : String(francais).replace(/\{\{values\.(\w+)\}\}/g, (_, k) => (values && values[k] != null ? values[k] : ''));
const portEchapper = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
let portDerniereLecture = null;
let portEnCours = false;

function portDevise(pays) { return (typeof COUNTRIES !== 'undefined' && COUNTRIES[pays] && COUNTRIES[pays].cur) || 'FR'; }
function portPaysNom(pays) { return (typeof COUNTRIES !== 'undefined' && COUNTRIES[pays] && COUNTRIES[pays].n) || pays; }
function portRessource(cle) { return typeof libelleMatiereCommerceHtml === 'function' ? libelleMatiereCommerceHtml(cle) : portEchapper(cle); }
function portVille(pays, ville) { return portEchapper((typeof villeNom === 'function' && villeNom(pays, ville)) || ville); }
function portMontant(v, pays) {
  const n = Math.round((Number(v) || 0) * 100) / 100;
  return n.toLocaleString('fr-FR') + ' ' + portDevise(pays);
}

async function portLire(pays) {
  const brut = (typeof sbRpc === 'function') ? await sbRpc('port_lire', { p_pays: pays || null }).catch(() => null) : null;
  const v = Array.isArray(brut) ? brut[0] : brut;
  return (v && v.ok === true) ? v : null;
}

function portOuvrirModal(titreHtml, corpsHtml) {
  document.getElementById('postes-modal-title').innerHTML = titreHtml;
  document.getElementById('postes-body').innerHTML = corpsHtml;
  document.getElementById('modal-postes').classList.add('open');
}

function portRaison(r) {
  const raisons = {
    reserve_commandant_port: portT('errCommander', 'Réservé au Commandant du Port.'),
    reserve_ministre_finances: portT('errMinister', 'Réservé au ministre de l\'Économie.'),
    pas_sur_place: portT('errPlace', 'Le Commandant règle le port depuis son bureau, au port.'),
    prix_hors_bornes: portT('errPrice', 'Prix hors bornes ({{values.min}} à {{values.max}}).', { min: r && r.min, max: r && r.max }),
    quota_invalide: portT('errQuota', 'Quota invalide : un nombre entier positif, ou vide pour aucun quota.'),
    repartition_invalide: portT('errSplit', 'Les trois parts doivent faire 100 %.'),
    taux_hors_bornes: portT('errRate', 'Le taux de douane va de 0 à 30 %.'),
    caisse_insuffisante: portT('errFunds', 'La caisse du ministère ne couvre pas ce virement.'),
    montant_invalide: portT('errAmount', 'Montant invalide.')
  };
  return raisons[r && r.raison] || portT('errGeneric', 'Refusé par le serveur ({{values.r}}).', { r: portEchapper((r && r.raison) || '?') });
}

// ----- Administration du port : lecture publique -----
async function ouvrirAdministrationPort() {
  const pays = state.country || 'republic';
  const p = await portLire(pays);
  if (!p) { showToast(portT('unavailable', 'Indisponible'), portT('readFail', 'Le registre du port ne répond pas.'), false); return; }
  portDerniereLecture = p;
  let h = '<div class="cpj-dialogue" style="padding:1rem;max-height:72vh;overflow-y:auto">';
  h += '<div class="cpj-note">' + portT('commander', 'Commandant du Port : {{values.who}}', { who: portEchapper(p.commandant || '—') }) + '</div>';
  h += '<div class="cpj-note">' + portT('cash', 'Caisse du port : {{values.v}}', { v: portMontant(p.caisse, pays) })
    + ' · ' + portT('customsRate', 'Douane : {{values.t}} %', { t: p.taux_douane })
    + (Number(p.dotation_jour) > 0 ? ' · ' + portT('dailyGrant', 'Dotation du ministère : {{values.v}} par jour', { v: portMontant(p.dotation_jour, pays) }) : '') + '</div>';

  h += '<h4 style="margin:.8rem 0 .3rem">' + portT('balanceTitle', 'Balance commerciale') + '</h4>';
  if (!(p.balance || []).length) h += '<div class="cpj-note">' + portT('balanceNone', 'Aucune journée de commerce enregistrée pour l\'instant.') + '</div>';
  else {
    h += '<table style="width:100%;font-size:.85rem;border-collapse:collapse"><tr><th style="text-align:left">' + portT('day', 'Jour') + '</th><th>'
      + portT('exports', 'Exportations') + '</th><th>' + portT('imports', 'Importations') + '</th><th>' + portT('balance', 'Solde') + '</th></tr>';
    p.balance.forEach(b => {
      const solde = Number(b.solde) || 0;
      h += '<tr><td>' + portEchapper(b.jour) + '</td><td style="text-align:right">' + portMontant(b.exportations, pays) + '</td><td style="text-align:right">'
        + portMontant(b.importations, pays) + '</td><td style="text-align:right;color:' + (solde < 0 ? '#e07b6a' : '#8fc98f') + '">'
        + (solde > 0 ? '+' : '') + portMontant(solde, pays) + '</td></tr>';
    });
    h += '</table>';
  }

  h += '<h4 style="margin:.8rem 0 .3rem">' + portT('goodsTitle', 'Marchandises du port') + '</h4>';
  h += '<table style="width:100%;font-size:.82rem;border-collapse:collapse"><tr><th style="text-align:left">' + portT('good', 'Ressource') + '</th><th>'
    + portT('stock', 'Au port') + '</th><th>' + portT('cessionPrice', 'Cession') + '</th><th>' + portT('exportPrice', 'Export') + '</th><th>'
    + portT('quotas', 'Quotas imp./exp.') + '</th></tr>';
  (p.ressources || []).forEach(r => {
    const q = v => (v == null ? '—' : portEchapper(v));
    h += '<tr style="border-top:1px solid #34404e"><td>' + portRessource(r.cle) + '</td><td style="text-align:right">' + (r.stock || 0)
      + '</td><td style="text-align:right">' + portEchapper(r.prix_cession) + (r.cession_fixe ? ' *' : '') + '</td><td style="text-align:right">'
      + portEchapper(r.prix_export) + (r.export_fixe ? ' *' : '') + '</td><td style="text-align:right">' + q(r.quota_import) + ' / ' + q(r.quota_export) + '</td></tr>';
  });
  h += '</table><div class="cpj-note">' + portT('starNote', '* prix fixé par le Commandant ; sinon prix intérieur (cession) ou cours international (export).') + '</div>';

  const dp = p.derniere_passe;
  h += '<h4 style="margin:.8rem 0 .3rem">' + portT('contractsTitle', 'Contrats de la dernière nuit') + (dp ? ' (' + portEchapper(dp.jour) + ')' : '') + '</h4>';
  if (!dp || !(dp.contrats || []).length) h += '<div class="cpj-note">' + portT('contractsNone', 'Aucune livraison enregistrée.') + '</div>';
  else dp.contrats.forEach(c => {
    const sens = c.origine === pays
      ? portT('toCountry', 'vers {{values.c}}', { c: portEchapper(portPaysNom(c.destination)) })
      : portT('fromCountry', 'de {{values.c}}', { c: portEchapper(portPaysNom(c.origine)) });
    h += '<div class="cpj-note">' + portRessource(c.cle) + ' ' + sens + ' : ' + (c.livre || 0) + ' / ' + (c.contrat || 0)
      + (c.raison ? ' — ' + portT('reason_' + c.raison, portEchapper(c.raison)) : '') + '</div>';
  });

  h += '<h4 style="margin:.8rem 0 .3rem">' + portT('logTitle', 'Registre du port') + '</h4>';
  (p.journal || []).slice(0, 15).forEach(j => {
    h += '<div class="cpj-note">' + portEchapper(j.jour) + ' · ' + portT('nature_' + j.nature, portEchapper(j.nature))
      + (j.cle ? ' · ' + portRessource(j.cle) : '') + (j.quantite ? ' × ' + j.quantite : '')
      + (Number(j.montant) ? ' · ' + (j.montant > 0 ? '+' : '') + portMontant(j.montant, pays) : '')
      + (j.partenaire ? ' · ' + portEchapper(portPaysNom(j.partenaire)) : '') + '</div>';
  });
  if (p.est_commandant) h += '<button class="cpj-touche cpj-primaire" style="margin-top:.8rem;width:100%" onclick="ouvrirReglagesPort()">' + portT('settings', 'Régler le port') + '</button>';
  h += '</div>';
  portOuvrirModal(portT('title', 'Administration du port') + ' — ' + portEchapper(p.nom), h);
}

// ----- Réglages du Commandant du Port -----
async function ouvrirReglagesPort() {
  const pays = state.country || 'republic';
  const p = await portLire(pays);
  if (!p) { showToast(portT('unavailable', 'Indisponible'), portT('readFail', 'Le registre du port ne répond pas.'), false); return; }
  if (!p.est_commandant) { showToast(portT('refused', 'Refusé'), portT('errCommander', 'Réservé au Commandant du Port.'), false); return; }
  portDerniereLecture = p;
  let h = '<div class="cpj-dialogue" style="padding:1rem;max-height:72vh;overflow-y:auto">';
  h += '<div class="cpj-note">' + portT('settingsIntro', 'Chaque réglage reste en vigueur jusqu\'à ce que vous le changiez. Un champ vide revient au réglage par défaut.') + '</div>';
  h += '<label class="cpj-note">' + portT('customsRateLabel', 'Taux de douane (0 à 30 %)') + '</label>';
  h += '<input id="port-taux" class="cpj-champ" type="number" min="0" max="30" step="0.5" value="' + portEchapper(p.taux_douane) + '">';
  h += '<button class="cpj-touche" style="width:100%;margin:.3rem 0 .8rem" onclick="portRegler(\'taux_douane\')">' + portT('save', 'Enregistrer') + '</button>';
  h += '<label class="cpj-note">' + portT('good', 'Ressource') + '</label><select id="port-cle" class="cpj-champ" onchange="portAfficherRessource()">';
  (p.ressources || []).forEach(r => { h += '<option value="' + portEchapper(r.cle) + '">' + portRessource(r.cle) + '</option>'; });
  h += '</select><div id="port-ressource"></div></div>';
  portOuvrirModal(portT('settings', 'Régler le port'), h);
  portAfficherRessource();
}

function portAfficherRessource() {
  const p = portDerniereLecture; const sel = document.getElementById('port-cle'); const zone = document.getElementById('port-ressource');
  if (!p || !sel || !zone) return;
  const r = (p.ressources || []).find(x => x.cle === sel.value) || {};
  const pays = p.pays; const rep = r.repartition || {};
  const champ = (id, label, val, note) => '<label class="cpj-note">' + label + '</label><input id="' + id + '" class="cpj-champ" type="number" min="0" step="any" value="'
    + (val == null ? '' : portEchapper(val)) + '">' + (note ? '<div class="cpj-note">' + note + '</div>' : '');
  let h = '<div class="cpj-note" style="margin-top:.5rem">' + portT('stockLine', 'Au port : {{values.n}} · prix intérieur {{values.p}} · cours international {{values.c}}',
    { n: r.stock || 0, p: portMontant(r.prix_interieur, pays), c: portMontant(r.cours_international, pays) }) + '</div>';
  h += champ('port-cession', portT('cessionLabel', 'Prix de cession aux entrepôts'), r.cession_fixe ? r.prix_cession : null);
  h += '<button class="cpj-touche" style="width:100%;margin:.2rem 0 .6rem" onclick="portRegler(\'prix_cession\')">' + portT('save', 'Enregistrer') + '</button>';
  h += champ('port-export', portT('exportLabel', 'Prix d\'exportation'), r.export_fixe ? r.prix_export : null);
  h += '<button class="cpj-touche" style="width:100%;margin:.2rem 0 .6rem" onclick="portRegler(\'prix_export\')">' + portT('save', 'Enregistrer') + '</button>';
  h += champ('port-qimp', portT('quotaImportLabel', 'Quota d\'importation (unités par jour, 0 = embargo)'), r.quota_import);
  h += '<button class="cpj-touche" style="width:100%;margin:.2rem 0 .6rem" onclick="portRegler(\'quota_import\')">' + portT('save', 'Enregistrer') + '</button>';
  h += champ('port-qexp', portT('quotaExportLabel', 'Quota d\'exportation (unités par jour, 0 = embargo)'), r.quota_export);
  h += '<button class="cpj-touche" style="width:100%;margin:.2rem 0 .6rem" onclick="portRegler(\'quota_export\')">' + portT('save', 'Enregistrer') + '</button>';
  if (p.a_un_batiment) {
    h += '<div class="cpj-note" style="margin-top:.4rem">' + portT('splitTitle', 'Fléchage vers les entrepôts (%, total 100)') + '</div>';
    ['capitale', 'ville_a', 'ville_b'].forEach(v => {
      h += champ('port-rep-' + v, portVille(pays, v), rep[v] != null ? rep[v] : Math.round(10000 / 3) / 100);
    });
    h += '<button class="cpj-touche" style="width:100%;margin:.2rem 0" onclick="portRegler(\'repartition\')">' + portT('save', 'Enregistrer') + '</button>';
  }
  zone.innerHTML = h;
}

async function portRegler(action) {
  if (portEnCours) return;
  const val = id => { const e = document.getElementById(id); const s = e ? String(e.value).trim() : ''; return s === '' ? null : Number(s); };
  const cle = document.getElementById('port-cle')?.value;
  let params;
  if (action === 'taux_douane') params = { taux: val('port-taux') };
  else if (action === 'prix_cession') params = { cle, prix: val('port-cession') };
  else if (action === 'prix_export') params = { cle, prix: val('port-export') };
  else if (action === 'quota_import') params = { cle, quota: val('port-qimp') };
  else if (action === 'quota_export') params = { cle, quota: val('port-qexp') };
  else if (action === 'repartition') params = { cle, capitale: val('port-rep-capitale'), ville_a: val('port-rep-ville_a'), ville_b: val('port-rep-ville_b') };
  else return;
  portEnCours = true;
  const brut = await sbRpc('port_commandant_regler', { p_action: action, p_params: params }).catch(() => null);
  portEnCours = false;
  const r = Array.isArray(brut) ? brut[0] : brut;
  if (!r || r.ok !== true) { showToast(portT('refused', 'Refusé'), portRaison(r), false); return; }
  portDerniereLecture = r;
  showToast(portT('saved', 'Réglage enregistré'), '', true);
  if (typeof addJournalEntry === 'function') addJournalEntry(portT('journalSaved', 'Le Commandant du Port modifie un réglage du port.'), 'event-info');
  portAfficherRessource();
}

// ----- Dotation du ministre de l'Économie -----
async function ouvrirDotationPort() {
  const pays = state.country || 'republic';
  const p = await portLire(pays);
  if (!p) { showToast(portT('unavailable', 'Indisponible'), portT('readFail', 'Le registre du port ne répond pas.'), false); return; }
  let h = '<div class="cpj-dialogue" style="padding:1rem">';
  h += '<div class="cpj-note">' + portT('cash', 'Caisse du port : {{values.v}}', { v: portMontant(p.caisse, pays) }) + '</div>';
  const dernier = (p.balance || [])[0];
  if (dernier) h += '<div class="cpj-note">' + portT('lastBalance', 'Dernière balance commerciale : {{values.v}}', { v: portMontant(dernier.solde, pays) }) + '</div>';
  h += '<label class="cpj-note">' + portT('oneOffLabel', 'Virement ponctuel depuis la caisse du ministère (1 PA)') + '</label>';
  h += '<input id="port-dot-ponctuelle" class="cpj-champ" type="number" min="1" step="1">';
  h += '<button class="cpj-touche cpj-primaire" style="width:100%;margin:.3rem 0 .9rem" onclick="portDoter(\'ponctuelle\')">' + portT('transfer', 'Virer') + '</button>';
  h += '<label class="cpj-note">' + portT('dailyLabel', 'Dotation quotidienne (versée chaque nuit, 0 pour l\'arrêter)') + '</label>';
  h += '<input id="port-dot-recurrente" class="cpj-champ" type="number" min="0" step="1" value="' + portEchapper(p.dotation_jour || 0) + '">';
  h += '<button class="cpj-touche" style="width:100%;margin-top:.3rem" onclick="portDoter(\'recurrente\')">' + portT('save', 'Enregistrer') + '</button>';
  h += '</div>';
  portOuvrirModal(portT('grantTitle', 'Dotation au port'), h);
}

async function portDoter(action) {
  if (portEnCours) return;
  const champ = document.getElementById(action === 'ponctuelle' ? 'port-dot-ponctuelle' : 'port-dot-recurrente');
  const montant = Math.floor(Number(champ && champ.value));
  if (!isFinite(montant) || montant < 0 || (action === 'ponctuelle' && montant <= 0)) { showToast(portT('refused', 'Refusé'), portT('errAmount', 'Montant invalide.'), false); return; }
  portEnCours = true;
  const brut = await sbRpc('port_dotation_ministre', { p_action: action, p_montant: montant }).catch(() => null);
  portEnCours = false;
  const r = Array.isArray(brut) ? brut[0] : brut;
  if (!r || r.ok !== true) {
    const connues = ['reserve_ministre_finances', 'caisse_insuffisante', 'montant_invalide', 'port_inconnu'];
    if (r && r.raison && !connues.includes(r.raison) && typeof signalerRefusCout === 'function') signalerRefusCout(r);
    else showToast(portT('refused', 'Refusé'), portRaison(r), false);
    return;
  }
  if (r.paie && typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur(r.paie);
  if (typeof updateUI === 'function') updateUI();
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast(action === 'ponctuelle' ? portT('transferDone', 'Virement effectué') : portT('saved', 'Réglage enregistré'),
    action === 'ponctuelle' ? portMontant(r.montant, state.country) : portT('dailySet', '{{values.v}} par jour', { v: portMontant(r.dotation_jour, state.country) }), true);
}
