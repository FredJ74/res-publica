# Synthèse de l'audit — lecture du jeu et limites de certification

**Périmètre :** Human Gambit / Res Publica, instantané de référence `main` `a8bd5e266f18f3432ec3feb11d53dbb799043531` du 9 novembre 2026. Ce document conclut le **volet exploratoire documentaire, cartographique et de lecture serveur non mutante**. Il **ne clôt pas une recette de jouabilité** et n'autorise aucune correction de règles.

## Ce que l'on peut désormais affirmer avec fondement

1. Le jeu est construit en **systèmes sociaux interdépendants**, pas comme une collection d'ordres : politique, institutions, professions, propriété, production, finance, logement, sécurité, justice, guerre, presse, religion, sports, mobilité, espionnage, contre-pouvoirs et PNJ. C'est l'intention explicite de `CONSTITUTION.md`, dont le code présente de nombreux points d'entrée identifiés dans `INDEX-TECHNIQUE.md`.
2. Le moteur déployé est riche en données : **110 bâtiments, 303 pièces et 956 références statiques à fonctions** dans la déclaration `BUILDINGS` de `data.js` ; **1 072 occurrences non commentées d'identifiants d'ordres** dans le fichier, **417 identifiants distincts** ; **517 tarifs/entrées** dans la table de coûts serveur. Ces chiffres mesurent **des inventaires de sources hétérogènes**, jamais « 517 actions jouables ».
3. La structure vivante Supabase a été interrogée **sans lecture de données privées de joueurs** : 444 tables publiques, 1 605 fonctions publiques, 249 policies, registre de 1 317 migrations. Une vaste structure n'assure ni qualité, ni sûreté, ni disponibilité individuelle d'un ordre.
4. Les six graphes des rues de Républia et Sovarka sont techniquement cohérents selon la requête SQL (aucune cible de voisin inexistante, graphes connectés) ; **l'utilité de la carte visuelle** et l'accès à tous les bâtiments ne sont pas établis. Les sorties explicites de Starovka/Krasnov restent peu nombreuses dans le relevé.
5. La production Vercel a été identifiée à un déploiement READY correspondant **exactement au SHA inspecté** lors du contrôle initial ; cela prouve l'origine du code publié, non ses chemins fonctionnels ni l'absence de panne pour un PJ.
6. Des PNJ sociaux ont de vrais déclencheurs configurés et une **mémoire relationnelle persistée**, mais le système social vérifié ne constitue pas, à lui seul, un journal exhaustif des conversations. D'autres mémoires contextuelles de PNJ doivent être distinguées.
7. Les pouvoirs de Sovarka changent substantiellement la relation entre institutions et joueurs : compétition des partis, présidence limitée, conseil très puissant, censure, surveillance et exploitation de biens étatiques. Ne pas les réduire à un habillage de Républia.
8. Les économies et la logistique offrent de multiples occasions de coopération et de conflits : offres d'achat avec fonds bloqués, contrats de propriété, pénuries, production progressive, fret et douanes, entreprises et recrutement.
9. Certains systèmes affichés sont **intentionnellement incomplets** : navigation privée des bateaux, mobilité PJ interempire et effets internationaux dérivés, activation multilingue générale, certaines options diplomatiques ; des documents comportent un historique « à coder » suivi d'un état codé plus tardif.
10. **Journal de production vérifié** : les passes nocturnes du 1er au 6 novembre 2026 sont toutes marquées en échec sur une RPC de prêts Helvetia ; les trois du 7 au 9 sont marquées ok. Ce n'est ni une certification de chaque débit ni une preuve de rattrapage. [Audit](AUDIT-ACCUEIL-I18N-NUIT-DROITS.md).
11. **Onboarding codé et substantiel** : parcours de Luthécia, Jérémy, trois orientations de carrière plus l'indécision, et invitation au forum volontaire, sans recette humaine. Les neuf codes de langues sur l'accueil ne signifient pas neuf expériences complètes. [Audit](AUDIT-ACCUEIL-I18N-NUIT-DROITS.md).
12. Aucune base de mesure de l'activation, de D1/D7 ou de la réussite d'un nouveau joueur n'a été examinée ; toute prévision de rétention est une **hypothèse**, pas un résultat.

## Ce que cet audit rend possible

Discuter en connaissance des **contraintes de conception** : l'intérêt central doit venir des relations entre PJ, les PNJ et les services assurent une continuité avec peu d'habitants, et les systèmes peuvent donner des objectifs personnels émergents sans les transformer en obligations mécaniques. Les documents `EXPERIENCE-ET-RETENTION.md` et `FICHES-PARCOURS-SOCIAUX-ET-FRICTIONS.md` distinguent premières minutes, progression, satisfaction des actes, densité de personnes et retour spontané.

## Ce qui n'est pas certifié (et ne doit jamais être déclaré terminé)

- Les **417 identifiants client** ne sont pas tous rattachés ordre par ordre à une RPC active, à sa migration, ses permissions SQL, ses coûts et une contre-épreuve. Le catalogue sert d'index, pas de certification.
- Les **1 605 fonctions SQL** n'ont pas toutes fait l'objet d'une lecture de corps. L'audit serveur a ciblé la structure et quelques exemples majeurs (PNJ sociaux, naval, géographie).
- Les tests automatiques **n'ont pas été relancés sur un environnement d'exécution PostgreSQL + navigateur** lors de ce travail ; les anciens bancs et CI sont rapportés avec leur provenance.
- Aucun **PJ connecté** n'a été utilisé, et aucun vrai flux de recrutement, marchandise, paiement, police, élection, justice ou PNJ IA n'a été déclenché en production.
- Aucun essai sur **vrai iPhone ou Android**, aucune validation d'ergonomie non-francophone et aucune mesure de cohorte de nouveaux joueurs.
- Les règles encore contradictoires entre intentions historiques et versions publiées demandent des vérifications ciblées, pas des modifications automatiques.

## Verdict de portée

**Volet de compréhension conceptuelle, inventaire, rapprochement technique et vérification de configuration : avancé et documenté ; pas d'exhaustivité opérationnelle démontrée.** Le référentiel est immédiatement utile comme base de discussion et de contrôle transversal, mais **« audit entièrement terminé et jeu vérifié » serait une affirmation non étayée**. La suite relève d'une campagne de traçabilité exhaustive par commande et de recettes isolées avec prérequis d'exécution/identité, non d'un nouvel arbitrage de design. La PR doit rester ouverte tant que ces preuves manquent.

## Ordre de lecture pour une discussion de rétention
`CONSTITUTION.md` → `ATLAS-SYSTEMES.md` → `FICHES-PARCOURS-SOCIAUX-ET-FRICTIONS.md` → `FICHES-POUVOIRS-ET-CONTREPOUVOIRS.md` → `FICHES-ECONOMIE-LOGISTIQUE-MOBILITE.md` → `EXPERIENCE-ET-RETENTION.md` → `ECARTS-ET-VERIFICATIONS.md`. Toujours consulter les catalogues et la matrice pour vérifier une action précise avant de la présenter comme jouable.
