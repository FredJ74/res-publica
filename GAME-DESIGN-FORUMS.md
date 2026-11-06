# Forums — règles territoriales et adhésions (décision du 3 novembre 2026)

## Forums locaux
- Le forum local accessible est celui de **la ville où se trouve réellement le PJ**, indépendamment de son domicile.
- Luthécia → Port-Sainte-Marie → Luthécia : le forum local change à chaque voyage et redevient celui de Luthécia au retour. Le forum quitté est inaccessible, y compris ses sujets précédemment ouverts.
- Deux pays ayant une ville avec le même identifiant technique n'ont jamais le même contenu local. Le serveur associe chaque sujet à `forum_topics.country` et contrôle le pays et la ville de la fiche canonique du joueur.

## Forum national
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
