# Carrières sans métier et personnages mineurs

Décisions de Fred du 20/11/2026. Migration `migrations/20261120230000_mineurs_carrieres_garde_fous.sql`.

## Deux carrières de plus à la création

| Carrière | Pécule | Bonus de caractéristique | Compétences | Blocage d'études | Effet |
|---|---|---|---|---|---|
| **Enfant / Adolescent** (`minor`) | 50 (monnaie du pays, comme les autres bonus) | aucun | aucune (« argent de poche ») | aucun | personnage **mineur**, pour toujours |
| **Sans expérience professionnelle** (`sans_experience`) | 100 (monnaie du pays) | aucun | aucune | aucun | personnage adulte ordinaire |

- Les deux carrières n'ont aucune mission de carrière ni habilitation.
- Le conseiller de création (`api/conseiller-creation.js`) peut proposer « Sans expérience ». Il ne propose **jamais** « Enfant / Adolescent » : on la choisit soi-même.
- Les anciennes fiches ne bougent pas, car `migrerCareerId` ne touche que les anciens identifiants.

## Le statut de mineur

- La colonne serveur `personnages_donnees.est_mineur` est posée à la création quand la carrière est `minor`.
- Le déclencheur `personnages_mineur_verrou` la rend **permanente**. Ni le joueur ni une fonction serveur ne peut la retirer. La carrière d'un mineur est figée, et un adulte ne peut pas devenir mineur après coup.
- Un mineur ne peut avoir **aucune autre carrière** :
  - pas de seconde carrière (déclencheur sur `carrieres_acquises`) ;
  - pas de cursus universitaire, ni de stage, puisque les stages en font partie : `universite_inscrire` et un déclencheur sur `universite_inscriptions` refusent ;
  - `mes_carrieres` répond `seconde_carriere_disponible: false` et `mineur: true`.

## Garde-fous, dans les deux sens

Le mineur ne peut pas agir, et personne ne peut agir sur lui. Tout passe par un seul contrôle, `mineur_refus_interne(acteur, cibles, motif)`. Il rend un refus **neutre**, `action_non_disponible` (« Cette action n'est pas disponible. »), le même que le mineur soit l'acteur ou la cible. L'écran l'affiche depuis un point d'écoute unique (`sbTransportRpc` → `rpActionNonDisponible`).

- **Escorts.** Les points bloqués :
  - le recrutement à l'agence ;
  - l'accompagnatrice sociale ;
  - le standard Roxane Velours (résidences de Novomirsk et cliniques privées : devis, validation, « Faire l'amour ») ;
  - le débauchage d'une escort.

  La carrière « Prostitué(e) » est inaccessible, comme toute autre carrière.
- **Séduction.** Le jeu n'a pas d'ordre « séduire » : la séduction passe par les escorts (bloquées) et par le dialogue libre avec les PNJ. `pnj_contexte_public` transmet `mineur: true` au dialogue. La consigne `blocMineurInterlocuteur` (`api/_pnj-profils.js`) interdit alors au PNJ toute séduction et tout ton romantique ou sexuel. Elle lui interdit aussi de proposer de l'alcool, de la drogue ou une escort.
- **Kompromat à caractère intime.** La « rencontre piège » (`escort_piege_tenter`) est refusée si l'auteur **ou la cible** est mineur.
- **Alcool** (recettes `boisson = 'alcoolisee'`). Les points bloqués :
  - les verres au bar et dans les commerces (`consommer_sur_place_commerce`, `acheter_produit_commerce_interne`, ce qui couvre aussi les bouteilles et spiritueux des distilleries) ;
  - la buvette du stade ;
  - les tournées : on ne peut ni offrir une tournée alcoolisée à un mineur, ni en accepter une si l'on est mineur ;
  - les dîners avec alcool (restaurant de Luthecia, dîners en commerce) ;
  - le service d'étage ;
  - le mini-bar de la résidence ;
  - trinquer avec l'habitant (Sovarka) ;
  - boire une boisson alcoolisée de l'inventaire.

  Les PNJ ne vendent rien de tout cela à un mineur.
- **Drogue.** Sont bloqués : les dealers, le GHB du marché noir et la consommation de drogue depuis l'inventaire.

## Signalement des messages

- Le bouton « Signaler » (drapeau) est présent :
  - sur le courrier reçu ;
  - sur les messages du forum ;
  - sur les messages des conversations (privées et salons) ;

  mais jamais sur ses propres messages. Le motif est libre (500 caractères).
- Le serveur (`message_signaler`) relit le message et vérifie que le joueur y a accès : destinataire du courrier, participant de la conversation, ou lecteur pour le forum. Il conserve un extrait et note l'auteur réel (même pour un message signé par une organisation ou envoyé en secret) ainsi que les destinataires.
- La file du MJ est dans admin.html, bloc « Signalements de messages » :
  - les signalements ouverts d'abord ;
  - en tête, ceux qui **impliquent un personnage mineur** (auteur ou destinataire), marqués « [MINEUR] » ;
  - puis les plus anciens.

  Le MJ peut marquer un signalement traité, le rejeter ou le rouvrir.

## Charte

« Tout contenu sexuel ou suggestif impliquant un personnage mineur, en message, en forum ou en RP, entraîne un bannissement définitif, sans avertissement. » La règle sera intégrée à la charte à rédiger avant le 19/12 (voir RELAIS).
