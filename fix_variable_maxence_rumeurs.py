#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (/maxence/i.test(action)) {
    if (nomCourtEnigme === 'Pat Hounette') {"""
new = """  const nomCourtMaxenceRumeur = (pnj.name || '').replace(' (PNJ)', '').trim();
  if (/maxence/i.test(action)) {
    if (nomCourtMaxenceRumeur === 'Pat Hounette') {"""
assert content.count(old) == 1, f"bloc 1 : trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

old_2 = """    if (nomCourtEnigme === 'Florian Grès') {"""
new_2 = """    if (nomCourtMaxenceRumeur === 'Florian Grès') {"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

old_3 = """    if (nomCourtEnigme === 'Jean-Pierre Ciseaux') {"""
new_3 = """    if (nomCourtMaxenceRumeur === 'Jean-Pierre Ciseaux') {"""
assert content.count(old_3) == 1, f"bloc 3 : trouvé {content.count(old_3)} fois (attendu 1)"
content = content.replace(old_3, new_3)

old_4 = """    if (nomCourtEnigme === 'Louis Chevillard') {
      speech.textContent = "En quarante ans de carrière, j'ai vu des braqueurs, des meurtriers... mais Maxence... celui-là me fait froid dans le dos.";
      return;
    }
  }

  // Enigme du portrait disparu : Clerc Delhune"""
new_4 = """    if (nomCourtMaxenceRumeur === 'Louis Chevillard') {
      speech.textContent = "En quarante ans de carrière, j'ai vu des braqueurs, des meurtriers... mais Maxence... celui-là me fait froid dans le dos.";
      return;
    }
  }

  // Enigme du portrait disparu : Clerc Delhune"""
assert content.count(old_4) == 1, f"bloc 4 : trouvé {content.count(old_4)} fois (attendu 1)"
content = content.replace(old_4, new_4)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Bug corrigé : variable locale dédiée, plus de conflit avec la déclaration plus bas.")
