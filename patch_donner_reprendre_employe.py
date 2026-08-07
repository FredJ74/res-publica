#!/usr/bin/env python3
PATH = "plateau-multijoueur.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """        '<button onclick="licencierPnj(\\'' + emp.nom.replace(/'/g,'') + '\\')" title="Renvoyer cet employe — arret du contrat et du salaire" style="background:none;border:1px solid #3a1a1a;color:#6a3a2a;cursor:pointer;padding:.15rem .3rem;font-size:.8rem">✕</button>' +
      '</div>' +
    '</div>';
  }).join('');
}"""

new = """        '<button onclick="ouvrirDonnerEmploye(\\'' + emp.nom.replace(/'/g,'') + '\\')" title="Donner un objet a porter (plafond 100 unites au total)" style="background:none;border:1px solid #2a3a3a;color:#4a7a7a;cursor:pointer;padding:.15rem .3rem;font-size:.8rem">📦</button>' +
        '<button onclick="ouvrirReprendreEmploye(\\'' + emp.nom.replace(/'/g,'') + '\\')" title="Reprendre ce que porte cet employe" style="background:none;border:1px solid #3a3a2a;color:#7a7a4a;cursor:pointer;padding:.15rem .3rem;font-size:.8rem">↩️</button>' +
        '<button onclick="licencierPnj(\\'' + emp.nom.replace(/'/g,'') + '\\')" title="Renvoyer cet employe — arret du contrat et du salaire. Ce qu\\'il porte est perdu." style="background:none;border:1px solid #3a1a1a;color:#6a3a2a;cursor:pointer;padding:.15rem .3rem;font-size:.8rem">✕</button>' +
      '</div>' +
    '</div>';
  }).join('');
}

// =====================
// DONNER / REPRENDRE UN OBJET A UN EMPLOYE — chaque employe peut porter jusqu'a 100 unites
// (meme plafond que le joueur), plafond fixe pour tous les PNJ pour l'instant (voir Fred,
// 7 aout 2026 : differenciation par PNJ a construire plus tard si besoin). Ce qu'un employe
// porte est definitivement perdu s'il est licencie ou part faute de paiement.
// =====================
const PLAFOND_CHARGE_EMPLOYE = 100;

function getTotalChargeEmploye(emp) {
  return Object.values(emp.charge || {}).reduce((s, q) => s + q, 0);
}

function ouvrirDonnerEmploye(nomEmploye) {
  const emp = (state.employes || []).find(e => e.nom === nomEmploye);
  if (!emp) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const chargeActuelle = getTotalChargeEmploye(emp);
  const placeRestante = Math.max(0, PLAFOND_CHARGE_EMPLOYE - chargeActuelle);

  if ((state.inventory || []).length === 0) {
    showToast('Inventaire vide', "Vous n'avez rien à donner.", false);
    return;
  }

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#8a8060;margin-bottom:.8rem">' + emp.nom + ' porte déjà ' + chargeActuelle + '/' + PLAFOND_CHARGE_EMPLOYE + ' unités. Place restante : ' + placeRestante + '.</div>';
  html += '<div style="display:flex;flex-direction:column;gap:.4rem">';
  state.inventory.forEach((item, idx) => {
    const qte = item.qty || 1;
    html += '<div style="display:flex;justify-content:space-between;align-items:center;padding:.5rem;border:1px solid #2a2010;background:#0f0d05">';
    html += '<span style="font-size:.85rem;color:#c0b090"><i class="ti ' + (item.icon||'ti-package') + '" style="margin-right:.3rem"></i>' + item.name + (qte > 1 ? ' (×' + qte + ')' : '') + '</span>';
    if (item.stackable && qte > 1) {
      html += '<div style="display:flex;gap:.3rem;align-items:center"><input type="number" min="1" max="' + Math.min(qte, placeRestante) + '" id="donner-emp-qty-' + idx + '" value="1" style="width:60px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.2rem" /><button class="pnj-action-btn" onclick="confirmerDonnerEmploye(\\'' + nomEmploye + '\\',' + idx + ')" style="padding:.3rem .6rem">Donner</button></div>';
    } else {
      html += '<button class="pnj-action-btn" onclick="confirmerDonnerEmploye(\\'' + nomEmploye + '\\',' + idx + ')" style="padding:.3rem .6rem">Donner</button>';
    }
    html += '</div>';
  });
  html += '</div></div>';

  document.getElementById('postes-modal-title').textContent = 'Donner à ' + emp.nom;
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerDonnerEmploye(nomEmploye, idx) {
  const emp = (state.employes || []).find(e => e.nom === nomEmploye);
  const item = state.inventory[idx];
  if (!emp || !item) return;

  const chargeActuelle = getTotalChargeEmploye(emp);
  const placeRestante = Math.max(0, PLAFOND_CHARGE_EMPLOYE - chargeActuelle);
  if (placeRestante <= 0) {
    showToast('Charge maximale', emp.nom + ' ne peut plus rien porter de plus.', false);
    return;
  }

  if (!emp.charge) emp.charge = {};

  if (item.stackable && item.stackKey) {
    const qteVoulue = parseInt(document.getElementById('donner-emp-qty-' + idx)?.value || item.qty || 1);
    const qteReelle = Math.min(qteVoulue, item.qty || 1, placeRestante);
    if (qteReelle <= 0) return;

    emp.charge[item.stackKey] = (emp.charge[item.stackKey] || 0) + qteReelle;
    item.qty = (item.qty || 1) - qteReelle;
    if (item.qty <= 0) state.inventory.splice(idx, 1);
  } else {
    // Objet unique : cle basee sur le nom, compte pour 1 unite de charge
    const cle = '_unique_' + item.name;
    if (!emp.chargeUnique) emp.chargeUnique = [];
    emp.chargeUnique.push(item);
    emp.charge[cle] = (emp.charge[cle] || 0) + 1;
    state.inventory.splice(idx, 1);
  }

  renderInventory();
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Objet confié', emp.nom + ' porte maintenant "' + item.name + '".', true);
  addJournalEntry('Vous avez confié "' + item.name + '" à ' + emp.nom + '.', 'event-info');
}

function ouvrirReprendreEmploye(nomEmploye) {
  const emp = (state.employes || []).find(e => e.nom === nomEmploye);
  if (!emp || !emp.charge || Object.keys(emp.charge).length === 0) {
    showToast('Rien à reprendre', emp?.nom + ' ne porte rien pour l\\'instant.', false);
    return;
  }

  let html = '<div style="padding:1rem"><div style="display:flex;flex-direction:column;gap:.4rem">';
  Object.entries(emp.charge).forEach(([cle, qte]) => {
    if (qte <= 0) return;
    const estUnique = cle.startsWith('_unique_');
    const label = estUnique ? cle.replace('_unique_', '') : (RESSOURCES_ECONOMIE[cle]?.label || cle);
    html += '<div style="display:flex;justify-content:space-between;align-items:center;padding:.5rem;border:1px solid #2a2010;background:#0f0d05">';
    html += '<span style="font-size:.85rem;color:#c0b090">' + label + (qte > 1 ? ' (×' + qte + ')' : '') + '</span>';
    if (!estUnique && qte > 1) {
      html += '<div style="display:flex;gap:.3rem;align-items:center"><input type="number" min="1" max="' + qte + '" id="reprendre-emp-qty-' + cle + '" value="' + qte + '" style="width:60px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.2rem" /><button class="pnj-action-btn" onclick="confirmerReprendreEmploye(\\'' + nomEmploye + '\\',\\'' + cle + '\\')" style="padding:.3rem .6rem">Reprendre</button></div>';
    } else {
      html += '<button class="pnj-action-btn" onclick="confirmerReprendreEmploye(\\'' + nomEmploye + '\\',\\'' + cle + '\\')" style="padding:.3rem .6rem">Reprendre</button>';
    }
    html += '</div>';
  });
  html += '</div></div>';

  document.getElementById('postes-modal-title').textContent = 'Reprendre à ' + emp.nom;
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerReprendreEmploye(nomEmploye, cle) {
  const emp = (state.employes || []).find(e => e.nom === nomEmploye);
  if (!emp || !emp.charge || !emp.charge[cle]) return;

  const estUnique = cle.startsWith('_unique_');

  if (estUnique) {
    const item = (emp.chargeUnique || []).find(i => ('_unique_' + i.name) === cle);
    if (!item) return;
    const qteAjoutee = addToInventory(item);
    if (qteAjoutee > 0) {
      emp.chargeUnique = emp.chargeUnique.filter(i => i !== item);
      delete emp.charge[cle];
    }
  } else {
    const qteVoulue = parseInt(document.getElementById('reprendre-emp-qty-' + cle)?.value || emp.charge[cle]);
    const res = RESSOURCES_ECONOMIE[cle];
    const qteAjoutee = addToInventory({ name: res?.label || cle, icon: res?.icon, stackable: true, stackKey: cle, qty: Math.min(qteVoulue, emp.charge[cle]) });
    if (qteAjoutee > 0) {
      emp.charge[cle] -= qteAjoutee;
      if (emp.charge[cle] <= 0) delete emp.charge[cle];
    }
  }

  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Objet récupéré', 'Repris à ' + emp.nom + '.', true);
  addJournalEntry('Vous avez repris ce que portait ' + emp.nom + '.', 'event-info');
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Donner/reprendre un objet à un employé créé (plafond 100, perdu si licenciement).")
