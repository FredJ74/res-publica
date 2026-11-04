# Test de duplication du socle : navigation de Novomirsk (Sovarka), 04/11/2026

Demande de Fred (04/11/2026, 19 h 26) : raccorder les bâtiments de la capitale de Sovarka vue
par vue, pour éprouver la duplication des couches du socle. Cette demande vaut exception
explicite à la feuille de route (« aucun travail sur un autre empire avant l'internationalisation »,
`ARCHITECTURE.md`) : c'est un test, pas l'ouverture de Sovarka aux joueurs.

## Les couches d'une ville navigable

| Couche | Où | État à Novomirsk avant le test |
|---|---|---|
| Vues de rue (images, flèches, zones cliquables) | `plateau-rue-centrale.js`, `RUE_CENTRALE_NOEUDS.soviet` | 18 vues, 34 zones (17 raccordées, 17 « à venir ») |
| Graphe de rue au serveur | `rue_noeuds_serveur` | **0 nœud** : aucun déplacement de rue n'était possible |
| Entrées / sorties des bâtiments | `rue_sorties_batiments` | **0 ligne** : aucun bâtiment n'était accessible depuis la rue |
| Pièces autorisées par bâtiment | `navigation_lieux_regles` (générée de `data.js`) | présente pour les 28 bâtiments de `WORLD.soviet.capitale` |
| Plan de ville | `PLAN_VILLES` / `PLAN_LAYOUTS` (`plateau-navigation.js`) | emprunte encore le plan de Luthécia (clé `capitale` sans pays) |

**Constat 1 — la couche rue n'était pas dupliquée au serveur.** Les migrations de directions du
31/10 contenaient déjà des `UPDATE` pour les nœuds de Novomirsk, sans effet faute de lignes.

**Correctif (04/11)** : générateur générique `outils/generateurs/rue-ville-serveur.cjs
<pays> <ville> <préfixe>` qui produit nœuds et entrées depuis les vues déclarées (rien d'inventé ;
`--verifier` contrôle la fidélité). Migration `20261104184000_novomirsk_rue_serveur` **appliquée**
(registre `novomirsk_rue_serveur_20261104184000`) : 18 nœuds, 17 entrées (16 bâtiments, deux
entrées pour le Grand Hôtel). Banc annulé `outils/bancs/banc-novomirsk-rue-serveur.sql` vert avant
application (trajet fléché accepté, trajet sans flèche refusé, sortie par une entrée réelle
acceptée, sortie ailleurs refusée).

**Constat 2 — bâtiments de la ville sans aucune entrée de rue** (donc inaccessibles, même par le
plan, puisque l'entrée exige d'être devant) : `palais-presidentiel`, `assemblee`,
`banque-nationale`, `banque-privee`, `loge-maconnique`, `universite`, `mairie-capitale`,
`terrain-a-batir-1/4/5/6/7`. Aucune vue ne les montre.

**Constat 3 — le plan de Novomirsk est celui de Luthécia** (déjà connu, « lot 4 » du cadastre).

## Zones « à venir », vue par vue, et homologue possible dans Républia

| Vue | Zone | Homologue existant (piste, à valider) |
|---|---|---|
| V1 | Librairie du Peuple | `imprimerie-librairie` (PSM) |
| V2 | Restaurant La Mère Volga | `capitaine-sauvage` (PSM), `brasserie-voyageurs-montrouge` |
| V2 | Musée municipal de Novomirsk | `musee-ville-luthecia` |
| V6 | Palais des Ambassades | `quartier-ambassades` |
| V7 | Pavillon des Ambassadeurs | aucun |
| V7 | Résidence impériale | `palais-presidentiel` ? |
| V8 | Entrepôt logistique | `entrepot-logistique-luthecia` |
| V8 | Direction du Renseignement | aucun |
| V11, V12 | Caserne centrale | `caserne-militaire` (zone spéciale « caserne », hors de la ville) |
| V11 | Garage | aucun |
| V12 | Salon de coiffure | aucun |
| V14 | Logements | `logements-montrouge` |
| V14 | Pharmacie officielle | aucun |
| V16 | Marchande de poissons | aucun |
| V18 | Usine pharmaceutique Pharmanov | `usine-pharmaceutique-luthecia` |
| V18 | Musée de la République de Sovarka | `musee-national-republia` |

Raccordement fait à mesure des décisions de Fred ; chaque bâtiment raccordé est consigné ici.
