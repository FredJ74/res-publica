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
const GABARIT_HAUT = new Set(['building', 'logement']);
const DEMARRAGE = 'images/chantier-en-cours.webp';
function villeSlug() { const s = etat(); return (VILLES[s.country] || {})[s.currentCity] || String(s.currentCity || ''); }
function fraction(ch) { const d = Number(ch && ch.dureeJours) || 0; return d > 0 ? Math.max(0, Math.min(1, (Number(ch.progressionJours) || 0) / d)) : 0; }
function etapeDe(ch) { const f = fraction(ch); return f >= 1 ? 'acheve' : f < 1 / 3 ? 'demarrage' : f < 2 / 3 ? 'gros_oeuvre' : 'facade'; }
// Candidats, du plus juste au plus général ; le dernier existe toujours.
// Port-Sainte-Marie : série complète (Fred, 21/11/2026, soir, point 5 ; images reçues le 22/11/2026), dans images/chantiers/psm/.
// Démarrage petit (hangar, commerce standard) ou grand (commerce premium, logement, building) ; puis une image par étape,
// quelle que soit la taille ; puis le bâtiment achevé par type. Tous les fichiers existent : plus de repli.
const PSM_TYPE = { hangar: 'hangar', commerce_standard: 'commerce_standard', commerce_premium: 'commerce_premium', logement: 'logement', building: 'building' };
const PSM_PETIT = new Set(['hangar', 'commerce_standard']);
function candidatsPsm(t0) {
  const b = 'images/chantiers/psm/';
  if (t0 && t0.chantier) {
    const ch = t0.chantier, e = etapeDe(ch), prog = Number(ch.progressionJours) || 0;
    if (e === 'demarrage') return [prog < 1 ? b + 'PSM_chantier_demarrage_' + (PSM_PETIT.has(ch.niveau) ? 'petit' : 'grand') + '.webp' : b + 'PSM_chantier_fondations.webp'];
    return [b + (e === 'gros_oeuvre' ? 'PSM_chantier_gros_oeuvre.webp' : 'PSM_chantier_facade.webp')];
  }
  if (t0 && t0.niveau_construction) return [b + 'PSM_batiment_' + (PSM_TYPE[t0.niveau_construction] || 'building') + '.webp'];
  return [];
}
function candidatsImage(t0) {
  const v = villeSlug(), base = 'images/chantiers/' + v + '/';
  if (v === 'psm') return candidatsPsm(t0);
  if (t0 && t0.chantier) {
    const ch = t0.chantier, g = GABARIT_HAUT.has(ch.niveau) ? 'haut' : 'bas', e = etapeDe(ch);
    // Règle des images (Fred, 22/11/2026, point 3) : démarrage commun le premier jour, puis fondations par ville
    // (même image pour tous les types), puis gros œuvre et façade en deux gabarits. Repli si l'image de la ville manque.
    if (e === 'demarrage') return (Number(ch.progressionJours) || 0) < 1 ? [DEMARRAGE] : [base + 'fondations.webp', DEMARRAGE];
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

const POSER_SURCOUCHE = false;
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
  // Retiré (Fred, 21/11/2026, soir) : l'encadré restait visible derrière la fenêtre et chevauchait le texte du terrain.
  // Tout l'état est dans l'onglet « État » de la fenêtre « Le chantier ».
  if (s) s.remove();
  if (POSER_SURCOUCHE !== true) return;
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
  // Rafraîchir la fenêtre seulement si elle est ouverte (jamais d'ouverture automatique en entrant sur le terrain).
  const f = global.document.getElementById('chantier-fenetre');
  if (f && fenetreOuverte() && !f.contains(global.document.activeElement)) ouvrirFenetreChantier(true);
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

// ── Fenêtre « Le chantier » : quatre onglets (Fred, 21/11/2026, soir) ─────────────────────────────────────
// Elle ne s'ouvre JAMAIS seule : uniquement par l'ordre « Le chantier ». État (par défaut), Stock de matériaux,
// Main-d'œuvre, Gestion (maître d'ouvrage). Chaque onglet s'affiche dans la fenêtre elle-même. Police plus grande.
// Jauges dessinées en CSS : cadre bronze en relief, petits carrés du rouge au vert, reflet, onglet incliné rayé.
const TXT4 = {
  o_etat: 'État', o_stock: 'Stock de matériaux', o_main: 'Main-d’œuvre', o_gestion: 'Gestion',
  j_chantier: 'Jour {x} / {n} · {p} %', j_jour: '{f} / {c} h', j_heures: 'Heures du jour', j_suivante: 'Étape suivante : {e}', j_fin: 'Fin prévue : {date}',
  j_journal: 'Journal du chantier', j_manque: 'L’entrepôt de {ville} n’a pas pu tout fournir : il manque {liste} pour aujourd’hui. Passants, vendez ou donnez ces matériaux au chantier (onglet « Stock de matériaux ») : il vous les rachète.',
  j_commande: 'Commande de la nuit à l’entrepôt de {ville} : {livre}.', j_commande_avance: 'Jour d’avance ouvert : commande immédiate à l’entrepôt de {ville} : {livre}.', j_rien_livre: 'rien n’a pu être livré',
  j_journee: 'Nuit du {date} : le chantier a avancé de {a} jour(s).',
  j_crue: 'Nuit du {date} : crue dans la ville, le chantier n’a pas avancé (un jour de retard).',
  s_materiau: 'Matériau', s_prix: 'Prix de rachat', s_stock: 'Stock / besoin du jour', s_quantite: 'Quantité', s_donner: 'Donner au lieu de vendre', s_rien: 'Indiquez une quantité sur au moins une ligne.',
s_complet: 'Le besoin du jour est couvert : le chantier n’achète plus de {m} aujourd’hui.',
  s_valider: 'Valider', s_plafond: 'au plus {n} (ce qui manque et ce que vous avez)',
  m_main: 'Heures restant à faire / heures du jour : {r} / {c}', m_salaire: 'Salaire horaire : {v} {cur}', m_pa: '(1 PA/h)', m_travailler: 'Travailler', m_nb: 'Nombre d’heures',
  m_aucune: 'Aucune heure n’est ouverte pour l’instant.', m_sans_pa: 'Il vous faut au moins 1 PA par heure.', m_sans_treso: 'La trésorerie du chantier ne peut plus payer d’heures.',
  m_gain: 'Vous recevrez {v} {cur} pour {h} heure(s) (−{h} PA).',
  m_avance: 'Ensuite, {h} heure(s) du jour d’avance : si elles sont toutes faites, le chantier gagne une journée cette nuit.',
  g_treso: 'Trésorerie', g_verse: 'Fonds versés / coût total', g_appel: 'Prochain appel de fonds', g_appel_ok: 'Tout est versé',
  g_appel_txt: '{m} {cur} avant le jour {j} ({date})', g_prix: 'Prix de rachat des matériaux', g_salaire: 'Salaire horaire des ouvriers', g_fonds: 'Verser des fonds',
  g_commande: 'Commande de matériaux', g_commande_txt: 'Commande automatique chaque nuit à l’entrepôt de {ville}',
  g_commande_note: 'Payée par la trésorerie du chantier, dans la limite du stock de l’entrepôt. Ce qui manque reste à acheter aux joueurs.',
  g_derniere: 'Dernière commande ({date}, pour le jour {j}) : livré {livre} ; manquant {manque} ; coût {cout} {cur}.', g_aucune: 'Aucune commande pour l’instant : la première partira cette nuit.', g_rien: 'rien',
  g_enregistrer: 'Enregistrer', g_verser: 'Verser', g_lots: 'Définir les lots', g_reception: 'Réceptionner le bâtiment', g_reserve: 'Réservé au maître d’ouvrage.'
};
// Purge, bloc C (Fred, 24/11/2026) : fenêtre simplifiée « comme pour un enfant ». Textes nouveaux (français, pour Codex).
const TXTC = {
  r_heures: 'Encore {h} heure(s) à faire aujourd’hui', r_heures_avance: 'Les heures du jour sont faites. Encore {h} heure(s) du jour d’avance.',
  r_heures_aucune: 'Plus aucune heure à faire aujourd’hui.', r_heures_attente: 'Lecture du chantier…',
  r_heures_aide: 'Chaque heure de travail coûte 1 PA et rapporte le salaire fixé par le propriétaire du chantier. Si toutes les heures du jour sont faites, le jour suivant s’ouvre en avance et le chantier gagne une journée cette nuit.',
  r_materiaux: 'Matériaux du jour', r_mat: '{m} : {s} sur {b}', r_mat_aide: 'Chaque jour de travail consomme du bois, du minerai et du métal. Ce qui manque, le chantier le rachète aux joueurs au prix fixé par le propriétaire.',
  r_lecture_ko: 'Le chantier ne répond pas pour l’instant. Réessayez dans un moment.', aide: 'Aide',
  o_participer: 'Participer', o_avancement: 'Avancement',
  w_titre: 'Travailler sur ce chantier', w_salaire: 'Salaire : {v} {cur} de l’heure · 1 PA par heure', w_moins: 'Une heure de moins', w_plus: 'Une heure de plus',
  w_heures: '{h} h', w_gain: 'Vous recevrez {v} {cur} et utiliserez {h} PA.', w_bouton: 'Travailler {h} h', w_plafond: 'Au plus {h} heure(s) pour vous maintenant.',
  w_salaire_aide: 'Le salaire est fixé par le propriétaire du chantier et payé par sa trésorerie. Le nombre d’heures est limité par les heures encore ouvertes, vos PA et l’argent du chantier.',
  x_aucune_heure_ouverte: 'Plus aucune heure de travail ouverte aujourd’hui.', x_pa_insuffisants: 'Il vous faut au moins 1 PA par heure.',
  x_tresorerie_insuffisante: 'La trésorerie du chantier ne peut plus payer d’heures.', x_chantier_intemperies: 'Le chantier est arrêté par les intempéries.',
  x_pas_sur_place: 'Vous devez être sur le terrain pour travailler.', x_acteur_incapacite: 'Vous êtes hospitalisé : impossible de travailler.',
  x_acteur_detenu: 'Vous êtes détenu : impossible de travailler.', x_terrain_gele: 'Ce terrain est gelé (succession en cours).',
  x_defaut: 'Le travail n’est pas possible pour l’instant.'
};
const tc = (k, v) => String(TXTC[k] || TXT4[k] || TXT[k] || k).replace(/\{(\w+)\}/g, (m, c) => (v && v[c] != null) ? String(v[c]) : m);
const t4 = (k, v) => String(TXT4[k] || k).replace(/\{(\w+)\}/g, (m, c) => (v && v[c] != null) ? String(v[c]) : m);
const MATS = ['bois', 'minerai', 'metal'];
const vue = { onglet: 'participer' };
const choix = { action: null };   // compatibilité (anciens bancs, chemins existants)
function maitreOuvrage(t0) { return typeof constructionPeutGerer === 'function' ? constructionPeutGerer(t0) : false; }
function stockPJ(m) { return (etat().inventory || []).filter(i => i && i.stackable && i.stackKey === m).reduce((a, i) => a + (Number(i.qty) || 0), 0); }
function argentPJ() { const s = etat(); return Number(s.liquide ?? s.char?.liquide ?? s.money ?? 0) || 0; }
function paPJ() { const s = etat(); return Number(s.pa ?? s.char?.pa ?? 0) || 0; }
function besoinJour(ch) { try { return besoinMateriauxJourChantier(ch, numeroJourChantier(ch)) || {}; } catch (_) { return {}; } }
function injecterStyleJauges() {
  const doc = global.document;
  if (!doc || doc.getElementById('chantier-jauges-style')) return;
  const st = doc.createElement('style'); st.id = 'chantier-jauges-style';
  st.textContent = '#chantier-fenetre{font-size:1.08rem;line-height:1.45;color:#ece4cc}'
    + '#chantier-fenetre .cj-onglets{display:flex;gap:.3rem;flex-wrap:wrap;border-bottom:2px solid #5a4220;margin-bottom:.8rem}'
    + '#chantier-fenetre .cj-onglets button{font-family:Bebas Neue,sans-serif;letter-spacing:.08em;font-size:1.1rem;padding:.35rem .8rem;border:1px solid #5a4220;border-bottom:none;border-radius:6px 6px 0 0;background:#1a140c;color:#b8a070;cursor:pointer}'
    + '#chantier-fenetre .cj-onglets button[aria-selected=true]{background:linear-gradient(#6a4c22,#3a2a12);color:#ffe7a0}'
    + '.cj-jauge{display:flex;align-items:center;gap:.7rem;margin:1.25rem 0 .5rem}'
    + '.cj-cadre{position:relative;flex:1;padding:5px;border-radius:14px;background:linear-gradient(#6a4c22,#2a1c0c);border:1px solid #8a6a30;'
    + 'box-shadow:inset 0 2px 2px rgba(255,220,150,.3),inset 0 -2px 3px rgba(0,0,0,.6),0 2px 5px rgba(0,0,0,.6)}'
    + '.cj-onglet{position:absolute;top:-19px;left:16px;padding:0 12px;font-family:Bebas Neue,sans-serif;letter-spacing:.08em;font-size:.95rem;color:#ffe7a0;'
    + 'transform:skewX(-14deg);background:repeating-linear-gradient(135deg,#7a5626 0 7px,#5e4019 7px 10px);border:1px solid #9a7a3a;border-bottom:none;border-radius:4px 4px 0 0}'
    + '.cj-onglet span{display:inline-block;transform:skewX(14deg)}'
    + '.cj-cases{position:relative;display:grid;gap:2px;height:24px;padding:3px;background:#100a05;border-radius:10px;overflow:hidden}'
    + '.cj-cases.petite{height:16px}'
    + '.cj-cases::after{content:"";position:absolute;left:3px;right:3px;top:3px;height:42%;border-radius:8px;background:linear-gradient(rgba(255,255,255,.38),rgba(255,255,255,0));pointer-events:none}'
    + '.cj-case{border-radius:3px;background:#2c2218;box-shadow:inset 0 0 0 1px rgba(0,0,0,.4)}'
    + '.cj-case.sep{box-shadow:inset 2px 0 0 #e6c870}'
    + '.cj-case.on{box-shadow:inset 0 1px 0 rgba(255,255,255,.5),0 0 4px rgba(255,200,80,.25);animation:cjAllume .45s ease both}'
    + '.cj-case.on.sep{box-shadow:inset 2px 0 0 #e6c870,inset 0 1px 0 rgba(255,255,255,.5)}'
    + '@keyframes cjAllume{from{opacity:0;transform:scaleY(.35)}to{opacity:1;transform:none}}'
    + '@media (prefers-reduced-motion: reduce){.cj-case.on{animation:none}}'
    + '.cj-texte{min-width:6.5rem;font-size:1.05rem;color:#f4ead0;white-space:nowrap}'
    + '.cj-trois{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:.4rem .8rem}'
    + '#chantier-fenetre table{width:100%;border-collapse:collapse;font-size:1rem}#chantier-fenetre th{text-align:left;color:#C9A84C;font-weight:600;padding:.3rem .25rem;border-bottom:1px solid #5a4220}'
    + '#chantier-fenetre td{padding:.4rem .25rem;border-bottom:1px solid #2a2016;vertical-align:middle}#chantier-fenetre input[type=number]{width:5.5rem;font-size:1rem}'
    + '#chantier-fenetre .cj-carte{border:1px solid #5a4220;border-radius:6px;padding:.6rem .7rem;margin:.6rem 0;background:#16110a}'
    + '#chantier-fenetre .cj-tableau-bord{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:.5rem}'
    + '#chantier-fenetre .cj-tableau-bord div{border:1px solid #5a4220;border-radius:6px;padding:.5rem;background:#1a140c}#chantier-fenetre .cj-tableau-bord b{display:block;font-size:1.2rem;color:#ffe7a0}'
    + '#chantier-fenetre .cj-raison{color:#e0a040;margin:.4rem 0}#chantier-fenetre .cj-resume{color:#9fd08a;margin:.4rem 0}'
    + '@media (max-width:520px){#chantier-fenetre .cj-stock-table thead{display:none}#chantier-fenetre .cj-stock-table tr{display:grid;grid-template-columns:1fr 1fr;gap:.2rem .6rem;padding:.4rem 0;border-bottom:1px solid #2a2016}#chantier-fenetre .cj-stock-table td{border:none;padding:.1rem}}';
  doc.head.appendChild(st);
}
// Jauge : n carrés, « on » allumés, dégradé rouge → orange → vert, séparateurs fins aux indices « seps ».
function jauge(titre, n, on, texte, opts) {
  n = Math.max(1, Math.floor(n)); on = Math.max(0, Math.min(n, Math.floor(on)));
  const seps = new Set((opts && opts.seps) || []);
  let cases = '';
  for (let i = 0; i < n; i++) {
    const h = opts && opts.rouge ? 0 : (n === 1 ? 120 : Math.round(120 * i / (n - 1)));   // rouge : matériau manquant
    const allume = i < on;
    cases += '<i class="cj-case' + (allume ? ' on' : '') + (seps.has(i) ? ' sep' : '') + '" style="' + (allume ? 'background:linear-gradient(hsl(' + h + ',85%,60%),hsl(' + h + ',80%,40%));animation-delay:' + (i * 28) + 'ms' : '') + '"></i>';
  }
  return '<div class="cj-jauge" role="meter" aria-label="' + esc(titre) + '" aria-valuemin="0" aria-valuemax="' + n + '" aria-valuenow="' + on + '">'
    + '<div class="cj-cadre">' + (titre ? '<div class="cj-onglet"><span>' + esc(titre) + '</span></div>' : '')
    + '<div class="cj-cases' + (opts && opts.petite ? ' petite' : '') + '" style="grid-template-columns:repeat(' + n + ',1fr)">' + cases + '</div></div>'
    + '<div class="cj-texte">' + esc(texte) + '</div></div>';
}
function dateDuJour(j, ch) {
  const reste = Math.max(0, j - 1 - (Number(ch.progressionJours) || 0));
  const d = new Date(Date.now() + reste * 86400e3);
  try { return d.toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', timeZone: 'Europe/Paris' }); } catch (_) { return ''; }
}
function prochainAppel(ch) {
  const d = Number(ch.dureeJours) || 0, tot = Number(ch.coutTotal) || 0, v = Number(ch.totalVerse) || 0;
  if (v >= tot) return null;
  const s = v >= Math.ceil(tot * .7) ? { m: tot - v, j: Math.floor(d * 2 / 3) + 1 } : { m: Math.ceil(tot * .7) - v, j: Math.floor(d / 3) + 1 };
  s.m = Math.max(s.m, manqueFinancement(ch));
  return s;
}
// Commande automatique et journal du chantier (Fred, 22/11/2026, point 2 ; serveur : migration 20261122120000).
function nomVilleChantier() {
  const s = etat();
  try { if (typeof villeNom === 'function') return villeNom(s.country, s.currentCity) || ''; } catch (_) {}
  return ({ capitale: 'Luthécia', ville_a: 'Port-Sainte-Marie', ville_b: 'Montrouge' })[s.currentCity] || '';
}
function listeQuantites(o) {
  const p = MATS.filter(m => (Number((o || {})[m]) || 0) > 0).map(m => fr(Number(o[m])) + ' ' + t('m_' + m).toLowerCase());
  return p.length > 1 ? p.slice(0, -1).join(', ') + ' et ' + p[p.length - 1] : (p[0] || '');
}
function derniereCommandeTexte(ch) {
  const c = ch && ch.derniereCommande;
  if (!c) return t4('g_aucune');
  return t4('g_derniere', { date: c.date || '', j: c.pourJour || '', livre: listeQuantites(c.livre) || t4('g_rien'),
    manque: listeQuantites(c.manque) || t4('g_rien'), cout: fr(Number(c.cout) || 0), cur: cur() });
}
function journalChantier(ch) {
  const ville = nomVilleChantier();
  const lignes = (ch.evenements || []).slice(-6).reverse().map(e => {
    if (e.cle === 'commande_materiaux') return t4(e.motif === 'avance' ? 'j_commande_avance' : 'j_commande', { ville, livre: listeQuantites(e.livre) || t4('j_rien_livre') });
    if (e.cle === 'manque_materiaux') return t4('j_manque', { ville, liste: listeQuantites(e.manque) });
    if (e.cle === 'journee' || e.cle === 'journee_avance') return t4('j_journee', { date: e.date || '', a: (Math.round((Number(e.avance) || 0) * 100) / 100).toString().replace('.', ',') });
    if (e.cle === 'crue') return t4('j_crue', { date: e.date || '' });   // crue (Fred, 22/11/2026) : un jour de retard
    return null;
  }).filter(Boolean);
  if (!lignes.length) return '';
  return '<div class="cj-carte"><b>' + esc(t4('j_journal')) + '</b><ul style="margin:.3rem 0 0 1rem;padding:0">' + lignes.map(l => '<li>' + esc(l) + '</li>').join('') + '</ul></div>';
}
function ongletEtat(ch, t0) {
  const d = Math.max(1, Number(ch.dureeJours) || 1), prog = Math.floor(Number(ch.progressionJours) || 0), e = etapeDe(ch);
  const pct = Math.floor(fraction(ch) * 100), cap = capacite(ch), faites = Math.floor(Number(ch.heuresFaites) || 0);
  const besoin = besoinJour(ch), st = ch.stockMateriaux || {};
  const img = imageImmediate(t0);
  const manques = MATS.filter(m => (Number(besoin[m]) || 0) > (Number(st[m]) || 0)).map(m => fr((Number(besoin[m]) || 0) - (Number(st[m]) || 0)) + ' ' + t('m_' + m).toLowerCase());
  let h = (img ? '<img src="' + esc(img) + '" alt="" style="width:100%;max-height:220px;object-fit:cover;border-radius:6px;border:1px solid #5a4220">' : '')
    + jauge(t('etape_' + e), d, prog, t4('j_chantier', { x: Math.min(d, prog + 1), n: d, p: pct }), { seps: [Math.floor(d / 3), Math.floor(2 * d / 3)] })
    + '<p style="margin:.2rem 0">' + (ch.attenteReception ? esc(t('attente_reception'))
        : (SUIVANTE[e] ? esc(t4('j_suivante', { e: t('etape_' + SUIVANTE[e]) })) + ' · ' : '') + esc(t4('j_fin', { date: dateFinPrevue(ch) }))) + '</p>'
    + (ch.arrete === 'financement' ? '<p class="cj-raison">' + esc(t('arret_fin', { m: fr(manqueFinancement(ch)), cur: cur() })) + '</p>' : '')
    + (ch.arrete === 'penurie_materiaux' ? '<p class="cj-raison">' + esc(t('arret_mat')) + '</p>' : '')
    + jauge(t4('j_heures'), 10, cap > 0 ? Math.round(10 * faites / cap) : 0, t4('j_jour', { f: faites, c: cap }))
    + (avanceHeures(ch) > 0 ? '<p style="margin:.2rem 0">' + esc(t('avance_ouverte', { h: avanceHeures(ch), c: cap })) + '</p>' : '')
    + (manques.length ? '<p class="cj-raison">' + esc(t4('j_manque', { ville: nomVilleChantier(), liste: listeQuantites(Object.fromEntries(MATS.map(m => [m, Math.max(0, (Number(besoin[m]) || 0) - (Number(st[m]) || 0))]))) })) + '</p>' : '')
    + '<div class="cj-trois">' + MATS.map(m => {
        const b = Number(besoin[m]) || 0, s0 = Number(st[m]) || 0;
        return jauge(t('m_' + m), 10, b > 0 ? Math.round(10 * Math.min(s0, b) / b) : 10, fr(s0) + ' / ' + fr(b), { petite: true, rouge: s0 < b });
      }).join('') + '</div>'
    + journalChantier(ch)
    + '<p style="margin:.6rem 0 0;font-style:italic;color:#b8a888">' + esc(t('explication')) + '</p>';
  return h;
}
function ligneStock(m, ch) {
  const besoin = Number(besoinJour(ch)[m]) || 0, s0 = Number((ch.stockMateriaux || {})[m]) || 0, manque = Math.max(0, besoin - s0);
  const prix = Number((ch.prixAchatPJ || {})[m]) || 0, a = stockPJ(m), max = Math.min(manque, a);
  return '<tr data-m="' + m + '"><td><b>' + esc(t('m_' + m)) + '</b></td><td>' + fr(prix) + ' ' + cur() + '</td><td>' + fr(s0) + ' / ' + fr(besoin) + '</td>'
    + '<td><input type="number" id="cj-q-' + m + '" min="0" max="' + max + '" step="1" value="0"' + (max <= 0 ? ' disabled' : '') + ' oninput="chantierStockTotaux()" aria-label="' + esc(t4('s_quantite')) + '">'
    + '<div style="font-size:.8rem;color:#9a8a68">' + esc(manque <= 0 ? t4('s_complet', { m: t('m_' + m).toLowerCase() }) : t4('s_plafond', { n: max })) + '</div></td>'
    + '<td><label style="white-space:nowrap"><input type="checkbox" id="cj-d-' + m + '" onchange="chantierStockTotaux()"> ' + esc(t4('s_donner')) + '</label></td>'
    + '<td style="min-width:110px">' + jauge('', 10, besoin > 0 ? Math.round(10 * Math.min(s0, besoin) / besoin) : 10, '', { petite: true, rouge: s0 < besoin }) + '</td></tr>';
}
function ongletStock(ch) {
  return '<table class="cj-stock-table"><thead><tr><th>' + esc(t4('s_materiau')) + '</th><th>' + esc(t4('s_prix')) + '</th><th>' + esc(t4('s_stock')) + '</th><th>' + esc(t4('s_quantite')) + '</th><th></th><th></th></tr></thead><tbody>'
    + MATS.map(m => ligneStock(m, ch)).join('') + '</tbody></table>'
    + '<p id="cj-stock-resume" class="cj-resume"></p><p id="cj-stock-raison" class="cj-raison"></p>'
    + '<span id="cj-stock-env" style="display:inline-block"><button type="button" id="cj-stock-valider" class="cpj-touche cpj-primaire" onclick="chantierStockValider()">' + esc(t4('s_valider')) + '</button></span>';
}
function lignesStockSaisies() {
  const t0 = ts(), ch = t0.chantier; if (!ch) return [];
  return MATS.map(m => {
    const el = global.document.getElementById('cj-q-' + m); if (!el) return null;
    const besoin = Number(besoinJour(ch)[m]) || 0, s0 = Number((ch.stockMateriaux || {})[m]) || 0;
    const max = Math.min(Math.max(0, besoin - s0), stockPJ(m));
    let q = Math.floor(Number(el.value) || 0); if (q > max) { q = max; el.value = String(max); } if (q < 0) { q = 0; el.value = '0'; }
    const don = !!global.document.getElementById('cj-d-' + m)?.checked;
    return q > 0 ? { m, q, don, prix: don ? 0 : (Number((ch.prixAchatPJ || {})[m]) || 0) } : null;
  }).filter(Boolean);
}
function verdictStock() {
  const t0 = ts(), ch = t0.chantier, c = cur();
  const l = lignesStockSaisies();
  if (!l.length) return { refus: t4('s_rien'), lignes: l };
  if (typeof chantierAccepteMateriaux === 'function' && !chantierAccepteMateriaux(ch)) return { refus: t('r_mat_refus'), lignes: l };
  const total = l.reduce((a, x) => a + x.q * x.prix, 0);
  if (total > (Number(ch.tresorerie) || 0)) return { refus: t('r_tresorerie_achat'), lignes: l };
  const ventes = l.filter(x => !x.don), dons = l.filter(x => x.don);
  const liste = xs => { const p = xs.map(x => fr(x.q) + ' ' + t('m_' + x.m).toLowerCase()); return p.length > 1 ? p.slice(0, -1).join(', ') + ' et ' + p[p.length - 1] : p[0]; };
  const morceaux = [];
  if (ventes.length) morceaux.push('vous vendez ' + liste(ventes) + ' pour ' + fr(total) + ' ' + c);
  if (dons.length) morceaux.push('vous donnez ' + liste(dons));
  let r = morceaux.join(' et ');
  r = r.charAt(0).toUpperCase() + r.slice(1) + '.';
  return { resume: r, lignes: l };
}
function chantierStockTotaux() {
  const doc = global.document, v = verdictStock();
  const res = doc.getElementById('cj-stock-resume'), rai = doc.getElementById('cj-stock-raison'), b = doc.getElementById('cj-stock-valider'), env = doc.getElementById('cj-stock-env');
  if (res) res.textContent = v.resume || ''; if (rai) rai.textContent = v.refus || '';
  if (b) b.disabled = !!v.refus; if (env) env.title = v.refus || '';
  return v;
}
function ongletMain(ch) {
  const c = cur(), cap = capacite(ch), rest = heuresPossibles(ch), taux = typeof tauxHoraireChantier === 'function' ? tauxHoraireChantier(ch) : 0;
  const duJour = Math.min(rest, typeof heuresUtilesRestantes === 'function' ? heuresUtilesRestantes(ch) : rest), avance = Math.max(0, rest - duJour);
  const payables = taux > 0 ? Math.floor((Number(ch.tresorerie) || 0) / taux) : 0;
  const max = Math.max(0, Math.min(rest, paPJ(), payables));
  const raison = rest <= 0 ? t4('m_aucune') : paPJ() < 1 ? t4('m_sans_pa') : payables < 1 ? t4('m_sans_treso') : '';
  return '<div class="cj-carte"><p style="margin:0 0 .3rem;font-size:1.15rem">' + esc(t4('m_main', { r: duJour, c: cap })) + '</p>'
    + jauge(t4('j_heures'), 10, cap > 0 ? Math.round(10 * (cap - Math.min(cap, duJour)) / cap) : 0, t4('j_jour', { f: Math.max(0, cap - duJour), c: cap }))
    + (avance > 0 ? '<p style="margin:.2rem 0">' + esc(t4('m_avance', { h: avance })) + '</p>' : '')
    + '<p style="margin:.3rem 0">' + esc(t4('m_salaire', { v: fr(taux), cur: c })) + '</p></div>'
    + '<div style="display:flex;gap:.6rem;align-items:center;flex-wrap:wrap;margin:.6rem 0">'
    + '<label>' + esc(t4('m_nb')) + ' <input type="number" id="chantier-heures" min="1" max="' + max + '" step="1" value="' + Math.min(max, Math.max(1, max)) + '"' + (max <= 0 ? ' disabled' : '') + ' oninput="chantierMainTotaux()"></label>'
    + '<span>' + esc(t4('m_pa')) + '</span>'
    + '<span id="cj-main-env" style="display:inline-block" title="' + esc(raison) + '"><button type="button" id="cj-main-valider" class="cpj-touche cpj-primaire" onclick="chantierMainValider()"' + (max <= 0 ? ' disabled' : '') + '>' + esc(t4('m_travailler')) + '</button></span></div>'
    + '<p id="cj-main-resume" class="cj-resume"></p>' + (raison ? '<p class="cj-raison">' + esc(raison) + '</p>' : '');
}
function chantierMainTotaux() {
  const t0 = ts(), ch = t0.chantier, doc = global.document; if (!ch) return null;
  const el = doc.getElementById('chantier-heures'); if (!el) return null;
  const max = Number(el.max) || 0; let h = Math.floor(Number(el.value) || 0);
  if (h > max) { h = max; el.value = String(max); }
  const taux = typeof tauxHoraireChantier === 'function' ? tauxHoraireChantier(ch) : 0;
  const res = doc.getElementById('cj-main-resume'); if (res) res.textContent = h > 0 ? t4('m_gain', { v: fr(h * taux), cur: cur(), h }) : '';
  const b = doc.getElementById('cj-main-valider'); if (b) b.disabled = !(h > 0);
  return h;
}
function ongletGestion(ch, t0) {
  const c = cur(), p = ch.prixAchatPJ || {}, min = typeof CHANTIER_SALAIRE_MINIMUM !== 'undefined' ? CHANTIER_SALAIRE_MINIMUM : 50;
  if (!maitreOuvrage(t0)) return '<p>' + esc(t4('g_reserve')) + '</p>';
  const ap = prochainAppel(ch);
  let h = '<div class="cj-tableau-bord">'
    + '<div>' + esc(t4('g_treso')) + '<b>' + fr(ch.tresorerie) + ' ' + c + '</b></div>'
    + '<div>' + esc(t4('g_verse')) + '<b>' + fr(ch.totalVerse) + ' / ' + fr(ch.coutTotal) + ' ' + c + '</b></div>'
    + '<div>' + esc(t4('g_appel')) + '<b>' + esc(ap ? t4('g_appel_txt', { m: fr(ap.m), cur: c, j: ap.j, date: dateDuJour(ap.j, ch) }) : t4('g_appel_ok')) + '</b></div></div>';
  if (ch.attenteReception || (typeof chantierTermine === 'function' && chantierTermine(ch)))
    return h + '<div class="cj-carte"><button type="button" class="cpj-touche cpj-primaire" onclick="chantierGestion(\'reception\')">' + esc(t4('g_reception')) + '</button></div>';
  h += '<div class="cj-carte"><b>' + esc(t4('g_prix')) + '</b><div style="font-size:.95rem;color:#b8a888">' + esc(t('prix_note')) + '</div>'
    + MATS.map(m => '<label style="margin-right:.8rem">' + esc(t('m_' + m)) + ' <input type="number" min="0" step="1" id="chantier-prix-' + m + '" value="' + esc(p[m] ?? '') + '"> ' + c + '</label>').join('')
    + ' <button type="button" class="cpj-touche cpj-primaire" onclick="chantierGestion(\'prix\')">' + esc(t4('g_enregistrer')) + '</button></div>'
    + '<div class="cj-carte"><b>' + esc(t4('g_salaire')) + '</b><div style="font-size:.95rem;color:#b8a888">' + esc(t('taux_note', { m: min, cur: c })) + '</div>'
    + '<input type="number" min="' + min + '" step="1" id="chantier-taux" value="' + esc(ch.tauxHoraire ?? (typeof tauxHoraireChantier === 'function' ? tauxHoraireChantier(ch) : '')) + '"> ' + c
    + ' <button type="button" class="cpj-touche cpj-primaire" onclick="chantierGestion(\'taux\')">' + esc(t4('g_enregistrer')) + '</button></div>'
    + '<div class="cj-carte"><b>' + esc(t4('g_fonds')) + '</b><div style="font-size:.95rem;color:#b8a888">' + esc(t('fonds_note')) + '</div>'
    + '<input type="number" min="1" step="1" id="chantier-fonds" value="' + esc(ap ? ap.m : Math.max(0, (Number(ch.coutTotal) || 0) - (Number(ch.totalVerse) || 0))) + '"> ' + c
    + ' <button type="button" class="cpj-touche cpj-primaire" onclick="chantierGestion(\'fonds\')">' + esc(t4('g_verser')) + '</button></div>'
    + '<div class="cj-carte"><b>' + esc(t4('g_commande')) + '</b><div><b>' + esc(t4('g_commande_txt', { ville: nomVilleChantier() })) + '</b></div>'
    + '<div style="font-size:.95rem;color:#b8a888">' + esc(t4('g_commande_note')) + '</div>'
    + '<div id="cj-derniere-commande">' + esc(derniereCommandeTexte(ch)) + '</div></div>';
  if (typeof verdictModificationPlan === 'function' && verdictModificationPlan(ch).ok)
    h += '<div class="cj-carte"><button type="button" class="cpj-touche" onclick="chantierGestion(\'lots\')">' + esc(t4('g_lots')) + '</button></div>';
  return h;
}
// ── Lecture du serveur (migration 20261124120000_chantier_fenetre_lire) ─────────────────────────────
// Heures du jour, plafond d'heures, salaire, prix et plafonds de vente : décidés par le serveur, jamais par l'écran.
const lecture = { terrain: null, r: null, enCours: null };
function lectureCourante() { const id = etat().currentBuilding; return lecture.terrain === id ? lecture.r : null; }
async function lireServeur() {
  const id = etat().currentBuilding;
  if (!estTerrain(id) || typeof global.sbRpcVerdict !== 'function') return null;
  if (lecture.enCours && lecture.enCours.id === id) return lecture.enCours.p;
  const p = global.sbRpcVerdict('chantier_fenetre_lire', { p_terrain_id: id }).catch(() => null).then(r => {
    if (etat().currentBuilding === id) { lecture.terrain = id; lecture.r = r && typeof r === 'object' ? r : { ok: false, raison: 'transport' }; }
    return r;
  }).finally(() => { if (lecture.enCours && lecture.enCours.p === p) lecture.enCours = null; });
  lecture.enCours = { id, p };
  return p;
}
// Rond « ? » : bulle de deux phrases au survol, au clavier et au toucher (même bulle que les jauges, .hg-jauge-bulle).
function aide(cle) { return '<button type="button" class="cj-aide" data-cj-aide="' + esc(cle) + '" aria-label="' + esc(tc('aide')) + '">?</button>'; }
function montrerAide(b) {
  const doc = global.document; let bulle = doc.getElementById('cj-aide-bulle');
  if (!bulle) { bulle = doc.createElement('div'); bulle.id = 'cj-aide-bulle'; bulle.className = 'hg-jauge-bulle cj-aide-bulle'; bulle.setAttribute('role', 'tooltip'); doc.body.appendChild(bulle); }
  if (bulle.hidden || bulle.dataset.cle !== b.dataset.cjAide) bulle.dataset.depuis = String(Date.now());
  bulle.dataset.cle = b.dataset.cjAide; bulle.textContent = tc(b.dataset.cjAide); bulle.hidden = false;
  const r = b.getBoundingClientRect(), vw = global.innerWidth || 1024, largeur = Math.min(300, vw - 32);
  bulle.style.maxWidth = largeur + 'px'; bulle.style.left = Math.max(16, Math.min(r.left, vw - largeur - 16)) + 'px'; bulle.style.top = (r.bottom + 8) + 'px';
  const h = bulle.getBoundingClientRect().height, vh = global.innerHeight || 768;
  if (r.bottom + 8 + h > vh - 8) bulle.style.top = Math.max(8, r.top - h - 8) + 'px';
}
function cacherAide() { const b = global.document && global.document.getElementById('cj-aide-bulle'); if (b) b.hidden = true; }
function brancherAides(racine) {
  racine.querySelectorAll('.cj-aide').forEach(b => {
    b.addEventListener('mouseenter', () => montrerAide(b)); b.addEventListener('mouseleave', cacherAide);
    b.addEventListener('focus', () => montrerAide(b)); b.addEventListener('blur', cacherAide);
    b.addEventListener('keydown', e => { if (e.key === 'Escape') cacherAide(); });
    b.addEventListener('click', e => {   // toucher : bascule (un toucher émet aussi focus et mouseenter juste avant)
      e.stopPropagation(); const bulle = global.document.getElementById('cj-aide-bulle');
      if (bulle && !bulle.hidden && bulle.dataset.cle === b.dataset.cjAide && e.pointerType !== 'mouse' && Date.now() - Number(bulle.dataset.depuis || 0) > 600) { cacherAide(); return; }
      montrerAide(b);
    });
  });
}
// C.1 — résumé permanent en haut de la fenêtre : heures du jour et matériaux du jour (valeurs du serveur).
function resumeChantier() {
  const L = lectureCourante();
  let heures;
  if (!L) heures = esc(tc('r_heures_attente'));
  else if (!L.ok) heures = esc(tc('r_lecture_ko'));
  else {
    const tr = L.travail || {}, j = Math.max(0, Number(tr.restantesJour) || 0), a = Math.max(0, Number(tr.restantesAvance) || 0);
    heures = j > 0 ? esc(tc('r_heures', { h: fr(j) })).replace(fr(j), '<b>' + fr(j) + '</b>') : a > 0 ? esc(tc('r_heures_avance', { h: fr(a) })) : esc(tc('r_heures_aucune'));
  }
  const mats = L && L.ok ? MATS.map(m => {
    const x = (L.materiaux || {})[m] || {}, s0 = Number(x.stock) || 0, b = Number(x.besoin) || 0;
    return '<span class="cj-pastille' + (s0 < b ? ' cj-manque' : '') + '">' + esc(tc('r_mat', { m: t('m_' + m), s: fr(s0), b: fr(b) })) + '</span>';
  }).join('') : '';
  return '<section class="cj-resume-haut" aria-live="polite">'
    + '<p class="cj-resume-heures">' + heures + ' ' + aide('r_heures_aide') + '</p>'
    + (mats ? '<p class="cj-resume-mat"><span class="cj-resume-titre">' + esc(tc('r_materiaux')) + '</span> ' + aide('r_mat_aide') + '</p><div class="cj-pastilles">' + mats + '</div>' : '')
    + '</section>'
    // Emplacement réservé au climat (bloc D de la mission Purge : arrêt par canicule ou crue, « Offrir 20 bouteilles d’eau »).
    // Vide et caché ici : le module climat le remplit par chantierZoneClimat(zone, contexte) ou l'événement « rp:chantier-fenetre ».
    + '<div id="chantier-zone-climat" class="cj-zone-climat" hidden></div>';
}
function remplirZoneClimat() {
  const doc = global.document, zone = doc.getElementById('chantier-zone-climat');
  if (!zone) return;
  const contexte = { terrain: etat().currentBuilding, lecture: lectureCourante(), chantier: ts().chantier || null };
  try { if (typeof global.chantierZoneClimat === 'function') global.chantierZoneClimat(zone, contexte); } catch (_) {}
  try { doc.dispatchEvent(new global.CustomEvent('rp:chantier-fenetre', { detail: Object.assign({ zone }, contexte) })); } catch (_) {}
}
// C.2 — « Travailler sur ce chantier » dans la fenêtre principale : heures avec − et +, plafonnées par le serveur,
// gain affiché avant validation (salaire horaire renvoyé par le serveur × heures choisies).
const saisie = {};   // valeurs des compteurs − / + (heures, quantités), gardées d'un rendu à l'autre
function borne(cle, max, defaut) {
  const v = saisie[cle] == null ? defaut : saisie[cle];
  saisie[cle] = Math.max(max > 0 ? (cle === 'h' ? 1 : 0) : 0, Math.min(max, Math.floor(Number(v) || 0)));
  return saisie[cle];
}
function compteur(cle, valeur, max, moins, plus, unite) {
  return '<div class="cj-compteur" role="group">'
    + '<button type="button" class="cpj-touche cj-pas" aria-label="' + esc(moins) + '" onclick="chantierPas(\'' + cle + '\',-1)"' + (valeur <= (cle === 'h' ? 1 : 0) ? ' disabled' : '') + '>−</button>'
    + '<output class="cj-valeur" id="cj-v-' + cle + '" aria-live="polite">' + esc(unite) + '</output>'
    + '<button type="button" class="cpj-touche cj-pas" aria-label="' + esc(plus) + '" onclick="chantierPas(\'' + cle + '\',1)"' + (valeur >= max ? ' disabled' : '') + '>+</button></div>';
}
function raisonTexte(r) { return TXTC['x_' + r] ? tc('x_' + r) : tc('x_defaut'); }
function carteTravail() {
  const L = lectureCourante(), c = cur();
  const tr = L && L.ok ? (L.travail || {}) : null;
  const max = tr ? Math.max(0, Math.floor(Number(tr.max) || 0)) : 0, taux = tr ? Number(tr.taux) || 0 : 0;
  const h = borne('h', max, max);
  let corps;
  if (!tr) corps = '<p class="cpj-note">' + esc(tc(L ? 'r_lecture_ko' : 'r_heures_attente')) + '</p>';
  else if (max <= 0) corps = '<p class="cj-raison">' + esc(raisonTexte(tr.raison)) + '</p>';
  else corps = compteur('h', h, max, tc('w_moins'), tc('w_plus'), tc('w_heures', { h }))
    + '<p class="cpj-note">' + esc(tc('w_plafond', { h: max })) + '</p>'
    + '<p class="cj-resume" id="cj-main-resume">' + esc(tc('w_gain', { v: fr(h * taux), cur: c, h })) + '</p>'
    + '<input type="hidden" id="chantier-heures" value="' + h + '">'
    + '<button type="button" id="cj-main-valider" class="cpj-touche cpj-primaire cj-action" onclick="chantierMainValider()">' + esc(tc('w_bouton', { h })) + '</button>';
  return '<section class="cj-carte cj-travail"><h3 class="cj-carte-titre">' + esc(tc('w_titre')) + '</h3>'
    + (tr ? '<p class="cj-ligne-aide">' + esc(tc('w_salaire', { v: fr(taux), cur: c })) + ' ' + aide('w_salaire_aide') + '</p>' : '')
    + corps + '</section>';
}
function chantierPas(cle, d) {
  saisie[cle] = (Number(saisie[cle]) || 0) + d;
  ouvrirFenetreChantier(true, null, true);
  const b = global.document.querySelector('#chantier-fenetre button[onclick="chantierPas(\'' + cle + '\',' + d + ')"]');
  if (b && !b.disabled) b.focus();
}
function ongletParticiper(ch) { return carteTravail(); }
function fenetreOuverte() {
  const doc = global.document, m = doc && doc.getElementById('modal-postes');
  return !!(m && m.classList.contains('open') && doc.getElementById('chantier-fenetre'));
}
function ouvrirFenetreChantier(silencieux, onglet, sansLecture) {
  const t0 = ts(), ch = t0.chantier, doc = global.document;
  if (!ch || !doc) return;
  if (silencieux === true && !fenetreOuverte()) return;   // jamais d'ouverture automatique
  if (onglet) vue.onglet = onglet; else if (silencieux !== true) { vue.onglet = 'participer'; for (const k of Object.keys(saisie)) delete saisie[k]; }
  injecterStyleJauges();
  const gere = maitreOuvrage(t0);
  if (vue.onglet === 'main') vue.onglet = 'participer';
  if (vue.onglet === 'etat') vue.onglet = 'avancement';
  const onglets = ['participer', 'stock', 'avancement'].concat(gere ? ['gestion'] : []);
  if (!onglets.includes(vue.onglet)) vue.onglet = 'participer';
  const contenu = vue.onglet === 'stock' ? ongletStock(ch) : vue.onglet === 'participer' ? ongletParticiper(ch) : vue.onglet === 'gestion' ? ongletGestion(ch, t0) : ongletEtat(ch, t0);
  const html = '<div id="chantier-fenetre" class="cpj-dialogue" style="padding:.3rem .2rem .6rem">' + resumeChantier()
    + '<div class="cj-onglets" role="tablist">' + onglets.map(o => '<button type="button" role="tab" aria-selected="' + (o === vue.onglet) + '" onclick="chantierOnglet(\'' + o + '\')">' + esc(tc('o_' + o)) + '</button>').join('') + '</div>'
    + '<div role="tabpanel">' + contenu + '</div></div>';
  const titre = doc.getElementById('postes-modal-title'), corps = doc.getElementById('postes-body');
  if (!corps) return;
  if (titre) titre.textContent = t('titre');
  const saisies = {};
  if (silencieux === true) corps.querySelectorAll('#chantier-fenetre input').forEach(e => { if (e.id) saisies[e.id] = e.type === 'checkbox' ? e.checked : e.value; });
  corps.innerHTML = html;
  for (const [id, v] of Object.entries(saisies)) { const e = doc.getElementById(id); if (!e) continue; if (e.type === 'checkbox') e.checked = v; else e.value = v; }
  doc.getElementById('modal-postes')?.classList.add('open');
  const f = doc.getElementById('chantier-fenetre'); if (f) brancherAides(f);
  remplirZoneClimat();
  if (vue.onglet === 'stock') chantierStockTotaux();
  // Relecture du serveur, puis nouveau rendu (sans relancer de lecture) si la fenêtre est toujours ouverte.
  if (!sansLecture) lireServeur().then(() => { if (fenetreOuverte()) ouvrirFenetreChantier(true, null, true); });
}
function chantierOnglet(o) { vue.onglet = o; ouvrirFenetreChantier(false, o); }
const val = id => (global.document.getElementById(id)?.value || '').trim();
const entier = s => /^[0-9]{1,9}$/.test(s) ? Number(s) : null;
let validation = false;
async function relireEtRouvrir() {
  if (typeof global.chargerTerrainState === 'function') await global.chargerTerrainState(etat().currentBuilding);
  const onglet = vue.onglet;
  ouvrirFenetreChantier(false, onglet);
}
async function chantierStockValider() {
  const v = chantierStockTotaux();
  if (v.refus || validation) return;
  validation = true;
  try {
    const doc = global.document;
    for (const l of v.lignes) {
      // Le chemin existant (reçus, rejeu sûr) lit #vente-matiere et #vente-quantite.
      const tmp = doc.createElement('div'); tmp.style.display = 'none';
      tmp.innerHTML = '<input id="vente-matiere" value="' + esc(l.m) + '"><input id="vente-quantite" value="' + esc(String(l.q)) + '">';
      doc.body.appendChild(tmp);
      try { await global.confirmerVenteMateriauxChantier(l.don ? 'don' : 'vente'); } finally { tmp.remove(); }
    }
    await relireEtRouvrir();
  } finally { validation = false; }
}
async function chantierMainValider() {
  const h = Math.floor(Number(global.document.getElementById('chantier-heures')?.value) || 0);
  if (!(h > 0) || validation) return;
  validation = true;
  try { await global.confirmerTravailChantier(); await relireEtRouvrir(); } finally { validation = false; }
}
async function chantierGestion(a) {
  if (validation) return;
  const c = cur(), min = typeof CHANTIER_SALAIRE_MINIMUM !== 'undefined' ? CHANTIER_SALAIRE_MINIMUM : 50;
  if (a === 'prix') {
    const prix = {};
    for (const m of MATS) { const x = val('chantier-prix-' + m); if (x !== '') { if (entier(x) === null) { global.showToast(t('titre'), t('r_prix'), false); return; } prix[m] = x; } }
    if (!Object.keys(prix).length) return;
    validation = true; try { await global.constructionExecuterCommande('prix', { prix }); await relireEtRouvrir(); } finally { validation = false; }
  } else if (a === 'taux') {
    const v = entier(val('chantier-taux'));
    if (v === null || v < min) { global.showToast(t('titre'), t('r_taux', { m: min, cur: c }), false); return; }
    validation = true; try { await global.constructionExecuterCommande('taux', { taux: String(v) }); await relireEtRouvrir(); } finally { validation = false; }
  } else if (a === 'fonds') {
    const v = entier(val('chantier-fonds'));
    if (!v) { global.showToast(t('titre'), t('r_montant'), false); return; }
    if (argentPJ() > 0 && v > argentPJ()) { global.showToast(t('titre'), t('r_argent'), false); return; }
    validation = true; try { await global.constructionExecuterCommande('verser', { montant: String(v) }); await relireEtRouvrir(); } finally { validation = false; }
  } else if (a === 'lots') { return global.doModifierPlanChantier(0, 0); }
  else if (a === 'reception') { global.document.getElementById('modal-postes')?.classList.remove('open'); return global.receptionnerChantier(); }
}
// Ancienne API (verdictChoix, chantierChoisir, chantierTotaux, chantierValider) : conservée pour les écrans encore ouverts.
function verdictChoix() { return choix.action ? { pa: 0 } : { refus: t('r_choisir') }; }
function chantierChoisir(a) { choix.action = a; vue.onglet = a === 'travailler' ? 'participer' : (a === 'vendre' || a === 'donner') ? 'stock' : 'gestion'; ouvrirFenetreChantier(false, vue.onglet); }
function chantierTotaux() { return verdictChoix(); }
async function chantierValider() { return null; }

function demarrer() {
  brancher();
  setInterval(suivre, 20000);
  global.document.addEventListener('click', e => { if (!e.target.closest || !e.target.closest('.cj-aide')) cacherAide(); });
  global.addEventListener('scroll', cacherAide, true);
}
if (global.document && global.document.readyState !== 'loading') demarrer();
else if (global.document) global.document.addEventListener('DOMContentLoaded', demarrer);

global.RPChantierVue = { TXT, TXT4, TXTC, lireServeur, lectureCourante, jauge, verdictStock, candidatsImage, imageImmediate, imageResolue, etapeDe, lignesSurcouche, rafraichirVueChantier, verdictChoix, _choix: choix, _existe: existe };
Object.assign(global, { ouvrirFenetreChantier, chantierChoisir, chantierTotaux, chantierValider, chantierOnglet, chantierStockTotaux, chantierStockValider, chantierMainTotaux, chantierMainValider, chantierGestion, chantierPas, chantierImageImmediate: imageImmediate, rafraichirVueChantier });
})(typeof window !== 'undefined' ? window : globalThis);
