#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Fonction de suivi des deux succes (independante du systeme OBJECTIFS_SECRETS par archetype) ---
old_1 = """  const nomCourtMaxenceRumeur = (pnj.name || '').replace(' (PNJ)', '').trim();"""
new_1 = """// Deux succes caches lies a Maxence Monfils, universels (independants de l'archetype du
// joueur, contrairement au systeme OBJECTIFS_SECRETS). Stockes sur state.char.succesMaxence.
function verifierSuccesMaxence(cle) {
  if (typeof state === 'undefined' || !state.char) return;
  if (!state.char.succesMaxence) state.char.succesMaxence = { parle: false, rumeurs: [] };

  if (cle === 'parle' && !state.char.succesMaxence.parle) {
    state.char.succesMaxence.parle = true;
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(function() {});
    if (typeof showToast === 'function') showToast('🎯 Succès débloqué', 'Le fugitif du jardin botanique', true);
    if (typeof addJournalEntry === 'function') addJournalEntry('🎯 Succès débloqué : Le fugitif du jardin botanique', 'event-good');
    return;
  }

  if (cle && cle !== 'parle' && !state.char.succesMaxence.rumeurs.includes(cle)) {
    state.char.succesMaxence.rumeurs.push(cle);
    const toutesLesRumeurs = ['pat', 'florian', 'ciseaux', 'chevillard', 'garde'];
    const complet = toutesLesRumeurs.every(function(n) { return state.char.succesMaxence.rumeurs.includes(n); });
    if (complet && !state.char.succesMaxence.legendeUrbaine) {
      state.char.succesMaxence.legendeUrbaine = true;
      if (typeof showToast === 'function') showToast('🎯 Succès débloqué', 'Légende urbaine', true);
      if (typeof addJournalEntry === 'function') addJournalEntry('🎯 Succès débloqué : Légende urbaine', 'event-good');
    }
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(function() {});
  }
}

  const nomCourtMaxenceRumeur = (pnj.name || '').replace(' (PNJ)', '').trim();"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- 2. Appeler le suivi depuis chacune des 5 rumeurs ---
old_2 = """    if (nomCourtMaxenceRumeur === 'Pat Hounette') {
      speech.textContent = "Chut... si Maxence apprend qu'il y a des scarabées ici, on est mal...";
      return;
    }
    if (nomCourtMaxenceRumeur === 'Florian Grès') {
      speech.textContent = "Je le surveille depuis ce matin. Impossible de savoir où il est passé...";
      return;
    }
    if (nomCourtMaxenceRumeur === 'Jean-Pierre Ciseaux') {
      speech.textContent = "Les orchidées ne risquent rien... ce sont les insectes qui m'inquiètent.";
      return;
    }
    if (nomCourtMaxenceRumeur === 'Louis Chevillard') {
      speech.textContent = "En quarante ans de carrière, j'ai vu des braqueurs, des meurtriers... mais Maxence... celui-là me fait froid dans le dos.";
      return;
    }
    if (nomCourtMaxenceRumeur === 'Garde Republicain') {
      speech.textContent = "J'ai déjà tenu tête à des manifestants, des émeutiers, même un coup d'État... Mais si je croise Maxence Monfils dans une ruelle un jour, je change de trottoir, foi de Garde Républicain.";
      return;
    }
  }"""
new_2 = """    if (nomCourtMaxenceRumeur === 'Pat Hounette') {
      speech.textContent = "Chut... si Maxence apprend qu'il y a des scarabées ici, on est mal...";
      if (typeof verifierSuccesMaxence === 'function') verifierSuccesMaxence('pat');
      return;
    }
    if (nomCourtMaxenceRumeur === 'Florian Grès') {
      speech.textContent = "Je le surveille depuis ce matin. Impossible de savoir où il est passé...";
      if (typeof verifierSuccesMaxence === 'function') verifierSuccesMaxence('florian');
      return;
    }
    if (nomCourtMaxenceRumeur === 'Jean-Pierre Ciseaux') {
      speech.textContent = "Les orchidées ne risquent rien... ce sont les insectes qui m'inquiètent.";
      if (typeof verifierSuccesMaxence === 'function') verifierSuccesMaxence('ciseaux');
      return;
    }
    if (nomCourtMaxenceRumeur === 'Louis Chevillard') {
      speech.textContent = "En quarante ans de carrière, j'ai vu des braqueurs, des meurtriers... mais Maxence... celui-là me fait froid dans le dos.";
      if (typeof verifierSuccesMaxence === 'function') verifierSuccesMaxence('chevillard');
      return;
    }
    if (nomCourtMaxenceRumeur === 'Garde Republicain') {
      speech.textContent = "J'ai déjà tenu tête à des manifestants, des émeutiers, même un coup d'État... Mais si je croise Maxence Monfils dans une ruelle un jour, je change de trottoir, foi de Garde Républicain.";
      if (typeof verifierSuccesMaxence === 'function') verifierSuccesMaxence('garde');
      return;
    }
  }"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

# --- 3. Appeler le suivi quand le joueur parle reellement a Maxence lui-meme ---
old_3 = """  if (nomCourtMaxence === 'Maxence Monfils' && action !== 'bonjour') {
    if (!state.char.maxence) state.char.maxence = { lieu: 'parc', questions: 0 };
    state.char.maxence.questions = (state.char.maxence.questions || 0) + 1;"""
new_3 = """  if (nomCourtMaxence === 'Maxence Monfils' && action !== 'bonjour') {
    if (!state.char.maxence) state.char.maxence = { lieu: 'parc', questions: 0 };
    state.char.maxence.questions = (state.char.maxence.questions || 0) + 1;
    if (typeof verifierSuccesMaxence === 'function') verifierSuccesMaxence('parle');"""
assert content.count(old_3) == 1, f"bloc 3 : trouvé {content.count(old_3)} fois (attendu 1)"
content = content.replace(old_3, new_3)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Les deux succès cachés de Maxence Monfils ajoutés (universels, indépendants de l'archétype).")
