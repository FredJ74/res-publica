#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """    if (histOpen.length >= 2 && pnj.job !== 'escort') {
      // Afficher le dernier échange
      const lastReply = histOpen.filter(h => h.role === 'assistant').slice(-1)[0];"""
new = """    if (pnjNameClean === 'Jérémy' && histOpen.length >= 2) {
      // Ne jamais reafficher la derniere reponse pour Jeremy (peut preter a confusion selon
      // le lieu/contexte au moment de la reouverture) : on repart sur une invitation neutre.
      const speechElJeremy = document.getElementById('pnj-speech');
      if (speechElJeremy) speechElJeremy.textContent = 'Une autre question ?';
    } else if (histOpen.length >= 2 && pnj.job !== 'escort') {
      // Afficher le dernier échange
      const lastReply = histOpen.filter(h => h.role === 'assistant').slice(-1)[0];"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Jérémy affiche 'Une autre question ?' à la réouverture, plus la dernière réponse.")
