# #219 — Raccordements civils, groupes et squatteurs — 30 octobre 2026

> Mise à jour de livraison : [rapport après intégration de main #258/#260/#261/#264](LIVRAISON-CONTROLEE-GROUPES-219-20261030.md). Les chiffres et conditions ci-dessous décrivent la passe antérieure.

**Code raccordé et testé localement ; PR non autorisée à fusionner ou déployer à ce stade.**
Le prévol du catalogue réel et la recette authentifiée isolée restent nécessaires.
Aucun accès Supabase callable n'est exposé dans cette session ; les commentaires
judiciaires fournis ne remplacent pas un relevé complet et actuel. Aucun joueur
réel connecté pour ces essais, aucune migration de production appliquée.

Code éprouvé : `678f7c81` ; branche `codex/groupes-universels-20261028`, PR #219.
Main `d4ee7224` (#257) intégré par `e733ad65`, après `496454ff` pour #255/#256.
Les derniers fichiers financiers et municipaux de Claude sont conservés.

## Corrections livrées sur la branche

- `20261030202300` : profils définitifs des squatteurs (bêta, tous 10, VOL13
  pour agressifs, END stocké dans ENT), une identité par occupation. La famille
  technique employé ne crée aucun emploi, propriétaire, salaire ou carrière.
- `20261030202400` : ouverture civile dans les batailles/engagements existants,
  acteurs et positions canoniques, chef réel, paiement historique préalable,
  reçu par acteur/paramètres et protection d'installation partielle. Le PNJ
  est résolu par son identifiant, sinon son nom unique ; homonymes, gamma et
  occupations périmées sont refusés avant paiement. Aucun objet PNJ décrit par
  le navigateur n'est enregistré comme autorité.
- `20261030202500` : trois décisions initiales, cinq rounds sans désengagement
  volontaire, mêmes coups et armes, suites terminales réelles. VOL13 agit dans
  le lecteur de compétence commun, pas dans un nouveau jet final. Terrain
  libéré pour fuite/reddition du PNJ ; cadavre seulement après sa mort réelle.
  Le motif historique de tentative après échec civil reste inscrit une fois.
- `20261030202600` : ancienne porte instantanée `crime_neutraliser` refusée,
  après extraction de ses conditions/paiement/bruit ; doctrines PNJ dans le
  même résolveur. Aucun deuxième jet ou prélèvement après les rounds.
- `20261030202700` : parcours d'accompagnement extrait du recrutement militaire,
  appelé par les deux contextes ; un PNJ accompagné engage son groupe réel.
- Chef neutralisé : ni nouveau chef, ni dissolution, ni repli impossible ; les
  compagnons continuent avec les résolutions automatiques existantes.
- Client : choix liés à la phase serveur, même reçu après réponse perdue,
  garde de session/personnage, arme de l'agresseur bornée au mode choisi.
  La branche institutionnelle des députés, explicitement distincte du combat,
  conserve son circuit existant ; son test de retour anticipé est conservé.
- Reprise après refus de navigation lié au combat : même panneau, aucune commande
  de combat automatique. Après round, santé et occupation sont relues ; aucune
  visite ou commande immobilière n'est rejouée par cette consultation.
- Courrier système persistant à l'ouverture, sans doublon au rejeu. Le journal
  ouvre le calepin existant, avec accès aux vrais rounds ; aucun second historique.
- Caches JS augmentés ; étape CI ajoutée sans retirer les étapes précédentes.

Les migrations préparées qui entraient en collision avec les mairies déjà
appliquées ont seules été renumérotées : correspondance exhaustive dans
`VERSIONS-GROUPES-219-20261030.json`. Les versions appliquées et anciennes preuves
n'ont pas été réécrites. Références de navigation préparées régénérées depuis
le vrai `data.js` de main : 284 bâtiments et 64 nœuds, quatre vues PSM conservées.

## Preuves

Dossier : [preuves-groupes-219-civils-20261030](preuves-groupes-219-civils-20261030/).
Les résultats détaillés sont archivés, pas seulement les totaux.

| Vérification | Résultat |
| --- | --- |
| PostgreSQL jetable, rôles RPC `authenticated`, JWT de décor | **373/373** |
| Contrôleur complet des bancs clients, Chromium local compris | **138/138** |
| SQL préparé : syntaxe et limites de taille | 28 fichiers du bloc `2026103020*` + prévol conformes |
| Références générées de navigation | 284 bâtiments / 64 nœuds conformes |
| Contrôleur global sur branche | **5/12**, sept catégories rouges |
| Même contrôleur sur main `d4ee7224`, worktree séparé | **5/12**, mêmes catégories rouges |

Les 337 cas acquis restent exécutés, avec un refus camion supplémentaire et
35 cas civils. Les cas SQL courants sont annulés par SAVEPOINT ; les essais de
concurrence utilisent de vrais commits sur plusieurs connexions dans la seule
base jetable, ensuite détruite. **Ce ne sont pas tous des transactions annulées.**
Les services périphériques du décor et les sources judiciaires communiquées
restent identifiés : aucune équivalence complète avec Supabase vivant revendiquée.
Les décisions PNJ de fuite/reddition sont aussi éprouvées par une doctrine
serveur contrôlée dans le décor, pas par un choix client ni un barème inventé.

| Contre-épreuve, mêmes 373 cas | Échecs effectivement détectés |
| --- | ---: |
| Mort falsifiée en neutralisation | 1 |
| Deuxième paiement au rejeu | 5 |
| PNJ déclaré replié mais immobile | 1 |
| Ancienne contre-épreuve de faux mouvement PJ | 5 |
| Ancien embarquement du seul chef | 4 |
| Provenance PNJ oubliée | 1 |

Tous ces mutants doivent échouer ; leurs résultats rouges sont conservés comme
contre-épreuves, jamais présentés comme des cas fonctionnels réussis.

Une instabilité du décor camion a été corrigée : le banc héritait parfois des
PA, décès et matricules retirés du blob lors d'un précédent combat fictif. Il
réutilise maintenant le décor initial complet des quatre soldats du banc corps,
avec leurs projections et leur embarquement effectif. Le refus PA insuffisants
reste un test obligatoire ; aucune règle de transport n'a été assouplie.

## Contrôles globaux : limites explicites

Workflow passe. Classification, fidélité du baseline, Authority, Referential,
concordance des fonctions, assemblage et reconstruction restent rouges sur
branche et main. Aucune empreinte, mesure ou baseline n'a été modifiée.

Authority : 127 RPC absentes du baseline contre 117 sur main ; 10 signatures
inconnues dans les préparations contre 5 sur main. Les préparations #219 ajoutent
ces écarts ; leurs tests locaux ne permettent pas de déclarer Authority vert.
Le défaut d'identité `resilier_bail_volontaire` préexiste sur main, hors ce lot.

Referential et certains contrôles de calcul exigent des exécutables
JavaScriptCore macOS absents de cet environnement Linux. Leurs mesures de base
datées ne prouvent donc aucune cohérence actuelle. Les erreurs exactes, ainsi
que les autres défauts de classification/baseline, sont conservées dans les
journaux comparatifs. Aucun vérificateur global n'a été affaibli.

## Conditions restant avant intégration et production

1. Exécuter en lecture seule le prévol versionné
   `outils/bancs/PREFLIGHT-GROUPES-UNIVERSELS-20261028.sql` via le connecteur
   autorisé : registre, corps, ACL/RLS et triggers réels, positions, PNJ,
   batailles, terrains, courrier, paiements et justice. Comparer les sources
   communiquées et les corps effectivement installés, avec leurs protections
   d'asile. Un MD5 documentaire n'autorise pas un remplacement différent.
2. Confirmer le référencement des PNJ présentés par le jeu. Un PNJ sans identité
   canonique existante reste refusé ; aucune création massive ou identité déduite
   d'un simple nom affiché ne doit être improvisée pour contourner ce refus.
3. Vérifier le statut réel des migrations financières #257 de Claude, leur
   ordre avec #255/#256 et leurs garanties de versement au Trésor. Ne pas
   les réappliquer parce qu'elles sont présentes sur main. Leurs fichiers et
   leur relais les signalent encore comme non appliquées ; aucun circuit
   financier parallèle n'a été ajouté ici.
4. Faire une recette authentifiée avec comptes isolés autorisés : personnes
   présentes, choix initial du défenseur, perte de réponse, plusieurs onglets,
   rapports après déconnexion, arrestation individuelle et protections d'asile.
   Arnie n'est pas autorisé à subir ces mutations de combat dans cette mission.
5. Seulement après ces preuves, valider l'ensemble cohérent des migrations
   #219 et du client. Ne pas appliquer tout le dossier migrations ni fusionner
   une consolidation générale. Le contrat refuse l'ouverture pendant une
   installation partielle ; conserver cette fermeture sûre et prévoir le
   renouvellement des anciens clients avant activation.

Le calendrier existant assure un rattrapage nocturne et les interactions font
progresser les combats sans clic adverse. **Aucune résolution exactement à
90 secondes sans navigateur n'est démontrée** ; aucune horloge parallèle ni
consultation périodique navigateur n'a été ajoutée.

**Verdict : chantier non terminé en production ; validation locale livrée,
prévol vivant et recette authentifiée indispensables avant fusion.**
