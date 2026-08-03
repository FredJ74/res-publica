#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_1 = """  html += '<div style="display:flex;gap:.4rem;margin-bottom:.4rem">';
  html += '<input id="subdiv-label" type="text" placeholder="Nom du lot..." style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" />';
  html += '<input id="subdiv-surface" type="number" placeholder="Surface m²..." style="width:130px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" />';
  html += '</div>';
  html += '<button class="pnj-action-btn" onclick="doAjouterSubdivision()">+ Ajouter ce lot</button>';"""
new_1 = """  html += '<div style="display:flex;gap:.4rem;margin-bottom:.4rem">';
  html += '<input id="subdiv-label" type="text" placeholder="Nom du lot..." style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" />';
  html += '<input id="subdiv-surface" type="number" placeholder="Surface m²..." style="width:120px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" />';
  html += '<input id="subdiv-loyer" type="number" placeholder="Loyer/jour..." style="width:120px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" />';
  html += '</div>';
  html += '<button class="pnj-action-btn" onclick="doAjouterSubdivision()">+ Ajouter ce lot</button>';"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

old_2 = """  const label = (document.getElementById('subdiv-label')?.value || '').trim();
  const surface = parseInt(document.getElementById('subdiv-surface')?.value || 0);

  if (!label) { showToast('Nom manquant', 'Donnez un nom à ce lot.', false); return; }
  if (!surface || surface < surfaceMin) { showToast('Surface trop petite', 'Chaque lot doit faire au moins ' + surfaceMin + ' m².', false); return; }"""
new_2 = """  const label = (document.getElementById('subdiv-label')?.value || '').trim();
  const surface = parseInt(document.getElementById('subdiv-surface')?.value || 0);
  const loyer = parseInt(document.getElementById('subdiv-loyer')?.value || 0);

  if (!label) { showToast('Nom manquant', 'Donnez un nom à ce lot.', false); return; }
  if (!surface || surface < surfaceMin) { showToast('Surface trop petite', 'Chaque lot doit faire au moins ' + surfaceMin + ' m².', false); return; }
  if (!loyer || loyer < 1) { showToast('Loyer manquant', 'Indiquez un loyer journalier.', false); return; }"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

old_3 = """  subdivisions.push({ id: 'lot-' + Date.now(), label: label, surface: surface, locataire: null, loyer: null });"""
new_3 = """  subdivisions.push({ id: 'lot-' + Date.now(), label: label, surface: surface, locataire: null, loyer: loyer });"""
assert content.count(old_3) == 1, f"bloc 3 : trouvé {content.count(old_3)} fois (attendu 1)"
content = content.replace(old_3, new_3)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Prix du loyer ajouté à la création d'un lot.")
