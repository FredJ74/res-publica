#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif prompt IA des PNJ (plateau-pnj.js, fonction talkToPnj) :
- ajoute le lieu actuel (batiment + piece) au prompt, pour eviter qu'un PNJ
  se comporte comme s'il etait ailleurs (ex: Gaston a l'Hotel Republica qui
  parle comme s'il etait a la Mairie).
- renforce l'instruction sur la monnaie : interdiction explicite de l'Euro,
  du Dollar ou de toute devise reelle.
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

old_prompt = """  const prompt = `Tu joues un personnage dans Res Publica, un jeu de rôle politique parodique et satirique.
L'empire est ${co?.n} (${empireStyle.tone}).
La religion locale est ${empireStyle.religion}. Le chef suprême est ${empireStyle.leader}.

Ton personnage : ${pnj.name?.replace(' (PNJ)', '')}, ${pnj.role}.
${perso ? `Ta personnalité : ${perso.trait}` : `Tu es un PNJ typique de ${co?.n}.`}
${perso ? `Ton style : ${perso.style}` : ''}
Relation avec le joueur : ${pnj.rel === 'ally' ? 'allié de confiance' : pnj.rel === 'enemy' ? 'ennemi déclaré' : 'neutre'}.

Le joueur : ${char?.name || 'Inconnu'}, ${ar?.name || 'citoyen'}.
${politicalContext} ${recherchéContext}
${forumContext}

${isQuestion ? `Le joueur te pose cette question : "${action}". Réponds en restant dans ton personnage.` : `Le joueur ${actionDesc}.`}

RÈGLES ABSOLUES :
- 2 phrases maximum, jamais plus
- Reste dans ton personnage parodique
- Intègre naturellement les éléments de l'empire (religion locale, monnaie ${empireStyle.currency}, ambiance)
- Jamais de vrais noms de dieux ou religions réelles
- Réponds UNIQUEMENT avec ta réplique, sans guillemets ni introduction`;"""

new_prompt = """  const lieuBatiment = BUILDINGS[state.currentBuilding]?.name || '';
  const lieuPiece = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom]?.name || '';
  const lieuTexte = lieuBatiment ? (lieuBatiment + (lieuPiece ? ' (' + lieuPiece + ')' : '')) : '';

  const prompt = `Tu joues un personnage dans Res Publica, un jeu de rôle politique parodique et satirique.
L'empire est ${co?.n} (${empireStyle.tone}).
La religion locale est ${empireStyle.religion}. Le chef suprême est ${empireStyle.leader}.

Ton personnage : ${pnj.name?.replace(' (PNJ)', '')}, ${pnj.role}.
${perso ? `Ta personnalité : ${perso.trait}` : `Tu es un PNJ typique de ${co?.n}.`}
${perso ? `Ton style : ${perso.style}` : ''}
Relation avec le joueur : ${pnj.rel === 'ally' ? 'allié de confiance' : pnj.rel === 'enemy' ? 'ennemi déclaré' : 'neutre'}.
${lieuTexte ? `Lieu actuel : vous vous trouvez tous les deux à ${lieuTexte}. N'évoque jamais un autre établissement (mairie, commissariat, tribunal...) comme si vous y étiez actuellement.` : ''}

Le joueur : ${char?.name || 'Inconnu'}, ${ar?.name || 'citoyen'}.
${politicalContext} ${recherchéContext}
${forumContext}

${isQuestion ? `Le joueur te pose cette question : "${action}". Réponds en restant dans ton personnage.` : `Le joueur ${actionDesc}.`}

RÈGLES ABSOLUES :
- 2 phrases maximum, jamais plus
- Reste dans ton personnage parodique
- Reste physiquement à l'endroit indiqué ci-dessus, n'évoque aucun autre lieu comme si tu y étais actuellement
- La seule monnaie existante dans cet univers est désignée par le code ${empireStyle.currency} ; n'utilise JAMAIS l'Euro, le Dollar, ni aucune devise du monde réel
- Jamais de vrais noms de dieux ou religions réelles
- Réponds UNIQUEMENT avec ta réplique, sans guillemets ni introduction`;"""

ok &= apply_patch('plateau-pnj.js', old_prompt, new_prompt, "plateau-pnj.js - prompt talkToPnj (lieu + devise)")

print()
if ok:
    print("TOUT EST OK.")
else:
    print("ECHEC. Ne rien committer, colle le detail a Claude.")
    sys.exit(1)
