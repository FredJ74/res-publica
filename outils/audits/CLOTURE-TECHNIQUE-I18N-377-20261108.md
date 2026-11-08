# Clôture technique indépendante — internationalisation #377

8 novembre 2026, Europe/Paris. **Verdict sur la PR : CORRECTIONS NÉCESSAIRES.**
Ce rapport remplace, pour le HEAD actuel, la revue du seul SHA 6173d9a4.
Il ne donne aucune autorisation de publication.

## 1. Versions et responsabilité

- HEAD final récupéré : **ddc72445fe570209ad8dac777b4feeb65a7719f9**.
- Main final observé : **3151c5b6ebc65d1bcce2d1aff3beac24f57e12a0**.
- Première passe de cette mission : PR 81b219e4, main ee986fe1. Les deux sont
  conservés dans les preuves historiques intermédiaires, pas confondus avec HEAD.
- **Intégration concurrente observée pendant la mission** : main et la PR ont
  désormais le même arbre `f59e96876c6b66e27866e4eef78e04abeb78620d`.
  Le commit main 3151c5b6 active le drapeau client dans plateau.html. Cette
  intégration n’a pas été faite par Codex ; aucun déploiement Vercel n’est attesté.
- Les 18 correctifs entre 6173d9a4 et 81b219e4 ont été examinés, puis les
  changements jusqu’à ddc72445 (intégration de main, activation client, banc et CI). Les défauts initiaux de
  montants/NUL/cache et la simple bascule des ordres ouverts sont corrigés.
  Les nouveaux tests de signes Unicode et de sous-menus ont été exécutés.
- Les sept workflows verts et la dernière revue sont annoncés dans la passation.
  Leur état distant n’est **pas recertifié ici** : API GitHub inaccessible lors
  de la revue précédente. Aucun essai en boucle ni statut inventé.
- Branche de preuves : `codex/audit-i18n-377-20261108` ; ni la branche de ChatGPT,
  ni main, ni le mobile, ni les fichiers de Claude n’ont été modifiés par cet audit. Les mises à jour
  amont sont conservées dans la branche de preuves.

## 2. Résultats exécutés

| Exécution | Résultat | Portée |
| --- | --- | --- |
| Contrôleur initial 81b219e4 | **253/253** | Tous les bancs existants, sans production |
| Contrôleur HEAD final ddc72445 | **254/254** | Inclut le nouveau banc d’activation ; aucune activation exécutée par l’audit |
| Chromium neuf langues existant | **63 vérifications** | HTML/rendus réels, mobile/bureau, rechargement/préférences, hors authentification |
| Nouveau parcours de session | **11 bascules** positives, FR/AR/FR compris | Chromium 360 px ; mêmes nœuds, saisies, sélection, coût et handler ; zéro appel métier, zéro requête réseau |
| Stockage SQL | Conforme sur **PostgreSQL 17.6** | Brouillon installé dans un cluster jetable détruit, pas Supabase |
| Quota concurrent | Une réservation acceptée, l’autre refusée, compteur 1:5 | Deux processus SQL distincts |
| ACL privées | **14 refus réels** | Quatre tables/trois RPC × anon/authenticated, SQLSTATE 42501 |
| Chaîne traduction → lecture RLS → cache/quota SQL | **13/13** | Vrais modules JS et PostgreSQL ; identités et fournisseur de fixture |
| Forums territoriaux, banc existant | **25/25**, moteur 170006 | Définitions préparées #422, tables du baseline, rôles réels, transaction annulée |
| Contre-épreuves des forums | Détectées | RLS rendue permissive : 11 cas échouent ; ancien écrivain : un cas échoue |
| Intégration calculée avec main | **253/253** | Arbre 0c3e7f5773a0ca50737b54f16d4cbd5810c4cef0, copie détachée locale |
| Correctif de référence | **253/253** sur intégration corrigée ; cas Chromium corrigés | Arbre ce9eb136192b4ba31df9602259f1150eca527bc7, aucun fichier applicatif de la PR modifié |

Les essais SQL ne sont pas une reconstruction de production. Auth.uid est une
fixture, pas un JWT Supabase Auth réellement vérifié. La chaîne utilise les vrais
lecteur/orchestrateur/stockage et des requêtes SQL réellement soumises à RLS,
mais son adaptateur SQL remplace PostgREST. **Ne pas appeler cela une recette
HTTP authentifiée ou une connexion réelle de joueur.**

Le banc de chaîne vérifie : deux membres lisant un même cache ; non-membre refusé
avant cache ; révocation d’adhésion ; chef autorisé ; édition invalidant le cache ;
pays national étranger refusé ; changement de ville fermant le local ; révocation
de salon ; chat direct réservé aux participants ; cache falsifié non servi ;
timeout fournisseur sans deuxième appel payant ; identité inconnue refusée.
Aucun fournisseur réel ni service payant appelé.

Les contrôleurs complets comprennent les contrôles mobiles et leurs comparaisons de bureau.
Aucun essai physique iPhone/Android ni parcours économique en production effectué.
Le test de session n’est pas une certification de toute l’ergonomie mobile.

## 3. Intégrité et sécurité

- WORLD/COUNTRIES de l’intégration et de main sont identiques après exclusion de
  la seule clé de présentation i18nKey : **144 071 caractères comparés**. Les
  nouveaux contenus, prix PSK, restrictions et noms de Claude sont préservés.
- Les corrections de langue ne remplacent aucun handler, coût ou permission.
  Le test conserve notamment `openPlainteModal(1,200)` et « 200 FR · 1 PA ».
- Nombres, devises, PA, signes, pourcentages, placeholders et contrôles NUL sont
  vérifiés à la sortie fournisseur **et** au cache. Le banc fournisseur contient
  neuf tests, l’orchestrateur seize ; tous passent sur HEAD.
- Le lecteur revalide catégorie/ID/colonne, lit sous l’identité du lecteur avant
  le cache et ne lit ni comptes, ni auteur secret, ni données de fiche.
- Les tables privées de traduction et leurs RPC sont fermées aux clients. Le
  rôle serveur ne sert qu’au stockage/quota ; jamais à la lecture des originaux.
- Les profils PNJ conservent contexte, identité et connaissances ; les filtres
  d’accords inventés et le drapeau serveur sont testés. Aucun dialogue généré réel
  n’a été demandé. Les filtres lexicaux ne prouvent pas l’absence de toute
  hallucination sémantique : la parole reste sans pouvoir transactionnel.
- La protection numérique n’est pas un validateur universel du sens, des noms
  cités dans une prose ou de la qualité d’une traduction. Les identités métier
  et les résultats restent les données serveur ; recette linguistique distincte.

## 4. Anomalies encore ouvertes sur HEAD

Aucun P0/P1 reproduit dans ce périmètre ; ce n’est pas une certification de production.

### P2-C1 — Un ancien menu peut être renommé avec le catalogue d’une autre pièce

Fichiers : `i18n/ordres.js:148-162`, `plateau-politique.js:3994,4459`.

Reproduction Chromium avec la vraie fonction renderRoomActions : rendre un ordre
« Porter plainte », conserver son bouton dans une fenêtre, rendre un autre
catalogue, puis passer en allemand. L’ancien bouton affiche
**« Ein Hotelzimmer buchen »** au lieu de **« Anzeige erstatten »**, mais conserve
**openPlainteModal(1,200)**. Le tableau global renderedOrders a été remplacé ;
l’index 0 de la fenêtre ne désigne plus son ordre original.

La condition est une fenêtre conservée pendant un nouveau rendu/reprise ou
changement de contexte. Ce chemin est reproduit sur fixtures, pas sur un PJ
connecté. Aucune transaction n’a été déclenchée pour le démontrer.

Correction concrète préparée : descripteur de présentation par nœud (fn, label,
i18nKey), lu par le traducteur, sans modifier le handler ni stocker un nouveau
montant. Le catalogue d’une autre pièce ne peut plus renommer ce nœud.
Contre-épreuve : neutraliser la lecture du descripteur fait échouer le test.

### P2-C2 — Pièce, navigation forum et courrier déjà ouverts restent dans l’ancienne langue

Fichiers : `i18n/plateau-init.js:111-122`, `plateau-navigation.js:660,1069`,
`forum.js:854,3015`. L’événement ne traduit que les clés statiques et les ordres.

Reproductions :

- Nom de pièce « Accueil » conservé après passage AR, alors que le catalogue
  retourne « استقبال البنك » pour cette salle bancaire.
- Forum national déjà rendu conservé en FR après passage DE, au lieu de
  « Nationales Forum ».
- Compositeur déjà ouvert conservant « Nouveau message » au lieu de
  « Neue Nachricht ». Les saisies restent intactes : aucun texte utilisateur perdu.

Correction de référence : rattacher les titres/onglets de pièce au helper de
salles existant ; annoter les libellés canoniques du forum et les libellés/
placeholders statiques du compositeur avec les clés existantes. Ne jamais
rappeler enterRoom, doOrder ou un chargement distant pour traduire un texte.
Les noms privés, badges non lus, icônes, destinataires et corps des messages
restent hors de ces remplacements. Contre-épreuve : supprimer le rafraîchissement
des noms de salle fait échouer le test.

### Limites du correctif livré comme artefact

`preuves-i18n-377-cloture-20261108/correctif-reference.patch` s’applique au HEAD
avec git apply --check. Il corrige les reproductions en mémoire et dans une copie
locale d’intégration ; **il n’est pas appliqué à la PR #377**.
Il couvre les cas précisés, pas chaque fragment dynamique de toutes les fenêtres.
ChatGPT doit intégrer la correction, compléter le même raccordement pour les
écrans encore non annotés et majorer les versions de cache des scripts concernés.
Le patch ne contient aucun changement de traduction, de règle ou de CSS mobile.

Première version du patch : 250/253 bancs (absence de window dans deux rendus
isolés, attribut supplémentaire dans une fixture historique). Ces compatibilités
ont été corrigées **dans le patch**, sans désactiver ni modifier les assertions.
Version finale : **253/253**, sans modification des bancs existants. Seule
  l’activation inline et son nouveau banc/CI différencient la nouvelle source
  finale de l’intégration initialement éprouvée ; les six fichiers du correctif
  et les modules serveur ont été comparés avant réemploi de ces preuves.

## 5. Couverture et ajouts récents

- Neuf locales : fr, en, es, zh-TW, ru, ko, ar, pt-BR, de.
- 1 006 clés françaises de référence ; aucune clé manquante ni divergence de
  placeholders recensée par l’outil éditorial dans ces neuf ressources.
- **392 ordres canoniques** par langue ; 47 variantes contextuelles et **38 noms
  de pièces / 15 rattachements** contrôlés par les bancs existants.
- Sur HEAD : 434 IDs, 387 stables couverts, cinq ambigus partiellement couverts,
  22 stables et 20 ambigus non couverts.
- Avec main : **436 IDs**, couverture inchangée, **24 stables non couverts** et
  20 ambigus non couverts. Ajouts absents du catalogue : sovarka_musee_billet
  (« Billet du musée présidentiel »), sovarka_surveiller (« Placer sous surveillance »).
  Ils restent en français, sans fausse traduction ni changement des coûts.
- Les nouvelles pièces du palais présidentiel de Sovarka ne font pas partie de
  la liste blanche des 38 noms. Elles gardent leurs noms/descriptions sources.
  Les ajouter relève du développement de traduction de ChatGPT, pas de cet audit.
- Les corps libres de courrier/forum/chat et de nombreuses fenêtres dynamiques
  ne sont pas intégralement localisés. Ne pas assimiler catalogue complet et jeu
  intégralement traduit. Le service de texte joueur reste interne non exposé.

Repli : FR pour les clés d’interface manquantes ; original pour les textes libres
ou traductions refusées. Le repli historique du chat PNJ reste EN pour une locale
inconnue, et le serveur normalise sur deux lettres (zh-CN/pt-PT notamment). Cette
limite déjà signalée ne doit pas être présentée comme un repli français universel.

## 6. Conditions exactes avant recette/activation

1. ChatGPT intègre/raccorde les correctifs résiduels, avec majoration des versions
   de cache et tests sur le nouveau HEAD ; vérifier les formulaires/sous-menus
   ouverts, les noms dynamiques et la conservation des saisies.
2. Rejouer l’intégration avec le main alors courant et observer ses workflows.
   Le calcul d’un arbre et nos tests locaux ne certifient pas GitHub Actions.
3. Fournir des comptes de recette isolés pour Supabase Auth/PostgREST réels :
   accès public/national/privé, révocation, changement de ville et reconnexion.
   Ni Arnie ni autre personnage réel n’a été utilisé ou modifié.
4. Validation linguistique humaine des huit traductions, variantes contextuelles,
   RTL et noms propres ; iPhone Safari et Android physiques pour l’ergonomie.
5. Prévol réel des politiques et dépendances avant toute installation du brouillon
   privé. Le SQL de cette revue ne sort pas de ses clusters jetables.
6. Définir/valider les limites de service et la procédure de désactivation avant
   tout raccordement payant. Aucun appel fournisseur réel réalisé ici.
7. **Décision explicite de Fred pour toute ouverture publique.** La version finale observée porte déjà `window.RP_I18N_GAME_ENABLED = true`
   dans main et la PR. Il serait faux de la déclarer fermée côté client. Le
   service de traduction sociale reste sans endpoint ; le budget de son SQL
   brouillon est fermé par défaut. Les langues PNJ nouvelles demandent encore
   le drapeau serveur (variable Vercel non vérifiée). L’accueil/création expose
   neuf langues dans ce code. État réellement servi et autorisations de livraison
   externes non vérifiés ; aucune activation effectuée par Codex.

Les fichiers applicatifs des deux références finales sont identiques : il n’y a
plus de conflit d’intégration à résoudre pour ces coupes. Cela ne prouve ni READY
ni la résolution des défauts P2 ; le patch de cet audit n’y figure pas.

Le lot n’est pas déclaré publiable. Il n’est pas « bloqué » par l’environnement :
les vérifications accessibles sont exécutées, les défauts résiduels sont reproduits
et un correctif exploitable est fourni. Les deux reproductions historiques ne
sont pas réouvertes : ce sont des cas de contexte supplémentaires.
