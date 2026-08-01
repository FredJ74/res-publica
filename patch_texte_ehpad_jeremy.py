#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """      texte: "Ici c'est le dispensaire. On peut se faire soigner gratuitement, ou à moindre frais. Bien sûr, si vous êtes riche, vous pouvez aller en hôpital privé pour de meilleurs soins.<br><br>Chaque jour, on se fatigue au travail. Il est important de se reposer en dormant. Une fois par jour seulement.<br><br>Idéalement, il vaut mieux dormir dans une chambre, on récupère mieux que si on dort n'importe où. Je vous montrerai juste après.","""
new = """      texte: "Ici c'est le dispensaire. On peut se faire soigner gratuitement, ou à moindre frais. Bien sûr, si vous êtes riche, vous pouvez aller en hôpital privé pour de meilleurs soins.<br><br>Il y a aussi nos anciens, ici, à l'EHPAD. Ils sont un peu la mémoire de la ville, vous savez.<br><br>Chaque jour, on se fatigue au travail. Il est important de se reposer en dormant. Une fois par jour seulement.<br><br>Idéalement, il vaut mieux dormir dans une chambre, on récupère mieux que si on dort n'importe où. Je vous montrerai juste après.","""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Mention de l'EHPAD ajoutée au discours de Jérémy sur le Dispensaire.")
