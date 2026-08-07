#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.75rem;color:#8a8060;margin-bottom:.8rem">Indiquez la quantité souhaitée pour chaque produit (laissez vide pour ne rien acheter). Le prix affiché varie selon le niveau du stock.</div>';
  html += '<table style="width:100%;font-size:.78rem;border-collapse:collapse">';
  html += '<tr style="color:#8a6a20;font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.05em;text-align:left"><th>Produit</th><th>Stock</th><th>Prix mini-maxi</th><th>Prix actuel</th><th>Quantité</th></tr>';

  Object.entries(RESSOURCES_ECONOMIE).forEach(([cle, res]) => {
    const enStock = stock[cle] || 0;
    const prixActuel = typeof getPrixRessource === 'function' ? getPrixRessource(cle, enStock) : res.prixBase;
    const prixMin = Math.round(res.prixBase * 0.6 * 100) / 100;
    const prixMax = Math.round(res.prixBase * 1.4 * 100) / 100;
    html += '<tr style="border-top:1px solid #2a2010">';
    html += '<td style="padding:.35rem 0"><i class="ti ' + res.icon + '" style="margin-right:.3rem"></i>' + res.label + '</td>';
    html += '<td style="color:' + (enStock === 0 ? '#cc5540' : '#8a8060') + '">' + enStock + '</td>';
    html += '<td style="color:#6a5a30">' + prixMin + '-' + prixMax + ' ' + cur + '</td>';
    html += '<td style="color:#C9A84C">' + prixActuel + ' ' + cur + '</td>';
    html += '<td><input type="number" min="0" max="' + enStock + '" id="achat-entrepot-' + cle + '" style="width:70px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.25rem" ' + (enStock === 0 ? 'disabled' : '') + ' /></td>';
    html += '</tr>';
  });
  html += '</table>';
  html += '<button class="pnj-action-btn" onclick="confirmerAchatEntrepot(\\'' + buildingId + '\\')" style="margin-top:1rem">Valider l\\'achat</button>';
  html += '</div>';"""

new = """  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:.95rem;color:#8a8060;margin-bottom:1rem">Indiquez la quantité souhaitée pour chaque produit (laissez vide pour ne rien acheter). Le prix affiché varie selon le niveau du stock.</div>';
  html += '<table style="width:100%;font-size:1rem;border-collapse:collapse">';
  html += '<tr style="color:#8a6a20;font-family:Bebas Neue,sans-serif;font-size:.85rem;letter-spacing:.05em;text-align:left"><th style="padding:.3rem 0">Produit</th><th>Stock</th><th>Prix mini-maxi</th><th>Prix actuel</th><th>Quantité</th></tr>';

  Object.entries(RESSOURCES_ECONOMIE).forEach(([cle, res]) => {
    const enStock = stock[cle] || 0;
    const prixActuel = typeof getPrixRessource === 'function' ? getPrixRessource(cle, enStock) : res.prixBase;
    const prixMin = Math.round(res.prixBase * 0.6 * 100) / 100;
    const prixMax = Math.round(res.prixBase * 1.4 * 100) / 100;
    html += '<tr style="border-top:1px solid #2a2010">';
    html += '<td style="padding:.55rem 0"><i class="ti ' + res.icon + '" style="margin-right:.4rem;font-size:1.1rem"></i>' + res.label + '</td>';
    html += '<td style="color:' + (enStock === 0 ? '#cc5540' : '#8a8060') + '">' + enStock + '</td>';
    html += '<td style="color:#6a5a30">' + prixMin + '-' + prixMax + ' ' + cur + '</td>';
    html += '<td style="color:#C9A84C;font-weight:bold">' + prixActuel + ' ' + cur + '</td>';
    html += '<td><input type="number" min="0" max="' + enStock + '" id="achat-entrepot-' + cle + '" style="width:90px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:1rem" ' + (enStock === 0 ? 'disabled' : '') + ' /></td>';
    html += '</tr>';
  });
  html += '</table>';
  html += '<button class="pnj-action-btn" onclick="confirmerAchatEntrepot(\\'' + buildingId + '\\')" style="margin-top:1.2rem;font-size:1rem;padding:.7rem">Valider l\\'achat</button>';
  html += '</div>';"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Fenêtre d'achat agrandie (texte, champs, boutons).")
