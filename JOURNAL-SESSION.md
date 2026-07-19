# Journal de session — Res Publica

*Dernière mise à jour : 18 juillet 2026 (soir)*

**Usage** : au début de chaque nouvelle session avec Claude, faire `cat JOURNAL-SESSION.md` et coller le résultat dans le chat.

---

## 🔒 Points de restauration Git connus comme stables

- `base-saine-18juillet` — état d'avant la crise du 17-18 juillet (avant migration ?v=).
- Le dépôt est maintenant propre et à jour (soirée du 18 juillet), tous les fichiers sont à noms définitifs, système `?v=1` en place dans `plateau.html`.

En cas de casse grave :
```bash
cd ~/ResPublica
git checkout base-saine-18juillet -- .
```

---

## ⚠️ Règles impératives (apprises à la dure le 17-18 juillet)

1. **Noms de fichiers définitifs, plus jamais de suffixe `-vXX`.** Livraison = toujours `cp fichier.js plateau-xxx.js` (écrase le même nom).
2. **Cache navigateur** géré par `?v=1` dans `plateau.html` sur TOUS les scripts/styles locaux. Augmenter ce chiffre partout d'un coup pour forcer un rechargement après une modif importante.
3. **Avant de livrer un fichier reconstruit "de mémoire"**, TOUJOURS demander à Fred un `grep`/`wc -l` de vérification sur SON fichier actuel.
4. **Pour un petit correctif**, préférer un script Python (créé via `create_file` puis donné en copier-coller direct dans le chat, PAS en téléchargement — Fred a du mal à déplacer les fichiers téléchargés) plutôt que de renvoyer un fichier entier.
5. **`node` n'est PAS installé** sur la machine de Fred — utiliser uniquement `grep -c` pour vérifier une modification, jamais `node --check`.
6. **En cas de doute sur l'état d'un fichier**, faire confiance à Git (`git log -S "texte" -- fichier`, `git checkout <hash> -- fichier`).
7. **Avant toute action destructive**, poser un tag Git de sécurité (`git tag nom && git push origin nom`).
8. **Vérification rapide de propreté du dépôt** :
   ```bash
   git ls-files | grep -E '\-v[0-9]+\.(js|css|html)$'
   ```
9. **`creation.js` et `index.html`** gèrent la création de personnage (Claude ne les avait jamais vus avant le 18 juillet — bien les avoir en tête pour tout ce qui touche à la création).

---

## 🗺️ Feuille de route (donnée par Fred le 18 juillet)

- **Fin juillet 2026** : terminer Luthécia (tour de tous les bâtiments, ordres morts).
- **1re quinzaine d'août** : finaliser Port-Sainte-Marie et Montrouge (les 2 autres villes de Républia).
- **2e quinzaine d'août** : déploiement de la "base commune" vers les 3 autres empires.
- **Fin août / début septembre** : spécificités propres à chaque empire.
- **Fin septembre 2026** : objectif bêta fermée.

---

## 🏛️ Tour des bâtiments de Luthécia — état exact

**Terminés et vérifiés** : Mairie, Assemblée Nationale, Tribunal, Université (amphi + salle
de réunion), Quartier des Ambassades, Centre d'Affaires (hall + Gretta Délieu), Centre
Commercial (hall), Centre Artisanal (Travées), **Dispensaire Public** (audité le 18/07 :
retrait de "Parler"/"Manger" hors-sujet, ajout de "Centre anti-poison").

**Prochain bâtiment à auditer** : Commissariat (Fred suit l'ordre de la rue, s'est arrêté
après le Dispensaire).

**Encore à faire** : Palais Présidentiel, Hôtel Republica, Palais du Gouvernement (Fred dit
les avoir déjà audités par le passé — à vérifier au cas par cas plutôt que de refaire tout
un audit), Banque Nationale, Banque Privée, Clinique Privée, La Tribune (Imprimerie), Loge
Maçonnique, Armurerie, Marché, Tabernacle des Impôts, Centre Multimodal, Office Notarial,
Stade, Place du Formulaire de la Liberté.

---

## 🩹 GROS CHANTIER DU 18 JUILLET (soir) — Système d'agression complet

**Entièrement codé et poussé.** Résumé technique pour reprise :

- **`declencherHospitalisation(palier)`** (plateau-personnage.js) : fonction commune,
  redirige vers `dispensaire-public` (durées 6/4/2 jours) ou `clinique-privee` (3/2/1 jours)
  selon que le joueur a un haut poste ou non. Utilisée par empoisonnement ET assassinat.
- **Assassinat** : mécanique instantanée inchangée (PV fixés au jet), MAIS ajoute maintenant
  2 caractéristiques aléatoires à 0 (`state.statsAffaiblies`), remontent proportionnellement
  aux PV via `getStatEffective()` (étendue). Durées d'hospitalisation doublées.
- **Empoisonnement** : entièrement refondu. Ne fixe plus les PV instantanément — déclenche
  `state.empoisonnement = {actif:true, palier, poisonType}` + notification immédiate vague
  ("malaise suspect"). Progression uniquement via l'ordre **Dormir** : division par 2 des PV,
  passage à 0 si <20 → hospitalisation automatique **dans la ville où se trouve la victime à
  ce moment** (pas son domicile). 2 caractéristiques aussi affectées, division par 2 en //.
- **"Centre anti-poison"** : nouvel ordre au dispensaire (60 FR, 65%) et à la clinique
  (150 FR, 85%), guérit l'empoisonnement en cours, limité à 2 tentatives/jour.
- **Régénération naturelle** (+10 PV/jour post-agression) : n'est plus automatique au cron
  de minuit, liée à l'ordre Dormir (`state.regenJour`).
- **`verifierProgressionHospitalisation()`** : corrigée pour utiliser `state.hospitalisation.jourFin`
  au lieu d'une durée fixe de 3 jours codée en dur (bug trouvé en cours de route).

**Pas encore testé en conditions réelles** — Fred attend d'avoir des bêta-testeurs pour ça.

---

## 🛏️ Refonte du système de sommeil (18 juillet, soir)

- **+12 PV de base** à chaque "Dormir" (n'existait pas avant), sauf le jour où le poison
  progresse (la division prend le dessus ce jour-là).
- **"Réserver une chambre d'hôtel"** (nouvel ordre, à l'accueil/hall, 60 FR) : stocke
  `state.reservationHotel = {buildingId, bonus}`. Reste active tant qu'elle n'est pas
  consommée (pas de limite à la journée).
- **"Dormir" dans la Chambre elle-même** (`dormir_chambre`, nouvel ordre local, gratuit) :
  nécessite une réservation active pour CE bâtiment précis. Applique le Dormir standard
  + le bonus de la réservation (+2 PA/+3 Moral pour l'Hôtel du Port), consomme la réservation.
  **Attention** : si on utilise "Dormir" ailleurs (ex: le bouton générique du panneau
  "Actions personnelles"), on n'a QUE le +12 PV de base, jamais le bonus de la réservation.
- Hôtel du Port (Port-Sainte-Marie) : Hall (accueil, image `hotel-du-port-accueil.png`) +
  Chambre (image `hotel-du-port-chambre.png`), toutes deux poussées et intégrées.
- **À faire plus tard** : généraliser à d'autres sources de bonus (nourriture, soins...) et
  à l'Hôtel Republica de Luthécia qui aura 2 formules (normale + suite de luxe) — pas
  encore défini, à faire au moment de l'audit de ce bâtiment. Un grand tableau de
  cohérence des ordres est prévu par Fred pour clarifier tout ça plus tard.

---

## 🖼️ Images en attente (poussées dans `images/` mais PAS ENCORE intégrées au code)

- `rue-hotel-mairie-port-sainte-marie.png` — vue de rue (Hôtel du Port + Mairie + Place d'Armes).
- `rue-capitaine-sauvage-armurerie-port-sainte-marie.png` — vue de rue (Restaurant Capitaine
  Sauvage + Maison Le Gall Chasse & Pêche, qui devriendra l'armurerie de Port-Sainte-Marie).
- Fred a dit qu'il enverrait encore une image de la rue du marché (déjà envoyée par le passé,
  à vérifier si intégrée) avant de construire le maillage de navigation de rue pour
  Port-Sainte-Marie (pas encore commencé, contrairement à Luthécia).
- Idée notée : adapter le catalogue d'armes de l'armurerie de Port-Sainte-Marie au thème
  "chasse & pêche" du magasin — clin d'œil qui révèle où l'arme a été achetée.

---

## 🏗️ Autres chantiers ouverts / en attente (non liés à la session du 18/07 soir)

- Système de groupe/emploi de PNJ à concevoir (recrutement, hiérarchie militaire, police).
- Système de duplication de PNJ désactivé temporairement dans `plateau-multijoueur.js`,
  en attente d'un vrai redesign.
- Tableau Excel des PNJ de Luthécia en cours d'enrichissement par Fred.
- Réflexion sur la refonte de l'architecture des fichiers (4 familles : décor / cartographie
  / contenu des lieux / systèmes de jeu) — non tranchée par Fred.
- Système de messagerie persistante (conversations privées + salons nommés) — fonctionnel.
- Avatars des PJ : réflexion en cours sur génération stylisée (pas de photo réelle de tiers),
  utilité future dans le premium (affiches électorales, portraits officiels — purement
  cosmétique, aucun impact sur les indices de jeu).

---

## 💡 Idées en réserve (pas de code, juste notées)

- Monétisation premium : cosmétique/confort uniquement, jamais d'avantage compétitif payant.
- Discord, traduction, mobile : pas des priorités de lancement, à traiter bien plus tard.
