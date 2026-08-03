#!/usr/bin/env python3
PATH = "plateau-enigme-portrait.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function enigme1AfficherPopupCadreVide(roomId) {"""
new = """// =====================
// DEBARRAS DU MUSEE — ouverture par la cle, revelation de Gerard Poincon
// =====================

function enigme1APossessionCle() {
  return typeof state !== 'undefined' && state.inventory &&
    state.inventory.some(function(it) { return it.id === 'cle-debarras-musee'; });
}

// Appelee depuis le hook d'entree en piece (enterRoom, plateau-navigation.js).
function enigme1VerifierDebarras(buildingId, roomId) {
  if (buildingId !== 'musee-ville-luthecia' || roomId !== 'debarras') return;
  if (!state.char) return;

  if (!enigme1APossessionCle()) {
    if (typeof showToast === 'function') showToast('Verrouillé', "Cette porte est fermée à clé.", false);
    return;
  }

  if (!state.char.enigme1) return;
  if (state.char.enigme1.debarrasOuvert) return; // deja ouvert, revelation deja vue

  state.char.enigme1.debarrasOuvert = true;
  state.char.enigme1.etape = 'resolue';
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(function() {});
  enigme1AfficherRevelationGerard();
}

function enigme1AfficherRevelationGerard() {
  let html = '<div style="padding:1.2rem">';
  html += '<img src="https://raw.githubusercontent.com/FredJ74/res-publica/main/images/gerard-poincon-gardien-musee.png" style="width:100%;border-radius:4px;margin-bottom:.9rem;display:block;max-height:260px;object-fit:cover"/>';
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.05em;margin-bottom:.6rem">Gérard Poinçon</div>';
  html += '<div style="font-size:.88rem;color:#e0d8c0;line-height:1.6">';
  html += "Ah. Vous avez trouvé la clé. Je m'en doutais qu'un jour, quelqu'un finirait par comprendre.<br><br>";
  html += "Mon arrière-grand-père, Pierre Thibault, a été spolié de sa terre par des hommes que cette ville honore encore aujourd'hui. Torcieu, Moulin, Caillon, Tintabin — chacun à sa manière, ils y ont participé.<br><br>";
  html += "Je n'ai pas retiré ces portraits pour les détruire. Je voulais simplement que quelqu'un, un jour, s'interroge sur leur présence ici.";
  html += '</div>';
  html += '<div style="margin-top:1rem;padding-top:1rem;border-top:1px solid #2a2010;font-size:.9rem;color:#C9A84C;font-style:italic;line-height:1.6">« Vous savez maintenant pourquoi j\\'ai retiré ces portraits...<br>...mais vous ne savez toujours pas pourquoi ils ont été accrochés. »</div>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Le Débarras';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function enigme1AfficherPopupCadreVide(roomId) {"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Débarras créé : verrouillé sans la clé, révélation de Gérard Poinçon à l'ouverture.")
