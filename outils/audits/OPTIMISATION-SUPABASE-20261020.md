# Optimisation Supabase — 20 octobre 2026

Projet `jxpwoosmmhohoihxpbuc`, organisation `jbhuwfahomxtfihjiwej`, suivi GitHub #55.
Branche indépendante : `codex/optimisation-supabase-20261020`.
Base `main` revérifiée par fetch : `baa9cb7e2b7f89db66cf268d21382deb0be2a3a2`.

**Correctifs testés localement et sauvegardés. Aucun déploiement de production confirmé, aucune mesure de facturation distante, aucune garantie de retour sous quota.**

## Diagnostic et preuves

Les huit compteurs sur 24 h et les quelque 1 500 requêtes/h nocturnes sont ceux fournis dans la mission. Ils n'ont pas pu être relus dans les journaux vivants. Fenêtre exacte, versions clientes, sessions actives, tailles et compression des réponses sont inconnues. Ces nombres ne permettent pas d'attribuer les 275 Go à une ressource ni d'établir une consommation par joueur.

| Chemin examiné | Défaut confirmé dans le code | Conséquence |
| --- | --- | --- |
| Titulaires toutes les 30 s | Lecture de l'annuaire contenant photos et domiciles | 120 lectures/h/onglet visible avec portraits inutiles au calcul des titres |
| Photos de présence | Annuaire complet même sans autre PJ ; cache vide non reconnu comme valide | Transferts et lectures inutiles |
| Sauvegarde personnage | Réponse du PATCH contenant la fiche entière ; la file consomme seulement succès/existence et `updated_at` | Renvoi de photo, inventaire et historique inutilisés |
| Présence | Réponse de l'upsert contenant le groupe et ses portraits | Corps répété ; aucun des quatre appelants ne consomme ces champs |
| Réception d'invitations | Deux GET simultanés pour le même destinataire | Lectures mutualisables sans changer les circuits dîner/tournée |
| Minuteurs | Garde existante absente de certains premiers chargements, réveils et traitements différés | Chevauchements possibles en cas de réponse longue |

`plateau-personnage.js` accepte les portraits en data URL (`FileReader.readAsDataURL`). Une photo volumineuse augmente donc chaque ancienne lecture d'annuaire et réponse de sauvegarde. Le dépôt atteste ce chemin, mais ne donne pas les tailles actuelles des portraits. **Inefficacité démontrée, origine du dépassement facturé non démontrée.**

Les pollings expliquent des requêtes régulières sans action manuelle, sans prouver le nombre d'onglets actifs lors des heures observées. Au maximum théorique, la paire de réceptions d'invitations à 12 s produit 600 GET/h/onglet visible, avant la vérification des tournées de l'offreur. Les trois files différées à 90 s font 120 lectures/h/onglet même masqué. Les sauvegardes de sécurité peuvent ajouter lecture et écriture toutes les 30 s. Ce sont des cadences de code, pas des mesures supplémentaires de production.

## Mécanismes déjà présents, conservés

- `sbGet` mutualise les GET identiques simultanés par session ; anti-rafale de 1,5 s limité à trois tables et invalidation lors des mutations.
- Plusieurs vues sont déjà suspendues en onglet masqué ; notifications chat protégées ; conversation à 8 s seulement visible.
- Le championnat utilise déjà calendrier et non-chevauchement ; le direct à 20 s est limité à la fenêtre dominicale de Paris. Aucune cadence sportive modifiée.
- `vercel.json` déclare deux crons quotidiens. Pas de boucle perpétuelle de polling trouvée dans les fonctions API examinées ; les tâches externes et exécutions réelles restent inconnues.
- Chat et journal ont déjà des accès/projections dédiés. Aucun moteur de dialogue, presse ou cron modifié.
- Pas de client Supabase Realtime/WebSocket trouvé dans le code applicatif actif recherché ; cela n'exclut pas un consommateur distant.
- Storage sert des avatars d'organisations, décors commerciaux et publicités ; les scènes utilisent aussi les assets Vercel. Taille des buckets, caches CDN et trafic facturé indisponibles. Aucun bucket supprimé ou modifié.

## Corrections et fichiers

1. `supabase.js`, `plateau-multijoueur.js` : titres lus via `select=name,poste`, sans photo ni domicile. Annuaire historique conservé pour les autres usages, cadence et recalcul des secrétariats municipaux inchangés.
2. Mêmes fichiers : projection `name,photo_url`, filtrée sur les autres PJ affichés dans la pièce. Aucun chargement de portraits pour une pièce vide. Forum, messagerie et organigrammes conservent l'accès aux photos complètes. TTL de 60 s conservé, y compris pour une absence de photo ou un cache vide ; lectures concurrentes sérialisées puis seules les références manquantes sont demandées. Lots de 100 noms et échappement des valeurs PostgREST.
3. `plateau-multijoueur.js` : cache séparé par compte/session, ancien retour ignoré ; après attente des photos, contrôle du personnage, pays, ville et pièce avant publication des présences. Position et permissions restent serveur.
4. `supabase.js` : réception commune filtrée `attente OU (tournee_id non NULL ET acceptee)`, limitée au destinataire ; chaque helper conserve ses lignes dîner/tournée. Mutualisation par le GET simultané existant, sans TTL ajouté ni cache entre deux vérifications. Aucune modification des réponses, paiements ou gains.
5. `supabase.js` : réponse de sauvegarde limitée à `name,updated_at`, présence à `name`. Méthodes, corps écrits, file, inventaire révisé, contrôles et journal serveur des déplacements conservés. La détection d'une fiche absente reste effective.
6. `plateau-core.js` : garde existante réutilisée pour premiers chargements, rafraîchissements et réveil des voyants. Dons, vols et impacts restent à 90 s **même masqués** ; seul le chevauchement est empêché. Présence à 30 s et sauvegardes périodiques conservées. Ce verrou local n'est pas une protection financière multi-onglets ni une transaction serveur.
7. `plateau.html`, `index.html` : versions des scripts corrigés actualisées.
8. `outils/bancs/banc-optimisation-supabase.cjs` et fixture historique : régressions et mesures comparables ; fixture autonome compatible checkout Git shallow. `banc-continuite-municipale.mjs` : nom du mock adapté à la projection dédiée, sans changement d'assertion.

Aucun fichier métier immobilier (`plateau-justice-economie.js`, `plateau-pnj.js`, `plateau-chantiers.js`, `plateau-immobilier.js`, navigation, migrations) modifié. Aucun tarif, horloge, scrutin, contenu de dialogue, transaction métier, abonnement ou Spend Cap modifié.

## Mesures avant/après

Le banc exécute les vraies fonctions avec des réponses REST simulées projetées selon les paramètres. Les deux fonctions historiques proviennent du commit de base, avec empreinte ; aucune assertion existante neutralisée.

| Scénario local comparable | Avant | Après |
| --- | ---: | ---: |
| 20 PJ fictifs, portraits 32 Kio, 2 PJ visibles, 20 ticks de 30 s, titres/photos uniquement | 19 748 370 octets JSON, 30 GET | 657 570 octets JSON, 30 GET |
| Deux helpers de réception simultanés | 2 GET distincts | 1 GET |
| Cinq demandes successives d'un cache photo vide dans le TTL | 5 lectures | 1 lecture |

Le premier cas mesure environ **96,7 % d'octets JSON en moins dans cette fixture**, avec le même nombre de GET. Le deuxième économise 50 % des requêtes de cette paire, pas du jeu entier. À 12 s, gain théorique maximal de 300 GET/h/onglet visible lorsque les deux vérifications partent ensemble ; modal ouverte et désynchronisation modifient ce gain. Aucun chiffre mensuel extrapolé.

Les réponses de PATCH/upsert réduites dépendent des tailles réelles des fiches et groupes : colonnes et identité des corps vérifiées, mais aucun pourcentage réel inventé. Les octets de fixture ne sont ni compressés, ni des octets TCP, ni une mesure facturée Supabase.

## Vérifications

- **24/24 tests ciblés après revue de la PR #56**, dont deux contre-épreuves historiques : filtres/statuts, erreurs HTTP/réseau, changement de session, retours tardifs, suppression de photo, concurrence, sauvegarde et présence/journal.
- **92/92 bancs client**, notamment navigation, dialogue PNJ, sport, mails/forum, finance, réception, chantier, location et continuité municipale.
- **90/90 contre-épreuves historiques** ; aucune assertion désactivée.
- **25/25 tests municipaux** inclus dans le contrôleur. Le mock ancien a d'abord provoqué deux échecs : il a été raccordé au nouveau helper, en conservant les assertions de rôles, vacance et identité.
- **5/5 tests calendrier**, **69/69 tests du pilote local**, avec fixtures et sans Arnie/authentification réelle.
- Syntaxe des scripts modifiés et des 23 modules API, garde payload Vercel et `git diff --check` conformes.
- Contrôles globaux : **10/12**. Authority : 28 RPC sans définition dans le baseline archivé. Referential : trois empreintes divergentes (`ordres_couts`, `postes_nommes_regles`, `miroirs_entreprises`). Aucune baseline ni empreinte falsifiée.
- Aucun test authentifié distant, test de charge en production, résultat GitHub Actions distant ou déploiement confirmé.

Résultats et commandes : `RESULTATS-OPTIMISATION-SUPABASE-20261020.json`. Les bancs historiques utilisent leur adaptateur JavaScript local existant, sans retrait d'assertions.

## Accès, livraison et suite technique

Aucun connecteur Supabase ni accès aux métriques n'est disponible. HTTPS vers le projet échoue au tunnel proxy (`CONNECT 403`), avant Supabase : ce n'est pas une erreur du jeu ni une panne fournisseur démontrée. Aucune donnée de joueur consultée ou modifiée par les tests.

Git fetch/push fonctionne. La PR #56 a depuis été créée par ChatGPT ; sa référence Git a été récupérée et comparée à la branche. L'API GitHub REST comme GraphQL répond toujours `Forbidden` : ticket #55, résultats des Actions et métadonnées de PR restent inaccessibles. La description proposée est conservée dans `PR-OPTIMISATION-SUPABASE-20261020.md` et n'a pas pu être actualisée via l'API. Aucune fusion ni activation automatique.

Commit principal : `7a025fb60657af75a9950df7efbd9dd77a96ef43`. Le commit de documentation/contre-épreuve supplémentaire figure dans le compte rendu final.

Branche prête pour revue, **pas validée en production** ; aucune migration à appliquer. Dès accès API rétabli : contrôler les résultats de la PR #56 et sa Preview, vérifier les projections REST et les parcours présence, portraits, mandats, messagerie/forum et invitations sur le vrai projet. Ne pas fusionner sur le seul pourcentage de fixture.

Comparer ensuite des fenêtres de 24 h de fréquentation similaire, puis plusieurs jours incluant le dimanche : ventiler egress base de données, Storage/CDN, Realtime, Auth et fonctions, octets/erreurs par route, sessions/heures actives et versions clientes. Contrôler réveil d'onglet, actualisation des portraits, invitations et tâches quotidiennes. Ces opérations restent techniques ; aucune manipulation SQL/GitHub n'est déléguée au game designer.

Retour arrière : revert des commits de cette branche, sans migration ni purge de données. **Risque de dépassement non quantifié** : autres réponses, portraits persistants, Storage, consommateurs externes et anciens onglets peuvent rester coûteux. Aucun changement de stockage ou baisse de fréquence métier n'est ajouté sans mesure démontrant sa nécessité.

## Complément de revue de la PR #56

Deux cas ont été reproduits en échec avant correction : arrivée tardive de présences de rue après entrée dans un bâtiment (le nœud restait mémorisé), et tournées masquées par une page pleine de dîners dans la nouvelle lecture commune. Le premier contrôle désormais aussi le bâtiment et la pièce de départ. Le second utilise des pages de 100 lignes ordonnées par clé `id`, sans offset ; il refuse pages incohérentes, identifiants numériques arrondis et changements de session, et ne publie aucune lecture partielle en cas d'échec. Les petits ensembles continuent à partager un seul GET ; les grands ensembles nécessitent plusieurs pages.

La compatibilité locale a été éprouvée sur les DDL archivés de `personnages_donnees`, `personnages`, `presences`, `invitations_diner` et leurs clés. Le nouveau banc PostgreSQL est intégré au workflow existant, sans nouvelle infrastructure. Ses fonctions d'authentification sont des fixtures et il ne charge pas les triggers/RLS de production : il ne certifie ni PostgREST vivant ni un compte réel.

Préconditions restant à vérifier sur le projet vivant : colonnes et types, droits SELECT/UPDATE/INSERT, triggers de la vue, policies RLS, traitement REST des projections/retours et de l'union, limite de réponse PostgREST d'au moins 100 lignes, représentation exacte des identifiants bigint (les nombres hors précision sûre sont refusés). Les tests réels de sauvegarde/présence doivent utiliser un compte isolé autorisé, jamais les données d'un joueur.

Les 14 bancs PostgreSQL du workflow ont été rejoués localement et réussissent. La revue ne donne pas le feu vert à la fusion tant que les Actions distantes et ces contrôles Supabase restent invérifiables. Voir `REVUE-PR56-20261020.md` et `RESULTATS-REVUE-PR56-20261020.json`.
