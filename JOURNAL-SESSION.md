# Journal de session — Res Publica (27 juillet 2026)

## État du dépôt
- Toutes les modifications de cette session ont été committées et poussées sur `main`.
- Dernière version dans `plateau.html` : `v=85`

---

## 🔨 Chantiers livrés cette session

### Bugs de fond corrigés
- **Indices (INF/HP/etc.) qui retombaient au rafraîchissement** : cause racine trouvée — `applyCharToState()` recalculait `state.inf/pop/dis` à partir de `char.resources`, jamais synchronisé après la fusion Supabase. Corrigé (synchronisation ajoutée avant le second appel).
- **Sauvegarde automatique périodique** ajoutée (toutes les 30s) comme filet de sécurité général.
- **Mauvais bâtiment affiché au rafraîchissement lors d'un changement de ville** (ex: "Centre Multimodal de Luthécia" alors qu'on est à PSM) : cause racine trouvée — un `fallback` bugué (`state.currentBuilding || state.char.currentBuilding || null`) empêchait `null` (= dans la rue) d'être jamais réellement sauvegardé. Corrigé à 3 endroits (`updateUI` x2, taxi). Idem pour les voyages train/bus/avion/bateau (`executerVoyage`, `confirmerTransport` dans `plateau-navigation.js`).
- **Repli "nouveau personnage" qui plaçait à tort un joueur existant dans la mairie** au lieu de le laisser dans la rue : corrigé (vérifie aussi l'absence de `currentCity` connue).
- **Arrivée par transport** : le joueur entre désormais directement dans le hall du centre multimodal de la ville de destination (via `enterBuilding`), au lieu d'atterrir dans la rue. Un bug de superposition de scène (l'ancienne scène de rue restait affichée en fond) a aussi été corrigé dans `enterBuilding()`.
- **Candidature au poste de Maire cassée** (`buildingId is not defined`) : corrigée dans `plateau-router.js`.
- **Poste de Député écrasait le poste principal** (PM/Ministre/Président/Maire) au lieu de se cumuler : Député vit désormais dans un champ séparé (`state.posteDepute`), persisté et affiché indépendamment.
- **`escortActive` n'était jamais sauvegardé dans Supabase** (contrairement à `employes`) : corrigé — prérequis pour le débauchage entre joueurs.

### PNJ employés désormais contactables + débauchage fonctionnel
- Fiche d'un PNJ employé par un autre joueur : bouton **Contacter** (réponse IA en personnage) + **Tenter de débaucher**.
- Débauchage : taux basé sur la vraie loyauté du métier (`PNJ_STATS_PAR_JOB[job].loyaute`) + DUP du joueur + pot-de-vin. Succès = transfert réel entre joueurs via Supabase (retiré de l'employeur actuel, ajouté au débaucheur).
- Renommage escort "Éléonore" → "Marlène" dans le catalogue (et sur le personnage de Fred).

### Port-Sainte-Marie (PSM) — extension et plan
- **9 nouveaux bâtiments créés** : Capitaine Sauvage, Chasse & Pêche (Maison Le Gall), Place d'Armes, École de Marine, Chantier Naval, Notre-Dame de la Mer, Cimetière Marin, Phare, Port de Plaisance. Plus le **Marché** (créé après coup, manquait initialement).
- **Port PSM renommé en "Port Industriel"** pour éviter la confusion avec le nouveau Port de Plaisance.
- **4 nouveaux terrains à bâtir** (total 5, comme Luthécia).
- Images branchées pour : Capitaine Sauvage, Chasse & Pêche, Place d'Armes, Marché, Notre-Dame de la Mer (nef).
- **Plan de ville en grille (PLAN_LAYOUTS.ville_a)** entièrement reconstruit à partir du vrai fichier Excalidraw de Fred (30 bâtiments positionnés fidèlement).
- **Rendu du plan de ville rendu générique** : le cadre/périmètre est calculé dynamiquement selon l'étendue réelle des bâtiments (au lieu d'un cadre fixe calibré pour Luthécia). Luthécia inchangée.
- **Route en croix générique** pour les autres villes (cherche le couloir le plus libre). **PSM a un tracé de rue spécifique dessiné à la main** (segment est-ouest Dispensaire/École de Marine → nord de Place d'Armes, puis nord-sud à l'est du Cimetière/Notre-Dame/Chantier Naval), qui remplace la croix générique pour cette ville.
- **Support technique ajouté** : un nœud de navigation par rue peut désormais avoir plusieurs images selon la direction d'arrivée (`imagesParArrivee`), pour varier l'angle de vue selon d'où vient le joueur. Rétrocompatible avec Luthécia.

### Réflexion économique (pas encore codée)
- **Zone de Production de PSM** : le poisson qu'elle produisait ne servait à rien (aucune recette d'arme n'utilise le poisson ; aucune ville de Republia ne produisait de bois, pourtant nécessaire aux recettes). **Décision de Fred : remplacer la Zone de Production par une Scierie (Guy Tarembois)**, qui comble ce trou (bois → recettes d'armes, et cohérent avec le Chantier Naval qui a besoin de bois). Le poisson sera géré plus tard via un **centre frigorifique** à construire près du Port Industriel (matières périssables).
- **Idée de musée** (local + national) pour évaluer et immortaliser les mandats des joueurs (bien ou en mal), à concevoir plus en détail plus tard — potentiel levier premium. Le "Musée de la ville" apparaît déjà sur le plan Excalidraw de PSM mais n'existe pas encore comme vrai bâtiment.

---

## 🗺️ Navigation rue par rue de PSM — état d'avancement

Toute la **périphérie** du plan a été définie avec Fred (nœuds, zones cliquables, liens), mais **RIEN N'EST ENCORE CODÉ** dans `plateau-rue-centrale.js` — seul le moteur générique (images multiples par direction) a été préparé. Fred a dit : "on prépare tout, et on lance l'ensemble d'un coup pour écraser le système actuel."

### Scènes définies (dans l'ordre du tour, en partant du Centre Multimodal) :

1. **Sortie Centre Multimodal** (image reçue : `port-sainte-marie-centre-multimodal (1).png`) — bâtiments cliquables : aucun mentionné (juste un carrefour). Flèches : gauche→Stade, droite→Port Industriel, bas→scène Dispensaire/École de Marine.
2. **Dispensaire + École de Marine** (image reçue, montre Stade/Port Industriel/Phare au loin) — cliquables : École de Marine, Phare. Flèches : haut→Centre Multimodal, gauche→Musée de la ville (pas encore créé), bas→Dispensaire/Port de Plaisance.
3. **Dispensaire + Port de Plaisance** (image reçue, avec panneaux École de Marine/Notre-Dame/Cimetière) — cliquables : Dispensaire, Port de Plaisance (PAS la banque, décor seulement). Flèches : haut→École de Marine/Phare, gauche→Tribunal/Banque.
4. **Tribunal + Banque** (image reçue) — cliquables : Tribunal, Banque (PAS le commissariat, décor). Flèches : droite→Dispensaire/Port de Plaisance, gauche→Commissariat/Bar des Pêcheurs, haut→carrefour Musée/Centre Commercial/Centre d'Affaires.
5. **Bar des Pêcheurs + Imprimerie + Commissariat** (image reçue) — cliquables : les 3. Flèches : droite→Tribunal/Banque, gauche→Capitaine Sauvage/Marché/Chasse&Pêche.
6. **Capitaine Sauvage + Marché (ruelle) + Chasse&Pêche** (image reçue) — cliquables : les 3 (le Marché = ruelle qui mène à une sous-scène). Flèches : droite→Bar des Pêcheurs/Imprimerie/Commissariat, gauche→Place d'Armes/Mairie/Hôtel du Port.
7. **Place d'Armes + Mairie + Hôtel du Port** (image reçue) — cliquables : les 3. Flèches : droite→Capitaine Sauvage, gauche→Église/Cimetière.
8. **Notre-Dame de la Mer + Cimetière Marin** (image reçue) — cliquables : les 2. Flèches : droite→Chantier Naval, gauche→Place d'Armes, arrière/bas→carrefour Musée/Centre Commercial/Centre d'Affaires.
9. **Chantier Naval** (image reçue) — cliquable : le chantier. Flèches : haut→Terrains à vendre, bas→Église/Cimetière.
10. **Terrains à vendre** (image reçue, montre 5 lots numérotés au loin via sous-scène) — cliquable : les terrains (sous-scène avec les 5 lots, image reçue aussi). Flèches : droite→Centre Artisanal/Scierie, bas→Chantier Naval.
11. **Carrefour Centre Artisanal + Scierie** (image reçue) — cliquables : les 2. Flèches : haut→Centre Multimodal, droite→Musée (carrefour central), bas→Terrains à vendre.
12. **Carrefour Musée + Centre d'Affaires + Centre Commercial** (2 variantes d'image reçues, vue "en provenance du Centre Artisanal") — cliquables : les 3. Flèches : haut→Tribunal, bas→Centre Artisanal, droite→Église, gauche→Phare.

### ⚠️ Reste à faire pour la navigation
- Le **carrefour central (Musée/Centre Commercial/Centre d'Affaires)** a plusieurs entrées (depuis Tribunal, depuis Chantier Naval/Église, depuis Centre Artisanal) — il faudra définir les flèches pour CHAQUE direction d'arrivée (utiliser le nouveau système `imagesParArrivee` qu'on vient de construire).
- Certaines images manquent encore (Fred génère au fur et à mesure).
- Une fois toutes les images prêtes : coder tous les nœuds dans `plateau-rue-centrale.js` (`RUE_CENTRALE_NOEUDS.republic`, sur le modèle de Luthécia), ajouter l'entrée dans `RUE_CENTRALE_DEPART.republic.ville_a`, et "lancer l'ensemble d'un coup".
- Remettre à jour le plan Excalidraw de PSM à la fin (les bâtiments ont bougé par rapport à la dernière version envoyée).

---

## 🖼️ Autre chantier en cours (hors code)
Fred construit un **blockout 3D dans Blender** (3.6 LTS, version Intel — son Mac est sous macOS Monterey 12.7.6, incompatible avec les versions récentes de Blender) pour positionner une caméra et générer des vues cohérentes entre elles à chaque carrefour de PSM, plutôt que de dépendre entièrement des générateurs d'images (qui produisent des résultats peu cohérents géométriquement d'une image à l'autre). Session en cours d'apprentissage de l'interface (import d'image de référence, positionnement de caméra). Pas un chantier de code.

---

## 📝 Chantiers en attente (rappel, non traités cette session)
- Calendrier électoral pas à jour.
- Photo du Chef de Cabinet qui ne charge pas.
- Réorganiser le dossier `images/` en sous-dossiers (pays/ville/PNJ/bâtiments) — actuellement tout à plat.
- Concevoir le système de musée (local + national) plus en détail.
- Concevoir le centre frigorifique de PSM (matières périssables, poisson).
