// Présentation seulement : une fenêtre visible, les précédentes sont conservées
// dans le DOM (saisies, défilement et progression) puis rendues à la fermeture.
(() => {
  'use strict';
  const selecteur = '.modal-overlay,dialog,[role="dialog"],#journal-store,#chat-piece-panel,.surveillance-trouvaille,[data-hg-fenetre]';
  const attente = 'hg-fenetre-en-attente';
  const etats = new WeakMap(), derniersFocus = new WeakMap();
  document.addEventListener('focusin', e => {
    const fenetre = e.target.closest?.(selecteur);
    const racine = fenetre?.closest('.modal-overlay') || fenetre;
    if (racine) derniersFocus.set(racine, e.target);
  });
  let pile = [], active = null;
  function ouverte(e) {
    if (!e.isConnected || e.hidden || e.parentElement?.closest(selecteur)) return false;
    if (e.matches('.modal-overlay')) return e.classList.contains('open');
    if (e.matches('dialog')) return e.open;
    return e.style.display !== 'none' && (e.classList.contains(attente) || getComputedStyle(e).display !== 'none');
  }
  function suspendre(e, oui) {
    if (e.classList.contains(attente) === oui) return;
    if (oui) {
      etats.set(e, { inert: e.inert, aria: e.getAttribute('aria-hidden'), focus: e.contains(document.activeElement) ? document.activeElement : derniersFocus.get(e), defilements: [e,...e.querySelectorAll('*')].filter(x=>x.scrollTop || x.scrollLeft).map(x=>({el:x,top:x.scrollTop,left:x.scrollLeft})) });
      e.inert = true;
      e.setAttribute('aria-hidden', 'true');
    } else {
      const etat = etats.get(e);
      e.inert = etat?.inert || false;
      if (etat?.aria == null) e.removeAttribute('aria-hidden');
      else e.setAttribute('aria-hidden', etat.aria);
    }
    e.classList.toggle(attente, oui);
    if (!oui) for (const d of etats.get(e)?.defilements || []) { d.el.scrollTop = d.top; d.el.scrollLeft = d.left; }
  }
  function actualiser(mutations = []) {
    // Les anciennes confirmations sans classe ni rôle sont des fonds plein écran.
    // Exclut les bandeaux, infobulles, boutons et décor de la vue.
    for (const e of document.querySelectorAll('body > div,body > section')) {
      if (e.matches(selecteur)) continue;
      const s = getComputedStyle(e);
      if (s.position === 'fixed' && [s.top,s.left,s.right,s.bottom].every(v => v === '0px')) e.setAttribute('data-hg-fenetre','');
    }
    const anciennes = pile;
    pile = pile.filter(ouverte);
    // Ordre réel des ouvertures, y compris les fenêtres ajoutées après le chargement.
    for (const m of mutations) {
      const cibles = m.type === 'childList' ? [...m.addedNodes].flatMap(n => n.nodeType === 1 ? [n, ...n.querySelectorAll(selecteur)] : []) : [m.target];
      for (const e of cibles) {
        if (!e.matches?.(selecteur) || !ouverte(e)) continue;
        // classList.add('open') sur une fenêtre déjà en attente la ramène devant.
        if (m.type === 'attributes' && m.attributeName === 'class' && m.oldValue === e.className && e.classList.contains(attente)) pile = pile.filter(x => x !== e);
        if (!pile.includes(e)) pile.push(e);
      }
    }
    for (const e of document.querySelectorAll(selecteur)) if (ouverte(e) && !pile.includes(e)) pile.push(e);
    // Un dialogue natif garde la priorité : showModal rend le reste inerte.
    // Une fenêtre HTML ouverte entre-temps attend donc sa fermeture.
    const courante = pile.filter(e=>e.matches('dialog')).at(-1) || pile.filter(e=>e.matches('#bandeau-reconnexion,#bandeau-personnage-fantome')).at(-1) || pile.at(-1) || null;
    const focusDansAncienne = active?.contains(document.activeElement);
    for (const e of new Set([...anciennes, ...pile])) suspendre(e, ouverte(e) && e !== courante);
    if (courante !== active) {
      active = courante;
      if (courante && (focusDansAncienne || etats.has(courante)) && !courante.contains(document.activeElement)) {
        const retour = etats.get(courante)?.focus;
        const cible = retour?.isConnected && courante.contains(retour) ? retour : courante.querySelector('button:not(:disabled),input:not(:disabled),textarea:not(:disabled),select:not(:disabled),[tabindex="0"]');
        cible?.focus({preventScroll: true});
      }
    }
  }
  // Une réassignation identique de style.display n'émet aucun changement DOM.
  // Les trois portes historiques de chat/journal reprennent donc explicitement
  // leur fenêtre en attente, sans fermeture, requête ou reconstruction.
  window.rpReprendreFenetre = e => {
    if (!e?.classList.contains(attente) || !ouverte(e)) return false;
    pile = pile.filter(x => x !== e);
    pile.push(e);
    actualiser();
    return true;
  };
  new MutationObserver(actualiser).observe(document.body, { subtree: true, childList: true, attributes: true, attributeOldValue: true, attributeFilter: ['class','style','open','hidden'] });
  actualiser();
})();
