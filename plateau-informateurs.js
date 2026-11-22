// INFORMATEURS (refonte décidée par Fred le 19/11/2026, codée le 22/11/2026 ; GAME-DESIGN-CRIMINALITE.md, « Barème commun
// des informateurs »). On ne recrute plus d'informateur : on paie un PNJ présent dans le lieu (barman, réceptionniste,
// serveuse, hôtesse, chef de gare, commandant de port, agent de sécurité, personnel de l'Assemblée, de la présidence et des
// mairies, entraîneur, dealer, lobbyiste, dirigeant syndical, l'habitué du Bar Sever).
// Le serveur décide tout : qui est présent (informateurs_ici, référentiel informateurs_pnj), le palier selon la somme
// (Républia 20-29 / 30-44 / 45-50 FR, Sovarka 7-11 / 12-17 / 18-20 PSK), le débit (l'argent disparaît du jeu) et le texte de
// la réponse (jamais un nom, seulement des traits). Cet écran affiche, rien de plus. Textes : français seulement.
(function (global) {
'use strict';
const TXT_INFORMATEURS = {
  ordre: 'Acheter une information',
  ordreDesc: 'Quelqu’un ici sait des choses. Payez-le : il répond toujours, et plus la somme est belle, meilleure est l’information. Il ne donne jamais de nom.',
  titre: 'Acheter une information',
  chargement: 'Un instant…',
  personne: 'Personne ici ne vend d’informations.',
  qui: 'À qui voulez-vous parler ?',
  profil_lieu: 'Il connaît son lieu : qui est passé ici ces dernières 24 heures, et ce qui s’y raconte.',
  profil_generaliste: 'Il entend tout, sur toute la ville : il vous dira une chose, prise au hasard.',
  profil_sujet_drogue: 'Il connaît le milieu de la drogue et des addictions, dans cette ville.',
  profil_sujet_politique: 'Il connaît les coulisses de la politique, dans cette ville.',
  profil_sujet_syndicat: 'Il connaît le monde syndical, dans cette ville.',
  bareme: 'Combien lui donnez-vous ? De {min} à {max} {cur}.',
  palier_flou: 'Flou : il met sur la piste sans rien livrer',
  palier_correct: 'Correct : une vraie information',
  palier_premier_choix: 'Premier choix : sa meilleure information',
  palierLigne: '{min} à {max} {cur} — {libelle}',
  horsBareme: 'Choisissez une somme entre {min} et {max} {cur}.',
  payer: 'Payer {montant} {cur}',
  disparait: 'L’argent versé est perdu : il reste dans la poche de l’informateur.',
  reponseTitre: '{nom} vous glisse à l’oreille…',
  reponsePalier: 'Vous avez donné {montant} {cur} ({libelle}).',
  encore: 'Payer encore quelqu’un',
  fermer: 'Fermer',
  journal: 'Information achetée à {nom} (−{montant} {cur}).',
  carnet: 'Nouveau contact au carnet : le colonel Gleb Voronov (station radar de Krasnov).',
  refus: 'Impossible',
  r_pas_sur_place: 'Cette personne n’est plus là : vous avez changé de pièce.',
  r_informateur_inconnu: 'Cette personne ne vend plus d’informations.',
  r_montant_invalide: 'Cette somme n’est pas dans le barème.',
  r_fonds_insuffisants: 'Vous n’avez pas assez d’argent.',
  r_acteur_non_authentifie: 'Connectez-vous d’abord.',
  r_defaut: 'Le serveur a refusé.'
};
function t(cle, v) { return String(TXT_INFORMATEURS[cle] ?? cle).replace(/\{(\w+)\}/g, (m, k) => (v && k in v) ? String(v[k]) : m); }
function esc(s) { return String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }
const st = () => global.state || {};
const cle = () => [st().country, st().currentCity, st().currentBuilding, st().currentRoom].join('/');

// Présents de la pièce, relus au serveur (cache court par pièce : la liste change quand on change de pièce).
const cache = new Map();
let enLecture = null;
async function lireIci(force) {
  const k = cle(), c = cache.get(k);
  if (!force && c && Date.now() - c.le < 60000) return c.v;
  if (typeof global.sbRpc !== 'function') return null;
  const brut = await global.sbRpc('informateurs_ici', {}).catch(() => null);
  const v = Array.isArray(brut) ? brut[0] : brut;
  if (!v || v.ok !== true) return null;
  // Le serveur répond pour la pièce où il voit le personnage : on range sous cette clé-là.
  const kServeur = [v.pays, v.ville, v.batiment, v.piece].join('/');
  cache.set(kServeur, { v, le: Date.now() });
  return kServeur === k ? v : null;
}
function redessiner() {
  const b = st().currentBuilding, r = st().currentRoom;
  if (!b || !r || typeof global.renderRoomActions !== 'function') return;
  const room = global.BUILDINGS?.[b]?.rooms?.[r] || (typeof global.getBuildingContext === 'function' ? global.getBuildingContext(b)?.roomsExtra?.[r] : null);
  if (room) global.renderRoomActions(room, b, r);
}

// Source d'ordres dynamique : « Acheter une information » quand un informateur se tient dans la pièce. L'habitué du Bar
// Sever garde son ordre propre (« Offrir un verre à l’habitué »), qui ouvre la même fenêtre.
function ordresInformateurs() {
  const k = cle(), c = cache.get(k);
  if (!c || Date.now() - c.le >= 60000) {
    if (!enLecture) enLecture = lireIci(true).then(v => { if (v && cle() === k) redessiner(); }).finally(() => { enLecture = null; });
    if (!c) return [];
  }
  const liste = (c.v.informateurs || []).filter(i => i.id !== 'habitue_krasnov');
  if (!liste.length) return [];
  return [{ fn: 'informateur_payer', label: 'Acheter une information', pa: 0, cost: 0, type: 'grey', icon: 'ti-coins', successRate: 100,
    desc: 'Quelqu’un ici sait des choses. Payez-le : il répond toujours, et plus la somme est belle, meilleure est l’information. Il ne donne jamais de nom.' }];
}
if (global.window) {
  global.RP_ORDRES_DYNAMIQUES = global.RP_ORDRES_DYNAMIQUES || [];
  if (!global.RP_ORDRES_DYNAMIQUES.includes(ordresInformateurs)) global.RP_ORDRES_DYNAMIQUES.push(ordresInformateurs);
}

function modale(titre, html) {
  const m = global.document.getElementById('modal-postes');
  global.document.getElementById('postes-modal-title').textContent = titre;
  global.document.getElementById('postes-body').innerHTML = html;
  m?.classList.add('open');
}
function fermer() { global.document.getElementById('modal-postes')?.classList.remove('open'); }
function palierDe(bareme, montant) {
  return (bareme?.paliers || []).find(p => montant >= p.min && montant <= p.max) || null;
}
function profilTexte(i) { return i.profil === 'sujet' ? t('profil_sujet_' + i.sujet) : t('profil_' + i.profil); }

let dernierIci = null, paiementEnCours = false;
async function ouvrirInformateursIci(focus) {
  modale(t('titre'), '<div class="cpj-dialogue"><p class="cpj-note">' + esc(t('chargement')) + '</p></div>');
  const v = await lireIci(true);
  dernierIci = v;
  const liste = (v?.informateurs || []).filter(i => focus ? i.id === focus : i.id !== 'habitue_krasnov');
  if (!v || !v.bareme || !liste.length) {
    modale(t('titre'), '<div class="cpj-dialogue"><p class="cpj-note">' + esc(t('personne')) + '</p>'
      + '<button class="cpj-touche" onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')">' + esc(t('fermer')) + '</button></div>');
    return;
  }
  const b = v.bareme, cur = b.devise;
  const correct = (b.paliers || []).find(p => p.palier === 'correct') || { min: b.min };
  let html = '<div class="cpj-dialogue">';
  if (liste.length > 1) html += '<p class="cpj-note">' + esc(t('qui')) + '</p>';
  html += '<p class="cpj-note">' + esc(t('bareme', { min: b.min, max: b.max, cur })) + '</p><ul class="cpj-note" style="margin:.2rem 0 .6rem 1rem">'
    + (b.paliers || []).map(p => '<li>' + esc(t('palierLigne', { min: p.min, max: p.max, cur, libelle: t('palier_' + p.palier) })) + '</li>').join('') + '</ul>'
    + '<p class="cpj-note">' + esc(t('disparait')) + '</p>';
  liste.forEach((i, n) => {
    html += '<div style="margin:.7rem 0;padding:.6rem 0;border-top:1px solid rgba(169,141,86,.35)" data-informateur="' + esc(i.id) + '">'
      + '<div><strong>' + esc(i.nom) + '</strong>' + (i.role ? ' — ' + esc(i.role) : '') + '</div>'
      + '<p class="cpj-note">' + esc(profilTexte(i)) + '</p>'
      + '<input type="number" class="cpj-champ" id="info-montant-' + n + '" min="' + b.min + '" max="' + b.max + '" step="1" value="' + correct.min + '" style="width:5.5rem" '
      + 'oninput="informateurMajBouton(' + n + ')"> ' + esc(cur) + ' '
      + '<button class="cpj-touche cpj-primaire" id="info-payer-' + n + '" onclick="informateurPayer(' + n + ')"></button>'
      + '<p class="cpj-note" id="info-palier-' + n + '"></p></div>';
  });
  html += '</div>';
  modale(t('titre'), html);
  dernierIci._liste = liste;
  liste.forEach((i, n) => majBouton(n));
}

// Mise à jour en direct : le bouton dit la somme et le palier, et reste grisé hors barème (jamais de formulaire impossible).
function majBouton(n) {
  const b = dernierIci?.bareme; if (!b) return;
  const champ = global.document.getElementById('info-montant-' + n), bouton = global.document.getElementById('info-payer-' + n);
  const note = global.document.getElementById('info-palier-' + n);
  if (!champ || !bouton) return;
  const m = Math.floor(Number(champ.value));
  const p = Number.isFinite(m) ? palierDe(b, m) : null;
  bouton.disabled = !p || paiementEnCours;
  bouton.textContent = p ? t('payer', { montant: m, cur: b.devise }) : t('payer', { montant: '…', cur: b.devise });
  if (note) note.textContent = p ? t('palier_' + p.palier) : t('horsBareme', { min: b.min, max: b.max, cur: b.devise });
}

function refuser(v) {
  const r = v?.raison;
  const msg = (r && TXT_INFORMATEURS['r_' + r]) ? t('r_' + r) : t('r_defaut');
  if (typeof global.showToast === 'function') global.showToast(t('refus'), msg, false);
}

async function payer(n) {
  if (paiementEnCours) return;
  const i = dernierIci?._liste?.[n], b = dernierIci?.bareme;
  const m = Math.floor(Number(global.document.getElementById('info-montant-' + n)?.value));
  if (!i || !b || !palierDe(b, m)) { majBouton(n); return; }
  paiementEnCours = true; majBouton(n);
  const geste = 'hg-informateur:' + (st().char?.name || '') + ':' + i.id + ':' + m;
  let requete = null;
  try { requete = global.sessionStorage.getItem(geste); } catch (_) {}
  if (!requete) { requete = global.crypto.randomUUID(); try { global.sessionStorage.setItem(geste, requete); } catch (_) {} }
  let v = null;
  try { v = await global.sbRpcVerdict('informateur_payer', { p_requete: requete, p_informateur: i.id, p_montant: m }).catch(() => null); }
  finally { paiementEnCours = false; }
  if (v && !v.transport) { try { global.sessionStorage.removeItem(geste); } catch (_) {} }
  if (!v || v.ok !== true) { refuser(v); majBouton(n); return; }
  if (v.paie && typeof global.appliquerPaiementServeur === 'function') global.appliquerPaiementServeur(v.paie);
  if (typeof global.updateUI === 'function') global.updateUI();
  const cur = v.devise || b.devise, nom = v.informateur?.nom || i.nom;
  const lignes = Array.isArray(v.lignes) ? v.lignes : [];
  modale(t('reponseTitre', { nom }), '<div class="cpj-dialogue">'
    + '<div id="info-reponse" style="white-space:pre-line;margin-bottom:.7rem"></div>'
    + '<p class="cpj-note">' + esc(t('reponsePalier', { montant: v.montant, cur, libelle: t('palier_' + v.palier) })) + '</p>'
    + '<button class="cpj-touche" onclick="ouvrirInformateursIci()">' + esc(t('encore')) + '</button> '
    + '<button class="cpj-touche cpj-primaire" onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')">' + esc(t('fermer')) + '</button></div>');
  // Le texte du serveur reste du texte : jamais de HTML venu d'une réponse.
  const zone = global.document.getElementById('info-reponse'); if (zone) zone.textContent = lignes.join('\n');
  if (typeof global.addJournalEntry === 'function') {
    global.addJournalEntry(t('journal', { nom, montant: v.montant, cur }) + ' ' + lignes.join(' '), 'event-info');
    if (v.appris) global.addJournalEntry(t('carnet'), 'event-info');
  }
  if (v.appris) {
    if (typeof global.chargerSecrets === 'function') await global.chargerSecrets();
    redessiner();
  }
}

global.TXT_INFORMATEURS = TXT_INFORMATEURS;
global.ouvrirInformateursIci = ouvrirInformateursIci;
global.informateurMajBouton = majBouton;
global.informateurPayer = payer;
global.ordresInformateurs = ordresInformateurs;
global.informateursFermer = fermer;
})(typeof window !== 'undefined' ? window : globalThis);
