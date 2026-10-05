#!/usr/bin/env python3
import re

PATH = "plateau-navigation.js"
SCALE = 1.4

with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Recalculer toutes les coordonnees du bloc 'capitale' de PLAN_LAYOUTS ---
start_marker = "  capitale: {"
end_marker = "\n  },\n  ville_a: {"

start_idx = content.find(start_marker)
assert start_idx != -1, "bloc capitale introuvable"
end_idx = content.find(end_marker, start_idx)
assert end_idx != -1, "fin du bloc capitale introuvable"

bloc = content[start_idx:end_idx]

def scale_coords(match):
    nums = [int(n.strip()) for n in match.group(1).split(',')]
    scaled = [round(n * SCALE) for n in nums]
    return '[' + ', '.join(str(n) for n in scaled) + ']'

nouveau_bloc = re.sub(r'\[\s*(-?\d+,\s*-?\d+,\s*-?\d+,\s*-?\d+)\s*\]', scale_coords, bloc)

assert nouveau_bloc != bloc, "aucune coordonnee n'a ete modifiee, verifier le motif"
content = content[:start_idx] + nouveau_bloc + content[end_idx:]

# --- 2. Recalculer le cadre SVG fixe pour Luthecia (SVG_W, SVG_H, perimX/Y/W/H) ---
old_cadre = """  if (estLuthecia) {
    // Luthecia : cadre valide visuellement avec Fred, ne pas toucher.
    SVG_W = 680; SVG_H = 600;
    perimX = 130; perimY = 150; perimW = 420; perimH = 370;
  } else {"""
new_cadre = """  if (estLuthecia) {
    // Luthecia : cadre agrandi le 5 aout 2026 (facteur x1.4, meilleure lisibilite),
    // disposition relative inchangee et validee avec Fred.
    SVG_W = 952; SVG_H = 840;
    perimX = 182; perimY = 210; perimW = 588; perimH = 518;
  } else {"""
assert content.count(old_cadre) == 1, f"cadre SVG : trouvé {content.count(old_cadre)} fois (attendu 1)"
content = content.replace(old_cadre, new_cadre)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Plan de Luthécia agrandi (x1.4) : toutes les coordonnées et le cadre SVG recalculés automatiquement.")
