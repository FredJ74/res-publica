# Interview d'accueil des nouveaux personnages — décisions de Fred du 21/11/2026

Consigne intégrale, recopiée mot pour mot. À traiter dans une PR à part, après la PR fenêtres et forum du 21/11.

---

Nouveau chantier : interview d'accueil des nouveaux personnages, décisions de Fred du 21/11/2026. PR à part, après la PR fenêtres et forum du 21/11. Contexte : Tom Tom (personnage de Fred, hors de Luthécia) a reçu un mail de Jodie Moitout pour une interview ; il a rempli les cinq réponses et l'envoi a été refusé avec « Indisponible – Portrait disponible après le premier jour ».

Consigne d'abord ces décisions mot pour mot sur main dans GAME-DESIGN-INTERVIEW-ACCUEIL-20261121.md.

1. Le bon journaliste
- Jodie Moitout est journaliste à l'antenne de Luthécia : elle n'interviewe que les personnages de Luthécia.
- Chaque ville a son antenne locale de presse. L'invitation à l'interview est envoyée par le journaliste de l'antenne de la ville où se trouve le personnage, dans toutes les villes de tous les pays (Sovarka comprise).
- Relis dans le code et la base les antennes locales existantes et leurs journalistes. Si une antenne n'a pas encore de journaliste nommé, n'en invente pas : liste-la dans ton rapport, Fred fournira le nom et le portrait. En attendant, cette antenne n'envoie pas d'invitation.

2. Une interview envoyée est toujours publiable
- Si un journaliste envoie une invitation, les réponses doivent pouvoir être envoyées et le portrait publié, quel que soit l'âge du personnage, premier jour compris.
- Supprime le verrou « Portrait disponible après le premier jour » pour les réponses à une invitation. Si ce verrou sert ailleurs, garde-le là, mais aucune invitation ne doit jamais aboutir à un envoi refusé.
- Règle générale : on ne laisse jamais un joueur remplir un formulaire qu'il ne pourra pas envoyer. Toute condition bloquante se vérifie avant l'ouverture du formulaire, pas au moment de l'envoi.

3. Lisibilité
- Le texte de chaque question (actuellement en petites capitales rouge sombre sur fond presque noir) devient le texte le plus lisible de la fenêtre : couleur claire à fort contraste, taille au moins égale à celle du texte courant, casse normale.
- Vérifie le contraste de toute la fenêtre d'interview (indications, boutons « Précédent » et d'envoi) au niveau AA des règles d'accessibilité WCAG.

4. Incohérences de la fenêtre de courrier
- La fenêtre qui affiche un mail s'intitule « Forum » : elle doit porter le titre de ce qu'elle affiche (« Courrier » quand on lit un mail, « Forum » quand on lit le forum).
- La Boîte Mail affiche « Aucun message » pendant qu'on lit un mail reçu : le compteur doit refléter les messages réels (nombre de messages, et de non lus).

5. Contrôle
Tests couvrant : invitation envoyée par le journaliste de la ville du personnage, aucune invitation de Jodie hors de Luthécia, envoi des réponses possible le premier jour, titre de fenêtre correct, compteur de la Boîte Mail correct.
Rapport attendu : antennes sans journaliste nommé, autres usages du verrou du premier jour, ce qui reste à décider par Fred.
