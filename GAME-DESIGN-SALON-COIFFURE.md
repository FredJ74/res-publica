# Salon de coiffure — décisions de Fred (06/11/2026), issue #490

Nouveauté du tour de Novomirsk (vue 12). Le principe n'avait été consigné nulle part
(ni issue, ni document : recherche du 06/11) ; Fred l'a redonné le 06/11/2026.

## Règles décidées

| Sujet | Décision |
|---|---|
| Nature | Un **commerce** qui vend des **services**, et éventuellement des **accessoires non alimentaires**. |
| La coupe de cheveux | **+5 POP** et **CHA +1 jusqu'à minuit**, **sans cumul**. |
| Fréquence | **Une coupe tous les 3 jours** (jours de jeu) ; avant ce délai, la coupe est refusée (« Vos cheveux n'ont pas encore repoussé »). |
| Accessoires | **Définis par le PJ coiffeur**, avec la **mécanique générale du commerce** : familles du catalogue (« Coiffure & esthétique »…) et nombre de références selon l'option gratuite ou premium. Rien de spécifique au salon. |
| Relooking | Prestation **premium** : l'IA génère une **image temporaire** du personnage, durée fonction du prix (à définir), **aucun bonus**, purement cosmétique. Session premium à venir : non codé. |
| Salon de Novomirsk | **Tenu par un PNJ**, **Ludmila Permanentova** (nom validé), **le local pourra être racheté par un PJ**. |
| Prix | **Aucun pour l'instant** : la logique de prix de Sovarka sera très différente et reste à décider (coupe et prix de rachat). |

## Implémentation (Claude, 06/11/2026)

- Migration `20261106001000_salon_coiffure_novomirsk` (registre `salon_coiffure_novomirsk_20261106001000`) :
  table `salon_coupes` (dernière coupe, jour de jeu, sans accès client), porte `salon_coupe(requete, entreprise)`
  et lecture `salon_lire()`. Le bonus de CHA réutilise les **effets actifs** (clé `coupe_cha`, même
  mécanique que la Brume) ; la POP passe par `jauges_effet_appliquer_interne` ; l'encaissement par le
  moteur commun des prestations (taxe locale, caisse du salon, journal).
- Générique : toute entreprise qui déclare `data.prestations.coupe` vend la coupe, au prix
  `data.prestations.coupe.prixVente`. Sans prix, refus `prix_non_fixe` avant tout débit.
- Salon PNJ `salon-soviet-capitale` (bâtiment `salon-coiffure-novomirsk`, pièce `salon_coiffure`), entrée
  depuis `novomirsk-vue-12`. Écran : `plateau-salon.js` ; l'ordre est « Bientôt disponible » tant que le
  prix n'est pas fixé.
- Banc annulé : `outils/bancs/banc-salon-coiffure.sql` (vert le 06/11).

## Reste à faire

- **Prix de Sovarka** (coupe, rachat du local) : à décider par Fred, puis poser `prestations.coupe.prixVente`,
  retirer `bientot` de l'ordre, ajouter le prix de rachat (`entreprises_prix_rachat` et
  `PRIX_RACHAT_COMMERCE`).
- **Salon d'un PJ** : vendre la coupe depuis un fonds de commerce de PJ (déclarer la prestation sur son
  fonds) reste à raccorder ; les accessoires passent déjà par la mécanique générale des fonds.
- **Relooking premium** : backlog, issue #491, avec la session premium.
- Images du salon : à générer par Fred.
