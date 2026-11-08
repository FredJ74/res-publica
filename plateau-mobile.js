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
  // L3 : focus et hauteur visible uniquement ; fermeture par le bouton existant.
  let fenetreActive = null;
  const retoursFenetre = new WeakMap();
  const visibles = p => [...p.querySelectorAll('button,a[href],input,textarea,select,[tabindex="0"]')]
    .filter(e => !e.disabled && e.getClientRects().length && getComputedStyle(e).visibility !== 'hidden');
  function fenetre() {
    return [...document.querySelectorAll('.modal-overlay.open')]
      .sort((a,b) => (Number(getComputedStyle(a).zIndex)||0) - (Number(getComputedStyle(b).zIndex)||0)).at(-1) || null;
  }
  function suivreFenetre() {
    if (!petit.matches) { fenetreActive = null; return; }
    const courante = fenetre();
    if (courante === fenetreActive) return;
    const ancienne = fenetreActive;
    fenetreActive = courante;
    if (courante) {
      fermer(false);
      if (!courante.contains(document.activeElement)) retoursFenetre.set(courante, document.activeElement);
      const boite = courante.querySelector('.modal-box');
      if (boite) {
        boite.setAttribute('role','dialog'); boite.setAttribute('aria-modal','true');
        boite.setAttribute('aria-label',courante.querySelector('.modal-title')?.textContent || 'Fenêtre');
        boite.tabIndex = -1;
        (visibles(boite)[0] || boite).focus({preventScroll:true});
      }
    } else if (ancienne) {
      const retour = retoursFenetre.get(ancienne);
      (retour?.isConnected && retour.getClientRects().length ? retour : boutons[2]).focus({preventScroll:true});
    }
  }
  const fenetres = new MutationObserver(suivreFenetre);
  document.querySelectorAll('.modal-overlay').forEach(e => fenetres.observe(e,{attributes:true,attributeFilter:['class']}));
  document.addEventListener('keydown', e => {
    if (!petit.matches || !fenetreActive) return;
    if (e.key === 'Escape') {
      const fermerExistant = visibles(fenetreActive).find(x => x.matches('.modal-close,.tribune-fronton-close'));
      if (fermerExistant) { e.preventDefault(); fermerExistant.click(); }
    }
    if (e.key !== 'Tab') return;
    const elements = visibles(fenetreActive), premier = elements[0], dernier = elements.at(-1);
    if (!premier) { e.preventDefault(); return; }
    if (e.shiftKey && (document.activeElement === premier || !elements.includes(document.activeElement))) { e.preventDefault(); dernier.focus(); }
    else if (!e.shiftKey && (document.activeElement === dernier || !elements.includes(document.activeElement))) { e.preventDefault(); premier.focus(); }
  });
  function hauteurVisible() {
    if (!petit.matches) return;
    const v = window.visualViewport;
    document.documentElement.style.setProperty('--hg-visible', (v?.height || window.innerHeight) + 'px');
    document.documentElement.style.setProperty('--hg-decalage', (v?.offsetTop || 0) + 'px');
    const e = document.activeElement;
    if (fenetreActive?.contains(e) && e.matches('input,textarea,select'))
      requestAnimationFrame(() => { if (e.isConnected) e.scrollIntoView({block:'nearest'}); });
  }
  window.visualViewport?.addEventListener('resize',hauteurVisible);
  window.visualViewport?.addEventListener('scroll',hauteurVisible);
  window.addEventListener('resize',hauteurVisible);
  petit.addEventListener('change',() => { hauteurVisible(); suivreFenetre(); });
  hauteurVisible(); suivreFenetre();
  // L5 : isoler le défilement des tableaux, sans toucher aux cellules ou commandes.
  function adapterTables() {
    const racines = document.querySelectorAll('.modal-overlay,#self-content');
    if (!petit.matches) {
      document.querySelectorAll('.hg-table-defilante').forEach(c => { c.replaceWith(...c.childNodes); });
      return;
    }
    racines.forEach(r => r.querySelectorAll('table').forEach(t => {
      if (t.closest('.hg-table-defilante')) return;
      const c = document.createElement('div'); c.className = 'hg-table-defilante';
      c.tabIndex = 0; c.setAttribute('role','region'); c.setAttribute('aria-label','Tableau défilant');
      t.before(c); c.append(t);
    }));
  }
  let tablesPlanifiees = false;
  const tables = new MutationObserver(() => {
    if (tablesPlanifiees) return;
    tablesPlanifiees = true;
    requestAnimationFrame(() => { tablesPlanifiees = false; adapterTables(); });
  });
  document.querySelectorAll('.modal-overlay,#self-content').forEach(e => tables.observe(e,{childList:true,subtree:true}));
  petit.addEventListener('change',adapterTables); adapterTables();
  // L8 : reprendre par le chargeur existant, jamais par une copie de ses champs.
  let aRelire = false, reprise = null, generationReprise = 0;
  const message = document.createElement('div'); message.id = 'hg-reprise'; message.hidden = true;
  message.setAttribute('role','status');
  const texte = document.createElement('span');
  const reessayer = document.createElement('button'); reessayer.type = 'button'; reessayer.textContent = 'Réessayer';
  message.append(texte,reessayer); document.body.append(message);
  async function reprendre() {
    if (!petit.matches || document.hidden || !aRelire || reprise) return;
    message.hidden = false;
    if (navigator.onLine === false) { texte.textContent = 'Connexion perdue. Les ordres attendent le retour du serveur.'; return; }
    texte.textContent = 'Vérification de votre personnage auprès du serveur…';
    reessayer.disabled = true;
    const generation = generationReprise;
    reprise = Promise.resolve().then(async () => {
      let delai, annule = false;
      try {
        if (typeof loadCharacter !== 'function') throw Error('chargeur indisponible');
        const operation = (async () => {
          if (typeof rpAuthAssurerSession === 'function') await rpAuthAssurerSession();
          if (annule) throw Error('reprise abandonnée');
          return loadCharacter({reprise:true});
        })();
        const resultat = await Promise.race([operation,new Promise((_,refus) => {
          delai = setTimeout(() => { annule = true; loadCharacter.generation = (loadCharacter.generation || 0) + 1; refus(Error('délai dépassé')); },15000);
        })]);
        if (resultat !== true) throw Error('lecture non confirmée');
        // Une nouvelle suspension peut survenir pendant la lecture (verrouillage,
        // autre onglet). Sa réponse ne confirme pas cet état plus récent.
        if (generation !== generationReprise) throw Error('nouvelle synchronisation nécessaire');
        aRelire = false; message.hidden = true;
        // Le listener commun de visibilité conserve déjà les actualisations mail/forum.
        // Pas de seconde paire de lectures ajoutée à chaque retour.
      } catch (_) { texte.textContent = 'État non confirmé. Aucun ordre exécuté. Rétablissez la connexion puis réessayez.'; }
      finally { clearTimeout(delai); reessayer.disabled = false; reprise = null; }
    });
    await reprise;
  }
  function suspendre() { if (petit.matches) { aRelire = true; generationReprise++; } }
  document.addEventListener('visibilitychange',() => { if (document.hidden) suspendre(); else reprendre(); });
  window.addEventListener('pagehide',suspendre);
  window.addEventListener('pageshow',e => { if (e.persisted) { suspendre(); reprendre(); } });
  window.addEventListener('offline',() => { suspendre(); reprendre(); });
  window.addEventListener('online',reprendre);
  window.addEventListener('storage',e => { if (e.key?.startsWith('respublica_')) suspendre(); });
  reessayer.addEventListener('click',reprendre);
  function garderOrdre(e) {
    // L’authentification doit rester utilisable pendant que les ordres sont
    // suspendus ; elle ne rejoue ni ne débloque elle-même aucune commande métier.
    if (!petit.matches || !aRelire || e.target.closest('#hg-reprise,#bandeau-reconnexion')) return;
    if (e.type === 'click' && !e.target.closest('button,[onclick],a')) return;
    e.preventDefault(); e.stopImmediatePropagation(); reprendre();
    // Aucune répétition automatique du clic après réconciliation.
  }
  document.addEventListener('click',garderOrdre,true);
  document.addEventListener('submit',garderOrdre,true);
  dimensionner();
})();
