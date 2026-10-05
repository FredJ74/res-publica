#!/usr/bin/env python3
PATH = "plateau-enigme-portrait.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function enigme1AfficherRevelationGerard() {
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
}"""

new = """// Revelation en 3 temps : 1) les 4 tableaux, 2) la porte se referme / Gerard apparait
// (tension), 3) le dialogue complet.
function enigme1AfficherRevelationGerard() {
  let html = '<div style="padding:1.2rem">';
  html += '<img src="https://raw.githubusercontent.com/FredJ74/res-publica/main/images/debarras-tableaux-musee.png" style="width:100%;border-radius:4px;margin-bottom:.9rem;display:block;max-height:280px;object-fit:cover"/>';
  html += '<div style="font-size:.88rem;color:#e0d8c0;line-height:1.6;font-style:italic;text-align:center">Les quatre portraits disparus sont là, appuyés contre le mur du débarras, comme oubliés.</div>';
  html += '<button class="pnj-action-btn" onclick="enigme1RevelationEtape2()" style="margin-top:1rem">Continuer</button>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Le Débarras';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function enigme1RevelationEtape2() {
  let html = '<div style="padding:1.2rem;text-align:center">';
  html += '<div style="font-size:.9rem;color:#cc6644;line-height:1.6;font-style:italic;margin-bottom:1rem">La porte se referme derrière vous, dans un bruit sec.</div>';
  html += '<img src="https://raw.githubusercontent.com/FredJ74/res-publica/main/images/gerard-poincon-gardien-musee.png" style="width:100%;border-radius:4px;margin-bottom:.9rem;display:block;max-height:260px;object-fit:cover"/>';
  html += '<div style="font-size:.88rem;color:#e0d8c0;line-height:1.6">Gérard Poinçon se tient là, immobile, vous observant.</div>';
  html += '<button class="pnj-action-btn" onclick="enigme1RevelationEtape3()" style="margin-top:1rem">Continuer</button>';
  html += '</div>';

  document.getElementById('postes-body').innerHTML = html;
}

function enigme1RevelationEtape3() {
  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.05em;margin-bottom:.6rem">Gérard Poinçon</div>';
  html += '<div style="font-size:.88rem;color:#e0d8c0;line-height:1.6">';
  html += "Je savais bien qu'un jour quelqu'un trouverait cette clé...<br><br>";
  html += "Mon arrière-grand-père, Pierre Thibault, a été spolié de sa terre par des hommes que cette ville honore encore aujourd'hui. Torcieu, Moulin, Caillon, Tintabin — chacun à sa manière, ils y ont participé.<br><br>";
  html += "Je n'ai pas retiré ces portraits pour les détruire. Je voulais simplement que quelqu'un, un jour, s'interroge sur leur présence ici.";
  html += '</div>';
  html += '<div style="margin-top:1rem;padding-top:1rem;border-top:1px solid #2a2010;font-size:.9rem;color:#C9A84C;font-style:italic;line-height:1.6">« Vous savez maintenant pourquoi j\\'ai retiré ces portraits...<br>...mais vous ne savez toujours pas pourquoi ils ont été accrochés. »</div>';
  html += '</div>';

  document.getElementById('postes-body').innerHTML = html;
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Révélation en 3 temps créée (tableaux, tension, dialogue).")
