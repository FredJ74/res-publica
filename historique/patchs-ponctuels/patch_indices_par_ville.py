#!/usr/bin/env python3
PATH = "plateau-divers.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function ouvrirIndicesImperiaux() {
  // Ouvrir dans un modal simple pour eviter les problemes de vue
  const empires = [
    { key:'republic', name:'Républia',   col:'#4a9ade' },
    { key:'narco',    name:'El Estado',  col:'#cc4444' },
    { key:'soviet',   name:'Sovarka',    col:'#cc2020' },
    { key:'khalija',  name:'Al-Khalija', col:'#C9A84C' }
  ];

  document.getElementById('postes-modal-title').textContent = 'Indices Imperiaux';
  let html = '<div style="padding:1rem">';

  empires.forEach(emp => {
    const idx = (typeof INDICES_NATIONAUX !== 'undefined') ? (INDICES_NATIONAUX[emp.key] || {ISN:30,IE:50,ID:40,IS:45}) : {ISN:30,IE:50,ID:40,IS:45};
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem">';
    html += '<div style="font-family:Playfair Display,serif;font-size:.88rem;color:' + emp.col + ';margin-bottom:.5rem">' + emp.name + '</div>';
    html += '<div style="display:grid;grid-template-columns:repeat(4,1fr);gap:.3rem">';
    [['ISN','Securite','#4a8a4a'],['IE','Eco','#C9A84C'],['ID','Diplo','#4a6aaa'],['IS','Social','#aa6a4a'],['IP','Piété','#8a4a8a']].forEach(([k,label,col]) => {
      const val = idx[k] || 0;
      html += '<div style="text-align:center;padding:.3rem;background:#0a0805;border:1px solid #1a1810">';
      html += '<div style="font-size:.78rem;color:#9a8a68">' + label + '</div>';
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:1.2rem;color:' + col + '">' + val + '</div>';
      html += '<div style="height:3px;background:#0a0a05;margin-top:.15rem"><div style="height:100%;width:' + val + '%;background:' + col + ';opacity:.6"></div></div>';
      html += '</div>';
    });
    html += '</div></div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}"""

new = """// Indices locaux, par ville — structure minimale pour l'instant, seule Luthecia (Republia)
// est peuplee (necessaire pour le vol de materiel de chantier). Les autres villes/empires
// restent a construire dans une session dediee (moyenne nationale, QHS, caserne...).
const INDICES_VILLES = {
  republic: {
    capitale: { nom: 'Luthécia', ISN: 30, IE: 50, ID: 40, IS: 45 }
  }
};

function getIndicesVille(pays, ville) {
  return (INDICES_VILLES[pays] && INDICES_VILLES[pays][ville]) || null;
}

function modifierIndiceVille(pays, ville, cle, delta) {
  if (!INDICES_VILLES[pays]) INDICES_VILLES[pays] = {};
  if (!INDICES_VILLES[pays][ville]) INDICES_VILLES[pays][ville] = { nom: ville, ISN: 30, IE: 50, ID: 40, IS: 45 };
  const iv = INDICES_VILLES[pays][ville];
  iv[cle] = Math.max(0, Math.min(100, (iv[cle] || 0) + delta));
}

function rendreGrilleIndices(idx, col) {
  let html = '<div style="display:grid;grid-template-columns:repeat(4,1fr);gap:.3rem">';
  [['ISN','Securite','#4a8a4a'],['IE','Eco','#C9A84C'],['ID','Diplo','#4a6aaa'],['IS','Social','#aa6a4a'],['IP','Piété','#8a4a8a']].forEach(([k,label,c]) => {
    const val = idx[k] || 0;
    html += '<div style="text-align:center;padding:.3rem;background:#0a0805;border:1px solid #1a1810">';
    html += '<div style="font-size:.78rem;color:#9a8a68">' + label + '</div>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:1.2rem;color:' + c + '">' + val + '</div>';
    html += '<div style="height:3px;background:#0a0a05;margin-top:.15rem"><div style="height:100%;width:' + val + '%;background:' + c + ';opacity:.6"></div></div>';
    html += '</div>';
  });
  html += '</div>';
  return html;
}

const LISTE_EMPIRES_INDICES = [
  { key:'republic', name:'Républia',   col:'#4a9ade' },
  { key:'narco',    name:'El Estado',  col:'#cc4444' },
  { key:'soviet',   name:'Sovarka',    col:'#cc2020' },
  { key:'khalija',  name:'Al-Khalija', col:'#C9A84C' }
];

function ouvrirIndicesImperiaux() {
  let html = '<div style="padding:1rem"><div style="display:flex;flex-direction:column;gap:.4rem">';
  LISTE_EMPIRES_INDICES.forEach(emp => {
    html += '<div onclick="afficherIndicesEmpire(\\'' + emp.key + '\\')" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05;font-family:Playfair Display,serif;font-size:.88rem;color:' + emp.col + '">' + emp.name + '</div>';
  });
  html += '</div></div>';
  document.getElementById('postes-modal-title').textContent = 'Indices Impériaux';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function afficherIndicesEmpire(empireKey) {
  const emp = LISTE_EMPIRES_INDICES.find(e => e.key === empireKey);
  if (!emp) return;
  const idx = (typeof INDICES_NATIONAUX !== 'undefined') ? (INDICES_NATIONAUX[empireKey] || {ISN:30,IE:50,ID:40,IS:45}) : {ISN:30,IE:50,ID:40,IS:45};

  let html = '<div style="padding:1rem">';
  html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.8rem">';
  html += '<div style="font-family:Playfair Display,serif;font-size:.9rem;color:' + emp.col + ';margin-bottom:.5rem">' + emp.name + ' — Indices Nationaux</div>';
  html += rendreGrilleIndices(idx, emp.col);
  html += '</div>';

  const villes = INDICES_VILLES[empireKey];
  if (villes && Object.keys(villes).length > 0) {
    html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.5rem">Détail par ville :</div>';
    Object.values(villes).forEach(iv => {
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.6rem;margin-bottom:.5rem">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#c0b090;margin-bottom:.4rem">' + iv.nom + '</div>';
      html += rendreGrilleIndices(iv, '#8a8060');
      html += '</div>';
    });
  }

  html += '<button class="pnj-action-btn" onclick="ouvrirIndicesImperiaux()" style="margin-top:.5rem;opacity:.8">← Retour aux empires</button>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = emp.name;
  document.getElementById('postes-body').innerHTML = html;
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Onglet Indices restructuré : sélection de l'empire, indices nationaux + détail par ville (Luthécia peuplée pour l'instant).")
