#!/usr/bin/env python3
PATH = "plateau-enigme-portrait.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function enigme1AfficherMandat(nomMaire) {
  const m = ENIGME1_REGISTRE_MANDATS.find(function(x) { return x.nom === nomMaire; });
  if (!m) return;

  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.05em;margin-bottom:.2rem">' + m.nom + ' — Maire de Luthécia (' + m.debut + '–' + m.fin + ')</div>';
  html += '<div style="font-size:.82rem;color:#8a8060;margin-bottom:.8rem">Recensement des grands chantiers et actes majeurs de son mandat :</div>';
  html += '<div style="display:flex;flex-direction:column;gap:.4rem">';
  m.actes.forEach(function(ligne) {
    html += '<div style="font-size:.85rem;color:#e0d8c0;line-height:1.4">• ' + ligne + '</div>';
  });
  html += '</div>';
  html += '<button class="pnj-action-btn" onclick="doConsulterResumesMandats()" style="margin-top:1rem;opacity:.8"><i class="ti ti-arrow-left" style="font-size:.85rem"></i> Nouvelle recherche</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;

  if (m.nom === 'Marcel Torcieu' && typeof enigme1DossierCocherCase === 'function') {
    enigme1DossierCocherCase('mairie');
  }
}"""

new = """function enigme1AfficherMandat(nomMaire) {
  const m = ENIGME1_REGISTRE_MANDATS.find(function(x) { return x.nom === nomMaire; });
  if (!m) return;

  const dejaConsulte = typeof state !== 'undefined' && state.char && state.char.enigme1 &&
    state.char.enigme1.dossier && state.char.enigme1.dossier.mairie;

  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.05em;margin-bottom:.2rem">' + m.nom + ' — Maire de Luthécia (' + m.debut + '–' + m.fin + ')</div>';
  html += '<div style="font-size:.82rem;color:#8a8060;margin-bottom:.8rem">Recensement des grands chantiers et actes majeurs de son mandat :</div>';
  html += '<div style="display:flex;flex-direction:column;gap:.4rem">';
  m.actes.forEach(function(ligne) {
    html += '<div style="font-size:.85rem;color:#e0d8c0;line-height:1.4">• ' + ligne + '</div>';
  });
  html += '</div>';

  if (m.nom === 'Marcel Torcieu' && !dejaConsulte) {
    html += '<div style="margin-top:1rem;padding:.6rem;border-left:2px solid #C9A84C;background:#0f0d05;font-size:.85rem;color:#c0b090;font-style:italic">"Ah, vous vous intéressez à l\\'affaire Thibault. Je pense que vous devriez en parler avec les anciens qui l\\'ont connu. Il doit en rester à l\\'EHPAD." — l\\'Archiviste Municipal</div>';
  }

  html += '<button class="pnj-action-btn" onclick="doConsulterResumesMandats()" style="margin-top:1rem;opacity:.8"><i class="ti ti-arrow-left" style="font-size:.85rem"></i> Nouvelle recherche</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;

  if (m.nom === 'Marcel Torcieu' && typeof enigme1DossierCocherCase === 'function') {
    enigme1DossierCocherCase('mairie');
  }
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Indice précoce de l'Archiviste ajouté (première consultation du mandat de Torcieu uniquement).")
