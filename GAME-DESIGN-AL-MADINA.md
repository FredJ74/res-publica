# Al Madina, capitale d'Al-Khalija — teaser (décisions de Fred, 28/11/2026)

> **Principe de contraste (Fred, 28/11/2026), qui guide tous les ajouts futurs dans ces empires.**
> **Al-Khalija revendique une morale irréprochable mais s'arrange en douce avec elle** (le whisky dans la théière, le
> passage forcé contre un jour de chambre). El Estado est un empire complètement décadent et corrompu, où l'on est
> pourtant très pieux. Voir aussi `GAME-DESIGN-CIUDAD-ROJA.md`.

Décision 17 de `GAME-DESIGN-LANCEMENT.md`, codée le 28/11/2026. Migrations : `20261128020000` (frontière, rue, accès
réservés), `20261128030000` (gestes, PNJ, secrets, backgammon), `20261128040000` (tarifs doublés).

## Ouverture

- Seule Al Madina est ouverte dans Al-Khalija (`frontieres_fermees` garde ville_a et ville_b) ; dans la capitale, seuls
  le **centre multimodal** et l'**Hôtel Royal d'Al-Khalija** sont ouverts (`navigation_lieux_regles.ferme`).
- Une vue de rue (`al-madina-rue`, image `Al_Madina_centre_multimodal_exterieur.webp`) avec deux bâtiments cliquables :
  le centre multimodal (à gauche) et l'hôtel (à droite). La flèche du bas affiche « Accès interdit ! » et le « ? » du
  compteur d'ouverture (mêmes conditions et même texte qu'à Ciudad Roja, voir `GAME-DESIGN-CIUDAD-ROJA.md`).
- Centre multimodal : règles du teaser (seul l'avion vers les autres capitales fonctionne), sans ordre exclusif. Un seul
  PNJ : **Youssef Safar**, référent transport (hall), portrait à venir ; douanes et embarquement sans PNJ.

## Hôtel Royal d'Al-Khalija

- Ancien « Hôtel Al-Nour Palace » ; les anciens PNJ (Hassan Marchandage, Yasmine Épices…) ne sont plus à l'hôtel.
- Monnaie : **dinar royal (DR)**. **Tous les prix de l'hôtel sont le double de l'équivalent en Républia** (chiffres
  ci-dessous déjà doublés ; ordres habituels : réserver une chambre 160 DR, dîner d'affaires 600 DR, service d'étage
  300 DR).
- Pièces : réception (`accueil`), suite (`chambres`), restaurant, salon de thé (pièce serveur `bar`, mixte), salon des
  gentlemen (hommes), hammam des hommes, hammam des femmes. Images dans `images/Al-Khalija/Al Madina/`
  (`Al_Madina_hotel_reception`, `_suite`, `_restaurant`, `_salon_the`, `_salon_gentlemen`, `_hammam_hommes`,
  `_hammam_femmes`, en `.webp`).

### Accès réservés (moteur du Pavillon)

- Salon des gentlemen et hammam des hommes : personnages de genre « H » ; hammam des femmes : genre « F ».
- L'onglet affiche « Accès strictement réservé aux hommes » (ou « aux femmes ») ; le serveur refuse l'entrée
  (`acces_reserve_raison_interne`, raisons `reserve_hommes` / `reserve_femmes`).
- **Forcer le passage** : 2 PA ; chance 60 % + 4 % par point de VOL au-dessus de 13 (− 4 % par point en dessous).
  - Échec : **assignation à résidence** dans la suite (pièce « chambres »), attribuée d'office et sans frais même sans
    réservation (décision du 28/11 après-midi, remplace le jour de prison).
  - Réussite : libre circulation dans les pièces réservées **jusqu'à la sortie de l'hôtel**, sans être recherché.

### Salon de thé

| Geste | Coût | Effet |
|---|---|---|
| Thé à la menthe | 1 PA, 60 DR | +2 Santé |
| Pâtisseries orientales | 1 PA, 150 DR | repas léger (catégorie « snack ») |
| Jus de fruits frais | 1 PA, 50 DR | +1 Santé, protège de la chaleur pour 12 heures |
| Demander un thé spécial (à Nabil Naana) | 1 PA, 150 DR (3 fois le prix d'un verre au bar de l'hôtel) | alcool servi dans une théière, effets habituels de l'alcool ; 10 % de chances par commande d'être signalé à la police des mœurs : 1 000 DR d'amende, sans prison (liquide d'abord, puis comptes bancaires, puis ce qui existe) ; sans limite quotidienne |

### Salon des gentlemen

| Geste | Coût | Effet | Limite |
|---|---|---|---|
| Narguilé | 1 PA, 250 DR | +4 influence, −2 Santé ; dès la 2e pipe de la journée, un vrai secret sur le fumeur échappe à tous les joueurs présents et part dans le circuit des rumeurs | 3 par jour |
| Backgammon | mise choisie par celui qui défie | défi lancé à un joueur présent, qui accepte ou refuse ; chacun mise le même montant ; chance 50 % + 2 % par point d'INT d'écart ; le gagnant prend les mises et +2 popularité | — |
| Café arabe | 2 PA, 80 DR | +2 VOL pendant 6 heures | non cumulable |
| Secret contre secret | 1 PA | voir les hammams | 1 par jour et par cible |

### Hammams

| Geste | Coût | Effet | Limite |
|---|---|---|---|
| Bain de vapeur | 1 PA, 300 DR | +6 Santé, guérit la gueule de bois | 1 par jour |
| Secret contre secret | 1 PA | voir ci-dessous | 1 par jour et par cible |

**Secret contre secret** : on vise un joueur de la même pièce, sans son accord.
- Chance : 50 % + 3 % par point de CHA de l'auteur au-dessus de 8 − 3 % par point de VOL de la cible au-dessus de 8,
  bornée entre 10 et 90 %.
- Réussite : chacun apprend un vrai secret de l'autre.
- Échec : personne n'apprend rien et la cible n'est pas prévenue ; **un échec sur dix est critique** : seule la cible
  apprend alors un secret de l'auteur.
- Les « vrais secrets » sont tirés comme ceux des maisons de Sovarka : poste, argent liquide, domicile, actions
  récentes.

### PNJ

- **Réception** : Amira Miftah (référente de l'hôtel), Saïd Chanta (bagagiste, référent des douanes d'Al-Khalija).
- **Restaurant** : Karim Sahn (référent des habitués, d'après les passages réels).
- **Salon de thé** : Nabil Naana (thé spécial).
- **Salon des gentlemen** : Faris Dukhan (serveur de narguilé, référent de ceux qui fréquentent le salon), Jabbar Bawwab
  (gardien géant et laconique, à l'entrée).
- **Hammam des hommes** : Hamid Bukhar (gardien placide). **Hammam des femmes** : Oum Saboun (matrone inflexible).
- Les portraits n'existent pas encore : les cartes de PNJ s'affichent sans image.

## Ce qui n'est pas codé

- Aucun commerce à louer, aucun poste à prendre, aucune domiciliation à Al Madina (décision 17).
- Pas d'ordre exclusif au centre multimodal d'Al Madina.

## Décisions du 28/11/2026 (après-midi) — migration `20261128100000_reponses_fred_teaser`

- **Accès réservés par genre** : un personnage de genre « NB » ou libre est refusé dans les deux hammams et au salon des
  gentlemen. **Voulu**, rien ne change.
- **Échec de « Forcer le passage »** : plus de prison. Le joueur est **assigné à résidence** dans la suite de l'Hôtel
  Royal (pièce « chambres »), attribuée d'office et sans frais même sans réservation (une nuitée gratuite est posée si
  aucune n'attend). Il ne peut pas en sortir (toute navigation est refusée : `assignation_residence`) ; il peut y
  dormir, commander au service d'étage (payant), écrire du courrier et aller sur le forum. **L'assignation prend fin à
  son premier ordre « Dormir »**. Message à l'écran, au journal et au courrier, dans les neuf langues (le courrier reste
  en français comme tous les courriers système).
- **Thé spécial** : 1 PA gardé. **Pâtisseries** : comptées comme en-cas. **Narguilé** : −2 Santé gardé.
- **Amende de la police des mœurs (1 000 DR)** : liquide d'abord, puis les comptes bancaires du joueur (banque nationale
  puis Helvetia) ; s'il manque encore de l'argent, on prend ce qui existe.
- **Vrais secrets** (narguilé, « Secret contre secret ») : moteur élargi, voir `GAME-DESIGN-CIUDAD-ROJA.md`
  (« Décisions du 28/11 après-midi ») ; jamais une organisation secrète.
- **Centre multimodal** : Chambellan Al-Transit et Inspecteur Prosper Tampon retirés ; Yasmine Embarquement devient
  **Youssef Safar** (homme), référent transport, avec une personnalité de dialogue ; portrait vide pour l'instant.
- **Bâtiments fermés** : les autres bâtiments de la capitale restent déclarés dans `data.js` et fermés par le serveur.
- **Traductions** : noms de pièces et de bâtiments, rôles des PNJ et descriptions des ordres dans les neuf langues
  (`plateau-teaser-traductions.js`).
