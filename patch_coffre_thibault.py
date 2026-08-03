#!/usr/bin/env python3
PATH = "plateau-enigme-portrait.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function enigme1AfficherPopupCadreVide(roomId) {"""
new = """// =====================
// BANQUE NATIONALE — coffre lie a la succession de Pierre Thibault
// =====================

function doPresenterAutorisationCoffre() {
  const autorise = state.char && state.char.enigme1 && state.char.enigme1.autorisationCoffre;

  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.05em;margin-bottom:.6rem">Directeur Mercier</div>';

  if (!autorise) {
    html += '<div style="font-size:.88rem;color:#e0d8c0;line-height:1.5">« Je suis navré, mais sans une autorisation en bonne et due forme, je ne peux rien vous dire sur un quelconque coffre. »</div>';
  } else if (state.char.enigme1.coffreOuvert) {
    html += '<div style="font-size:.88rem;color:#e0d8c0;line-height:1.5">« Le coffre a déjà été ouvert, il n\\'y a plus rien à y trouver. »</div>';
  } else {
    html += '<div style="font-size:.88rem;color:#e0d8c0;line-height:1.5">« Voyons... oui, effectivement, un coffre lié à cette succession existe toujours, et sa location est réglée à ce jour. Mais je ne peux vous révéler l\\'identité de son locataire actuel — secret bancaire oblige. Voici son contenu, puisque le juge en a autorisé l\\'ouverture. »</div>';

    state.char.enigme1.coffreOuvert = true;
    if (!state.inventory) state.inventory = [];
    state.inventory.push({
      id: 'cle-debarras-musee',
      name: 'Clé du débarras',
      icon: 'ti-key',
      desc: "Une vieille clé, retrouvée dans un coffre lié à la succession de Pierre Thibault. Elle semble correspondre à une porte du Musée de la Ville de Luthécia."
    });
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(function() {});
    if (typeof updateUI === 'function') updateUI();
    if (typeof renderInventory === 'function') renderInventory();
    if (typeof showToast === 'function') showToast('Clé obtenue', 'Une clé mystérieuse a été ajoutée à votre inventaire.', true);
  }
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Banque Nationale — Coffre';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function enigme1AfficherPopupCadreVide(roomId) {"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Coffre de la succession Thibault créé (Directeur Mercier, révèle la clé du débarras).")
