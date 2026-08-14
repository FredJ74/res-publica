/* ===========================================================================
   FORUM-CANVAS.JS — Moteur générique de surface de composition libre (Lot A2)

   Ne connaît RIEN du contenu réel des objets (ni Tiptap, ni image, ni texte) : c'est
   strictement le moteur de manipulation physique (déplacer, redimensionner, sélectionner,
   ordonner) d'éléments positionnés librement dans un conteneur. Extrait et généralisé, sans
   changement de logique, du prototype validé prototype-canvas-composition.html (F1.5) —
   voir ce fichier pour l'historique des itérations d'ergonomie qui ont amené à ce
   comportement exact (déplacement par poignée dédiée, largeur par bords, min-height par le
   bas, coins pour les objets à ratio fixe).

   Ce fichier est chargé par plateau.html. Le moteur d'édition (ci-dessous) n'est appelé par
   rien tant que les lots suivants (C1+) ne le câblent pas dans le forum réel — aucun effet
   visible. renderComposedPost (Lot B1) EST en revanche déjà branché en lecture seule dans
   forum.js (renderTopicView) : elle ne s'active que si un post porte un content_layout non
   nul, ce qu'aucun post réel ne fait encore (rien n'écrit ce champ avant le lot E2).
   =========================================================================== */

const RP_CANVAS_MIN_WIDTH = 40;

// ===========================================================================
// Rendu LECTURE SEULE d'un post composé (Lot B1). Aucune poignée, aucune interaction —
// uniquement l'affichage. Le contenu riche de chaque zone est affiché via son html_fallback
// déjà sanitisé à l'écriture (pas de montage Tiptap ici, l'édition vient aux lots C+), et
// re-sanitisé ici même par défense en profondeur, comme le fait déjà renderTopicView pour
// p.content/p.blocks. Rendu desktop uniquement pour ce lot : largeur fixe = canvas_width,
// sans mise à l'échelle responsive ni bascule mobile — prévues au lot G1.
// ===========================================================================
function rpCanvasEscapeAttr(str) {
  return String(str || '')
    .replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function renderComposedPost(layout) {
  if (!layout || !Array.isArray(layout.elements)) return '';
  const canvasWidth = layout.canvas_width || 680;

  const elementsHtml = layout.elements.map(el => {
    const lo = el.layout || {};
    const x = lo.x || 0, y = lo.y || 0, w = lo.width || 200, z = lo.z || 1;

    if (el.type === 'text_zone') {
      const minH = lo.minHeight || 0;
      const safeHtml = typeof sanitizeRichHtml === 'function' ? sanitizeRichHtml(el.html_fallback || '') : '';
      return '<div class="rp-composed-zone" style="position:absolute;left:' + x + 'px;top:' + y + 'px;' +
        'width:' + w + 'px;min-height:' + minH + 'px;z-index:' + z + '">' + safeHtml + '</div>';
    }

    if (el.type === 'image') {
      // Même filtre que sanitizeRichHtml applique déjà aux images du forum existant.
      const src = /^https?:\/\//i.test(el.src || '') ? el.src : '';
      if (!src) return '';
      const alt = rpCanvasEscapeAttr(el.alt);
      const captionHtml = el.caption
        ? '<div class="rp-composed-caption">' + rpCanvasEscapeAttr(el.caption) + '</div>' : '';
      return '<div class="rp-composed-image" style="position:absolute;left:' + x + 'px;top:' + y + 'px;' +
        'width:' + w + 'px;z-index:' + z + '"><img src="' + src + '" alt="' + alt + '" ' +
        'style="width:100%;height:auto;display:block"/>' + captionHtml + '</div>';
    }

    return '';
  }).join('');

  return '<div class="rp-composed-canvas" style="position:relative;width:' + canvasWidth + 'px">' +
    elementsHtml + '</div>';
}

// Crée un contrôleur de composition pour UN conteneur donné (jamais un #canvas fixe global) —
// plusieurs surfaces indépendantes peuvent coexister si besoin.
function rpCanvasCreateController(container) {
  let zCounter = 10;

  // Sélection = passage au premier plan par défaut (comportement validé dans le prototype).
  // `state` est optionnel pour compatibilité, mais tous les appelants internes le passent
  // désormais (Lot C5) pour garder state.z synchronisé avec le zIndex réellement appliqué —
  // sinon la sérialisation (lot E1, à venir) n'aurait aucun moyen fiable de retrouver l'ordre
  // de superposition choisi par le joueur.
  function selectElement(el, state) {
    container.querySelectorAll('.rp-canvas-el.selected').forEach(o => {
      if (o !== el) o.classList.remove('selected');
    });
    el.classList.add('selected');
    zCounter += 1;
    el.style.zIndex = zCounter;
    if (state) state.z = zCounter;
  }

  function deselectAll() {
    container.querySelectorAll('.rp-canvas-el.selected').forEach(o => o.classList.remove('selected'));
  }

  container.addEventListener('mousedown', (e) => {
    if (e.target === container) deselectAll();
  });

  // Bornes de z parmi les objets actuellement présents dans CE conteneur — interrogées en
  // direct sur le DOM plutôt que via un registre séparé à tenir à jour, pour rester aussi
  // simple et sans état caché que le reste du moteur.
  function computeZBounds(el) {
    let min = 1, max = 1, first = true;
    const parent = el.parentElement;
    if (parent) {
      Array.from(parent.children).forEach(node => {
        if (!node.classList || !node.classList.contains('rp-canvas-el')) return;
        const z = parseInt(node.style.zIndex, 10) || 1;
        if (first) { min = z; max = z; first = false; }
        else { if (z < min) min = z; if (z > max) max = z; }
      });
    }
    return { min, max };
  }

  // Actions explicites avant-plan/arrière-plan (Lot C5) — indépendantes du geste de
  // sélection (qui continue, lui, d'amener implicitement au premier plan au clic, comme déjà
  // validé). bringToFront resynchronise aussi le compteur global de sélection, sinon un
  // simple clic sur un AUTRE objet juste après pourrait ne pas suffire à repasser devant
  // celui qu'on vient d'amener explicitement au premier plan.
  function bringToFront(state, el) {
    const { max } = computeZBounds(el);
    const newZ = Math.max(max + 1, zCounter + 1);
    zCounter = newZ;
    state.z = newZ;
    el.style.zIndex = newZ;
  }
  function sendToBack(state, el) {
    const { min } = computeZBounds(el);
    const newZ = min - 1;
    state.z = newZ;
    el.style.zIndex = newZ;
  }

  // Mini barre avant-plan/arrière-plan, visible seulement si l'objet est sélectionné (même
  // discrétion que les poignées de redimensionnement). mousedown (pas click) et
  // stopPropagation, comme les poignées de redimensionnement : sinon le mousedown remonterait
  // aussi au déplacement de l'objet entier (cas d'une image, où toute la surface sert de
  // poignée de drag).
  function attachZControls(el, state) {
    const box = document.createElement('div');
    box.className = 'rp-z-controls';
    box.contentEditable = 'false';

    const frontBtn = document.createElement('button');
    frontBtn.type = 'button';
    frontBtn.textContent = '⬆';
    frontBtn.title = 'Amener au premier plan';
    frontBtn.addEventListener('mousedown', (e) => {
      e.preventDefault();
      e.stopPropagation();
      bringToFront(state, el);
    });

    const backBtn = document.createElement('button');
    backBtn.type = 'button';
    backBtn.textContent = '⬇';
    backBtn.title = "Envoyer à l'arrière-plan";
    backBtn.addEventListener('mousedown', (e) => {
      e.preventDefault();
      e.stopPropagation();
      sendToBack(state, el);
    });

    box.appendChild(frontBtn);
    box.appendChild(backBtn);
    el.appendChild(box);
    return box;
  }

  // Déplacement générique : `handleEl` capte le geste (une poignée dédiée, ou l'élément
  // entier selon l'objet), `el` est l'élément réellement déplacé. `state` est un objet
  // { x, y, ... } tenu à jour par l'appelant.
  function attachDrag(handleEl, state, el) {
    handleEl.addEventListener('mousedown', (e) => {
      e.preventDefault();
      selectElement(el, state);
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
      selectElement(el, state);
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
      selectElement(el, state);
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
      selectElement(el, state);
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
    bringToFront, sendToBack, attachZControls,
  };
}

// ===========================================================================
// Écran de composition (Lot C1, complété au Lot C2) — point d'entrée séparé, à côté du
// bouton "Nouveau sujet" existant (jamais retiré ni modifié).
// ===========================================================================
function renderComposeCanvasForm() {
  return `
    <div class="forum-header-bar">
      <button class="forum-back-btn" onclick="backToList()">
        <i class="ti ti-arrow-left"></i> Retour
      </button>
      <div class="forum-title-main">Nouveau sujet — Composition libre (bêta)</div>
    </div>
    <div style="padding:1rem">
      <div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">
        Chantier en cours — rien n'est encore publiable depuis cet écran.
      </div>
      <div class="rp-compose-toolbar">
        <button class="forum-new-btn" onclick="rpCanvasAddTextZoneToCompose()">
          <i class="ti ti-text-plus"></i> Ajouter une zone de texte
        </button>
        <button class="forum-new-btn" onclick="rpCanvasAddImageToCompose()">
          <i class="ti ti-photo-plus"></i> Ajouter une image
        </button>
      </div>
      <div id="rp-compose-canvas" style="position:relative;width:680px;max-width:100%;min-height:500px;background:#fff;border:1px solid #2a2010"></div>
    </div>
  `;
}

// Contrôleur de la surface de composition actuellement affichée — recréé à chaque entrée
// dans l'écran (voir rpCanvasInitComposeScreen, appelée par showComposeCanvasForm dans
// forum.js après le rendu). Pas de persistance à ce lot : quitter l'écran perd son contenu,
// comme prévu (la sauvegarde arrive au lot E2).
let rpComposeController = null;

function rpCanvasInitComposeScreen() {
  const container = document.getElementById('rp-compose-canvas');
  if (!container) return;
  rpComposeController = rpCanvasCreateController(container);
}

// Largeur minimale des zones de texte : 140px, PAS le repli générique du moteur (40px,
// pensé pour les images) — signalé explicitement au lot A2, appliqué ici comme convenu.
const RP_ZONE_MIN_WIDTH = 140;

function rpCanvasAddTextZoneToCompose() {
  if (!rpComposeController) return;
  const container = document.getElementById('rp-compose-canvas');
  if (!container) return;
  rpCanvasCreateTextZone(rpComposeController, container, 40, 40, 260, '<p>Nouvelle zone de texte…</p>');
}

// Création d'une zone de texte — reprise directe de createTextZone du prototype validé
// (F1.5), câblée sur le vrai contrôleur générique (Lot A2) et sur le vrai Tiptap chargé en
// ESM (voir plateau.html, exposé en window.RP_TIPTAP_EDITOR/RP_TIPTAP_STARTER_KIT).
function rpCanvasCreateTextZone(ctrl, container, x, y, width, html) {
  if (typeof window.RP_TIPTAP_EDITOR !== 'function' || !window.RP_TIPTAP_STARTER_KIT) {
    if (typeof showToast === 'function') showToast('Chargement en cours', 'Réessayez dans un instant.', false);
    return null;
  }

  const state = { x, y, width, minHeight: 0 };
  const el = document.createElement('div');
  el.className = 'rp-canvas-el rp-zone';
  el.style.left = x + 'px';
  el.style.top = y + 'px';
  el.style.width = width + 'px';
  el.style.minHeight = state.minHeight + 'px';

  const bar = document.createElement('div');
  bar.className = 'rp-zone-bar';
  bar.textContent = '⠿';
  bar.title = 'Déplacer cette zone';
  el.appendChild(bar);

  const toolbar = document.createElement('div');
  toolbar.className = 'rp-zone-toolbar';
  toolbar.contentEditable = 'false';
  el.appendChild(toolbar);

  const content = document.createElement('div');
  content.className = 'rp-zone-content';
  el.appendChild(content);

  ['left', 'right'].forEach(side => {
    const h = document.createElement('div');
    h.className = 'rp-resize-edge ' + side;
    el.appendChild(h);
    ctrl.attachEdgeResize(h, side, state, el, { minWidth: RP_ZONE_MIN_WIDTH });
  });

  const bottomHandle = document.createElement('div');
  bottomHandle.className = 'rp-resize-bottom';
  bottomHandle.title = "Réserver de l'espace sous le texte";
  el.appendChild(bottomHandle);
  ctrl.attachBottomResize(bottomHandle, state, el, () => bar.offsetHeight + content.offsetHeight);

  container.appendChild(el);
  ctrl.bringToFront(state, el); // z explicite dès la création (Lot C5) -- le nouvel objet arrive au-dessus
  ctrl.attachZControls(el, state);
  ctrl.attachDrag(bar, state, el);

  const editor = new window.RP_TIPTAP_EDITOR({
    element: content,
    extensions: [window.RP_TIPTAP_STARTER_KIT, window.RP_TIPTAP_UNDERLINE, window.RP_TIPTAP_TEXT_STYLE, window.RP_TIPTAP_COLOR],
    content: html || '<p></p>',
    onFocus: () => ctrl.selectElement(el, state),
  });

  rpCanvasAttachZoneToolbar(toolbar, editor);

  return el;
}

// ===========================================================================
// Barre de mise en forme minimale (Lot D1) : gras/italique/souligné. Bold/Italic sont
// natifs de StarterKit ; Underline nécessite l'extension officielle séparée
// @tiptap/extension-underline (absente de StarterKit, vérifié sur le paquet réel avant
// d'implémenter -- écart signalé et validé par rapport au plan initial, qui prévoyait
// "aucune nouvelle dépendance" pour ce lot). Volontairement minimale : pas d'état "actif"
// visuel sur les boutons selon la position du curseur, cohérent avec la sobriété demandée
// pour ce premier lot de richesse éditoriale.
// ===========================================================================
function rpCanvasAttachZoneToolbar(toolbar, editor) {
  const inlineButtons = [
    { label: 'G', title: 'Gras', style: 'font-weight:700', run: () => editor.chain().focus().toggleBold().run() },
    { label: 'I', title: 'Italique', style: 'font-style:italic', run: () => editor.chain().focus().toggleItalic().run() },
    { label: 'S', title: 'Souligné', style: 'text-decoration:underline', run: () => editor.chain().focus().toggleUnderline().run() },
  ];
  // Lot D2 : titres, citations, listes -- natifs de StarterKit (Heading, Blockquote,
  // BulletList, OrderedList, ListItem tous vérifiés présents dans le paquet réel dès le
  // lot D1), aucune dépendance supplémentaire cette fois.
  const blockButtons = [
    { label: 'H2', title: 'Titre', style: 'font-weight:700;font-size:.7rem', run: () => editor.chain().focus().toggleHeading({ level: 2 }).run() },
    { label: 'H3', title: 'Sous-titre', style: 'font-weight:700;font-size:.66rem', run: () => editor.chain().focus().toggleHeading({ level: 3 }).run() },
    { label: '❝', title: 'Citation', style: '', run: () => editor.chain().focus().toggleBlockquote().run() },
    { label: '•', title: 'Liste à puces', style: 'font-weight:700', run: () => editor.chain().focus().toggleBulletList().run() },
    { label: '1.', title: 'Liste numérotée', style: 'font-size:.68rem', run: () => editor.chain().focus().toggleOrderedList().run() },
  ];

  function addButton(b) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.textContent = b.label;
    btn.title = b.title;
    btn.style.cssText = b.style;
    // mousedown : empêche le clic sur le bouton de faire perdre la sélection de texte en
    // cours AVANT que la commande ne s'applique (sinon Tiptap n'aurait plus rien à mettre
    // en forme, ou plus le bon paragraphe à transformer en titre/citation/liste, au moment
    // où la commande s'exécute).
    btn.addEventListener('mousedown', (e) => e.preventDefault());
    btn.addEventListener('click', b.run);
    toolbar.appendChild(btn);
  }

  function addSep() {
    const sep = document.createElement('span');
    sep.className = 'rp-zone-toolbar-sep';
    toolbar.appendChild(sep);
  }

  inlineButtons.forEach(addButton);
  addSep();
  blockButtons.forEach(addButton);
  addSep();
  rpCanvasAttachColorButton(toolbar, editor);
}

// Palette identique à celle déjà utilisée par le forum existant (richColor, forum.js) --
// reprise telle quelle (Lot D3), aucune nouvelle couleur inventée. Conçue à l'origine pour
// le thème sombre de l'éditeur riche existant : certaines teintes très claires (ex.
// #f0ead6, presque blanc) peuvent être peu lisibles sur le fond clair du canvas -- signalé
// ici, non corrigé, puisque la consigne est de réutiliser la palette telle quelle.
const RP_COLOR_PALETTE = [
  '#f0ead6', '#C9A84C', '#E8D880', '#cc4444', '#e08a8a', '#4a8a4a', '#7abf6a',
  '#4a6aaa', '#7a9ad0', '#aa6aaa', '#c98ac9', '#d08a3a', '#8a8060', '#5a5040', '#000000',
];

function rpCanvasAttachColorButton(toolbar, editor) {
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.textContent = 'A';
  btn.title = 'Couleur du texte';
  btn.style.cssText = 'color:#C9A84C;font-weight:700';
  btn.addEventListener('mousedown', (e) => e.preventDefault());

  let panel = null;
  function closePanel() { if (panel) { panel.remove(); panel = null; } }

  btn.addEventListener('click', () => {
    if (panel) { closePanel(); return; }
    panel = document.createElement('div');
    panel.className = 'rp-color-panel';
    panel.contentEditable = 'false';
    RP_COLOR_PALETTE.forEach(c => {
      const swatch = document.createElement('button');
      swatch.type = 'button';
      swatch.style.background = c;
      swatch.title = c;
      swatch.addEventListener('mousedown', (e) => e.preventDefault());
      swatch.addEventListener('click', () => {
        editor.chain().focus().setColor(c).run();
        closePanel();
      });
      panel.appendChild(swatch);
    });
    toolbar.appendChild(panel);
  });

  toolbar.appendChild(btn);
}

// ===========================================================================
// Objet image (Lot C4) — reprise directe de createImage/startCornerResize du prototype
// validé (F1.5). Aucune validation d'URL côté saisie, par cohérence avec le comportement
// déjà existant du forum (confirmerRichInsertImage n'en fait pas non plus) : le filtre
// ^https?:// s'applique déjà à la lecture dans renderComposedPost (Lot B1), qui reste le
// vrai rempart au moment de la sauvegarde/l'affichage à d'autres joueurs.
// ===========================================================================
function rpCanvasAddImageToCompose() {
  if (!rpComposeController) return;
  const container = document.getElementById('rp-compose-canvas');
  if (!container) return;
  const url = window.prompt("URL de l'image à ajouter (https://...) :");
  if (!url || !url.trim()) return;
  rpCanvasCreateImage(rpComposeController, container, 60, 60, 220, url.trim());
}

function rpCanvasCreateImage(ctrl, container, x, y, width, src) {
  const state = { x, y, width, height: width * 0.75 };
  const el = document.createElement('div');
  el.className = 'rp-canvas-el rp-image';
  el.style.left = x + 'px';
  el.style.top = y + 'px';
  el.style.width = width + 'px';
  el.style.height = state.height + 'px';

  const img = document.createElement('img');
  img.src = src;
  img.draggable = false; // le navigateur ne doit jamais démarrer son propre drag natif
  img.addEventListener('load', () => {
    const aspect = img.naturalHeight / img.naturalWidth;
    state.height = state.width * aspect;
    el.style.height = state.height + 'px';
  });
  img.addEventListener('error', () => {
    if (typeof showToast === 'function') showToast('Image introuvable', "L'URL indiquée ne charge aucune image.", false);
    el.remove();
  });
  el.appendChild(img);

  ['nw', 'ne', 'sw', 'se'].forEach(corner => {
    const h = document.createElement('div');
    h.className = 'rp-resize-corner ' + corner;
    el.appendChild(h);
    ctrl.attachCornerResize(h, corner, state, el); // minWidth par défaut (40), comme le prototype pour les images
  });

  container.appendChild(el);
  ctrl.bringToFront(state, el); // z explicite dès la création (Lot C5) -- le nouvel objet arrive au-dessus
  ctrl.attachZControls(el, state);
  // L'image entière sert de poignée de déplacement — pas de texte éditable à l'intérieur,
  // donc aucun conflit possible entre "saisir" et "écrire" (même raisonnement que le prototype).
  ctrl.attachDrag(el, state, el);

  return el;
}
