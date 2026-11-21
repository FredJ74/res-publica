# Forêt de Krasnov — décisions de Fred du 21/11/2026 (version définitive)

Consigne intégrale, recopiée mot pour mot. Elle remplace la version consignée au commit 78b4f2e2.

> ⚠️ **Message reçu tronqué** : il s'arrête au milieu du point 4 (« Depuis la clairière, un clic »). La suite du point 4 et les points suivants (contrôle, rapport) sont à compléter dès que Fred les renverra. Image de la clairière déposée : `images/Sovarka/Krasnov/Krasnov_foret_clairiere.webp` (commit 93d3956e).

---

Forêt de Krasnov : version définitive des décisions de Fred du 21/11/2026. Ce message REMPLACE intégralement celui consigné au commit 78b4f2e2 : mets à jour GAME-DESIGN-FORET-KRASNOV-20261121.md mot pour mot avec ce message-ci. Ordre inchangé : PR à part, après la PR interview d'accueil.

Image jointe : la clairière de coupe (souches, piles de bois, feu de camp, sentier au centre). Convertis-la en WebP qualité 85, nomme-la Krasnov_foret_clairiere.webp et dépose-la par un commit dédié. C'est l'image des souches annoncée : Krasnov_foret_coupe.webp n'est donc pas concernée et reste inchangée là où elle sert déjà.

Relis d'abord le code actuel de la forêt de Krasnov (action « S'enfoncer dans la forêt », tirage aléatoire des images bois / loup(s) / ours / Olga, rencontres) : tout ce qui n'est pas modifié ci-dessous reste inchangé.

1. Aucun coût en PA pour se déplacer
Règle générale de Fred : les déplacements à l'intérieur d'une ville ne consomment jamais de PA ; seuls les trajets d'une ville à une autre en coûtent. Aucun clic de ce chantier (portique, exploration, retour, clairière) ne consomme de PA. Si l'exploration de la forêt coûte aujourd'hui des PA, supprime ce coût. Les actions qui ne sont pas des déplacements (Récolter, combats, rencontres) gardent leurs coûts.

2. Le portique comme porte d'entrée
- Sur l'image « Entrée de la forêt » de l'Exploitation forestière de Krasnov, le portique en bois (au fond à droite, au-dessus du chemin) devient une zone cliquable.
- Au survol : curseur main et infobulle « Explorer la forêt ». Sur écran tactile, un appui sur le portique déclenche l'action.
- Signal visuel très léger, à peine perceptible : un fin contour lumineux qui pulse lentement et faiblement autour du portique. Il ne doit pas attirer l'œil plus que le reste de l'image.
- Le bouton « S'enfoncer dans la forêt » de la zone de récolte est supprimé. « Récolter » et les autres actions restent.

3. La clairière, première et dernière image
- Un clic sur le portique mène toujours à la clairière (Krasnov_foret_clairiere.webp).
- Dans la clairière, le sentier au centre est une zone cliquable, avec la même infobulle « Explorer la forêt », le même curseur et le même contour très léger. Un clic sur le sentier lance le mécanisme existant d'images aléatoires bois / loup(s) / ours / Olga. Les images suivantes restent cliquables de la même façon pour continuer l'exploration.
- Dans la clairière, l'action de pièce (bouton vert) « Retour au campement » ramène directement à l'Exploitation forestière, sans tirage ni rencontre.
- Fred fournira une image de bois supplémentaire. Le tirage ne doit jamais afficher deux fois de suite la même image de bois.

4. Retour depuis le cœur de la forêt
- Au-delà de la clairière, l'action de pièce (bouton vert) « Retour au campement » remplace tout autre moyen de sortie.
- Le retour vers la clairière se fait en deux clics au maximum :
  - Premier clic : soit le joueur arrive à la clairière, soit il s'égare. S'il s'égare, il passe par le même mécanisme aléatoire que l'aller (bois / loup(s) / ours / Olga, rencontres comprises) et le message « Était-ce le bon chemin… ? » s'affiche.
  - Second clic : il arrive toujours à la clairière, sans rencontre.
- Depuis la clairière, un clic

[… message tronqué ici, suite à recevoir …]
