# Goulag : installation en production vérifiée, activation interdite


## État définitif de l’installation — 21/11/2026

**Installation réellement effectuée et vérifiée, goulag toujours DÉSACTIVÉ.** Les deux confirmations techniques demandées à Fred ont été validées. Le contrôle distant a rendu `installation_verifiee_et_annulee`, ouverture `false`, puis ROLLBACK. Après nouvelle lecture (aucune installation concurrente), les **22 sources** ont été appliquées **en une seule transaction et une seule entrée de registre** : `20261121145200`, `goulag_installation_verrouillee_20261121`.

Le SQL enregistré par Supabase a été relu : un seul bloc, SHA-256 **b0c100bd52e4db7b691ebfa8904ed58e09c06b09ae61400ef6f11a21b0cbad6f**, identique au paquet soumis et à son archive `historique/migrations-appliquees/20261121145200_goulag_installation_verrouillee_20261121.sql`. Le contrôle annulé porte le SHA-256 `2614220a3f701412b5700bc90e8daa10d0801c7f0e20f001e6b6a18b0af3103a`.

### Vérifications durables

- Configuration : `active=false`, ouverture `false`, CHECK `sovarka_goulag_activation_figee` présent et validé. Aucun retrait du verrou, aucun personnage de production créé ou utilisé pour une recette.
- **15 tables**, toutes avec RLS et sans privilège direct SELECT/INSERT/UPDATE/DELETE pour anon, authenticated ou service_role. **46 fonctions** de ce périmètre : aucune exécutable par anon ; helpers internes fermés aux clients ; contrôle de minuit réservé au serveur ; lecture d’ouverture autorisée à authenticated et service_role.
- Quatorze tables métier vides ; seule la ligne de configuration est créée. Pas de détenu, dépôt, visite, incident, refuge, tentative ou interrogation produit par l’installation.
- Les sept empreintes métier du paquet ont passé avant le commit : personnages (argent/PA/inventaire/position compris), détentions, jugements, plaintes, règles des pièces et caisses d’autorités/bâtiments inchangés. Les deux seuls deltas de graphe prévus (camp et lien depuis l’école) sont contrôlés exactement ; toutes les autres routes restent identiques.
- En transaction READ ONLY, rôle authenticated **sans identité de personnage** : départ, voyage, condamnation, dortoir, interrogation et sanction refusés `non_authentifie`. Ce n’est pas une recette avec un PJ connecté.
- En transaction READ ONLY, rôle service_role : contrôle de minuit `ok=true, inactif=true` ; aucun traitement de détenu.
- HTTP réel avec la clé publique anonyme : lecture d’ouverture, départ et lecture directe de la configuration **401 / 42501** (permission refusée).
- Conseillers de sécurité : **188 avant / 188 après**, aucune nouvelle alerte détectée dans la comparaison ; les alertes antérieures ne sont pas traitées ici. Droits/RLS vérifiés directement, indépendamment de ce relevé.
- Tests post-installation : **29/29 Node**, vérificateur de workflow et contrôle des archives conformes. Les premiers sept faux échecs du vérificateur exécuté sans pglast disparaissent avec l’environnement Python/pglast requis ; aucune règle de test modifiée.

Dernière vérification durable : **21/11/2026 15:02:58 UTC** (16:02:58 Paris), ouverture et active à false, une seule installation enregistrée. Les preuves nommées ci-dessous correspondent aux réponses réellement obtenues.

### Protection complémentaire de l’ancien bouton judiciaire

Le contrôle du client complet a confirmé un défaut de couverture : l’ancien chemin `appliquerSentence` pouvait atteindre `deduireCoutOrdre` pour le QHS de Sovarka alors que les nouvelles portes serveur exigent le circuit atomique du goulag. Le banc de verrou initial comparait seulement le trajet client avec une fonction de sanction simulée.

Une garde est ajoutée **avant toute lecture métier, paiement ou sanction** dans cette ancienne porte pour Sovarka/QHS. Le circuit normal du goulag ouvert reste `sovarka_goulag_juger`, déjà atomique ; la garde ne l’active pas. Les autres pays et les peines de prison ordinaires conservent leur trajet. Aucun tarif ni serveur modifié par ce correctif client. Messages réutilisés tels quels.

Nouveau banc sur la vraie fonction : **6/6** après correction ; l’ancienne source reproduit **deux échecs** atteignant la porte de paiement. Double clic, ancienne porte même avec cache « ouvert », absence de dossier et contre-épreuves Républia/prison testés. Le banc de verrou/navigation/ordres reste à **29/29**, sans modification de ses exigences. La nouvelle épreuve est ajoutée à la CI et l’URL du script est versionnée. Ce correctif client est publié dans #1176 ; **il n’est pas annoncé déployé tant que la PR n’est pas fusionnée et la version servie vérifiée**.

### Réextraction et dette du baseline

Les **quatre requêtes canoniques exactes** de `outils/baseline/requetes.py` ont été rejouées en lecture seule. Captures privées conservées hors Git, empreintes/tailles dans `exports-canoniques-manifeste.json`. Aucun contenu de joueur n’a été exporté.

Le rendu officiel a été tenté vers un répertoire candidat isolé : il refuse **5 434 affectations manquantes**, avec notamment des objets de criminalité, climat, cliniques et commerces antérieurs à ce lot. Le baseline global reste à sa coupe du 01/11 : **il n’est pas annoncé actualisé**. Le diagnostic est joint ; aucun SQL de baseline n’a été retouché à la main et aucun objet étranger n’a été classé arbitrairement. La réconciliation globale du classement et le rendu complet restent une dette documentaire/reconstruction distincte de l’installation vérifiée.

Les 22 fichiers source demeurent disponibles pour les bancs et la reconstruction depuis l’ancienne coupe ; **ne pas les appliquer individuellement en production** : ils sont déjà installés comme paquet atomique identifié ci-dessus. Leur repliement dans le baseline et leur déplacement final devront accompagner la nouvelle coupe, sans casser les bancs qui les utilisent. L’assembleur refuse déjà une seconde installation si la configuration existe.

### Recette restante

Proposition concrète sans nouveau projet payant : [RECETTE-GOULAG-ISOLEE-20261121.md](RECETTE-GOULAG-ISOLEE-20261121.md). Docker est disponible dans le workspace ; aucun conteneur de recette ni projet Supabase supplémentaire n’a été créé. Le parcours interactif complet n’a pas encore été testé avec Fred ; le second feu vert de production n’est ni demandé ni présumé.

### Arrêt demandé par Fred

Après la migration courante, Fred demande l’arrêt sans en commencer une autre. Dernière lecture : `active=false`, ouverture `false`, contrainte validée et une seule installation enregistrée. Aucun nouvel ordre d’activation, migration ou création d’environnement lancé. La PR #1176 reste non fusionnée, donc sa garde client anti-paiement n’est pas annoncée déployée. CI sur le code `19b15b53` : 63 réussites, seul contrôle général encore en cours au moment de l’arrêt. La mise à jour qui consigne cet arrêt est documentaire ; elle ne réinstalle rien.

<details><summary>Historique de préparation et des confirmations expirées — dépassé par l’état ci-dessus</summary>

## Autorisation et état réel

Fred a autorisé l'installation des tables et RPC après un essai annulé, **pas l'activation**. La PR #1161 avait ses trois contrôles verts ; sortie du brouillon et fusion effectuées au commit `4ec629153e166c9a3cc3ca01013227f93d8f9283`. Le déploiement public READY `dpl_GAtusaPD2fx5bEChZHsZ9rdzzKn9`, SHA `1459aea3f054c99e12b0873408cb7738c3d8fdd9`, contient cette fusion (ascendance Git vérifiée). Ce déploiement n'installe aucune migration Supabase.

**Aucune installation durable effectuée.** Les dernières lectures Supabase donnent toujours `NULL` pour la configuration et la fonction d'ouverture. Le connecteur a renvoyé `status: expired`, message « This confirmation expired after 10 minutes » ; l'autorisation textuelle de Fred ne s'est pas traduite par une confirmation technique exécutée pour le dernier contrôle. Aucune tentative de contournement ni application durable sans contrôle final réussi.

## Paquet préparé

`outils/livraison/preparer-installation-goulag-20261121.py` assemble exactement 22 sources existantes, ordonnées, sans modifier leurs textes. La migration visuelle `20261116105000` est exclue : elle figure déjà au registre de production sous `goulag_cinq_pieces_visuelles_20261116`. Le script refuse un nombre de sources différent et toute transaction interne. Il ne se connecte pas, ne migre pas et n'active rien ; sa sortie SQL est destinée au contrôle puis au canal `apply_migration`.

- Essai : transaction explicite REPEATABLE READ et ROLLBACK, délais de verrous et d'exécution bornés.
- Empreintes avant/après de personnages (inventaire, PA, argent et position inclus), détentions, jugements, plaintes, règles des pièces et deux caisses. Aucune différence acceptée.
- Toutes les routes hors raccord des bûcherons doivent rester identiques. Les deux lignes de raccord sont vérifiées exactement, en préservant les anciennes destinations : création du point camp et ajout du seul lien prévu depuis la rue de l'école.
- Ouverture `false`, contrainte d'activation présente et validée, configuration désactivée et RLS exigées avant validation.

L'essai distant initial a exécuté les sources puis été annulé par le contrôle `donnees_metier_modifiees:rue_noeuds_serveur` : les migrations prévoient effectivement le raccord de deux nœuds. Il ne s'agissait pas d'une modification de personnages. Le contrôle a été précisé pour vérifier ce delta exact, tout en refusant tout autre changement. La nouvelle exécution a rencontré l'expiration de confirmation. Une exécution intermédiaire a perdu son résultat lors du remplacement du runtime : elle n'est pas comptée comme une réussite. Les lectures suivantes ne trouvent aucune installation persistante.

Le paquet précis et ses gardes ont été exécutés dans le décor PostgreSQL 17.6 **isolé**, sans migrations de goulag préinstallées : compilation des 22 sources, contrôles d'intégrité, verrou et rollback réussis ; configuration absente après rollback. Journal et manifeste dans `preuves-goulag-installation-20261121/`. Ce résultat ne remplace pas le dernier essai distant obligatoire. Aucun test existant n'est modifié.

## Reste à exécuter par l'agent

1. Obtenir une confirmation technique Supabase qui s'exécute réellement ; refaire le contrôle annulé et conserver sa réponse positive.
2. Recontrôler l'absence d'installation concurrente. Appliquer le même paquet structurel atomique par `apply_migration`, avec enregistrement, sans lever le CHECK ni activer.
3. Relire configuration, droits, RLS, refus et empreintes ; contrôler les conseillers de sécurité ; réextraire le baseline conformément à `WORKFLOW-SUPABASE.md` avant de déclarer l'installation close.
4. Publier les preuves réelles et actualiser le relais. Ne jamais transformer le présent état « préparé » en « installé » par simple mise à jour documentaire.

## Comment Fred pourra tester sans ouvrir la production

**Limite actuelle : il n'existe pas d'exception « personnage de test ».** Le serveur et le navigateur partagent un verrou global ; avec `active=false`, les RPC du goulag refusent également Fred et ses personnages de test. Forcer un affichage dans le navigateur ne permet pas de les utiliser. Retirer temporairement le CHECK et activer la production, même « quelques minutes », ouvrirait les mécaniques : ce n'est pas autorisé.

Le parcours interactif complet nécessite **une copie de recette isolée** avec une URL et une base distinctes, des comptes de test et aucun joueur réel. Aucun environnement de ce type n'est annoncé prêt dans cette reprise : la liste accessible ne contient qu'une production active et un ancien projet inactif, qui n'est pas réutilisé sans autorisation. Fred ne doit exécuter aucun SQL ni modifier lui-même le verrou.

Sur cette copie, une fois préparée et contrôlée par l'agent, Fred pourra :

1. Se connecter avec un juge de test de Sovarka et condamner un dissident de test. Vérifier qu'un ministre seul ne peut pas condamner.
2. Faire autoriser un visiteur par le ministre de test, puis tester le transport depuis les centres multimodaux et le retour libre du visiteur. Un détenu ne doit pas pouvoir emprunter ce retour.
3. Vérifier l'arrivée du condamné, la confiscation sauf clés et la restitution lors de la libération.
4. Essayer liste des détenus, registre, dortoir, cachot et mirador ; vérifier les coûts d'interrogatoire/sanction et le compteur de peine au sommeil.
5. Tester l'évasion et les deux itinéraires, puis le refuge, uniquement sur cette copie ; les essais automatisés peuvent accélérer les jours dans leur décor isolé, jamais sur les personnages de production.

En production fermée, Fred peut seulement confirmer que les nouveaux boutons restent absents et que les anciens parcours continuent de fonctionner. Ce contrôle de fermeture n'est pas une recette fonctionnelle du goulag. Le second feu vert de production reste distinct, après les tests prévus.

</details>
