# Forums — règles territoriales et adhésions (décision du 3 novembre 2026)

## Règles d'accès du 24/11/2026 (Fred, mission « Purge », bloc B — remplacent « Forums locaux » et « Forum national » ci-dessous)

Consigne de Fred, mot pour mot :
- Le forum national de son pays est toujours accessible.
- À l'étranger, le forum national du pays visité est en lecture seule.
- Le forum local de sa ville de domiciliation est toujours accessible.
- Le forum local d'une ville visitée est en lecture-écriture.
- Les sous-forums nationaux suivent la règle de leur forum.
- Bernard ne doit plus voir ceux de Républia.

Lecture retenue (sans rien trancher de neuf) :
- « Son pays » = la **nationalité** du personnage (règle du 18/11, migration `20261118031000_nationalite_forums`), jamais sa position.
- Sous-forums nationaux : Présidence, Assemblée nationale, Gouvernement, Presse & Médias. Ils gardent leurs réserves propres
  (création réservée au Président, aux journalistes ; Gouvernement aux ministres) et suivent en plus la règle du forum national.
- Forums locaux : la ville de domicile (où que l'on soit, même hors de son pays) et la ville où l'on se trouve, toutes deux en écriture.
  L'écran les range dans une section « Forums locaux » séparée des « Forums nationaux » (point B.2).
- Le serveur décide (`forum_lecture_autorisee`, `forum_ecriture_autorisee`, RLS de `forum_topics` / `forum_posts`,
  `forum_publication_jauges_interne`) : migration `20261124110000_forums_acces_purge.sql`. Bancs :
  `outils/bancs/banc-forums-acces-pglite-20261124.cjs` (serveur), `outils/bancs/banc-forums-purge-20261124.cjs` (écran).
- Cause du défaut de Bernard (personnage de Sovarka) : la lecture serveur acceptait tout sous-forum national sans regarder le pays
  du sujet, et l'écran ne filtrait par pays que `national` et `local_` ; il voyait donc la Présidence, le Gouvernement et la Presse de Républia.
- Inchangés : forums d'organisation, international, sport, tribunaux de ville.

## Forums locaux (règle du 3/11, remplacée le 24/11)
- Le forum local accessible est celui de **la ville où se trouve réellement le PJ**, indépendamment de son domicile.
- Luthécia → Port-Sainte-Marie → Luthécia : le forum local change à chaque voyage et redevient celui de Luthécia au retour. Le forum quitté est inaccessible, y compris ses sujets précédemment ouverts.
- Deux pays ayant une ville avec le même identifiant technique n'ont jamais le même contenu local. Le serveur associe chaque sujet à `forum_topics.country` et contrôle le pays et la ville de la fiche canonique du joueur.

## Forum national (règle du 3/11, remplacée le 24/11)
- Un seul forum national **pour le pays courant du PJ**, accessible quelle que soit sa ville à l'intérieur de ce pays.
- Les sujets d'un autre pays ne peuvent jamais s'y mêler.
- Les identifiants existants `national` et `local_<ville>` sont conservés pour compatibilité avec les publications officielles. C'est le pays du sujet, vérifié côté serveur, qui isole les fils.

## Forums privés
- Un PJ voit uniquement les forums des organisations dont il est **membre**, ou dont il est le chef (le chef bénéficie de l'accès propre à son organisation).
- Une organisation simplement visible au catalogue, y compris une entreprise appartenant à un autre PJ, ne donne aucun droit de lecture.
- Le verrou porte sur les listes, les sujets, les messages, les compteurs et les accès directs à l'API, et doit suivre toute perte/gain d'adhésion.

## Inchangés
- Forums institutionnels : règles et autorisations existantes.
- Presse et médias : lecture publique, création de sujet réservée aux journalistes.
- Forums internationaux et sportifs : fonctionnement existant.

## Contrôle de livraison
- Cas concret : la candidature de Jean Népa située dans `local_ville_a` d'El Estado (`narco`) ne doit pas apparaître dans le forum de PSM (`republic`), malgré l'identifiant de ville commun.
- La personne non adhérente au Cabinet de Conseil en Fraude de Jean Jaaj ne voit pas son forum privé.
- Tester les allers-retours entre Luthécia et PSM, les changements de pays, les compteurs et les voyants d'activité, ainsi que l'accès direct aux sujets/réponses via PostgREST.
- Migration de RLS à appliquer **après prévol** et contrôles, avant de considérer la correction livrée.
