#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif ecouterRumeurs (plateau-actions-illegales-rumeurs.js) :
- ajoute un vrai jet de reussite base sur le successRate de l'ordre
- supprime totalement le repli IA generique (rumeur inventee)
- si echec du jet OU aucune rumeur vraie disponible : message neutre
  "Rien de croustillant a se mettre sous la dent aujourd'hui."
- plateau-router.js : passe successRate a ecouterRumeurs()
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
# 1) plateau-actions-illegales-rumeurs.js -- ecouterRumeurs
# ------------------------------------------------------------------
old_fn = """async function ecouterRumeurs() {
  const ville = WORLD[state.country]?.[state.currentCity]?.name || 'la ville';
  const char = state.char;
  const pnjPresents = ['Le Commissaire', 'Un député', 'Un journaliste', 'Un commerçant', 'Un inconnu'];
  const source = pnjPresents[Math.floor(Math.random() * pnjPresents.length)];

  showToast('Vous tendez l\\'oreille...', 'En attente d\\'une information.', false);

  // 1. Tenter d'abord une VRAIE rumeur basee sur une action reellement tracee
  let actionsDisponibles = [];
  if (typeof sbGetActionsTracables === 'function') {
    try {
      actionsDisponibles = await sbGetActionsTracables(state.country, state.currentCity, state.day || 1);
      // Ne jamais reveler sa propre action a soi-meme
      actionsDisponibles = actionsDisponibles.filter(a => a.auteur !== char?.name);
    } catch(e) {}
  }

  if (actionsDisponibles.length > 0 && Math.random() < 0.6) {
    const action = actionsDisponibles[Math.floor(Math.random() * actionsDisponibles.length)];
    const formulateur = FORMULATIONS_RUMEUR_VRAIE[action.type_action];
    if (formulateur) {
      const texte = formulateur(action.auteur, action.cible || 'quelqu\\'un');
      document.getElementById('postes-modal-title').textContent = source + ' vous glisse à l\\'oreille...';
      document.getElementById('postes-body').innerHTML =
        '<div style="padding:1.2rem">' +
        '<div style="font-size:.85rem;color:#c0b090;font-style:italic;line-height:1.7;font-family:Crimson Pro,serif">"' + texte + '"</div>' +
        '<div style="font-size:.68rem;color:#9a8a68;margin-top:.8rem">Source : ' + source + ' · Information vérifiée</div>' +
        '</div>';
      document.getElementById('modal-postes').classList.add('open');
      state.inf = Math.min(100, state.inf + 1);
      updateUI();
      addJournalEntry('Rumeur entendue à ' + ville, 'event-info');
      return;
    }
  }

  // 2. Fallback — generation IA generique si aucune vraie action disponible
  const context = 'Empire : ' + (COUNTRIES[state.country]?.n || 'Républia') +
    '. Ville : ' + ville +
    '. Votre personnage : ' + (char?.name || 'Anonyme') +
    (state.poste ? ', ' + state.poste.name : '') +
    '. Jour ' + state.day + '.' +
    (state.guerres?.length ? ' Guerre en cours contre : ' + state.guerres.map(g=>g.nom).join(', ') + '.' : '') +
    (state.electionsEnCours?.length ? ' Elections en cours.' : '');

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'claude-sonnet-4-5',
        max_tokens: 200,
        messages: [{
          role: 'user',
          content: 'Tu es le narrateur d\\'un jeu de rôle politique parodique et satirique. Contexte : ' + context + '. Génère UNE rumeur courte (2-3 phrases max) que "' + source + '" chuchote à l\\'oreille du joueur. La rumeur doit être crédible, légèrement compromettante pour un personnage politique ou une institution, et adaptée au contexte. Ton satirique et cynique. Réponds UNIQUEMENT avec la rumeur, sans introduction.'
        }]
      })
    });
    const data = await resp.json();
    const rumeur = data.content?.[0]?.text || 'Rien d\\'intéressant à rapporter aujourd\\'hui.';

    document.getElementById('postes-modal-title').textContent = source + ' vous glisse à l\\'oreille...';
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1.2rem">' +
      '<div style="font-size:.85rem;color:#c0b090;font-style:italic;line-height:1.7;font-family:Crimson Pro,serif">"' + rumeur + '"</div>' +
      '<div style="font-size:.68rem;color:#9a8a68;margin-top:.8rem">Source : ' + source + ' · Fiabilité incertaine</div>' +
      '</div>';
    document.getElementById('modal-postes').classList.add('open');

    state.inf = Math.min(100, state.inf + 1);
    updateUI();
    addJournalEntry('Rumeur entendue à ' + ville, 'event-info');

  } catch(e) {
    showToast('Silence', 'Personne ne parle aujourd\\'hui.', false);
  }
}"""

new_fn = """async function ecouterRumeurs(successRate) {
  const ville = WORLD[state.country]?.[state.currentCity]?.name || 'la ville';
  const char = state.char;
  const pnjPresents = ['Le Commissaire', 'Un député', 'Un journaliste', 'Un commerçant', 'Un inconnu'];
  const source = pnjPresents[Math.floor(Math.random() * pnjPresents.length)];

  showToast('Vous tendez l\\'oreille...', 'En attente d\\'une information.', false);

  const roll = Math.random() * 100;
  const succes = roll < (successRate ?? 70);

  // Rumeurs VRAIES uniquement, basees sur une action reellement tracee.
  // Aucun repli IA/invente : si le jet echoue ou qu'il n'y a rien a reveler,
  // le joueur repart simplement bredouille.
  let actionsDisponibles = [];
  if (succes && typeof sbGetActionsTracables === 'function') {
    try {
      actionsDisponibles = await sbGetActionsTracables(state.country, state.currentCity, state.day || 1);
      // Ne jamais reveler sa propre action a soi-meme
      actionsDisponibles = actionsDisponibles.filter(a => a.auteur !== char?.name);
    } catch(e) {}
  }

  if (succes && actionsDisponibles.length > 0) {
    const action = actionsDisponibles[Math.floor(Math.random() * actionsDisponibles.length)];
    const formulateur = FORMULATIONS_RUMEUR_VRAIE[action.type_action];
    if (formulateur) {
      const texte = formulateur(action.auteur, action.cible || 'quelqu\\'un');
      document.getElementById('postes-modal-title').textContent = source + ' vous glisse à l\\'oreille...';
      document.getElementById('postes-body').innerHTML =
        '<div style="padding:1.2rem">' +
        '<div style="font-size:.85rem;color:#c0b090;font-style:italic;line-height:1.7;font-family:Crimson Pro,serif">"' + texte + '"</div>' +
        '<div style="font-size:.68rem;color:#9a8a68;margin-top:.8rem">Source : ' + source + ' · Information vérifiée</div>' +
        '</div>';
      document.getElementById('modal-postes').classList.add('open');
      state.inf = Math.min(100, state.inf + 1);
      updateUI();
      addJournalEntry('Rumeur entendue à ' + ville, 'event-info');
      return;
    }
  }

  // Echec du jet ou aucune rumeur vraie disponible
  document.getElementById('postes-modal-title').textContent = source + '...';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1.2rem">' +
    '<div style="font-size:.85rem;color:#8a8060;font-style:italic;line-height:1.7;font-family:Crimson Pro,serif">Rien de croustillant à se mettre sous la dent aujourd\\'hui.</div>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}"""

ok &= apply_patch('plateau-actions-illegales-rumeurs.js', old_fn, new_fn, "plateau-actions-illegales-rumeurs.js - ecouterRumeurs (rumeurs vraies uniquement)")

# ------------------------------------------------------------------
# 2) plateau-router.js -- passer successRate
# ------------------------------------------------------------------
old_route = """  if (fn === 'ecouter_rumeurs')        { ecouterRumeurs(); return; }"""
new_route = """  if (fn === 'ecouter_rumeurs')        { ecouterRumeurs(successRate); return; }"""

ok &= apply_patch('plateau-router.js', old_route, new_route, "plateau-router.js - passer successRate a ecouterRumeurs")

print()
if ok:
    print("TOUT EST OK.")
else:
    print("ECHEC. Ne rien committer, colle le detail a Claude.")
    sys.exit(1)
