# Raccordements des ordres — première vérification (28 octobre 2026)

## Périmètre
Travail de lecture seule et qualification du premier écart provenant de `ARCHITECTURE.md` et `AUDIT_UNE_SEULE_VERITE.md`. Ne modifie ni les règles, ni le moteur, ni les fichiers d'inventaire de Codex, ni les fichiers d'ambassades/BNE de Claude.

## Contrôle douanier (dans `plateau-navigation.js`)

- `confirmerTransport`, branches avion/bateau : en cas de `state.recherche`, le navigateur tire `Math.random()` et peut afficher « Intercepté aux douanes ! » sans créer une interpellation ni un état carcéral serveur. Une annonce publique est produite côté client.
- `doControlDouanes` : un second jet de douane est également tiré par le navigateur ; l'échec annonce une arrestation sans déclencher la mécanique d'interception/incarcération.
- `doCorrompreDoanier` est **déjà** raccordé à `crime_corrompre_douanier` et ne doit pas être réécrit ou détourné pour remplacer un contrôle.
- En production, `police_detection_verifier(text,text,text)` existe et enregistre une `police_interceptions`, mais il exige une présence de policiers à l'emplacement du PJ ; il retourne `aucun_policier_present` sinon. Il ne représente **pas automatiquement** un poste douanier. Le brancher directement serait un faux raccordement.
- Fonctions également identifiées en base : `douane_pnj_id`, `douane_effectifs_publics`, `douane_caracteristiques_metier`, `douane_autorite_de_perimetre`. Elles imposent un examen de leurs usages réels avant tout raccordement.
- **À faire** : retrouver dans le socle la détection et l'interception d'une unité douanière (avec ses conditions de présence et compétences) ; vérifier la suite judiciaire existante ; ajouter un test de bout en bout « recherché → contrôle → détection → interpellation réelle » ; supprimer uniquement ensuite les tirages clients correspondants.

## Blocus portuaire (hors priorité Luthécia)
- `doBlocusPortuaire` possède encore un tirage navigateur et un effet `INDICES_NATIONAUX[pays].IE` local. Aucun RPC portant « blocus » n'a été trouvé parmi les fonctions publiques de production ; ne pas inventer une nouvelle fonction avant la recherche complète du socle des grèves/manifs.
- Pas de modification de cet ordre pendant cette première passe.

## Garde-fous
Les chantiers de sécurité privée #135 et d'inventaire sont en cours chez Codex. Ce constat n'autorise ni nouvelle structure douanière, ni patch du mécanisme policier en parallèle. Le projet doit faire primer l'état du serveur ; un texte de « capture » dans un toast n'est pas une capture effective.

**Statut** : écart démontré, mécanisme existant partiellement identifié ; correctif métier non réalisé et non déployé.
