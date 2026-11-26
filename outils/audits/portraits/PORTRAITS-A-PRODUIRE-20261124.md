# Portraits des PNJ — relevé et prompts (24/11/2026)

**Portée** : Novomirsk, plus les six guides. Le seul changement fonctionnel autorisé est le `photoUrl`. Aucune fiche, nom, rôle, dialogue ou mécanique n'est modifié.

## Portraits effectivement raccordés

| PNJ | Pièce | Action | Preuve |
|---|---|---|---|
| Valentina Petchatkina | mairie-capitale / hall_mairie | Recadrage du visage de la femme brune à lunettes, à gauche du comptoir, **différente** de Varvara Nakhodkina | `novo-secretaire-municipale-portrait.webp`, cadre [665,440,140,140] dans le relevé 23/11 |
| Zinaïda Kvassova | stade / buvette | Recadrage existant de la tenancière (chapka et tablier), raccordé | `novo-tenanciere-buvette-dynamo-portrait.webp`, cadre [505,268,240,240] |
| Varvara Nakhodkina | mairie-capitale / hall_mairie | Déjà raccordée : **non modifiée** (femme rousse à droite) | `novo-hotesse-objets-trouves-portrait.webp` |

Les portraits Valentina et Zinaïda étaient **déjà présents dans le dépôt** mais n'étaient pas raccordés à leur PNJ actuel. Ils ont été inspectés visuellement : front et menton intacts, visage et épaules visibles.

## Résultat du banc du 24/11/2026
- **140 apparitions de PNJ** contrôlées dans les pièces de Novomirsk (dont titulaires dans les salles).
- **106 apparitions disposent d'un portrait sur disque** (105 lors du relevé initial, plus Zinaïda Otcheredova ; résultat à confirmer sur la CI finale).
- **34 apparitions attendent un portrait**. Le tableau ci-dessous les recense.
- Deux lignes historiques du 23/11 ne sont plus présentes dans le parcours actuel : **Camarade Privilège** et **Caissier Méticuleux** (conservées dans le JSON en tant qu'archives, non comptées comme « portraits à produire »).
- Vérification visuelle : les six bureaux des ministres, les trois ambassades, la salle d'audience, le bureau du maire et le bureau de l'entrepôt sont **vides** ; au garage, les mécaniciens sont trop petits pour une photo de profil. Au centre artisanal, les passants ne peuvent pas être attribués sans ambiguïté aux trois PNJ ; au club de supporters, aucun chef ne peut être identifié avec certitude.
- **Point extérieur au chantier portraits** : Fiodor Medvedkine existe dans la déclaration source de `data.js` mais n'est pas présent dans `WORLD.soviet.ville_b.buildingContext.marche.persons` une fois le fichier chargé (liste effective : Nina Gorbounova seulement). Ne pas réintroduire Fiodor en modifiant sa présence dans cette PR.

## Livraison du 26/11/2026

32 portraits produits par ChatGPT et vérifiés par Fred (`novo-*-portrait.webp`, dans `images/Sovarka/Novomirsk/`), raccordés dans `PORTRAITS_PNJ_NOVOMIRSK` (`data.js`). Vera Pravdina reçoit en plus le portrait de l'interview d'accueil (`Novo_vera_pravdina_portrait.webp`), déjà présent dans le dépôt. Liste détaillée : `portraits_livres_20261126` dans le JSON. **Il ne reste qu'un portrait à produire : Boris Kovaliov.**

## Portraits à produire — Novomirsk (recontrôle du 25/11/2026)

34 entrées historiques conservées, dont 4 dans des pièces exclues et 30 dans des pièces accessibles selon les données de navigation. Aucun nouveau recadrage fiable. Les descriptions ci-dessous sont des **propositions artistiques non canoniques**, pas des faits tirés des fiches ; aucune génération ni modification des personnages. Une entrée collective (journalistes accrédités) ne doit pas être confondue avec un individu.

| PNJ | Rôle | Bâtiment / pièce | Constat visuel | Apparence proposée (deux phrases) |
|---|---|---|---|---|
| Boris Kovaliov (PNJ) | Directeur de l'usine Pharmanov | `usine-pharmaceutique-luthecia/bureau_direction` | absent — Bureau du directeur vide ; technicien en blouse derrière la vitre. | Homme de cinquante-cinq ans, cheveux gris et barbe courte soignée. Costume sobre et lunettes à monture métallique. |

## Guides — images de lieux inspectées

Les six images de lieux ont été vues. Elles montrent des scènes de foule/marché (visages trop petits, aucun portrait permettant d'identifier **avec certitude** les traits de la fiche). Par conséquent, aucun passant n'est attribué arbitrairement à un guide. Les six portraits fournis par Fred ont été intégrés par Claude dans le commit `f408064`. Les six fichiers et raccordements sont vérifiés dans GitHub ; ils sont retirés de la liste d'attente. Le cas de présence effective de Fiodor reste signalé séparément.

## Archives des prompts — six guides livrés

### Zinaïda Otcheredova — `images/Sovarka/Novomirsk/guide-zinaida-otcheredova-portrait.webp`

> Portrait photographique hyperréaliste pour Human Gambit, personnage fictif de Sovarka/Novomirsk. Doyenne des files d’attente, fichu à fleurs et cabas de toile. Sourire malicieux, regard protecteur qui sait reconnaître les nouveaux venus, allusion discrète aux files d’attente du marché collectif. Cadrage **buste / visage et épaules**, regard dirigé vers le spectateur, expression vivante et charismatique, éclairage chaud latéral, arrière-plan **sombre, neutre, légèrement flouté** ; palette et réalisme des portraits WebP de PNJ de Novomirsk. Un seul personnage, visage entier, front et menton non coupés, posture naturelle, vêtements cohérents avec son histoire et son pays, peau et texture authentiques, sans caricature, sans faucille ni marteau, aucun texte, aucun logo. Composition carrée 512×512 minimum, nette sur les yeux et parfaitement exploitable comme avatar. **Ne pas générer la scène entière du lieu.**


### Firmin Badaud — `images/Republia/Luthecia/guide-firmin-badaud-portrait.webp`

> Portrait photographique hyperréaliste pour Human Gambit, personnage fictif de Republia/Luthecia. Ancien huissier retraité de la capitale victorienne, chapeau mou, journal plié sous le bras, air bavard et bienveillant, regard curieux. Cadrage **buste / visage et épaules**, regard dirigé vers le spectateur, expression vivante et charismatique, éclairage chaud latéral, arrière-plan **sombre, neutre, légèrement flouté** ; palette et réalisme des portraits WebP de PNJ de Novomirsk. Un seul personnage, visage entier, front et menton non coupés, posture naturelle, vêtements cohérents avec son histoire et son pays, peau et texture authentiques, sans caricature, sans faucille ni marteau, aucun texte, aucun logo. Composition carrée 512×512 minimum, nette sur les yeux et parfaitement exploitable comme avatar. **Ne pas générer la scène entière du lieu.**


### Yvonne Bigorneau — `images/Republia/Port-Sainte-Marie/guide-yvonne-bigorneau-portrait.webp`

> Portrait photographique hyperréaliste pour Human Gambit, personnage fictif de Republia/Port-Sainte-Marie. Ancienne ramendeuse de filets de port, ciré jaune patiné et mains marquées par le sel, sourire franc de femme des quais. Cadrage **buste / visage et épaules**, regard dirigé vers le spectateur, expression vivante et charismatique, éclairage chaud latéral, arrière-plan **sombre, neutre, légèrement flouté** ; palette et réalisme des portraits WebP de PNJ de Novomirsk. Un seul personnage, visage entier, front et menton non coupés, posture naturelle, vêtements cohérents avec son histoire et son pays, peau et texture authentiques, sans caricature, sans faucille ni marteau, aucun texte, aucun logo. Composition carrée 512×512 minimum, nette sur les yeux et parfaitement exploitable comme avatar. **Ne pas générer la scène entière du lieu.**


### Lucien Boulon — `images/Republia/Montrouge/guide-lucien-boulon-portrait.webp`

> Portrait photographique hyperréaliste pour Human Gambit, personnage fictif de Republia/Montrouge. Cheminot retraité, casquette de travail usée, moustache grise et visage buriné ; attitude bourrue mais accueillante, homme solidaire du monde ouvrier. Cadrage **buste / visage et épaules**, regard dirigé vers le spectateur, expression vivante et charismatique, éclairage chaud latéral, arrière-plan **sombre, neutre, légèrement flouté** ; palette et réalisme des portraits WebP de PNJ de Novomirsk. Un seul personnage, visage entier, front et menton non coupés, posture naturelle, vêtements cohérents avec son histoire et son pays, peau et texture authentiques, sans caricature, sans faucille ni marteau, aucun texte, aucun logo. Composition carrée 512×512 minimum, nette sur les yeux et parfaitement exploitable comme avatar. **Ne pas générer la scène entière du lieu.**


### Bair Namsaraev — `images/Sovarka/Starovka/guide-bair-namsaraev-portrait.webp`

> Portrait photographique hyperréaliste pour Human Gambit, personnage fictif de Sovarka/Starovka. Ancien pêcheur bouriate, bonnet de fourrure et thermos de thé au lait salé visible près de l'épaule ; regard serein et hospitalier, fier de Starovka. Cadrage **buste / visage et épaules**, regard dirigé vers le spectateur, expression vivante et charismatique, éclairage chaud latéral, arrière-plan **sombre, neutre, légèrement flouté** ; palette et réalisme des portraits WebP de PNJ de Novomirsk. Un seul personnage, visage entier, front et menton non coupés, posture naturelle, vêtements cohérents avec son histoire et son pays, peau et texture authentiques, sans caricature, sans faucille ni marteau, aucun texte, aucun logo. Composition carrée 512×512 minimum, nette sur les yeux et parfaitement exploitable comme avatar. **Ne pas générer la scène entière du lieu.**


### Fiodor Medvedkine — `images/Sovarka/Krasnov/guide-fiodor-medvedkine-portrait.webp`

> Portrait photographique hyperréaliste pour Human Gambit, personnage fictif de Sovarka/Krasnov. Apiculteur du kolkhoze, barbe rousse généreuse, un petit pot de miel à côté de lui ; sourire jovial, allure paysanne robuste, humour d'homme des forêts. Cadrage **buste / visage et épaules**, regard dirigé vers le spectateur, expression vivante et charismatique, éclairage chaud latéral, arrière-plan **sombre, neutre, légèrement flouté** ; palette et réalisme des portraits WebP de PNJ de Novomirsk. Un seul personnage, visage entier, front et menton non coupés, posture naturelle, vêtements cohérents avec son histoire et son pays, peau et texture authentiques, sans caricature, sans faucille ni marteau, aucun texte, aucun logo. Composition carrée 512×512 minimum, nette sur les yeux et parfaitement exploitable comme avatar. **Ne pas générer la scène entière du lieu.**


## Test de clôture

`node outils/bancs/banc-portraits-pnj-20261124.cjs` vérifie chaque PNJ visible à Novomirsk : image disque existante ou entrée explicite de la liste `portraits-a-produire-20261124.json`. Il vérifie également les six raccordements des guides et l'existence de leurs fichiers. Aucun nouveau portrait ne doit être raccordé avant la présence physique du fichier.
