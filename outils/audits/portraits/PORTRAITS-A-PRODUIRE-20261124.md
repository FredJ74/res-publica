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

## Portraits à produire — Novomirsk (recontrôle du 25/11/2026)

34 entrées historiques conservées, dont 4 dans des pièces exclues et 30 dans des pièces accessibles selon les données de navigation. Aucun nouveau recadrage fiable. Les descriptions ci-dessous sont des **propositions artistiques non canoniques**, pas des faits tirés des fiches ; aucune génération ni modification des personnages. Une entrée collective (journalistes accrédités) ne doit pas être confondue avec un individu.

| PNJ | Rôle | Bâtiment / pièce | Constat visuel | Apparence proposée (deux phrases) |
|---|---|---|---|---|
| Lieutenant Nestor Medalev (PNJ) | PNJ - Gardien de la memoire | `caserne-militaire/salle_faits_armes` | absent — Salle commémorative vide ; les soldats sont sur des tableaux et un buste est une sculpture. | Officier d'une cinquantaine d'années aux cheveux poivre et sel, visage carré et yeux attentifs. Uniforme de cérémonie sobre et maintien digne. |
| Genrikh Vlassov | Sécurité | `centre-artisanal/travees` | ambigu — Accueil : homme au comptoir de dos et passants indistincts ; aucun agent identifiable. | Homme de quarante ans au crâne rasé, sourcils épais et carrure solide. Veste de sécurité sombre, posture vigilante. |
| Kolia Titov | Dealer | `centre-artisanal/travees` | ambigu — Même accueil ; aucun passant attribuable au dealer. | Jeune homme aux cheveux noirs ondulés, visage étroit et regard fuyant. Blouson usé sur un col roulé, posture détendue. |
| Sava Goussev | Mécanicien | `centre-artisanal/travees` | ambigu — Même accueil ; aucun mécanicien identifiable. | Homme d'une cinquantaine d'années, cheveux châtains grisonnants et barbe courte. Veste de travail bleue patinée et visage jovial. |
| Efim Zametkov (PNJ) | PNJ - Journaliste | `centre-affaires/tribune_republia` | piece_exclue — tribune_republia figure dans roomsExclues. | Journaliste d'âge mûr aux cheveux bruns clairsemés et lunettes rondes. Manteau de laine sobre et expression curieuse. |
| Timofeï Fomine (PNJ) | Detenu | `commissariat/prison` | absent — Geôles vides ; seul le gardien est visible au fond. | Homme d'une trentaine d'années, cheveux courts en désordre et traits fatigués. Chemise froissée et regard réservé. |
| Boris Stockov (PNJ) | Directeur de l'Entrepôt Logistique | `entrepot-logistique-novomirsk/bureau_direction` | absent — Bureau vide ; employé visible dans l'entrepôt derrière la vitre. | Directeur quinquagénaire au visage large et cheveux gris coiffés sur le côté. Costume anthracite et expression pragmatique. |
| Sergueï Zaptchastov (PNJ) | Garagiste | `garage-novomirsk/atelier_garage` | trop_petit_ambigu — Plusieurs mécaniciens, celui du premier plan de profil sous la voiture ; visages partiels ou minuscules. | Homme robuste d'une quarantaine d'années au nez marqué et moustache courte. Casquette et combinaison grise tachée de graisse. |
| Vera Pravdina (PNJ) | Journaliste de La Voix de Sovarka | `la-tribune/accueil_tribune` | trop_petit_ambigu — Deux visages centraux déjà raccordés à Zoïa et Arseni (portraits comparés) ; femme à droite de profil trop petite. | Femme d'environ trente-cinq ans, cheveux châtains relevés en chignon et sourire professionnel. Tailleur bleu marine, chemisier blanc et carnet de presse. |
| Rostislav Censurov | PNJ - Redacteur en chef | `la-tribune/redaction` | ambigu — Rédaction partagée avec Républia ; plusieurs hommes lisent ou travaillent sans indice de fonction. | Homme de cinquante ans aux cheveux bruns plaqués et lunettes rectangulaires. Chemise claire, gilet sombre et expression exigeante. |
| Le Maire de Novomirsk (PNJ) | Maire de la Capitale | `mairie-capitale/bureau_maire` | absent — Bureau du maire vide ; buste décoratif uniquement. | Homme de cinquante-cinq ans aux cheveux argentés et visage rond. Costume trois-pièces sombre, petite broche municipale et sourire mesuré. |
| Cheikh Rachid Al-Diplomi (PNJ) | Ambassadeur d'Al-Khalija | `palais-ambassades-novomirsk/bureau_khalija_novomirsk` | absent — Bureau de l'ambassade vide. | Homme mûr à barbe grise soigneusement taillée et regard calme. Tenue diplomatique élégante inspirée d'Al Khalija, étoffe claire et broderie discrète. |
| Don Esteban Cortesano (PNJ) | Ambassadeur d'El Estado | `palais-ambassades-novomirsk/bureau_estado_novomirsk` | absent — Bureau de l'ambassade vide. | Homme de cinquante ans aux cheveux noirs grisonnants aux tempes et moustache fine. Costume ivoire et cravate bordeaux, expression affable. |
| Hubert de La Courtoisie (PNJ) | Ambassadeur de Républia | `palais-ambassades-novomirsk/bureau_republia_novomirsk` | absent — Bureau de l'ambassade vide ; buste décoratif uniquement. | Homme d'une soixantaine d'années, cheveux argentés et favoris courts. Redingote ou costume bleu nuit et nœud de cravate soigné. |
| Evgueni Gromov (PNJ) | PNJ - Ministre de l'Amitié entre les Peuples | `palais-gouvernement/bureau_min_ae` | absent — Bureau ministériel vide. | Homme de cinquante-cinq ans aux cheveux gris ondulés et visage allongé. Costume bleu foncé, cravate sobre et sourire diplomatique. |
| Stanislav Roublov (PNJ) | PNJ - Ministre de l'Économie collective | `palais-gouvernement/bureau_min_fin` | absent — Bureau ministériel vide. | Homme d'âge mûr au front haut, lunettes fines et cheveux blonds grisonnants. Costume brun foncé et expression concentrée. |
| Rodion Tankov (PNJ) | PNJ - Ministre de la Défense de la Patrie | `palais-gouvernement/bureau_min_def` | absent — Bureau ministériel vide ; buste et uniforme décoratifs. | Officier âgé d'environ soixante ans, cheveux très courts et mâchoire forte. Uniforme de service et regard ferme. |
| Galina Sergueïeva (PNJ) | PNJ - Ministre de la Justice prolétarienne | `palais-gouvernement/bureau_min_just` | absent — Bureau ministériel vide. | Femme d'une cinquantaine d'années aux cheveux gris coupés au carré et traits nets. Tailleur noir, chemisier ivoire et posture droite. |
| Gleb Nikitine (PNJ) | PNJ - Ministre de la Sécurité du Peuple | `palais-gouvernement/bureau_min_int` | absent — Bureau ministériel vide. | Homme de quarante-cinq ans aux cheveux bruns courts, visage anguleux et yeux attentifs. Costume sombre sans ornement et expression impassible. |
| Zinaïda Propagandova (PNJ) | PNJ - Ministre de la Vérité officielle | `palais-gouvernement/bureau_min_info` | absent — Bureau ministériel vide. | Femme d'une cinquantaine d'années aux cheveux roux coiffés en rouleau et sourcils dessinés. Tailleur bordeaux, broche dorée et sourire maîtrisé. |
| Oleg Morozov (PNJ) | PNJ - Chef de cabinet du Président du Conseil du Peuple | `palais-gouvernement/bureaux` | absent — Bureau du Conseil vide. | Homme de quarante ans aux cheveux bruns bien coiffés, visage mince et lunettes discrètes. Costume gris, cravate noire et attitude méthodique. |
| Secrétaire Tamara Volkova | PNJ - Accueil officiel | `palais-gouvernement/hall` | absent — Hall monumental : gardes seulement, aucune secrétaire. | Femme de quarante-cinq ans au carré brun foncé et lunettes à monture écaille. Veste grise, foulard discret et sourire professionnel. |
| Journalistes accrédités (PNJ) | PNJ - Presse nationale accréditée | `palais-gouvernement/salle_presse` | collectif_absent — Salle de presse vide ; entrée collective, aucune identité individuelle. | Si une représentation collective est souhaitée, choisir un petit groupe de journalistes adultes aux apparences variées. Prévoir des vêtements de presse sobres et quelques carnets ou appareils photo, sans désigner un membre comme unique titulaire. |
| Raïssa Communiqueva (PNJ) | PNJ - Porte-parole du Conseil du Peuple | `palais-gouvernement/salle_presse` | absent — Salle de presse vide. | Femme de quarante ans aux cheveux noirs mi-longs et pommettes marquées. Tailleur vert sombre, chemisier clair et posture assurée. |
| Le Président (PNJ) | PNJ - Président de Sovarka | `palais-presidentiel/bureau_president` | piece_exclue — bureau_president figure dans roomsExclues. | Homme de soixante ans aux cheveux blancs et visage imposant. Costume noir impeccable, chemise blanche et regard solennel. |
| Nadejda Lebedeva (PNJ) | PNJ - Secretaire general de la presidence | `palais-presidentiel/bureau_president` | piece_exclue — bureau_president figure dans roomsExclues. | Femme de cinquante ans aux cheveux châtains grisonnants ramenés en chignon bas. Tailleur anthracite et expression précise. |
| Rodion Glasnov (PNJ) | PNJ - Porte-parole de la presidence | `palais-presidentiel/salle_presse_elysee` | piece_exclue — salle_presse_elysee figure dans roomsExclues. | Homme de quarante ans aux cheveux noirs lisses et visage ovale. Costume bleu pétrole et sourire de porte-parole. |
| Anatoli Sokolov (PNJ) | PNJ - Chef du protocole presidentiel | `palais-presidentiel/salle_reception` | absent — Salle à manger présidentielle vide ; image empire novomirsk-palais-presidentiel-reception.webp. | Homme d'une cinquantaine d'années aux cheveux poivre et sel et moustache soignée. Costume de cérémonie noir, posture élégante. |
| Meneur des Supporters (PNJ) | PNJ - Chef de Tribune | `stade/siege_supporters` | ambigu — Plusieurs supporters au premier plan et une hôtesse ; aucun indice certain du chef de tribune. | Homme barbu d'une quarantaine d'années, casquette bordeaux et visage expressif. Écharpe grenat et or du Dynamo sur une veste chaude. |
| Entraineur Local (PNJ) | PNJ - Entraineur | `stade/terrain` | trop_petit_ambigu — Terrain : silhouettes lointaines et spectateurs de dos ; entraîneur non identifiable. | Homme sportif d'une cinquantaine d'années aux cheveux courts grisonnants et nez légèrement cassé. Veste d'entraînement grenat et col montant. |
| Camarade Juge Pravdine (PNJ) | Juge Populaire | `tribunal/salle_audience` | absent — Salle d'audience de Novomirsk vide. | Homme mûr aux cheveux gris courts et traits sévères. Robe judiciaire sombre et posture droite. |
| Assistante Propagande (PNJ) | Assistante | `universite/amphi` | ambigu — Amphithéâtre partagé de Luthécia ; assistante non identifiable parmi les étudiants. | Femme d'une trentaine d'années aux cheveux blonds foncés attachés et lunettes fines. Veste de laine bleue et regard attentif. |
| Professeur Dialectique (PNJ) | Doyen | `universite/amphi` | trop_petit — Enseignant au tableau dans l'amphithéâtre partagé, visage minuscule ; pas de recadrage exploitable. | Homme âgé, calvitie et lunettes, costume sombre comme la silhouette au tableau. Visage marqué et expression de professeur passionné. |
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
