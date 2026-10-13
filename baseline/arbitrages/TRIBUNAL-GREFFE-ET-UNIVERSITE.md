# Tranche du 13 octobre 2026 — Tribunal, greffe, Université : ce qui reste à décider

**Ni le Tribunal ni l'Université ne sont déclarés clos ici** : le cahier des charges de la tranche
l'interdit explicitement, et cette page existe pour que la décision reste entière.

Registre Supabase **705 → 712**, sept migrations, toutes archivées byte-exact. Ce qui a été
livré est décrit dans `baseline/CONTROLE-GLOBAL.json`, section
`_chantier_greffe_et_universite`. Ce document ne liste que **les décisions non prises**.

---

## 1. Extrait officiel de domiciliation — ARBITRAGE VALIDÉ LE 13 OCTOBRE 2026

**Décision de game design :** toutes les organisations, sans exception de catégorie, reçoivent à leur constitution **un extrait officiel unique de domiciliation**. L'original est remis dans l'inventaire du fondateur. Le document atteste la constitution et la domiciliation, sans conférer de fonction dirigeante à son détenteur.

**Duplicata :** seul le **président ou le trésorier** de l'organisation peut demander un double, **au greffe du tribunal de la ville de domiciliation**, pour **75 FR et 1 PA**. Le duplicata reproduit un original existant, il ne constitue pas une nouvelle organisation et ne modifie pas sa domiciliation.

**Écart avec l'existant :** la porte actuelle `syndicat_etudiant_domicilier` émet déjà un extrait original, mais la règle n'est pas générale. La porte `organisation_extrait_duplicata` autorise actuellement le président **ou le secrétaire** : remplacer le secrétaire par le **trésorier**. Les organisations créées par l'ancien chemin client n'ont pas forcément de dirigeants normalisés ni d'extrait original. Il faut auditer les voies de constitution et prévoir un traitement cohérent des organisations préexistantes sans fabriquer silencieusement de faux originaux.

**Statut technique :** arbitrage enregistré ; implémentation transversale et vérifications restent à faire. Ne pas déclarer le chantier clos.

## 2. Greffiers nommés dans les trois tribunaux — ARBITRAGE VALIDÉ

**Décision :** chaque tribunal de Républia doit avoir son **propre greffier PNJ nommé** : Luthécia (Greffier Petit, existant), Port-Sainte-Marie (**Greffier Leroux**) et Montrouge (**Greffier Richard**). Le greffier n'est **jamais un poste accessible aux PJ** ; conserver la contrainte `postes_attribues_jamais_greffier`.

**État actuel :** `greffes_tribunaux` possède trois lignes, mais les deux greffes locaux ont `greffier_pnj = NULL` et utilisent la signature générique du greffe. Les noms ont été choisis par le game designer et inscrits dans `greffes_tribunaux` en production ; aucune nouvelle image n'a été générée. La présence physique de ces personnages dans les salles reste à contrôler.

**Statut technique :** casting validé et signatures des greffes mises à jour dans Supabase ; intégration visuelle des PNJ non vérifiée.

## 3. Énigme du Musée — passage au greffe du Tribunal (CONFIRMÉ)

L'énigme du Musée de Luthécia (portraits disparus, parcelle B-127, succession Pierre Thibault, coffre bancaire, clé du débarras, Gérard Poinçon) **est conservée intégralement** : sept indices, conditions, progression et révélation inchangés.

Le passage judiciaire se fait déjà par l'ordre **« Demander à parler au juge » au greffe**, relié à `doDemanderJugeInstruction` dans `plateau-enigme-portrait.js`. Il vérifie les archives et les témoignages puis, si le dossier est complet, le juge Honoré Cozetoujours autorise l'ouverture du coffre. **Aucun nouveau bouton ni déplacement de l'action**.

L'identité de Fontaine a été remplacée par Honoré Cozetoujours ; les trois répliques sont encore les formulations originales. Leur réécriture stylistique reste facultative et n'est pas arbitrée. Ne pas les modifier sans nouvelle décision explicite.

## 4. Quartier des Troupes — ordre « Recruter pour un groupe » (CLOS)

Après audit et validation du game designer le 13 octobre 2026, l'ordre obsolète a été **retiré de `data.js`** (commit `e963a8d`). Il utilisait à tort `fn:'recruter_etud'` et lançait le recrutement syndical ; il n'existait aucune mécanique militaire autonome pour ce bouton.

**Aucun changement** au contingent et à la réserve des compagnies, à la mobilisation nationale, ni à la réquisition civile de 24 citoyens ajoutés à une section existante pendant la mobilisation. Les ordres étudiants `recruter_etud` restent intacts.

## 5. Université — seconde carrière (principes confirmés, cursus à arbitrer)

L'ordre **« Suivre une formation »** permet à un PJ de développer **une seconde carrière sans effacer la première**. Cette reconversion n'est possible **qu'une seule fois dans la vie du personnage**. La formation s'étale sur **deux mois**, en alternant **cours et stages**. **Le choix de la seconde carrière est entièrement libre, quelle que soit la carrière initiale, le parcours scolaire ou la progression du personnage.** Il s'agit d'une formation pour adultes, sans condition préalable d'accès liée au premier build. **Manquer un cours repousse la fin de la formation**. **Rythme validé : 3 jours de cours par semaine, 6 PA par cours (18 PA par semaine hors stages).** **Calendrier glissant validé :** le PJ est informé de son emploi du temps hebdomadaire. À la date prévue d'un module, il se rend physiquement à l'Université et clique sur « Suivre une formation » : cela consomme **6 PA** et valide uniquement le module disponible. Si le PJ manque la date prévue, **ce même module reste disponible** jusqu'à validation ; tous les modules suivants sont **réellement décalés dans le temps**, sans rattrapage instantané ni possibilité de valider deux modules à la suite. L'emploi du temps doit refléter les décalages. **Arbitrage complémentaire : conserver l'intervalle normal entre deux cours lors de tout décalage.** Exemple indicatif : cours initialement lundi/mercredi/vendredi, premier cours validé jeudi => suivants samedi/lundi. Impossible de valider deux cours successivement sans respecter cet intervalle. **Jours initiaux validés : lundi, mercredi et vendredi**, avec conservation des intervalles entre modules lorsque le calendrier glisse. **Stages : lieu validé.** Les stages s'effectuent **physiquement dans les bâtiments dédiés à la carrière visée** (ex. carrière militaire : caserne), pas depuis l'Université. La formation doit exiger un engagement réel du PJ, et non une simple attente de deux mois. **Nature des activités validée : missions concrètes et spécifiques à la carrière visée**, et non simple présence et dépense de PA. Exemple donné : formation de médecin avec une mission à l'EHPAD des Tilleuls. **Interaction obligatoire : chaque stage implique au minimum un maître de stage (PNJ ou PJ), qui confie une mission liée au métier et accompagne l'étudiant.** Exemple : à l'EHPAD, le futur médecin reçoit une mission auprès d'un pensionnaire. **Validation automatique des stages par le moteur lorsque les objectifs de mission sont remplis**, sans approbation manuelle du maître de stage (PJ ou PNJ), pour éviter les blocages et la complexité. **Rythme et nombre de stages validés : un stage par formation, deux au maximum selon la carrière ; chaque stage comprend plusieurs missions, à raison d'une mission par semaine.** **Première semaine réservée aux cours ; missions de stage à partir de la deuxième semaine.** L'intérêt d'un éventuel deuxième stage est de **faire voyager le PJ dans une autre ville**, avec un autre bâtiment et un autre maître de stage (exemple de formation médicale : EHPAD des Tilleuls à Luthécia puis dispensaire de Port-Sainte-Marie). Une mission par semaine. **Mobilité interurbaine obligatoire pour toutes les formations**, à justifier par un contexte professionnel propre à chaque carrière, sans déplacement artificiel. Prévoir des lieux de stage pertinents dans au moins deux villes ; les exemples de métiers et d'établissements sont illustratifs tant que les parcours ne sont pas définis. **Rythme de cours adapté aux stages : trois cours à 6 PA pendant les semaines sans stage (dont la première semaine) ; deux cours à 6 PA pendant les semaines comportant une mission de stage, plus cette mission.** Le calendrier glissant des cours reste applicable ; le choix des deux jours de cours lors des semaines de stage, la répartition précise entre les lieux, le contenu des missions et leur coût en PA restent à arbitrer. ; ne pas assimiler d'office les stages à des cours ni accorder de prérogatives professionnelles anticipées. Le contenu précis des cours et stages, leur calendrier et les cursus offerts restent à définir avec le game designer, un arbitrage à la fois.

État technique audité : le bouton est visible mais désactivé (`bientot`), aucune route active, aucun coût d'ordre déclaré. Le socle `universite_cursus` existe mais son catalogue est vide volontairement ; ne pas inventer de cursus ni activer le bouton avant ces arbitrages.

## 6. Les arbitrages explicitement non rouverts

Trois points sont **déjà arbitrés** et ont été laissés intacts, pour mémoire :

* **`justification_rejetee` garde son dé.** Le Commissaire PJ ne remplace pas le jet par son
  appréciation. L'infraction reste **sans catégorie**, et une contrainte de base interdit qu'elle
  hérite d'un barème.
* **« Donner une conférence » est conservée mot pour mot** — même coût, même taux, même
  description, même type : un banc le mesure caractère par caractère.
* **La catégorie `delit` reste la catégorie**, et aucun barème n'a bougé. Le détail factuel des
  sept `delit` et des six `delit_grave` est dans
  `baseline/arbitrages/AUDIT-CORRUPTION-ET-FONDS-PUBLICS.md`.

## 7. Renvois

* Corruption, détournement de fonds publics, emplois fictifs :
  `AUDIT-CORRUPTION-ET-FONDS-PUBLICS.md` — **deux infractions sur trois n'existent pas**.
* Types de journal non judiciaires : `AUDIT-TYPES-DE-JOURNAL-NON-JUDICIAIRES.md` — **onze types
  restent écrits par le navigateur**, dette chiffrée et nommée.
* Divergence à trois valeurs du miroir `ordres_couts` : inchangée, lot 4D
  (`outils/baseline/referentiels.json`).
