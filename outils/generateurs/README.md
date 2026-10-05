# Générateurs — les miroirs de `data.js`

Huit générateurs, et **une seule doctrine** : une table qui n'est que le reflet
d'une déclaration de `data.js` ne se recopie pas à la main et ne se recopie pas
depuis la base. Elle se **régénère depuis sa source**.

Ils chargent le **vrai `data.js`** dans JavaScriptCore et capturent la table
telle que le jeu la lit. Pas une relecture approximative : la même donnée, lue
par le même moteur.

| Générateur | Table(s) miroir |
|---|---|
| `generer_ordres_couts.py` | `ordres_couts` — 405 coûts en PA et en argent |
| `generer_pa_bonus_differes.py` | `pa_bonus_differes` |
| `generer_postes_nommes.py` | `postes_nommes_regles` |
| `generer_postes_electifs.py` | `postes_electifs_regles` |
| `generer_clubs_football.py` | `clubs_football` |
| `generer_miroirs_entreprises.py` | `armureries_dotations`, `commerces_dotations`, `commerces_types`, `entreprises_constantes`, `entreprises_prix_rachat`, `recettes_commerce`, `recettes_production` |
| `generer_miroirs_chantiers.py` | `chantiers_besoins_jour`, `chantiers_paliers`, `entreprises_constantes` |
| `generer_edition_reelle.py` | l'édition du journal du jour |

La plupart offrent trois sorties : un résumé lisible, les `VALUES` SQL, et une
**empreinte** — c'est elle qui permet de détecter qu'un miroir a dérivé de sa
source.

## Pourquoi ils ont déménagé

Ils vivaient dans `.scratch/`, un répertoire de brouillon. Or le projet en
**dépend** : sans eux, une table miroir ne peut plus être reconstruite depuis sa
source, et il ne reste qu'à copier la base — ce qui fige la dérive au lieu de la
corriger. Le miroir des coûts d'ordre avait ainsi dérivé de **24 lignes mortes
et 19 ordres gratuits non déclarés**.

Un outil dont le projet dépend n'a pas sa place dans un brouillon. Déplacés au
chantier 2H.

## Ce qu'il reste à faire

Les faire écrire **directement** dans `baseline/seeds/95_a-regenerer/`. Onze
tables miroir sont aujourd'hui seedées par copie de la base, avec un
avertissement en en-tête de chaque fichier : la liste est dans
`baseline/DIFFERENCES-DELIBEREES.json`, bloc
`miroirs_de_data_js_seedes_par_copie`.

Le processus qui les encadre est dans `../../WORKFLOW-SUPABASE.md`.
