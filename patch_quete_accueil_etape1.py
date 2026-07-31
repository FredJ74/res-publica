#!/usr/bin/env python3
"""
Patch quete d'accueil - etape 1 (le garde presidentiel).
A executer a la racine du repo res-publica.
"""
import re

# --- 1. supabase.js ---
PATH_SB = "supabase.js"
with open(PATH_SB, "r", encoding="utf-8") as f:
    sb = f.read()

old_save = """    signature_html:   charState.char?.signatureHtml || null,
    signature_blocks: charState.char?.signatureBlocks || [],
    updated_at:       new Date().toISOString()"""
new_save = """    signature_html:   charState.char?.signatureHtml || null,
    signature_blocks: charState.char?.signatureBlocks || [],
    quete_accueil:    charState.char?.queteAccueil || null,
    updated_at:       new Date().toISOString()"""
assert sb.count(old_save) == 1, f"supabase.js (save) : trouvé {sb.count(old_save)} fois (attendu 1)"
sb = sb.replace(old_save, new_save)

old_load = """             signatureHtml: r.signature_html || null, signatureBlocks: r.signature_blocks || [] },"""
new_load = """             signatureHtml: r.signature_html || null, signatureBlocks: r.signature_blocks || [],
             queteAccueil: r.quete_accueil || null },"""
assert sb.count(old_load) == 1, f"supabase.js (load) : trouvé {sb.count(old_load)} fois (attendu 1)"
sb = sb.replace(old_load, new_load)

with open(PATH_SB, "w", encoding="utf-8") as f:
    f.write(sb)

# --- 2. plateau.html ---
PATH_HTML = "plateau.html"
with open(PATH_HTML, "r", encoding="utf-8") as f:
    html = f.read()

old_html_anchor = """<!-- MODAL FICHE PERSONNAGE -->"""
new_html_block = """<!-- MODAL QUETE D'ACCUEIL -->
<div id="modal-quete-accueil" class="modal-overlay">
  <div class="modal-box">
    <div class="modal-header">
      <div class="modal-title" id="quete-accueil-titre">...</div>
      <button class="modal-close" id="quete-accueil-close"><i class="ti ti-x"></i></button>
    </div>
    <div id="quete-accueil-body">
      <img id="quete-accueil-image" src="" style="width:100%;border-radius:8px;margin-bottom:.6rem;display:none" />
      <div class="pnj-speech" id="quete-accueil-texte"></div>
    </div>
  </div>
</div>

<!-- MODAL FICHE PERSONNAGE -->"""
assert html.count(old_html_anchor) == 1, f"plateau.html (modale) : trouvé {html.count(old_html_anchor)} fois (attendu 1)"
html = html.replace(old_html_anchor, new_html_block)

script_pattern = re.compile(r'<script src="plateau-rue-centrale\.js\?v=\d+"></script>')
matches = script_pattern.findall(html)
assert len(matches) == 1, f"plateau.html (script tag rue-centrale) : trouvé {len(matches)} fois (attendu 1)"
old_script_anchor = matches[0]
new_script_block = old_script_anchor + '\n<script src="plateau-quete-accueil.js?v=1"></script>'
html = html.replace(old_script_anchor, new_script_block)

with open(PATH_HTML, "w", encoding="utf-8") as f:
    f.write(html)

# --- 3. plateau-rue-centrale.js ---
PATH_RC = "plateau-rue-centrale.js"
with open(PATH_RC, "r", encoding="utf-8") as f:
    rc = f.read()

old_hook = """  if (typeof state !== 'undefined' && state.currentCity) {
    memoriserNoeudRueCentrale(pays, state.currentCity, noeudId);
  }

  const conteneur = document.getElementById('rue-centrale-conteneur');"""
new_hook = """  if (typeof state !== 'undefined' && state.currentCity) {
    memoriserNoeudRueCentrale(pays, state.currentCity, noeudId);
  }

  if (typeof queteAccueilDoitDemarrer === 'function' && queteAccueilDoitDemarrer(pays, noeudId)) {
    demarrerQueteAccueil();
  }

  const conteneur = document.getElementById('rue-centrale-conteneur');"""
assert rc.count(old_hook) == 1, f"plateau-rue-centrale.js : trouvé {rc.count(old_hook)} fois (attendu 1)"
rc = rc.replace(old_hook, new_hook)

with open(PATH_RC, "w", encoding="utf-8") as f:
    f.write(rc)

# --- 4. plateau-quete-accueil.js (nouveau fichier) ---
PATH_QA = "plateau-quete-accueil.js"
qa_content = """// plateau-quete-accueil.js
// Systeme de quete d'accueil pour les nouveaux joueurs de Res Publica.
// Etat sauvegarde sur le personnage : state.char.queteAccueil = { etape: '...' }
// Etape 1 (ce fichier, version initiale) : dialogue du garde presidentiel a l'arrivee.

const QUETE_ACCUEIL_IMAGES = {
  gardeMenacant: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/garde-menacant-luthecia.png',
  gardeBienveillant: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/garde-bienveillant-luthecia.png'
};

function queteAccueilDoitDemarrer(pays, noeudId) {
  if (pays !== 'republic') return false;
  if (noeudId !== 'luthecia-palais-presidentiel') return false;
  if (typeof state === 'undefined' || !state.char) return false;
  if (state.char.queteAccueil && state.char.queteAccueil.etape) return false;
  return true;
}

function demarrerQueteAccueil() {
  state.char.queteAccueil = { etape: 'garde_en_cours' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.gardeMenacant,
    titre: 'Un garde presidentiel',
    texte: "Hey, vous ! Vous n'etes pas autorise a rester ici ! Le President va bientot sortir ! Et puis vous etes nouveau, on ne vous a jamais vu, je me trompe ? Allez vous presenter a l'Hotel de Ville sinon c'est au commissariat que vous finirez.",
    suivant: afficherPopupQueteAccueilEtape2
  });
}

function afficherPopupQueteAccueilEtape2() {
  afficherPopupQueteAccueil({
    image: (state.char && state.char.photoUrl) || null,
    titre: (state.char && state.char.name) || 'Vous',
    texte: "Je veux bien, mais ou est l'Hotel de Ville ?",
    suivant: afficherPopupQueteAccueilEtape3
  });
}

function afficherPopupQueteAccueilEtape3() {
  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.gardeBienveillant,
    titre: 'Le garde presidentiel',
    texte: "Continuez sur cette rue, ensuite il y aura un croisement. Continuez encore une fois sur la meme rue, et vous trouverez l'Hotel de Ville. Adressez-vous au secretaire municipal. Il vous parlera surement des impots, mais repondez-lui simplement que vous etes nouveau, cela devrait l'adoucir.",
    suivant: afficherPopupQueteAccueilEtape4
  });
}

function afficherPopupQueteAccueilEtape4() {
  afficherPopupQueteAccueil({
    image: (state.char && state.char.photoUrl) || null,
    titre: (state.char && state.char.name) || 'Vous',
    texte: "D'accord... merci...",
    suivant: terminerEtapeGardeQueteAccueil
  });
}

function terminerEtapeGardeQueteAccueil() {
  state.char.queteAccueil = { etape: 'oriente_vers_mairie' };
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
}

function afficherPopupQueteAccueil(opts) {
  const modal = document.getElementById('modal-quete-accueil');
  if (!modal) return;
  const imgEl = document.getElementById('quete-accueil-image');
  const titreEl = document.getElementById('quete-accueil-titre');
  const texteEl = document.getElementById('quete-accueil-texte');

  if (imgEl) {
    if (opts.image) { imgEl.src = opts.image; imgEl.style.display = ''; }
    else { imgEl.style.display = 'none'; }
  }
  if (titreEl) titreEl.textContent = opts.titre || '';
  if (texteEl) texteEl.textContent = opts.texte || '';

  const closeBtn = document.getElementById('quete-accueil-close');
  if (closeBtn) {
    closeBtn.onclick = function() {
      modal.classList.remove('open');
      if (typeof opts.suivant === 'function') opts.suivant();
    };
  }
  modal.classList.add('open');
}
"""
with open(PATH_QA, "w", encoding="utf-8") as f:
    f.write(qa_content)

print("✅ Patch appliqué avec succès : etape 1 de la quete d'accueil (le garde) en place.")
