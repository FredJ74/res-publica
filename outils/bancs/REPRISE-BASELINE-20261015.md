# Reprise du baseline après les nominations municipales — 15 octobre 2026

## État confirmé par ChatGPT / Supabase

- Projet Supabase : `jxpwoosmmhohoihxpbuc`.
- Migration `nominations_municipales_au_maire` appliquée et enregistrée sous la version `20261015212703`.
- Fichier SQL archivé : `historique/migrations-appliquees/20261015210718_nominations_municipales_au_maire.sql`.
- Banc `outils/bancs/banc-nominations-municipales.sql` : **155 épreuves vertes** après correction de l'ambiguïté de variable PL/pgSQL ; l'exception finale annule volontairement la transaction.
- `postes_nommes_regles.directeur_entrepot.nomme_par = maire`.
- Les empreintes de `postes_attribues`, `titulaires_pnj` et des candidatures nationales sont identiques avant/après migration et banc.
- Le nouveau garde des candidatures est classé dans `outils/baseline/domaines.json`.
- Essais authentifiés de l'interface en jeu **non effectués**.

## Décalage global mesuré en lecture seule

Le `baseline/CONTROLE-GLOBAL.json` date du `2026-10-13T17:41:36.000139`. Le relevé réel du 15 octobre donne :

| Objet | Baseline daté | Base réelle | Écart |
|---|---:|---:|---:|
| Tables | 319 | 326 | +7 |
| Colonnes | 2541 | 2621 | +80 |
| Vues | 2 | 3 | +1 |
| Index | 517 | 527 | +10 |
| Fonctions | 906 | 918 | +12 |
| Contraintes | 615 | 639 | +24 |
| Policies | 281 | 284 | +3 |
| Triggers | 51 | 52 | +1 |
| Séquences | 38 | 38 | 0 |
| Droits de fonctions | 2458 | 2484 | +26 |
| Droits de relations | 1126 | 1155 | +29 |

Ces écarts sont **globaux**, antérieurs ou postérieurs à la migration municipale : ne pas les lui attribuer sans vérification. La réextraction complète n'a **pas** encore été effectuée.

## Suite technique obligatoire (agent disposant du dépôt et des exports Supabase)

1. Suivre **strictement** `WORKFLOW-SUPABASE.md`. Ne jamais éditer manuellement les SQL générés du baseline.
2. Exécuter les **quatre requêtes existantes** `python3 outils/baseline/requetes.py --export export_structure|export_fonctions|export_logique|export_droits` via le connecteur Supabase, en conservant **l'intégralité** des quatre sorties JSON, sans troncature.
3. Exécuter `python3 outils/baseline/requetes.py --controle-global` en lecture seule ; relever la date et les empreintes.
4. Reconstituer les fichiers d'export dans le format attendu par `outils/baseline/rendre.py`, puis lancer le rendu canonique, les seeds, et les **onze** contrôles `outils/baseline/controler-tout.py`.
5. Examiner le diff **objet par objet** ; justifier les changements non liés aux nominations. Corriger les véritables écarts du dépôt selon le workflow, sans modifier artificiellement les données du jeu.
6. Vérifier la concordance du registre Supabase avec `historique/migrations-appliquees/` et les contrôles d'archives. Consigner les éventuelles anomalies préexistantes séparément.
7. Mettre à jour `outils/baseline/referentiels.json` uniquement à partir de mesures réelles si ses observations datées sont concernées.
8. Faire un essai authentifié en jeu : maire et adjoint dans les trois villes, ouverture des trois dossiers, nomination/révocation, accès hors territoire et dossiers d'entrepôt. **Ne pas déclarer cet essai réussi tant qu'il n'a pas été effectué.**

**Ne pas exécuter de migrations supplémentaires ni d'écritures sur des personnages réels pour « tester » le baseline.** Les bancs comportementaux doivent rester annulés.

## Point d'attention

L'archivage de la migration et la documentation ont déjà été committés, **avant** le réalignement du baseline. Cela s'écarte de la règle du commit atomique du workflow. Ne pas masquer cet historique : le prochain commit doit contenir le baseline réellement réextrait et les vérifications associées.

## Dernière tentative de clôture dans Codex

Voir [`CLOTURE-NOMINATIONS-20261015.md`](CLOTURE-NOMINATIONS-20261015.md) :
contrôles locaux relancés et plantage du vérificateur de workflow corrigé,
mais ni accès au catalogue Supabase ni essais authentifiés disponibles dans
cette session. Aucune réextraction n'est revendiquée. Le ticket #1 doit rester ouvert.
