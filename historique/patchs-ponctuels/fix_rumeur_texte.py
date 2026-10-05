#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif : le succes de confirmerLancerRumeur genere maintenant un vrai texte
de rumeur (via l'API, meme principe que le scandale de confirmerEscortPiege)
au lieu d'un message generique sans detail.
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

old_success = """  if (succes) {
    const perte = Math.floor(Math.random() * 16) + 5; // entre 5 et 20
    if (typeof sbAjusterPopJoueur === 'function') {
      sbAjusterPopJoueur(nomCible, -perte).catch(() => {});
    }
    addExternalEvent('🗯 Une rumeur compromettante circule sur ' + nomCible + '.');
    addJournalEntry('Rumeur lancée avec succès contre ' + nomCible + ' (-' + perte + ' POP).', 'event-good');
    showToast('Rumeur lancée !', 'La rumeur se propage. ' + nomCible + ' perd ' + perte + ' POP.', true, true);
    if (typeof tracerActionPourRumeur === 'function') tracerActionPourRumeur('fausse_rumeur', nomCible);
    if (typeof checkDetection === 'function') checkDetection('fausse_rumeur', 'success');
  } else {"""

new_success = """  if (succes) {
    const perte = Math.floor(Math.random() * 16) + 5; // entre 5 et 20

    let texteRumeur = nomCible + ' serait impliqué(e) dans une affaire compromettante.';
    try {
      const resp = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'claude-haiku-4-5-20251001',
          max_tokens: 80,
          messages: [{
            role: 'user',
            content: 'Res Publica, jeu de rôle politique parodique et satirique. Une rumeur compromettante vient d\\'être lancée contre ' + nomCible + '. Génère UNE phrase de rumeur courte (1-2 phrases max), diffamatoire mais crédible, ton satirique et cynique. Réponds UNIQUEMENT avec la rumeur, sans introduction.'
          }]
        })
      });
      const data = await resp.json();
      texteRumeur = data.content?.[0]?.text?.trim() || texteRumeur;
    } catch(e) {}

    if (typeof sbAjusterPopJoueur === 'function') {
      sbAjusterPopJoueur(nomCible, -perte).catch(() => {});
    }

    document.getElementById('postes-modal-title').textContent = '🗯 Rumeur lancée !';
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1.2rem">' +
      '<div style="font-size:.85rem;color:#c0b090;font-style:italic;line-height:1.7;font-family:Crimson Pro,serif">"' + texteRumeur + '"</div>' +
      '<div style="font-size:.68rem;color:#9a8a68;margin-top:.8rem">Cible : ' + nomCible + ' · -' + perte + ' POP</div>' +
      '</div>';
    document.getElementById('modal-postes').classList.add('open');

    addExternalEvent('🗯 ' + texteRumeur);
    addJournalEntry('Rumeur lancée avec succès contre ' + nomCible + ' : "' + texteRumeur.substring(0,60) + '" (-' + perte + ' POP).', 'event-good');
    if (typeof tracerActionPourRumeur === 'function') tracerActionPourRumeur('fausse_rumeur', nomCible);
    if (typeof checkDetection === 'function') checkDetection('fausse_rumeur', 'success');
  } else {"""

ok &= apply_patch('plateau-pnj.js', old_success, new_success, "plateau-pnj.js - confirmerLancerRumeur genere un vrai texte de rumeur")

print()
if ok:
    print("TOUT EST OK.")
else:
    print("ECHEC. Ne rien committer, colle le detail a Claude.")
    sys.exit(1)
