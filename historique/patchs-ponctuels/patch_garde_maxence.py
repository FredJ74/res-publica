#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """    if (nomCourtMaxenceRumeur === 'Louis Chevillard') {
      speech.textContent = "En quarante ans de carrière, j'ai vu des braqueurs, des meurtriers... mais Maxence... celui-là me fait froid dans le dos.";
      return;
    }
  }"""
new = """    if (nomCourtMaxenceRumeur === 'Louis Chevillard') {
      speech.textContent = "En quarante ans de carrière, j'ai vu des braqueurs, des meurtriers... mais Maxence... celui-là me fait froid dans le dos.";
      return;
    }
    if (nomCourtMaxenceRumeur === 'Garde Republicain') {
      speech.textContent = "J'ai déjà tenu tête à des manifestants, des émeutiers, même un coup d'État... Mais si je croise Maxence Monfils dans une ruelle un jour, je change de trottoir, foi de Garde Républicain.";
      return;
    }
  }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Rumeur du Garde Républicain ajoutée.")
