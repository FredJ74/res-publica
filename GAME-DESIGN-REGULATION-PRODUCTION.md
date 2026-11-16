# Régulation de la production — décisions de Fred (16/11/2026, nuit)

Contexte : au champ de pétrole de Starovka, « Récolter » est limité à 2 fois par jour (règle du gabarit
`zone-production`, commune à toutes les villes). Fred veut pousser les joueurs à se déplacer.

## Décisions

1. **Plus de plafond fixe** de récoltes par jour dans les zones de production ; le coût en PA reste le frein.
2. **La limitation devient un pouvoir municipal**, dans **toutes les villes de tous les empires** (socle) :
   c'est une forme de régulation de la production.
3. **Ordre « Régulation de la production »** (adjoint au maire), avec la **liste des productions de la
   ville à réguler**.
4. **L'ordre revient à l'adjoint au maire seul** : chacun son pré carré ; le maire nomme l'adjoint et
   peut le remplacer en cas de désaccord.
5. **Deux limites possibles, cumulables**, réglées par ressource : un maximum de récoltes **par joueur
   et par jour**, et/ou un **plafond total de la ville par jour** (premiers arrivés, premiers servis).
6. **Pas de durée fixe** : une régulation est un acte volontaire, elle reste en vigueur jusqu'à ce que
   l'adjoint la change ou la lève (acte volontaire lui aussi).
7. **Pas d'ordre de sommation** : le ministre de l'Économie peut exiger une régulation, mais cela se
   traite en RP (forums), pas par un bouton ; Fred ne veut pas un bouton par interaction possible.
   Il n'a pas les commandes.
8. **Récolte à 1 PA** (au lieu de 2), quantité récoltée relevée pour que produire vaille la peine
   (PA minimum en Républia : 50 FR). Exemple validé par Fred : **poisson en Républia = 10 par PA**.
   Quantités fixes par PA validées par Fred (16/11) : poisson 10 (PSM), charbon 6 et métal 3 (Montrouge),
   pétrole 4 (Starovka), bois 6 (Krasnov ; forêt profonde doublée : 12).
9. **Prix des matières en Sovarka = moitié des prix de Républia** (règle de Fred, rappelée le 16/11 ;
   pas encore codée : un seul tableau de prix `ressources_economie`, mêmes chiffres en FR et PSK).
   S'applique à **toutes les matières premières** de Sovarka (entrepôts, usines, trading).
   Pétrole de Starovka à 4 PSK, donc **4 unités par PA** (16 PSK pour un PA à 15 PSK).

## À vérifier avant de coder (Claude)

- Sans plafond, la récolte ne doit pas devenir une planche à billets : relever ce qui freine déjà (prix
  de rachat, caisse et stock maximum des entrepôts) et proposer un réglage si nécessaire.

## Questions encore ouvertes

- Moyens de coercition des ministres sur les élus locaux (sujet plus large, à traiter plus tard).

## Idée notée au passage

- **Créer une ferme en Républia** (Fred, 16/11/2026) : chantier à part, à décider plus tard.

## Codé le 16/11/2026 (feu vert de Fred, nuit)

- Migration `20261116020000_regulation_production_recolte` (appliquée) : `recolte_effectuer` (1 PA, quantité
  fixe par `recolte_quantite_par_pa`, plus de limite de 2/jour), forêt profonde (1 PA, 12 bois), tables
  `production_regulations` / `production_recoltes_jour`, RPC `regulation_production_lire` / `_fixer`
  (adjoint attesté, dans la mairie de sa ville, 1 PA ; deux champs vides = levée ; 0 = interdiction).
- Prix : `coef_prix_matieres` (Sovarka 0,5) et `ressources_economie_pays(pays)` raccordés aux entrepôts,
  usines (rachat et vente directe), trading (cours, achats, fournisseurs étrangers), commandes des
  directeurs, commerces et fonds, chantiers, passes et exportations de Sovarka. Importations de Sovarka :
  payées au prix du pays d'origine (pas de taux de change).
- Écran : `plateau-regulation-production.js`, catalogue `i18n/regulation-production-resources.js`.

## Points relevés pour Fred

- **Port-Sainte-Marie n'a pas de lieu de pêche** : la zone de production de PSM est la Scierie Guy
  Tarembois, où « Récolter » est masqué depuis août. Le poisson à 10 par PA ne s'applique donc nulle
  part tant qu'un lieu de pêche n'existe pas (où ? le port, la criée ?).
- Les importations de Sovarka (médicaments, alcool, plantes, tabac) restent payées au prix du pays
  d'origine alors que Sovarka revend à moitié prix : les entrepôts de Sovarka perdent sur ces produits
  s'ils ne fixent pas un prix manuel. À surveiller lors de l'audit transversal des prix.
