# #219 — défaut Authority corrigé et services de recette réellement préparés

Suite de `c5671d16` sur `codex/certification-219-1021-20261101`. Aucun développement groupe/combat/déplacement repris. Main récupéré : pas de nouveau changement après `df67186a` au moment du fetch.

## Correction démontrée sans données privées

L'invariant12 d'Authority déclarait inconnue la policy `reserve jardins lecture`, malgré son CREATE dans la même migration `20261101040000_jardins_ouvriers_montrouge.sql`. Le détecteur retirait les guillemets du DROP puis cherchait un CREATE non cité. Il ne vérifiait pas non plus la table du CREATE.

La correction réutilise le parseur PostgreSQL déjà requis par Authority : uniquement les vrais `CreatePolicyStmt` de la migration, schema public, paire exacte (table, policy). Noms cités, échappés, casse SQL et espaces interprétés par le parseur ; commentaires, textes SQL dans une chaîne et autre table n'ouvrent aucune exemption. Aucun objet n'est ajouté au baseline et aucune déclaration de migration n'est présentée comme déploiement.

**5/5 tests du banc Authority** avec contre-épreuves. Invariant12 désormais conforme ; invariant13 reste rouge avec19 écarts. Aucune RPC ajoutée artificiellement aux fonctions connues.

## Préparation réelle des services

Nouveau banc `outils/bancs/test-services-certification-219.py` : uniquement cluster/socket/ports loopback jetables, aucune URL de production ni authentification existante. PostgreSQL natif demandé explicitement. Création d'une base ICU, démarrage des vrais binaires GoTrue/PostgREST, compte aléatoire `example.invalid` créé par GoTrue puis login HTTP. Aucun UID, jeton, email ou mot de passe dans le rapport. Arrêt et attente des processus, fermeture des connexions et destruction du cluster en finally, y compris sur échec.

**10/10 contrôles réellement exécutés :** version170006 ; ICU fournisseur i, datlocale en-US, versions déclarée et actuelle153.121 ; health GoTrue ; health PostgREST ; signup fictif ; login fictif ; UID transmis du JWT à la RPC ; accès anonyme refusé HTTP401/403 ; signature JWT altérée refusée401 ; reconnexion avec le même UID. Le rôle anonyme est vérifié sur une fonction de diagnostic distincte et son absence de droit sur la RPC cible est aussi contrôlée par SQL.

Ce banc vérifie la préparation de la plateforme, **pas les27 cas métier**. Il n'a installé aucune des95 migrations et n'a certifié aucun catalogue1021.

### Échecs intermédiaires conservés au diagnostic

La première fixture d'identité était une fonction SQL STABLE : après l'appel authentifié, un appel anonyme donnait200/null malgré un rôle anon et une ACL SQL refusant EXECUTE. Ce résultat n'est pas déclaré un refus401/403 et n'est pas caché par une assertion plus large. Le mécanisme exact de cette réponse SQL nullable n'a pas été isolé ici ; aucune conclusion de sécurité sur les RPC métier n'en est déduite.

Une proposition d'élargissement de l'assertion a été refusée par la revue automatique, faute de preuve. L'exigence401/403 est restée intacte. La fixture de contrôle d'accès est désormais PL/pgSQL, non inlinable, et vérifie l'ACL lors d'une véritable exécution. Elle produit le refus strict attendu. Aucune fonction du jeu n'a été changée. Une seconde erreur de diagnostic provenait d'une fonction créée après le chargement du cache PostgREST ; sa création précède maintenant le démarrage du service. Les essais finaux sont verts ; les échecs précédents ne sont pas comptés comme réussis.

## Autres exécutions

- **21/21 tests d'import/relais** sur PostgreSQL natif17.6 : SELECT en transaction read only, import validé, contenu tronqué/empreintes modifiées refusés, identités SQL et sources privées préservées. Fixtures uniquement, aucun paquet production reçu.
- **2/2 manifeste** toujours réussis, manifeste conservé sans réécriture.
- **74/75 outillage principal** rejoués sur17.6 : même échec explicite de composition95, sources tarifaires457 contre ancien plan452. Ne pas changer cette attente sans le delta complet439.
- **9/12 globaux** réexécutés avec pglast disponible : Baseline, Authority, Referential rouges. L'anomalie policy est retirée par correction du détecteur, pas par changement de références ; les19 écarts RPC demeurent. Baseline=miroir ordres_couts ; Referential=cinq divergences déjà documentées.
- Workflow conforme ; syntaxe Python et diff vérifiés. CI GitHub distante non observée (accès API précédemment refusé).

## Coupe et limites restantes

Mesures nouvellement transmises par l'intégrateur : registre1021, dernière20261101134313, 439tarifs, MD5 canonique870e48d44fcaeabdbadbac31060570ce, sentinelle6de4a84c58ed9b2b, douze cardinalités/MD5 et ICU153.121. Ce sont des observations externes issues de requêtes distinctes. Elles ne remplacent pas les sixracines, les définitions, les439lignes et les contenus statiques d'une coupe cohérente. Aucune référence n'est renumérotée ou empreinte inventée.

À réception du paquet : le manifeste existant décrit les formats exacts, SHA transmis séparément, vérifications de coupe, imports via relais/générateurs et paramètres du pilote95. Le banc services est déjà prêt à lancer avec les trois chemins de binaires et un rapport hors dépôt ; le pilote complet requiert les sept sorties cohérentes et les deltas réellement observés. Le plan tarifaire, les seeds et les contrôles ne peuvent pas être rendus verts par simple substitution du MD5.

**Non exécuté :** certification1021 sixracines/douzeréférentiels ; installation95 sur ce clone ; rollback/rejeu de ce lot ;27HTTP métier ; CI distante du dernierSHA. #318/#324 restent à Claude, aucun doublon. Aucune écriture, migration, fusion ou livraison de production. **CHANTIER NON TERMINÉ**, paquet privé complet toujours bloquant après les travaux indépendants réalisés.
