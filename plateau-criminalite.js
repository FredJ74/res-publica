// Criminalité — lot 1 : équipement et dissimulation (GAME-DESIGN-CRIMINALITE.md §§ 1 et 5, décisions de Fred des 18-19/11/2026).
// Lot 2 : Neutraliser par crime_neutraliser (résolution commune crim_resoudre_interne), cible masquée visée par jeton.
// Le serveur tranche tout : jets (se_cacher, crim_fouiller_cachettes), objet porté (crim_revetir / crim_retirer, marque
// `porte_par` dans l'inventaire), liste des présents (crim_presents : caché absent, masqué numéroté sans portrait),
// boutique « Équipement discret » (boutique_discretion_etat / _acheter), événements d'écran (crim_evenements_lire :
// démasquage à l'arrestation, débusqué). Cet écran affiche, rien de plus. Textes : français seulement (traductions à venir).
(function (global) {
'use strict';
const T = {
  fr: {
    shop: 'Équipement discret', buy: 'Acheter', cancel: 'Renoncer', traced: 'achat noté par le vendeur',
    bought: '{nom} acheté pour {paye} {cur}.', wear: 'Revêtir', remove: 'Retirer', worn: 'revêtu',
    woreOk: '{nom} : revêtu.', removedOk: '{nom} : retiré.',
    modeMasque: 'Vous êtes masqué(e) : les autres ne voient qu’un individu masqué.',
    search: '👁 Débusquer quelqu’un de caché (1 PA)',
    searchIntro: 'Vous inspectez la pièce à la recherche de quelqu’un qui s’y cacherait. Coût : <strong>1 PA</strong>.',
    searchOdds: 'Vos chances dépendent de votre perception ; une tenue ninja et la discrétion de celui qui se cache les réduisent. Policiers et agents de sécurité sont avantagés.',
    searchGo: 'Fouiller (1 PA)', searchDone: 'Fouille terminée', searchNone: 'Personne ne se cache ici, semble-t-il.',
    searchFound: 'Vous débusquez : {liste}.', masked: 'un individu masqué',
    flushed: 'Débusqué(e) !', flushedBy: '{par} vous a débusqué(e) : vous n’êtes plus caché(e).',
    flushedAnon: 'Quelqu’un vous a débusqué(e) : vous n’êtes plus caché(e).',
    unmaskTitle: 'Bas les masques !', unmaskText: 'Arrêté(e), vous êtes démasqué(e) : votre masque est rangé dans votre inventaire.',
    hideOk: 'Vous êtes caché(e)', hideOkText: 'Personne ne vous voit tant que vous restez dans cette pièce.',
    hideFail: 'Échec', hideFailText: 'Vous n’avez pas réussi à vous dissimuler. Vous pouvez réessayer.',
    hideCrit: 'Échec critique', hideCritText: 'Vous trébuchez bruyamment derrière le rideau. Votre moral en prend un coup (−15).',
    r_deja_cache: 'Vous êtes déjà caché(e) dans cette pièce.', r_hors_batiment: 'Il faut être dans une pièce.',
    r_pas_a_la_boutique: 'Il faut être dans la boutique.', r_fonds_insuffisants: 'Fonds insuffisants.',
    r_inventaire_plein: 'Inventaire plein.', r_objet_non_revetable: 'Cet objet ne se revêt pas.', r_deja_revetu: 'Vous le portez déjà.',
    r_pas_revetu: 'Vous ne le portez pas.', r_objet_introuvable: 'Objet introuvable : rouvrez votre inventaire.',
    r_emprisonne: 'Impossible en détention.', r_hospitalise: 'Impossible à l’hôpital.', r_pa_insuffisants: 'Pas assez de PA.',
    refused: 'Le serveur a refusé l’opération.',
    nTitle: 'Neutraliser — {nom}',
    nIntro: 'Le serveur tranche tout : réussite, détection, risque d’affrontement. Frapper depuis votre cachette aide ; un gilet pare-balles revêtu protège la cible. Le masque ne donne aucun bonus, mais cache votre identité.',
    nMode: '{label} — {pa} PA', nFeu: ' · −20 DIS', nArmeAbsente: ' (arme absente)',
    nOk: 'Cible neutralisée', nOkText: 'Votre cible s’effondre ; elle est conduite à l’hôpital.',
    nFail: 'Raté', nFailText: 'Votre tentative échoue. Vous pouvez retenter si vous avez encore des PA.',
    nCrit: 'Échec critique', nCritText: 'Maladresse : votre moral en prend un coup (−15).',
    nCombat: 'Affrontement !', nCombatText: 'Votre cible se défend : l’affrontement commence.',
    nIdent: 'Vous avez été identifié(e) : la police vous recherche ({jours} jour(s) de prison d’office).',
    nTrace: 'Quelqu’un vous a repéré(e), mais votre masque a préservé votre identité.',
    r_cible_introuvable: 'Cette personne n’est plus là.', r_pas_au_meme_endroit: 'Votre cible n’est plus dans la pièce.',
    r_arme_manquante: 'Vous n’avez pas l’arme nécessaire.', r_cible_indisponible: 'Cette personne est hors service.',
    r_meme_groupe: 'Vous ne pouvez pas viser un membre de votre groupe.', r_cible_protegee: 'Cette personne ne peut pas être visée.',
    r_cible_non_referencee: 'Cette personne ne peut pas être visée ici.', r_cible_invalide: 'Cible invalide.',
    r_cible_ambigue: 'Plusieurs personnes portent ce nom : impossible de viser.'
  }
};
const etat = () => (typeof state !== 'undefined' && state) ? state : {};
function langue() { try { const l = global.RPI18n && global.RPI18n.language; return (l && T[l]) ? l : 'fr'; } catch (_) { return 'fr'; } }
function texte(k, v) {
  let s = (T[langue()] && T[langue()][k]) || T.fr[k] || k;
  if (v) s = s.replace(/\{(\w+)\}/g, (m, n) => (v[n] !== undefined ? String(v[n]) : m));
  return s;
}
const esc = (s) => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const un = (r) => (Array.isArray(r) ? r[0] : r);
const uuid = () => (global.crypto && global.crypto.randomUUID) ? global.crypto.randomUUID()
  : 'xxxxxxxx-xxxx-4xxx-8xxx-xxxxxxxxxxxx'.replace(/x/g, () => Math.floor(Math.random() * 16).toString(16));
function devise() { return etat().country === 'soviet' ? 'PSK' : 'FR'; }
function motif(r) { const k = 'r_' + (r && r.raison); return T.fr[k] ? texte(k) : texte('refused'); }
function toast(t, b, ok) { if (typeof global.showToast === 'function') global.showToast(t, b, !!ok); }
function appliquerInventaire(r) {
  if (r && typeof global.sbAdopterInventaireServeur === 'function') { try { global.sbAdopterInventaireServeur(r); } catch (_) {} }
  else if (r && Array.isArray(r.inventory) && etat()) etat().inventory = r.inventory;
  if (typeof global.renderInventory === 'function') { try { global.renderInventory(); } catch (_) {} }
}
async function rpc(fn, params) {
  if (typeof global.sbRpc !== 'function') return null;
  return un(await global.sbRpc(fn, params || {}).catch(() => null));
}
function fermerModale() { const m = global.document.getElementById('modal-postes'); if (m) m.classList.remove('open'); }

// ── Boutique « Équipement discret » (armureries, marchés) ───────────────────────────────────────────────────────
// Lieux de vente : copie d'affichage de la table serveur crim_boutiques (le serveur refuse ailleurs).
const LIEUX_BOUTIQUE = [
  ['republic', 'capitale', 'armurerie', 'magasin'], ['republic', 'ville_b', 'armurerie', 'magasin'],
  ['republic', 'ville_a', 'chasse-peche-psm', 'boutique'], ['soviet', 'capitale', 'armurerie', 'magasin'],
  ['soviet', 'ville_a', 'armurerie', 'magasin'], ['republic', 'capitale', 'marche', 'marche_ext'],
  ['republic', 'ville_b', 'marche', 'marche_ext'], ['republic', 'ville_a', 'marche-psm', 'etals'],
  ['soviet', 'capitale', 'marche', 'marche_ext'], ['soviet', 'ville_a', 'marche', 'marche_ext'], ['soviet', 'ville_b', 'marche', 'marche_ext']
];
function ordresBoutiqueDiscretion(buildingId, roomId, ville) {
  const pays = etat().country;
  if (!LIEUX_BOUTIQUE.some(l => l[0] === pays && l[1] === ville && l[2] === buildingId && l[3] === roomId)) return [];
  return [{fn:'boutique_discretion', label:'Équipement discret', pa:0, cost:0, type:'legal', icon:'ti-mask', successRate:100,
    desc:'Masques, tenue ninja et, chez les armuriers, gilet pare-balles, kit de crochetage et pied-de-biche.'}];
}
if (global.window) {
  global.RP_ORDRES_DYNAMIQUES = global.RP_ORDRES_DYNAMIQUES || [];
  if (!global.RP_ORDRES_DYNAMIQUES.includes(ordresBoutiqueDiscretion)) global.RP_ORDRES_DYNAMIQUES.push(ordresBoutiqueDiscretion);
}

let achatEnCours = false;
async function ouvrirBoutiqueDiscretion() {
  const e = await rpc('boutique_discretion_etat');
  if (!e || e.ok !== true) { toast(texte('shop'), motif(e), false); return; }
  const titre = global.document.getElementById('postes-modal-title');
  if (titre) titre.textContent = texte('shop');
  let html = '<div class="cpj-dialogue" style="padding:1rem;display:flex;flex-direction:column;gap:.5rem">';
  for (const o of (e.offre || [])) {
    html += '<div style="display:flex;justify-content:space-between;align-items:center;gap:.5rem">'
      + '<span>' + esc(o.nom) + (o.trace ? ' <span class="cpj-note" style="font-size:.75rem">(' + esc(texte('traced')) + ')</span>' : '') + '</span>'
      + '<button class="cpj-touche cpj-primaire" data-cle="' + esc(o.cle) + '" onclick="acheterDiscretion(this.dataset.cle)">'
      + esc(texte('buy')) + ' — ' + esc(o.prix) + ' ' + esc(devise()) + '</button></div>';
  }
  html += '<button class="cpj-touche" style="margin-top:.5rem" onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')">' + esc(texte('cancel')) + '</button></div>';
  global.document.getElementById('postes-body').innerHTML = html;
  global.document.getElementById('modal-postes').classList.add('open');
}
async function acheterDiscretion(cle) {
  if (achatEnCours || !cle) return;
  // Vente légale d'une protection : règle générale des interdictions votées, avant tout débit (comme l'ancien achat du gilet).
  if (cle === 'gilet' && typeof global.assembleeControlerVenteLegale === 'function'
      && !(await global.assembleeControlerVenteLegale([{ type: 'protection' }]))) return;
  achatEnCours = true;
  try {
    const r = await rpc('boutique_discretion_acheter', { p_requete: uuid(), p_cle: cle });
    if (!r || r.ok !== true) { toast(texte('shop'), motif(r), false); return; }
    appliquerInventaire(r);
    const s = etat();
    if (s && typeof r.liquide === 'number') s.liquide = r.liquide;
    if (s && typeof r.arg === 'number') s.arg = r.arg;
    fermerModale();
    const nom = (r.inventory || []).slice().reverse().find(i => i && (i.generique_id === cle || (cle === 'gilet' && i.type === 'protection')));
    toast(texte('shop'), texte('bought', { nom: (nom && nom.name) || cle, paye: r.paye, cur: devise() }), true);
    if (typeof global.updateUI === 'function') global.updateUI();
  } finally { achatEnCours = false; }
}

// ── Revêtir / Retirer (0 PA) ────────────────────────────────────────────────────────────────────────────────────
// Affichage seulement : la catégorie réelle est décidée par crim_objet_categorie_interne côté serveur.
function objetRevetable(item) {
  if (!item) return false;
  return !!item.revetable || item.produitMilitaire === 'gilet_pare_balles' || (item.type === 'protection' && /^gilet/i.test(item.name || ''));
}
function objetPorte(item) { return !!item && !!item.porte_par && item.porte_par === (etat().char && etat().char.name); }
function boutonRevetir(item, idx, style) {
  if (!objetRevetable(item)) return '';
  const porte = objetPorte(item);
  return '<button onclick="' + (porte ? 'crimRetirer' : 'crimRevetir') + '(' + Number(idx) + ')" style="' + (style || '') + '">'
    + '<i class="ti ' + (porte ? 'ti-hanger-off' : 'ti-hanger') + '"></i> ' + esc(texte(porte ? 'remove' : 'wear')) + '</button>';
}
function badgeRevetu(item) { return objetPorte(item) ? ' <span style="color:#8aca6a;font-size:.75rem">(' + esc(texte('worn')) + ')</span>' : ''; }
async function crimPorter(fn, idx) {
  const item = (etat().inventory || [])[idx];
  if (!item) return;
  const r = await rpc(fn, { p_index: idx, p_signature: { name: item.name, type: item.type, stackKey: item.stackKey } });
  if (!r || r.ok !== true) { toast(item.name, motif(r), false); return; }
  appliquerInventaire(r);
  fermerModale();
  toast(item.name, texte(fn === 'crim_revetir' ? 'woreOk' : 'removedOk', { nom: r.objet || item.name })
    + (r.categorie === 'masque' && fn === 'crim_revetir' ? ' ' + texte('modeMasque') : ''), true);
  if (typeof global.updateUI === 'function') global.updateUI();
  if (r.categorie === 'masque' && typeof global.chargerVraisJoueursPresents === 'function') global.chargerVraisJoueursPresents();
}
const crimRevetir = (idx) => crimPorter('crim_revetir', idx);
const crimRetirer = (idx) => crimPorter('crim_retirer', idx);

// ── Se cacher : messages selon le verdict du serveur (le jet est tiré par se_cacher) ────────────────────────────
function messageSeCacher(v) {
  if (!v || v.ok !== true) {
    if (v && T.fr['r_' + v.raison]) { toast(texte('hideFail'), motif(v), false); return true; }
    return false;
  }
  if (v.cache) toast(texte('hideOk'), texte('hideOkText'), true);
  else if (v.critique) toast(texte('hideCrit'), texte('hideCritText'), false);
  else toast(texte('hideFail'), texte('hideFailText'), false);
  if (typeof v.moral === 'number' && etat()) etat().moral = v.moral;
  return true;
}

// ── Fouiller les cachettes (1 PA), dans le menu « Fouiller ou voler » ───────────────────────────────────────────
function ouvrirFouilleCachettes() {
  const titre = global.document.getElementById('postes-modal-title');
  if (titre) titre.textContent = texte('searchGo');
  global.document.getElementById('postes-body').innerHTML = '<div class="cpj-dialogue" style="padding:1rem">'
    + '<p class="cpj-note">' + texte('searchIntro') + '</p><p class="cpj-note">' + esc(texte('searchOdds')) + '</p>'
    + '<div style="margin-top:1rem;display:flex;gap:.5rem;flex-wrap:wrap">'
    + '<button class="cpj-touche cpj-primaire" onclick="fouilleCachettesConfirmer()">' + esc(texte('searchGo')) + '</button>'
    + '<button class="cpj-touche" onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')">' + esc(texte('cancel')) + '</button></div></div>';
  global.document.getElementById('modal-postes').classList.add('open');
}
async function fouilleCachettesConfirmer() {
  fermerModale();
  const r = await rpc('crim_fouiller_cachettes');
  if (!r || r.ok !== true) { toast(texte('searchDone'), motif(r), false); return; }
  if (etat() && typeof r.pa === 'number') etat().pa = r.pa;
  if (typeof global.updateUI === 'function') global.updateUI();
  const trouves = Array.isArray(r.trouves) ? r.trouves : [];
  if (!trouves.length) { toast(texte('searchDone'), texte('searchNone'), true); return; }
  toast(texte('searchDone'), texte('searchFound', { liste: trouves.map(t => t.masque ? texte('masked') : t.nom).join(', ') }), true);
  if (typeof global.chargerVraisJoueursPresents === 'function') global.chargerVraisJoueursPresents();
}

// ── Neutraliser (lot 2) : crime_neutraliser tranche tout (jet, détection, passage au combat) ─────────────────────
// Aucun taux calculé ici. Un individu masqué est visé par son jeton (crim_presents), jamais par un nom.
function cibleNeutraliser(enc) { try { return JSON.parse(decodeURIComponent(enc)); } catch (_) { return null; } }
function identifiantCible(c) {
  if (!c) return '';
  if (c.jeton) return c.jeton;
  if (c.isPJ) return c.name;
  return c.socleId || c.pnjSocleId || (c.name ? String(c.name).replace(/ \(PNJ\)$/, '') : c.id);
}
function possedeArme(m) {
  if (!m || !m.sousTypes) return true;
  return (etat().inventory || []).some(i => i && i.type === 'arme' && m.sousTypes.includes(i.sousType));
}
function ouvrirNeutraliser(enc) {
  const c = cibleNeutraliser(enc);
  if (!c) return;
  const modes = (typeof global.NEUTRALISER_MODES === 'object' && global.NEUTRALISER_MODES) ? global.NEUTRALISER_MODES
    : (typeof NEUTRALISER_MODES === 'object' ? NEUTRALISER_MODES : {});
  const titre = global.document.getElementById('postes-modal-title');
  if (titre) titre.textContent = texte('nTitle', { nom: String(c.name || '').replace(/ \(PNJ\)$/, '') });
  let html = '<div class="cpj-dialogue"><p class="cpj-note">' + esc(texte('nIntro')) + '</p>';
  for (const [cle, m] of Object.entries(modes)) {
    const dispo = possedeArme(m);
    html += '<button class="cpj-touche" ' + (dispo ? '' : 'disabled ') + 'onclick="crimNeutraliserConfirmer(\'' + enc + '\',\'' + cle + '\')">'
      + esc(texte('nMode', { label: m.label, pa: m.paPJ })) + (cle === 'feu' ? esc(texte('nFeu')) : '') + (dispo ? '' : esc(texte('nArmeAbsente'))) + '</button>';
  }
  global.document.getElementById('postes-body').innerHTML = html + '</div>';
  global.document.getElementById('modal-postes').classList.add('open');
}
async function crimNeutraliserConfirmer(enc, mode) {
  fermerModale();
  const c = cibleNeutraliser(enc);
  if (!c) return;
  const r = await rpc('crime_neutraliser', { p_cible: identifiantCible(c), p_mode: mode, p_requete: uuid() });
  if (!r || r.ok !== true) { toast(texte('nFail'), motif(r), false); return; }
  if (r.paie && typeof global.appliquerPaiementServeur === 'function') global.appliquerPaiementServeur(r.paie);
  const e = etat();
  if (typeof r.dis === 'number') e.dis = r.dis;
  if (typeof r.moral === 'number') e.moral = r.moral;
  if (Array.isArray(r.recherche)) e.recherche = r.recherche;
  let suite = '';
  if (r.identifie) suite = ' ' + texte('nIdent', { jours: r.peine_jours == null ? '?' : r.peine_jours });
  else if (r.trace) suite = ' ' + texte('nTrace');
  if (r.issue === 'reussite') toast(texte('nOk'), texte('nOkText') + suite, true);
  else if (r.issue === 'combat') toast(texte('nCombat'), texte('nCombatText'), false);
  else if (r.echec_critique) toast(texte('nCrit'), texte('nCritText') + suite, false);
  else toast(texte('nFail'), texte('nFailText') + suite, false);
  if (typeof global.updateUI === 'function') global.updateUI();
  if (r.issue === 'combat' && Number.isSafeInteger(Number(r.bataille)) && typeof global.ouvrirPanneauCombat === 'function')
    await global.ouvrirPanneauCombat(Number(r.bataille));
}

// ── Événements d'écran : « Bas les masques ! » (arrestation d'un PJ masqué), débusqué ───────────────────────────
function injecterStyle() {
  const doc = global.document;
  if (!doc || doc.getElementById('crim-style')) return;
  const st = doc.createElement('style');
  st.id = 'crim-style';
  st.textContent = '#crim-demasque{position:fixed;inset:0;z-index:2147483000;display:flex;align-items:center;justify-content:center;'
    + 'background:rgba(12,16,22,.88);padding:16px;animation:crimFond .4s ease-out}'
    + '#crim-demasque .crim-scene{position:relative;width:min(340px,90vw);text-align:center;color:#e8eef5}'
    + '#crim-demasque .crim-visage{position:relative;width:160px;height:160px;margin:0 auto 1rem;border-radius:50%;'
    + 'background:radial-gradient(circle at 50% 40%,#e9c9a6 0 55%,#c9a37f 56% 100%);box-shadow:0 0 0 4px #2b3644}'
    + '#crim-demasque .crim-oeil{position:absolute;top:58px;width:16px;height:16px;border-radius:50%;background:#1d2530}'
    + '#crim-demasque .crim-oeil.g{left:46px}#crim-demasque .crim-oeil.d{right:46px}'
    + '#crim-demasque .crim-bouche{position:absolute;left:58px;top:104px;width:44px;height:14px;border-radius:0 0 22px 22px;background:#7a3a3a}'
    + '#crim-demasque .crim-masque{position:absolute;left:18px;top:40px;width:124px;height:52px;border-radius:26px 26px 40px 40px;'
    + 'background:linear-gradient(90deg,#7b2fbe,#d4af37 50%,#7b2fbe);box-shadow:0 2px 6px rgba(0,0,0,.5);'
    + 'animation:crimArrache 1.4s .6s cubic-bezier(.5,-0.4,.7,1) forwards}'
    + '#crim-demasque .crim-masque::before,#crim-demasque .crim-masque::after{content:"";position:absolute;top:16px;width:26px;height:18px;'
    + 'border-radius:50%;background:#10151c}#crim-demasque .crim-masque::before{left:22px}#crim-demasque .crim-masque::after{right:22px}'
    + '#crim-demasque .crim-titre{font-family:Bebas Neue,Arial Narrow,sans-serif;font-size:2.2rem;letter-spacing:.08em;color:#ffd98a;'
    + 'opacity:0;animation:crimTitre .5s 1.6s ease-out forwards}'
    + '#crim-demasque .crim-texte{font-size:.95rem;opacity:0;animation:crimTitre .5s 2s ease-out forwards}'
    + '@keyframes crimFond{from{opacity:0}to{opacity:1}}'
    + '@keyframes crimArrache{0%{transform:none}25%{transform:translateY(-6px) rotate(-4deg)}100%{transform:translate(160px,-220px) rotate(70deg);opacity:0}}'
    + '@keyframes crimTitre{from{opacity:0;transform:scale(.6)}to{opacity:1;transform:none}}'
    + '@media (prefers-reduced-motion:reduce){#crim-demasque *{animation-duration:.01s!important;animation-delay:0s!important}}';
  doc.head.appendChild(st);
}
function animationDemasquage() {
  const doc = global.document;
  if (!doc || !doc.body || doc.getElementById('crim-demasque')) return;
  injecterStyle();
  const f = doc.createElement('div');
  f.id = 'crim-demasque';
  f.setAttribute('role', 'dialog');
  f.innerHTML = '<div class="crim-scene"><div class="crim-visage"><span class="crim-oeil g"></span><span class="crim-oeil d"></span>'
    + '<span class="crim-bouche"></span><span class="crim-masque"></span></div>'
    + '<div class="crim-titre">' + esc(texte('unmaskTitle')) + '</div><div class="crim-texte">' + esc(texte('unmaskText')) + '</div>'
    + '<button class="cpj-touche" style="margin-top:1rem" onclick="document.getElementById(\'crim-demasque\').remove()">OK</button></div>';
  f.addEventListener('click', (e) => { if (e.target === f) f.remove(); });
  doc.body.appendChild(f);
}
let lectureEnCours = false;
async function lireEvenementsCrim() {
  if (lectureEnCours || !(etat().char && etat().char.name)) return;
  lectureEnCours = true;
  try {
    const r = await rpc('crim_evenements_lire');
    if (!r || r.ok !== true) return;
    for (const ev of (r.evenements || [])) {
      if (ev.type === 'demasque') animationDemasquage();
      else if (ev.type === 'debusque') toast(texte('flushed'), ev.donnees && ev.donnees.par ? texte('flushedBy', { par: ev.donnees.par }) : texte('flushedAnon'), false);
    }
  } finally { lectureEnCours = false; }
}
function demarrer() {
  setTimeout(lireEvenementsCrim, 8000);
  setInterval(lireEvenementsCrim, 60000);
}
if (global.document && global.setTimeout) {
  if (global.document.readyState !== 'loading') demarrer();
  else global.document.addEventListener('DOMContentLoaded', demarrer);
}

global.RPCriminalite = { T, texte, objetRevetable, objetPorte, ordresBoutiqueDiscretion, LIEUX_BOUTIQUE, identifiantCible };
Object.assign(global, { ouvrirBoutiqueDiscretion, acheterDiscretion, boutonRevetir, badgeRevetu, crimRevetir, crimRetirer,
  messageSeCacher, ouvrirFouilleCachettes, fouilleCachettesConfirmer, lireEvenementsCrim, animationDemasquage,
  ouvrirNeutraliser, crimNeutraliserConfirmer });
})(typeof window !== 'undefined' ? window : globalThis);
