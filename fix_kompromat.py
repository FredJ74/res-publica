#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif "Recueillir des informations" -> "Fabriquer un kompromat" :
- supprime l'ordre de salle escort_infos du bar (nom trompeur, cible aleatoire)
- ajoute un bouton contextuel "Fabriquer un kompromat" sur la fiche de tout
  PNJ job:'escort' (comme Roxane), peu importe le lieu ou il se trouve
- le joueur choisit maintenant la cible dans son repertoire (PJ uniquement)
- cout inchange (300 FR), genere toujours un objet kompromat dans l'inventaire
"""
import sys

def apply_patch(path, old, new, label):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    count = content.count(old)
    if count == 0:
        print(f"[ECHEC] {label} : ancre introuvable dans {path}")
        return False
    if count > 1:
        print(f"[ECHEC] {label} : ancre trouvee {count} fois dans {path} (doit etre unique)")
        return False
    content = content.replace(old, new, 1)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"[OK] {label}")
    return True

ok = True

# ------------------------------------------------------------------
# 1) plateau-pnj.js -- bouton contextuel + fonctions
# ------------------------------------------------------------------
old_pnj = """  // Recruter escort
  if (pnj.job === 'escort') {
    const escortNom = pnj.name.replace(' (PNJ)', '').replace(/'/g, '');
    actionBtns += '<button class="pnj-action-btn" onclick="ouvrirRecrutementEscort(\\'' + escortNom + '\\')"><i class="ti ti-heart" style="font-size:.85rem"></i> Recruter comme escort</button>';
  }"""

new_pnj = """  // Recruter escort
  if (pnj.job === 'escort') {
    const escortNom = pnj.name.replace(' (PNJ)', '').replace(/'/g, '');
    actionBtns += '<button class="pnj-action-btn" onclick="ouvrirRecrutementEscort(\\'' + escortNom + '\\')"><i class="ti ti-heart" style="font-size:.85rem"></i> Recruter comme escort</button>';
    actionBtns += '<button class="pnj-action-btn" onclick="ouvrirModalFabriquerKompromat(\\'' + escortNom + '\\')"><i class="ti ti-file-shredder" style="font-size:.85rem"></i> Fabriquer un kompromat (300 FR)</button>';
  }"""

ok &= apply_patch('plateau-pnj.js', old_pnj, new_pnj, "plateau-pnj.js - bouton Fabriquer un kompromat")

old_fn = """function doEscortPiege() {"""

new_fn = """function ouvrirModalFabriquerKompromat(nomAgent) {
  const pjContacts = (state.contacts || []).filter(c => c.isPJ || c.type === 'pj');
  if (pjContacts.length === 0) {
    showToast('Aucune cible', 'Vous devez avoir des PJ dans votre répertoire pour fabriquer un kompromat.', false);
    return;
  }
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  document.getElementById('postes-modal-title').textContent = '🗂️ Choisir une cible';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.7rem">' + nomAgent + ' peut fabriquer un kompromat sur un PJ de votre répertoire. Coût : 300 ' + cur + '.</div>' +
    pjContacts.map(c =>
      '<div onclick="confirmerFabriquerKompromat(\\'' + nomAgent.replace(/'/g,'') + '\\',\\'' + c.name.replace(/'/g,'') + '\\')" style="display:flex;align-items:center;gap:.6rem;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\\'#1a1005\\'" onmouseout="this.style.background=\\'#0f0d05\\'">' +
        '<i class="ti ti-user" style="font-size:.9rem;color:#8a6a20"></i>' +
        '<div><div style="font-size:.82rem;color:#c0b090">' + c.name + '</div></div>' +
      '</div>'
    ).join('') +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerFabriquerKompromat(nomAgent, nomCible) {
  document.getElementById('modal-postes').classList.remove('open');
  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';
  if (state.arg < 300) { showToast('Fonds insuffisants', '300 ' + cur + ' requis.', false); return; }
  state.arg -= 300;

  const prompt = `Tu joues dans Res Publica, jeu politique parodique.
${nomAgent} a recueilli des informations compromettantes sur ${nomCible} dans l'empire ${co?.n}.
Génère UNE révélation compromettante, parodique et drôle (2 phrases max). Style scandale politique. Pas de vrais noms de personnes réelles. Pas de religions réelles.`;

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ model: 'claude-haiku-4-5-20251001', max_tokens: 60, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    const info = data.content?.[0]?.text?.trim() || 'Information confidentielle obtenue.';

    addToInventory({
      id: 'kompromat-' + Date.now(),
      name: 'Kompromat sur ' + nomCible,
      icon: 'ti-file-shredder',
      desc: info,
      type: 'kompromat',
      cible: nomCible,
      legal: false
    });

    state.inf = Math.min(100, (state.inf || 0) + 5);
    updateUI();
    addJournalEntry('Kompromat obtenu sur ' + nomCible + ' via ' + nomAgent + '. Ajouté à l\\'inventaire.', 'event-info');
    showToast('Kompromat fabriqué !', info.substring(0, 100) + (info.length > 100 ? '...' : ''), true, true);
  } catch(e) {
    state.arg += 300;
    showToast('Erreur', 'Impossible de fabriquer le kompromat pour le moment. Remboursé.', false);
  }
}

function doEscortPiege() {"""

ok &= apply_patch('plateau-pnj.js', old_fn, new_fn, "plateau-pnj.js - ouvrirModalFabriquerKompromat + confirmerFabriquerKompromat")

# ------------------------------------------------------------------
# 2) data.js -- suppression de l'ordre de salle
# ------------------------------------------------------------------
old_data = """          {fn:'escort_infos',    label:'Recueillir des informations', pa:2, cost:300, type:'grey', icon:'ti-ear', successRate:75, desc:'Roxane collecte des confidences. Génère un kompromat sur une cible.'},
"""
new_data = ""
ok &= apply_patch('data.js', old_data, new_data, "data.js - bar : suppression de l'ordre escort_infos")

print()
if ok:
    print("TOUT EST OK.")
else:
    print("ECHEC. Ne rien committer, colle le detail a Claude.")
    sys.exit(1)
