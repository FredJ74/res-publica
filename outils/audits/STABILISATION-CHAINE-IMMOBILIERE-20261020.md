# Stabilisation de la chaîne immobilière — 20 octobre 2026

**CHANTIER NON TERMINÉ. Aucun correctif serveur ni déploiement de production dans cette livraison.**

Branche : `codex/stabilisation-chaine-immobiliere-20261020`, issue de l'audit `83d7e77`.
Base `main` vérifiée après fetch : `baa9cb7e2b7f89db66cf268d21382deb0be2a3a2`.
Les corrections presse, commerciales, graphiques et les quatre vues de Port-Sainte-Marie sont conservées.

## Corrections exécutables livrées

- `plateau-justice-economie.js` : les helpers de localisation foncière utilisent le pays et les villes de `WORLD`, plutôt que les seules listes de Républia. Les 36 terrains déclarés sont couverts ; une référence absente ou ambiguë est refusée.
- `plateau-pnj.js` : les quatre terrains de Port-Sainte-Marie ont leur surface canonique de 1 500 m². L'achat direct n'invente plus une surface de 2 000 m² : une référence indéterminée est bloquée avant paiement. Le prix reste surface × prix au m² existant, sans changement tarifaire.
- `plateau-justice-economie.js` : le résultat du prêt national met à jour la map bancaire ; les anciens caches en tableau sont convertis. Cela corrige l'exception `.find is not a function` **après** une réponse de prêt réussie. Cela ne prouve ni ne corrige la création du prêt côté serveur.
- Même fichier : la quantité de matériaux volés est une variable réaffectable. Auparavant, la réponse réussie du serveur provoquait `Assignment to constant variable` avant l'ajout à l'inventaire. La quantité effectivement confirmée, éventuellement nulle, est utilisée. L'atomicité globale stock/inventaire reste à traiter côté serveur ; cette correction ne la garantit pas.
- `plateau.html` : versions des deux scripts actualisées pour recharger les fichiers corrigés.
- `outils/bancs/banc-immobilier-stabilisation-client.cjs` : sept tests, dont une contre-épreuve réintroduisant le `const` fautif dans une copie en mémoire et exigeant l'exception historique.

Sauvegardes GitHub :

- `5d80c5e0153bff2e254a49333f9d501a42a95603` : surfaces, localisation, map bancaire et premières régressions.
- `f11ea67b98495bf6c39d718685bba7e5daf9f78f` : traitement de la quantité confirmée, contre-épreuve, versions client et prévol enrichi.

Aucune fusion sur `main`. Aucun commit de cette branche annoncé comme déployé.

## Accès réel et limite préalable imposée

La mission exige de comparer les définitions Supabase vivantes **avant de modifier le SQL**. Aucun connecteur Supabase n'est exposé ; aucun accès administrateur de ce projet n'est disponible dans l'environnement. Une requête HTTP sans identifiant vers le point REST a échoué au tunnel proxy : `CONNECT tunnel failed, response 403`. Ce résultat ne prouve pas une panne Supabase : la connexion au service n'a pas été établie.

Git fetch/push fonctionne. L'accès API Vercel nécessaire au contrôle distant n'est pas disponible. Aucun compte autorisé pour un achat, un prêt ou un travail de test n'est disponible ; Arnie n'est pas autorisé pour ces opérations et n'a pas été utilisé.

En conséquence, **aucune migration nouvelle n'a été rédigée, appliquée ou déclarée prête à activer** depuis les seules définitions du baseline du 13 octobre. Aucune fonction vivante n'a été remplacée, aucun droit distant modifié. Il serait dangereux de raccorder un nouveau débit client sans connaître les contrats et protections d'inventaire actuellement installés.

## Prévol préparé, non exécuté à distance

`outils/bancs/prevol-audit-chaine-immobiliere.sql` reste en transaction explicitement READ ONLY, terminée par ROLLBACK. Il comprend désormais :

- registre des migrations et définitions/signatures exactes des surcharges foncières, prêts, chantiers, entrepôts, réceptions, reçus et inventaires ;
- rôles, droits EXECUTE, politiques RLS, triggers et contraintes ;
- types réels des colonnes (texte/JSON, numeric/integer, vues et tables), valeurs par défaut et dépendances catalogue ;
- fonctions du socle d'emploi et de position des agents privés ;
- référentiels de coûts/paliers et agrégats de données sans identité ni solde individuel.

Les dépendances SQL dynamiques nécessitent aussi une lecture des définitions et des appelants ; `pg_depend` seul ne suffit pas. La syntaxe des 17 instructions a été contrôlée avec pglast ; seuls SELECT, paramètres de transaction et BEGIN/ROLLBACK sont présents. Ce contrôle syntaxique ne certifie pas leur exécution sur le schéma vivant.

La reprise technique nécessite un accès de lecture autorisé au catalogue du projet. L'opérateur technique devra comparer ces résultats au baseline et aux migrations avant de préparer les changements suivants ; aucune manipulation SQL n'est demandée au game designer.

## Périmètre restant, sans masquer les risques

| Domaine | Travail restant avant activation | Dépendance précise |
| --- | --- | --- |
| Autorité foncière P0 | Vérifier le rôle de service réel, pays/ville, propriétaire, première réservation concurrente, patchs autorisés et droits sur dettes | Définitions vivantes de `terrain_*`, `est_appel_serveur`, RLS de `prets` |
| Acompte et acte | Débit et réservation/mutation dans une transaction, reçu lié à l'acteur et à l'intention, rejeu stable | Contrats financiers vivants et miroir des coûts ; ne pas ajouter arbitrairement un coût variable au miroir |
| Prêts | Dette et crédit bancaire utilisable atomiques ; pas de second crédit si la dette existe ; préserver Helvetia | `pret_national_contracter` absent des définitions archivées, `compromis_expire_resoudre`, comptes et triggers actuels |
| Permis et réaménagement | Dimensionnement serveur, plan verrouillé, refus des gabarits clients forgés, paiement atomique | Portes de permis et plans persistants vivants |
| Chantier | Refuser second chantier initial, versements avec reçus, présence réelle pour travailler, mutation cohérente des colonnes/JSON | RPC et référentiels de chantiers vivants |
| Matériaux et plafonds | Réglage propriétaire, refus avant transfert si plafond absent ou dépassé, comparaison sous verrou au moment de la vente, monnaie au centime et inventaire révisé | Aucun champ de plafond propriétaire trouvé dans le contrat archivé ; ne pas initialiser un tarif implicite |
| Consolidation nocturne | Transaction par chantier/jour et par remboursement, stock/réserve/argent/salaire/progression/livraison indissociables | API service, entrepôts, réserves militaires, finances et reçus vivants ; le PATCH de blob actuel n'est pas atomique |
| Changement de propriétaire | Transmettre chantier, trésorerie, matériaux et obligations en vente/succession/saisie ; synchroniser colonnes | Fonctions de mutation et de saisie actuelles, notamment cron |
| Vigiles | Affectation via emploi/position communs, présence autoritaire et mêmes détection/intervention/combat | Le comptoir Grobras documente recrutement seulement ; le branchement opérationnel partagé de garde doit être retrouvé/vérifié, pas recréé en parallèle |
| Livraison et exploitation | Vérifier pièces, baux, vocation commerciale des lots, rejet avant apport, reliquats et usages du hangar | `creer_fonds_commerce`, classification des locaux, locations/inventaires vivants et tests authentifiés isolés |

Les démonstrations historiques de l'audit restent des **preuves de défauts dans une photographie locale**, et non des tests de production. Le succès des bancs existants ne referme pas ces défauts. Le banc d'audit cron exigeant les anciens défauts J08/J11/J13 n'a pas été présenté comme une validation du client corrigé ; ses assertions historiques n'ont pas été supprimées.

## Vérifications locales

- Banc ciblé : **7/7** (quantité confirmée 3 ou 0 ; contre-épreuve `const` ; 36 terrains ; surface inconnue sans débit ; prêt avec map et ancien tableau).
- Contrôleur client complet : **92/92 bancs réussis**.
- Contre-épreuves existantes : **90/90 réussies**, aucune assertion neutralisée.
- Syntaxe des deux scripts client et `git diff --check` : conformes.
- Prévol : syntaxe PostgreSQL et caractère non mutateur vérifiés ; aucune exécution distante.
- Contrôles globaux : **10/12**, toujours deux échecs :
  - **Authority** : 28 RPC client sans définition dans le baseline archivé ; certaines ont une migration préparée, ce qui ne prouve pas leur installation.
  - **Referential** : empreintes divergentes d'`ordres_couts`, `postes_nommes_regles` et `miroirs_entreprises`.
- Aucun baseline, observation ou empreinte retouché pour obtenir du vert.
- Aucun test authentifié de production, aucune visite réelle, aucun déploiement Vercel confirmé.

## Verdict

**CHANTIER NON TERMINÉ, NON PRÊT POUR UNE ACTIVATION SERVEUR.** Corrections client limitées, testées et sauvegardées sur une branche distante ; reste de la chaîne non sécurisé. La comparaison du catalogue vivant est le verrou technique préalable. Aucune donnée de joueur, dette, solde, inventaire ou authentification n'a été modifiée.
