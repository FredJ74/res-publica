# Journal de session — Res Publica (9 août 2026)

## État du dépôt
- Toutes les modifications ont été committées et poussées sur `main` (16 commits).
- Session arrêtée à 3h du matin — reprise prévue avec le résumé de fin de journal ci-dessous.

---

## 🕍 Clarification Tabernacle des Impôts (religion vs fiscalité)
- Inventaire du bâtiment `tabernacle-impots` (Luthécia) : tout son contenu (2 salles, 8 ordres) est en réalité **100% religieux** (mécanique de l'indice IP, Moral, POP) — le vocabulaire fiscal ("Formulaire Sacré", "Percepteur Suprême") n'est qu'un habillage. Aucun doublon avec les vrais ordres fiscaux (mairie : `fixer_impots_locaux`/`repartition_budget_local` ; Ministère des Finances : `fixer_impots_nationaux`/`redressement_fiscal`/`fiscal`).
- Confirmé : le nom "Tabernacle des Impôts" est **canonique et volontaire** (objet `RELIGIONS`, `plateau-divers.js:248`) — la religion de Republia s'appelle le **Papyrusisme**, son temple s'appelle bien "Tabernacle des Impôts". C'est la fusion assumée religion/bureaucratie qui fait la blague (comme le Cocaïsme à El Estado, le Tractorisme à Sovarka, le Loukoumisme à Al-Khalija). **Décision : on garde le nom tel quel.**
- Bug annexe corrigé au passage : `EMPIRE_STYLES.republic.religion` valait `"le Tabernacle des Impôts"` (nom du temple) au lieu de `"le Papyrusisme"` (nom de la religion) — incohérent avec `RELIGIONS`. Corrigé (`ac8ebc7`).

---

## 🔍 Audit Ordres — inventaire des 344 ordres de Luthécia (préparatoire, avant le grand audit de la semaine prochaine)
- Classement des 344 ordres des 36 bâtiments de Luthécia en 4 catégories : **Fonction** (92, `requiresPost` renseigné), **Lieu** (212), **Rencontre** (23, cible un individu précis choisi/cliqué), **Autres** (17, actions méta ou cibles collectives). Critères détaillés et cas limites calibrés avec Fred avant classement.
- Au passage, **7 ordres trouvés sans aucun effet mécanique réel** malgré une description ou un coût qui en promettait un (jusqu'à 500 FR facturés pour rien) — voir section suivante.
- Niveau de vérification obtenu ce soir : seuls les **21 ordres au chemin générique** (pas de handler dédié) ont pu être vérifiés avec certitude contre `ORDER_EFFECTS`. Les **318 ordres routés vers un handler dédié** (`doOrder` → fonction spécifique) n'ont **pas** été vérifiés un par un — leur taux affiché vient de la déclaration dans `data.js`, pas d'une lecture du code réel.
- Résultat livré à Fred sous forme d'un inventaire interactif (tableau filtrable/triable, catégorie/difficulté/statut de vérification) plutôt que dans ce journal — trop volumineux pour être utile ici.

### 🐛 7 ordres sans effet réel — corrigés ce soir (`7df6a28`)
| Ordre | Bâtiment | Correctif appliqué |
|---|---|---|
| `investir` | Banque Nationale | Coût remis à 0 FR (était 500 FR pour un "rendement dans 24h" qui n'existe nulle part dans le code — aucun cron ne le traite) |
| `redaction_testament` | Office Notarial | Coût remis à 0 FR (était 500 FR — le code de succession applique toujours la dévolution par défaut, jamais un héritier désigné) |
| `contrat_mariage` | Office Notarial | Coût remis à 0 FR (était 400 FR — même souci, le régime matrimonial choisi n'est jamais lu) |
| `emprunter_prive` | Banque Privée | Routé vers le vrai système de prêt existant (`ouvrirModalPretBancaire('privee','consommation')`) — n'avait aucun handler avant |
| `consulter_succession` | Office Notarial | Routé vers `doConsulterArchivesNotariales()` — doublon orphelin d'un ordre déjà fonctionnel dans la même zone |
| `demander_adhesion` | Loge Maçonnique | Bouton retiré (`orders: []`) — aucun système de membres/parrain n'existe dans le code, le clic ne faisait jamais rien |
| `construire_sur_terrain` (×3, terrains 1/4/5) | Terrains à bâtir | **Non touché** — coût déjà nul (0 PA, 0 FR), donc aucun joueur lésé. Pas trouvé où/si la construction démarre réellement ailleurs — à investiguer lors de l'audit Ordres plutôt que de toucher un flux mal compris. |

---

## 🧭 Fix navigation PSM (Pôle Tabac/Entrepôt + carrefour Scierie/Artisanal)
- 3 rounds successifs, corrigés au fur et à mesure des retours de test en jeu réel :
  1. Image manquante sur `psm-pole-tabac-entrepot` (fichier jamais commité) + `flechesStyle` ajouté après inspection de l'image réelle.
  2. Retour arrière de `psm-carrefour-artisanal-scierie` d'abord "corrigé" via `liensParArrivee` — ne se déclenchait quasiment jamais en jeu (voir cause racine ci-dessous).
  3. **Cause racine trouvée et corrigée** : `rueCentraleDepuisNoeud` (la provenance, nécessaire à `imagesParArrivee`/`zonesParArrivee`/`liensParArrivee`) était perdue à **chaque sortie de bâtiment** (`showVueRue()` → `initialiserRueCentrale()` ne la transmettait jamais). Corrigé à la racine en propageant la provenance de bout en bout (`memoriserNoeudRueCentrale`/`obtenirNoeudRueCentraleMemorise` stockent désormais `{noeudId, depuisNoeudId}`). Bénéfice général au-delà de PSM : `psm-carrefour-musee` (3 bâtiments, 4 vues différentes selon provenance) et `psm-eglise-cimetiere` en profitent aussi. Rétrocompatible avec les anciennes sauvegardes localStorage.

---

## 🗳️ Bug électoral corrigé : le cas Arnie/Gaston Intérim expliqué
- Investigation demandée par Fred (candidature Arnie à la présidentielle, remplacée par le PNJ "Gaston Intérim faute de candidat"). Données Supabase réelles retrouvées : Arnie était bien seul candidat, élu à l'unanimité (3/3 votes PNJ), mais `eluId` n'a jamais été renseigné.
- **Cause racine, différente du fix d'hier sur `cycle.phase`** : `calculerResultatsServer` (`api/cron-minuit.js`) lisait `cycle.votes_pj`/`cycle.votes_pnj` — des champs qui n'existent nulle part ailleurs dans le jeu (toujours `undefined`). Résultat : `totalVoix` valait systématiquement 0, donc **aucune élection traitée par le cron n'a jamais pu déclarer d'élu**, quel que soit le nombre réel de votes. Corrigé pour lire les vrais champs `cycle.votes`/`cycle.votesPNJ`.
- Rejoué contre les vraies données Arnie après correctif (en Python, hors jeu) : élection bien déclarée à l'unanimité. **Ne réécrit pas rétroactivement l'historique Supabase** — Arnie reste non-élu dans l'archive, seules les prochaines élections sont concernées.

---

## 💼 Bureau National de l'Emploi (BNE) — nouveau, complet ce soir
- Revenu régulier pour un PJ sans poste politique : inscription volontaire → consultation d'offres → candidature, sur les 3 guichets existants (Luthécia, Montrouge, annexe PSM dans le Centre d'Affaires — trouvée par Fred, pas créée ce soir).
- **Catalogue** `OFFRES_EMPLOI_BNE` (`data.js`) : 7 offres de départ, jobs repris de `PNJ_STATS_PAR_JOB` (serveur, docker, hôtelier, secrétaire, commerçant, banquier, hôtesse), 3 portées (locale par ville / nationale / internationale — cette dernière juste étiquetée pour l'instant, pas de vraie mécanique inter-empire), salaire 200-450 FR/jour selon le poste (au-dessus du plancher universel de 150 FR/jour, en dessous des salaires politiques).
- **Pas de nouvelle table Supabase** (impossible en DDL avec la clé anon) : réutilise la table générique `batiments_etat` déjà existante, une seule entrée partagée par pays. `state.emploiBNE` n'est qu'un cache local, rafraîchi au chargement du personnage et après chaque action.
- **Règle de conflit** (demandée par Fred) : aucune situation active n'est jamais écrasée automatiquement. Postuler en ayant déjà un emploi BNE réserve la nouvelle offre et envoie un mail d'arbitrage (garder / prendre le nouveau) au lieu de trancher. Obtenir un poste politique en gardant un emploi BNE (possible via les 3 systèmes de postes parallèles, voir dette technique) est détecté par un nouveau passage du cron nocturne (`verifierConflitsEmploiBNE`), même mécanique de mail, rien n'est jamais tranché automatiquement.
- Incompatible avec un poste politique (vérifié à la candidature). Démission immédiate et gratuite.
- **Bug distinct repéré au passage** (voir chantiers en attente ci-dessous) : plusieurs mails envoyés par le cron utilisent probablement les mauvais noms de colonnes.

---

## 🖼️ Pat Hounette (photo) + 🏦 Laurent Barre (invisible) — deux corrections PNJ
- **Pat Hounette** (Place du Formulaire de la Liberté) : n'avait en réalité **jamais** eu de `photoUrl` dans le code (vérifié sur tout l'historique git) — pas le même bug que les photos du Palais, juste jamais branchée. Fichier déjà présent sur le disque, jamais commité. Ajouté (`photoUrl` + `photoPos`).
- **Laurent Barre** (Directeur d'agence, Banque Nationale) : Fred ne le trouvait plus en jeu. Cause trouvée — un `buildingContext` obsolète (`WORLD.republic.capitale.buildingContext['banque-nationale']`, avec Bernard Coffre-Fort/Simone Intérêt) écrasait silencieusement le vrai contenu de la salle via la règle de priorité sur la première salle (`plateau-navigation.js:565` et `:91` pour la minimap). Entrée obsolète supprimée, Laurent Barre redevient visible sans rien déplacer — reste cohérent avec son rôle déjà établi dans l'énigme du portrait (coffre lié à la succession Thibault, situé à la Banque Nationale).
- **Même bug repéré ailleurs, pas corrigé** : `banque-privee` (Hans Von Discret masque M. Fischer), et potentiellement `commissariat`/`tribunal` (même bloc `buildingContext`, mêmes personnes issues de `PNJ_PERSONALITIES` jamais nettoyées après l'ajout des vraies salles/PNJ). À auditer.

---

## 🎯 Quête carrière (aiguillage par Jérémy) — script reçu et validé par Fred, pas encore codé
Extension de la quête d'accueil : après le tour actuel, Jérémy demande au joueur ce qu'il aimerait devenir et l'oriente vers un référent selon son ambition (Criminelle / Politique / Entrepreneuriale / Indécis), chaque référent proposant une mini-mission qui fait *expérimenter* sa logique plutôt que réciter les règles.
- **Investigation faite ce soir** : le squelette FSM de `plateau-quete-accueil.js` (`state.char.queteAccueil = {etape}`, `queteAccueilVerifierEtapeBatiment`, `afficherPopupQueteAccueil`) est directement réutilisable, y compris le motif `reprise_contact`/`choix_destination` (popup à boutons multiples) qui correspond presque exactement à l'aiguillage à 3 branches + indécis. Le "revenir plus tard" a aussi déjà un vrai précédent (`queteAccueilGenererReponseMailJeremy`, réponse IA + réapparition au Marché). Rien d'existant en revanche pour la mécanique "mini-mission avec objet à livrer" — mais `addToInventory`/`state.inventory` et le motif de `state.char.enigme1` (marqueurs de possession d'objet) donnent tout ce qu'il faut pour la construire.
- **Noms vérifiés** :
  - **Pat Hounette** (branche criminelle) — existe déjà, Place du Formulaire de la Liberté. Photo ajoutée ce soir (voir plus haut).
  - **Laurent Barre** (branche entrepreneuriale) — existe déjà, **Banque Nationale** confirmé (pas "banque d'affaires" comme indiqué dans le script initial — ce bâtiment n'existe pas ; la Banque Privée Helvétia envisagée un temps a été écartée, cf. bug `buildingContext` ci-dessus qui le rendait invisible, maintenant corrigé).
  - **Jean-Lou Zeure** (branche politique) — **nouveau, à créer**, au Bureau National de l'Emploi de Luthécia (`bureau-national-emploi`, salle `accueil`), construit ce soir et actuellement `persons: []`. Re-vérifié en fin de session (10 août, 3h) suite à une remontée de Fred : aucune trace nulle part dans le code (`grep` sur tout le dépôt) — il n'a jamais été créé, ni par erreur ni autrement. Confirmé : reste entièrement à faire, pas une régression.
- **2 décisions de conception à trancher avant de coder** (voir chantiers en attente) : le déclenchement de l'aiguillage, et ce que "le référent reste disponible comme point de repère durable" veut dire concrètement.

---

## 📝 Chantiers en attente (mis à jour — priorité aux 2 premiers points pour la prochaine session)

**À reprendre en premier :**
1. **Quête carrière — 2 décisions de conception à trancher avant de coder** (voir section dédiée ci-dessus) :
   - Déclenchement de l'aiguillage par Jérémy : juste après la fin du tour actuel (`quete_terminee_avec_aide`/`sans_aide`), ou reprise séparée plus tard ?
   - "Le référent reste disponible comme point de repère durable" : ajout automatique au répertoire de contacts (comme Jérémy), ou simple PNJ retrouvable physiquement avec une réaction différente si on lui reparle ?
   Une fois tranché : plan technique complet des 3 mini-missions (colis de Pat Hounette, 3 interviews pour Jean-Lou Zeure, observation des cours pour Laurent Barre) à détailler avant de coder.
2. **Point 2 du chantier "priorité PJ" — pas commencé** : quand l'autorité de nomination d'un poste nommé (ex: le Maire) est elle-même un PNJ générique auto-pourvu, un PJ qui postule doit obligatoirement remplacer le PNJ en poste (pas de vraie décision politique derrière un PNJ) ; à l'inverse une vraie autorité PJ garde son plein pouvoir de choix. Basé sur `POSTES_NOMMES_EXCLUSIFS`/`titulaires_pnj`/`getTitulairePosteNomme` (déjà couverts) — nécessite en plus un vrai mécanisme "un PJ postule", qui n'existe pas aujourd'hui pour ces postes (seule la nomination par l'autorité existe). Investigation faite le 9 août, plan pas encore proposé.

**Backlog déjà connu, pas prioritaire :**
3. **Grand audit Ordres, prévu la semaine prochaine** — portée précisée le 9 août : vérifier un par un les **318 handlers dédiés** non couverts par la vérification du 9 août (confirmer que chacun applique bien un effet cohérent avec sa description), plus élucider le cas `construire_sur_terrain` (flux de démarrage de chantier non identifié). Bons candidats à y intégrer : le bug des mails `destinataire`/`expediteur` (point 6 ci-dessous) et l'audit `buildingContext` (point 7).
4. **Audit PNJ** — prévu avant la bêta, pas encore fait (état des ~18 points d'appel IA hors périmètre de la fondation `PNJ_PROFILS` posée le 8 août).
5. **Tâche optionnelle** : décrets automatiques du PNJ Président (à décider si prioritaire).
6. **Tableau Excel PNJ** à mettre à jour avec les nouveaux PNJ créés le 8 août (cascade de nomination automatique, postes de Directeur usine/entrepôt), plus Jean-Lou Zeure une fois créé pour la quête carrière.
7. **Dette technique — 3 systèmes de postes parallèles et non synchronisés** : `POSTES` (structure statique, `data.js`, holders codés en dur, couvre Président/PM/Ministères/Députés/Maires), `POSTES_ELECTIFS`/`cycles_electoraux` (élections), et `POSTES_NOMMES_EXCLUSIFS`/`titulaires_pnj` (nominations : juge, commissaire, directeurs). Comportements parfois contradictoires — ex : le bouton "Postuler à un poste" (`postulerPoste`, Palais du Gouvernement) **bloque aujourd'hui** une candidature PJ à un ministère quand le PM est un PNJ générique (`getTitulairePoste` ne connaît que les vrais PJ, pas `titulaires_pnj`), à l'inverse de la règle de priorité PJ du point 2 ci-dessus.
8. **Idée backlog (session future)** : annonces d'emploi **entre joueurs**, notamment pour des jobs illégaux (ex: un PJ recrute un autre PJ pour un coup précis), en complément du Bureau National de l'Emploi (offres officielles/légales, codé le 9 août).
9. **Bug probable, pas corrigé** : dans `api/cron-minuit.js`, plusieurs envois de mail existants (relances de chantier impayé, avertissements de prêt...) utilisent des noms de colonnes (`destinataire`/`expediteur`/`sujet`/`corps`) différents de ceux relus par le client (`to_player`/`from_player`/`subject`/`body`, voir `sbGetMailsFor`/`plateau-communication.js`). Vraisemblablement le même type de bug que celui du cycle électoral corrigé le 9 août (`votes_pj`/`votes_pnj`) — ces mails ne doivent jamais arriver dans la boîte de réception des joueurs concernés.
10. **Bug `buildingContext` vestige, corrigé seulement pour `banque-nationale`** : `WORLD.<pays>.<ville>.buildingContext[<batimentId>].persons` écrase silencieusement le vrai contenu de la première salle d'un bâtiment (`plateau-navigation.js:565` + minimap `:91`), avec des noms de `PNJ_PERSONALITIES` jamais nettoyés après l'ajout des vraies salles/PNJ dans `BUILDINGS`. Repéré aussi sur `banque-privee` (Hans Von Discret masque M. Fischer) — probablement `commissariat`/`tribunal` aussi (même bloc). À auditer entièrement (tous pays/villes) plutôt que de corriger bâtiment par bâtiment au fil des demandes de Fred.

---

# Journal de session — Res Publica (8 août 2026)

## État du dépôt
- Toutes les modifications ont été committées et poussées sur `main` (7 commits).
- Reste des fichiers `patch_*.py` non trackés dans le dépôt (scripts ponctuels utilisés pour appliquer certains correctifs) — sans impact, cohérent avec la pratique habituelle de la session.

---

## 🐛 Fix critique : cron entrepôt (bug de fond, corrigé en premier)
- **Cause racine** : `sbGetBatimentEtat`/`sbSetBatimentEtat` manquaient dans le cron nocturne → le stock des entrepôts n'était jamais réellement alimenté malgré les livraisons programmées.
- Corrigé (`d2a451e`). Ce bug bloquait silencieusement toute la mécanique entrepôt/production en aval — corrigé avant tout le reste de la session car les tableaux de bord Directeur en dépendaient.

---

## 💰 Affichage des caisses entrepôts/usines
- Caisse (solde) désormais visible dans l'en-tête du bâtiment, pour tous les joueurs présents (`8b803c0`).

---

## 🏭 Tableau de bord Directeur d'usine (mode PJ, V1 complet)
- Poste de Directeur PJ sur les 3 usines stratégiques : prix de vente directe réglable (±40% du prix de base), répartition production entrepôts/vente directe réglable, salaire quotidien plafonné (500 FR/j) par la caisse de l'usine.
- Présence PNJ par défaut masquée dès qu'un PJ est nommé au poste (`1c0f537`).

## 🏬 Tableau de bord Directeur d'entrepôt
- Poste nommé par le Maire (local, `scope:'ville'`) : prix d'achat réglable ±40%, salaire quotidien 500 FR/j plafonné par la caisse — caisse désormais réellement alimentée par les achats des joueurs (le bug corrigé plus haut : l'argent disparaissait sans jamais créditer la caisse).
- Affichage du directeur en poste (PJ ou PNJ) dans l'en-tête du bâtiment, appliqué aussi rétroactivement aux 3 usines.
- Au passage, correction de 3 fonctions maire cassées depuis l'élection du maire (comparaison exacte au lieu de `startsWith`) : `nommer_commissaire`, `financer_communal`, `traiter_demandes_permis` (`ccefa84`).

---

## 🧠 Fondation de la fiche PNJ enrichie
- Suite à l'audit du système de dialogue IA : nouvelle table `PNJ_PROFILS` (traits, savoirs, fonction pédagogique, secrets, objectifs, rumeurs, notes), même clé que `PNJ_PERSONALITIES`.
- Remplissage partiel assumé — un seul PNJ enrichi pour l'instant en exemple : **Gérard Poinçon** (gardien du musée).
- `talkToPnj` lit désormais ce profil quand il existe et l'injecte dans le prompt, avec repli gracieux total pour les PNJ non enrichis (comportement inchangé pour tous les autres). Les ~18 autres points d'appel IA restent volontairement hors périmètre pour cette session (`ea8f8b8`).

---

## 🖼️ Images restaurées / branchées
- **5 images du Palais Présidentiel/Gouvernement** jamais commitées depuis le 22 juillet (chef de cabinet, protocole, garde républicain, secrétaire générale, porte-parole) — laissaient ces photos cassées en production.
- 2 images PSM déjà existantes mais jamais reliées : Port Industriel (`quai_principal`, remplace un placeholder générique) et Port de Plaisance (`quai`, n'avait aucune image du tout) (`a18ee30`).

---

## 🗳️ Renouvellement du calendrier électoral + cascade de nomination automatique
*(bugs remontés par Fred le 8 août 2026)*
- Les mandats (5 semaines, déjà prévu dans `POSTES_ELECTIFS` mais jamais branché) déclenchent désormais un nouveau cycle de candidatures à échéance, PJ ou PNJ.
- Bug connexe corrigé : `cycle.phase` était mis à `'vacant'` même en cas de victoire, ce qui empêchait le calendrier d'afficher correctement "Mandat en cours" ou "Campagne 2nd tour".
- Quand un cycle conclut à "vacant" (0 candidat), un **PNJ générique prend immédiatement le poste** (résolution en un seul passage du cron), sur le périmètre président → PM → 6 ministères → juge et maire → commissaire par ville — évite qu'un poste vacant bloque indéfiniment les nominations en cascade en dessous.
- Périmètre volontairement restreint (hors commandant/directeurs, déjà fonctionnels sans titulaire), scope Republia uniquement comme le reste du système électoral/fiscal (`43c4f1b`).

---

## 🧭 Fix navigation retour Luthécia/PSM (bug 3)
- **Cause racine** : `getBuildingIdCentreMultimodal` utilisait `'port-sainte-marie'`/`'montrouge'` comme clés alors que les appelants passent toujours `'ville_a'`/`'ville_b'` — un voyage vers PSM ou Montrouge générait un id de bâtiment inexistant et `enterBuilding` échouait silencieusement (**Montrouge était donc cassé aussi, pas seulement PSM**).
- Fonction rendue consciente de l'empire pour éviter qu'un joueur d'un autre empire entre dans un bâtiment Republia par erreur.
- Nouvelle fonction `trouverNoeudRueCentralePourBatiment`, appelée à l'arrivée d'un voyage pour repositionner le souvenir de rue centrale sur la scène du Centre Multimodal réellement atteint, au lieu de laisser le joueur retomber sur la dernière scène visitée dans cette ville en sortant du bâtiment — parfois périmée de plusieurs jours.
- Ajout d'un repli vers la rue si le bâtiment d'arrivée n'existe pas (`confirmerTransport` n'en avait aucun) (`8117d0d`).

---

## 📝 Chantiers en attente
1. **Audit PNJ** — prévu avant la bêta, pas encore fait (état des ~18 points d'appel IA hors périmètre de la fondation `PNJ_PROFILS` posée ce soir).
2. **Audit Ordres** — prévu avant la bêta, pas encore fait.
3. **Tâche optionnelle** : décrets automatiques du PNJ Président (à décider si prioritaire).
4. **Tableau Excel PNJ** à mettre à jour avec les nouveaux PNJ créés aujourd'hui (notamment ceux générés par la cascade de nomination automatique et les postes de Directeur usine/entrepôt).

---

# Journal de session — Res Publica (30 juillet 2026)

## État du dépôt
- Toutes les modifications ont été committées et poussées sur `main`.
- **Changement de session prévu à la fin de ce journal** : la prochaine session reprend directement sur Luthécia (voir priorités en fin de journal).

---

## 🐛 Corrections diverses (poursuite du debug d'hier, sur Luthécia cette fois)

1. **Voile sombre trop fort sur les images de pièces** : deux couches d'assombrissement se cumulaient — un dégradé JS dans `plateau-navigation.js` (ligne ~454, corrigé de 50% à 15% de noir en bas) ET un second voile CSS `::before` sur `.piece-image` dans `style.css` (allant jusqu'à 88% de noir, la vraie cause principale, réduit à 35% et concentré sur les 35% inférieurs de l'image). **Les deux fixes sont en place et validés par Fred ("bien mieux !").**
2. **Image de la Place du Formulaire de la Liberté** : depuis sa création le 15 juillet, le fichier `place-formulaire-liberte.png` contenait en fait une image d'autruche entravée (erreur de `mv` à l'origine, jamais un écrasement ultérieur — un seul commit a touché ce fichier). Fred a retrouvé la vraie image dans ses téléchargements (14 juillet 22h31) et on l'a remise en place.

### Leçon générale sur les erreurs de fichiers
Deux catégories de bugs récurrents identifiées sur toute la session : (1) noms de fichiers dans `~/Downloads` qui utilisent espaces/accents/casse différents de ce que Claude suppose — toujours vérifier avec `ls | grep` avant un `mv` s'il n'a pas été confirmé explicitement ; (2) `git add` avec plusieurs fichiers échoue **intégralement** si un seul chemin n'existe pas — même les fichiers valides de la commande ne sont alors pas committés.

---

## 🏛️ Luthécia — Création des deux Musées (nouveau grand morceau de contenu)

- **Nouvelle scène de rue** `luthecia-musees`, insérée entre le carrefour `luthecia-intersection-stade-commercial` et `luthecia-quartier-ambassades` (liens recâblés dans les deux sens). Les deux musées sont face à face sur la même rue.
- **Musée de la Ville de Luthécia** : structure identique au Musée de Port-Sainte-Marie (hall + 10 salles thématiques : Criminels, Maires, Personnalités, Entrepreneurs, Organisations, Plumes, Honneur Militaire, Unions Célèbres, Dynasties, Scandales). Images du hall intégrées.
- **Musée National de Republia** : structure complète également (hall + 10 salles), avec deux salles supplémentaires spécifiques au niveau national par rapport au modèle de ville :
  - **Salle des Grandes Villes de Republia** : les maires des différentes villes du pays entrent en compétition pour la reconnaissance nationale de leur cité (méta-classement inter-villes).
  - **Salle des Plus Grands Criminels du Pays** : même logique de compétition inter-villes côté criminalité.
  - Plus : Salle des Présidents, Salle des Pères Fondateurs, Panthéon National, Salle d'Honneur Militaire Nationale, Salle des Relations Diplomatiques (clin d'œil : juste à côté du Quartier des Ambassades), Salle du Trésor National, Salle des Grandes Réussites Économiques, Salle des Scandales d'État.
- Positions ajoutées à `PLAN_LAYOUTS.capitale` (entre Quartier des Ambassades et Stade, coordonnées estimées à ajuster si besoin) + icônes `PLAN_ICONS`.
- **Aucune mécanique de classement/vote n'est codée** pour l'instant — uniquement la structure et les noms des salles, comme convenu (placeholders "Contenu à venir" / "Classement à venir").

---

## 🔄 GROS PIVOT ANNONCÉ EN FIN DE SESSION

Fred a annoncé vouloir **terminer complètement le codage de Luthécia**, ce qui implique nécessairement de coder le **système économique complet** (production/marchés/jauges PJ/géopolitique, voir détail dans l'entrée du 29-30 juillet précédente) — bien plus large que le simple "reprendre le tour des bâtiments" évoqué initialement.

**Ordre de priorité entre i18n et système économique NON tranché** — Fred avait dit vouloir faire l'i18n avant l'économie (pour éviter d'avoir à retraduire), mais n'a pas reconfirmé cet ordre au moment du pivot. **Point à trancher explicitement en début de prochaine session.**

---

## 📝 Chantiers en attente (mis à jour, ordre indicatif à revalider)
1. **Décider l'ordre : i18n d'abord, ou système économique d'abord** (voir pivot ci-dessus).
2. **Terminer Luthécia** : finir le tour des bâtiments restants (état exact non ré-audité ce soir — repartir de l'audit du 27 juillet si besoin, plusieurs sessions ont pu faire avancer les choses depuis).
3. **Système économique de production** complet (voir détail 29-30 juillet : production par ville, marchés, jauges PJ, dimension géopolitique eau/pétrole, inspiration parodique par empire).
4. **Système i18n** (`t("clé")` + fichiers `fr.json`/`en.json`, audit d'ampleur non fait, potentiellement des milliers de chaînes en dur).
5. Vrai fix JS pour le mode plein écran de la navigation de rue (PSM) — fix CSS temporaire en place (`max-height: 78vh`), imparfait.
6. Auditer les autres scènes PSM à risque de chevauchement zones/flèches (yPct) — non fait systématiquement.
7. Quête Yann Le Goff (calendrier, mécanique de communication, récompense) — contours posés uniquement.
8. Contenu réel des salles vides : Musée PSM (7/10 sans image), Musée National Republia (10/10 sans image), Musée Ville Luthécia (9/10 sans image), Port Industriel PSM (5 salles placeholders).
9. Mécanique de classement/vote des musées (stats + votes, historique des anciens détenteurs) — jamais développée, juste évoquée en principe.
10. Calendrier électoral pas à jour, photo du Chef de Cabinet qui ne charge pas, réorganisation du dossier `images/` en sous-dossiers.

# Journal de session — Res Publica (28-29 juillet 2026, nuit)

## État du dépôt
- Toutes les modifications ont été committées et poussées sur `main`.
- **Régression identifiée en fin de session, non résolue** : positionnement des flèches directionnelles cassé sur plusieurs scènes de rue PSM, et certaines flèches ne déclenchent plus le déplacement. Semble lié à une confusion entre le système de flèches rondes (`rc-fleche`, géré par `flechesStyle`/`stylesParDefaut` dans `plateau-rue-centrale.js`) et des panneaux directionnels visibles différemment sur la capture (voir `bug.jpg` fourni par Fred). **À investiguer en priorité à la prochaine session**, potentiellement côté CSS (feuille de style qui gère `.rc-fleche` ou un système de panneaux plus récent non repéré ce soir).

---

## 🗺️ Navigation rue par rue de PSM — TERMINÉE (12/12 scènes)

Toutes les scènes suivantes ont été codées dans `plateau-rue-centrale.js` cette nuit :
1. `psm-carrefour-musee` (Musée/Centre Commercial/Centre d'Affaires, 4 images selon arrivée)
2. `psm-carrefour-artisanal-scierie`
3. `psm-centre-multimodal` (point de départ officiel `RUE_CENTRALE_DEPART.republic.ville_a`)
4. `psm-ecole-phare`
5. `psm-dispensaire-port-plaisance`
6. `psm-tribunal-banque`
7. `psm-bar-imprimerie-commissariat`
8. `psm-marche-resto-chasse` (zone Marché → bâtiment `marche-psm`, pas une scène de rue)
9. `psm-hotel-mairie-place`
10. `psm-eglise-cimetiere` (zone unique → bâtiment fusionné, voir ci-dessous)
11. `psm-chantier-naval`
12. `psm-terrains-vente` → sous-scène `psm-terrains-lots` (5 lots, sur le modèle de `luthecia-terrains-lots`)

### Bugs corrigés en cours de route
- Zones Hôtel du Port / Place d'Armes inversées : corrigé.
- Zone Marché qui menait à tort vers la scène de rue Église/Cimetière au lieu d'ouvrir le bâtiment `marche-psm` (déjà existant avec son propre contenu) : corrigé.
- `notre-dame-mer` et `cimetiere-marin` étaient deux bâtiments séparés sans hall commun ; fusionnés en un seul bâtiment `notre-dame-mer` avec un hall d'accueil (nouvelle image), la salle `nef` existante, et une nouvelle salle `tombe` (placeholder, contenu à venir). `cimetiere-marin` retiré de la liste des bâtiments PSM.
- Plusieurs `flechesStyle` ajoutés pour corriger des positions par défaut inadaptées (voir régression ci-dessus : correction possiblement incomplète ou en conflit avec autre chose).

### Reste à faire
- **Régression flèches à corriger en priorité** (voir en tête de journal).
- Vérifier le carrefour Centre Artisanal/Scierie : accepté avec un seul retour fixe à l'origine (une seule entrée connue), mais a maintenant 2 entrées (Terrains à vendre + Musée) — vérifier la cohérence de navigation en jouant.
- Contenu de la salle "Tombe" (cimetière) à concevoir.
- Sous-scène des 5 lots PSM : xPct des lots posés à l'oeil, à vérifier/ajuster en jouant.

---

## 🏛️ Musée de Port Sainte Marie — création + contenu

- Bâtiment complet créé (`musee-port-sainte-marie`) : hall d'accueil (PNJ Soizic Le Gall à l'accueil, Yvon Le Gall conservateur) + 10 salles thématiques (Criminels, Maires, Personnalités, Entrepreneurs, Organisations, Plumes, Honneur Militaire, Unions Célèbres, Dynasties, Scandales).
- **Contexte narratif acté avec Fred** : Port-Sainte-Marie appartient historiquement à deux familles rivales, les **Le Gall** et les **Le Roux** — traité de façon parodique. Gentilé des habitants : **"Mariannais"**.
- **Principe du musée** : immortaliser/classer les meilleurs (et pires) joueurs par catégorie, mélange de stats et de votes (mécanique de calcul à détailler plus tard, différente selon les catégories — ex: un rôliste ne se juge pas aux mêmes critères qu'un min-maxer). Historique des anciens détenteurs de chaque titre à conserver (mémoire du jeu).
- **Images de salles reçues et intégrées ce soir** : Maires, Criminels, Personnalités. Il reste 7 salles sans image (Entrepreneurs, Organisations, Plumes, Honneur Militaire, Unions Célèbres, Dynasties, Scandales) + l'image du hall (reçue et intégrée en toute fin de session).
- **Prévu pour plus tard** : dupliquer ce même principe de musée à Luthécia, avec deux musées distincts (ville + pays).

---

## 🖼️ Méthode de travail Blender — bilan de la session précédente, confirmé validé cette nuit

- Décision actée : Blender n'est utilisé que ponctuellement, pour les scènes où le générateur d'images échoue à produire une composition cohérente — pas systématiquement. Confirmé efficace cette nuit : plusieurs scènes de rue PSM ont été générées directement par IA sans passer par Blender, avec de très bons résultats (ex. église/place d'armes/fortifications, carrefour Musée sous 4 angles).
- Workflow qui fonctionne bien : donner au générateur d'images une image de référence existante + des instructions précises de repositionnement/correction, plutôt que de tout décrire depuis un prompt texte vierge à chaque fois.
- **Piège récurrent identifié cette nuit** : les noms de fichiers réels dans `~/Downloads` de Fred diffèrent souvent de ce qu'on suppose (espaces vs underscores, accents, casse) — **toujours vérifier avec un `ls | grep` avant de lancer un `mv`** si le nom n'a pas été confirmé explicitement.
- Autre piège identifié : une image simplement affichée dans une conversation ChatGPT (URL `blob:...`) n'est pas automatiquement enregistrée sur le disque — il faut un vrai clic droit "Enregistrer l'image sous..." avant de pouvoir la déplacer/committer.

---

## 📝 Chantiers en attente (rappel)
- **Régression flèches de navigation PSM (priorité absolue prochaine session)**.
- Calendrier électoral pas à jour.
- Photo du Chef de Cabinet qui ne charge pas.
- Réorganiser le dossier `images/` en sous-dossiers (pays/ville/PNJ/bâtiments) — session dédiée à prévoir.
- Terminer les 7 salles du Musée restantes (images + éventuel contenu).
- Concevoir le centre frigorifique de PSM (matières périssables, poisson).
- Une fois PSM stabilisé : retour prioritaire sur **Luthécia** pour finir le tour des bâtiments (objectif principal de Fred), avant de revenir sur PSM par petites touches.
# Journal de session — Res Publica (28 juillet 2026)

## État du dépôt
- Session consacrée exclusivement au blockout 3D Blender pour PSM (pas de code touché, rien à committer côté `plateau.html`).

---

## 🎥 Blender — apprentissage et méthode validée

### Interface et raccourcis clavier
- Le clavier Mac de Fred n'a pas de pavé numérique, et plusieurs raccourcis standards (G, E, Tab pour mode édition) ne répondent pas dans son environnement. **Toujours passer par les menus** (Vue, Objet, Maillage) plutôt que par les raccourcis clavier tant que la cause n'est pas identifiée.
- Navigation viewport au trackpad : pincement à deux doigts pour zoomer (fonctionne bien). "Cadrer sur tout" redézoome sur toute la scène (normal) ; préférer "Voir la sélection" pour rester zoomé sur un objet précis.
- Positionner le curseur 3D : avec l'outil "Curseur 3D" actif dans la colonne d'outils à gauche, un simple clic gauche sur le viewport suffit (pas besoin de Maj+clic droit).
- "Sélection vers curseur" (Maj+S) copie X, Y **et Z** du curseur — penser à rectifier le Z ensuite si le curseur était au sol.
- Une caméra sélectionnée n'est pas forcément la caméra **active** de la scène (celle affichée en vue caméra) : utiliser Vue → Caméras → "Définir l'objet actif comme caméra".

### Plan de ville PSM importé
- Le plan (image de référence PSM) est un **Objet vide de type Image**, donc sans géométrie éditable (pas de mode édition possible, pas d'extrusion).
- Échelle réelle du plan : **Taille = 6.3m** pour l'ensemble de la carte (~30 bâtiments) → chaque bâtiment individuel ne fait que 0.2 à 0.5m de large dans la scène. Point de repère essentiel pour toute la suite (échelles caméras, cubes, etc.).

### Rues de PSM — nommées et tracées
Sept rues ont été définies et tracées sur un schéma de principe (à corriger/compléter librement si besoin en avançant) :
1. **Rue de la Corniche** — axe nord-sud, est de Notre-Dame de la Mer / Cimetière Marin
2. **Rue Tanguy Le Roux** — axe nord-sud, sépare quartiers ouest/est
3. **Rue des Quais** — bordure est, dessert Port Industriel et Port de Plaisance
4. **Rue des Artisans** — axe est-ouest, sépare nord/sud
5. **Rue de la Mairie** — quartier sud-ouest, dessert Place d'Armes/HDV
6. **Rue du Palais** — quartier sud-est, dessert Tribunal/Banque
7. **Rue du Marché** — diagonale, de Capitaine Sauvage/Chasse&Pêche à l'arrière de la Place d'Armes

### Méthode de caméra validée — vue "place publique" (plongée)
Pour une place avec plusieurs bâtiments cliquables à identifier (ex. Place d'Armes/HDV/Hôtel du Port), sur plan 2D plat, sans volume :
- Position Z ≈ 4-9m, Rotation X ≈ 40-65° (plongée douce), Rotation Z ajustée à l'orientation voulue, focale à ajuster au jugé (essais de 24mm à 100mm selon le cadrage voulu).
- **Valeurs qui ont fonctionné pour `Cam_RueMairie_01`** : Position (X=-4.5, Y=-1, Z=4), Rotation (X=40°, Y=0°, Z=285°), Focale=100mm.
- Méthode : dupliquer une caméra existante déjà bien réglée plutôt que repartir de zéro, positionner via curseur 3D + "Sélection vers curseur", puis ajuster à la main par tâtonnement en vue caméra (plus fiable que de calculer des coordonnées a priori).

### Test de vue "piéton" (corridor de rue) — en cours
- Sur un plan 2D plat, **impossible d'obtenir une vraie vue horizontale de type corridor** (façades qui encadrent la vue) : la caméra regarde par-dessus le plan et voit l'horizon à perte de vue. Ce n'est pas un bug, c'est une conséquence de l'absence de volume.
- Premier test de solution : ajout de deux cubes bruts (sans texture) représentant les volumes de Capitaine Sauvage et Chasse&Pêche, à l'échelle du plan (env. 0.3-0.5m de large, 8m de haut → Échelle Z=4 sur cube standard 2m).
- Caméra piéton `Camera_RueMarche.002` positionnée entre les deux cubes, Z=1.7m (hauteur d'yeux). Premiers essais concluants pour voir les bâtiments encadrer l'espace, mais réglage encore à peaufiner (distance/reculs, angle pour voir les bâtiments "en pied" du sol jusqu'en haut) — **non finalisé, à reprendre**.

### ⚠️ Décision importante sur l'usage de Blender
Blender ne doit **pas être utilisé systématiquement** pour chaque rue/scène. Principe retenu :
- Si le générateur d'images produit déjà un résultat satisfaisant directement (sans passer par Blender), **on garde ce résultat tel quel**, sans perdre de temps à reconstruire la géométrie dans Blender.
- Blender n'est utile que pour les cas où le générateur d'images échoue à produire une composition cohérente (comme la Rue du Marché), ou pour garantir une géométrie stable réutilisable dans le temps (plusieurs angles/moments d'une même rue).
- **Workflow prévu** : fournir au générateur d'images à la fois (1) le rendu Blender basique (composition/perspective/géométrie) et (2) une photo de référence de style (ambiance, architecture, lumière) pour guider le rendu final. Pas de reproduction pixel-perfect attendue, mais une approximation stylistique cohérente.

---

## 📝 Chantiers en attente (rappel, non traités cette session)
- Calendrier électoral pas à jour.
- Photo du Chef de Cabinet qui ne charge pas.
- Réorganiser le dossier `images/` en sous-dossiers (pays/ville/PNJ/bâtiments) — actuellement tout à plat.
- Concevoir le système de musée (local + national) plus en détail.
- Concevoir le centre frigorifique de PSM (matières périssables, poisson).
- Navigation rue par rue de PSM : coder tous les nœuds dans `plateau-rue-centrale.js` une fois les images prêtes (voir détail complet dans l'entrée du 27 juillet ci-dessous).
- Rue du Marché : finaliser le test de caméra piéton avec volumes (distance, angle "en pied"), ou abandonner cette rue au profit d'un rendu direct par générateur d'images si le résultat Blender ne progresse pas rapidement.

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
