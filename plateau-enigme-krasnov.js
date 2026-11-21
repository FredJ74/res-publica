// ÉCOLE ET ÉNIGME DE KRASNOV (lot de Krasnov, point 7 ; Fred, 20/11/2026 ; migration 20261121060000).
// Le serveur décide de tout (krasnov_ecole_agir) : stage de survie, guide au musée avec sa feuille volante, réponse à
// l'énigme donnée au directeur du musée. L'écran affiche la fenêtre d'ouverture (générique, même formule pour chaque ville),
// la liste des énigmes résolues dans l'inventaire et la réplique des habitués du Bar Sever.
(function (global) {
'use strict';
const NOMS_ENIGMES = { krasnov: 'L’énigme de Krasnov' };

function echapper(t) { return String(t ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }

async function agir(action, texte) {
  const r = await global.executerReceptionInventaire('krasnov_ecole_agir', texte == null ? { p_action: action } : { p_action: action, p_texte: texte },
    { surRefus: (x) => { refus(x); return true; } });
  return r;
}
const MOTIFS = { pas_sur_place: 'Vous n’êtes pas au bon endroit.', effet_deja_actif: 'Votre stage de survie fait encore effet.',
  pas_de_feuille: 'Il vous faut la feuille volante glissée dans le guide des baies.', deja_resolue: 'Vous avez déjà résolu l’énigme de Krasnov.',
  inventaire_plein: 'Votre inventaire est plein.' };
function refus(v) {
  if (!v) return;
  if (MOTIFS[v.raison]) global.showToast('Krasnov', MOTIFS[v.raison], false);
  else if (typeof global.signalerRefusCout === 'function') global.signalerRefusCout(v);
}
function apres() { if (typeof global.renderInventory === 'function') global.renderInventory(); if (typeof global.updateUI === 'function') global.updateUI(); }

// Fenêtre d'ouverture d'une énigme de ville (générique).
function ouvrirPopupEnigme(ville) {
  global.document.getElementById('postes-modal-title').textContent = 'Énigme';
  global.document.getElementById('postes-body').innerHTML = '<div style="padding:1.2rem;text-align:center">'
    + '<div style="font-family:Bebas Neue,sans-serif;font-size:1.3rem;letter-spacing:.08em;color:#c9a84c;margin-bottom:.6rem">'
    + echapper('Ici commence l’énigme de ' + ville + ' : saurez-vous la résoudre… ?') + '</div>'
    + '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" class="cpj-touche" style="margin-top:.6rem">OK</button></div>';
  global.document.getElementById('modal-postes').classList.add('open');
}

async function stageSurvie() {
  const v = await agir('stage_survie');
  if (!v) return;
  if (Array.isArray(v.effets_actifs) && global.state) global.state.effetsActifs = v.effets_actifs;
  apres();
  global.showToast('Alevtina Gramotova', 'Une journée dans les bois avec l’institutrice : +4 VOL pendant 24 h.', true, true);
  if (typeof global.addJournalEntry === 'function') global.addJournalEntry('Stage de survie en forêt avec Alevtina Gramotova : +4 VOL pendant 24 h (−3 PA, −25 PSK versés à la mairie).', 'event-good');
}

async function acheterGuide() {
  const v = await agir('acheter_guide');
  if (!v) return;
  apres();
  global.showToast('Musée de Krasnov', 'Le guide des baies sauvages est à vous (−10 PSK). Une feuille volante s’en échappe…', true);
  if (typeof global.addJournalEntry === 'function') global.addJournalEntry('Achat au musée de Krasnov : le guide des baies sauvages et sa feuille volante (−10 PSK).', 'event-info');
  if (v.premiere_feuille && !v.resolue) ouvrirPopupEnigme('Krasnov');
}

function ouvrirReponse() {
  global.document.getElementById('postes-modal-title').textContent = 'Directeur du musée de Krasnov';
  global.document.getElementById('postes-body').innerHTML = '<div style="padding:1rem">'
    + '<div style="font-size:.82rem;color:#8a8060;margin-bottom:.6rem">« Alors, quel est cet ingrédient effacé de la recette ? »</div>'
    + '<input id="enigme-krasnov-reponse" type="text" maxlength="80" class="cpj-champ" style="width:100%" dir="auto">'
    + '<button onclick="soumettreEnigmeKrasnov()" class="cpj-touche" style="width:100%;margin-top:.6rem">Répondre</button></div>';
  global.document.getElementById('modal-postes').classList.add('open');
}

async function soumettre() {
  const texte = String(global.document.getElementById('enigme-krasnov-reponse')?.value || '').trim();
  if (!texte) return;
  const v = await agir('repondre_enigme', texte);
  if (!v) return;
  global.document.getElementById('modal-postes')?.classList.remove('open');
  if (!v.resolue) { global.showToast('Directeur du musée de Krasnov', '« Non… ce n’est pas cela. Relisez bien la feuille. »', false); return; }
  global.showToast('Directeur du musée de Krasnov', '« La graisse d’ours… Alors notre organisation n’a plus lieu d’exister. Allez l’annoncer à l’institutrice. »', true, true);
  if (typeof global.addJournalEntry === 'function') global.addJournalEntry('Énigme de Krasnov résolue : ' + (v.distinction || 'distinction obtenue') + '.', 'event-good');
  await chargerEnigmes();
}

// Énigmes résolues et distinctions, sous les objets de l'inventaire (visible du seul joueur).
async function chargerEnigmes() {
  if (typeof global.sbRpc !== 'function' || !global.state?.char?.name) return;
  const r = await global.sbRpc('enigmes_lire', {}).catch(() => null);
  const v = Array.isArray(r) ? r[0] : r;
  if (v && v.ok === true) { global.state.enigmesResolues = v.enigmes || []; rendreEnigmes(); }
}
function rendreEnigmes() {
  const panneau = global.document?.getElementById('inventaire-panel');
  if (!panneau) return;
  const liste = Array.isArray(global.state?.enigmesResolues) ? global.state.enigmesResolues : [];
  let bloc = global.document.getElementById('inv-enigmes');
  if (!liste.length) { if (bloc) bloc.remove(); return; }
  if (!bloc) { bloc = global.document.createElement('div'); bloc.id = 'inv-enigmes'; bloc.className = 'inv-section'; panneau.appendChild(bloc); }
  bloc.innerHTML = '<div class="inv-label" data-i18n="enigmes.solved">Énigmes résolues</div>'
    + liste.map(e => '<div style="margin:.3rem 0;font-size:.78rem;color:#c0b090"><i class="ti ti-award"></i> ' + echapper(NOMS_ENIGMES[e.enigme] || e.enigme)
      + '<br><span style="color:#8a8060">' + echapper(e.distinction || '') + '</span></div>').join('');
}

// Bar Sever : les habitués vantent leur « Miss », une fois par session.
let habituesDits = false;
function habituesBarSever() {
  const s = global.state;
  if (habituesDits || !s || s.country !== 'soviet' || s.currentCity !== 'ville_b' || s.currentBuilding !== 'cafe-tabac-cheminots-montrouge') return;
  habituesDits = true;
  global.showToast('Les habitués du Bar Sever', '« À Krasnov, on a les plus belles femmes du pays ! Elle n’est pas belle notre Miss ? Et intelligente ! Elle enseigne à l’école ! »', true);
}

global.ouvrirPopupEnigme = ouvrirPopupEnigme;
global.doStageSurvieForet = stageSurvie;
global.doAcheterGuideMusee = acheterGuide;
global.doRepondreEnigmeKrasnov = ouvrirReponse;
global.soumettreEnigmeKrasnov = soumettre;
global.chargerEnigmesResolues = chargerEnigmes;
const attente = global.setInterval(() => { if (global.state?.char?.name) { global.clearInterval(attente); chargerEnigmes(); } }, 1500);
global.setInterval(habituesBarSever, 2000);
})(typeof window !== 'undefined' ? window : globalThis);
