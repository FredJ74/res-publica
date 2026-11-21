// PRESSE — noms cliquables (règle de Fred, 21/11/2026) : dans un article, le nom de chaque personnage joueur cité (victime,
// personne arrêtée, élu…) ouvre sa fiche publique, avec « Écrire à ». Les noms viennent des faits sources de l'édition
// (champ estPJ, auteur identifié) : un auteur anonyme n'y figure jamais nommé, il n'est donc jamais cliquable.
(function (global) {
'use strict';
const TXT = { ecrire: 'Écrire à {nom}', fermer: 'Fermer', fiche: 'Fiche de {nom}' };   // clés pour Codex (RELAIS)
const t = (k, v) => TXT[k].replace(/\{(\w+)\}/g, (m, c) => v && v[c] != null ? v[c] : m);
const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
// Noms de personnages joueurs cités par les faits sources de l'édition.
function nomsCites(edition) {
  const noms = new Set();
  // Liste calculée par le serveur (journal_edition_lire, « noms_cites ») ; sinon les faits sources disponibles.
  if (Array.isArray(edition && edition.noms_cites)) edition.noms_cites.forEach(n => typeof n === 'string' && noms.add(n));
  const fs = edition && edition.faits_sources;
  const faits = Array.isArray(fs) ? fs : (fs && typeof fs === 'object' ? [...(fs.FACTS || []), ...(fs.PUBLIC_STATEMENTS || [])] : []);
  for (const f of faits) {
    if (!f || typeof f !== 'object') continue;
    if (f.estPJ && typeof f.acteur === 'string') noms.add(f.acteur);
    if (f.victime && f.victime.estPJ && typeof f.victime.nom === 'string') noms.add(f.victime.nom);
    if (f.auteur && f.auteur.identifie === true && typeof f.auteur.nom === 'string') noms.add(f.auteur.nom);
  }
  return [...noms].map(n => n.trim()).filter(n => n.length >= 2).sort((a, b) => b.length - a.length);
}
// Remplace, dans le texte seulement (jamais dans les balises, liens ou boutons), chaque nom par un lien.
function lierNoms(html, noms) {
  if (!noms.length || typeof html !== 'string' || !global.document) return html;
  const tpl = global.document.createElement('template'); tpl.innerHTML = html;
  const motif = new RegExp('(' + noms.map(n => n.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|') + ')', 'g');
  const marcheur = global.document.createTreeWalker(tpl.content, 4 /* texte */);
  const textes = []; let n;
  while ((n = marcheur.nextNode())) if (!n.parentElement || !n.parentElement.closest('a,button,script,style,textarea')) textes.push(n);
  for (const tn of textes) {
    const v = tn.nodeValue; if (!motif.test(v)) continue; motif.lastIndex = 0;
    const frag = global.document.createDocumentFragment(); let i = 0, m;
    while ((m = motif.exec(v))) {
      if (m.index > i) frag.appendChild(global.document.createTextNode(v.slice(i, m.index)));
      const a = global.document.createElement('a');
      a.href = '#'; a.className = 'journal-nom'; a.dataset.nom = m[1]; a.textContent = m[1];
      a.setAttribute('style', 'color:inherit;text-decoration:underline dotted;cursor:pointer');
      frag.appendChild(a); i = m.index + m[1].length;
    }
    if (i < v.length) frag.appendChild(global.document.createTextNode(v.slice(i)));
    tn.parentNode.replaceChild(frag, tn);
  }
  return tpl.innerHTML;
}
// Fiche publique : portrait, nom, « Écrire à » (messagerie, destinataire rempli), « Fermer ».
function ficheNom(nom) {
  const doc = global.document; doc.getElementById('journal-fiche')?.remove();
  const avatar = typeof global.getAvatarHtmlPourNom === 'function' ? global.getAvatarHtmlPourNom(nom, 72, '#C9A84C') : '';
  const f = doc.createElement('div'); f.id = 'journal-fiche'; f.setAttribute('role', 'dialog'); f.setAttribute('aria-label', t('fiche', { nom }));
  f.style.cssText = 'position:fixed;inset:0;z-index:9500;background:rgba(0,0,0,.55);display:flex;align-items:center;justify-content:center;padding:16px';
  f.innerHTML = '<div style="background:#12100c;border:1px solid #8a6a20;padding:1.1rem 1.3rem;display:flex;flex-direction:column;align-items:center;gap:.6rem;min-width:240px">'
    + avatar + '<div style="font-family:Bebas Neue,sans-serif;letter-spacing:.06em;font-size:1.1rem;color:#f0ead6">' + esc(nom) + '</div>'
    + '<button type="button" class="pnj-action-btn" data-ecrire><i class="ti ti-mail"></i> ' + esc(t('ecrire', { nom })) + '</button>'
    + '<button type="button" class="pnj-action-btn" data-fermer style="opacity:.8">' + esc(t('fermer')) + '</button></div>';
  f.addEventListener('click', e => {
    if (e.target === f || e.target.closest('[data-fermer]')) f.remove();
    else if (e.target.closest('[data-ecrire]')) { f.remove(); if (typeof global.ecrireAMembre === 'function') global.ecrireAMembre(nom); }
  });
  doc.body.appendChild(f);
}
function brancher() {
  if (typeof global.construireHtmlJournalDuJour === 'function' && !global.construireHtmlJournalDuJour.__noms) {
    const orig = global.construireHtmlJournalDuJour;
    const env = function (edition) { const h = orig.apply(this, arguments); try { return lierNoms(h, nomsCites(edition)); } catch (_) { return h; } };
    env.__noms = true; global.construireHtmlJournalDuJour = env;
  }
  global.document.addEventListener('click', e => {
    const a = e.target.closest && e.target.closest('a.journal-nom');
    if (!a) return; e.preventDefault(); ficheNom(a.dataset.nom);
  });
}
if (global.document && global.document.readyState !== 'loading') brancher();
else if (global.document) global.document.addEventListener('DOMContentLoaded', brancher);
global.RPPresseNoms = { nomsCites, lierNoms, ficheNom, TXT };
})(typeof window !== 'undefined' ? window : globalThis);
