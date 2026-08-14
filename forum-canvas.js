/* ===========================================================================
   FORUM-CANVAS.JS — Moteur générique de surface de composition libre (Lot A2)

   Ne connaît RIEN du contenu réel des objets (ni Tiptap, ni image, ni texte) : c'est
   strictement le moteur de manipulation physique (déplacer, redimensionner, sélectionner,
   ordonner) d'éléments positionnés librement dans un conteneur. Extrait et généralisé, sans
   changement de logique, du prototype validé prototype-canvas-composition.html (F1.5) —
   voir ce fichier pour l'historique des itérations d'ergonomie qui ont amené à ce
   comportement exact (déplacement par poignée dédiée, largeur par bords, min-height par le
   bas, coins pour les objets à ratio fixe).

   Ce fichier est chargé par plateau.html mais n'est appelé par rien tant que les lots
   suivants (C1+) ne le câblent pas dans le forum réel. Aucun effet visible à lui seul.
   =========================================================================== */

const RP_CANVAS_MIN_WIDTH = 40;

// Crée un contrôleur de composition pour UN conteneur donné (jamais un #canvas fixe global) —
// plusieurs surfaces indépendantes peuvent coexister si besoin.
function rpCanvasCreateController(container) {
  let zCounter = 10;

  // Sélection = passage au premier plan par défaut (comportement validé dans le prototype ;
  // des actions avant-plan/arrière-plan explicites, indépendantes du geste de sélection,
  // sont prévues au lot C5 — non incluses ici).
  function selectElement(el) {
    container.querySelectorAll('.rp-canvas-el.selected').forEach(o => {
      if (o !== el) o.classList.remove('selected');
    });
    el.classList.add('selected');
    zCounter += 1;
    el.style.zIndex = zCounter;
  }

  function deselectAll() {
    container.querySelectorAll('.rp-canvas-el.selected').forEach(o => o.classList.remove('selected'));
  }

  container.addEventListener('mousedown', (e) => {
    if (e.target === container) deselectAll();
  });

  // Déplacement générique : `handleEl` capte le geste (une poignée dédiée, ou l'élément
  // entier selon l'objet), `el` est l'élément réellement déplacé. `state` est un objet
  // { x, y, ... } tenu à jour par l'appelant.
  function attachDrag(handleEl, state, el) {
    handleEl.addEventListener('mousedown', (e) => {
      e.preventDefault();
      selectElement(el);
      const startX = e.clientX, startY = e.clientY;
      const startLeft = state.x, startTop = state.y;
      function onMove(ev) {
        state.x = startLeft + (ev.clientX - startX);
        state.y = startTop + (ev.clientY - startY);
        el.style.left = state.x + 'px';
        el.style.top = state.y + 'px';
      }
      function onUp() {
        document.removeEventListener('mousemove', onMove);
        document.removeEventListener('mouseup', onUp);
      }
      document.addEventListener('mousemove', onMove);
      document.addEventListener('mouseup', onUp);
    });
  }

  // Redimensionnement horizontal par un bord (gauche ou droit) — largeur uniquement, jamais
  // la hauteur. Utilisé pour les zones de texte (largeur réglable, hauteur toujours pilotée
  // par le contenu).
  function attachEdgeResize(handleEl, side, state, el, opts) {
    const minWidth = (opts && opts.minWidth) || RP_CANVAS_MIN_WIDTH;
    handleEl.addEventListener('mousedown', (e) => {
      e.preventDefault();
      e.stopPropagation();
      selectElement(el);
      const startX = e.clientX;
      const startWidth = state.width;
      const originalLeft = state.x;
      const originalRight = state.x + state.width;
      function onMove(ev) {
        const dx = ev.clientX - startX;
        let newWidth;
        if (side === 'right') { newWidth = Math.max(minWidth, startWidth + dx); state.x = originalLeft; }
        else { newWidth = Math.max(minWidth, startWidth - dx); state.x = originalRight - newWidth; }
        state.width = newWidth;
        el.style.left = state.x + 'px';
        el.style.width = newWidth + 'px';
      }
      function onUp() {
        document.removeEventListener('mousemove', onMove);
        document.removeEventListener('mouseup', onUp);
      }
      document.addEventListener('mousemove', onMove);
      document.addEventListener('mouseup', onUp);
    });
  }

  // Redimensionnement de la hauteur MINIMALE par le bord bas — jamais une hauteur fixe (pas
  // de height/max-height/overflow ici). `getRequiredHeight()` est fourni par l'appelant : ce
  // moteur ignore délibérément ce qu'est le contenu réel, mais a besoin de savoir jusqu'où il
  // peut réduire le plancher sans jamais descendre sous la hauteur réellement nécessaire —
  // c'est ce qui garantit qu'aucun texte n'est jamais tronqué et qu'aucun défilement interne
  // n'apparaît, et que la poignée s'arrête pile où le contenu s'arrête (sans "zone morte").
  function attachBottomResize(handleEl, state, el, getRequiredHeight) {
    handleEl.addEventListener('mousedown', (e) => {
      e.preventDefault();
      e.stopPropagation();
      selectElement(el);
      const startY = e.clientY;
      const startMinHeight = state.minHeight;
      function onMove(ev) {
        const dy = ev.clientY - startY;
        const requiredHeight = getRequiredHeight();
        const candidate = startMinHeight + dy;
        const newMinHeight = Math.max(requiredHeight, candidate);
        state.minHeight = newMinHeight;
        el.style.minHeight = newMinHeight + 'px';
      }
      function onUp() {
        document.removeEventListener('mousemove', onMove);
        document.removeEventListener('mouseup', onUp);
      }
      document.addEventListener('mousemove', onMove);
      document.addEventListener('mouseup', onUp);
    });
  }

  // Redimensionnement 2D par un coin, ratio conservé — pour les objets à hauteur explicite
  // (ex. une image), jamais utilisé pour une zone de texte.
  function attachCornerResize(handleEl, corner, state, el, opts) {
    const minWidth = (opts && opts.minWidth) || RP_CANVAS_MIN_WIDTH;
    handleEl.addEventListener('mousedown', (e) => {
      e.preventDefault();
      e.stopPropagation(); // sinon le mousedown remonterait aussi au drag de l'objet entier
      selectElement(el);
      const startX = e.clientX;
      const startWidth = state.width, startHeight = state.height;
      const aspect = startHeight / startWidth; // ratio conservé, jamais recalculé pendant le drag
      const originalLeft = state.x, originalTop = state.y;
      const originalRight = state.x + state.width;
      const originalBottom = state.y + state.height;
      const growRight = corner === 'ne' || corner === 'se';
      function onMove(ev) {
        const dx = (ev.clientX - startX) * (growRight ? 1 : -1);
        const newWidth = Math.max(minWidth, startWidth + dx);
        const newHeight = newWidth * aspect;
        if (corner === 'se') { state.x = originalLeft; state.y = originalTop; }
        else if (corner === 'sw') { state.x = originalRight - newWidth; state.y = originalTop; }
        else if (corner === 'ne') { state.x = originalLeft; state.y = originalBottom - newHeight; }
        else { state.x = originalRight - newWidth; state.y = originalBottom - newHeight; }
        state.width = newWidth; state.height = newHeight;
        el.style.left = state.x + 'px';
        el.style.top = state.y + 'px';
        el.style.width = newWidth + 'px';
        el.style.height = newHeight + 'px';
      }
      function onUp() {
        document.removeEventListener('mousemove', onMove);
        document.removeEventListener('mouseup', onUp);
      }
      document.addEventListener('mousemove', onMove);
      document.addEventListener('mouseup', onUp);
    });
  }

  return {
    selectElement, deselectAll,
    attachDrag, attachEdgeResize, attachBottomResize, attachCornerResize,
  };
}
