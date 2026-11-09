# Référentiel de game design — Human Gambit / Res Publica

**Édition consolidée de l'audit : 9 novembre 2026.** Source examinée : `main` au commit `a8bd5e266f18f3432ec3feb11d53dbb799043531`. **Statut : audit documentaire et technique avancé, sans certification générale de jouabilité.**

## Objet
Servir de mémoire durable commune au game designer, à ChatGPT, Claude et Codex, afin de comprendre **les règles, leurs interactions et leur disponibilité effective**, puis d'évaluer expérience joueur, rétention et masse critique. Ce répertoire **ne modifie aucune règle**, n'entraîne aucune migration et n'autorise aucune mise en production.

## Ordre de lecture obligatoire
1. [Constitution fondatrice](../CONSTITUTION.md) : la relation humaine prime sur la simulation ; plusieurs trajectoires de réussite ; le moteur arbitre sans remplacer le joueur.
2. [Méthode et niveaux de preuve](METHODE-ET-PREUVES.md).
3. [Atlas des systèmes et parcours](ATLAS-SYSTEMES.md).
4. [Catalogue historique des 61 mécaniques de l'architecture](CATALOGUE-MECANIQUES-HISTORIQUE.md), à actualiser ordre par ordre.
5. [Relevé vérifié de Supabase en lecture seule](ETAT-SUPABASE-LECTURE-SEULE.md).
6. [Catalogue des 517 coûts d'ordres configurés](CATALOGUE-COUTS-SERVEUR.md).
7. [État de publication Vercel et commit réellement publié](ETAT-VERCEL-PUBLICATION.md).
8. [Catalogue des 1 072 déclarations d'ordres client](CATALOGUE-ORDRES-CLIENT.md).
9. [Localisation des 956 ordres par bâtiment et pièce](CATALOGUE-BATIMENTS-PIECES-ORDRES.md).
10. [Croisement statique des identifiants client et des coûts serveur](CROISEMENT-CATALOGUES.md).
11. [Navigation et accessibilité : six graphes de rues](NAVIGATION-ET-ACCESSIBILITE.md).
12. [PNJ IA : prise de contact et formes de mémoire](PNJ-IA-MEMOIRES-INTERACTIONS.md).
13. [Fiches détaillées des pouvoirs, élections et contre-pouvoirs](FICHES-POUVOIRS-ET-CONTREPOUVOIRS.md).
14. [Fiches détaillées d'économie, logistique et mobilité](FICHES-ECONOMIE-LOGISTIQUE-MOBILITE.md).
15. [Fiches parcours personnel, sociabilité et frictions](FICHES-PARCOURS-SOCIAUX-ET-FRICTIONS.md).
16. [Synthèse, certitudes et frontières de l'audit](SYNTHESE-AUDIT-ET-LIMITES.md).
17. [Matrice de couverture et d'état](MATRICE-COUVERTURE.md).
18. [Contradictions, risques et vérifications manquantes](ECARTS-ET-VERIFICATIONS.md).
19. [Cadre de l'audit expérience joueur et rétention](EXPERIENCE-ET-RETENTION.md).
20. [Index technique des sources (fichiers, migrations et bancs)](INDEX-TECHNIQUE.md) : piste d'audit, non preuve d'activité.
21. Sources détaillées préexistantes : [architecture](../ARCHITECTURE.md), [relais](../RELAIS.md), [game design Sovarka](../GAME-DESIGN-NOVOMIRSK.md), tous les `GAME-DESIGN-*.md`, [audit d'autorité](../AUDIT_UNE_SEULE_VERITE.md).

## Convention de statut (ne jamais les confondre)
- **D — Décidé** : règle explicitement adoptée, preuve documentaire datée ; ne prouve pas son exécution.
- **C — Codé** : chemin effectif identifiable dans le code du commit examiné ; ne prouve ni migration appliquée ni absence de défaut.
- **T — Testé** : banc et résultat identifiables, avec environnement, date et SHA ; une simple présence de fichier de test ne suffit pas.
- **M — Migration appliquée** : preuve du registre de production ou mention d'exécution attribuée et datée ; distinguer **déclarée** de **indépendamment vérifiée**.
- **P — Publié** : commit réellement fusionné et déploiement explicitement attesté ; jamais déduit d'un fichier présent.
- **J — Jouable confirmé** : essai humain avec version, parcours et résultat réellement observés. **Non établi** par un test de code ou une CI verte.
- **? — Inconnu / à corroborer** : ne pas extrapoler.

Un élément peut être D+C mais non T/M/P/J. `main` ne vaut ni migration produite ni recette réelle.

## Où se trouve chaque source
| Source | Usage canonique | Limite |
| --- | --- | --- |
| `CONSTITUTION.md` | Principes non négociables du jeu | Ne précise pas les valeurs chiffrées de chaque ordre |
| `GAME-DESIGN-*.md` et `GAME-DESIGN-NOVOMIRSK.md` | Décisions et exceptions d'empire | Contiennent parfois propositions et états historiques |
| `ARCHITECTURE.md` | Cartographie des couches et catalogue historique | Daté principalement du 26–27 octobre ; chiffres non recalculés au 9 novembre |
| `RELAIS.md` | Historique d'intégration, déclarations et chantiers | Journal cumulatif, mélanges de livraisons et travaux non publiés |
| `data.js`, `plateau-*.js`, `api/*.js` | Interface, catalogue, chemin de commande et services Vercel | Pas la preuve du schéma vivant Supabase |
| `baseline/`, `migrations/`, `historique/` | Modèle SQL, évolutions et archives | Le contenu Git ne certifie pas l'état réel de la production |
| `outils/bancs/`, `outils/audits/` | Tests et rapports versionnés | Résultats à rattacher à un SHA précis ; certaines fixtures ne simulent que le serveur |
| Issues et PR GitHub | Arbitrages, intégration, contre-exemples | Une PR ouverte n'est pas fusionnée |

## Règle de maintenance partagée
Pour chaque modification de mécanique future, l'agent qui intervient :
1. vérifie la décision existante et cite la source, sans réarbitrer spontanément ;
2. met à jour la fiche de système et sa ligne de matrice, sans remplacer un **?** par une supposition ;
3. relie la fonction client, la RPC/SQL, les autorisations, le coût PA/monnaie, les impacts croisés et les tests ;
4. conserve séparément le résultat des tests automatiques, l'état de la migration, la publication et la recette PJ ;
5. documente contradictions et régressions dans `ECARTS-ET-VERIFICATIONS.md` ;
6. ne déclare « jouable confirmé » qu'après un test réellement observé.

**Fiche-type :** identifiant stable ; finalité sociale ; décision datée ; territoire/pays ; acteur et adversaires ; déclencheur et lieu ; préconditions ; coûts PA/monnaie/objets ; gains/risques ; sorties et contre-pouvoirs ; temps réel/quotidien ; données persistées ; route client → RPC → tables ; PNJ de repli ; dépendances ; statut D/C/T/M/P/J ; sources ; lacunes ; effet sur l'interaction entre PJ.

**Périmètre du présent lot :** inventaire du dépôt, lecture des sources fondatrices et de documents métier, confrontation ponctuelle au code, **lectures SQL strictement non mutantes des catalogues et règles de configuration Supabase**, lecture du registre de migrations ; **production Vercel READY vérifiée en lecture seule pour le SHA de référence ; pas d'accès authentifié à un PJ, pas de requête sur les données des joueurs, pas de tests d'actions du jeu exécutés, pas de recette de production**. L'exhaustivité des centaines de commandes et de fonctions SQL exige encore un dépouillement systématique ; consulter la matrice pour les zones non closes.
