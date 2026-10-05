#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif texte IA tronque + markdown parasite :
- confirmerLancerRumeur, confirmerFabriquerKompromat, confirmerEscortPiege
  utilisaient un max_tokens trop bas (60-80), ce qui tronquait le texte en
  plein milieu (ex: "...comme ⚠ Objet illegal").
- Le modele generait aussi parfois du Markdown (titres #, gras **), affiche
  tel quel puisque l'interface ne le met pas en forme. Ajout d'une consigne
  explicite "texte brut, sans markdown" dans les 3 prompts.
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
# 1) confirmerLancerRumeur
# ------------------------------------------------------------------
old1 = """          max_tokens: 80,
          messages: [{
            role: 'user',
            content: 'Res Publica, jeu de rôle politique parodique et satirique. Une rumeur compromettante vient d\\'être lancée contre ' + nomCible + '. Génère UNE phrase de rumeur courte (1-2 phrases max), diffamatoire mais crédible, ton satirique et cynique. Réponds UNIQUEMENT avec la rumeur, sans introduction.'
          }]"""

new1 = """          max_tokens: 150,
          messages: [{
            role: 'user',
            content: 'Res Publica, jeu de rôle politique parodique et satirique. Une rumeur compromettante vient d\\'être lancée contre ' + nomCible + '. Génère UNE phrase de rumeur courte (1-2 phrases max), diffamatoire mais crédible, ton satirique et cynique. Réponds UNIQUEMENT avec la rumeur, en texte brut sans markdown (pas de #, pas de **), sans introduction.'
          }]"""

ok &= apply_patch('plateau-pnj.js', old1, new1, "confirmerLancerRumeur - max_tokens + sans markdown")

# ------------------------------------------------------------------
# 2) confirmerFabriquerKompromat
# ------------------------------------------------------------------
old2 = """  const prompt = `Tu joues dans Res Publica, jeu politique parodique.
${nomAgent} a recueilli des informations compromettantes sur ${nomCible} dans l'empire ${co?.n}.
Génère UNE révélation compromettante, parodique et drôle (2 phrases max). Style scandale politique. Pas de vrais noms de personnes réelles. Pas de religions réelles.`;

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ model: 'claude-haiku-4-5-20251001', max_tokens: 60, messages: [{ role: 'user', content: prompt }] })
    });"""

new2 = """  const prompt = `Tu joues dans Res Publica, jeu politique parodique.
${nomAgent} a recueilli des informations compromettantes sur ${nomCible} dans l'empire ${co?.n}.
Génère UNE révélation compromettante, parodique et drôle (2 phrases max). Style scandale politique. Pas de vrais noms de personnes réelles. Pas de religions réelles. Réponds en texte brut uniquement, sans markdown (pas de #, pas de **, pas de titre).`;

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ model: 'claude-haiku-4-5-20251001', max_tokens: 150, messages: [{ role: 'user', content: prompt }] })
    });"""

ok &= apply_patch('plateau-pnj.js', old2, new2, "confirmerFabriquerKompromat - max_tokens + sans markdown")

# ------------------------------------------------------------------
# 3) confirmerEscortPiege
# ------------------------------------------------------------------
old3 = """    const prompt = 'Res Publica, jeu politique parodique. ' + nomCible + ' vient d\\'être piégé(e) par une escort dans un scandale compromettant. Génère UN titre de scandale parodique (1 phrase max, style journal à scandales).';
    let scandale = nomCible + ' impliqué(e) dans un scandale compromettant avec une escort.';
    try {
      const resp = await fetch('/api/chat', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({ model: 'claude-haiku-4-5-20251001', max_tokens: 60, messages: [{ role: 'user', content: prompt }] })
      });"""

new3 = """    const prompt = 'Res Publica, jeu politique parodique. ' + nomCible + ' vient d\\'être piégé(e) par une escort dans un scandale compromettant. Génère UN titre de scandale parodique (1 phrase max, style journal à scandales). Réponds en texte brut uniquement, sans markdown (pas de #, pas de **).';
    let scandale = nomCible + ' impliqué(e) dans un scandale compromettant avec une escort.';
    try {
      const resp = await fetch('/api/chat', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({ model: 'claude-haiku-4-5-20251001', max_tokens: 120, messages: [{ role: 'user', content: prompt }] })
      });"""

ok &= apply_patch('plateau-pnj.js', old3, new3, "confirmerEscortPiege - max_tokens + sans markdown")

print()
if ok:
    print("TOUT EST OK.")
else:
    print("ECHEC. Ne rien committer, colle le detail a Claude.")
    sys.exit(1)
