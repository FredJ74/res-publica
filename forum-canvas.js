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

// Fond de zone de texte (lot de finitions, après I) : petite palette fixe de couleurs sobres,
// semi-transparentes (rgba, jamais opaques -- le fond ne doit jamais masquer totalement le
// canvas derrière la zone). '' = transparent, comportement par défaut inchangé. Uniquement le
// FOND est concerné : jamais de CSS `opacity` sur la zone entière, qui rendrait aussi le texte
// transparent -- exigence explicite du plan. RP_ZONE_BG_SAFE_RE valide strictement le format
// à la lecture (renderComposedPost) et à la désérialisation (rpCanvasDeserializeIntoCompose) :
// bgColor vient de content_layout, une donnée stockée relue depuis la base, potentiellement
// modifiée hors du client officiel -- même défense en profondeur que le reste du pipeline
// (src d'image filtré par ^https?://, html_fallback repassé par sanitizeRichHtml, etc.).
const RP_ZONE_BG_PALETTE = [
  { label: 'Transparent (par défaut)', value: '' },
  { label: 'Parchemin', value: 'rgba(232,224,204,0.55)' },
  { label: 'Gris sobre', value: 'rgba(120,120,120,0.18)' },
  { label: 'Or discret', value: 'rgba(201,168,76,0.15)' },
  { label: 'Ardoise', value: 'rgba(58,90,120,0.14)' },
];
const RP_ZONE_BG_SAFE_RE = /^rgba\(\d{1,3},\d{1,3},\d{1,3},(0|1|0?\.\d+)\)$/;

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

  // Hauteur du canvas (correctif rendu, après E3) : ses enfants sont tous en position:absolute
  // (voir plus bas) -- selon les règles CSS standard, un enfant absolu ne contribue PAS à la
  // hauteur d'un conteneur en flux normal. Sans ce calcul explicite, .rp-composed-canvas avait
  // une hauteur quasi nulle alors que son contenu s'affichait visuellement bien plus bas. Ce
  // n'est ni un fond, ni une bordure, ni une ombre qui causait la rupture visible signalée :
  // .rp-composed-canvas n'en a jamais eu (aucune règle CSS ne le concerne). La rupture venait
  // du conteneur englobant du post (.forum-post, qui a bien un fond défini) dont la boîte
  // s'arrêtait à cette hauteur quasi nulle, exposant le fond normal de la page juste en dessous
  // -- exactement à la limite du canvas. contentHeight (zones) et height (images) sont des
  // mesures réelles capturées à la sauvegarde (voir rpCanvasSerializeCompose, correctif du
  // même lot) ; repli sur minHeight/une estimation par défaut pour d'éventuels posts composés
  // avant ce correctif, qui n'ont pas encore ces deux champs.
  const canvasHeight = layout.elements.reduce((max, el) => {
    const lo = el.layout || {};
    const y = lo.y || 0;
    let h = 0;
    if (el.type === 'text_zone') h = Math.max(lo.minHeight || 0, lo.contentHeight || 0);
    else if (el.type === 'image') h = lo.height || Math.round((lo.width || 200) * 0.75);
    return Math.max(max, y + h);
  }, 0);

  const elementsHtml = layout.elements.map(el => {
    const lo = el.layout || {};
    const x = lo.x || 0, y = lo.y || 0, w = lo.width || 200, z = lo.z || 1;

    if (el.type === 'text_zone') {
      const minH = lo.minHeight || 0;
      const safeHtml = typeof sanitizeRichHtml === 'function' ? sanitizeRichHtml(el.html_fallback || '') : '';
      // Fond de zone (lot de finitions) : validé strictement avant interpolation dans le HTML
      // -- une valeur hors de ce format précis (rgba(...) uniquement) est silencieusement
      // ignorée plutôt qu'insérée telle quelle dans l'attribut style.
      const bg = RP_ZONE_BG_SAFE_RE.test(el.bgColor || '') ? 'background-color:' + el.bgColor + ';' : '';
      return '<div class="rp-composed-zone" style="position:absolute;left:' + x + 'px;top:' + y + 'px;' +
        'width:' + w + 'px;min-height:' + minH + 'px;z-index:' + z + ';' + bg + '">' + safeHtml + '</div>';
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

  // background/border/box-shadow explicitement neutres (et non simplement omis) : le canvas
  // doit se fondre totalement dans le corps du message, sans aucune différence visuelle avec
  // le fond normal du post -- comportement par défaut demandé ; un futur choix de couleur de
  // fond par l'auteur n'est PAS implémenté ici.
  return '<div class="rp-composed-canvas" style="position:relative;width:' + canvasWidth + 'px;' +
    'min-height:' + canvasHeight + 'px;background:transparent;border:none;box-shadow:none">' +
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

  // Resynchronise le compteur interne de z sans toucher au DOM (Lot E3) -- nécessaire quand
  // un z est restauré directement depuis une valeur sauvegardée (désérialisation d'un post
  // composé existant) plutôt qu'attribué par bringToFront/selectElement : sans ça, zCounter
  // resterait bloqué à sa valeur de départ (10) et un simple clic dans un élément restauré
  // (qui appelle selectElement, lequel fait `zCounter+=1; el.style.zIndex=zCounter`, sans
  // relire le DOM contrairement à bringToFront) pourrait lui attribuer un z inférieur à
  // celui d'autres éléments restaurés, inversant silencieusement l'ordre de superposition
  // voulu. N'affecte que ce compteur privé, aucun effet visuel immédiat.
  function syncZCounter(z) {
    if (typeof z === 'number' && z > zCounter) zCounter = z;
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
    bringToFront, sendToBack, attachZControls, syncZCounter,
  };
}

// ===========================================================================
// Écran de composition (Lot C1, complété au Lot C2) — depuis le lot de finitions post-I,
// chemin normal et unique de création d'un sujet (le bouton "Nouveau sujet" historique,
// qui ouvrait renderNewTopicForm/l'éditeur classique, a été retiré de renderTopicList ;
// son code reste intact dans forum.js -- non supprimé -- car encore nécessaire à la lecture
// et à la modification des sujets créés avant la bascule).
// ===========================================================================
function renderComposeCanvasForm() {
  // Mode édition (Lot E3) : editingTopicId/editingPostId posés par editPost() (forum.js)
  // avant d'entrer dans cet écran. Pas de champ Titre (le titre du sujet n'est jamais
  // modifiable depuis un post, même règle que renderEditPostForm côté éditeur classique) ;
  // "Retour" annule vers le sujet plutôt que la liste ; le bouton principal indique
  // "Enregistrer les modifications" au lieu de "Publier le sujet" -- même bouton, même appel
  // à submitComposeCanvas(), aucune logique dupliquée.
  const enEdition = typeof editingTopicId !== 'undefined' && typeof editingPostId !== 'undefined'
    && editingTopicId != null && editingPostId != null;
  return `
    <div class="forum-header-bar">
      <button class="forum-back-btn" onclick="${enEdition ? 'backToTopic()' : 'backToList()'}">
        <i class="ti ti-arrow-left"></i> ${enEdition ? 'Annuler' : 'Retour'}
      </button>
      <div class="forum-title-main">${enEdition ? 'Modifier le message' : 'Nouveau sujet'}</div>
    </div>
    <div style="padding:1rem">
      ${enEdition ? '' : `
      <div class="forum-field">
        <label class="forum-field-label">Titre du sujet</label>
        <input class="forum-field-input" id="compose-canvas-title" type="text" placeholder="Intitulé du sujet..."/>
      </div>`}
      <div class="rp-compose-toolbar" id="rp-compose-toolbar">
        <div id="rp-compose-add-buttons" class="rp-compose-btn-group">
          <button class="forum-new-btn" onclick="rpCanvasAddTextZoneToCompose()">
            <i class="ti ti-text-plus"></i> Ajouter une zone de texte
          </button>
          <button class="forum-new-btn" onclick="rpCanvasAddImageToCompose()">
            <i class="ti ti-photo-plus"></i> Ajouter une image
          </button>
        </div>
        <div class="rp-compose-btn-group">
          <button class="forum-new-btn" id="rp-compose-preview-btn" onclick="rpCanvasTogglePreview()">
            <i class="ti ti-eye"></i> Prévisualiser
          </button>
          <button class="forum-submit-btn" onclick="submitComposeCanvas()">
            <i class="ti ti-send"></i> ${enEdition ? 'Enregistrer les modifications' : 'Publier le sujet'}
          </button>
        </div>
      </div>
      <!-- Fond du canvas (lot de finitions) : gris chaud clair sobre plutôt que blanc pur --
           évite l'effet feuille blanche agressive à côté du reste du forum, tout en restant
           un fond clair (le texte des zones -- .rp-zone-content, style.css -- est en gris
           foncé #222, pensé pour un fond clair, pas pour la charte sombre générale du jeu). -->
      <div id="rp-compose-canvas" style="position:relative;width:680px;max-width:100%;min-height:500px;background:#e8e0cc;border:1px solid #2a2010"></div>
      <div id="rp-compose-preview" style="display:none;width:680px;max-width:100%;border:1px dashed #8a6a20;padding:.5rem 0"></div>
    </div>
  `;
}

// Contrôleur de la surface de composition actuellement affichée — recréé à chaque entrée
// dans l'écran (voir rpCanvasInitComposeScreen, appelée par showComposeCanvasForm dans
// forum.js après le rendu). Pas de persistance à ce lot : quitter l'écran perd son contenu,
// comme prévu (la sauvegarde arrive au lot E2).
let rpComposeController = null;

// Registre des objets vivants de l'écran de composition (Lot E1) -- { type, el, state,
// editor? }, un état par objet, réutilisant directement les mêmes objets `state` déjà tenus
// à jour par le moteur générique (x/y/width/z/minHeight, voir rpCanvasCreateController) :
// aucune duplication d'état, la sérialisation lit directement la même source de vérité que
// l'affichage. Recréé à chaque entrée dans l'écran, comme rpComposeController.
let rpComposeElements = [];

function rpCanvasInitComposeScreen() {
  const container = document.getElementById('rp-compose-canvas');
  if (!container) return;
  rpComposeController = rpCanvasCreateController(container);
  rpComposeElements = [];
  // Écran fraîchement rendu (renderComposeCanvasForm) : le canvas est visible et la
  // prévisualisation masquée par défaut dans le HTML généré -- resynchronise l'état de
  // bascule en conséquence (Lot E1.5), sinon une entrée répétée dans l'écran de composition
  // laisserait le bouton afficher "Revenir à l'édition" à tort.
  rpComposeEnPreview = false;

  // Édition d'un post composé existant (Lot E3) : editingTopicId/editingPostId sont posés
  // par editPost() (forum.js) avant d'entrer dans cet écran -- et explicitement remis à null
  // par showComposeCanvasForm() pour une NOUVELLE composition, afin qu'une session d'édition
  // précédente ne "fuite" jamais dans un nouveau sujet. editingTopicId/editingPostId sont des
  // variables de forum.js, visibles ici car les deux fichiers sont des scripts classiques
  // partageant le même contexte global (même principe déjà en place pour EMOJI_CATS, lot D7).
  if (editingTopicId != null && editingPostId != null) {
    const topic = (typeof FORUM_TOPICS !== 'undefined' ? (FORUM_TOPICS[currentForumId] || []) : []).find(t => t.id === editingTopicId);
    const post = topic ? (topic.posts.find(p => (p.id || '') === editingPostId) || topic.posts[parseInt(editingPostId)]) : null;
    if (post && post.content_layout) {
      rpCanvasDeserializeIntoCompose(post.content_layout, container);
    }
  }
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
function rpCanvasCreateTextZone(ctrl, container, x, y, width, html, bgColor) {
  if (typeof window.RP_TIPTAP_EDITOR !== 'function' || !window.RP_TIPTAP_STARTER_KIT) {
    if (typeof showToast === 'function') showToast('Chargement en cours', 'Réessayez dans un instant.', false);
    return null;
  }

  const state = { x, y, width, minHeight: 0, bgColor: bgColor || '' };
  const el = document.createElement('div');
  el.className = 'rp-canvas-el rp-zone';
  el.style.left = x + 'px';
  el.style.top = y + 'px';
  el.style.width = width + 'px';
  el.style.minHeight = state.minHeight + 'px';
  // Uniquement le fond -- jamais `opacity`, qui ferait aussi disparaître le texte.
  if (state.bgColor) el.style.backgroundColor = state.bgColor;

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
  const zBox = ctrl.attachZControls(el, state);
  ctrl.attachDrag(bar, state, el);

  const editor = new window.RP_TIPTAP_EDITOR({
    element: content,
    extensions: [
      window.RP_TIPTAP_STARTER_KIT, window.RP_TIPTAP_UNDERLINE, window.RP_TIPTAP_TEXT_STYLE,
      window.RP_TIPTAP_COLOR, window.RP_TIPTAP_FONT_FAMILY, window.RP_TIPTAP_FONT_SIZE,
      window.RP_TIPTAP_TEXT_ALIGN,
      window.RP_TIPTAP_LINK, window.RP_TIPTAP_DETAILS, window.RP_TIPTAP_DETAILS_SUMMARY,
      window.RP_TIPTAP_DETAILS_CONTENT,
    ],
    content: html || '<p></p>',
    onFocus: () => ctrl.selectElement(el, state),
  });

  rpCanvasAttachZoneToolbar(toolbar, editor);
  rpCanvasAttachZoneBgButton(toolbar, el, state);

  rpComposeElements.push({ type: 'text_zone', el, state, editor });

  // Duplication / suppression (Lot F1) : ajoutées à la même mini-barre que les contrôles de
  // superposition (attachZControls, lot C5) -- zBox est le conteneur déjà créé et positionné
  // par le moteur générique, pas une nouvelle barre. Le décalage +20px évite de superposer
  // exactement la copie sur l'original ; le contenu est dupliqué via editor.getHTML() (état
  // actuel réel, pas le html de création) dans une TOUTE NOUVELLE instance Tiptap
  // (rpCanvasCreateTextZone recrée systématiquement son propre éditeur) -- indépendance
  // totale garantie par construction, aucune référence partagée entre l'original et la copie.
  if (zBox) {
    const dupBtn = document.createElement('button');
    dupBtn.type = 'button';
    dupBtn.textContent = '⧉';
    dupBtn.title = 'Dupliquer cette zone';
    dupBtn.addEventListener('mousedown', (e) => {
      e.preventDefault();
      e.stopPropagation();
      const newEl = rpCanvasCreateTextZone(ctrl, container, state.x + 20, state.y + 20, state.width, editor.getHTML(), state.bgColor);
      if (!newEl) return;
      const newEntry = rpComposeElements[rpComposeElements.length - 1];
      if (newEntry && newEntry.el === newEl) {
        // minHeight n'est pas un paramètre de création -- repris explicitement ici, comme le
        // fait déjà rpCanvasDeserializeIntoCompose (lot E3) pour la même raison.
        newEntry.state.minHeight = state.minHeight;
        newEl.style.minHeight = state.minHeight + 'px';
      }
    });

    const delBtn = document.createElement('button');
    delBtn.type = 'button';
    delBtn.textContent = '🗑';
    delBtn.title = 'Supprimer cette zone';
    delBtn.addEventListener('mousedown', (e) => {
      e.preventDefault();
      e.stopPropagation();
      // Reprise du principe déjà en place pour la suppression d'un message
      // (confirmerSuppressionPost, forum.js) : action irréversible, confirmation requise.
      if (!window.confirm('Supprimer cette zone de texte ? Cette action est irréversible.')) return;
      rpCanvasDeleteElement(el);
    });

    zBox.appendChild(dupBtn);
    zBox.appendChild(delBtn);
  }

  return el;
}

// Suppression (Lot F1) — générique aux deux types d'objets (zone de texte ou image) : ne
// s'appuie que sur `el`/`editor`, retrouve l'entrée correspondante dans le registre
// (rpComposeElements, lot E1), détruit l'instance Tiptap si elle existe (editor.destroy(),
// méthode réelle vérifiée dans le code source de @tiptap/core avant implémentation --
// libère proprement la vue ProseMirror et ses écouteurs), retire l'élément du DOM, puis
// retire l'entrée du registre. Aucune trace résiduelle : ni dans le DOM, ni dans l'état de
// composition, ni dans une instance Tiptap orpheline.
function rpCanvasDeleteElement(el) {
  const idx = rpComposeElements.findIndex((entry) => entry.el === el);
  if (idx === -1) return;
  const entry = rpComposeElements[idx];
  if (entry.editor && typeof entry.editor.destroy === 'function') entry.editor.destroy();
  if (entry.el && typeof entry.el.remove === 'function') entry.el.remove();
  rpComposeElements.splice(idx, 1);
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
  // Alignement (lot de finitions, après I) : extension officielle TextAlign (plateau.html),
  // gauche/centre/droite uniquement -- justify n'est pas exposé, conformément à la consigne.
  const alignButtons = [
    { label: 'Ga', title: 'Aligner à gauche', style: 'font-size:.66rem', run: () => editor.chain().focus().setTextAlign('left').run() },
    { label: 'Ce', title: 'Centrer', style: 'font-size:.66rem', run: () => editor.chain().focus().setTextAlign('center').run() },
    { label: 'Dr', title: 'Aligner à droite', style: 'font-size:.66rem', run: () => editor.chain().focus().setTextAlign('right').run() },
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
  alignButtons.forEach(addButton);
  addSep();
  rpCanvasAttachColorButton(toolbar, editor);
  addSep();
  rpCanvasAttachSizeSelect(toolbar, editor);
  rpCanvasAttachFontSelect(toolbar, editor);
  addSep();
  rpCanvasAttachLinkButton(toolbar, editor);
  rpCanvasAttachSpoilerButton(toolbar, editor);
  addSep();
  rpCanvasAttachEmojiButton(toolbar, editor);
}

// Lien (Lot D5, corrigé D6-fix) : demande l'URL par window.prompt, même mécanisme déjà
// utilisé pour les images (rpCanvasAddImageToCompose). Double vérification volontaire : un
// retour immédiat à la saisie via le même filtre ^https?://, EN PLUS du filtre équivalent
// déjà configuré sur l'extension elle-même (isAllowedUri, voir plateau.html) qui refuserait
// de toute façon la commande -- la vérification ici n'est qu'un message d'erreur plus clair,
// pas le vrai rempart de sécurité (qui reste l'extension + la sanitisation à la lecture,
// lot B1).
// Ergonomie corrigée (audit du 14/08) : Link est une marque (Mark) standard -- vérifié dans
// le code source réel de @tiptap/extension-link@2.27.2 -- setLink() appelle en interne
// setMark(), dont le comportement natif (vérifié dans @tiptap/core) gère déjà les deux
// usages demandés sans code supplémentaire : sur une sélection non vide, il n'habille QUE le
// texte sélectionné ; sur une sélection vide (curseur seul), il pose une "stored mark" qui
// s'applique à la frappe suivante -- c'est le mécanisme natif de la "balise ouverte avant
// d'écrire". Pour refermer/retirer, unsetMark('link') SANS extendEmptyMarkRange (vérifié
// dans le code source réel de @tiptap/core, fonction unsetMark) gère nativement les deux
// autres usages : sélection vide -- ne retire que la marque en cours de frappe (le texte
// déjà tapé reste un lien, "terminer le lien") ; sélection non vide -- retire la marque du
// texte sélectionné, qui redevient normal sans être supprimé ("retirer un lien existant" :
// sélectionner son texte, puis recliquer).
function rpCanvasAttachLinkButton(toolbar, editor) {
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.textContent = '🔗';
  btn.title = 'Lien (sélection, ou balise ouverte avant la frappe -- recliquer pour terminer/retirer)';
  btn.addEventListener('mousedown', (e) => e.preventDefault());
  btn.addEventListener('click', () => {
    if (editor.isActive('link')) {
      editor.chain().focus().unsetMark('link').run();
      return;
    }
    const url = window.prompt("Adresse du lien (https://...) :");
    if (!url || !url.trim()) return;
    const trimmed = url.trim();
    if (!/^https?:\/\//i.test(trimmed)) {
      if (typeof showToast === 'function') showToast('Lien refusé', 'Seules les adresses http:// ou https:// sont autorisées.', false);
      return;
    }
    editor.chain().focus().setLink({ href: trimmed }).run();
  });
  toolbar.appendChild(btn);
}

// Spoiler (Lot D6, corrigé -- modèle BBCode [spoiler]...[/spoiler]) : Details reste un
// noeud de type "block" (content: "detailsSummary detailsContent", group:"block" --
// vérifié dans le code source réel de @tiptap/extension-details@2.27.2), il ne peut donc
// pas se comporter comme une simple marque inline. Sa commande native setDetails()
// enveloppe tout le bloc englobant (blockRange), pas seulement la sélection réelle : c'est
// le défaut signalé au premier passage. La commande ci-dessous construit donc directement
// le noeud details via insertContentAt() -- le mécanisme que setDetails() natif utilise
// lui-même en interne, vérifié dans son code source -- mais borné à la sélection réelle.
// ProseMirror scinde alors automatiquement le paragraphe autour du noeud de bloc inséré
// (comportement standard d'un replace avec un contenu de bloc à l'intérieur d'un texte,
// pas une manipulation DOM). Aucun calcul manuel de position de curseur pour la création :
// insertContentAt() place déjà par défaut la sélection à la fin du contenu inséré (option
// updateSelection, vérifiée à true par défaut dans le code source réel de @tiptap/core).
//
// Second clic pendant qu'on est dans un spoiler -- deux usages distincts, désambiguïsés par
// la présence ou non d'une sélection (même logique que le bouton Lien) :
// - sélection vide (curseur seul) = "fermeture" façon [/spoiler] : sort du spoiler sans le
//   modifier ni le supprimer, la frappe suivante est hors spoiler. Aucune commande officielle
//   ne fait exactement cela (l'unique mécanisme natif d'évasion est le raccourci clavier
//   Entrée de DetailsContent, vérifié dans son code source, mais il exige d'être sur un
//   paragraphe final déjà vide -- trop restrictif pour un clic de bouton explicite). Implémenté
//   ci-dessous avec les primitives de position ProseMirror déjà utilisées par l'extension
//   elle-même en interne ($pos.after(depth), insertContentAt, setTextSelection) : pas de
//   manipulation DOM.
// - sélection non vide = retrait complet du spoiler (unsetDetails, commande officielle --
//   remonte le contenu du spoiler en texte normal à la même place, contenu conservé).
function rpCanvasExitSpoiler(editor) {
  const { state } = editor;
  const { $from } = state.selection;
  let depth = null;
  for (let d = $from.depth; d > 0; d -= 1) {
    if ($from.node(d).type.name === 'details') { depth = d; break; }
  }
  if (depth === null) return;
  const after = $from.after(depth);
  const nodeAfter = state.doc.nodeAt(after);
  if (nodeAfter && nodeAfter.isTextblock) {
    editor.chain().focus().setTextSelection(after + 1).run();
  } else {
    editor.chain().focus().insertContentAt(after, { type: 'paragraph' }).run();
  }
}

function rpCanvasAttachSpoilerButton(toolbar, editor) {
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.textContent = '👁';
  btn.title = 'Spoiler (sélection, ou balise ouverte avant la frappe -- recliquer pour fermer/retirer)';
  btn.addEventListener('mousedown', (e) => e.preventDefault());
  btn.addEventListener('click', () => {
    if (editor.isActive('details')) {
      if (editor.state.selection.empty) {
        rpCanvasExitSpoiler(editor);
      } else {
        editor.chain().focus().unsetDetails().run();
      }
      return;
    }
    const { state } = editor;
    const { $from, $to, empty, from, to } = state.selection;
    if (empty) {
      // Balise ouverte avant la frappe : nouveau spoiler VIDE inséré exactement à la
      // position du curseur, quel que soit le texte environnant dans le paragraphe.
      editor.chain().focus().insertContentAt(from, {
        type: 'details',
        content: [
          { type: 'detailsSummary' },
          { type: 'detailsContent', content: [{ type: 'paragraph' }] },
        ],
      }).run();
      return;
    }
    if ($from.sameParent($to) && $from.parent.isTextblock) {
      // Sélection à l'intérieur d'un seul paragraphe : seule la portion sélectionnée migre
      // dans le spoiler, le reste du paragraphe (avant/après) est préservé tel quel.
      const inline = state.doc.slice(from, to).toJSON()?.content || [];
      editor.chain().focus().insertContentAt({ from, to }, {
        type: 'details',
        content: [
          { type: 'detailsSummary' },
          { type: 'detailsContent', content: [{ type: 'paragraph', content: inline }] },
        ],
      }).run();
      return;
    }
    // Repli : sélection à cheval sur plusieurs blocs (cas rare, non couvert par la demande
    // explicite) -- comportement d'origine, enveloppe le ou les blocs entiers concernés.
    // Limitation connue et consignée, pas une régression silencieuse.
    editor.chain().focus().setDetails().run();
  });
  toolbar.appendChild(btn);
}

// Smileys (Lot D7) : réutilise directement EMOJI_CATS (défini dans forum.js, chargé dans
// le même contexte global classique -- forum-canvas.js et forum.js ne sont pas des modules,
// donc les déclarations de haut niveau de l'un sont visibles dans l'autre, exactement comme
// showToast() déjà référencé plus haut) -- aucun contenu nouveau, conforme au plan. Insertion
// via editor.chain().insertContent(...), l'équivalent Tiptap de document.execCommand
// ('insertText'/'insertHTML') utilisé par l'éditeur contenteditable existant
// (richInsertEmoji/richInsertSep dans forum.js) ; insertContent() délègue en interne à
// insertContentAt() sur la sélection courante (vérifié dans le code source réel de
// @tiptap/core), donc un emoji tapé sur une sélection existante la remplace, comme n'importe
// quelle frappe normale.
// Simplification volontaire, périmètre strictement D7 : les entrées "séparateur" (chaînes de
// plus de 4 caractères, même critère de longueur que l'existant) sont insérées comme texte
// brut, sans l'habillage visuel centré du <div> que l'éditeur existant leur applique --
// reproduire cet habillage demanderait soit une extension Tiptap TextAlign absente du
// périmètre, soit d'injecter du HTML brut hors du modèle de noeuds Tiptap. Non traité ici,
// à reconsidérer si demandé séparément.
// Panneau propre à chaque zone (pas d'ID global partagé comme #emoji-grid dans l'éditeur
// existant, où une seule instance existe à la fois) : plusieurs zones peuvent avoir leur
// panneau ouvert simultanément sans collision.
function rpCanvasAttachEmojiButton(toolbar, editor) {
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.textContent = '😊';
  btn.title = 'Emojis & symboles';
  btn.addEventListener('mousedown', (e) => e.preventDefault());

  let panel = null;
  function closePanel() { if (panel) { panel.remove(); panel = null; } }

  function renderGrid(grid, cat) {
    grid.innerHTML = '';
    EMOJI_CATS[cat].forEach((entry) => {
      const item = document.createElement('button');
      item.type = 'button';
      item.textContent = entry;
      item.className = entry.length > 4 ? 'rp-emoji-sep' : 'rp-emoji-glyph';
      item.addEventListener('mousedown', (e) => e.preventDefault());
      item.addEventListener('click', () => {
        editor.chain().focus().insertContent(entry).run();
        closePanel();
      });
      grid.appendChild(item);
    });
  }

  btn.addEventListener('click', () => {
    if (panel) { closePanel(); return; }
    panel = document.createElement('div');
    panel.className = 'rp-emoji-panel';
    panel.contentEditable = 'false';

    const cats = document.createElement('div');
    cats.className = 'rp-emoji-cats';
    panel.appendChild(cats);

    const grid = document.createElement('div');
    grid.className = 'rp-emoji-grid';
    panel.appendChild(grid);

    const catNames = Object.keys(EMOJI_CATS);
    catNames.forEach((cat, i) => {
      const catBtn = document.createElement('button');
      catBtn.type = 'button';
      catBtn.textContent = cat;
      catBtn.className = 'rp-emoji-cat-btn' + (i === 0 ? ' is-active' : '');
      catBtn.addEventListener('mousedown', (e) => e.preventDefault());
      catBtn.addEventListener('click', () => {
        cats.querySelectorAll('.rp-emoji-cat-btn').forEach((b) => b.classList.remove('is-active'));
        catBtn.classList.add('is-active');
        renderGrid(grid, cat);
      });
      cats.appendChild(catBtn);
    });

    renderGrid(grid, catNames[0]);
    toolbar.appendChild(panel);
  });

  toolbar.appendChild(btn);
}

// Tailles bornées (Lot D4) : exactement les paliers ci-dessous sont atteignables depuis
// l'interface -- aucune saisie libre nulle part, donc structurellement impossible d'obtenir
// une valeur hors liste par ce chemin (mark personnalisé fontSize, voir plateau.html).
const RP_FONT_SIZES = [
  { label: 'Petit', value: '.8em' },
  { label: 'Normal', value: '1em' },
  { label: 'Grand', value: '1.3em' },
  { label: 'Très grand', value: '1.6em' },
];

function rpCanvasAttachSizeSelect(toolbar, editor) {
  const select = document.createElement('select');
  select.className = 'rp-zone-toolbar-select';
  select.title = 'Taille du texte';
  RP_FONT_SIZES.forEach(s => {
    const opt = document.createElement('option');
    opt.value = s.value;
    opt.textContent = s.label;
    if (s.value === '1em') opt.selected = true;
    select.appendChild(opt);
  });
  select.addEventListener('mousedown', (e) => e.stopPropagation());
  select.addEventListener('change', () => {
    editor.chain().focus().setFontSize(select.value).run();
  });
  toolbar.appendChild(select);
}

// Polices bornées (Lot D4) : liste blanche volontairement réduite à des polices déjà
// chargées ailleurs dans le jeu (voir le <link> Google Fonts de plateau.html) -- cohérent
// avec l'identité visuelle existante, et n'ajoute aucune requête de police supplémentaire.
const RP_FONT_FAMILIES = [
  { label: 'Georgia (par défaut)', value: 'Georgia, serif' },
  { label: 'Crimson Pro', value: "'Crimson Pro', serif" },
  { label: 'Playfair Display', value: "'Playfair Display', serif" },
  { label: 'Bebas Neue', value: "'Bebas Neue', sans-serif" },
  // Lot D5 : 5e police ajoutée à la demande, écriture calligraphique -- chargée en plus des
  // 4 déjà présentes (nouvel ajout au <link> Google Fonts de plateau.html, contrairement aux
  // 4 précédentes qui réutilisaient des polices déjà chargées ailleurs dans le jeu).
  { label: 'Great Vibes', value: "'Great Vibes', cursive" },
];

function rpCanvasAttachFontSelect(toolbar, editor) {
  const select = document.createElement('select');
  select.className = 'rp-zone-toolbar-select';
  select.title = 'Police';
  RP_FONT_FAMILIES.forEach(f => {
    const opt = document.createElement('option');
    opt.value = f.value;
    opt.textContent = f.label;
    select.appendChild(opt);
  });
  select.addEventListener('mousedown', (e) => e.stopPropagation());
  select.addEventListener('change', () => {
    editor.chain().focus().setFontFamily(select.value).run();
  });
  toolbar.appendChild(select);
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

// Fond de la zone (lot de finitions, après I) — propriété de la zone elle-même (state.bgColor),
// pas une marque Tiptap : bouton séparé de rpCanvasAttachZoneToolbar (formatage du texte),
// mais posé sur la même barre. Réutilise le même panneau .rp-color-panel (style.css) que
// rpCanvasAttachColorButton pour rester cohérent visuellement, avec une petite palette dédiée
// (RP_ZONE_BG_PALETTE, sobre, semi-transparente) distincte de la palette de couleur de texte.
function rpCanvasAttachZoneBgButton(toolbar, el, state) {
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.textContent = '▦';
  btn.title = 'Fond de la zone';
  btn.addEventListener('mousedown', (e) => e.preventDefault());

  let panel = null;
  function closePanel() { if (panel) { panel.remove(); panel = null; } }

  btn.addEventListener('click', () => {
    if (panel) { closePanel(); return; }
    panel = document.createElement('div');
    panel.className = 'rp-color-panel';
    panel.contentEditable = 'false';
    RP_ZONE_BG_PALETTE.forEach(opt => {
      const swatch = document.createElement('button');
      swatch.type = 'button';
      // Une valeur vide (transparent) n'a pas de couleur CSS unie représentative -- damier
      // sobre, reconnaissable, uniquement pour ce swatch-là.
      swatch.style.background = opt.value || 'repeating-conic-gradient(#ccc 0% 25%, #fff 0% 50%) 0 0/10px 10px';
      swatch.title = opt.label;
      swatch.addEventListener('mousedown', (e) => e.preventDefault());
      swatch.addEventListener('click', () => {
        state.bgColor = opt.value;
        // Uniquement le fond -- jamais `opacity`, qui ferait aussi disparaître le texte.
        el.style.backgroundColor = opt.value || 'transparent';
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
    // L'objet est retiré du DOM : le retirer aussi du registre de sérialisation (Lot E1),
    // sinon une entrée fantôme (élément détaché) subsisterait dans rpComposeElements.
    rpComposeElements = rpComposeElements.filter((entry) => entry.el !== el);
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
  const zBox = ctrl.attachZControls(el, state);
  // L'image entière sert de poignée de déplacement — pas de texte éditable à l'intérieur,
  // donc aucun conflit possible entre "saisir" et "écrire" (même raisonnement que le prototype).
  ctrl.attachDrag(el, state, el);

  rpComposeElements.push({ type: 'image', el, state });

  // Duplication / suppression (Lot F1) : même mini-barre que les contrôles de superposition
  // (attachZControls, lot C5), même principe que pour les zones de texte ci-dessus. La copie
  // recharge le même src dans un tout nouvel élément <img> (rpCanvasCreateImage recrée
  // systématiquement son propre état et recalcule sa hauteur au chargement) -- indépendance
  // totale garantie par construction, aucune référence partagée avec l'original.
  if (zBox) {
    const dupBtn = document.createElement('button');
    dupBtn.type = 'button';
    dupBtn.textContent = '⧉';
    dupBtn.title = 'Dupliquer cette image';
    dupBtn.addEventListener('mousedown', (e) => {
      e.preventDefault();
      e.stopPropagation();
      rpCanvasCreateImage(ctrl, container, state.x + 20, state.y + 20, state.width, src);
    });

    const delBtn = document.createElement('button');
    delBtn.type = 'button';
    delBtn.textContent = '🗑';
    delBtn.title = 'Supprimer cette image';
    delBtn.addEventListener('mousedown', (e) => {
      e.preventDefault();
      e.stopPropagation();
      // Reprise du principe déjà en place pour la suppression d'un message
      // (confirmerSuppressionPost, forum.js) : action irréversible, confirmation requise.
      if (!window.confirm('Supprimer cette image ? Cette action est irréversible.')) return;
      rpCanvasDeleteElement(el);
    });

    zBox.appendChild(dupBtn);
    zBox.appendChild(delBtn);
  }

  return el;
}

// ===========================================================================
// Sérialisation (Lot E1) — canvas vivant -> content_layout conforme au schéma déjà consommé
// par renderComposedPost (Lot B1). Fonction pure au sens où elle ne modifie ni le DOM ni les
// instances Tiptap : elle ne fait que LIRE le registre rpComposeElements, qui référence
// directement les mêmes objets `state` que le moteur générique tient déjà à jour (aucune
// duplication d'état à maintenir en parallèle).
//
// canvas_width = 680 : la largeur réelle, fixe, du conteneur #rp-compose-canvas
// (renderComposeCanvasForm) -- exactement la même valeur que le repli par défaut déjà
// utilisé par renderComposedPost (layout.canvas_width || 680), donc déjà cohérente avec la
// lecture réelle sans avoir besoin de la lire dynamiquement du DOM.
//
// reading_order : ordre de création (index dans rpComposeElements), conformément à la règle
// par défaut déjà prévue pour le lot F2 ("pas d'interface de réordonnancement manuel dans ce
// premier lot"). F2 n'existant pas encore, ce lot n'invente pas de mécanisme d'identifiants
// au-delà de cet ordre simple -- à faire évoluer par F2 si un besoin de réordonnancement
// manuel ou de suppression/duplication le justifie.
//
// html_fallback de chaque zone de texte : editor.getHTML() passé par sanitizeRichHtml, dont
// la liste blanche a été étendue dans ce même lot (DETAILS/SUMMARY, font-family, target/rel
// sur les liens) pour couvrir tout ce que la Phase D a introduit -- sans cette extension, un
// spoiler ou une police choisie disparaîtrait silencieusement à la sérialisation.
function rpCanvasSerializeCompose() {
  const elements = rpComposeElements.map((entry) => {
    const state = entry.state;
    const layout = { x: state.x || 0, y: state.y || 0, width: state.width || 0, z: state.z || 1 };

    if (entry.type === 'text_zone') {
      layout.minHeight = state.minHeight || 0;
      // Hauteur réellement mesurée du contenu (correctif rendu, après E3) : .rp-zone-content
      // est un DIV en flux normal à l'intérieur de la zone (seule la zone elle-même, .rp-zone,
      // est positionnée en absolute) -- son scrollHeight reflète donc fidèlement la hauteur
      // réelle du texte tel qu'il s'affiche au moment de la sauvegarde, y compris quand
      // minHeight est resté à 0 (zone jamais redimensionnée manuellement, cas courant). Sert
      // uniquement au calcul de la hauteur du canvas en lecture (renderComposedPost) -- ignoré
      // partout ailleurs, notamment par la désérialisation (E3), qui laisse le vrai Tiptap
      // live recalculer sa propre hauteur normalement.
      const contentEl = entry.el && typeof entry.el.querySelector === 'function' ? entry.el.querySelector('.rp-zone-content') : null;
      if (contentEl) layout.contentHeight = contentEl.scrollHeight || 0;
      const rawHtml = entry.editor ? entry.editor.getHTML() : '';
      const html_fallback = typeof sanitizeRichHtml === 'function' ? sanitizeRichHtml(rawHtml) : '';
      // Fond de zone (lot de finitions) : propriété visuelle de la zone, pas géométrique --
      // au même niveau que html_fallback, pas dans layout (réservé aux propriétés de position/
      // taille). Revalidé au format strict (RP_ZONE_BG_SAFE_RE) avant d'être sauvegardé : une
      // valeur qui ne vient pas de la palette (ne devrait jamais arriver via l'UI) n'est pas
      // persistée.
      const bgColor = RP_ZONE_BG_SAFE_RE.test(state.bgColor || '') ? state.bgColor : '';
      return { type: 'text_zone', html_fallback, bgColor, layout };
    }

    if (entry.type === 'image') {
      const img = entry.el.querySelector('img');
      // state.height est déjà la hauteur réelle (ratio de l'image chargée, recalculée par
      // rpCanvasCreateImage dès que l'image charge) -- la sérialiser permet à
      // renderComposedPost (lecture, DOM-free) de connaître la vraie hauteur sans avoir à la
      // deviner (voir correctif rendu ci-dessous).
      layout.height = Math.round(state.height || 0);
      return {
        type: 'image',
        src: img ? img.src : '',
        alt: img ? (img.alt || '') : '', // aucune saisie d'alt/légende dans l'interface à ce
        caption: '',                     // stade (lot C4) -- dette consignée, hors périmètre E1
        layout,
      };
    }

    return null;
  }).filter(Boolean);

  return {
    canvas_width: 680,
    elements,
    reading_order: elements.map((_, i) => i),
  };
}

// Fallback HTML "à plat" (Lot E1) — concaténation, dans l'ordre de reading_order, du
// html_fallback de chaque zone et d'un <img> simple pour chaque image ; destiné aux
// surfaces qui ne comprennent pas content_layout (aperçus de liste, notifications...),
// jamais à renderComposedPost qui lit content_layout directement. Ne re-sanitise pas
// html_fallback : il vient d'être produit par rpCanvasSerializeCompose() dans le même appel,
// déjà passé par sanitizeRichHtml -- contrairement à renderComposedPost, qui doit se méfier
// d'un content_layout relu depuis la base et donc re-sanitise par défense en profondeur.
function rpCanvasBuildFallbackContent(layout) {
  if (!layout || !Array.isArray(layout.elements)) return '';
  const order = Array.isArray(layout.reading_order) && layout.reading_order.length
    ? layout.reading_order
    : layout.elements.map((_, i) => i);

  return order.map((i) => {
    const el = layout.elements[i];
    if (!el) return '';
    if (el.type === 'text_zone') return el.html_fallback || '';
    if (el.type === 'image') {
      const src = /^https?:\/\//i.test(el.src || '') ? el.src : '';
      if (!src) return '';
      return '<img src="' + src + '" alt="' + rpCanvasEscapeAttr(el.alt) + '"/>';
    }
    return '';
  }).join('');
}

// ===========================================================================
// Désérialisation (Lot E3) — sens inverse de rpCanvasSerializeCompose() : content_layout
// existant -> canvas vivant (éléments DOM + une instance Tiptap par zone), pour la réouverture
// d'un post composé déjà publié. Réutilise directement rpCanvasCreateTextZone/
// rpCanvasCreateImage (Lots C2/C4, inchangées) pour la création elle-même -- ce sont déjà les
// seules fonctions qui savent construire un élément vivant correctement câblé (moteur
// générique, registre, Tiptap) ; cette fonction ne fait que les appeler avec les valeurs
// sauvegardées puis restaurer ce qu'elles ne peuvent pas déjà connaître à la création
// (min-height et z proviennent du layout sauvegardé, pas d'une valeur par défaut).
//
// html_fallback (déjà passé par sanitizeRichHtml à la sauvegarde, liste blanche étendue au
// lot E1 pour couvrir exactement ce que les extensions Tiptap actives produisent) est fourni
// tel quel comme contenu initial de l'éditeur -- son propre parseHTML() (StarterKit, Color/
// TextStyle, Link, Details/Summary/Content, etc., les mêmes extensions qui ont servi à le
// générer) le reconvertit fidèlement en document Tiptap, sans étape de conversion
// supplémentaire à écrire ici.
//
// z restauré à la valeur exacte sauvegardée puis synchronisé avec syncZCounter() (ajout
// minimal à rpCanvasCreateController, lot E3) : sans cette resynchronisation, une simple
// sélection (clic dans une zone restaurée) pourrait plus tard lui attribuer un z inférieur à
// celui d'un autre élément restauré et inverser silencieusement l'ordre de superposition
// voulu -- bringToFront()/sendToBack() n'ont pas ce problème (ils relisent déjà le DOM à
// chaque appel), seule la sélection implicite (selectElement) incrémente son propre compteur
// interne sans le faire.
function rpCanvasDeserializeIntoCompose(layout, container) {
  if (!layout || !Array.isArray(layout.elements) || !rpComposeController) return;

  layout.elements.forEach((el) => {
    if (!el) return;
    const lo = el.layout || {};
    const x = lo.x || 0, y = lo.y || 0, width = lo.width || (el.type === 'image' ? 100 : RP_ZONE_MIN_WIDTH);
    const z = lo.z || 1;

    if (el.type === 'text_zone') {
      // Fond de zone (lot de finitions) : revalidé au même format strict qu'à la lecture --
      // défense en profondeur, content_layout est une donnée stockée relue depuis la base.
      const bgColor = RP_ZONE_BG_SAFE_RE.test(el.bgColor || '') ? el.bgColor : '';
      const domEl = rpCanvasCreateTextZone(rpComposeController, container, x, y, width, el.html_fallback || '<p></p>', bgColor);
      if (!domEl) return;
      const entry = rpComposeElements[rpComposeElements.length - 1];
      if (!entry || entry.el !== domEl) return;
      const minHeight = lo.minHeight || 0;
      entry.state.minHeight = minHeight;
      domEl.style.minHeight = minHeight + 'px';
      entry.state.z = z;
      domEl.style.zIndex = z;
      rpComposeController.syncZCounter(z);
      return;
    }

    if (el.type === 'image') {
      const src = /^https?:\/\//i.test(el.src || '') ? el.src : '';
      if (!src) return;
      const domEl = rpCanvasCreateImage(rpComposeController, container, x, y, width, src);
      if (!domEl) return;
      const entry = rpComposeElements[rpComposeElements.length - 1];
      if (!entry || entry.el !== domEl) return;
      entry.state.z = z;
      domEl.style.zIndex = z;
      rpComposeController.syncZCounter(z);
      // alt restauré tel quel (déjà présent dans le schéma depuis E1, aucune saisie possible
      // dans l'interface aujourd'hui -- dette déjà consignée, voir rapport E1) : ne rien
      // perdre de ce qui existe, sans ajouter de champ de saisie ici (hors périmètre E3).
      if (el.alt) {
        const img = domEl.querySelector('img');
        if (img) img.alt = el.alt;
      }
      return;
    }
  });
}

// ===========================================================================
// Prévisualisation (Lot E1.5) — bascule d'affichage pure, jamais une reconstruction. Le
// canvas d'édition (#rp-compose-canvas, ses éléments DOM, ses instances Tiptap par zone) et
// son registre (rpComposeElements) ne sont JAMAIS touchés par ce lot : ils sont seulement
// masqués (display:none) pendant la prévisualisation, puis réaffichés tels quels. C'est ce
// qui garantit par construction qu'aucun état (texte, mise en forme, position, taille,
// min-height, z, ordre) ne peut se perdre, et qu'un nombre illimité d'allers-retours est
// possible sans jamais repasser par une désérialisation (qui n'existera qu'au lot E3, pour
// la réouverture d'un post déjà publié).
//
// Le rendu affiché est produit par renderComposedPost() (Lot B1), très exactement le même
// renderer que celui déjà branché en lecture réelle dans forum.js (renderTopicView) --
// aucune fonction de prévisualisation séparée n'a été écrite. Le HTML produit est enveloppé
// dans un <div class="forum-post-content">, la même classe CSS que le vrai rendu d'un post
// dans le fil de discussion (style.css), pour que la typographie du texte corresponde à ce
// qu'un lecteur verra réellement -- sans dupliquer cette règle CSS ici. La largeur (680px)
// vient de layout.canvas_width, produit par rpCanvasSerializeCompose() (Lot E1) avec la
// même valeur que le repli par défaut déjà utilisé par renderComposedPost -- c'est
// exactement la largeur réelle du canvas de composition, donc déjà celle qu'aura le post
// publié.
//
// Liens et spoilers : le HTML produit par renderComposedPost() sort de sanitizeRichHtml(),
// dont la liste blanche a été étendue au lot E1 pour laisser passer <details>/<summary>
// (spoilers) et href/target/rel sur <a> (liens) intacts -- ce sont donc de vrais éléments
// HTML natifs dans la prévisualisation (un <a href> cliquable, un <details> nativement
// repliable/dépliable par le navigateur), pas une imitation : aucun JavaScript de repli/
// dépli ou de gestion de clic n'est nécessaire ni présent ici.
let rpComposeEnPreview = false;

function rpCanvasTogglePreview() {
  const canvasEl = document.getElementById('rp-compose-canvas');
  const addButtonsEl = document.getElementById('rp-compose-add-buttons');
  const previewEl = document.getElementById('rp-compose-preview');
  const btn = document.getElementById('rp-compose-preview-btn');
  if (!canvasEl || !addButtonsEl || !previewEl || !btn) return;

  if (rpComposeEnPreview) {
    // Retour à l'édition : le canvas vivant n'a jamais été touché, on le réaffiche tel quel.
    previewEl.style.display = 'none';
    previewEl.innerHTML = '';
    canvasEl.style.display = '';
    addButtonsEl.style.display = '';
    btn.innerHTML = '<i class="ti ti-eye"></i> Prévisualiser';
    rpComposeEnPreview = false;
    return;
  }

  // "Ajouter une zone de texte" / "Ajouter une image" sont eux aussi des contrôles
  // d'édition -- masqués pendant la prévisualisation, contrairement au bouton
  // Prévisualiser/Revenir lui-même, qui reste le seul contrôle visible (nécessaire pour
  // revenir à l'édition).
  const layout = rpCanvasSerializeCompose();
  const html = renderComposedPost(layout);
  previewEl.innerHTML = '<div class="forum-post-content">' + html + '</div>';
  canvasEl.style.display = 'none';
  addButtonsEl.style.display = 'none';
  previewEl.style.display = 'block';
  btn.innerHTML = '<i class="ti ti-arrow-back-up"></i> Revenir à l\'édition';
  rpComposeEnPreview = true;
}
