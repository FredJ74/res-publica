#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Contexte special pour l'IA (personnalite evasive, mysterieuse, jamais de reponse nette) ---
old_1 = """${(pnj.name || '').replace(' (PNJ)', '').trim() === 'Jérémy' ? (() => {"""
new_1 = """${(pnj.name || '').replace(' (PNJ)', '').trim() === 'Maxence Monfils' ? `Contexte special : tu es un enfant d'une dizaine d'annees, curieux, insaisissable et un peu mysterieux. Tu passes ton temps a observer des insectes et des plantes avec ta loupe. Tu vouvoies ou tutoies selon ton humeur (tu es un enfant, pas tenu a la politesse formelle). Tu ne reponds JAMAIS de facon claire ou directe aux questions ; reste evasif, enigmatique, parfois carrement hors sujet, sans jamais mentir grossierement ni etre desagreable. Tu ne dis jamais explicitement que tu es recherche par des organisations environnementales ni que tu arraches des ailes d'insectes, mais tu peux le suggerer de facon detournee et innocente si on te pose une question qui s'en approche. Reponds en 1 a 2 phrases maximum, jamais plus.` : ''}
${(pnj.name || '').replace(' (PNJ)', '').trim() === 'Jérémy' ? (() => {"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- 2. Compteur de questions + fuite vers l'autre lieu apres la 2eme ---
old_2 = """  // Quete d'accueil : reponse d'accueil scriptee de Jeremy a la toute premiere ouverture de sa"""
new_2 = """  // Maxence Monfils : limite de 2 questions avant qu'il ne detale vers l'autre lieu (parc/serre).
  const nomCourtMaxence = (pnj.name || '').replace(' (PNJ)', '').trim();
  if (nomCourtMaxence === 'Maxence Monfils' && action !== 'bonjour') {
    if (!state.char.maxence) state.char.maxence = { lieu: 'parc', questions: 0 };
    state.char.maxence.questions = (state.char.maxence.questions || 0) + 1;

    if (state.char.maxence.questions > 2) {
      speech.textContent = "Maxence n'est plus là... il a déjà détalé ailleurs.";
      return;
    }
    if (state.char.maxence.questions === 2) {
      const autreLieu = state.char.maxence.lieu === 'parc' ? 'serre' : 'parc';
      setTimeout(function() {
        if (!state.char.maxence) return;
        state.char.maxence.lieu = autreLieu;
        state.char.maxence.questions = 0;
        if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
        if (typeof showToast === 'function') {
          showToast('Maxence a détalé', 'Il est parti vers ' + (autreLieu === 'serre' ? 'la serre' : 'le parc') + '...', false);
        }
        if (typeof maxenceVerifierPresence === 'function') {
          maxenceVerifierPresence(state.currentBuilding, state.currentRoom);
        }
      }, 4000);
    }
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  }

  // Quete d'accueil : reponse d'accueil scriptee de Jeremy a la toute premiere ouverture de sa"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Comportement conversationnel de Maxence ajouté (2 questions max, puis fuite).")
