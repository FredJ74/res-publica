#!/usr/bin/env python3

# --- 1. Renommer le libelle du bouton dans plateau-pnj.js ---
PATH1 = "plateau-pnj.js"
with open(PATH1, "r", encoding="utf-8") as f:
    content1 = f.read()

old_1 = """  actionBtns += '<button class="pnj-action-btn" onclick="ouvrirDonPnjModal(\\'' + enc + '\\')"><i class="ti ti-coins" style="font-size:.85rem"></i> Donner de l\\'argent</button>';"""
new_1 = """  actionBtns += '<button class="pnj-action-btn" onclick="ouvrirDonPnjModal(\\'' + enc + '\\')"><i class="ti ti-coins" style="font-size:.85rem"></i> Donner</button>';"""
assert content1.count(old_1) == 1, f"pnj.js : trouvé {content1.count(old_1)}"
content1 = content1.replace(old_1, new_1)

with open(PATH1, "w", encoding="utf-8") as f:
    f.write(content1)
print("✅ Bouton renommé en 'Donner'.")

# --- 2. Ajouter la possibilite de donner un objet, uniquement pour un vrai joueur (isPJ) ---
PATH2 = "plateau-justice-economie.js"
with open(PATH2, "r", encoding="utf-8") as f:
    content2 = f.read()

old_2 = """  // modal-pnj reste ouvert
  document.getElementById('postes-modal-title').textContent = 'Donner de l\\'argent a ' + pnj.name.replace(' (PNJ)', '');
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#a09060;font-style:italic;margin-bottom:.7rem;border-left:2px solid #3a2a10;padding-left:.6rem">' + (jobLabels[job] || jobLabels.default) + '</div>' +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">MONTANT (' + cur + ')</div>' +
    '<input id="don-pnj-montant" type="number" min="10" step="50" placeholder="Ex: 200" style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,Georgia,serif;font-size:.9rem;box-sizing:border-box;margin-bottom:.7rem"/>' +
    '<button onclick="confirmerDonPnj(\\'' + encodedPnj + '\\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">💰 Donner</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}"""

new_2 = """  // modal-pnj reste ouvert
  document.getElementById('postes-modal-title').textContent = 'Donner à ' + pnj.name.replace(' (PNJ)', '');
  let html = '<div style="padding:.8rem 1rem">';
  html += '<div style="font-size:.78rem;color:#a09060;font-style:italic;margin-bottom:.7rem;border-left:2px solid #3a2a10;padding-left:.6rem">' + (jobLabels[job] || jobLabels.default) + '</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">MONTANT (' + cur + ')</div>';
  html += '<input id="don-pnj-montant" type="number" min="10" step="50" placeholder="Ex: 200" style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,Georgia,serif;font-size:.9rem;box-sizing:border-box;margin-bottom:.7rem"/>';
  html += '<button onclick="confirmerDonPnj(\\'' + encodedPnj + '\\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">💰 Donner de l\\'argent</button>';

  // Donner un objet — reserve aux vrais joueurs (semantique non definie pour un PNJ non
  // employe). Pas de mail de confirmation (juste le journal), sur demande de Fred.
  if (pnj.isPJ && (state.inventory || []).length > 0) {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.12em;color:#8a6a20;margin:.9rem 0 .4rem">OU DONNER UN OBJET</div>';
    html += '<div style="display:flex;flex-direction:column;gap:.3rem;max-height:200px;overflow-y:auto">';
    state.inventory.forEach((item, idx) => {
      const qte = item.qty || 1;
      html += '<button onclick="confirmerDonObjetPj(\\'' + encodedPnj + '\\',' + idx + ')" style="display:flex;justify-content:space-between;align-items:center;padding:.4rem .6rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.8rem;text-align:left">';
      html += '<span><i class="ti ' + (item.icon||'ti-package') + '" style="margin-right:.3rem"></i>' + item.name + (qte > 1 ? ' (×' + qte + ')' : '') + '</span>';
      html += '</button>';
    });
    html += '</div>';
  }

  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// Donne un objet a un vrai joueur (jamais a un PNJ non employe — semantique non definie).
// Contrairement a donnerObjetAJoueur (fiche personnage), pas de mail de confirmation : le
// don est seulement note dans le journal, sur demande explicite de Fred le 7 aout 2026.
async function confirmerDonObjetPj(encodedPnj, idx) {
  let pnj;
  try { pnj = JSON.parse(decodeURIComponent(encodedPnj)); } catch(e) { return; }
  const item = state.inventory[idx];
  if (!item || !pnj.isPJ) return;

  const cible = pnj.name.replace(' (PNJ)', '');
  state.inventory.splice(idx, 1);
  renderInventory();
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Objet donné', '"' + item.name + '" donné à ' + cible + '.', true, true);
  addJournalEntry('Vous avez donné "' + item.name + '" à ' + cible + '.', 'event-info');
}"""

assert content2.count(old_2) == 1, f"justice-economie.js : trouvé {content2.count(old_2)}"
content2 = content2.replace(old_2, new_2)

with open(PATH2, "w", encoding="utf-8") as f:
    f.write(content2)
print("✅ Don d'objet à un vrai joueur ajouté (sans mail de confirmation, journal uniquement).")
