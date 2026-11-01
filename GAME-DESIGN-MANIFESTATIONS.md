# Manifestation spontanée — règles décidées par Fred (1er novembre 2026)

Ordre commun aux places des villes : Place du Formulaire de la Liberté (Luthécia),
Place d'Armes (Port-Sainte-Marie), Place du Rail (Montrouge).

## Règles (décision explicite de Fred, 1er novembre 2026)

- Il faut un **groupe d'au moins 10 PJ**. Seul le **chef du groupe** passe l'ordre.
- **Pas de déclaration préalable**, mais la manifestation peut être réprimée par la police :
  chaque PJ du groupe devient **temporairement hors-la-loi**.
- **Une seule manifestation spontanée par jour et par ville**, quel que soit le PJ.
- Une manifestation officielle le même jour **ne la bloque pas** (réponse de Fred : « pas de blocage »).
- Le chef choisit **« en faveur »** ou **« hostile »** et une **cible**, comme pour les tracts.
- Effet **immédiat au clic** : +1 POP (en faveur) ou -1 POP (hostile) à la cible **par participant**,
  sans durée minimale.
- Durée **1 h au maximum** ; elle s'arrête dès que le **chef quitte le groupe**.
- À la fin, les participants **ne sont plus hors-la-loi** ; une **trace** de leur action demeure,
  pour les rumeurs.

## Choix d'application (Claude, délégués par Fred)

- Participants : le chef et les PJ de son groupe **présents avec lui sur la place** au moment du clic.
- Cible : un personnage joueur (seuls les PJ ont une POP enregistrée), de n'importe quel empire,
  soi-même compris. POP bornée entre 0 et 100.
- Coût : 1 PA pour le chef.
- Hors-la-loi : avis de recherche « manifestation spontanée » (délit mineur, barème ordinaire
  en cas d'interpellation : 2 jours, 500 FR). La police physiquement présente peut interpeller.
- Fin : à l'heure, ou dès que le groupe du chef est dissous (le chef le quitte ou le dernier
  membre part). Le départ d'un simple membre ne lève pas son avis avant la fin.
- La trace n'est jamais découverte la nuit (pas d'arrestation après coup) ; elle nourrit les
  rumeurs et les fuites.
- Annonce publique dans l'empire au lancement.

Code : `migrations/20261101121000_manifestation_spontanee.sql` (attend #219, groupes PJ),
`plateau-communication.js` (fenêtre et suivi), banc `outils/bancs/banc-manifestation-spontanee.sh`.
