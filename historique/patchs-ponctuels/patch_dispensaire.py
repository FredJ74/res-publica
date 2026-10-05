#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Etendre le hook de rue : arrivee au carrefour -> guidage vers le Dispensaire ---
old_1 = """  if (etape === 'guide_sortie' && noeudId === 'luthecia-hotel-de-ville') {
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

new_1 = """  if (etape === 'guide_sortie' && noeudId === 'luthecia-hotel-de-ville') {
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

  if (etape === 'attente_gauche_dispensaire' && noeudId === 'luthecia-imprimerie') {
    state.char.queteAccueil = { etape: 'attente_entree_dispensaire' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    afficherGuidageUnBatiment('luthecia-imprimerie', 'dispensaire-public', 'Entrons ici !');
    return;
  }
}

// Variante d'afficherGuidageBatiments qui ne met en evidence qu'UN SEUL batiment cible parmi
// les zones du noeud (au lieu de nommer les 4 facades). Utilise un marqueur dore pulsant,
// comme pour les fleches de rue, plutot qu'un simple nom au-dessus de la facade.
function afficherGuidageUnBatiment(noeudId, buildingIdCible, texteAccroche) {
  const noeud = (typeof RUE_CENTRALE_NOEUDS !== 'undefined') ? RUE_CENTRALE_NOEUDS.republic?.[noeudId] : null;
  if (!noeud) return;
  const image = noeud.image;
  const zone = (noeud.zones || []).find(function(z) { return z.buildingId === buildingIdCible; });
  if (!zone) return;
  const centre = (zone.xPct[0] + zone.xPct[1]) / 2;

  const guidageHtml =
    '<img src="' + image + '" style="width:100%;display:block;filter:sepia(0.9) contrast(1.05) brightness(0.85)" />' +
    '<div style="position:absolute; top:12px; left:' + centre + '%; transform:translateX(-50%);">' +
    '<div style="width:44px;height:44px;border-radius:50%;' +
    'background:radial-gradient(circle,#f0d488,#b8860b);border:2px solid #fff8dc;' +
    'display:flex;align-items:center;justify-content:center;font-size:1.4rem;color:#241608;' +
    'box-shadow:0 0 16px 6px rgba(230,190,90,0.75);animation:queteAccueilPulse 1.4s ease-in-out infinite;">' +
    '↓</div></div>' +
    '<div style="position:absolute; top:60px; left:' + centre + '%; transform:translateX(-50%);' +
    'max-width:40%; text-align:center; font-size:.7rem; font-weight:bold; color:#f0d488;' +
    'text-shadow:0 0 4px #000, 0 0 8px #000;">' + zone.nom + '</div>';

  afficherPopupQueteAccueil({
    guidageHtml: guidageHtml,
    titre: 'Jérémy',
    texte: texteAccroche || 'Entrons ici !',
    suivant: null
  });
}
"""

assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- 2. Etendre queteAccueilVerifierEtapeBatiment : arrivee au Dispensaire -> discours + guidage fiche perso ---
old_2 = """  if (etape === 'guide_salle_elections' && buildingId === 'mairie-capitale' && roomId === 'salle_elections') {"""
new_2 = """  if (etape === 'attente_entree_dispensaire' && buildingId === 'dispensaire-public') {
    state.char.queteAccueil = { etape: 'attente_fiche_personnage' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

    afficherPopupQueteAccueil({
      image: QUETE_ACCUEIL_IMAGES.jeremy,
      titre: 'Jérémy',
      texte: "Ici c'est le dispensaire. On peut se faire soigner gratuitement, ou à moindre frais. Bien sûr, si vous êtes riche, vous pouvez aller en hôpital privé. Chaque jour, on se fatigue au travail. Il est important de se reposer en dormant. Une fois par jour seulement. Idéalement, il vaut mieux dormir dans une chambre, on récupère mieux que si on dort n'importe où.",
      suivant: function() {
        queteAccueilSurbrillance('.char-card', 15000);
      }
    });
    return;
  }

  if (etape === 'guide_salle_elections' && buildingId === 'mairie-capitale' && roomId === 'salle_elections') {"""

assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Guidage vers le Dispensaire + discours Jérémy + guidage fiche personnage ajoutés.")
