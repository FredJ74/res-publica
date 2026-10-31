# #219 — CI réparée, livraison encore retenue

31 octobre 2026. Branche `codex/groupes-universels-20261028`, PR #219 toujours en brouillon. Main relu via Git : `59ea6d901241eb3f55bd89a472a7f6617a6b1fb9`, déjà intégré. Les modifications de #258/#260 et suivantes restent présentes. Aucune fusion ni modification de production.

## Corrections livrées

- `75d849c2` : le lecteur restaurant ne remplace plus une fonction explicitement demandée dans une migration par une entrée historique du baseline. C’était la cause du `KeyError: raison` : la contre-épreuve n’exécutait pas le moteur prévu. Le sommeil utilise dans ce décor les définitions historiques de bonus épinglées au même commit public que les autres entrées. Réservation : **49/49** sur PostgreSQL 17.6 et 16.2 du gestionnaire CI ; restaurant **94/94**. Aucune assertion retirée.
- `6ef82a65` : les erreurs suivantes du workflow ont été recherchées en exécutant toutes ses étapes Python, sans arrêt au premier échec. Réutilisation du lecteur commun pour les archives, morceaux de fonctions et séquences ; listes de versions explicites à la place de globs devenus vides. Entrées des transformations anciennes épinglées et vérifiées par SHA256, sans élargir les gardes SQL. Aucun fichier SQL de jeu modifié.
- `18d54366` : preuves et diagnostic des 19 écarts ; lecture des arguments RPC corrigée pour les commentaires et accolades citées. **496 fonctions recensées conservées**, y compris les appels embarqués en HTML. Quatre tests couvrent aussi les faux paramètres imbriqués. Le `p_fn` des impôts n’est plus perdu dans un commentaire. Les arguments propagés par spread restent une limite déclarée du lecteur, pas une preuve de signature complète.

Ces corrections de fixtures n’attestent pas que les anciennes préparations soient compatibles avec le catalogue vivant. Exemple explicitement testé : le payeur actuel refuse un mouvement d’organisation de 5,50 FR sans débit ; le banc historique des équipements revient ensuite à ses entrées cohérentes d’origine. Cette incompatibilité n’a pas été corrigée en production et les migrations d’organisations restent hors du paquet.

## Tests et contre-épreuves

- **43/43 commandes Python** du workflow Cohérence exécutées localement, y compris les étapes après la réservation auparavant masquées par son arrêt.
- **150/150 bancs clients** et **105/105 tests du pilote Chromium** ; aucun compte réel, aucune campagne Arnie.
- **40/40 tests d’outillage** ; notamment refus de SHA altéré, prérequis omis, non-substitution de la source SQL et diff de contenus monétaires.
- **379/379 scénarios groupes** repassés. Six mutations exécutées chacune sur les 379 cas et détectées par les assertions.
- Réserve conservée : le vérificateur temporaire exigeant exactement la liste historique des échecs d’une mutation a échoué pour `issue-fausse`. Le cas obligatoire `squatteurs_issue_reelle_obligatoire_tues` détecte la mutation ; un autre combat à issue variable n’a pas produit le second échec historique. Cinq autres listes identiques. Aucun cas supprimé, résultat brut conservé.
- Les assertions immobilières (324), inventaire, transactions, police, prison, radio, rounds, déplacements et calendrier présentes dans le workflow passent dans ses décors. Ce sont des tests SQL avec identités/services périphériques de fixture, pas une recette GoTrue réelle.

Preuves : `preuves-finalisation-219-20261031/` et preuves canoniques précédentes. Les exports privés restent hors Git.

## Six workflows distants : résultat réellement consulté

L’API Actions reste refusée. Alternative utilisée avec succès : lecture publique de la page `/pull/219/checks`, SHA explicitement contrôlé dans sa réponse. **Six succès sur `6ef82a65dc3f8ecb5a18a874194109626ea85188`** :

| Workflow | Exécution réussie |
|---|---|
| Cohérence client et transactions locales | [41214656628](https://github.com/FredJ74/res-publica/actions/runs/41214656628) |
| Parcours immobilier cinq terrains | [41214656592](https://github.com/FredJ74/res-publica/actions/runs/41214656592) |
| Placement national transactionnel | [41214656596](https://github.com/FredJ74/res-publica/actions/runs/41214656596) |
| Tests détention calendrier universel | [41214656597](https://github.com/FredJ74/res-publica/actions/runs/41214656597) |
| Tests fermetures calendrier universel | [41214656611](https://github.com/FredJ74/res-publica/actions/runs/41214656611) |
| Garde du payload Vercel | [41214656642](https://github.com/FredJ74/res-publica/actions/runs/41214656642) |

Les succès de ce SHA ne doivent pas être attribués automatiquement aux commits suivants. La page publique permet de vérifier les prochains résultats sans demander au propriétaire de manipuler les secrets.

## Authority : 19 écarts de capture, 12 résolus dans le lot

Le contrôle du catalogue capturé reste distinct du contrôle APRÈS installation locale. Il ne doit pas présenter les nouvelles fonctions #219 comme déployées. Inventaire individuel, signatures demandées, sites, fonctions englobantes et migrations : `AUTHORITY-19-219-20261031.json`.

**12/19** sont résolus par les 89 installations déjà éprouvées ; leurs signatures et EXECUTE authenticated sont vérifiés dans la preuve locale. Les **sept contrats restants** ne sont pas couverts par ce paquet :

- `organisation_commande_administrative`, `organisation_commande_evenement`, `organisation_commande_membres` ; `sbOrganisationCommande` tente ces contrats et prévoit le cas `PGRST202`. Un repli prévu ne prouve pas leur déploiement.
- `organisation_equipement_acheter`, `organisation_equipements_etat`, `organisation_equipement_deplacer`, `organisation_equipements_payeurs` ; appels présents dans les interfaces commerce et équipements. Ils ne sont pas classés morts sans preuve.

Ne pas importer les 65 préparations historiques pour effacer ces écarts. La preuve plus stricte APRÈS lot signalait 17 formes supplémentaires/anciennes : certaines RPC existent mais leur ancien droit est fermé, le spread de `tournee_creer` n’était pas résolu, et le `p_fn` des impôts était mal lu (corrigé depuis). Cela n’équivaut pas à 17 fonctions absentes ; pas de faux résultat zéro après installation. La recette authentifiée isolée reste nécessaire.

## Referential : ce qui est connu et ce qui manque réellement

**Global toujours 10/12**, Authority et Referential rouges. Aucune attente, observation ni empreinte n’a été modifiée pour le faire passer.

Le relais canonique complet a été vérifié : quatre exports de catalogues, registre, contrôles et 474 INSERT de dix référentiels. **Il ne contient pas les lignes de `ordres_couts`**, seulement le nombre 438 et des empreintes. Le générateur actuel fournit 427 triples. Ce delta net de onze ne permet pas de nommer onze lignes absentes : il peut aussi résulter d’ajouts, suppressions et changements de couples PA/prix. La contre-épreuve +12/-1 le démontre. Aucune attribution de tarif ou de règle n’est inventée.

Comparaison prête, strictement en lecture seule : `comparer-couts-captures.py --requete` produit une transaction READ ONLY datée, avec snapshot et les colonnes publiques fn/pa/cost ; `--capture <json>` calcule communs, contenu présent seulement dans la capture et contenu présent seulement dans la source, refuse les doublons et types invalides. Ni connexion distante ni réécriture du baseline. Cette requête supplémentaire vise les contenus de référence manquants, pas une nouvelle demande des quatre exports déjà reçus.

Postes nommés et ressources : les empreintes fraîches du contenu concordent avec les générateurs, leurs sentinelles sont périmées ; les anciennes observations versionnées sont distinctes et conservées. PA et villes concordent. Pour les miroirs chantiers, entreprises et BNE, les contenus vivants ne figurent pas non plus dans les dix tables reçues : comparer leurs lignes canoniques avant toute mise à jour de déclaration. Les contrôles restent rouges tant que cette réconciliation n’est pas prouvée.

## Paquet et ordre de livraison — SUSPENDU

La reconstruction 17.6 réussie n’a pas été recommencée. Le paquet re-préparé par `preparer-groupes-219.py --inclure-prerequis-233` est **identique octet pour octet** au paquet de 89 migrations déjà installé/testé en une transaction ; empreinte enregistrée dans `integrite-paquet.json`. Le prérequis #233 y précède les 88, sous le même BEGIN/COMMIT, les mêmes gardes et contrôles de données. Panne tardive : registre revenu à 1003, fonctions/relations et fiche fictive préservées. Les 65 autres préparations ne sont pas incluses.

Ordre exact conditionnel pour l’intégrateur, aucune exécution autorisée par ce rapport :

1. Finir la comparaison des contenus référentiels et traiter les sept contrats hors lot avec leurs responsables ; revalider les contrôles sans exception artificielle.
2. Prévol vivant frais, lecture seule : registre et absence des versions déjà appliquées, définitions/signatures, RLS, triggers et ACL des dépendances. Vérifier les changements après la capture de 11:35:45 UTC ; ne pas considérer une ancienne empreinte comme preuve de l’état actuel. Aucun connecteur Supabase vivant callable ici, donc prévol **non effectué**.
3. Obtenir l’autorisation de production et valider un canal capable d’exécuter le paquet **entier en une transaction**, sans limite MCP qui le tronque ; aucune activation isolée de #233.
4. Préparer la sauvegarde/retour avant commit avec l’intégrateur ; au moindre refus prévol ou erreur, rollback de la transaction entière, pas de remplacement partiel de définitions. Après commit, pas de restauration aveugle d’une ancienne base qui écraserait les nouvelles actions de joueurs.
5. Dans la fenêtre de livraison autorisée, installer le paquet validé, vérifier les registres et intégrités avant de rendre le client correspondant accessible. Fusion/déploiement coordonné uniquement après conformité, en conservant les dernières protections de main.
6. Recette GoTrue sur ressources/comptes réservés : groupes mixtes, transport payé par le leader, refus sans débit partiel, détection avant interception, remise à la police, écrou, rounds, repli, radio, reconnexion et rejeux. Arnie reste en consultation seule.
7. Réextraire le baseline après application attestée, régénérer avec les outils canoniques, observer les contrôles et la production réelle. Aucune réécriture manuelle du SQL généré.

**Non livré en production. Pas de fusion. Aucun joueur modifié.** Le blocage actuel n’est plus la reconstruction ni la CI de réservation ; ce sont les contenus référentiels indisponibles, les contrats d’organisations hors lot et le prévol vivant/recette authentifiée encore absents. Luthécia n’est pas techniquement clôturée.
