#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif "Lancer une rumeur" (ciblee, acte illegal) :
- plateau-pnj.js : ajout de ouvrirModalLancerRumeur() + confirmerLancerRumeur()
  (meme pattern que doEscortPiege : selection d'un PJ du repertoire)
- plateau-router.js : la route existante appelait openRumeurModal(), qui n'a
  jamais ete definie nulle part (bug d'origine) -> corrige vers la vraie fonction
- data.js : le "Lancer une rumeur" du restaurant (fn:'rumeur', generique, sans
  cible) est aligne sur le vrai mecanisme cible (fn:'lancer_rumeur_cible')
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
# 1) plateau-pnj.js -- nouvelles fonctions (inserees juste avant doEscortPiege)
# ------------------------------------------------------------------
old_pnj = """function doEscortPiege() {"""

new_pnj = """function ouvrirModalLancerRumeur(pa, cost, successRate) {
  const pjContacts = (state.contacts || []).filter(c => c.isPJ || c.type === 'pj');
  if (pjContacts.length === 0) {
    showToast('Aucune cible', 'Vous devez avoir des PJ dans votre répertoire pour lancer une rumeur.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = '🗯 Choisir une cible';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.7rem">Sélectionnez le PJ visé par la rumeur. Acte illégal — un jet raté se retourne contre vous.</div>' +
    pjContacts.map(c =>
      '<div onclick="confirmerLancerRumeur(\\'' + c.name.replace(/'/g,'') + '\\',' + pa + ',' + cost + ',' + successRate + ')" style="display:flex;align-items:center;gap:.6rem;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\\'#1a1005\\'" onmouseout="this.style.background=\\'#0f0d05\\'">' +
        '<i class="ti ti-user" style="font-size:.9rem;color:#8a6a20"></i>' +
        '<div><div style="font-size:.82rem;color:#c0b090">' + c.name + '</div>' +
        '<div style="font-size:.85rem;color:#9a8a68">' + (c.role||'PJ') + '</div></div>' +
      '</div>'
    ).join('') +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerLancerRumeur(nomCible, pa, cost, successRate) {
  document.getElementById('modal-postes').classList.remove('open');

  const roll = Math.floor(Math.random() * 100) + 1;
  const succes = roll <= (successRate || 50);

  if (succes) {
    const perte = Math.floor(Math.random() * 16) + 5; // entre 5 et 20
    if (typeof sbAjusterPopJoueur === 'function') {
      sbAjusterPopJoueur(nomCible, -perte).catch(() => {});
    }
    addExternalEvent('🗯 Une rumeur compromettante circule sur ' + nomCible + '.');
    addJournalEntry('Rumeur lancée avec succès contre ' + nomCible + ' (-' + perte + ' POP).', 'event-good');
    showToast('Rumeur lancée !', 'La rumeur se propage. ' + nomCible + ' perd ' + perte + ' POP.', true, true);
    if (typeof tracerActionPourRumeur === 'function') tracerActionPourRumeur('fausse_rumeur', nomCible);
    if (typeof checkDetection === 'function') checkDetection('fausse_rumeur', 'success');
  } else {
    state.pop = Math.max(0, (state.pop || 0) - 5);
    state.dis = Math.max(0, (state.dis || 50) - 5);
    addJournalEntry('Tentative de rumeur contre ' + nomCible + ' ratée. Elle se retourne contre vous. -5 POP -5 DIS.', 'event-bad');
    showToast('Rumeur ratée', 'Votre tentative échoue et se retourne contre vous. -5 POP -5 DIS.', false);
    if (typeof checkDetection === 'function') checkDetection('fausse_rumeur', 'success');
  }

  if (typeof advanceTime === 'function') advanceTime(Math.max(0, pa || 0));
  updateUI();
}

function doEscortPiege() {"""

ok &= apply_patch('plateau-pnj.js', old_pnj, new_pnj, "plateau-pnj.js - ouvrirModalLancerRumeur + confirmerLancerRumeur")

# ------------------------------------------------------------------
# 2) plateau-router.js -- corriger la route (appelait une fonction inexistante)
# ------------------------------------------------------------------
old_route = """  if (fn === 'lancer_rumeur_cible') { openRumeurModal(); return; }"""
new_route = """  if (fn === 'lancer_rumeur_cible') { ouvrirModalLancerRumeur(pa, cost, successRate); return; }"""

ok &= apply_patch('plateau-router.js', old_route, new_route, "plateau-router.js - corrige la route lancer_rumeur_cible")

# ------------------------------------------------------------------
# 3) data.js -- restaurant Hotel Republica : aligner sur le vrai mecanisme
# ------------------------------------------------------------------
old_data = """{fn:'rumeur',       label:'Lancer une rumeur',   pa:1, cost:0,   type:'grey',   icon:'ti-messages', successRate:80,  desc:'Faire circuler une information.'}"""
new_data = """{fn:'lancer_rumeur_cible', label:'Lancer une rumeur', pa:1, cost:0, type:'grey', icon:'ti-messages', successRate:80, desc:'Sur un PJ de votre repertoire. Succes : -5 a -20 POP sur la cible. Echec : se retourne contre vous (-5 POP -5 DIS) + risque de detection.'}"""

ok &= apply_patch('data.js', old_data, new_data, "data.js - restaurant : Lancer une rumeur (cible)")

print()
if ok:
    print("TOUT EST OK.")
else:
    print("ECHEC. Ne rien committer, colle le detail a Claude.")
    sys.exit(1)
