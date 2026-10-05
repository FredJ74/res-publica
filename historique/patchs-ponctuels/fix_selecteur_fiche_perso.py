#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """      suivant: function() {
        queteAccueilSurbrillance('.char-card', 15000);
      }
    });
    return;
  }

  if (etape === 'guide_salle_elections' """
new = """      suivant: function() {
        queteAccueilSurbrillance('[onclick*="openSelfView"]', 15000);
      }
    });
    return;
  }

  if (etape === 'guide_salle_elections' """
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Sélecteur corrigé : la fiche personnage depuis Personnes Présentes.")
