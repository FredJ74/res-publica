# Revue indépendante de l’internationalisation — PR #377

8 novembre 2026, Europe/Paris. **Verdict : CORRECTIONS NÉCESSAIRES.**

## Périmètre et version

- SHA réellement audité : `6173d9a4ede2d2e27b10f4d8557c8976138601dc`, obtenu par
  `refs/pull/377/head`. Ce n’est pas une revue d’une branche supposée à jour.
- Main comparé : `e13aab9a8fe24401561ccd02ca51085978bd9332` ; ancêtre commun
  `30887df7f53b7e56b188dde2f8e1b274f8185de4`.
- Lecture de RELAIS, AGENTS et des changements réels : 119 fichiers entre
  l’ancêtre commun et ce HEAD. Aucun développement applicatif repris.
- Revues antérieures : les commits `8f5c408b`, `152605ef`, `6173d9a4` corrigent
  respectivement la garde des attributs dynamiques et le retour RTL/LTR. Leurs
  tests ont été relus et exécutés. Aucune revue équivalente de ce HEAD trouvée
  dans les documents/historiques accessibles. **Impossible de vérifier les
  commentaires et approbations GitHub : API refusée 403**, après une tentative.
- `git merge-tree --write-tree origin/main origin/pr377` réussit sans conflit ;
  arbre calculé `4b18e15465c3946bbc2ee6d4e20bc33a11527a78`. Ce calcul ne constitue
  ni fusion, ni test fonctionnel de l’intégration, ni contrôle CI distant.

## Contrôles réussis et portée des preuves

| Contrôle | Résultat observé | Limite |
| --- | --- | --- |
| Contrôleur clients complet | **253/253 bancs**, aucun échec | SHA audité, fixtures et navigateur local ; pas des comptes réels |
| Bancs i18n ciblés | **50/50 fichiers de bancs** | Recoupent le contrôleur ; ne pas additionner ces deux totaux |
| Chromium neuf langues | **63 vérifications** accueil/rechargement/plateau, mobile/bureau | Site statique, sorties réseau bloquées, pas d’authentification |
| Stockage privé SQL existant | ACL, RLS, fermeture, cache, quotas, anti-rejeu conformes sur **PostgreSQL 16.2 jetable** | Pas PostgreSQL 17 ni catalogue Supabase vivant |
| Concurrence SQL existante | Deux processus, une réservation acceptée et une refusée, compteur 1:5 | Base locale détruite |
| Refus SQL supplémentaires | **14 accès réellement refusés**, rôles anon/authenticated : quatre tables et trois RPC pour chaque rôle | Ne démontre pas les politiques des forums/chat de production |
| Données de jeu | WORLD et COUNTRIES sérialisés identiques à l’ancêtre, hors `i18nKey` ; 142 353 caractères comparés | Données statiques ; ce n’est pas une certification de chaque ordre dynamique |
| Modifications SQL de jeu | Aucun diff dans migrations/, baseline/, supabase.js ou api/_deepseek.js | Le brouillon privé i18n reste hors migrations/ |
| Catalogues | Neuf langues, 1 006 clés FR de référence, aucune clé manquante ni divergence de placeholders recensée par l’outil | Un alignement de clés ne valide pas une traduction linguistique |
| Ordres | 392 clés canoniques conformes par langue ; variantes contextuelles et prix interpolés testés | Couverture partielle explicitée ci-dessous |
| Présentation bureau/mobile | Bancs mobiles, restauration et comparaison bureau inclus dans les 253 bancs, sans échec | Ni Safari réel, ni Android physique, ni parcours authentifié |

Les neuf locales sont `fr`, `en`, `es`, `zh-TW`, `ru`, `ko`, `ar`, `pt-BR`, `de`.
Chromium local : **154.0.8037.57**, Playwright installé localement ; la CI prévoit
son propre Chromium. Seul le chemin du binaire est adapté par préchargement hors
Git ; aucun fichier applicatif ou banc existant n’est modifié.

### Mécaniques et contenus

`data.js` ajoute des métadonnées d’affichage. La comparaison indépendante exécute
les deux sources puis compare WORLD/COUNTRIES en omettant uniquement `i18nKey` :
prix, PA, taux, permissions, noms, descriptions, identifiants et destinations
restent identiques dans ce périmètre. `renderRoomActions` transmet encore les
paramètres canoniques aux handlers ; sa reproduction conserve
`openPlainteModal(1,200)` et « 200 FR · 1 PA » avant/après changement de langue.

Les descriptions et noms dynamiques ne portent plus les anciennes clés statiques
sur les huit nœuds recensés, dont `piece-desc` et `pnj-modal-title`. Les salles
traduites passent par une liste blanche bâtiment/pièce et une comparaison du nom
source ; les variantes spécifiques conservent leur original. Tests des 38 salles,
15 rattachements, variantes d’hôtel, formulaires et commandes forum exécutés.
Les values, identifiants de publication et textes libres ne sont pas réécrits par
les traducteurs de libellés. Les messages inconnus restent originaux.

### Sécurité, RLS et quotas

Les modules de traduction n’exposent aucun handler HTTP. L’assemblage interne
identifie le lecteur par Supabase Auth, puis lit l’original avec **son JWT**,
colonnes autorisées uniquement, avant **tout hit de cache**. Les tables admises
sont forum_topics, forum_posts et messages_chat ; audiences et presse en attente
restent exclues. Service_role est réservé au cache/quota, pas à la lecture des
textes sociaux. Une absence et un refus ne révèlent ni original ni existence.
Ces chemins sont testés avec transports simulés ; aucun accès privé réel testé.

Le brouillon SQL ferme le budget par défaut, verrouille le compteur par UID/jour,
refuse la même réservation deux fois et réserve avant fournisseur. Les essais
SQL réels locaux réussissent, y compris les 14 refus supplémentaires. **Aucun de
ces objets n’a été appliqué ou activé dans Supabase durant cette revue.**

PNJ : les modifications du chat conservent authentification et contexte de position
serveur. Elles réutilisent une langue autorisée pour le prompt ET le filtre.
Les filtres de faux accords/départs de squatteurs et les répliques FR/EN passent
les tests dans les neuf langues. Il s’agit de protections lexicales et de
consignes : **pas d’une preuve que toute formulation inventée sera filtrée**.
Aucune parole d’IA ne devient une mutation métier dans le diff examiné. Aucun
appel DeepSeek réel effectué ; aucune réponse générée certifiée.

## Anomalies reproduites

Aucun P0 ou P1 démontré dans les vérifications accessibles. Les défauts ci-dessous
sont P2 : ils empêchent la validation complète de ce lot, mais les nouveaux chemins
restent fermés/non raccordés publiquement. Aucun dommage PJ réel observé ou testé.

### P2-01 — Une traduction peut modifier montants, devise et PA

**Fichier :** `api/_traduction.js:41,49-52` ; orchestration
`api/_traduction-contenu.js:58-61`.

Source : « Votre commande coûte 100 FR et 1 PA, {{name}}. »
Fournisseur simulé : « Your order costs 1000 USD and 9 AP, {{name}}. »
**Résultat actuel : ok=true**. Seuls longueur et placeholders sont vérifiés ;
l’instruction de conserver nombres/devise ne suffit pas. Le cache accepte ensuite
ce résultat. C’est un contre-exemple à la validation du moteur interne, **pas une
hallucination DeepSeek effectivement observée**, ni une modification de solde.

Reproduction : `reproduire-traduction.mjs`, résultat `traduction.json`.
Contre-épreuve : retirer {{name}} est correctement refusé par le même moteur.
**Correction recommandée à ChatGPT :** protéger et vérifier les tokens invariants
(nombres, devises et marqueurs métier) ou les substituer par des marqueurs opaques
avant traduction ; refuser le résultat contradictoire et conserver l’original.
Aucun arrondi, conversion ou nouvelle règle de coût ne doit être ajouté.

Le même script démontre qu’un NUL ajouté au résultat est accepté à cette première
réponse, alors qu’il est interdit à l’entrée et au hit de cache. Aligner la
validation des caractères de contrôle sur les trois chemins. Aucun XSS démontré :
le module de présentation utilise textContent.

### P2-02 — La bascule de langue laisse les ordres déjà rendus dans l’ancienne langue

**Fichiers :** `i18n/plateau-init.js:111-124`,
`plateau-politique.js:3987-3992` et `i18n/ordres.js`.

Conditions : activation i18n dans une fixture, rendu de « Porter plainte » en FR,
puis `i18next.changeLanguage('ar')` (la synchronisation storage emprunte le même
chemin). Le moteur et document.lang passent à ar, mais le bouton reste français.
Le listener n’appelle que apply(), qui cherche des attributs statiques ; ce bouton
est produit par le renderer et n’en porte pas. **Un nouveau rendu explicite
traduit correctement le même bouton en arabe**, sans changer commande ni coût.

Reproduction : `reproduire-menus.cjs`, résultat `menus.json`. Le script exécute la
vraie fonction renderRoomActions extraite par Acorn et les vrais modules i18next,
avec un DOM/état minimal fictif ; ce n’est pas une session authentifiée.
**Correction recommandée à ChatGPT :** raccorder les rendus de présentation ouverts
au changement de langue, en réutilisant les renderers existants. Ne pas rappeler
enterRoom/doOrder ni relancer les lectures/paiements pour traduire un bouton.
Conserver les saisies et positions de défilement des formulaires ouverts.
Étendre le test aux onglets de salles, guides, menus forum et courriers ouverts.

## Écarts et risques à ne pas masquer

- **P3 — Repli PNJ historiquement anglais.** `api/_pnj-profils.js:76,82-89` conserve
  LANGUE_DEFAUT=en et les codes non FR deviennent EN quand le drapeau est fermé.
  Le repli français est démontré pour l’interface i18next, **pas systématiquement
  pour toutes les routes PNJ**. Ce contrat est hérité et explicitement conservé,
  pas modifié par l’audit. La normalisation courte serveur accepte aussi zh-CN
  comme zh et pt-PT comme pt quand ouvert, alors que le pont navigateur refuse
  ces variantes et revient au FR. Clarifier/aligner le contrat avant ouverture ;
  ne pas réécrire silencieusement les dialogues historiques.
- **Couverture partielle connue, pas anomalie dissimulée :** 434 IDs statiques,
  387 couverts de façon stable, cinq ambigus partiellement couverts, 22 stables
  non couverts et 20 ambigus non couverts. Le français conserve un sens utile,
  mais « neuf langues présentes » ne signifie pas tout le jeu traduit. Les noms
  de PNJ et lieux propres doivent rester des identités, pas des clés à écraser.
- Le helper texte joueur capture la locale à attachToggle. Aucun consommateur
  applicatif actif trouvé hors tests : prévoir sa reconstruction/actualisation
  lors d’une bascule avant raccordement, avec une traduction périmée en autre
  langue remplacée par l’original. Ce risque n’est pas présenté comme une panne
  déjà vécue par un utilisateur.
- Le garde des huit nœuds dynamiques corrigé par `8f5c408b` est testé ; ce n’est
  pas une preuve exhaustive sur toute future fenêtre construite par un module.

## Fermeture publique et vérifications manquantes

Le plateau utilise FR sans `window.RP_I18N_GAME_ENABLED===true` ; les tentatives
programmatiques de bascule sont refusées dans les tests. Les langues PNJ nouvelles
nécessitent le drapeau serveur explicite. Le service de traduction de contenus
n’a pas de route et son budget SQL est fermé par défaut.

**Nuance importante :** l’accueil/création ne dépend pas de ce drapeau : il propose
six langues sur le main comparé et neuf dans la PR. Ne pas affirmer une fermeture
universelle de toutes les pages ; les nouveaux boutons d’accueil seraient visibles
si la PR était fusionnée telle quelle. L’audit n’a activé aucune langue ni fusionné
la PR. Variables Vercel et configuration Supabase réelles non accessibles.
La lecture du HTML public a échoué avant HTTP : tunnel CONNECT 403. **Fermeture
publique actuelle non certifiée en production depuis cet environnement.**

Restent nécessaires :

1. Corriger P2-01/P2-02 et ajouter les tests de non-régression sur le SHA corrigé.
2. Tests authentifiés isolés de RLS : lecteur autorisé/interdit, changement de
   ville/adhésion, révocation entre deux accès au cache, forum privé et chat.
3. Tester PostgreSQL 17 et observer les workflows du SHA final ; le refus API
   empêche de déclarer la CI distante verte ici.
4. Recette des formulaires ouverts et de leurs valeurs pendant bascule FR/AR,
   mail/forum/notifications, plusieurs onglets et reconnexion ; aucune écriture
   métier ne doit être provoquée par la traduction.
5. Validation linguistique humaine des huit traductions, des variantes régionales,
   du RTL et de la lisibilité sur iPhone Safari et Android physiques.
6. Prévol réel avant toute installation du brouillon privé, puis vérification
   d’une intégration fraîche avec main. Le merge-tree seul ne la certifie pas.

## Livraison de l’audit

Branche `codex/audit-i18n-377-20261108`, basée sur le HEAD audité. Seuls rapport,
preuves, scripts d’audit et RELAIS changent ; aucun code applicatif/mobile/Claude,
aucune donnée, migration de production ou fonctionnalité n’est modifié.

Les reproductions réussies signifient **« défaut reproduit »**, pas « conformité ».
Les 253 bancs clients verts ne les remplacent pas. Les corrections restent à
ChatGPT. Aucun service payant, aucune fusion, aucun déploiement.
