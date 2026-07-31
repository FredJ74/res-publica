#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Le popup de presentation de Jeremy enchaine maintenant sur la surbrillance de l'onglet ---
old_1 = """  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Bonjour, je suis Jérémy, le stagiaire à tout faire de ce maudit Hôtel de Ville. Je suis bien content de pouvoir vous guider, le secrétaire n'arrête pas de me demander de lui faire du café et des photocopies. On va commencer par aller dans un endroit plus calme. On va aller dans la salle des élections.",
    suivant: null
  });
}"""
new_1 = """  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Bonjour, je suis Jérémy, le stagiaire à tout faire de ce maudit Hôtel de Ville. Je suis bien content de pouvoir vous guider, le secrétaire n'arrête pas de me demander de lui faire du café et des photocopies. On va commencer par aller dans un endroit plus calme. On va aller dans la salle des élections.",
    suivant: function() {
      state.char.queteAccueil = { etape: 'guide_salle_elections' };
      if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
      queteAccueilSurbrillance('.piece-tab[onclick*="salle_elections"]', 12000);
    }
  });
}

// =====================
// GUIDAGE SUR DE VRAIS ELEMENTS D'INTERFACE (surbrillance doree, pas une image)
// =====================

// Ajoute une surbrillance doree pulsante sur le(s) element(s) correspondant au selecteur,
// pendant la duree donnee (ou 10s par defaut). Utilise pour les boutons reels de l'interface
// (onglets de piece, bouton Sortir...) plutot que l'image sepia utilisee pour la rue.
function queteAccueilSurbrillance(selector, dureeMs) {
  const els = document.querySelectorAll(selector);
  if (!els.length) return;
  els.forEach(function(el) { el.classList.add('quete-accueil-surbrillance'); });
  setTimeout(function() {
    els.forEach(function(el) { el.classList.remove('quete-accueil-surbrillance'); });
  }, dureeMs || 10000);
}

// Declenche depuis le hook ajoute dans enterRoom() (plateau-navigation.js).
function queteAccueilVerifierEtapeBatiment(buildingId, roomId) {
  if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
  const etape = state.char.queteAccueil.etape;

  if (etape === 'guide_salle_elections' && buildingId === 'mairie-capitale' && roomId === 'salle_elections') {
    state.char.queteAccueil = { etape: 'guide_sortie' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Ici on sera tranquille, en plus le responsable électoral est malentendant. Ici on est au cœur du système électoral car c'est ici qu'on vote. On peut aussi voir qui est candidat aux élections par exemple. Chaque pièce est dédiée à un usage.",
      suivant: function() {
        afficherPopupQueteAccueil({
          image: QUETE_ACCUEIL_IMAGES.jeremy,
          titre: 'Jérémy',
          texte: "À présent, on va aller en ville. On va déjà sortir de l'Hôtel de Ville.",
          suivant: function() {
            queteAccueilSurbrillance('.sortir-btn', 12000);
          }
        });
      }
    });
  }
}
"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- 2. Etendre le hook de rue pour la sortie de l'HDV ---
old_2 = """  if (etape === 'guide_hdv' && noeudId === 'luthecia-hotel-de-ville') {
    state.char.queteAccueil = { etape: 'attente_entree_mairie' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    afficherGuidageBatiments('luthecia-hotel-de-ville');
    return;
  }
}"""
new_2 = """  if (etape === 'guide_hdv' && noeudId === 'luthecia-hotel-de-ville') {
    state.char.queteAccueil = { etape: 'attente_entree_mairie' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    afficherGuidageBatiments('luthecia-hotel-de-ville');
    return;
  }

  if (etape === 'guide_sortie' && noeudId === 'luthecia-hotel-de-ville') {
    // Point d'arret de cette session de codage : la suite (aller a gauche vers le Dispensaire)
    // sera codee a la prochaine etape.
    state.char.queteAccueil = { etape: 'attente_gauche_dispensaire' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Allons sur la gauche, j'ai quelque chose à vous montrer.",
      suivant: null
    });
    return;
  }
}"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

# --- 3. CSS de surbrillance, ajoute au style deja injecte ---
old_3 = """  style.textContent = '@keyframes queteAccueilPulse { 0%,100% { transform:scale(1); } 50% { transform:scale(1.15); } }' +
    '#quete-accueil-guidage div[style*="border-radius:50%"] { transform-origin:center; }';"""
new_3 = """  style.textContent = '@keyframes queteAccueilPulse { 0%,100% { transform:scale(1); } 50% { transform:scale(1.15); } }' +
    '#quete-accueil-guidage div[style*="border-radius:50%"] { transform-origin:center; }' +
    '.quete-accueil-surbrillance { outline:3px solid #e6c34a !important; box-shadow:0 0 14px 4px rgba(230,195,74,0.85) !important; border-radius:6px; animation:queteAccueilPulseBtn 1.2s ease-in-out infinite; }' +
    '@keyframes queteAccueilPulseBtn { 0%,100% { box-shadow:0 0 10px 2px rgba(230,195,74,0.6); } 50% { box-shadow:0 0 22px 8px rgba(230,195,74,0.95); } }';"""
assert content.count(old_3) == 1, f"bloc 3 : trouvé {content.count(old_3)} fois (attendu 1)"
content = content.replace(old_3, new_3)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Guidage Salle des Élections + Sortir ajouté à plateau-quete-accueil.js.")
