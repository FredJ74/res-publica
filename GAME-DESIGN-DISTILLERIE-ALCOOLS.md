# Économie de la distillerie et des alcools

Décisions de Fred du 20/11/2026. Migration `20261120340000_distilleries_alcools`.

## 1. Distilleries d'État

- **Les deux distilleries :**
  - Républia : le pôle Tabac & Alcools de Port-Sainte-Marie ;
  - Sovarka : la distillerie de Krasnov.
- Ce sont des usines d'État : jamais rentables, jamais à louer. Le local loué de la salle des ventes de Krasnov est retiré, ainsi que ses ordres « Demande de location » et « Ce commerce ».
- **Directeur :** un seul poste, `directeur_tabac_alcools`, nommé par le ministre `min_fin`. C'est le même poste partout ; seul l'intitulé local change :
  - Ministre des Finances en Républia ;
  - Ministre de l'Économie collective en Sovarka.
- **Titulaires PNJ :**
  - Fernand Cendrier en Républia ;
  - Anatoli Pokhmelkine en Sovarka.

## 2. Matières

| Clé | Libellé | Prix de base | Usage |
|---|---|---|---|
| `alcool` | Alcool pur | 14 | industriel : désinfectant (Luthécia, Pharmanov), contrebande, exports |
| `spiritueux` | Spiritueux | 14 | l'alcool à boire : bars, buvettes (référence générique unique en entrepôt) |
| `sucre` | Sucre | 5 (environ 2 à 3 PSK en Sovarka, avec le coefficient de prix du pays) | matière du circuit logistique |

- La clé historique `alcool` est conservée pour l'alcool pur : aucun usage industriel n'est cassé.
- Les œufs restent hors circuit.

## 3. Production

Mêmes rendements partout : 1 PA consomme 5 matières et produit 10 unités.

| Produit | Républia (PSM) | Sovarka (Krasnov) |
|---|---|---|
| Alcool pur | céréales, 55 FR le PA | fruits et légumes, 15 PSK le PA |
| Spiritueux | céréales, 55 FR le PA | fruits et légumes, 15 PSK le PA |
| Sucre | fruits et légumes, 50 FR le PA (salaire minimum) | fruits et légumes, 15 PSK le PA |

- **Production de nuit :**
  - Républia : `api/cron-minuit.js`, avec trois chaînes de plus à PSM. L'usine reçoit désormais aussi des fruits et légumes de l'entrepôt local.
  - Sovarka : `sovarka_production_passe`, qui lit `chaines_production_pays` et reprend donc les nouvelles chaînes sans autre modification.

## 4. Spiritueux de la maison

- À la salle des ventes de chaque distillerie, l'ordre « Spiritueux de la maison » vend une bouteille de collection :
  - Sovarka : vodka, slivovitz ou samogon ;
  - Républia : champagne, cognac ou pastis ;
  - El Estado : tequila (deux autres noms à fixer) ;
  - Al-Khalija : aucune.
- La bouteille a le même effet qu'un spiritueux. Elle sort du stock de spiritueux de la vente directe, au même prix (prix du directeur s'il en a fixé un).
- L'achat est refusé aux mineurs.
- La commande porte une clé d'unicité : un rejeu ne fait jamais payer deux fois.

## 5. Flux internationaux quotidiens (`commerce_contrats`)

| Origine | Destination | Matière | Quantité par jour |
|---|---|---|---|
| Républia | Al-Khalija | alcool pur | 50 |
| Républia | Al-Khalija | spiritueux | 50 |
| Sovarka | Al-Khalija | alcool pur | 50 |
| Sovarka | Al-Khalija | spiritueux | 50 |
| Républia | Sovarka | spiritueux | 50 (remplace l'ancien contrat d'alcool) |
| El Estado | Al-Khalija | fruits et légumes | 100 |
| Républia | Al-Khalija | fruits et légumes | 50 |

Al-Khalija interdit la production d'alcool mais en importe : c'est une parodie assumée.

## 6. Migration des stocks et des usages

- Le désinfectant reste fabriqué à partir de l'alcool pur.
- Les recettes de bar qui consommaient de l'alcool passent au spiritueux : `voyageurs_vodka`, `sever_vodka`, `vin_chaud_sovarka`.
- Les stocks d'alcool des commerces deviennent du spiritueux.
- Les entrepôts de Sovarka (environ 700 alcools, très au-dessus des besoins) sont partagés moitié alcool pur, moitié spiritueux.

## 7. Pénuries (outil du MJ)

L'outil se trouve dans la page d'administration, section « Pénuries ». Le MJ choisit :
- **Matière :** une matière du jeu.
- **Zone :** un pays, une ville ou tout le pays.
- **Intensité :** de 1 à 100 % de la production coupée.
- **Durée :** en jours, avec fin automatique ; vide jusqu'à la levée manuelle.
- **Destruction du stock :** optionnelle, en pourcentage du stock des entrepôts de la zone.
- **Annonce :** optionnelle, publiée dans le bandeau et dans le journal.

Ce que la pénurie coupe :
- les livraisons de la matière aux entrepôts de la Républia (nuit) ;
- la production locale de Sovarka (nuit) ;
- les chaînes qui fabriquent la matière : production des PJ (`produire_en_usine`, refus « penurie » quand la coupure est totale) et production de nuit dans les deux pays.

Plusieurs pénuries sur la même matière ne s'additionnent pas : la plus forte l'emporte. Chaque déclaration et chaque levée est journalisée (`admin_journal`).
