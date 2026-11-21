// CHANTIER « CONSTRUCTION » — vue et fenêtre unique (GAME-DESIGN-CHANTIERS-IMAGES-20261120.md, décisions de Fred des
// 20 et 21/11/2026). Aucune règle serveur nouvelle ici : chaque action passe par le chemin existant (chantier_commande,
// vendre_materiaux_chantier) ; l'écran ne fait que lire l'état du serveur et le montrer.
//  1. Rafraîchissement : toute relecture du terrain (action, retour de commande, suivi périodique) redessine aussitôt
//     l'image, la surcouche, les ordres et la fenêtre ouverte. Suivi toutes les 20 s pour voir les actions des autres.
//  2. Image par étape : démarrage commun, puis gros œuvre / façade par ville et par gabarit, puis bâtiment achevé ;
//     repli sur l'image disponible la plus proche, jamais d'image cassée (convention images/chantiers/<ville>/…).
//  3. Surcouche d'avancement sur l'image (vraies données du serveur).
//  4. Fenêtre unique « Le chantier » : État (tous), Participer (tous), Gestion (maître d'ouvrage) ; une seule opération
//     validée à la fois, totaux en direct, Valider grisé avec l'explication quand il manque quelque chose.
(function (global) {
'use strict';

// Textes (français ; clés listées dans RELAIS pour Codex).
const TXT = {
  titre: 'Le chantier', etat: 'État', participer: 'Participer', gestion: 'Gestion',
  jour: 'Jour {x} / {n}', etape_demarrage: 'Démarrage', etape_gros_oeuvre: 'Gros œuvre', etape_facade: 'Façade et finitions', etape_acheve: 'Bâtiment achevé',
  etape: 'Étape : {e}', prochaine: 'Prochaine étape : {e}', fin_prevue: 'Fin prévue : {date}', avance_ouverte: 'Jour d’avance ouvert : {h} heure(s) déjà faites sur {c}',
  arret_fin: 'À l’arrêt : appel de fonds non versé ({m} {cur} manquants)', arret_mat: 'À l’arrêt : matériaux manquants', attente_reception: 'Travaux achevés : le bâtiment attend sa réception',
  tresorerie: 'Trésorerie : {v} {cur}', verse: 'Fonds versés : {v} / {t} {cur}', prochain_appel: 'Prochain appel de fonds : {m} {cur} avant le jour {j}', appels_ok: 'Tout le financement est versé.',
  stock: 'Matériaux sur place / besoin du jour', heures: 'Heures du jour : {f} faites, {r} restante(s)', salaire: 'Salaire horaire : {v} {cur}',
  prix_rachat: 'Prix de rachat des matériaux : bois {b}, minerai {mi}, métal {me} {cur} l’unité',
  explication: 'Si les joueurs terminent les heures du jour, le jour suivant s’ouvre en avance : le chantier gagne une journée cette nuit.',
  m_bois: 'Bois', m_minerai: 'Minerai', m_metal: 'Métal',
  a_travailler: 'Travailler sur le chantier', a_vendre: 'Vendre des matériaux au chantier', a_donner: 'Donner des matériaux au chantier',
  a_prix: 'Prix de rachat des matériaux', a_taux: 'Salaire horaire des ouvriers', a_fonds: 'Apporter des fonds', a_lots: 'Définir les lots', a_reception: 'Réceptionner le bâtiment',
  heures_label: 'Nombre d’heures (1 PA par heure, {v} {cur} de l’heure)', matiere: 'Matière', quantite: 'Quantité', prix_unitaire: 'Prix unitaire : {p} {cur} · total : {t} {cur}',
  don_note: 'Don gratuit : aucun paiement.', prix_note: 'C’est le prix auquel le chantier rachète les matériaux aux joueurs.', taux_note: 'Minimum {m} {cur} de l’heure, payé par la trésorerie du chantier.',
  fonds_note: 'Le montant est prélevé sur votre argent et versé à la trésorerie du chantier.', montant: 'Montant ({cur})',
  annuler: 'Annuler', valider: 'Valider', total_pa: 'PA : {pa}', total_argent: 'Argent : {v} {cur}', recoit: 'Vous recevez : {v} {cur}',
  r_choisir: 'Choisissez d’abord une action.', r_pa: 'Il vous manque des PA.', r_heures: 'Plus aucune heure de travail disponible aujourd’hui.', r_treso: 'La trésorerie du chantier ne peut pas payer ces heures.',
  r_stock: 'Vous n’avez pas assez de cette matière.', r_quantite: 'Indiquez une quantité entière positive.', r_mat_refus: 'Le chantier n’accepte plus de matériaux.',
  r_argent: 'Vous n’avez pas assez d’argent.', r_prix: 'Indiquez des prix entiers, positifs ou nuls.', r_taux: 'Le salaire doit être d’au moins {m} {cur}.', r_montant: 'Indiquez un montant entier positif.',
  r_tresorerie_achat: 'La trésorerie du chantier ne peut pas payer cette vente.',
  ok_titre: 'Le chantier', ordre: 'Le chantier'
};
const t = (k, v) => String(TXT[k] || k).replace(/\{(\w+)\}/g, (m, c) => (v && v[c] != null) ? String(v[c]) : m);
const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const etat = () => (typeof state !== 'undefined' && state) ? state : {};
const cur = () => (typeof COUNTRIES !== 'undefined' && COUNTRIES[etat().country]?.cur) || 'FR';
const fr = n => Math.round(Number(n) || 0).toLocaleString('fr-FR');
const estTerrain = id => typeof id === 'string' && id.startsWith('terrain-a-batir');
const ts = () => (typeof getTerrainState === 'function' ? getTerrainState(etat().currentBuilding) : null) || {};

// ── Images ───────────────────────────────────────────────────────────────────────────────────
const VILLES = { republic: { capitale: 'luthecia', ville_a: 'psm', ville_b: 'montrouge' },
                 soviet: { capitale: 'novomirsk', ville_a: 'starovka', ville_b: 'krasnov' } };
const GABARIT_HAUT = new Set(['building', 'logements_moyen', 'logements_barre']);
const DEMARRAGE = 'images/chantier-en-cours.webp';
function villeSlug() { const s = etat(); return (VILLES[s.country] || {})[s.currentCity] || String(s.currentCity || ''); }
function fraction(ch) { const d = Number(ch && ch.dureeJours) || 0; return d > 0 ? Math.max(0, Math.min(1, (Number(ch.progressionJours) || 0) / d)) : 0; }
function etapeDe(ch) { const f = fraction(ch); return f >= 1 ? 'acheve' : f < 1 / 3 ? 'demarrage' : f < 2 / 3 ? 'gros_oeuvre' : 'facade'; }
// Candidats, du plus juste au plus général ; le dernier existe toujours.
function candidatsImage(t0) {
  const v = villeSlug(), base = 'images/chantiers/' + v + '/';
  if (t0 && t0.chantier) {
    const ch = t0.chantier, g = GABARIT_HAUT.has(ch.niveau) ? 'haut' : 'bas', e = etapeDe(ch);
    if (e === 'demarrage') return [DEMARRAGE];
    if (e === 'gros_oeuvre') return [base + 'gros-oeuvre-' + g + '.webp', DEMARRAGE];
    return [base + 'facade-' + g + '.webp', base + 'gros-oeuvre-' + g + '.webp', DEMARRAGE];
  }
  if (t0 && t0.niveau_construction) {
    const fiche = (typeof NIVEAUX_CONSTRUCTION !== 'undefined' && NIVEAUX_CONSTRUCTION[t0.niveau_construction]?.imageUrl) || DEMARRAGE;
    return [base + 'final-' + String(t0.niveau_construction).replace(/_/g, '-') + '.webp', fiche];
  }
  return [];
}
const existe = new Map();   // url -> true | false | Promise
function sonder(url) {
  if (existe.has(url)) return existe.get(url);
  if (typeof Image === 'undefined') return Promise.resolve(false);
  const p = new Promise(res => { const i = new Image(); i.onload = () => { existe.set(url, true); res(true); }; i.onerror = () => { existe.set(url, false); res(false); }; i.src = url; });
  existe.set(url, p); return p;
}
// Image tout de suite (meilleure connue), puis la plus juste dès qu'elle est confirmée.
function imageImmediate(t0) {
  const c = candidatsImage(t0);
  return c.find(u => existe.get(u) === true) || c[c.length - 1] || null;
}
async function imageResolue(t0) {
  const c = candidatsImage(t0);
  for (let i = 0; i < c.length - 1; i++) if (await sonder(c[i])) return c[i];
  return c[c.length - 1] || null;
}
function poserImage(url) {
  const el = global.document && global.document.getElementById('piece-image');
  if (!el || !url) return;
  el.style.background = 'linear-gradient(180deg, rgba(0,0,0,0) 0%, rgba(0,0,0,0) 65%, rgba(0,0,0,0.18) 100%), url(\'' + url + '\') center/cover no-repeat';
}

// ── Surcouche d'avancement ───────────────────────────────────────────────────────────────────
function dateFinPrevue(ch) {
  const reste = Math.max(0, Math.ceil((Number(ch.dureeJours) || 0) - (Number(ch.progressionJours) || 0)));
  const d = new Date(Date.now() + reste * 86400e3);
  try { return d.toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', timeZone: 'Europe/Paris' }); } catch (_) { return d.toISOString().slice(0, 10); }
}
// Jour d'avance (serveur, migration 20261121140000) : {jour, heures} ; ouvert le jour même seulement.
function jourParis() { try { return new Date().toLocaleDateString('en-CA', { timeZone: 'Europe/Paris' }); } catch (_) { return new Date().toISOString().slice(0, 10); } }
function avanceHeures(ch) { const a = ch && ch.jourAvance; return a && a.jour === jourParis() ? Math.max(0, Math.floor(Number(a.heures) || 0)) : 0; }
function capacite(ch) { return typeof capaciteHeuresJourChantier === 'function' ? Math.floor(capaciteHeuresJourChantier(ch)) : 0; }
// Heures encore possibles : celles du jour, puis celles du jour d'avance si le jour peut être entièrement fait.
function heuresPossibles(ch) {
  const rest = typeof heuresUtilesRestantes === 'function' ? heuresUtilesRestantes(ch) : 0;
  const cap = capacite(ch), faites = Math.floor(Number(ch.heuresFaites) || 0);
  return rest + (cap > 0 && faites + rest >= cap ? Math.max(0, cap - avanceHeures(ch)) : 0);
}
const SUIVANTE = { demarrage: 'gros_oeuvre', gros_oeuvre: 'facade', facade: 'acheve' };
function manqueFinancement(ch) {
  if (typeof montantManquant === 'function') { try { return montantManquant(Number(ch.totalVerse) || 0, Number(ch.progressionJours) || 0, Number(ch.dureeJours) || 0, Number(ch.coutTotal) || 0); } catch (_) {} }
  return 0;
}
function lignesSurcouche(ch) {
  const e = etapeDe(ch), pct = Math.floor(fraction(ch) * 100), d = Number(ch.dureeJours) || 0;
  const l = [t('jour', { x: Math.min(d, Math.floor(Number(ch.progressionJours) || 0) + 1), n: d }) + ' · ' + pct + ' %', t('etape', { e: t('etape_' + e) })];
  if (ch.attenteReception) l.push(t('attente_reception'));
  else {
    if (SUIVANTE[e]) l.push(t('prochaine', { e: t('etape_' + SUIVANTE[e]) }));
    l.push(t('fin_prevue', { date: dateFinPrevue(ch) }));
  }
  if (avanceHeures(ch) > 0) l.push(t('avance_ouverte', { h: avanceHeures(ch), c: capacite(ch) }));
  if (ch.arrete === 'financement') l.push(t('arret_fin', { m: fr(manqueFinancement(ch)), cur: cur() }));
  if (ch.arrete === 'penurie_materiaux') l.push(t('arret_mat'));
  return { pct, l, alerte: !!ch.arrete };
}
function poserSurcouche(t0) {
  const doc = global.document, hote = doc && doc.getElementById('piece-image');
  let s = doc && doc.getElementById('chantier-surcouche');
  if (!hote || !t0 || !t0.chantier) { if (s) s.remove(); return; }
  const { pct, l, alerte } = lignesSurcouche(t0.chantier);
  if (!s) { s = doc.createElement('div'); s.id = 'chantier-surcouche'; s.setAttribute('role', 'status'); }
  if (s.parentNode !== hote) hote.appendChild(s);
  if (global.getComputedStyle && global.getComputedStyle(hote).position === 'static') hote.style.position = 'relative';
  s.style.cssText = 'position:absolute;left:8px;bottom:8px;max-width:min(320px,70%);background:rgba(8,10,14,.78);color:#e8e2d0;border:1px solid rgba(201,168,76,.55);'
    + 'border-radius:4px;padding:.45rem .6rem;font-size:.78rem;line-height:1.35;pointer-events:none;z-index:2';
  s.innerHTML = '<div style="height:6px;background:rgba(255,255,255,.15);border-radius:3px;overflow:hidden;margin-bottom:.35rem">'
    + '<div style="height:100%;width:' + pct + '%;background:' + (alerte ? '#c0603a' : '#C9A84C') + '"></div></div>'
    + l.map((x, i) => '<div' + (i === 0 ? ' style="font-weight:600"' : '') + '>' + esc(x) + '</div>').join('');
}

// ── Rafraîchissement immédiat ────────────────────────────────────────────────────────────────
let rendu = null;
function rafraichirVueChantier() {
  const s = etat(), id = s.currentBuilding;
  if (!estTerrain(id) || !global.document) return;
  const t0 = ts();
  poserImage(imageImmediate(t0));
  poserSurcouche(t0);
  const cle = JSON.stringify([id, !!t0.chantier, t0.niveau_construction || null]);
  imageResolue(t0).then(u => { if (etat().currentBuilding === id && u) poserImage(u); });
  if (rendu !== null && typeof renderRoomActions === 'function' && typeof BUILDINGS !== 'undefined') {
    const room = BUILDINGS[id]?.rooms?.[s.currentRoom];
    if (room) { try { renderRoomActions(room, id, s.currentRoom); } catch (_) {} }
  }
  rendu = cle;
  const f = global.document.getElementById('chantier-fenetre');
  if (f && !f.contains(global.document.activeElement)) ouvrirFenetreChantier(true);
}
function brancher() {
  if (typeof global.chargerTerrainState === 'function' && !global.chargerTerrainState.__vueChantier) {
    const orig = global.chargerTerrainState;
    const enveloppe = async function (id) {
      const r = await orig.apply(this, arguments);
      if (id && id === etat().currentBuilding) rafraichirVueChantier();
      return r;
    };
    enveloppe.__vueChantier = true; global.chargerTerrainState = enveloppe;
  }
  if (typeof global.enterRoom === 'function' && !global.enterRoom.__vueChantier) {
    const orig = global.enterRoom;
    const enveloppe = function () { const r = orig.apply(this, arguments); rendu = null; if (estTerrain(etat().currentBuilding)) rafraichirVueChantier(); return r; };
    enveloppe.__vueChantier = true; global.enterRoom = enveloppe;
  }
}
// Suivi des actions des autres joueurs : relecture du terrain toutes les 20 s quand on le regarde.
function suivre() {
  const s = etat(), doc = global.document;
  if (!estTerrain(s.currentBuilding) || (doc && doc.hidden) || typeof global.chargerTerrainState !== 'function') return;
  global.chargerTerrainState(s.currentBuilding).catch(() => null);
}

// ── Fenêtre unique « Le chantier » ───────────────────────────────────────────────────────────
const choix = { action: null };
function maitreOuvrage(t0) { return typeof constructionPeutGerer === 'function' ? constructionPeutGerer(t0) : false; }
function stockPJ(m) { return (etat().inventory || []).filter(i => i && i.stackable && i.stackKey === m).reduce((a, i) => a + (Number(i.qty) || 0), 0); }
function argentPJ() { const s = etat(); return Number(s.liquide ?? s.char?.liquide ?? s.money ?? 0) || 0; }
function besoinJour(ch) {
  try { return besoinMateriauxJourChantier(ch, numeroJourChantier(ch)) || {}; } catch (_) { return {}; }
}
function sectionEtat(ch) {
  const c = cur(), d = Number(ch.dureeJours) || 0, besoin = besoinJour(ch), st = ch.stockMateriaux || {};
  const cap = typeof capaciteHeuresJourChantier === 'function' ? Math.floor(capaciteHeuresJourChantier(ch)) : 0;
  const faites = Math.floor(Number(ch.heuresFaites) || 0), rest = typeof heuresUtilesRestantes === 'function' ? heuresUtilesRestantes(ch) : Math.max(0, cap - faites);
  const manque = manqueFinancement(ch);
  const prochainSeuil = (Number(ch.totalVerse) || 0) >= (Number(ch.coutTotal) || 0) ? null
    : (Number(ch.totalVerse) || 0) >= Math.ceil((Number(ch.coutTotal) || 0) * .7) ? { m: (Number(ch.coutTotal) || 0) - (Number(ch.totalVerse) || 0), j: Math.floor(d * 2 / 3) + 1 }
    : { m: Math.ceil((Number(ch.coutTotal) || 0) * .7) - (Number(ch.totalVerse) || 0), j: Math.floor(d / 3) + 1 };
  const { pct, l } = lignesSurcouche(ch);
  const p = ch.prixAchatPJ || {};
  return '<div class="chantier-etat">'
    + '<div style="height:8px;background:rgba(255,255,255,.12);border-radius:4px;overflow:hidden;margin:.2rem 0 .5rem"><div style="height:100%;width:' + pct + '%;background:#C9A84C"></div></div>'
    + l.map(x => '<p class="cpj-note" style="margin:.1rem 0">' + esc(x) + '</p>').join('')
    + '<p class="cpj-note" style="margin:.4rem 0 .1rem">' + esc(t('tresorerie', { v: fr(ch.tresorerie), cur: c })) + ' · ' + esc(t('verse', { v: fr(ch.totalVerse), t: fr(ch.coutTotal), cur: c })) + '</p>'
    + '<p class="cpj-note" style="margin:.1rem 0">' + esc(prochainSeuil ? t('prochain_appel', { m: fr(Math.max(manque, prochainSeuil.m)), cur: c, j: prochainSeuil.j }) : t('appels_ok')) + '</p>'
    + '<p class="cpj-note" style="margin:.4rem 0 .1rem">' + esc(t('stock')) + ' : ' + ['bois', 'minerai', 'metal'].map(m => esc(t('m_' + m)) + ' ' + fr(st[m]) + ' / ' + fr(besoin[m])).join(' · ') + '</p>'
    + '<p class="cpj-note" style="margin:.1rem 0">' + esc(t('heures', { f: faites, r: rest })) + (avanceHeures(ch) > 0 ? ' · ' + esc(t('avance_ouverte', { h: avanceHeures(ch), c: capacite(ch) })) : '') + '</p>'
    + '<p class="cpj-note" style="margin:.1rem 0">' + esc(t('salaire', { v: fr(typeof tauxHoraireChantier === 'function' ? tauxHoraireChantier(ch) : 0), cur: c })) + '</p>'
    + '<p class="cpj-note" style="margin:.1rem 0">' + esc(t('prix_rachat', { b: fr(p.bois), mi: fr(p.minerai), me: fr(p.metal), cur: c })) + '</p>'
    + '<p class="cpj-note" style="margin:.4rem 0 0;font-style:italic">' + esc(t('explication')) + '</p></div>';
}
const radio = (a, label, contenu) => '<label class="chantier-choix" style="display:block;border:1px solid #394656;border-radius:4px;padding:.5rem .6rem;margin:.35rem 0;cursor:pointer">'
  + '<input type="radio" name="chantier-action" value="' + a + '"' + (choix.action === a ? ' checked' : '') + ' onchange="chantierChoisir(\'' + a + '\')"> <b>' + esc(label) + '</b>'
  + '<div class="chantier-detail" style="margin-top:.35rem;' + (choix.action === a ? '' : 'display:none') + '">' + contenu + '</div></label>';
const selMatiere = id => '<select id="' + id + '" class="cpj-champ" oninput="chantierTotaux()">' + ['bois', 'minerai', 'metal'].map(m => '<option value="' + m + '">' + esc(t('m_' + m)) + '</option>').join('') + '</select>';
function sectionParticiper(ch) {
  const c = cur();
  return radio('travailler', t('a_travailler'), '<label class="cpj-note">' + esc(t('heures_label', { v: fr(tauxHoraireChantier(ch)), cur: c })) + ' <input id="chantier-heures" class="cpj-champ" type="number" min="1" step="1" value="1" oninput="chantierTotaux()"></label>')
    + radio('vendre', t('a_vendre'), selMatiere('chantier-v-matiere') + ' <input id="chantier-v-qte" class="cpj-champ" type="number" min="1" step="1" value="1" oninput="chantierTotaux()"><div class="cpj-note" id="chantier-v-prix"></div>')
    + radio('donner', t('a_donner'), '<div class="cpj-note">' + esc(t('don_note')) + '</div>' + selMatiere('chantier-d-matiere') + ' <input id="chantier-d-qte" class="cpj-champ" type="number" min="1" step="1" value="1" oninput="chantierTotaux()">');
}
function sectionGestion(ch, t0) {
  const c = cur(), p = ch.prixAchatPJ || {}, min = typeof CHANTIER_SALAIRE_MINIMUM !== 'undefined' ? CHANTIER_SALAIRE_MINIMUM : 50;
  if (ch.attenteReception || (typeof chantierTermine === 'function' && chantierTermine(ch)))
    return radio('reception', t('a_reception'), '');
  let h = radio('prix', t('a_prix'), '<div class="cpj-note">' + esc(t('prix_note')) + '</div>' + ['bois', 'minerai', 'metal'].map(m =>
      '<label class="cpj-note" style="margin-right:.6rem">' + esc(t('m_' + m)) + ' <input id="chantier-prix-' + m + '" class="cpj-champ" style="width:5.5rem" inputmode="numeric" value="' + esc(p[m] ?? '') + '" oninput="chantierTotaux()"></label>').join(''))
    + radio('taux', t('a_taux'), '<div class="cpj-note">' + esc(t('taux_note', { m: min, cur: c })) + '</div><input id="chantier-taux" class="cpj-champ" inputmode="numeric" value="' + esc(ch.tauxHoraire ?? '') + '" oninput="chantierTotaux()">')
    + radio('fonds', t('a_fonds'), '<div class="cpj-note">' + esc(t('fonds_note')) + '</div><label class="cpj-note">' + esc(t('montant', { cur: c })) + ' <input id="chantier-fonds" class="cpj-champ" inputmode="numeric" value="' + esc(Math.max(0, (Number(ch.coutTotal) || 0) - (Number(ch.totalVerse) || 0))) + '" oninput="chantierTotaux()"></label>');
  if (typeof verdictModificationPlan === 'function' && verdictModificationPlan(ch).ok) h += radio('lots', t('a_lots'), '');
  return h;
}
function ouvrirFenetreChantier(silencieux) {
  const t0 = ts(), ch = t0.chantier, doc = global.document;
  if (!ch || !doc) return;
  if (!silencieux) choix.action = null;
  const gere = maitreOuvrage(t0);
  const html = '<div id="chantier-fenetre" class="cpj-dialogue" style="padding:.2rem .2rem 0">'
    + '<h4 style="font-family:Bebas Neue,sans-serif;letter-spacing:.1em;color:#C9A84C;margin:.2rem 0">' + esc(t('etat')) + '</h4>' + sectionEtat(ch)
    + (ch.attenteReception ? '' : '<h4 style="font-family:Bebas Neue,sans-serif;letter-spacing:.1em;color:#C9A84C;margin:.8rem 0 .2rem">' + esc(t('participer')) + '</h4>' + sectionParticiper(ch))
    + (gere ? '<h4 style="font-family:Bebas Neue,sans-serif;letter-spacing:.1em;color:#C9A84C;margin:.8rem 0 .2rem">' + esc(t('gestion')) + '</h4>' + sectionGestion(ch, t0) : '')
    + '<div style="position:sticky;bottom:0;background:#12100c;border-top:1px solid #394656;margin-top:.8rem;padding:.6rem 0;display:flex;gap:.6rem;align-items:center;flex-wrap:wrap">'
    + '<span id="chantier-totaux" class="cpj-note" style="flex:1 1 12rem"></span>'
    + '<button type="button" class="cpj-touche" onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')">' + esc(t('annuler')) + '</button>'
    + '<span id="chantier-valider-enveloppe" style="display:inline-block"><button type="button" id="chantier-valider" class="cpj-touche cpj-primaire" onclick="chantierValider()">' + esc(t('valider')) + '</button></span>'
    + '</div></div>';
  const titre = doc.getElementById('postes-modal-title'), corps = doc.getElementById('postes-body');
  if (!corps) return;
  if (titre) titre.textContent = t('titre');
  // Conserver les saisies en cours lors d'un rafraîchissement.
  const saisies = {};
  if (silencieux) corps.querySelectorAll('#chantier-fenetre input, #chantier-fenetre select').forEach(e => { if (e.id) saisies[e.id] = e.value; });
  corps.innerHTML = html;
  for (const [id, v] of Object.entries(saisies)) { const e = doc.getElementById(id); if (e && e.type !== 'radio') e.value = v; }
  doc.getElementById('modal-postes')?.classList.add('open');
  chantierTotaux();
}
const val = id => (global.document.getElementById(id)?.value || '').trim();
const entier = s => /^[0-9]{1,9}$/.test(s) ? Number(s) : null;
// Ce que coûte et rapporte l'opération choisie, et pourquoi on ne peut pas la valider.
function verdictChoix() {
  const t0 = ts(), ch = t0.chantier, c = cur(), s = etat();
  if (!ch) return { refus: t('r_choisir') };
  const pa = Number(s.pa ?? s.char?.pa ?? 0) || 0;
  switch (choix.action) {
    case 'travailler': {
      const h = entier(val('chantier-heures'));
      if (!h) return { refus: t('r_quantite') };
      const taux = tauxHoraireChantier(ch), rest = heuresPossibles(ch);
      const tot = { pa: h, recoit: h * taux };
      if (rest <= 0) return { ...tot, refus: t('r_heures') };
      if (h > rest) return { ...tot, refus: t('r_heures') + ' (' + rest + ')' };
      if (h > pa) return { ...tot, refus: t('r_pa') };
      if (h * taux > (Number(ch.tresorerie) || 0)) return { ...tot, refus: t('r_treso') };
      return tot;
    }
    case 'vendre': case 'donner': {
      const p = choix.action === 'vendre' ? 'v' : 'd', m = val('chantier-' + p + '-matiere'), q = entier(val('chantier-' + p + '-qte'));
      const prix = choix.action === 'vendre' ? (Number((ch.prixAchatPJ || {})[m]) || 0) : 0;
      const info = global.document.getElementById('chantier-v-prix');
      if (info && p === 'v') info.textContent = t('prix_unitaire', { p: fr(prix), t: fr(prix * (q || 0)), cur: c });
      if (!q) return { refus: t('r_quantite') };
      const tot = { pa: 0, recoit: prix * q };
      if (typeof chantierAccepteMateriaux === 'function' && !chantierAccepteMateriaux(ch)) return { ...tot, refus: t('r_mat_refus') };
      if (stockPJ(m) < q) return { ...tot, refus: t('r_stock') };
      if (prix * q > (Number(ch.tresorerie) || 0)) return { ...tot, refus: t('r_tresorerie_achat') };
      return tot;
    }
    case 'prix': {
      for (const m of ['bois', 'minerai', 'metal']) { const v = val('chantier-prix-' + m); if (v && entier(v) === null) return { refus: t('r_prix') }; }
      return { pa: 0 };
    }
    case 'taux': {
      const min = typeof CHANTIER_SALAIRE_MINIMUM !== 'undefined' ? CHANTIER_SALAIRE_MINIMUM : 50, v = entier(val('chantier-taux'));
      if (v === null || v < min) return { refus: t('r_taux', { m: min, cur: c }) };
      return { pa: 0 };
    }
    case 'fonds': {
      const v = entier(val('chantier-fonds'));
      if (!v) return { refus: t('r_montant') };
      if (v > argentPJ() && argentPJ() > 0) return { pa: 0, paie: v, refus: t('r_argent') };
      return { pa: 0, paie: v };
    }
    case 'lots': case 'reception': return { pa: 0 };
    default: return { refus: t('r_choisir') };
  }
}
function chantierTotaux() {
  const doc = global.document, v = verdictChoix(), c = cur();
  const parts = [];
  if (v.pa != null) parts.push(t('total_pa', { pa: v.pa }));
  if (v.paie) parts.push(t('total_argent', { v: '−' + fr(v.paie), cur: c }));
  if (v.recoit) parts.push(t('recoit', { v: fr(v.recoit), cur: c }));
  const tot = doc.getElementById('chantier-totaux'); if (tot) tot.textContent = parts.join(' · ');
  const b = doc.getElementById('chantier-valider'), env = doc.getElementById('chantier-valider-enveloppe');
  if (b) { b.disabled = !!v.refus; b.setAttribute('aria-disabled', v.refus ? 'true' : 'false'); }
  if (env) env.title = v.refus || '';   // infobulle même sur un bouton grisé
  return v;
}
function chantierChoisir(a) {
  choix.action = a;
  global.document.querySelectorAll('#chantier-fenetre .chantier-choix').forEach(l => {
    const r = l.querySelector('input[type=radio]'), d = l.querySelector('.chantier-detail');
    if (d) d.style.display = r && r.value === a ? '' : 'none';
  });
  chantierTotaux();
}
let validation = false;
async function chantierValider() {
  const v = chantierTotaux();
  if (v.refus || validation) return;
  validation = true;
  try {
    const a = choix.action;
    if (a === 'travailler') {
      const champ = global.document.getElementById('chantier-heures');
      if (champ) champ.id = 'chantier-heures';   // confirmerTravailChantier lit ce champ
      await global.confirmerTravailChantier();
    } else if (a === 'vendre' || a === 'donner') {
      const p = a === 'vendre' ? 'v' : 'd', doc = global.document;
      // Le chemin existant (reçus, rejeu sûr) lit #vente-matiere et #vente-quantite.
      const tmp = doc.createElement('div'); tmp.style.display = 'none';
      tmp.innerHTML = '<input id="vente-matiere" value="' + esc(val('chantier-' + p + '-matiere')) + '"><input id="vente-quantite" value="' + esc(val('chantier-' + p + '-qte')) + '">';
      doc.body.appendChild(tmp);
      try { await global.confirmerVenteMateriauxChantier(a === 'vendre' ? 'vente' : 'don'); } finally { tmp.remove(); }
    } else if (a === 'prix') {
      const prix = {};
      for (const m of ['bois', 'minerai', 'metal']) { const x = val('chantier-prix-' + m); if (x) prix[m] = x; }
      if (Object.keys(prix).length) await global.constructionExecuterCommande('prix', { prix });
    } else if (a === 'taux') {
      await global.constructionExecuterCommande('taux', { taux: val('chantier-taux') });
    } else if (a === 'fonds') {
      await global.constructionExecuterCommande('verser', { montant: String(entier(val('chantier-fonds'))) });
    } else if (a === 'lots') {
      return global.doModifierPlanChantier(0, 0);
    } else if (a === 'reception') {
      global.document.getElementById('modal-postes')?.classList.remove('open');
      return global.receptionnerChantier();
    }
    // Relecture du serveur : la fenêtre, l'image et la surcouche se mettent à jour d'elles-mêmes.
    if (typeof global.chargerTerrainState === 'function') await global.chargerTerrainState(etat().currentBuilding);
    choix.action = null;
    if (global.document.getElementById('chantier-fenetre')) ouvrirFenetreChantier(true);
  } finally { validation = false; }
}

function demarrer() {
  brancher();
  setInterval(suivre, 20000);
}
if (global.document && global.document.readyState !== 'loading') demarrer();
else if (global.document) global.document.addEventListener('DOMContentLoaded', demarrer);

global.RPChantierVue = { TXT, candidatsImage, imageImmediate, imageResolue, etapeDe, lignesSurcouche, rafraichirVueChantier, verdictChoix, _choix: choix, _existe: existe };
Object.assign(global, { ouvrirFenetreChantier, chantierChoisir, chantierTotaux, chantierValider, chantierImageImmediate: imageImmediate, rafraichirVueChantier });
})(typeof window !== 'undefined' ? window : globalThis);
