#!/usr/bin/env python3
PATH = "plateau-core.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  // Vérification mails toutes les 2 minutes
  verifierNouveauxMails();
  setInterval(verifierNouveauxMails, 120000);"""

new = """  // Vérification mails toutes les 2 minutes
  verifierNouveauxMails();
  setInterval(verifierNouveauxMails, 120000);

  // Vérification des objets reçus (dons d'un autre joueur) toutes les 2 minutes
  verifierObjetsRecus();
  setInterval(verifierObjetsRecus, 120000);"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Vérification périodique des objets reçus branchée (même rythme que les mails).")
