# Socle transversal — consommation des aliments à emporter

**Décision de game design :** la consommation d'un produit alimentaire est indépendante du fabricant, de la marque, du commerce, du propriétaire et de la ville. Aucun cas particulier pour la chocolaterie d'Angie.

## Contrat commun

- Toute référence commerciale appartenant à la famille alimentaire et vendue à emporter produit un objet d'inventaire reconnu comme consommable.
- La reconnaissance doit être établie à partir de la catégorie/référence fiable de l'objet, jamais à partir de son nom, du nom du fabricant ou d'une liste codée en dur de chocolats.
- Le serveur inscrit un horodatage d'acquisition fiable sur chaque unité achetée. La date ne doit pas pouvoir être inventée par le client.
- Le bouton « Consommer » apparaît dans l'inventaire pour tout objet alimentaire éligible.
- L'action vérifie la propriété, retire exactement une unité et applique l'effet en PA dans une seule transaction serveur ; protection contre double-clic et requêtes concurrentes.
- Respect des règles de fraîcheur existantes (7 jours, +1 PA frais, −1 PA périmé), sans afficher la fraîcheur avant consommation.
- Les produits déjà achetés doivent être migrés de manière sûre : reconstituer leur classification et leur horodatage depuis une source fiable. Si la date historique n'est pas retrouvable, ne pas inventer une date récente ; définir un traitement explicite avant activation.
- Tester plusieurs commerces PJ et plusieurs références alimentaires, ainsi que les produits PNJ existants, les lots empilables et les refus sur objets non alimentaires.

## Diagnostic constaté le 14 octobre 2026

Un chocolat acheté à emporter possède `generique_id='encas-a-emporter'` et `recette_id='chocolat_generique'`, mais n'a ni `familleProduitMarche='aliment'` ni `dateAchat`. Le bouton du client `ouvrirDetailObjetInventaire` et la RPC `inventaire_consommer` exigent le marqueur `aliment`. Le problème est transversal au mécanisme d'achat/inventaire.

**Statut : arbitrage enregistré, correctif générique à implémenter et tester ; ne pas considérer le chantier livré.**
