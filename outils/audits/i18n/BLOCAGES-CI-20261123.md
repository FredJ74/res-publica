# Contrôle général : six échecs préexistants sur main

Témoin distant **main 14d0716e**, exécution **45222382938** : **449/455 bancs réussis, six échecs** (étape « Bancs JavaScript, transports simulés »). Les premiers blocages sur d0f0e127 ont été corrigés par Claude ; le présent relevé remplace ce diagnostic initial.

| Banc | Échec observé sur main | Traitement dans cette mission |
|---|---|---|
| `banc-cycle-plaintes.js` | « le Ministre ne garde que la nomination du Procureur » | Non modifié : décisions/registre de postes du chantier parallèle. |
| `banc-groupes-bataille-client.cjs` | Attend encore le lien « Rapports de combat » | Non modifié : journal réservé à Claude. |
| `banc-mobile-certification.cjs` | Pixels du plateau bureau différents du témoin | Non modifié : panneau de gauche/journal/navigation réservés à Claude ; aucune tolérance ajoutée. |
| `banc-nominations-municipales.cjs` | Comparaison des libellés avec/sans accents | Non modifié : registre/organigramme du chantier parallèle ; français du lot conservé. |
| `banc-parquet-client.js` | « il est déclaré au référentiel des postes nommés » | Non modifié : référentiel de postes du chantier parallèle. |
| `banc-sorties-batiments.cjs` | Deux assertions de sortie/double clic | Non modifié : navigation commune du chantier parallèle. |

Les empreintes des six bancs et de leurs fichiers communs sont dans `COMPARAISON-MAIN-20261123.json` : identiques à main sur les deux branches. Les catalogues et modules modifiés par Codex ne sont pas ceux qui produisent ces différences. Aucun test n’est assoupli pour forcer une fusion.

Les CI dédiées passent : formation **45223825553**, saisie **45223911116**. Les parcours supplémentaires locaux vérifient la vraie fonction `showToast` et les catalogues communs (81 bascules sans rejeu), ainsi que les écrans 320×568 et 390×568 (neuf langues, fermeture après défilement, aucun débordement horizontal ni RPC supplémentaire). Scripts reproductibles dans ce dossier ; aucun personnage connecté ni téléphone physique testé.

**Fusion et déploiement retenus tant que la CI générale reste rouge.** Corriger ces six écarts appartient au chantier qui modifie ces zones. Après rétablissement : fetch/rebase des deux branches, conserver main dans les zones interdites, régénérer Brotli si nécessaire, relancer les contrôles puis fusionner et vérifier Vercel/public. Aucune écriture en base n’est nécessaire ni autorisée ici.

Production observée : Vercel READY sur **14d0716e**, déploiement **dpl_E2rUtNMfgsgqknvZyXhGKJktCK7B**. Les deux lots ne sont pas inclus. Aucun aperçu de branche trouvé. Le script de vérification publique est préparé mais n’a pas été exécuté contre un déploiement des lots, puisqu’ils ne sont pas fusionnés.

## Comparaison complète des trois exécutions

| Périmètre | Commit testé | Exécution | Résultat |
|---|---|---|---|
| main | 14d0716e | 45222382938 | 449/455, les six échecs ci-dessus |
| PR #1183 | 80b89c03 | 45223825981 | 450/456, exactement les mêmes six échecs |
| PR #1184 | 82b05288 | 45223911404 | 450/456, exactement les mêmes six échecs |

Aucun échec supplémentaire observé dans les deux lots. Tous les autres contrôles PR sont verts : 10 pour #1183, 11 pour #1184. Les commits documentaires ultérieurs ne modifient pas le code testé ; leurs nouvelles exécutions restent visibles dans les PR et ne constituent pas une autorisation de contourner les six échecs communs.
