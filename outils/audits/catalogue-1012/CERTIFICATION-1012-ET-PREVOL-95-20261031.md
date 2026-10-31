# Catalogue de production 1012 et prévol du paquet #219 (Claude, 31/10/2026, 22 h 30 – 23 h 45)

Toutes les lectures ont été faites par Claude **directement en production**, en lecture seule (`execute_sql`). Aucune écriture, aucune donnée de joueur extraite : uniquement le registre, des définitions de fonctions et des empreintes md5.

## Ce qui est prouvé

| Point | Résultat | Preuve |
|---|---|---|
| Registre de production | **1012** lignes, dernière `20261031211256` (`transfert_prime_signature_serveur_20261031220000`), PostgreSQL 17.6 | `EMPREINTE-PRODUCTION-1012.json` |
| Delta 1003 → 1012 : SQL réellement appliqué = fichiers de `main` | **10/10** (dont `genre`, déjà dans le décor 1003) | `DELTA-1012-CERTIFIE.json` |
| Corps des fonctions définies en clair par ce delta (caisses, transfert, prime) | **14/14 identiques** en production et dans le dépôt | idem, `corps_vivants_normalises` |
| Gardes d'empreinte des 95 sur des fonctions **déjà en production** | **toutes concordent** : `payer_ordre` 5cf45c19…, `police_autorite_de_perimetre` 212ae9ff…, `justice_executer_condamnation_soi` 00334c44…, `crime_corrompre_douanier` 038b507c…, `militaire_deposer_soldats` / `_recuperer_soldats` / `_affecter_leader` (corps « ancienne » attendus, SECURITY DEFINER, jsonb) | ci-dessous |
| Fonctions des 95 absentes de production | toutes créées par le paquet lui-même (commandes d'organisations, adaptateurs douane/ambassade, `payer_ordre_interne`) | idem |
| Le paquet 95 touche-t-il caisses, transfert, prime, Helvetia, courriers ? | **non** ; il touche `personnages_donnees` (3 migrations : colonne de navigation) et `payer_ordre` (1 : enveloppe gardée par 5cf45c19…) | idem |
| Fichiers #299 dans les 95 | **absents** (113610 / 113631 hors sélection) | manifeste `LIVRAISON-COMPLETE-219`, sha256 95/95 vérifiés |

### Pourquoi le « candidat 1011 » de Codex était refusé

Sa comparaison portait sur `md5(prosrc)` **brut**. Or l'application par Supabase **retire les commentaires** du corps : le fichier donnait `ab4cb70e…` (avec commentaires), la production `057d4b8e…` (sans). Même logique, octets différents. Depuis la prime, la production vaut `fdb85f2d…`. Avec une normalisation identique des deux côtés (commentaires et blancs retirés), les 14 fonctions du delta concordent. **Correction à faire dans `--delta-candidat` : comparer le corps normalisé**, pas le corps brut. Aucune attente à élargir et aucune garde à retirer.

## Le catalogue complet : empreinte arborescente (au lieu d'un export impossible)

Les seules définitions de fonctions font **2,5 Mo** (1 213 fonctions). Elles ne passent pas par le canal de lecture de Claude, et l'export brut doit rester privé. D'où l'outil suivant, rejouable des deux côtés :

- `outils/bancs/empreinte-catalogue-racine.sql`
  - réduit **chaque objet** du schéma public à l'empreinte de sa définition complète : 1 213 fonctions, 422 relations, 262 politiques, 81 déclencheurs, 732 contraintes, 592 index ;
  - prend en compte, pour les fonctions, le corps normalisé, la signature, le retour, la sécurité, la configuration et les droits ;
  - prend en compte, pour les relations, les colonnes, types, défauts, RLS et droits, et la définition des vues ;
  - regroupe les objets en 16 seaux par famille.
- `outils/audits/catalogue-1012/EMPREINTE-PRODUCTION-1012.json` : **référence relevée en production**.
- `outils/bancs/comparer-empreinte-catalogue.py <empreinte_locale.json>` : CONFORME, ou les seaux discordants et la clause à coller dans
- `outils/bancs/empreinte-catalogue-detail.sql` (même définition des objets, garantie par `test-empreinte-catalogue.mjs`), qui nomme l'objet qui diffère.

Deux catalogues dont les six racines concordent ont, objet par objet, la même définition normalisée. C'est une comparaison exhaustive des définitions, pas un contrôle par noms. Le propriétaire et le concédant des droits sont écartés : le rôle d'installation diffère en local.

**Non certifié ici :** Claude n'a pas le décor privé 1003 (les quatre exports de Codex sont hors Git) et ne peut pas faire transiter 2,5 Mo. La reconstruction locale 1012 et l'installation des 95 sur ce décor restent donc à exécuter par Codex (PostgreSQL 17.6), avec la procédure ci-dessous. Le contrôle final est mécanique : comparateur CONFORME.

## Classement des copies rehorodatées de #219 (erreur de règle trouvée)

`CLASSEMENT-MIGRATIONS-219-20261031.json` range 65 fichiers en « préparation sans application attestée ». La règle « nom exact unique » manque les noms suffixés du registre. Relevé réel (`REHORODATEES-219-STATUT-REEL.json`) :

| Statut réel | Hors des 95 | Dans les 95 |
|---|---|---|
| **appliquée sous nom suffixé** (`_94`, `_135`, `_AAAAMMJJ`, `_sources`, `_fusion_…`) | 50 | 0 |
| probablement appliquée sous un autre ordre de mots (à confirmer par corps) | 6 | 0 |
| réellement non appliquée | 3 (équipements collectifs ×2, verrou final d'inventaire) | **6** (organisations ×5, squatteurs) |

**Conséquence pour l'intégration :** les 56 copies hors des 95 qui sont déjà en production ne doivent pas entrer dans `migrations/` de `main`. Elles rejoueraient un état dépassé, et leurs gardes échoueraient : c'est exactement le cas #299. Les 95 eux-mêmes sont sains sur ce point.

## Contrôles globaux : qualification des écarts

**Authority** (contre le baseline du 13/10) :
- **Invariant 13, 116 RPC « absentes du baseline »** : 115 noms distincts, contrôlés un à un en production :
  - **108 existent en production** : le baseline est périmé, c'est un écart attendu ;
  - **3 commandes d'organisations** sont absentes en production et installées par les 95 : écart attendu avant installation, résolu après ;
  - **4 RPC d'équipements collectifs** (`organisation_equipement_acheter`, `_deplacer`, `organisation_equipements_etat`, `_payeurs`) sont absentes en production **et hors des 95**. Leurs migrations (113558 / 113559) sont des préparations non appliquées : la fonctionnalité est dormante. L'écran l'annonce sans repli silencieux ni mouvement d'argent (« Équipements indisponibles », refus nommé à l'achat). Écart réel qui subsiste après installation ; le raccordement est à décider.
- **Invariant 12, 5 signatures « inconnues »** : les 4 signatures existent exactement en production (baseline périmé). Deux migrations de `main` déjà appliquées (`election_contester`, `fermer_recompense_quete_ancienne`, corps normalisé identique au registre) sont **déplacées dans `historique/migrations-appliquees/`** par cette PR, conformément au processus : il reste 1 écart. `fontaine_exclusivite_sur_place` reste en place, car son fichier diffère du SQL appliqué et un banc le lit.
- **Invariant 3, `resilier_bail_volontaire`** : la production a la version corrigée du 13/10 à 17 h 42, qui vérifie l'acteur via `acteur_est_moi`. Le baseline date de 17 h 41 : baseline périmé.

Le remède unique et propre est la **réextraction du baseline après installation des 95** (processus, étape 5 : les quatre requêtes de `requetes.py`, jouées par ChatGPT et rendues privées). Ne pas réécrire les contrôles ni annoncer 12/12 avant.

**Referential** : pas jouable ici (JavaScriptCore absent). Il exige les contenus des référentiels statiques (requête `referentiels` de `DEMANDE-PREVOL-ACTUALISE-219`).

## Plan de livraison définitif

1. **Codex (décor)** : décor privé 1003 + les 10 fichiers du delta de `main`, dans l'ordre du registre (`DELTA-1012-CERTIFIE.json`), en sessions séparées. Puis `empreinte-catalogue-racine.sql` en local et `comparer-empreinte-catalogue.py`. **Exiger CONFORME.** En cas de seau discordant, jouer `empreinte-catalogue-detail.sql` des deux côtés (côté production par ChatGPT ou Claude).
2. **Codex (`--delta-candidat`)** : comparer les corps normalisés (sans commentaires) ; les cinq contrats financiers concorderont.
3. **Codex (paquet)** : installation atomique des 95 sur le décor certifié, rollback tardif, suites (groupes, organisations, HTTP).
4. **Intégration #219 → main** : ne garder dans `migrations/` que les 95 et les migrations réellement en attente. Écarter les 56 copies appliquées et les 2 copies #299. Résoudre le workflow comme déjà indiqué par Codex.
5. **Production (ChatGPT)**, après Vercel READY du client fusionné : prévol (gardes des 95 sur fonctions vivantes, déjà concordantes au 31/10 à 23 h ; à rejouer juste avant), puis les 95 en une transaction, et la racine d'empreinte avant/après.
6. Ensuite seulement : étape A des organisations (`20261031230000`, feu vert), puis réextraction du baseline et contrôles globaux.
