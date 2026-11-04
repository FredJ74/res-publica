# Novomirsk (capitale de Sovarka) — raccordement des bâtiments

Chantier lancé par Fred le 04/11/2026 : raccorder les bâtiments de Novomirsk **vue par vue**
dans la navigation de rue, pour tester la duplication des couches du socle sur un autre empire
(écart volontaire et décidé par Fred avec la feuille de route d'`ARCHITECTURE.md`, qui plaçait
les autres empires après l'internationalisation).

Point de départ (04/11/2026) : 18 vues, 34 zones cliquables, 17 raccordées (16 bâtiments, le
Grand Hôtel ayant deux entrées), 17 marquées « à venir ».

## Décisions de Fred

| Date | Vue | Zone | Décision |
|---|---|---|---|
| 04/11/2026 | V1 Place du Peuple | Librairie du Peuple | Copie de l'Imprimerie-Librairie Gutenberg de Port-Sainte-Marie (tracts électoraux à l'accueil ; tracts calomnieux et vente de bois à l'atelier). Libraire propre à Novomirsk : **Ludmila Pamphletova** (nom choisi par Fred). L'ouvrier typographe reste anonyme, comme à PSM. |
| 04/11/2026 | V1 Place du Peuple | Palais du Gouvernement | **Pas réellement raccordé** malgré sa zone cliquable (constat de Fred). Gros morceau : gardé pour la fin du tour. |
| 04/11/2026 | V2 | Restaurant La Mère Volga | Copie du Capitaine Sauvage de PSM ; la carte sera retravaillée plus tard. Serveuse propre à Novomirsk : **Tatiana Bortchova** (nom choisi par Fred). |

**Méthode (Fred, 04/11/2026)** : d'abord l'interface intérieure de chaque bâtiment, avec ses
différentes pièces ; Fred générera ensuite les images avec ChatGPT. En attendant, un bâtiment
copié porte `imagesAVenir: true` dans son `buildingContext` : ses pièces s'affichent sur leur
fond, sans emprunter les images de la ville d'origine.

## Couches à dupliquer pour un bâtiment existant du gabarit

Relevé sur la Librairie du Peuple (migration `20261104203000_novomirsk_librairie_peuple`) :

- **Écran** : `data.js` (liste `buildings` de la ville ; `buildingContext` : nom, description,
  PNJ locaux), `plateau-rue-centrale.js` (zone de la vue passée de `a-venir` à `batiment`),
  version `?v=` des scripts dans `plateau.html` et `index.html`.
- **Serveur** : `batiments_etat` (état propre à la ville, identifiant `<pays>_<ville>_<bâtiment>`,
  colonnes `country`, `city`, `building_id` obligatoires), `navigation_lieux_regles` (pièces
  autorisées), `rue_sorties_batiments` (entrée depuis la vue). Un commerce (`commerces_types`,
  `commerces_dotations`, indexés par bâtiment et pièce, sans pays) n'a rien à semer : le serveur
  crée l'entreprise de la ville au premier accès. Pas de `blocus_ordres_batiments`
  ni de `pnj_lieux_metiers` hors Républia (ces deux tables ne couvrent que Républia).
- **Générés** : `api/_pnj-scenes-generes.js` (`generer-pnj-lieux-metiers.cjs --scenes-js`),
  fiche minimale du PNJ dans `api/_pnj-personnalites.js` ; le bâtiment est exclu de la
  génération historique de `navigation-lieux.cjs`, comme les ajouts de Montrouge et de PSM.

## Limites connues

- Aucune image d'intérieur n'existe pour Sovarka : pièces sur fond uni (`imagesAVenir`) en
  attendant les images de Fred.
- Pas de titre de murs pour les commerces de Sovarka (aucun commerce hors Républia n'en a) :
  la mécanique murs/fonds ne s'y applique pas encore.
- Le plan de Novomirsk emprunte encore celui de Luthécia : les bâtiments raccordés n'y sont pas
  dessinés tant que la ville n'a pas son propre cadastre.
- Plusieurs noms anciens du `buildingContext` de Novomirsk ne correspondent pas aux noms des
  zones de rue (ex. « Distribution Collective » pour le Marché) ; à harmoniser vue par vue.
