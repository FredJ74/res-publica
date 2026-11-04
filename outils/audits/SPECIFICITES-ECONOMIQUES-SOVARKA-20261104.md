# Spécificités économiques retrouvées — 4 novembre 2026

Recherche demandée par Fred pendant le raccordement de Novomirsk. Sources : fichiers actuels,
historique Git toutes branches, documents de conception et arbitrages du dépôt. La recherche
HTML des tickets « Sovarka » n'a livré aucun ticket exploitable ; l'API GitHub est refusée.
Cette note distingue les traces retrouvées d'un barème national complet, non retrouvé.

## Flux internationaux historiques

| Empire | Trace existante | Limite de ce qu'elle prouve |
|---|---|---|
| Sovarka | 150 unités de bois/jour reçues en Républia | C'est un volume d'exportation historique vers Républia, pas la production totale de Sovarka ni une dotation à Novomirsk |
| Sovarka | 1/3 du pétrole brut reçu par Républia | Origine déclarée ; le moteur historique ne prélève pas ce volume dans un stock sovarkien |
| Al-Khalija | 2/3 du pétrole brut reçu par Républia | Même limite : pas de production nationale totale chiffrée par cette proportion |
| El Estado | 100 % des produits exotiques importés par Républia | Origine déclarée, pas un panier initial de ses entrepôts |
| Républia | 150 bois/jour de la scierie Guy Tarembois, et exportations de céréales/viande vers Al-Khalija | Le flux intérieur de bois est distinct des 150 attribués à Sovarka |

**Source primaire du bois :** commit [`05adb9f6448c669b2103418c89db1367d7e5a0a6`](https://github.com/FredJ74/res-publica/commit/05adb9f6448c669b2103418c89db1367d7e5a0a6),
25 août 2026, « production nationale déterministe de bois (150 + 150/jour) ».
Il définit `BOIS_UNITES_PAR_VILLE_JOUR=100`, `BOIS_SCIERIE_JOUR=150`,
`BOIS_SOVARKA_JOUR=150` et une redistribution unique, sans changer l'abondance des autres matières.
Ces constantes sont toujours dans `api/cron-minuit.js` ; les origines du pétrole et des
produits exotiques sont dans `ORIGINE_IMPORTS_PORT` du même fichier.

**Source de la logistique :** commit [`31147354`](https://github.com/FredJ74/res-publica/commit/31147354),
25 août 2026 ; `EMBARGO_FLUX_CONNUS` dans `plateau-gouvernement.js`. Ce dernier précise même que
les fractions du pétrole ne constituent pas un prélèvement attribuable sur une production
étrangère réelle. Ne pas transformer ces commentaires en nouveaux stocks.

## Matières locales de Sovarka

`MATIERES_PREMIERES_VILLE.soviet`, dans `plateau-justice-economie.js`, déclare :

- `ville_a` : minerai de fer et charbon ; nom actuel **Starovka**, selon `VILLES`.
- `ville_b` : blé et cuir ; nom actuel **Krasnov**, selon `VILLES`.
- Aucune matière brute déclarée pour `capitale` (Novomirsk) : les capitales y sont décrites comme lieux de transformation.

Les commentaires anciens parlent encore de Sibirsk-9/Kolkhoz-7 ; ce ne sont pas deux autres
villes à créer. Les identifiants `ville_a`/`ville_b` n'ont pas changé. Le tableau a été ajouté
par le commit [`ac3dbd8a`](https://github.com/FredJ74/res-publica/commit/ac3dbd8a), 9 juillet 2026.
Aucune quantité nationale ou règle de livraison à l'entrepôt de Novomirsk n'en découle.

## Ce qui reste indéterminé

Aucun barème complet retrouvé pour le stock initial, le panier de réapprovisionnement,
les volumes quotidiens, les lieux de production du bois en Sovarka ou la dotation financière
de son entrepôt. La note fiscale ancienne évoque des prix « fixes par décret » comme exemple
à traiter ultérieurement, sans procédure ni barème : ce n'est pas une exception implémentable.

`baseline/DIFFERENCES-DELIBEREES.json`, décision `8_dotations_de_matieres_premieres`, valide
les 17 stocks initiaux **pour les trois villes de Républia**. Ce texte n'autorise pas de les
recopier en Sovarka. `baseline/arbitrages/AUDIT-EMPIRES-4G.md` rappelle explicitement :
absence de configuration ≠ repli sur Républia.

**Conséquence sur le lot préparé :** économie locale par achats et offres existants, caisse et
stocks initialement vides s'ils n'existent pas déjà ; aucun nouveau réapprovisionnement
artificiel, aucune ouverture internationale. Les flux historiques républiens sont préservés.
La reprise de l'approvisionnement automatique de Novomirsk attend donc des instructions plus
complètes retrouvées ou un arbitrage sur ce seul paramétrage.
