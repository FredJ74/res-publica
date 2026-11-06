// Adaptation de présentation uniquement : mêmes éléments et mêmes commandes métier.
(() => {
  'use strict';
  const petit = window.matchMedia('(max-width: 1023px)');
  const boutons = [...document.querySelectorAll('[data-hg-panneau]')];
  const fond = document.getElementById('hg-mobile-fond');
  if (!fond || !boutons.length) return;
  let precedent = null;
  function fermer(restaurer = true) {
    delete document.body.dataset.mobilePanel;
    fond.hidden = true;
    boutons.forEach(b => b.setAttribute('aria-expanded', 'false'));
    if (restaurer && precedent?.isConnected && petit.matches) precedent.focus({preventScroll:true});
    precedent = null;
  }
  function panneau() {
    const choix = document.body.dataset.mobilePanel;
    if (choix === 'personnage') return document.getElementById('left');
    if (choix === 'menu') return document.getElementById('hg-menu-existant');
    if (choix === 'personnes') {
      const p = document.querySelector('.vue.active .persons-sidebar');
      return p?.style.display === 'none' ? document.querySelector('.vue.active .minimap') : p;
    }
    return null;
  }
  function ouvrir(b) {
    if (!petit.matches) return;
    if (document.body.dataset.mobilePanel === b.dataset.hgPanneau) { fermer(); return; }
    fermer(false);
    precedent = b;
    document.body.dataset.mobilePanel = b.dataset.hgPanneau;
    b.setAttribute('aria-expanded', 'true');
    fond.hidden = false;
    const cible = panneau();
    if (cible) { cible.tabIndex = -1; cible.focus({preventScroll:true}); }
  }
  boutons.forEach(b => b.addEventListener('click', () => ouvrir(b)));
  fond.addEventListener('click', () => fermer());
  document.addEventListener('keydown', e => {
    if (!petit.matches || !document.body.dataset.mobilePanel) return;
    if (e.key === 'Escape') { e.preventDefault(); fermer(); return; }
    if (e.key !== 'Tab') return;
    const p = panneau();
    const accessibles = p ? [...p.querySelectorAll('button,a[href],input,select,textarea,[tabindex="0"]')]
      .filter(x => !x.disabled && x.getClientRects().length) : [];
    if (!accessibles.length) { e.preventDefault(); return; }
    const premier = accessibles[0], dernier = accessibles[accessibles.length - 1];
    if (e.shiftKey && (document.activeElement === premier || document.activeElement === p)) { e.preventDefault(); dernier.focus(); }
    else if (!e.shiftKey && (document.activeElement === dernier || document.activeElement === p)) { e.preventDefault(); premier.focus(); }
  });
  // L'ouverture d'une vraie fenêtre métier ferme le tiroir, sans intercepter sa commande.
  document.addEventListener('click', e => {
    const p = panneau();
    if (p?.id === 'hg-menu-existant' && e.target.closest('button,a,[onclick]') && p.contains(e.target)) fermer(false);
  });
  const observer = new MutationObserver(() => {
    if (document.body.dataset.mobilePanel && document.querySelector('.modal-overlay.open')) fermer(false);
  });
  document.querySelectorAll('.modal-overlay').forEach(e => observer.observe(e, {attributes:true,attributeFilter:['class']}));
  const dimensionner = () => {
    if (!petit.matches) { fermer(false); return; }
    const hauteur = document.getElementById('topbar')?.getBoundingClientRect().height || 56;
    document.documentElement.style.setProperty('--hg-entete', hauteur + 'px');
  };
  petit.addEventListener('change', dimensionner);
  window.addEventListener('resize', dimensionner);
  // Les zones gardent leurs gestionnaires : la liste tactile les active, elle ne
  // reconstruit ni les destinations ni les contrôles du moteur de déplacement.
  const scenesPreparees = new WeakSet();
  function preparerScene() {
    document.querySelectorAll('.rc-fleche[onclick],.minimap-building[onclick]').forEach(e => {
      e.setAttribute('role','button'); e.tabIndex = 0;
      if (!e.getAttribute('aria-label')) {
        const icone = e.querySelector('i')?.className || '';
        e.setAttribute('aria-label', e.classList.contains('minimap-building') ? e.textContent.trim()
          : /arrow-down/.test(icone) ? 'Retour' : /chevron-left/.test(icone) ? 'À gauche'
          : /chevron-right/.test(icone) ? 'À droite' : 'Tout droit');
      }
    });
    const scene = document.getElementById('rc-scene');
    if (!petit.matches || !scene || scenesPreparees.has(scene)) return;
    const zones = [...scene.querySelectorAll('.rc-zone')];
    if (!zones.length) return;
    scenesPreparees.add(scene);
    const details = document.createElement('details'); details.className = 'hg-lieux-tactiles';
    const titre = document.createElement('summary'); titre.textContent = 'Lieux visibles'; details.append(titre);
    zones.forEach(zone => {
      const b = document.createElement('button'); b.type = 'button';
      b.textContent = zone.getAttribute('aria-label') || 'Consulter ce lieu';
      b.addEventListener('click', () => { if (zone.isConnected) zone.click(); });
      details.append(b);
    });
    scene.after(details);
  }
  document.addEventListener('keydown', e => {
    if (!e.target.matches('.rc-zone,.rc-fleche[onclick],.minimap-building[onclick]')) return;
    if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); if (!e.repeat) e.target.click(); }
  });
  const rue = document.getElementById('vue-rue');
  if (rue) new MutationObserver(preparerScene).observe(rue,{childList:true,subtree:true});
  petit.addEventListener('change',preparerScene);
  preparerScene();
  dimensionner();
})();
