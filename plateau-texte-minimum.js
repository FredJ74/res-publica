// TAILLE DE TEXTE MINIMALE DANS TOUTES LES FENÊTRES (Fred, 22/11/2026, GAME-DESIGN-FORET-TEST-20261122.md, point 1).
// « Aucune fenêtre, aucun rapport, aucune note ne doit afficher de texte plus petit que le texte courant des pages du jeu. »
//
// Texte courant des pages du plateau : 0,95 rem (15,2 px), la taille des descriptions de pièce, des personnes présentes,
// des ordres et des onglets (style.css, « Lisibilité du plateau »). C'est le plancher retenu.
//
// POURQUOI UN PLANCHER EN JAVASCRIPT. Les fenêtres du jeu sont écrites en HTML dans plus de 2 800 chaînes qui portent
// chacune leur taille (« font-size:.7rem », « .78rem »…). Une règle CSS ne sait pas dire « au moins 0,95 rem, sinon
// garder sa taille » : elle écraserait aussi les titres, plus grands. Ce module fait exactement cela, et rien d'autre :
//  - il regarde chaque fenêtre qui s'ouvre ou change (fenêtres classiques, rapports, rencontres, notes, infobulles,
//    journal des événements, notifications, fenêtres plein écran créées par le code) ;
//  - pour chaque élément qui porte du texte, si sa taille calculée est sous le plancher, il la remonte au plancher ;
//  - un texte déjà assez grand (titres compris) n'est jamais touché ; les pictogrammes, dessins et images non plus.
// Exceptions : le forum (page plein écran au gabarit propre, comparé au pixel près par banc-mobile-coque) et le plan de
// la ville (une carte). Un élément peut aussi s'exclure lui-même avec l'attribut data-texte-libre.
(function (global) {
'use strict';
const doc = global.document;
if (!doc) return;

const PLANCHER_REM = 0.95;
// Ce qui compte comme une fenêtre (ou un morceau de fenêtre) : le texte qu'on y lit ne descend jamais sous le plancher.
const FENETRES = [
  '.modal-overlay', '.modal-box', '[role="dialog"]', '[role="alertdialog"]', '[aria-modal="true"]', 'dialog',
  '#journal-store', '.journal', '#result-toast', '.rc-tooltip', '.building-hover-tooltip', '#climat-explication',
  '.rp-order-info-dialog', '.cpj-dialogue', '.cpj-note', '#climat-alerte'
].join(',');
// Jamais touchés : forum, plan de la ville, pictogrammes, dessins.
const EXCLUS = '#modal-forum, .modal-fullscreen, #minimap-ville-body, [data-texte-libre], svg, canvas';
const PICTO = /(^|\s)ti(\s|$)|(^|\s)ti-/;
const SAISIES = new Set(['INPUT', 'SELECT', 'TEXTAREA', 'OPTION', 'BUTTON']);
// Fenêtres créées par le code et posées sur la page (fond plein écran, panneau, bulle) : reconnues à leur position fixe.
const fenetresDynamiques = new WeakSet();

function plancherPx() {
  const racine = parseFloat(global.getComputedStyle(doc.documentElement).fontSize) || 16;
  return racine * PLANCHER_REM;
}
// Un élément « porte du texte » s'il contient directement des mots, ou si c'est un champ ou un bouton.
function porteDuTexte(el) {
  if (SAISIES.has(el.tagName)) return true;
  for (let n = el.firstChild; n; n = n.nextSibling) if (n.nodeType === 3 && n.nodeValue.trim()) return true;
  return false;
}
function exclu(el) {
  if (el.closest(EXCLUS)) return true;
  // Pictogramme Tabler (<i class="ti ti-…">) : une icône, pas du texte.
  const c = typeof el.className === 'string' ? el.className : '';
  return el.tagName === 'I' && PICTO.test(c);
}
function dansUneFenetre(el) {
  if (!el || el.nodeType !== 1) return false;
  if (el.closest(FENETRES)) return true;
  for (let n = el; n && n !== doc.body; n = n.parentElement) if (fenetresDynamiques.has(n)) return true;
  return false;
}
// Remonte au plancher chaque texte trop petit de « racine » (racine comprise). Rend le nombre d'éléments corrigés.
function imposer(racine, plancher) {
  if (!racine || racine.nodeType !== 1) return 0;
  const p = plancher || plancherPx();
  let corriges = 0;
  const liste = [racine].concat(Array.from(racine.getElementsByTagName('*')));
  for (const el of liste) {
    if (!porteDuTexte(el) || exclu(el)) continue;
    const taille = parseFloat(global.getComputedStyle(el).fontSize);
    if (!(taille > 0) || taille + 0.05 >= p) continue;
    el.style.setProperty('font-size', PLANCHER_REM + 'rem', 'important');
    el.dataset.texteMinimum = '1';
    corriges++;
  }
  return corriges;
}
// Toutes les fenêtres présentes sur la page.
function imposerPartout() {
  const p = plancherPx();
  let n = 0;
  doc.querySelectorAll(FENETRES).forEach(f => { if (!f.parentElement || !f.parentElement.closest(FENETRES)) n += imposer(f, p); });
  Array.from(doc.body ? doc.body.children : []).forEach(e => { if (fenetresDynamiques.has(e)) n += imposer(e, p); });
  return n;
}
function estFenetreDynamique(el) {
  if (!el || el.nodeType !== 1 || el.parentElement !== doc.body || el.closest(EXCLUS)) return false;
  if (/^(SCRIPT|STYLE|LINK|META|TEMPLATE)$/.test(el.tagName)) return false;
  // Habillage mobile du plateau (identifiants « hg-… » : en-tête, présences, reprise) : pas une fenêtre, gabarit propre.
  if (/^hg-/.test(el.id || '') && el.getAttribute('role') !== 'dialog') return false;
  const pos = (el.style && el.style.position) || global.getComputedStyle(el).position;
  return pos === 'fixed';
}

// Les fenêtres changent sans cesse (innerHTML) : on corrige ce qui vient d'arriver, groupé à l'image suivante.
let enAttente = new Set();
let prevu = false;
function traiter() {
  prevu = false;
  const lot = enAttente; enAttente = new Set();
  const p = plancherPx();
  lot.forEach(el => { if (el.isConnected) imposer(el, p); });
}
function noter(el) {
  enAttente.add(el);
  if (!prevu) { prevu = true; (global.requestAnimationFrame || setTimeout)(traiter); }
}
function observer() {
  if (!doc.body || typeof global.MutationObserver !== 'function') return;
  new global.MutationObserver(records => {
    for (const r of records) {
      const cible = r.target && r.target.nodeType === 1 ? r.target : (r.target && r.target.parentElement);
      if (r.type === 'characterData') { if (dansUneFenetre(cible)) noter(cible); continue; }
      for (const n of r.addedNodes) {
        if (n.nodeType === 3) { if (dansUneFenetre(cible)) noter(cible); continue; }
        if (n.nodeType !== 1) continue;
        if (estFenetreDynamique(n)) fenetresDynamiques.add(n);
        if (dansUneFenetre(n)) { noter(n); continue; }
        // Bloc ajouté hors fenêtre qui en contient (fragment inséré d'un coup).
        if (n.querySelector && n.querySelector(FENETRES)) n.querySelectorAll(FENETRES).forEach(noter);
      }
    }
  }).observe(doc.body, { childList: true, subtree: true, characterData: true });
  imposerPartout();
}

if (doc.readyState !== 'loading') observer();
else doc.addEventListener('DOMContentLoaded', observer);

global.RPTexteMinimum = { PLANCHER_REM, FENETRES, EXCLUS, plancherPx, imposer, imposerPartout, dansUneFenetre };
})(typeof window !== 'undefined' ? window : globalThis);
