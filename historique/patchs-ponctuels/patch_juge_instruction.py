#!/usr/bin/env python3
PATH = "plateau-enigme-portrait.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function enigme1AfficherPopupCadreVide(roomId) {"""
new = """// =====================
// GREFFE — demande d'audience au juge (Juge Fontaine, deja presente au Tribunal)
// =====================

function doDemanderJugeInstruction() {
  const dossier = (state.char && state.char.enigme1 && state.char.enigme1.dossier) || {};
  const clesArchives = ['mairie', 'commissariat', 'notaire', 'presse'];
  const clesEhpad = ['ehpad_dubois', 'ehpad_chevillard', 'ehpad_chauchay'];
  const archivesOk = clesArchives.every(function(c) { return !!dossier[c]; });
  const ehpadOk = clesEhpad.every(function(c) { return !!dossier[c]; });
  const toutOk = archivesOk && ehpadOk;

  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.05em;margin-bottom:.6rem">Juge Fontaine</div>';

  if (toutOk) {
    if (state.char.enigme1 && !state.char.enigme1.autorisationCoffre) {
      state.char.enigme1.autorisationCoffre = true;
      if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(function() {});
    }
    html += '<div style="font-size:.88rem;color:#e0d8c0;line-height:1.5">« Votre dossier est solide, et le témoignage des anciens confère à cette affaire un poids que je ne peux ignorer. J\\'autorise l\\'ouverture du coffre lié à la succession de Pierre Thibault, à la Banque Nationale de Républia. Le greffier vous remettra l\\'autorisation nécessaire. »</div>';
  } else if (archivesOk && !ehpadOk) {
    html += '<div style="font-size:.88rem;color:#e0d8c0;line-height:1.5">« C\\'est très intéressant... mais des documents seuls ne suffisent pas toujours. Avez-vous des témoins de l\\'époque ? Il ne doit pas en rester beaucoup aujourd\\'hui... mais ceux qui restent se souviennent parfois de choses qu\\'aucune archive ne consigne. »</div>';
  } else {
    html += '<div style="font-size:.88rem;color:#e0d8c0;line-height:1.5">« C\\'est très intéressant, mais il vous manque des éléments pour déclencher une enquête. »</div>';
  }
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = "Greffe — Demande d'audience";
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function enigme1AfficherPopupCadreVide(roomId) {"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Système du juge d'instruction créé (via Juge Fontaine, au Greffe).")
