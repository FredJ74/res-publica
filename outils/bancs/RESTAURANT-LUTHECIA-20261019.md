# Bar et restaurant gastronomique de Luthécia

## État de livraison

Code et migration préparés sur `main`. **Activation Supabase non effectuée, fonctionnement en production non vérifié.** Aucun connecteur Supabase ou Vercel, ni identifiant SQL/Vercel, n'est disponible dans cet environnement. Les lectures HTTPS de la page de production et de l'API GitHub échouent au tunnel du proxy (`CONNECT ... 403`, code HTTP applicatif non obtenu). Cela ne démontre pas une panne du jeu. Git fetch/push fonctionne.

Aucune donnée réelle modifiée, aucun personnage créé, aucune image changée. Aucune migration d'organisation ou d'équipement collectif modifiée ou appliquée.

## Arbitrage économique retenu

Le propriétaire a choisi l'option 1 : 25 FR, rendement entier et marge **minimale** ×2. Le vin de référence utilise un fruit/légume et un PA. Champagne et cocktail utilisent deux fruits/légumes, deux PA et donnent neuf verres. Avec les coûts de référence, 108 FR par lot, le minimum ×2 par verre est 24 FR : 25 FR convient. La règle générale de prix automatique PNJ n'est pas changée. Si le coût moyen réel fait dépasser 25 FR au minimum ×2, la production PNJ est refusée avant dépenses ; aucun arrondi ou rendement fictif ne masque ce refus.

Les trois recettes gastronomiques de Luthécia passent d'un à trois PA, gardent leurs cinq portions et leurs matières, avec prix fixe numérique 125 FR. L'ancien booléen `prixFixe: true` n'était pas un prix exportable par le générateur de référentiels. L'exception reste limitée à ces recettes et à l'établissement de Luthécia. Les recettes de Port-Sainte-Marie et les boissons ordinaires ne sont pas changées.

## Raccordements

- Une entreprise canonique, une caisse et des stocks conservés ; deux cartes serveur par pièce. Bar : boissons, cacahuètes, cocktail et champagne. Restaurant : repas, boissons existantes, champagne et amuse-bouche ; aucun cocktail ajouté automatiquement. Les nouveaux stocks commencent à zéro. Aucune conversion des anciennes cacahuètes en amuse-bouche ni duplication d'actifs.
- Le catalogue existant reste le point d'achat, de production et de fiche produit. Les autorisations de production, le propriétaire réel et le moteur de tournée existants sont conservés. La séparation est aussi contrôlée dans les ventes, productions et créations de tournées serveur, même par appel direct.
- L'ordre de dîner existant garde deux PA, 300 FR et ses effets (+10 Santé, +2 Moral, +5 INF, +3 PA différés). Son service appelle le moteur privé de vente existant avec exactement deux repas disponibles et deux champagnes. Débit, stocks, caisse, fiscalité, effets des deux convives PJ et reçu sont dans la même transaction. Avec un PNJ, seul l'organisateur PJ reçoit ses effets.
- Les invitations existantes portent le nouveau contrat et les reçus. Les nouvelles RPC authentifiées recontrôlent identité, présence, acceptation et accès. Aucun montant ni panier fourni par le navigateur n'est accepté. Les invitations refusées n'entraînent aucun service.
- Le tirage PNJ est serveur, conservé au rejeu : neutre 60 %, ennemi 20 %, groupe 95 %. Employés, escorts et membres sont lus côté serveur ; les agents utilisent la projection existante `agents_couverture_de_mon_groupe`, sans exposer de vrai nom. Le départ du groupe invalide le service.
- Identifiant d'invitation stable après réponse perdue, verrous de concurrence, reçu de service, relecture des états et acquittement évitent les doubles débits et bonus. Aucun delta financier ou bonus local ne remplace la réponse officielle. Les réponses tardives d'une autre session/personnage sont ignorées.

### Dépendance visible avant installation

Le client refuse d'afficher une fausse nouvelle carte si `versionGastronomieLuthecia` et `cartesParPiece` ne sont pas confirmés par le serveur : message « Carte en cours de mise à jour ». **Ces deux cartes seront donc indisponibles tant que la migration n'est pas installée.** Le dîner ne peut pas réussir sans ses RPC. Il ne faut pas présenter la publication du client comme une activation complète.

Les anciennes invitations acceptées ne prouvent pas l'absence de facturation antérieure. Elles ne sont ni converties, ni supprimées, ni refacturées automatiquement. Le service libre historique à Luthécia est refusé par la nouvelle garde afin d'éviter un second paiement. Leur éventuelle reprise exige d'examiner les preuves historiques, pas de rejouer leurs effets. Les autres lieux conservent leur circuit historique.

## Vérifications exécutées

| Vérification locale | Résultat |
| --- | --- |
| Contrôleur client complet, dont Chromium et bundle Vercel | 90/90 bancs |
| Nouveau banc client restaurant, inclus ci-dessus | 18/18 tests |
| Nouveau PostgreSQL jetable restaurant | 94/94 assertions |
| Catalogue et tournée, PostgreSQL jetable | 60/60 assertions |
| Assemblage électronique, PostgreSQL jetable | 20/20 groupes |
| Achat commerce, PostgreSQL jetable | 12 groupes réussis |
| Réception atomique, PostgreSQL jetable | 31 groupes réussis |
| Contre-épreuves existantes | 90/90 |
| Tests calendrier Node | 5/5 |
| Syntaxe API | 23/23 modules |
| Syntaxe des quatre scripts client modifiés/nouveau | Conforme |
| Analyse SQL pglast | Migration 66 instructions ; prévol 13 instructions valides |
| Workflow global | **10/12**, deux contrôles rouges détaillés ci-dessous |

Les 94 assertions PostgreSQL incluent migrations rejouées, refus explicite d'une définition serveur inconnue avant mutation, cartes, prix, PA, matières, marge, stocks insuffisants, refus après débit simulé, exception et rollback, réponse perdue/rejeu, deux services concurrents, accès tiers, invitation obsolète, PNJ et agents, lecture après rechargement, protection des reçus, création future et tournée avec champagne via le moteur existant. Authentification, paiement et fiscalité annexes sont des fixtures : **ce ne sont pas des tests authentifiés Supabase ni une preuve de RLS réelle**. Les fonctions métier de production et de vente exécutées sont celles des migrations.

La vérification finale de la projection REST a supprimé une lecture de `bonus_pa_differe` envisagée dans le premier commit : cette colonne de la table privée n'est pas exposée par la vue `personnages` archivée. Le bonus différé reste entièrement serveur, comme le prévoient les fonctions existantes d'attribution et de repos. Un test exécute la vraie relecture sociale et confronte ses colonnes à la vue ; aucune modification de vue ni exposition supplémentaire n'est nécessaire.

### Contrôles globaux non satisfaits

- **Authority** : invariant 13, 28 RPC appelées côté navigateur absentes du baseline archivé, dont les cinq nouvelles RPC préparées ici. Une déclaration dans une migration ne prouve pas son installation. Les autres invariants d'autorité passent. L'existence et les droits réels restent à extraire du catalogue vivant.
- **Referential** : trois empreintes divergent : `ordres_couts` (`a1159f6106f955b9` contre `20e52d8f9bbe8e3f`), `postes_nommes_regles` (`694f117ace57b0b1` contre `6c0c7aa0d29bf852`), `miroirs_entreprises` (`a497db09af2c6fe7` contre `e2b15dda50c9a640`). Les nouvelles recettes contribuent à la divergence du miroir d'entreprises. Aucune empreinte de référence, observation ou baseline généré n'a été réécrit pour faire passer le contrôle. Après installation réelle, extraire et régénérer avec les outils du workflow.

## Installation contrôlée restante — opérateur technique

1. Utiliser le canal Supabase autorisé du projet `jxpwoosmmhohoihxpbuc`. Exécuter en lecture seule `outils/bancs/banc-restaurant-luthecia-prevol.sql`, ainsi que le prévol du catalogue/tournée. Vérifier le registre des migrations, toutes les définitions, propriétaires et `search_path`, les droits, RLS, triggers, contraintes, recettes de référence, bonus différé de trois PA et circuits de paiement. Vérifier aussi la projection des agents. Ne pas déduire l'installation des messages de commits Git.
2. Comparer avec `20261019213444_catalogue_et_offrir_a_boire.sql`, puis `20261019221500_luthecia_cartes_et_diners.sql`. La première conserve le moteur électronique fusionné par les commits concurrents `0e93d13`, `41f6e3c` et `c78777c`, intégrés avant livraison. Ses garde/rejeu et son banc sont ceux de `main`. Une fonction serveur inconnue doit arrêter l'application, jamais être écrasée pour satisfaire une empreinte.
3. Vérifier une seule entreprise cible, sa structure JSON, ses coûts moyens, stocks, prix, caisse, matières et historique. Conserver les empreintes de prévol dans un stockage technique approprié, sans publier de données personnelles. Examiner les anciennes invitations acceptées séparément. Ne pas créditer de stock fictif pour rendre possible un test.
4. Si et seulement si les préconditions sont conformes, appliquer via le workflow la migration catalogue/tournée si absente, puis la migration restaurant. Les transactions et gardes empêchent les modifications partielles ; elles ne remplacent pas l'inspection préalable. Ne pas rejouer une migration enregistrée sans nécessité.
5. Relire registre, définitions, droits et cartes ; confronter les empreintes des anciennes valeurs préservées avant/après. Régénérer baseline, seeds et référentiels via les outils prévus, sans édition manuelle des SQL générés. Relancer les douze contrôles et publier les écarts réellement restants.
6. Vérifier Vercel et les fichiers servis correspondant au commit publié. Tester avec comptes autorisés/entreprise isolée : les deux pièces, production autorisée/interdite, achats, dîner PJ/PNJ, refus, insuffisance et perte de réponse. Aucun acte fictif sur un joueur réel. Tant que ces contrôles ne sont pas faits, **chantier non terminé en production**.

### Retour arrière

Ne pas supprimer les invitations, reçus, nouvelles colonnes ni stocks après utilisation. En cas d'incident, arrêter les nouveaux services par une correction contrôlée et conserver les reçus pour réconciliation. Préférer une migration corrective transactionnelle après comparaison du catalogue. Revenir uniquement au vieux client sans traiter le contrat serveur ne constitue pas un retour arrière sûr ; ne pas restaurer une photographie de caisse/inventaire au détriment des transactions intervenues depuis.
