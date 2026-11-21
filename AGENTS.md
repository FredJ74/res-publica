# Règles communes des agents — Human Gambit

Ce fichier s'adresse à **tous les agents de code** qui travaillent sur ce dépôt
(Codex, Claude). Claude le lit via `CLAUDE.md`, Codex le lit directement.


**Avant toute décision de game design, lire `CONSTITUTION.md`** (document fondateur I sur IV de Fred, 2 octobre 2026) : elle dit pourquoi les règles sont ce qu'elles sont, et à quoi l'on reconnaît qu'une règle trahit le projet.
**L'état du socle et des mécaniques est dans `ARCHITECTURE.md`** : les couches du jeu, l'inventaire des mécaniques et la marche à suivre pour un nouvel empire. Le tenir à jour.
**Pour auditer les règles, leur code, les preuves de test et la jouabilité, commencer par [`referentiel-game-design/README.md`](referentiel-game-design/README.md).** Ce dossier est un référentiel en constitution : ses cases « non vérifié » ne valent jamais preuve de fonctionnement, et les décisions restent dans les documents métier et la Constitution.

## Qui fait quoi

- **Fred est le game designer.** Il ne code pas. Il décide du gameplay, du
  ton, de l'équilibrage et de ce qui part en bêta.
- **Les agents codent.** Ils implémentent, testent et documentent.
- On parle à Fred **en français, sans jargon** : ce qui change dans le jeu,
  comment le tester, ce qui reste à décider. Pas de commandes à taper.
- Toute question de design (règle du jeu, prix, équilibrage, texte RP) se
  pose à Fred **avant** de coder, jamais tranchée par l'agent.

## Décisions de game design : aucune décision oubliée

**Avant de solliciter un arbitrage de Fred, rechercher si la question a déjà été tranchée.**
L'agent consulte, selon le sujet, `CONSTITUTION.md`, les documents de game design,
`ARCHITECTURE.md`, `RELAIS.md`, les issues GitHub, les échanges et comptes rendus
accessibles, ainsi que les discussions des PR. Il distingue clairement **règle décidée**,
**règle implémentée** et **règle testée** : l'absence d'une fonction dans le code ne
constitue jamais la preuve qu'une décision de gameplay n'existe pas.

- Une décision antérieure retrouvée s'applique sans reposer la même question.
  Citer sa source dans le chantier et signaler l'écart entre décision et code.
- Si les documents se contredisent, rechercher la décision explicite la plus
  récente de Fred ; **ne jamais remplacer silencieusement une règle par une
  hypothèse technique**. Ne demander à Fred que l'arbitrage qui reste réellement
  indéterminé, après cette recherche.
- Toute nouvelle décision explicite de Fred, ou décision ancienne retrouvée mais
  absente des références, doit être **consignée dans un document de game design
  versionné et reliée à l'issue concernée**. Mettre aussi `RELAIS.md` à jour pour
  assurer la transmission aux autres agents, sans transformer un compte rendu
  de session en seule source de vérité.
- Lors de la reprise d'un chantier, vérifier les règles qui le concernent
  **avant** de modifier le code ou de demander un nouvel arbitrage.

**Précédent #135 — sécurité privée des chantiers (décision de Fred déjà prise).**
Les « vigiles de chantier » sont simplement des **agents de sécurité privée ordinaires**.
**Deux socles exclusivement** : (1) embauche, groupe, déplacement et présence des PNJ ;
(2) dissuasion des actes illégaux, détection, confrontation et emprisonnement selon
le fonctionnement policier existant. L'employeur déplace librement son agent ;
aucune affectation obligatoire au chantier, aucun statut de vigile, aucun moteur
parallèle, aucun nouveau lieu de détention. L'agent présent impose les malus
de sécurité applicables et peut interpeller un PJ recherché **uniquement après
sa détection effective**. Si l'interpellation réussit, le parcours carcéral
policier existant s'applique ; le récit précise que l'agent privé a remis le PJ
à la police avant sa conduite en prison (décisions explicites de Fred, 27/10/2026).
Le raccordement reste à tester en production, ne pas le présenter comme réalisé.

## Une seule réalité : celle du serveur (règle de Fred, 24/10/2026)

- **L'écran ne doit jamais pouvoir afficher autre chose que ce que le
  serveur a décidé et enregistré.**
- Tirages, gains, pertes, droits d'accès, échéances : décidés par une
  fonction serveur, jamais par `Math.random()`, `Date.now()` ou un cache du
  navigateur.
- Pas de message de succès avant la réponse du serveur ; un refus est nommé.
- Pas de montant ou d'effet annoncé que l'écran a calculé lui-même : il
  affiche ce que le serveur renvoie.
- **Une fonction serveur écrit la fiche dans `personnages_donnees`, jamais par
  la vue `personnages`** (porte de l'écran, qui corrige en silence l'argent et
  les champs protégés). Leçon du 30/10/2026 : 150 000 FR d'un joueur perdus au
  retrait Helvetia. La base refuse désormais cette écriture dans une RPC
  (`fiche_ecriture_serveur_par_la_vue`) et le test
  `outils/bancs/test-ecritures-fiche-serveur.mjs` bloque toute migration qui la
  réintroduit.

## Le relais entre agents

Fred alterne les agents : il travaille avec l'un jusqu'à sa limite de
session, puis bascule sur l'autre. Le travail doit donc pouvoir être
**repris à tout moment** par un autre agent.

1. **En arrivant**, lire `RELAIS.md`. S'il indique un chantier en cours,
   le reprendre **sur sa branche**, sans en créer une nouvelle.
2. **Une branche par chantier**, nommée `<agent>/<sujet>-AAAAMMJJ`
   (ex. `claude/squatteurs-20261024`). Jamais de commit direct sur `main`.
3. **Sauvegarder souvent** : après chaque étape qui fonctionne, commit et
   push. Une limite de session ne doit jamais faire perdre plus que
   l'étape en cours.
4. **À chaque push, mettre à jour `RELAIS.md`** : chantier, branche, PR,
   ce qui est fait, ce qui reste, comment Fred peut tester.
5. **Une pull request par chantier**, ouverte dès le premier push (en
   brouillon si le travail n'est pas fini). **L'agent fusionne lui-même**
   dans `main` (= mise en bêta) dès que le chantier est fini et que les
   contrôles passent, sans attendre le feu vert de Fred (décision de Fred,
   25/10/2026). Il ne fusionne jamais un chantier qui attend une décision
   de design, ni une branche en conflit, et il dit à Fred ce qui est parti
   en bêta et comment le tester.
   **Exception (décision de Fred, 17/11/2026)** : un chantier d'image seule
   se fusionne dès que les contrôles rapides sont verts, sans attendre
   « bancs-hors-production », qui tourne aussi chaque nuit sur `main`.
6. **Chantier terminé et fusionné** : vider la section « En cours » de
   `RELAIS.md` et ajouter une ligne dans « Derniers chantiers ».

Le backlog vit dans les **issues GitHub** ; les chantiers s'y réfèrent par
leur numéro (#57, #135…).

## Sécurité du code

- Ne jamais réécrire un fichier entier de mémoire : modifications ciblées
  sur le contenu réel du fichier.
- Vérifier le contenu réel (fonctions et variables présentes), pas
  seulement que la syntaxe passe.
- En cas de doute sur l'état d'un fichier, Git fait foi (`git log -S`).
- **Base Supabase** : suivre `WORKFLOW-SUPABASE.md` sans exception.
- Freemium **jamais pay-to-win** : le premium est cosmétique ou de confort.
- Aucune clé ni secret dans le dépôt ou les messages.

## Fonctions serveur Vercel : 12 au maximum (incident du 11/11/2026)

L'offre Vercel du projet accepte **12 fonctions serveur** par déploiement. Chaque fichier `api/xxx.js` sans
préfixe `_` en est une ; une 13ᵉ fait échouer **tous** les déploiements sans que rien ne casse ailleurs
(la production cesse simplement d'être mise à jour). Un nouveau point d'entrée s'écrit en module
`api/_xxx.js` et passe par une fonction existante (redirection `vercel.json` + délégation, comme
`/api/aide` → `/api/chat?mode=aide`). Le banc `banc-vercel-douze-fonctions-20261111.cjs` le vérifie.
Après une fusion, vérifier que le statut Vercel de `main` est vert.

## Charte graphique

- **Habillage retenu : fond bleu-gris** (décision de Fred, 03/11/2026 ; l'ancienne charte
  « ardoise et or » est abandonnée, issue #143 fermée). La source unique est `style.css` :
  fenêtres `.modal-box` en `#202a36` bordées d'or doux `#a98d56`, texte `#e2e9f1`, champs
  `#1b2531`, boutons `#344354` à texte or `#e5c477`.
- Toute fenêtre pop-up utilise les classes communes : conteneur `cpj-dialogue`, texte
  secondaire `cpj-note`, boutons `cpj-touche` (`cpj-primaire` pour l'action principale),
  champs `cpj-champ` (déjà déclinées en bleu-gris). Pas de couleurs en dur dans le JavaScript :
  si une classe manque, l'ajouter dans `style.css`. L'ancienne palette brune (`#0f0d05`,
  `#8a8060`, `#2a2010`…) ne doit plus être recopiée.
- Pas de campagne de reprise des anciennes fenêtres : `style.css` les habille déjà en
  bleu-gris ; on corrige une fenêtre seulement quand on y travaille ou si elle s'affiche mal.

## Catalogues i18n et livraison statique

Les fichiers `i18n/*resources.js` restent les sources originales lisibles. Après
chaque ajout/modification de catalogue, lancer
`node outils/generateurs/compresser-catalogues-i18n.cjs` et committer les paquets
`i18n/packed/*.js.br` avec `outils/audits/I18N-CATALOGUES-TRANSPORT.json`.
`--check` vérifie que chaque paquet restitue exactement sa source. Les URL JS
canoniques et le moteur i18next restent inchangés : Vercel sert la compression
HTTP native via `vercel.json`. Ne pas relever le plafond de payload pour une
traduction et ne pas modifier d’images pour contourner le contrôle.

## Coordination Claude Code / Codex (Claude, 21/11/2026)

Base de production **gelée** jusqu'à nouvel ordre de Fred : Codex y termine le goulag. Claude n'y écrit plus rien
(ni migration, ni donnée, ni fichier de stockage) ; il prépare, teste sur un banc PGlite et laisse en attente.

### Cinq migrations appliquées en production le 21/11/2026 par Claude (on ne les réécrit ni ne les annule)
| Migration | Objet | Tables et fonctions touchées |
|---|---|---|
| `20261121070000_climat_douze_heures_gare_accueil` | gare jamais inondée ; accueil du nouveau personnage pendant un événement (durées 12 h, remplacées par 090000) | `climat_zones_inondables` (contrainte `climat_zones_jamais_gare`), `climat_parametres`, `climat_evenements`, `equipements_installes` ; table `climat_accueils` ; `climat_lieu_est_gare_interne`, `climat_accueil_interne`, `climat_accueil_vu_interne`, `climat_accueil_lire`, `climat_accueil_vu` ; raccords dans `climat_creer_interne`, `climat_texte_alerte_interne` |
| `20261121090000_climat_six_heures_pays_sacs_eau` | 6 heures ; lieu protégé par sacs ouvert ; un seul événement à la fois par pays ; consignes ; eau gratuite | `climat_parametres`, `climat_evenements`, `equipements_installes`, `aliments_parametres`, `evenements_globaux` ; tables `climat_lieux_vente`, `climat_points_eau` ; `climat_lieu_protege_interne`, `climat_batiment_inonde_interne`, `climat_espacer_interne`, `climat_nom_type_interne`, `climat_passe`, `climat_vente_interne`, `climat_points_eau_lister`, `point_eau_remplir`, `climat_consigne_interne`, `climat_texte_alerte_interne`, `climat_evenement_json_interne`, `climat_etat` ; raccords dans `climat_crue_appliquer_interne`, `sacs_sable_poser`, `climat_alertes_publier_interne`, `climat_accueil_interne` |
| `20261121100000_incidents_client` | journal des vues de rue restées vides (filet « La ville se charge encore… ») | table `incidents_client` ; `incident_client_noter` |
| `20261121110000_climat_parades_vente` | parades climatiques en vente dans chaque pays | `aliments_parametres`, `climat_boutiques`, `climat_lieux_vente` ; `climat_prix_interne`, `climat_objet_interne`, `climat_consigne_interne`, `climat_parades_verifier_interne` |
| `20261121120000_climat_parades_sovarka` | sels à moitié prix en Sovarka ; bidons au garage de Novomirsk | `climat_boutiques` ; `pharmacie_prix_pays_interne`, `climat_prix_pays_interne`, `climat_bidons_meme_lieu_interne`, `climat_parades_verifier_interne` ; raccords dans `boutique_climat_acheter`, `boutique_climat_etat`, `pharmacie_acheter_interne`, `pharmacie_etat`, `climat_consigne_interne` |

**Pour Codex** : horodater les migrations du goulag **après `20261121120000`** (ou les appliquer en acceptant cet
ordre), sans jamais réécrire ni annuler ces cinq migrations. Aucune ne touche une table ou une fonction du goulag.

### Appliqué par Claude le 21/11 au soir (pause levée par Fred ; goulag vérifié désactivé avant et après)
- `20261121130000_climat_horaire_cadence_catastrophe_sacs` : `climat_*` (heure au hasard, brouillard 1/mois, préavis de 48 h garanti,
  `debut_prevu`), `catastrophe_couts_interne`, `catastrophe_etat`, `catastrophe_proposer`, `catastrophe_declarer`, `climat_crue_appliquer_interne`,
  `sacs_sable_poser` ; suppression de `climat_sacs_reste_pct_interne`, `climat_sacs_poses_interne`, colonne `climat_protections.sacs`.
- `20261121140000_chantier_jour_avance` : nouvelles `chantier_avance_heures_interne`, `chantier_avance_enregistrer_interne`,
  `chantier_avance_nuit_interne` ; **jonctions** : deux insertions dans `chantier_travailler` (marques `chantier_jour_avance_v1`,
  `chantier_jour_avance_enregistrer_v1`) et **un seul appel** dans `chantier_jour_traiter`, juste avant `jourTraite`
  (marque `chantier_jour_avance_nuit_v1`). `api/cron-minuit.js` n'est pas modifié.

- `20261121150000_foret_krasnov_clairiere_retour` : `sovarka_foret_aller` (réécrite : forêt, non commune), `sovarka_foret_vue_interne`,
  nouvelle `sovarka_foret_tirer_vue_interne`, raccord dans `sovarka_foret_couper` (marque `foret_clairiere_v1`), `navigation_lieux_regles`
  (pièce `foret_clairiere`), réglage `aliments_parametres.foret_egarement_pct`. N'utilise pas les nœuds du camp de bûcherons de Codex.
- `20261121160000_presse_noms_cites_monde_reel` : nouvelle `journal_noms_cites_interne`, raccord dans `journal_edition_lire`
  (marque `presse_noms_cites_v1`), correction de quatre `journal_editions` (« soviétique » → « de Sovarka »).

### Fonctions communes et points de jonction
- **Traitement de nuit** : `api/cron-minuit.js` (commun : il appelle aussi `sovarka_goulag_controle_minuit`, tâche
  `controle_goulag_sovarka`). Claude **ne le réécrit pas** : la nuit des chantiers reste l'appel existant
  `sbRpc('chantier_jour_traiter', { p_terrain_id })` ; la logique nouvelle vit dans une fonction SQL séparée,
  appelée par une seule ligne dans `chantier_jour_traiter`.
- **Climat** : tâche planifiée `climat_passe` (17 de chaque heure), propre au climat.
- **Communs touchés par Codex** (Claude n'y touche pas) : `justice_rendre_sentence` (raccord goulag), lignes de
  `rue_noeuds_serveur` du camp de bûcherons de Krasnov (`krasnov-rue-ecole-foret`, `krasnov-camp-bucherons`) — à
  reprendre avec Codex avant le chantier de la forêt de Krasnov.
- Claude ne modifie **aucun** fichier, table ou fonction propre au goulag (`sovarka_goulag_*`, `goulag_*`, `api/_goulag-*`).
