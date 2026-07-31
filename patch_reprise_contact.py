#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Armer le minuteur de reprise de contact a l'entree au stade ---
old_1 = """  if (etape === 'guide_stade' && buildingId === 'stade') {"""
new_1 = """  if (etape === 'stade_libre' && buildingId === 'stade') {
    // On arme le minuteur une seule fois (passage a 'stade_libre_minuteur' pour ne pas le
    // reclencher a chaque changement de piece a l'interieur du stade).
    state.char.queteAccueil = { etape: 'stade_libre_minuteur' };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    setTimeout(function() {
      if (typeof state === 'undefined' || !state.char || !state.char.queteAccueil) return;
      if (state.char.queteAccueil.etape !== 'stade_libre_minuteur') return; // le joueur a deja avance autrement
      afficherRepriseContactJeremy();
    }, 90000);
    return;
  }

  if (etape === 'guide_stade' && buildingId === 'stade') {"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- 2. Fonctions de reprise de contact (Oui/Non, 3 destinations, ou separation) ---
old_2 = """function afficherPopupQueteAccueil(opts) {"""
new_2 = """function afficherRepriseContactJeremy() {
  state.char.queteAccueil = { etape: 'reprise_contact' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Dites, vous avez encore besoin de moi pour découvrir la ville, ou vous vous sentez de continuer seul(e) ?",
    suivant: null,
    actionsHtml:
      '<button class="pnj-action-btn" onclick="document.getElementById(\\'modal-quete-accueil\\').classList.remove(\\'open\\'); queteAccueilRepriseOui();">' +
      '<i class="ti ti-check" style="font-size:.85rem"></i> Oui, encore un peu d\\'aide</button> ' +
      '<button class="pnj-action-btn" onclick="document.getElementById(\\'modal-quete-accueil\\').classList.remove(\\'open\\'); queteAccueilRepriseNon();">' +
      '<i class="ti ti-x" style="font-size:.85rem"></i> Non merci, ça ira</button>'
  });
}

function queteAccueilRepriseOui() {
  state.char.queteAccueil = { etape: 'choix_destination' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Où voulez-vous aller ? Le marché, les terrains à bâtir, ou le centre multimodal ?",
    suivant: null,
    actionsHtml:
      '<button class="pnj-action-btn" onclick="document.getElementById(\\'modal-quete-accueil\\').classList.remove(\\'open\\'); queteAccueilDestination(\\'marche\\');">Le marché</button> ' +
      '<button class="pnj-action-btn" onclick="document.getElementById(\\'modal-quete-accueil\\').classList.remove(\\'open\\'); queteAccueilDestination(\\'terrains\\');">Les terrains à bâtir</button> ' +
      '<button class="pnj-action-btn" onclick="document.getElementById(\\'modal-quete-accueil\\').classList.remove(\\'open\\'); queteAccueilDestination(\\'multimodal\\');">Le centre multimodal</button>'
  });
}

const QUETE_ACCUEIL_TEXTES_DESTINATION = {
  marche: "Le marché ? C'est plutôt vers le centre, pas très loin d'ici. Regardez le plan si besoin, en haut à droite, ça vous montrera le chemin le plus sûr.",
  terrains: "Les terrains à bâtir sont plutôt excentrés. Consultez le plan pour vous y retrouver, c'est le plus simple.",
  multimodal: "Le centre multimodal, c'est là où vous êtes arrivé en arrivant en ville. Le plan vous montrera comment y retourner facilement."
};

function queteAccueilDestination(dest) {
  state.char.queteAccueil = { etape: 'quete_terminee_avec_aide' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: (QUETE_ACCUEIL_TEXTES_DESTINATION[dest] || QUETE_ACCUEIL_TEXTES_DESTINATION.marche) + " Si vous avez des questions en chemin, n'hésitez pas à me demander.",
    suivant: function() {
      queteAccueilSurbrillance('button[onclick*="ouvrirPlanVille"]', 12000);
    }
  });
}

function queteAccueilRepriseNon() {
  state.char.queteAccueil = { etape: 'quete_terminee_sans_aide' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  if (typeof addContactByName === 'function') {
    addContactByName('Jérémy', 'Ancien stagiaire de la Mairie', 'ally', false);
  }
  if (typeof quitterJeremy === 'function') quitterJeremy();

  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Alors nos chemins se séparent ici. Pour le moment, bien sûr ! Si vous avez besoin de moi, envoyez-moi un mail. Je vous ai ajouté à mes contacts.",
    suivant: null
  });
}

function afficherPopupQueteAccueil(opts) {"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

# --- 3. afficherPopupQueteAccueil doit maintenant gerer aussi actionsHtml ---
old_3 = """  const closeBtn = document.getElementById('quete-accueil-close');
  if (closeBtn) {
    closeBtn.onclick = function() {
      modal.classList.remove('open');
      if (typeof opts.suivant === 'function') opts.suivant();
    };
  }
  modal.classList.add('open');
}"""
new_3 = """  const actionsEl = document.getElementById('quete-accueil-actions');
  if (actionsEl) actionsEl.innerHTML = opts.actionsHtml || '';

  const closeBtn = document.getElementById('quete-accueil-close');
  if (closeBtn) {
    closeBtn.onclick = function() {
      modal.classList.remove('open');
      if (typeof opts.suivant === 'function') opts.suivant();
    };
  }
  modal.classList.add('open');
}"""
assert content.count(old_3) == 1, f"bloc 3 : trouvé {content.count(old_3)} fois (attendu 1)"
content = content.replace(old_3, new_3)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Reprise de contact de Jérémy (Oui/Non, destinations, séparation) ajoutée.")
