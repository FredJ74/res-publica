# PR #219 — livraison contrôlée, reprise du 30 octobre 2026

> Rapport courant du 31/10 : [reconstruction réelle, 88 migrations et recette](RECONSTRUCTION-CANONIQUE-GROUPES-219-20261031.md). Les résultats ci-dessous restent historiques.

> État courant : [reconstruction canonique, moteur PostgreSQL 17.6 et bilan des contrôles](RECONSTRUCTION-CANONIQUE-GROUPES-219-20261030.md). Les observations ci-dessous restent celles de la passe précédente.

**Code sauvegardé et validé localement. Fusion et production encore bloquées par le prévol réel complet et la recette authentifiée isolée.** Ce rapport remplace le verdict courant du rapport `CLOTURE-LOCALE-GROUPES-219-20261030.md`, dont les observations antérieures sont conservées. Ni migration ni action sur un joueur réel pendant cette reprise.

## Périmètre et intégrations

Branche `codex/groupes-universels-20261028`, PR #219. Code testé : `981d02c7`.

- `ea9794c7` intègre main `888eb386` (#258/#260).
- `83de8665` conserve la fusion trois voies des fiches et les achats idempotents ; les PA, positions et états réellement confirmés après déplacement/combat alimentent `sbFicheBaseAdopter`. Les valeurs zéro et null sont conservées, aucun champ absent n'est inventé. La déduplication des RPC est cloisonnée par identité et session, tout en conservant la déduplication dans une session.
- `697a6ca8` intègre le main concurrent `44357f24` (#261/#264) : capacité universelle d'entrepôt et consultation du coût de construction avant achat conservées. Aucun développement immobilier supplémentaire.
- `981d02c7` réconcilie les versions préparées avec ce nouveau main. La migration d'entrepôt utilise déjà 20261030200000 : les 29 préparations propres à #219 passent de 20h à 21h, de 20261030210000 à 20261030212800. Aucun numéro appliqué n'est changé. Correspondances dans `VERSIONS-GROUPES-219-20261030.json`.

Les circuits déjà développés restent communs : groupes volontaires PJ/PNJ, autorités d'origine des unités, navigation collective, transports avec paiement du leader pour tous les voyageurs, police/douanes/sécurité privée, vrais rounds militaires et civils, repli géométrique et provenance de Port-Sainte-Marie, effets judiciaires, rapports et reprise par le calendrier existant. Aucun second moteur ni nouveau tarif.

## PNJ et derniers défauts corrigés

Les commentaires 6530637637, 6527957846, 6528065525, 6530467223 et 6530563556 ont été relus ; leurs informations sont archivées dans `outils/bancs/fixtures/groupes-prevol-communique-20261030-soir.json` avec leur provenance.

- Les trois `Garde republicain` gardent leur identité et leur nom. Le client sélectionne uniquement l'identifiant effectivement renvoyé comme présent par le serveur : `garde-republic-assemblee-permanent`, `garde-republic-palais-gouvernement-permanent`, `garde-republic-palais-presidentiel-permanent`. Aucun emplacement n'est déduit de leur identifiant.
- Le bouton d'attaque attend désormais la lecture minimale `combat_cibles_lire`, réutilisant `pnj_co_present`. Aucun argent, inventaire ou profil chiffré d'autrui n'est exposé. Une erreur de lecture n'est pas présentée comme une absence confirmée.
- Un homonyme ambigu n'est jamais choisi arbitrairement. Une réponse tardive après changement de session, personnage, lieu ou fenêtre ne crée pas un bouton étranger. Aucun sondage périodique ajouté.
- Gamma, PNJ absent, sans PA ou profil combattant incomplet : aucun bouton utilisable. Le serveur refuse aussi les profils incomplets avant paiement. Aucun profil numérique inventé pour les 108 PNJ du catalogue.
- Lire une occupation ne crée aucun squatteur. Sa matérialisation reste dans l'ouverture transactionnelle existante et son issue dépend du vrai combat.
- Deux anciens fichiers SQL dépassaient la limite technique : les parties `20261029121001` et `20261029131001` les scindent sans changer leurs instructions métier. Les bancs installent et réinstallent les deux parties.
- Workflow : tous les ordres de décor des bancs d'achat #260/#261 sont maintenant sous BEGIN/ROLLBACK ; la lecture des empreintes est read-only. La photographie de fonctions communiquées a sa place documentaire dans `historique/photographies/20261030-fonctions-achat-communiquees.sql`, réutilisée par le montage jetable. Aucun test supprimé, aucune exception ajoutée au contrôleur.

## Preuves locales

Dossier `outils/audits/preuves-groupes-219-main443-20261030/` : journaux bruts compressés, résultats structurés et empreintes des sources.

- **379/379 assertions PostgreSQL** avec `--catalogue-20261029`. RPC exercées au rôle authenticated, identité JWT de fixture et request.path. Reçus, concurrence à deux connexions, refus avant paiement, panne aval, combats civils/mixtes, issues des squatteurs, repli, groupes, camions, protections #258. Les commits nécessaires aux scénarios concurrents concernent exclusivement PostgreSQL jetable ; ne pas présenter tous ces essais comme des transactions annulées.
- **141/141 bancs clients** après les corrections Workflow. Une première passe après le main concurrent avait 140/141 (Workflow), conservée comme observation intermédiaire ; le défaut est corrigé et la suite entière a été rejouée.
- **105/105 tests du pilote Chromium**, aucun ignoré : fixtures locales, aucun personnage authentifié en production.
- **6/6 contre-épreuves détectées**, chacune exécute les 379 cas et échoue réellement : issue faussée, double paiement, PNJ immobile, faux repli, camion solo, provenance oubliée. Les erreurs secondaires restent visibles ; leur code non nul n'est pas présenté comme une réussite de la mutation.
- Grammaire PostgreSQL : 88 sources SQL, prévol et bundle complet parsés. Manifeste : SHA-256 vérifiés, zéro collision avec les fichiers du main 44357f24. Ce n'est pas encore une preuve d'installation des 88 fichiers sur une copie fidèle du catalogue vivant.

## Contrôles globaux : 5/12, pas un feu vert

Main 44357f24 : 4/12. Branche : 5/12, Workflow réparé. Les sept autres contrôles restent rouges : classification, fidélité du baseline, Authority, Referential, fonctions, assemblage et reconstruction. Les résultats exacts sont archivés, sans modification du baseline généré ou des observations.

- Authority : 123 appels absents du baseline contre 112 sur main ; 10 signatures de migrations inconnues contre 5. Les ajouts de #219 sont préparés, pas installés ni extraits dans le baseline. Ce surcroît demeure une dépendance de livraison à homologuer. `resilier_bail_volontaire` sans garde d'acteur est également signalé sur main ; aucun correctif de bail hors périmètre n'est importé.
- Referential : des générateurs imposent encore des chemins JavaScriptCore macOS absents sous Linux ; d'autres déclarations d'empreinte ne correspondent plus à un miroir. Aucune concordance actuelle affirmée.
- Fonctions : copie non déclarée `tauxHoraireChantierServeur` et texte canonique d'expulsion d'ambassadeur introuvable. Les sources correspondantes préexistent sur main ; la mesure native de main s'arrête sans moteur. Ne pas transformer cette limite en réussite ou attribuer ces deux défauts à #219.
- Classification : deux anomalies ; baseline : 21 anomalies. Assemblage : deux fonctions de triggers immobiliers absentes du baseline. Reconstruction : zéro refus de grammaire, deux dépendances manquantes et six attentes du monde non tenues. Ces défauts empêchent de certifier une reconstruction globale propre ; les corriger nécessite l'extraction canonique, pas une édition manuelle des SQL générés.

## Prévol réel obligatoire, sans données de joueurs

Exécuter via l'accès Supabase autorisé `outils/bancs/PREFLIGHT-GROUPES-219-LIVRAISON.sql`. C'est une transaction **read-only**, un seul résultat JSON pour éviter la perte des premiers jeux de résultats du connecteur. Conserver l'export complet comme artefact technique, sans le tronquer dans un commentaire.

Il fournit registre intégral, signatures/types, définitions/ACL/propriétaires/search_path, colonnes, contraintes, index, RLS/policies et triggers complets ; diagnostic PNJ sans fiche ni compte PJ. Comparer cet export aux sources et fixtures communiquées, notamment les fonctions judiciaires/asile, protections de fiche #258, reçus d'achat #260 et capacité #261. Toute définition vivante différente doit être examinée, jamais remplacée à l'aveugle.

Faits communiqués : 996 versions, 108 PNJ dont 107 actifs, 11 profils, 17 triggers PJ et 3 PNJ ; tables d'adhésion/navigation absentes ; aucun lot #219 appliqué. Cela ne donne **ni les 996 versions ni tous les corps/ACL/RLS**. Les versions appliquées #260 sont 20261030182403 et 20261030182449, distinctes des horodatages des fichiers sources. Ne pas réappliquer #257/#258/#260/#261 parce qu'ils sont présents dans le dépôt. Leur état exact doit provenir du registre vivant, jamais d'une égalité supposée entre nom de fichier et version appliquée.

Contrôler les PNJ incomplets remontés, la co-présence de chacun des trois gardes et les scènes des trois villes ; aucune création massive, renommage ou attribution de statistiques pour rendre un test vert. L'affichage des cibles est désormais protégé, mais la complétude des 108 raccordements n'est pas certifiée sans cette recette réelle.

## Plan d'installation pour l'intégrateur technique

1. Épingler le SHA livré et conserver sauvegardes, définitions et métadonnées avant changement. Obtenir le prévol complet, résoudre toute collision de registre/dépendance, vérifier les protections de données PJ et d'inventaire. Pas d'accès de joueur pendant l'installation sensible.
2. Le manifeste `LIVRAISON-GROUPES-219-20261030.json` donne les **88 fichiers propres à #219**, dépendances #212/#217 incluses, dans leur ordre. Les migrations propres au main sont exclues. Garder toutes les parties techniques consécutives ; aucune installation par morceaux de client/navigation/combat.
3. Générer hors ligne avec `outils/livraison/preparer-groupes-219.py --sortie <fichier-temporaire.sql>`. Le générateur vérifie versions, SHA et limites, sans connexion. Le bundle est une transaction : collision avant DDL, signatures prérequises, verrou court des fiches PJ, contrôle d'intégrité des anciennes colonnes PJ, installation complète, estampillage des 88 versions et notification du schéma seulement en fin. Un changement de PA ou d'autre ancienne donnée PJ annule le lot ; un ajout de colonne est admis.
4. Rejouer ce bundle **en entier sur une copie jetable fidèle du schéma vivant**, avec fixtures exclusivement fictives, puis les 379 assertions/contre-épreuves et la recette ci-dessous. Les tests actuels installent les sources métier et leurs dépendances de fixture ; ils ne certifient pas cette copie complète encore indisponible.
5. L'artefact généré fait environ 882 ko : utiliser une connexion administrative PostgreSQL persistante autorisée capable d'exécuter ce fichier en une transaction et d'arrêter à la première erreur. **Ne jamais répartir BEGIN/COMMIT entre des appels MCP indépendants ni appliquer 88 petits appels `apply_migration`** : leur atomicité globale n'est pas démontrée. Si l'intégrateur ne dispose que du connecteur SQL borné, ce canal d'installation demeure un blocage technique ; aucune activation partielle.
6. Après validation technique seulement : fenêtre de livraison coordonnée SQL/client, vérification du déploiement Vercel réel et des versions de cache JS, anciennes sessions invitées à recharger. Ne pas fusionner le client avant que son contrat serveur soit disponible. Observer achats, déplacements, PA, erreurs RPC et échéances sans lancer d'opérations sur des joueurs réels.
7. Refaire l'export, vérifier 88 versions nouvelles, ACL/RLS/portes privées, conservation de toutes les fiches/possessions et identités PNJ, exécuter les contrôles de dérive et régénérer le baseline uniquement avec les outils canoniques. Les contrôles rouges ne deviennent pas verts sur déclaration.

**Retour arrière :** avant COMMIT, toute erreur doit annuler le lot et son registre. Le garde de collision interdit de rejouer aveuglément une installation déjà enregistrée ou partielle. Après COMMIT et après reprise d'activité, ne jamais restaurer une ancienne photographie de joueurs ou supprimer des reçus : arrêter les ordres concernés et préparer un correctif en avant fondé sur l'état actuel. Un retour des seules définitions/client exige une compatibilité démontrée sur copie jetable avec les nouveaux états ; aucun rollback destructeur générique n'est livré.

## Recette authentifiée isolée à exécuter avant feu vert

Réutiliser Chromium/Playwright existant, même client et mêmes RPC, contre un environnement isolé autorisé au schéma homologué. Comptes de test existants et identités vérifiées ; pas de création/modification d'authentification en production. Fournir URL de staging et accès de test par secrets protégés. L'autorisation d'Arnie reste **consultation seule**, sans déplacement ni combat : elle ne peut pas servir à ces scénarios.

| Parcours | Résultat exigé et preuve |
|---|---|
| Deux sessions PJ, adhésion/retrait/chef | Consentement, autorité serveur, groupe non inventé à l'écran, pas de réponse livrée au mauvais personnage |
| Policiers, soldats, douaniers, vigiles | Métier/mandat/affectation réels ; détection avant intervention, pas de pouvoir institutionnel attribué au vigile ; refus sans PA si non autorisé |
| PNJ homonymes, gamma, profil incomplet | Identifiant canonique du présent ; aucune attaque arbitraire ni paiement sur un refus ; les trois villes couvertes |
| Marche, sortie, quatre vues PSM, transport PJ/PNJ, camion | Position de tous confirmée, provenance correcte, coût historique, payeur leader pour tous les voyageurs ; insuffisance = aucun débit/déplacement partiel |
| Combat civil, militaire, privé et squatteurs | Même bataille/rounds/armes, cinq rounds puis décisions, neutralisation/mort/fuite réelles, chef neutralisé, courrier/rapport persistants |
| Réponses perdues, double clic, reconnexion, deux onglets | Même requête rejouée sans second paiement/round ; ancienne sauvegarde ne rétablit ni PA, santé, argent ni position ; aucune conséquence sur un tiers |
| Justice, douanes et rapports | Confiscation réelle et convocations des seuls PJ ; écrou et séparation cohérents ; tiers ne lit pas un rapport privé |
| Calendrier sans navigateur | Rattrapage des échéances par le cron existant, pas de polling ni nouveau minuteur ; aucun traitement doublé |

Conserver captures et statuts réseau expurgés, références de reçus et positions avant/après, sans jeton, mot de passe ni données de joueurs réels. Un cas absent est **non exécuté**, jamais réussi. À ce jour aucune recette authentifiée isolée ni de production de ce lot n'a été exécutée ; aucun service Supabase n'est exposé à cette session. Les accès du connecteur d'une autre session ne sont pas transférés implicitement.

## Verdict

Corrections et preuves locales disponibles sur #219 ; aucune fusion ni migration de production. **PR pas encore certifiée prête à fusionner en production** : restent le catalogue complet, l'installation atomique sur copie fidèle, la recette authentifiée isolée et le traitement explicite des contrôles globaux rouges. Ces obstacles sont documentés et ne demandent aucun nouvel arbitrage de game design.
