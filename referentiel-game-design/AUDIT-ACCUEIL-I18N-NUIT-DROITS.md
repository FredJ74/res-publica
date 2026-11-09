# Audit complémentaire — accueil, i18n, horloge, nuit et droits

**Capture :** 9 novembre 2026 ; sources JS de `main` au SHA `a8bd5e266f18f3432ec3feb11d53dbb799043531`, lectures **non mutantes** du catalogue et du journal `public.cron_journal` Supabase. Aucune connexion PJ, aucun achat ni appel de fonction métier.

## A. Parcours d'arrivée — mécanismes vus dans le code, pas recette humaine

### A-01 — Création et récupération de compte
`creation.js` (1 264 lignes) construit le personnage à travers les choix de pays/ville, origine, école, archétype, carrière, caractéristiques, identité et compte ; le nouvel état inclut `queteAccueil: {etape:'non_commencee'}` (vers ligne 1071). `connecterAvecMotDePasse` récupère la fiche **à partir du compte authentifié** via `mon_personnage` ; le client ne sélectionne pas librement la fiche par son nom. Ces chemins sont codés, mais la réussite depuis navigateur vierge n'a pas été éprouvée.

### A-02 — Tutoriel : monde réel, multiples sorties
`plateau-quete-accueil.js` (1 147 lignes) expose une chaîne substantielle : garde présidentiel → carrefour → Hôtel de ville → Secrétaire Petit et Jérémy → salle des élections → dispensaire et fiche → hôtel, bar et chambre → stade, puis orientation personnelle. La progression dépend de **vraies entrées de bâtiment, changements de pièces, mouvements et ordres** ; le simple affichage du dialogue n'atteste pas l'étape accomplie.

L'orientation par Jérémy propose **criminel, politique, entrepreneurial, indécis**. Référents prévus : Pat Hounette (criminel), Jean-Lou Zeure (politique), Laurent Barre (entrepreneurial). La route `indecis` reste légitime ; la fin de tutoriel ne force pas de carrière. La séquence propose ensuite une présentation volontaire sur le **forum local**, sans rédiger ni publier à la place du joueur, sans bonus artificiel, et « Plus tard » est terminal. L'état `queteAccueil` est sauvegardé ; certains embranchements réparent le rappel après fermeture de fenêtre ou recharge.

**Limites UX importantes :** ce parcours est explicitement ancré à **Luthécia** (`luthecia-imprimerie`, `luthecia-hotel-de-ville`, `mairie-capitale`, etc.). La présence d'autres villes/empire et des langues ne prouve pas un onboarding équivalent à Novomirsk ou à Starovka. Des mentions `suite a coder` en tête de fichier sont historiques et contredites par les fonctions effectivement développées plus bas : lire les fonctions, non une entête périmée. Le scénario de première session ne devient pas un système de rétention D1/D7 par lui-même.

### A-03 — Blocages et contexte d'ordre
`plateau-router.js` expose `doOrder(fn,pa,cost,...)` : garde « patient de chambre clinique », garde de rôle/propriété, immobilisation de match, refus lors de blocus, et spécialisation par ordre avant facturation. L'affichage client n'est pas une barrière de sécurité : vérifier chaque RPC réelle et ses permissions sur la base. Un ordre présent dans `data.js` ne devient pas automatiquement utilisable.

## B. I18n — distinction décisive

`i18n/resources.js` publie **9 codes de langues**, relevés directement : `fr`, `en`, `es`, `zh-TW`, `ru`, `ko`, `ar`, `pt-BR`, `de`. `i18n/i18n-init.js` choisit d'abord la préférence conservée, ensuite la langue navigateur, puis le français ; les ressources sont locales, sans CDN. La PR #377 a été fusionnée sur le SHA de référence avec un périmètre annoncé de **sélecteur d'accueil**, non **activation générale du jeu multilingue**. **Ne pas déduire « neuf langues jouables » du sélecteur.**

À vérifier avant campagne rétention non-francophone : pages de création, détails de bâtiments, fenêtres d'ordres, demandes d'erreur serveur, courriels générés, PNJ, textes dynamiques, retours de paiement. Un libellé de commande traduit n'est pas une transaction traduite de bout en bout.

## C. Horloge et traitements nocturnes : preuves de production

### C-01 — Horaire de déclenchement et doctrine
`vercel.json` inscrit `/api/cron-minuit` à **23:00 UTC quotidiennement**. C'est **00:00 à Paris en hiver** mais **01:00 à Paris en été**. Le code `api/cron-minuit.js` calcule les clés et jours avec `jourParisISO()` ; il implémente journalisation durable `cron_journal_ecrire`, garde d'idempotence `tacheQuotidienne`, détecteur d'erreurs et réponse HTTP 500 en cas de passe incomplète. Une heure programmée ne signifie pas exécution à la minute : l'heure de début observée dans le journal est différente.

**Point de design à arbitrer ultérieurement** : la promesse narrative « minuit » et la tolérance de déclenchement décalé. Ne pas modifier le cron au titre d'un audit. Ne pas affirmer que tous les effets attendent un même événement : certains événements temporels sont exécutés par d'autres routes/RPC.

`/api/cron-assemblee` est programmé à **22:00 UTC chaque jour**. Le commentaire et les RPC organisent volontairement un traitement après l'échéance locale pour éviter une clôture prématurée ; cette architecture est distincte de `cron-minuit`.

### C-02 — **Fait inédit directement vérifié : six nuits incomplètes**

Requête non mutante sur `public.cron_journal`, uniquement **métadonnées d'exécution** (`jour`, `tache`, `statut`, `tentatives`, début/fin de passe, et libellé de l'étape en échec). Aucun joueur ni solde consulté.

| Jours | `_passe` | Tentatives rapportées | Étape en échec |
| --- | --- | --- | --- |
| 1, 2, 3, 4, 5, 6 novembre 2026 | `echec` **chaque jour** | 1 par jour | `sbRpc:traiter_prets_helvetia_quotidien` |
| 7, 8, 9 novembre 2026 | `ok` **chaque jour** | 1 par jour | aucune étape d'échec dans le champ de la passe |

Cela prouve **une anomalie bancaire déclarée par la passe et une restauration de l'état global « ok » à partir du 7**, **pas** un débit erroné, une perte financière précise, la réussite de chaque tâche, ni une reprise rétroactive des jours 1–6. Le registre n'a livré aucune ligne séparée sous un nom de tâche contenant « helvetia » pour ces dates ; le nom provient du champ `_passe.erreur` qui ne listait que les étapes en échec.

**Horaires directement lus (Europe/Paris) :** 7–9 novembre, démarrage vers **00:40:27–00:40:29**, fin vers **00:41:36–00:41:46** ; sur les 1–6 novembre, heures similaires. La planification à 00:00 ne garantit donc pas, ici, que l'effet soit perceptible par le joueur exactement à 00:00. Le journal du 28 octobre n'est pas présent dans la fenêtre consultée ; ne pas inférer la continuité historique totale.

### C-03 — Étapes nocturnes structurantes visibles dans le code
Le handler inclut notamment fiscalité foncière, loyers, budgets et subventions, retenues sur prêts, justice et détention, blocus, grèves, acheminement, production, exportations, construction navale, garages, salaires douaniers/policiers, Sovarka (gloire, pouvoir, urbanisme), renseignements et journal. Cela **matérialise un monde persistant même navigateur fermé**. Mais le simple fait que l'appel figure dans le handler ne démontre pas sa réussite réelle pour chaque objet métier ni les dates non documentées.

## D. Surface de permissions SQL — indicateurs, pas vulnérabilités prouvées

Lecture de `pg_proc`, `pg_namespace` et `has_function_privilege()` en base de production :
- **1 605 fonctions dans `public`** ;
- **1 401 `SECURITY DEFINER`** ;
- **26 `SECURITY DEFINER` exécutables par le rôle `anon`** ;
- **750 `SECURITY DEFINER` exécutables par `authenticated`** ;
- **36 `SECURITY INVOKER` exécutables par `anon`**.

Des fonctions d'accès `anon` comprennent des lectures intentionnelles et des fonctions portant des noms d'action (`assemblee_achat_illegal`, `calomnie_distribuer`, `tracts_electoraux_distribuer`). **Il ne s'agit pas d'une preuve d'exploitabilité**, car les corps des fonctions peuvent imposer l'identité et l'autorisation correctement ; il faut auditer leur `auth.uid()`, `search_path`, vérification serveur et droits dans leur corps avant de conclure. Ces chiffres sont un **périmètre de vérification de sécurité**, pas une instruction de changement de politique.

## E. Incidences sur le futur diagnostic de rétention

1. Un tutoriel **riche et orienté monde social** existe déjà : le besoin ne peut pas être présumé « ajouter un tutoriel » ; la question est sa compréhension et sa sortie autonome.
2. Les embranchements de carrières sont des **opportunités de projets personnels**, mais la suite réelle et la visibilité des personnages référents doivent être observées.
3. La première présentation au forum est **facultative et réellement rédigée par le joueur** ; vérifier qu'elle obtient une réponse humaine sans transformer cette initiative en automatisation sociale.
4. Les systèmes temporels et bancaires influent sur la **confiance au retour D1**. Les nuits en échec sont factuelles, mais aucune conséquence joueur n'est établie.
5. Le calendrier nocturne réel peut être décalé par rapport à la promesse de minuit et dépend du fuseau. Formuler clairement l'heure « attendue » et « effectivement constatée » dans toute recette.
6. Une locale sélectionnable sur accueil n'assure pas une expérience longue dans cette langue : mesurer l'ensemble du parcours avant d'ouvrir largement.

**Frontière de preuve :** audits SRC et SQL lecture seule. **Aucun J (jouabilité humaine) attribué.**