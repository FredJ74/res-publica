#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_1 = '''      texte: "Ici on sera tranquille, en plus le responsable électoral est malentendant. Ici on est au cœur du système électoral car c'est ici qu'on vote. On peut aussi voir qui est candidat aux élections par exemple. Chaque pièce est dédiée à un usage. À présent, on va aller en ville. On va déjà sortir de l'Hôtel de Ville.",'''
new_1 = '''      texte: "Ici on est au cœur du système électoral car c'est ici qu'on vote.<br><br>On peut aussi voir qui est candidat aux élections par exemple.<br><br>Chaque pièce est dédiée à un usage.<br><br>À présent, on va aller en ville. On va déjà sortir de l'Hôtel de Ville.",'''
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

old_2 = '''      texte: "Ici c'est le dispensaire. On peut se faire soigner gratuitement, ou à moindre frais. Bien sûr, si vous êtes riche, vous pouvez aller en hôpital privé. Chaque jour, on se fatigue au travail. Il est important de se reposer en dormant. Une fois par jour seulement. Idéalement, il vaut mieux dormir dans une chambre, on récupère mieux que si on dort n'importe où.",'''
new_2 = '''      texte: "Ici c'est le dispensaire. On peut se faire soigner gratuitement, ou à moindre frais. Bien sûr, si vous êtes riche, vous pouvez aller en hôpital privé pour de meilleurs soins.<br><br>Chaque jour, on se fatigue au travail. Il est important de se reposer en dormant. Une fois par jour seulement.<br><br>Idéalement, il vaut mieux dormir dans une chambre, on récupère mieux que si on dort n'importe où. Je vous montrerai juste après.",'''
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Textes Salle des Élections et Dispensaire mis à jour.")
