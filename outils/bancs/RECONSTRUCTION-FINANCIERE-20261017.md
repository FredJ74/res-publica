# Reconstruction financière contrôlée — 17 octobre 2026

**CHANTIER NON TERMINÉ. Ne pas appliquer les migrations financières ni fusionner cette branche dans `main`.**

La reconstruction est sauvegardée sur GitHub, branche `codex/reconstruction-finances-atomiques`. Elle n'est pas encore un remplacement complet des anciens circuits. L'accès au catalogue Supabase manque, mais ce n'est PAS le seul blocage : des raccordements et des transactions restent à développer.

## Reprise vérifiée et sauvegardes

La branche part de `main` au commit `1efd28516847086c2f5443ce492c3937958cbdfb`. Les évolutions suivantes du forum jusqu'à `2d65db3` ont été intégrées **dans la branche financière**, sans conflit (`1c9910308dc2bb37aabf70aecedc2174d0f30b88`). Aucune fusion financière dans `main`.

Sauvegardes successives, toutes poussées :

| Commit | Contenu |
|---|---|
| `0b1f3a6` | Montants exacts en francs et tests |
| `34f6051` | Conversion stricte préparée et loyers banque puis liquide |
| `086b544` | Réception atomique des dons, reçus et concurrence |
| `7e804ea` | Référentiel du Journal réaligné sur les 18 ressources |
| `d0b18de` | Huit opérations Helvetia encapsulées et testées |
| `8eeb816` | Garde serveur des sauvegardes et transport durable préparés |
| `787d03e` | Vente atomique de bois et portrait affichant le liquide |
| `94d14d8` | Contre-épreuves, précontrôle en lecture et cartographie |
| `78bfb29` | Gardes de schéma et révisions des comptes |
| `1c99103` | Intégration des dernières corrections de `main` dans la branche |

Le JSON de vérifications identifie le commit de code testé. Le commit documentaire final est donné dans le compte rendu GitHub, pour éviter une référence circulaire dans ce fichier.

## Ce qui est effectivement reconstruit

### Précision et conservation

`monnaie.js` calcule exactement avec des entiers internes représentant les centimes ; le stockage proposé reste en **francs décimaux**, sans multiplication ni division des soldes par 100. Les montants transportés sont des chaînes canoniques. `5.50` reste `5.50`. Les nombres flottants et fractions de centime sont refusés ; la passerelle historique n'accepte que les nombres entiers sûrs.

La migration `20261017090342_precision_monetaire_reconstruction.sql` prépare un domaine `numeric` sans typmod susceptible d'arrondir avant vérification. Elle couvre onze colonnes : les trois montants du personnage, le solde bancaire, deux montants des placements, trois montants des prêts et les montants des deux tables de dons. Elle conserve les NULL. Une valeur historique hors centime bloque la transaction ; elle n'est pas corrigée silencieusement.

La vue réelle `personnages`, ses ACL, options, propriétaire, commentaires et triggers sont mémorisés et recréés. `DROP RESTRICT` bloque une dépendance non prévue. Les états de triggers non standards et les triggers DDL actifs nécessitent examen. Les tests utilisent la vraie vue et le vrai trigger archivés, pas seulement un schéma réduit inventé.

Cela ne prouve PAS que toutes les colonnes monétaires et tous les JSON de production sont couverts. Les JSON de caisses, les autres colonnes et les calculs historiques restent dans le périmètre de l'audit.

### Loyers : nouvelle règle validée

`20261017090621_loyers_banque_prioritaire_atomiques.sql` conserve les destinations et mécanismes d'impayés du prélèvement existant. Elle change la source du paiement : compte(s) national(aux) du pays du locataire en premier, puis complément liquide. Helvetia, placements et comptes étrangers sont exclus de ce prélèvement ordinaire. `arg` n'est plus utilisé comme source de prélèvement.

Le total disponible est vérifié sous verrou avant tout débit. Insuffisance totale : aucun débit ni crédit partiel ; les avertissements et impayés continuent selon le circuit existant. Crédit du bénéficiaire, débit et marqueur journalier restent dans une transaction. Le rejeu quotidien et deux connexions concurrentes ne paient qu'une fois. Un échec après crédit annule toute l'opération.

La fonction reste réservée au serveur. Les tests des recettes municipales utilisent un service annexe de fixture explicitement déclaré ; ils ne certifient pas les recettes municipales vivantes.

### Dons, reçus et révisions

`20261017090721_receptions_dons_atomiques_et_revisions.sql` ajoute les reçus privés par utilisateur et UUID, les révisions financières et la réception transactionnelle. Un UUID confirmé ne peut changer de personnage ni de corps. Marquage et crédit sont atomiques. Deux demandes distinctes pour le même don ne créditent qu'une fois. Les droits directs de marquage et suppression sont fermés dans la migration préparée.

L'allocation historique est conservée : la réception créditait `arg` seul ; elle n'est pas transformée arbitrairement en crédit liquide. Le portrait continue donc de représenter exclusivement le liquide.

Les mouvements de comptes seuls incrémentent aussi la révision. Un rejeu conserve son résultat historique mais transporte une photographie actuelle, pour ne pas republier un ancien solde après un crédit serveur.

### Helvetia

`20261017091047_helvetia_requetes_atomiques.sql` réutilise les huit fonctions archivées : ouverture, dépôt, retrait, placement, prêt, remboursement, accord, fermeture. Elle contrôle identité, présence réelle au bureau, montant chaîne au centime, capital entier du prêt et paiement serveur des PA. Reçu et contreparties sont dans la même transaction ; les anciennes RPC directes sont révoquées dans le SQL préparé.

Les tarifs, taux, arrondis et comportements historiques sont conservés. Notamment la fermeture existante conserve le compte avec solde nul : le test vérifie cette réalité, sans inventer une suppression de compte.

### Garde des sauvegardes — pas encore activable

`20261017091428_garde_sauvegardes_financieres.sql` interdit qu'une modification financière soit introduite par la vue générale. Une sauvegarde non financière reprend les soldes canoniques verrouillés. Les actes autorisés utilisent un marqueur privé lié à la transaction, inaccessible au navigateur ; un GUC falsifié ne suffit pas.

**Danger d'activation prématurée :** les anciennes fonctions et interfaces qui écrivent encore les montants par la vue seraient refusées. Le refus SQL annule leurs contreparties transactionnelles, mais les anciens circuits à plusieurs requêtes et leurs miroirs restent à remplacer. Cette garde ne doit donc pas être appliquée isolément.

`finances-exactes.js` prépare le transport persistant : intention figée avant envoi, même UUID après une réponse perdue et après réouverture, mutualisation du double clic, contrôle du personnage/session, refus d'une réponse financière invalide et invalidation des réponses anciennes. **Le module n'est pas chargé dans les pages : le raccordement global n'est pas terminé.**

### Bois d'imprimerie

`20261017091745_bois_imprimerie_transaction_atomique.sql` associe dans une transaction : retrait du bois réel, entrée au stock, débit de la caisse, crédit liquide et `arg`, reçu. Prix serveur : canon du bois à 5 FR + 10 %, soit exactement 5,50 FR. Le plafond PNJ de 10 et la vente partielle limitée par la caisse/capacité sont conservés. Un miroir tarifaire différent est refusé pour examen.

Les lieux autorisés sont ceux des configurations existantes de Républia. Le contrat inventaire atomique préparé le 16 octobre est requis. Des postconditions relisent inventaire, révision, soldes, caisse et stock ; une écriture non appliquée annule l'ensemble.

**Le vieux bouton et le helper général de caisse ne sont pas encore remplacés/fermés partout. Ce circuit ne doit pas être annoncé sécurisé en production.**

### Affichage et Journal

Les deux écritures du compteur sous portrait dans `plateau-core.js` lisent désormais `liquide`. Le test exécute le vrai `updateUI()` et compare portrait/inventaire avec zéro, centimes et soldes bancaires distincts. La fiche de fortune n'est pas simplifiée.

La table du Journal utilisait des prix fournisseurs à la place des prix du canon et omettait des ressources. Elle a été corrigée réellement. Le générateur inclut les laitages à la position déjà présente dans l'artefact serveur ; il régénère un fichier identique. Le test fonctionnel mesure désormais une seule divergence voulue (ressource inconnue : null plutôt que zéro), au lieu de 109. La déclaration a été mise à jour APRÈS cette correction et son exécution, pas pour masquer un défaut.

## Vérifications réellement exécutées

| Batterie | Résultat | Portée |
|---|---:|---|
| Lanceur client complet | **73/73 bancs** | Node et adaptateur des bancs historiques ; transports simulés |
| Reconstruction PostgreSQL | **29/29 groupes** | Base jetable ; vraie vue, trigger et fonctions archivées ; auth/services annexes explicitement en fixture |
| Achat commerce PostgreSQL existant | **12/12 groupes** | Local, services annexes simulés |
| Réception objets PostgreSQL existante | **31/31 groupes** | Local, aucun compte réel |
| Contre-épreuves historiques | **90/90** | Régressions injectées dans des copies |
| Contre-épreuves reconstruction | **9/9** | Sous-centime, double loyer, fonds insuffisants, priorité inversée, reçu falsifié, crédit perdu, sauvegarde périmée, prix bois faux, inventaire non débité |
| Bundle Vercel réel | **12/12 cas** | Inclus dans les bancs client ; constructeur épinglé `@vercel/node@5.3.25` |
| Syntaxe API | **23/23 modules** | Analyseur Node via adaptateur externe JSC |
| Workflow global | **10/12** | Autorité et Référentiels restent rouges |

Les contre-épreuves ajustent uniquement les gardes de définition de leurs COPIES MUTANTES afin d'atteindre les assertions métier, plutôt que de s'arrêter au simple refus d'une empreinte modifiée. Les sources du dépôt restent intactes.

Tous les anciens bancs SQL du dépôt n'ont PAS été exécutés : les 29 + 12 + 31 groupes ci-dessus n'équivalent pas à une reconstruction fonctionnelle de toute la base. Une tentative locale d'assemblage réel du baseline a rencontré la séquence `registre_ventes_armes_id_seq` déclarée deux fois (IDENTITY puis CREATE SEQUENCE autonome). Le contrôle statique existant reste vert : il ne constitue pas une preuve d'application réelle. Ce défaut préexistant est à traiter par le moteur de rendu et une extraction vérifiée, jamais par édition du SQL généré.

Aucun test authentifié Supabase, aucune vérification en navigateur connecté, aucun accès joueur. Aucun solde réel, livraison ou inventaire réel modifié.

## Deux contrôles rouges, sans dissimulation

### Autorité

Le baseline ne contient pas quatre portes déjà appelées par le client :

- `inventaire_reception_etat` ;
- `inventaire_reclamer_livraison` ;
- `inventaire_sauver_revision` ;
- `tracts_electoraux_distribuer_collectif`.

Les trois premières existent dans une migration préparée ; la quatrième existe dans une photographie SQL hors registre. Leur présence réelle en production n'a pas été observée. Une migration préparée ne vaut pas une fonction déployée : le contrôle reste rouge. Aucun faux ajout au baseline.

### Référentiels

Après correction de la cause du Journal et de l'ordre des 18 ressources, cinq problèmes restent déclarés par le contrôle :

- `ordres_couts` : calcul actuel `79ecb2f9d4bf71f5`, ancienne déclaration `20e52d8f9bbe8e3f` ;
- `postes_nommes_regles` : calcul actuel `694f117ace57b0b1`, ancienne déclaration `6c0c7aa0d29bf852` ;
- trois déclarations de divergences anciennes ne peuvent plus être rapprochées après ces écarts.

Les mesures historiques `reelle`, `posee` et les observations de base sont conservées. Il faut comparer les miroirs vivants et leurs lignes aux générateurs, corriger les écarts confirmés, puis remesurer. Aucune empreinte n'a été inventée pour obtenir 12/12.

## Blocage externe et précontrôles

Aucun outil Supabase n'est exposé. Les variables usuelles de connexion/catalogue et de service sont absentes ; la lecture OpenAPI via l'URL et la clé publique déjà présentes échoue : `Tunnel connection failed: 403 Forbidden`. Aucun contournement de proxy n'a été tenté. Une clé publique ne donnerait de toute façon pas accès au catalogue administratif complet.

`PREFLIGHT-FINANCIER-RECONSTRUCTION-LECTURE.sql` prépare une transaction exclusivement en lecture : colonnes, fonctions réelles, droits, RLS, triggers, dépendances et agrégats financiers, sans noms ni soldes individuels dans la sortie. Ce précontrôle ciblé ne remplace pas l'export des quatre ensembles du workflow : `export_structure`, `export_fonctions`, `export_logique`, `export_droits`, fournis par `outils/baseline/requetes.py`.

L'agent devra aussi compléter les contrôles des valeurs financières dans les JSON et des autres colonnes à partir du catalogue réel. Cette action n'est pas déléguée au game designer.

## Implémentation et raccordements restant réellement à faire

| Domaine | Situation au présent commit |
|---|---|
| Dons | SQL local testé ; récupération client encore ancienne |
| Helvetia | Huit actes SQL locaux testés ; formulaires et wrappers historiques encore à raccorder |
| Bois | Acte SQL local testé ; bouton et droits de caisse historiques encore à remplacer |
| Prêts classiques | Création et crédit encore séparés ; échéances, dettes, pénalités et saisies cron encore multi-requêtes |
| Fret | Réservation, dépôt/reprise, transfert, vente et transport à réunir avec toutes leurs contreparties ; droits directs encore à fermer |
| Douanes | Tirage, PA, confiscation, convocations et marqueur à rendre transactionnels et rejouables |
| Ateliers/production | Écritures de stocks, caisses, objets et salaires à auditer et raccorder intégralement |
| Successions | Circuit serveur présent, mais compatibilité financière/droits et contre-épreuves spécifiques non certifiés |
| Calculs historiques | Nombreux traitements binaires/entiers et JSON encore à convertir sans changer leurs arrondis métier |
| Sauvegardes/écrans | Garde et transport préparés ; pas encore de remplacement général des écritures anciennes |

La cartographie statique `CARTOGRAPHIE-ECRIVAINS-FINANCIERS-RECONSTRUCTION.json` relève **117 fonctions SQL candidates et 264 points JavaScript**. Ce sont des candidats, pas autant de défauts prouvés ni une liste certifiée des écrivains vivants. Le SQL dynamique, les triggers et les Edge Functions doivent être comparés au catalogue réel.

## Déploiement et retour arrière — procédure réservée à l'agent

1. Finir les raccordements ci-dessus et fermer les accès historiques sans briser les autres actes. Rejouer tous les tests et les transitions de propriété.
2. Obtenir une lecture autorisée du catalogue, extraire les quatre ensembles et les miroirs, vérifier les données historiques et les dépendances. Résoudre réellement Autorité/Référentiels.
3. Tester la séquence complète dans un environnement isolé représentatif, avec authentification réelle. Préserver toutes les files et tous les personnages. Vérifier le payload Vercel et l'interface réelle.
4. Préparer une fenêtre contrôlée, une sauvegarde vérifiée et l'arrêt coordonné des anciennes écritures. N'activer aucun garde financier avant le client et les actes compatibles.
5. Exécuter les migrations dans une transaction orchestrée et revue ; leurs BEGIN/COMMIT individuels ne sont PAS un script d'orchestration déjà validé. Le contrat réception doit être présent avant le bois ; la table privée du garde doit exister avant tout appel Helvetia encapsulé.
6. Comparer avant/après les agrégats, NULL, nombres de lignes, livraisons et dettes. Vérifier toutes les devises et les rôles de service. Réextraire ensuite seulement le baseline et ses seeds avec les outils prévus.

Avant commit SQL, une erreur annule le DDL et les données de la transaction. Après ouverture aux opérations, **ne jamais retransformer aveuglément les montants en integer**, ni restaurer une photographie globale qui supprimerait les opérations nouvelles. Conserver les décimaux exacts et privilégier un correctif transactionnel en avant. Un retour de version applicative doit maintenir les gardes et la compatibilité monétaire ; il n'est pas encore qualifié.

## Périmètre préservé et phases suivantes

Les corrections graphiques et commerciales de `main` sont préservées. Le fichier `plateau-commerce-pj.js` est identique à celui du `main` intégré. Aucun autre PNJ, ville ou bâtiment n'est modifié. Aucune migration appliquée, aucune fusion financière dans `main`, aucun déploiement de production effectué ou vérifié par cet agent. Le résultat distant de GitHub Actions n'a pas été observé.

Commerce automatique, causes des champs de prix désactivés, navigation/infobulles et extension alimentaire demandée ne sont pas déclarés terminés. Conformément à l'ordre demandé, ils restent après la sécurisation financière ; la seule présence de tests alimentaires existants ne prouve pas le raccordement complet souhaité.

L'environnement Node/PostgreSQL local fonctionne. Les instructions reproductibles d'installation et de reprise ont été enregistrées en brouillon via le skill cloud-environment-onboarding:setup ; ce brouillon n'est pas une publication de l'environnement.
