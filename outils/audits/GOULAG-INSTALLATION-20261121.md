# Goulag : premier feu vert, installation préparée mais bloquée

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
