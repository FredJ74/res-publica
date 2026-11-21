# Forêt de Krasnov : entrée depuis l'exploitation forestière — décisions de Fred du 21/11/2026

Consigne intégrale, recopiée mot pour mot. PR à part, dans le lot de Krasnov, après la PR interview d'accueil du 21/11.

---

Nouveau chantier : entrée dans la forêt de Krasnov depuis l'exploitation forestière, décisions de Fred du 21/11/2026. PR à part, dans le lot de Krasnov, après la PR interview d'accueil du 21/11.

Consigne d'abord ces décisions mot pour mot sur main dans GAME-DESIGN-FORET-KRASNOV-20261121.md.

Relis d'abord le code actuel de la forêt de Krasnov (action « S'enfoncer dans la forêt », tirage aléatoire des images bois / loup(s) / ours / Olga, coûts en PA, rencontres) : tout ce qui n'est pas modifié ci-dessous reste inchangé, coûts en PA compris.

1. Le portique comme porte d'entrée
- Sur l'image « Entrée de la forêt » de l'Exploitation forestière de Krasnov, le portique en bois (au fond à droite, au-dessus du chemin) devient une zone cliquable.
- Au survol : curseur main et infobulle « Explorer la forêt ». Sur écran tactile, un appui sur le portique déclenche directement l'action.
- Signal visuel très léger, à peine perceptible : un fin contour lumineux qui pulse lentement et faiblement autour du portique. Il ne doit pas attirer l'œil plus que le reste de l'image ; la curiosité du joueur fait le reste.
- Le bouton « S'enfoncer dans la forêt » de la zone de récolte est supprimé. « Récolter » et les autres actions restent.

2. Première image de forêt
- Un clic sur le portique mène toujours à la même première image : la forêt avec quelques souches d'arbres coupés.
- Cette image est à son tour cliquable (zone centrale vers le sous-bois), avec la même infobulle « Explorer la forêt », le même curseur et le même contour très léger.
- Un clic sur cette image lance le mécanisme existant d'images aléatoires bois / loup(s) / ours / Olga. Les images suivantes restent cliquables de la même façon pour continuer l'exploration.
- Fred fournira une image de bois supplémentaire. Le tirage ne doit jamais afficher deux fois de suite la même image de bois.
- Si l'image des souches n'existe pas encore dans le dépôt, signale-le dans ton rapport : Fred la produira.

3. Retour au campement
- Dans la forêt, l'action de pièce (bouton vert) « Retour au campement » remplace tout autre moyen de sortie.
- Le retour se fait en deux clics au maximum :
  - Premier clic : le joueur peut s'égarer. S'il s'égare, il passe par le même mécanisme aléatoire que l'aller (bois / loup(s) / ours / Olga, rencontres comprises), et le message « Était-ce le bon chemin… ? » s'affiche.
  - Second clic : il ramène toujours à l'Exploitation forestière, sans rencontre.
- Probabilité de s'égarer au premier clic : si le code définit déjà une probabilité de se perdre en forêt, garde-la ; sinon, une chance sur deux. Écris-la en configuration pour que Fred puisse l'ajuster.
- Coût en PA du retour : le même que celui d'un pas d'exploration.

4. Contrôle
Tests couvrant : clic sur le portique vers l'image des souches, bouton « S'enfoncer dans la forêt » absent, image des souches cliquable vers le tirage aléatoire, jamais deux images de bois identiques à la suite, retour en deux clics maximum avec message « Était-ce le bon chemin… ? » en cas d'égarement, retour garanti au second clic.
Rapport attendu : images manquantes, probabilité d'égarement retenue, ce qui reste à décider par Fred.
