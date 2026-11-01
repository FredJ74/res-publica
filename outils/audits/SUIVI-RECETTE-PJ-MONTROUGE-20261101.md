# Registre des anomalies — visite PJ à Montrouge — 01/11/2026

**Suivi opérationnel lié à la PR #304.** Les signalements proviennent de la visite PJ ; les vérifications techniques indiquées ont été faites en lecture seule sur `main` et Supabase. **Aucune anomalie n'est considérée corrigée sur production sans preuve de déploiement et essai PJ.** Préserver les contenus spécifiques à chaque ville et réutiliser exclusivement le moteur commercial commun. Pas de changement des autres empires.

## M-01 — Brasserie des Voyageurs : parcours commercial non raccordé en jeu

- **Observé PJ :** établissement non reconnu comme commerce / accès au socle restauration inadéquat.
- **Constat technique :** `BUILDING_COMMERCE_TYPE['brasserie-voyageurs-montrouge']='brasserie'`; ordres de production, carte, gestion, approvisionnement dans `data.js`. Entreprise réelle `brasserie-republic-ville_b-brasserie-voyageurs-montrouge` de type `brasserie`, propriétaire PNJ, carte `carbonade_frites`, `plat_de_poisson`, `saucisse_puree`, historique de production/ventes ; prix de rachat configuré 120 000 FR.
- **À corriger/vérifier :** identification dans l'interface, consultation/commande, production, livraison de matières, caisse, propriété/rachat, gestion pour le propriétaire, messages de refus fondés sur le serveur, parcours PNJ/PJ.
- **Recette :** effectuer un parcours visiteur et un parcours propriétaire (test isolé), vérifier débit/crédit et persistance. Ne pas recréer d'entreprise.

## M-02 — Marché de Montrouge : mélange des catalogues et spécialité absente

- **Observé PJ :** « Faire des achats » affiche des articles de Luthécia ; carbonade-frites souhaitée par le designer absente.
- **Preuve Supabase :** `marche-republic-ville_b-marche` contient les cinq références de Montrouge (`casse_croute_cheminot`, `casquette_montrouge`, `carte_montrouge_place_rail`, `carte_montrouge_touristique`, `carte_montrouge_musee_rail`) **et huit références de Luthécia**. Le référentiel `commerces_dotations['marche']` expose la carte de Luthécia, tandis que `DOTATIONS_COMMERCE_PILOTE['marche']` différencie localement `ville_b` ; le rattrapage serveur additif réintroduit les références indésirables.
- **À corriger :** isoler les dotations serveur **par empire/ville et bâtiment**, nettoyer uniquement les références hors assortiment de la carte persistée de Montrouge, préserver caisse, stocks réels, paramètres utiles et historiques ; empêcher leur réintroduction. Ne rien altérer à Luthécia/PSM.
- **Carbonade-frites :** recette existante dans la brasserie (`RECETTES_ALIMENTAIRES.carbonade_frites`, type `brasserie` uniquement). Raccorder à la vente du **marché** selon le socle commun, avec représentation cohérente d'un plat/produit consommable (ne pas simplement contourner les gardes de type).
- **Recette :** recharger plusieurs fois le marché, tester achats et prix, comparer indépendamment les trois catalogues. Vérifier la persistance réelle et l'étanchéité PSM/Luthécia.

## M-03 — Café des Cheminots / Bar-Tabac : parcours commercial non raccordé en jeu et carte polluée

- **Observé PJ :** café non reconnu comme commerce, comme la brasserie.
- **Constat technique :** `BUILDING_COMMERCE_TYPE['cafe-tabac-cheminots-montrouge']='cafe'`; ordres communs présents ; entreprise `cafe-republic-ville_b-cafe-tabac-cheminots-montrouge` de type café, propriétaire PNJ ; prix rachat 180 000 FR.
- **Preuve Supabase :** carte réelle inclut `boeuf_bourguignon` (du Café de la Gare) **et** `sandwich_cheminots`, alors que `commerces_dotations['cafe-tabac-cheminots-montrouge']` déclare uniquement `sandwich_cheminots`, `cafe_boisson`, `jus_de_fruits`, `vin`, `biere_pression`.
- **À corriger :** supprimer de ce café la référence du Café de la Gare (sans supprimer ses stocks/historique/caisse), prévenir sa réintroduction, réparer reconnaissance, commandes, production, gestion, rachat et approvisionnements.
- **Recette :** carte conforme à la dotation spécifique ; aucun impact sur le Café de la Gare ni sur les autres villes ; essais visiteur/propriétaire avec écritures atomiques.

## M-04 — Décors de Montrouge : inventaire visuel

- **En cours de visite PJ :** surveiller les images manquantes, doublons, images provisoires et décors correspondant à la mauvaise pièce. Des défauts de bureau du commissaire, pièces du stade et zone de récolte avaient été évoqués dans l'audit précédent, **non revérifiés ici**.
- **À faire :** contrôle systématique bâtiment/pièce, liens d'assets et rendu réel ; documenter chaque défaut avec chemin et correction plutôt que conclure sur la présence d'un fichier seul.

## Critères de clôture

1. Les trois commerces/marchés doivent réutiliser les fonctions communes existantes ; aucune mécanique parallèle.
2. Les cartes et dotations sont strictement localisées ; aucune référence d'une autre ville ne réapparaît au rafraîchissement.
3. Achats, stocks, production, caisse, propriétaire et droits fonctionnent côté serveur, sans prix inventés ni débit client autonome.
4. Tests de non-régression sur Luthécia/PSM/Montrouge, et essais réels PJ clairement distingués des tests locaux.
5. Intégration dans une livraison groupée, en respectant les prérequis SQL et la limite Vercel.
6. Chaque point reste **OUVERT** jusqu'à preuve de correction, déploiement et recette.

Historique des signalements : commentaires PR #304, dont les relais techniques sur la brasserie, le marché et le café. Ce document fait office de liste de contrôle de la visite.

## M-05 — EHPAD : PNJ volontairement reportés

- **Décision du game designer, 01/11/2026 :** aucun PNJ à l'EHPAD de Montrouge pour le moment ; les créer ultérieurement **au moment de finaliser Républia**. Ne pas classer l'absence de PNJ comme anomalie bloquante de ce lot et ne pas en inventer maintenant.

## M-06 — Jardins ouvriers : lieu sans ordres ; game design en discussion

- **Observé PJ :** aucun ordre dans le bâtiment. **Confirmé dans `data.js`** : `BUILDINGS['jardins-ouvriers-montrouge'].rooms.salle.orders` est vide.
- **Propositions non encore validées :** récolter des fruits/légumes via `recolter_matiere` (contrôler le filtrage par lieu et les plafonds), donner une récolte via une transaction existante, discuter/écouter les rumeurs via ordres existants, consulter les parcelles. N'introduire aucun moteur de culture parallèle, aucune propriété parcellaire ou chronologie agricole sans décision.
- **Statut :** à arbitrer par le game designer AVANT toute implémentation. Ne pas traiter comme une fonctionnalité validée.

## Décision M-06 validée — Jardins ouvriers (01/11/2026)

- **Ordre :** « Travailler aux jardins » ; **1 PA** pour **5 légumes** crédités dans l'inventaire du PJ. **Production journalière limitée par PJ** (interprétation opérationnelle proposée : une fois par journée de Paris, donc 5 légumes/jour ; demander validation si un autre plafond était visé). Pas de paiement en FR.
- **PNJ à introduire :** ancien cheminot retraité, présent aux parcelles. Sa réplique explique qu'un joueur peut, s'il le souhaite, **laisser sur place une partie ou la totalité des légumes récoltés pour les personnes qui en ont besoin**. Nom et portrait non définis, ne pas les improviser comme décision validée.
- **Don :** choix libre, jamais automatique ; ne pas retirer de légumes de l'inventaire sans action explicite et sans un mécanisme sûr de dépôt/retrait côté serveur. Un simple texte du PNJ n'est pas une fonction de don : si une réserve partagée n'existe pas, la concevoir/reconnecter proprement, avec capacité, disponibilité et protections transactionnelles. Le don doit rendre les légumes effectivement accessibles aux autres PJ, et empêcher duplication/accès négatif.
- **Attention technique :** `recolte_effectuer` attribue actuellement 1–2 unités d'une ressource autorisée par ville et limite les récoltes ordinaires à 2/jour ; à Montrouge cette liste contient charbon/métal, **pas les légumes**. Ne pas raccorder aveuglément cet ordre ni affaiblir la vérification serveur des lieux. Les légumes doivent reprendre une référence d'inventaire existante vérifiée, sans inventer une matière parallèle.
- **Tests :** 1 PA exactement, +5 légumes exactement, plafond journalier confirmé côté serveur après rechargement, aucun effet sur récolte générale, inventaire plein, simultanéité/rejeu, don volontaire, stock redistribuable, aucun changement hors Montrouge.
- **Statut :** game design validé pour travail/quantité/don volontaire et concept PNJ ; implémentation et recette non vérifiées. Le plafond exact proposé à 1 action/jour est à confirmer si nécessaire.

### Complément PNJ jardins ouvriers — décision game design du 01/11/2026

**Le retraité cheminot doit également orienter le PJ vers le musée de Montrouge.** Il évoque fièrement l'histoire pionnière de la ville : **Montrouge a été la première à avoir un cinéma, des logements sociaux et des jardins ouvriers** (fait **canonique de l'univers du jeu** tel que fixé par le game designer ; ne pas présenter comme une affirmation historique réelle). Ce dialogue est additionnel à l'explication du don volontaire des légumes. Prévoir une invitation à visiter le musée de Montrouge, sans déplacement forcé ni nouvelle mécanique. Exemple de ton, à adapter au PNJ : « Vous savez, ici, on a toujours été en avance : Montrouge a eu le premier cinéma, les premiers logements sociaux et les premiers jardins ouvriers ! Vous devriez aller voir notre musée, ils racontent tout ça bien mieux que moi. Et si vous récoltez davantage de légumes que nécessaire, laissez-en pour ceux qui en ont besoin : c'est l'esprit du quartier. » Éviter d'inventer son nom, son portrait ou d'autres faits non validés.
