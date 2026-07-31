#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_1 = '''    texte: "Hey, vous ! Vous n'etes pas autorise a rester ici ! Le President va bientot sortir ! Et puis vous etes nouveau, on ne vous a jamais vu, je me trompe ? Allez vous presenter a l'Hotel de Ville sinon c'est au commissariat que vous finirez.",'''
new_1 = '''    texte: "Hey, vous !<br><br>Vous n'êtes pas autorisé à rester ici ! Le Président va bientôt sortir !<br><br>Et puis vous êtes nouveau, on ne vous a jamais vu, je me trompe ? Allez vous présenter à l'Hôtel de Ville sinon c'est au commissariat que vous finirez.",'''
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

old_2 = '''    texte: "Je veux bien, mais ou est l'Hotel de Ville ?",'''
new_2 = '''    texte: "Je veux bien, mais ou est l'Hotel de Ville ?",'''
# (inchangé, laissé pour reference)

old_3 = '''    texte: "Continuez sur cette rue, ensuite il y aura un croisement. Continuez encore une fois sur la meme rue, et vous trouverez l'Hotel de Ville. Adressez-vous au secretaire municipal. Il vous parlera surement des impots, mais repondez-lui simplement que vous etes nouveau, cela devrait l'adoucir.",'''
new_3 = '''    texte: "Continuez sur cette rue, ensuite il y aura un croisement.<br><br>Continuez encore une fois sur la même rue, et vous trouverez l'Hôtel de Ville.<br><br>Adressez-vous au secrétaire municipal <strong>Petit</strong>.<br><br>Il vous parlera sûrement des impôts, mais répondez-lui simplement que <strong>vous êtes nouveau</strong>, cela devrait l'adoucir.",'''
assert content.count(old_3) == 1, f"bloc 3 : trouvé {content.count(old_3)} fois (attendu 1)"
content = content.replace(old_3, new_3)

old_4 = '''    texte: "D'accord... merci...",'''
new_4 = '''    texte: "D'accord... merci... je lui dirai que je suis nouveau...",'''
assert content.count(old_4) == 1, f"bloc 4 : trouvé {content.count(old_4)} fois (attendu 1)"
content = content.replace(old_4, new_4)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Textes du garde et réponses du PJ mis à jour.")
