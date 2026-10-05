#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_1 = """    subdivisions.forEach(function(l, i) {
      html += '<div style="padding:.5rem .6rem;border:1px solid #2a2010;background:#0f0d05;display:flex;justify-content:space-between;align-items:center">';
      html += '<span style="font-size:.82rem;color:#c0b090">' + l.label + ' — ' + l.surface + ' m²' + (l.locataire ? ' (loué par ' + l.locataire + ')' : ' (libre)') + '</span>';
      html += '<button onclick="doSupprimerSubdivision(' + i + ')" style="font-size:.68rem;color:#cc5540;background:transparent;border:none;cursor:pointer">Retirer</button>';
      html += '</div>';
    });"""
new_1 = """    const yATilDesLotsVides = subdivisions.some(function(l) { return !l.locataire; });
    subdivisions.forEach(function(l, i) {
      html += '<div style="padding:.5rem .6rem;border:1px solid #2a2010;background:#0f0d05;display:flex;justify-content:space-between;align-items:center">';
      html += '<span style="font-size:.82rem;color:#c0b090">' + l.label + ' — ' + l.surface + ' m²' + (l.locataire ? ' (loué par ' + l.locataire + ')' : ' (libre)') + '</span>';
      html += '<div style="display:flex;gap:.5rem">';
      if (l.locataire && yATilDesLotsVides) {
        html += '<button onclick="doOuvrirAgrandirLot(' + i + ')" style="font-size:.68rem;color:#4a9a6a;background:transparent;border:none;cursor:pointer">Agrandir</button>';
      }
      html += '<button onclick="doSupprimerSubdivision(' + i + ')" style="font-size:.68rem;color:#cc5540;background:transparent;border:none;cursor:pointer">Retirer</button>';
      html += '</div>';
      html += '</div>';
    });"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

old_2 = """function getValeurTotaleBien(ts) {"""
new_2 = """function doOuvrirAgrandirLot(idxOccupe) {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const subdivisions = ts.subdivisions || [];
  const lotOccupe = subdivisions[idxOccupe];
  if (!lotOccupe) return;

  const lotsVides = subdivisions
    .map(function(l, i) { return { l: l, i: i }; })
    .filter(function(x) { return !x.l.locataire && x.i !== idxOccupe; });

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.82rem;color:#8a8060;margin-bottom:.8rem">Agrandir « ' + lotOccupe.label + ' » (' + lotOccupe.surface + ' m², loué par ' + lotOccupe.locataire + ') en y fusionnant un lot vide. Le locataire n\\'est pas affecté.</div>';
  html += '<div style="display:flex;flex-direction:column;gap:.3rem">';
  lotsVides.forEach(function(x) {
    html += '<div onclick="doFusionnerLot(' + idxOccupe + ',' + x.i + ')" style="cursor:pointer;padding:.5rem .6rem;border:1px solid #2a2010;background:#0f0d05">';
    html += '<span style="font-size:.82rem;color:#c0b090">' + x.l.label + ' — ' + x.l.surface + ' m² (libre)</span>';
    html += '</div>';
  });
  html += '</div>';
  html += '<button class="pnj-action-btn" onclick="doOuvrirDivisionTerrain()" style="margin-top:1rem;opacity:.8">Annuler</button>';
  html += '</div>';

  document.getElementById('postes-body').innerHTML = html;
}

function getValeurTotaleBien(ts) {"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Bouton Agrandir + selection du lot vide ajoutés.")
