// CONTACTS ET SECRETS (lot de Krasnov, point 8 ; Fred, 20/11/2026 ; migration 20261121020000).
// Les secrets appris sont attachés au personnage, côté serveur (personnages_secrets) ; l'écran les relit
// (secrets_lire), affiche le carnet privé dans l'inventaire et cache les ordres « secret » tant qu'ils sont inconnus.
// Premier secret : le colonel Gleb Voronov (station radar de Krasnov) vend le polonium sous le manteau.
(function (global) {
'use strict';
let secretsCharges = false;
let chargementEnCours = null;

function secretConnu(cle) {
  return Array.isArray(global.state?.secrets) && global.state.secrets.some(s => s && s.cle === cle);
}

async function chargerSecrets() {
  if (chargementEnCours) return chargementEnCours;
  if (typeof global.sbRpc !== 'function' || !global.state?.char?.name) return null;
  chargementEnCours = global.sbRpc('secrets_lire', {}).then(r => {
    const v = Array.isArray(r) ? r[0] : r;
    if (v && v.ok === true && Array.isArray(v.secrets)) { global.state.secrets = v.secrets; secretsCharges = true; }
    rendreCarnet();
    return global.state.secrets;
  }).catch(() => null).finally(() => { chargementEnCours = null; });
  return chargementEnCours;
}

function echapper(t) { return typeof global.escapeHtmlText === 'function' ? global.escapeHtmlText(String(t ?? '')) : String(t ?? '').replace(/[&<>"']/g, c => '&#' + c.charCodeAt(0) + ';'); }

// Carnet privé « Contacts et secrets » : visible du seul joueur, sous les objets de l'inventaire.
function rendreCarnet() {
  const panneau = global.document?.getElementById('inventaire-panel');
  if (!panneau) return;
  let bloc = global.document.getElementById('inv-secrets');
  if (!bloc) { bloc = global.document.createElement('div'); bloc.id = 'inv-secrets'; bloc.className = 'inv-section'; panneau.appendChild(bloc); }
  const liste = Array.isArray(global.state?.secrets) ? global.state.secrets : [];
  bloc.innerHTML = '<div class="inv-label" data-i18n="secrets.notebook">Contacts et secrets</div>'
    + (liste.length
      ? liste.map(s => '<div style="margin:.35rem 0;font-size:.78rem;color:#c0b090"><strong>' + echapper(s.titre || s.cle) + '</strong><br><span style="color:#8a8060">' + echapper(s.texte || '') + '</span></div>').join('')
      : '<div class="inv-item-empty" data-i18n="secrets.empty">Aucun contact ni secret.</div>');
}

async function acte(rpc, params, geste) {
  const cle = 'hg-secrets:' + (global.state?.char?.name || '') + ':' + geste;
  let requete = global.sessionStorage.getItem(cle);
  if (!requete) { requete = global.crypto.randomUUID(); global.sessionStorage.setItem(cle, requete); }
  const v = await global.sbRpcVerdict(rpc, Object.assign({ p_requete: requete }, params)).catch(() => null);
  if (v && !v.transport) global.sessionStorage.removeItem(cle);
  if (v && v.ok === true && typeof global.appliquerPaiementServeur === 'function')
    global.appliquerPaiementServeur({ pa: v.pa, liquide: v.liquide, arg: v.arg, solde_national: v.solde_national });
  return v;
}

const MOTIFS = { montant_invalide: 'Entre 7 et 20 PSK.', pas_sur_place: 'Vous n’êtes pas au bon endroit.', secret_inconnu: 'Le colonel ne voit pas de quoi vous parlez.',
  fonds_insuffisants: 'Fonds insuffisants.', inventaire_plein: 'Votre inventaire est plein.', pa_insuffisants: 'PA insuffisants.' };
function refus(titre, v) {
  if (!v) return;
  if (MOTIFS[v.raison]) global.showToast(titre, MOTIFS[v.raison], false);
  else if (typeof global.signalerRefusCout === 'function') global.signalerRefusCout(v);
  else global.showToast(titre, 'Le serveur a refusé l’opération.', false);
}

// Habitué du Bar Sever : règle commune des informateurs de Sovarka (Fred, 21/11/2026) — on le paie de 7 à 20 PSK,
// payer donne toujours un service, la qualité dépend de la somme (flou, correct, premier choix à 20 PSK).
function ouvrirHabitue() {
  global.document.getElementById('postes-modal-title').textContent = 'L’habitué du Bar Sever';
  global.document.getElementById('postes-body').innerHTML = '<div style="padding:1rem">'
    + '<div style="font-size:.82rem;color:#8a8060;margin-bottom:.7rem" data-i18n="secrets.regularRule">Il parle à qui le paie, de 7 à 20 PSK : plus la somme est belle, meilleure est l’information.</div>'
    + '<input id="habitue-montant" type="number" min="7" max="20" value="7" class="cpj-champ" style="width:5rem"> PSK '
    + '<button onclick="payerHabitue()" style="margin-left:.5rem;font-family:Bebas Neue,sans-serif;font-size:.9rem;letter-spacing:.1em;padding:.45rem .9rem;background:#1a1408;border:1px solid #5a4a20;color:#c9a84c;cursor:pointer" data-i18n="secrets.pay">Payer</button>'
    + '</div>';
  global.document.getElementById('modal-postes').classList.add('open');
}

async function payerHabitue() {
  const montant = Math.floor(Number(global.document.getElementById('habitue-montant')?.value || 0));
  if (!(montant >= 7 && montant <= 20)) { global.showToast('L’habitué du Bar Sever', 'Entre 7 et 20 PSK.', false); return; }
  const v = await acte('secret_source_ecouter', { p_source: 'habitue_krasnov', p_montant: montant }, 'source:habitue:' + montant);
  if (!v || v.ok !== true) { refus('L’habitué du Bar Sever', v); return; }
  global.document.getElementById('modal-postes')?.classList.remove('open');
  if (typeof global.updateUI === 'function') global.updateUI();
  const repliques = {
    flou: '« À ta santé, camarade ! Au moins ce verre est sûr, pas comme ceux du colonel du centre d’écoute… »',
    correct: '« Le colonel Voronov, à la station radar… il n’écoute pas que les ondes, celui-là. Il vend quelque chose, sous le manteau. »',
    premier_choix: '« Va voir le colonel Voronov, à la station radar. Demande-lui des nouvelles de notre ami de Luthécia. »'
  };
  global.showToast('L’habitué du Bar Sever', repliques[v.palier] || repliques.flou, v.palier === 'premier_choix', v.palier === 'premier_choix');
  if (typeof global.addJournalEntry === 'function') global.addJournalEntry('L’habitué du Bar Sever (−' + montant + ' PSK) : ' + (repliques[v.palier] || ''), 'event-info');
  if (v.appris) {
    if (typeof global.addJournalEntry === 'function') global.addJournalEntry('Nouveau contact au carnet : le colonel Gleb Voronov (station radar de Krasnov).', 'event-info');
    await chargerSecrets();
    if (typeof global.renderRoomActions === 'function') global.renderRoomActions();
  }
}

async function ecouterSource(source) {
  if (source === 'habitue_krasnov') { ouvrirHabitue(); return; }
  const titre = 'Camarade Kalachnikov';
  const v = await acte('secret_source_ecouter', { p_source: source }, 'source:' + source);
  if (!v || v.ok !== true) { refus(titre, v); return; }
  if (typeof global.updateUI === 'function') global.updateUI();
  global.showToast(titre, '« Pour ça, va voir le colonel Voronov, à la station radar de Krasnov. Demande-lui des nouvelles de notre ami de Luthécia. »', true, true);
  if (v.appris && !v.deja && typeof global.addJournalEntry === 'function') global.addJournalEntry('Nouveau contact au carnet : le colonel Gleb Voronov (station radar de Krasnov).', 'event-info');
  await chargerSecrets();
  if (typeof global.renderRoomActions === 'function') global.renderRoomActions();
}

function ganbaatarPolonium() {
  global.showToast('Chef de quai Ganbaatar Tsybikov', '« Du polonium ? Je ne suis pas une balance ! Allez poser vos questions ailleurs. »', false);
}

async function acheterPoloniumColonel() {
  if (!secretConnu('colonel_polonium')) { global.showToast('Colonel Gleb Voronov', MOTIFS.secret_inconnu, false); return; }
  const v = await (async () => {
    const r = await global.executerReceptionInventaire('polonium_colonel_acheter', { p_acteur: global.state.char?.name }, { surRefus: (x) => { refus('Colonel Gleb Voronov', x); return true; } });
    return r;
  })();
  if (!v) return;
  if (typeof global.renderInventory === 'function') global.renderInventory();
  if (typeof global.updateUI === 'function') global.updateUI();
  if (v.reussi) {
    global.showToast('Colonel Gleb Voronov', 'Le colonel glisse une petite boîte blindée dans votre poche : −150 PSK.', true, true);
    if (typeof global.addJournalEntry === 'function') global.addJournalEntry('Achat sous le manteau : une fiole de polonium (−150 PSK, −2 PA).', 'event-bad');
  } else {
    global.showToast('Colonel Gleb Voronov', '« Je ne connais personne à Luthécia, camarade. »', false);
    if (typeof global.addJournalEntry === 'function') global.addJournalEntry('Le colonel Voronov a fait mine de ne pas comprendre (−2 PA)' + (v.denonce ? ' ; il vous a dénoncé.' : '.'), v.denonce ? 'event-bad' : 'event-neutral');
  }
}

global.rpSecretConnu = secretConnu;
global.chargerSecrets = chargerSecrets;
global.rendreCarnetSecrets = rendreCarnet;
global.ecouterSourceSecret = ecouterSource;
global.payerHabitue = payerHabitue;
global.ganbaatarPolonium = ganbaatarPolonium;
global.acheterPoloniumColonel = acheterPoloniumColonel;

// Chargement dès que le personnage est connu, puis à chaque ouverture de l'inventaire.
const attente = global.setInterval(() => { if (global.state?.char?.name) { global.clearInterval(attente); chargerSecrets(); } }, 1500);
global.document?.addEventListener('click', e => { if (e.target && e.target.closest && e.target.closest('#inv-chevron, .inv-toggle')) rendreCarnet(); });
})(typeof window !== 'undefined' ? window : globalThis);
