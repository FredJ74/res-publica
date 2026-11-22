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

## Pays d'un poste : le registre, jamais la position (règle de Fred, 22/11/2026)

- **Le pays (et la ville) d'un poste se lit dans son registre** : `postes_attribues` (`country`, `city` ; `id` =
  `<pays>_<poste>_<ville|national>`) pour un poste nommé ; `cycles_electoraux` (`country`, `city`, `eluId` / `elus`)
  pour un poste élu ; la compagnie (`compagnie-<pays>-…`) pour un grade militaire. **Jamais**
  `personnages_donnees.country` / `state.country` (c'est la POSITION du voyageur, et les identifiants de ville sont
  partagés entre pays : `ville_b` = Montrouge et Krasnov), **jamais** la nationalité, jamais `poste->>'id'` seul.
- Une ligne du registre ne vaut que si la fiche du titulaire porte ce même poste (une seule fonction nommée à la
  fois) : une ligne orpheline ne donne rien. On ne modifie ni le registre ni `personnages_donnees.poste` pour
  « réparer » un affichage.
- **Un personnage en voyage garde son poste, son salaire et sa place dans les organigrammes de SON pays, et
  n'obtient jamais aucun pouvoir du pays où il se trouve.** Un ordre réservé se passe dans le pays du poste
  (règle du 05/11 : `exiger_poste`, `poste_autorite_de`, `ordre_generique_executer` « hors_de_son_pays »).
- Fonctions uniques — n'en écrivez pas d'autres :
  - serveur (`migrations/20261123120000_postes_pays.sql`) : `poste_detenu(nom, poste, pays, ville DEFAULT NULL)`
    (« ce personnage détient-il ce poste dans ce pays / cette ville »), `poste_pays_de(nom)` (pays du poste de la
    fiche), `poste_exerce(nom)` (le poste s'il est dans le pays de son poste, sinon NULL) ; `acteur_poste_courant`,
    `mon_poste_est_dans`, `exiger_poste` les utilisent ;
  - navigateur (`plateau-organisations-quetes.js`) : `posteDetenu(nom, poste, pays, ville)`, `paysDuPoste(nom)`,
    `posteExerceIci(poste)`, `titulairesRegistre(pays, poste, ville)`, cache `chargerRegistrePostes()` ; les
    organigrammes, `getTitulaireActuel`, `paysMandatPourOrdre` et le panneau du personnage les lisent ;
  - cron (`api/cron-minuit.js`) : `titulairesPostesPaysServeur(pays)`.
- Bancs : `outils/bancs/banc-postes-pays-pglite-20261123.cjs`, `banc-postes-pays-navigateur-20261123.cjs`.
- Migration appliquée en production le 22/11/2026 (contrôlée en lecture). La crue (`climat_crue_appliquer_interne`) lit le
  ministre de l'Intérieur par `poste_detenu` (marque `pp_crue_min`).

## Accueil du nouveau personnage (Fred, 22/11/2026)

- Interview d'accueil (Jodie Moitout en Républia, Vera Pravdina en Sovarka), six chemins par pays, trois étapes chacun,
  bulle des PA une seule fois : tout est décidé par le serveur (`accueil_*`, migration `20261123140000_accueil_interview`).
  Une étape « ordre » se valide dans `payer_ordre_interne` (marque `accueil_ordre_paye_v1`) ; n'ajoutez pas de
  validation côté navigateur. Réglages MJ : table `accueil_parametres` (page `admin-accueil.js`).

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
- `20261121170000_point_eau_puiser_mairie_krasnov` : nouvelles `point_eau_tranche_interne`, `point_eau_etat`, `point_eau_puiser`, table
  `climat_points_eau_puisages`, réglage `aliments_parametres.point_eau_bouteilles_tranche`, ordre `puiser_eau` (1 PA) ; `point_eau_remplir`
  renvoie `remplace_par_puiser` ; raccord dans `climat_consigne_interne` (marque `point_eau_puiser_v1`) ; sortie
  `rue_sorties_batiments` mairie → `krasnov-place-ours` supprimée. Appelle `payer_ordre_interne` (commune, non modifiée).
- `20261121180000_groupes_presents_masques_cachette` : nouvelles `presents_ici`, `se_cacher_chances`, `groupe_chef_de_interne`,
  `groupe_membres_avec_chef_interne`, `groupe_cacher_taux_interne` ; déclencheurs `zz_groupe_cachette_suivre` (sur `caches_pj`) et
  `zz_groupe_adhesion_signaux` (sur `groupes_pj_adhesions`) ; réglage `crim_parametres.cacher_malus_par_membre` ; **une ligne** ajoutée
  dans `se_cacher` (marque `groupe_cachette_v1`).
- `20261122100000_navigation_culs_de_sac_sovarka` : `rue_noeuds_serveur.directions` de `krasnov-place-ours` (retour à droite) et
  `krasnov-rue-hopital` (retour à gauche). Le camp des bûcherons (ouverture du goulag) n'est pas touché.
- `20261122110000_foret_egarement_rencontre_arrivee` : `aliments_parametres.foret_egarement_pct` = 50, nouveau
  `foret_rencontre_arrivee_pct` = 15 ; nouvelle `sovarka_foret_rencontre_arrivee_interne` ; raccords dans `sovarka_foret_aller`
  (`foret_rencontre_arrivee_v1`) et `sovarka_foret_rencontre` (« se laisser faire » dans la vue de la rencontre, `foret_rencontre_vue_v1`).
- `20261122120000_chantier_heures_ouvertes_commande_nuit` : nouvelles `chantier_commande_materiaux_interne`,
  `chantier_commande_nuit_interne`, `chantier_commande_avance_interne` ; raccords : `chantier_travailler` (heures toujours
  ouvertes `chantier_heures_ouvertes_v1`, commande du jour d'avance `chantier_commande_avance_v1`), `chantier_avance_heures_interne`
  (`chantier_heures_ouvertes_v1`), `chantier_jour_traiter` (plus de courrier de pénurie `chantier_sans_courrier_v1`, commande de
  nuit `chantier_commande_nuit_v1`). Le chantier garde `derniereCommande` et des entrées `commande_materiaux` / `manque_materiaux`
  dans `evenements`.
- `20261122130000_types_batiments_cinq` : `chantiers_paliers` = hangar, commerce_standard, commerce_premium, **logement**, building
  (les trois `logements_*` supprimés, aucun usage) ; nouvelles `logements_classiques_lots_interne` ; réécrites
  `logements_sociaux_lots_interne` (logement = 6) et `chantier_plan_normaliser_interne` (Logement fixe, Building ≤ 6 commerces et
  ≤ 14 appartements, catégorie sociale si terrain communal) ; remplacements contrôlés dans `terrain_permis_deposer`
  (durée, surface ≥ 2 000 m², libellé), `terrain_permis_decider` (libellé), `terrain_acquisition_commande` (liste),
  `traiter_prets_helvetia_quotidien` (valeur du Logement 70 000, 4 grilles). Marques `types_batiments_cinq_*`.
- `20261122140000_forum_images_stockage` : seau `forum-images` (public, 5 Mo, PNG/JPEG/WebP/GIF) ; politiques
  `forum_images_lecture` (lecture publique) et `forum_images_ecriture_joueur` (écriture du joueur connecté dans le dossier
  `<auth.uid()>/`). Le dossier `externes/` est écrit par le traitement de nuit (clé de service).
- `20261122150000_interview_accueil_invitation_serveur` (étape H) : l'invitation d'interview de Jodie Moitout est écrite par le
  serveur ; le navigateur perd le droit d'écrire au nom de Jodie.
- `20261122160000_krasnov_marche_unique`, `20261122161000_points_eau_une_fontaine_par_ville`, `20261122162000_pieces_inspecter_desinstaller`,
  `20261122163000_ordres_couts_lot_krasnov` (étape I) : marché unique de Krasnov (tables `marche_krasnov_*`, caisse `soviet_marche_ville_b`,
  ligne `graisses_points_vente` conservée), une fontaine par ville dans `climat_points_eau`, RPC `inspecter_piece`, `desinstaller_lire`,
  `desinstaller_materiel`, tarifs dans `ordres_couts` (594 ordres payants, listes en dur et seeds à jour).
- `20261122180000_informateurs_refonte` (étape K) : 97 informateurs PNJ ; raccords `rumeur_ecoute_jauges_interne`
  (`informateurs_ecoute_payante_v1`), `crim_enquete_taux_interne` (`informateurs_piste_v1`, `informateurs_taux_v1`, `informateurs_pistes_v1`).
- `20261122200000_inventaire_direct_capacite` : colonne `personnages_donnees.capacite_inventaire` (100, de 1 à 10 000) ;
  `inventaire_place_restante(jsonb, integer)` (la forme à un argument prend la capacité du joueur connecté), `inventaire_capacite`,
  `inventaire_unites_interne`, `inventaire_place_destinataire_interne` ; `inventaire_abandonner(…, p_qte)`, `objet_abandonne_ramasser(p_id, p_qte)`,
  `inventaire_donner` (refus `destinataire_plein`), `inventaire_reception_etat` (+ `capacite`), `admin_inventaire_capacite_fixer/lire` ;
  remplacement contrôlé dans **`inventaire_deposer_interne`** (commune, marque `inventaire_capacite_v1`) ; `personnages_signaux_trg` réécrite
  (inventaire et capacité) ; déclencheurs `zz_objets_recus_signaux`, `zz_objets_abandonnes_signaux`.
- `20261122210000_foret_groupe_combat_meute` : table `sovarka_foret_journal` (RPC `sovarka_foret_journal_lire`) ; meute = trois loups
  (`sovarka_foret_creature_interne`, `sovarka_foret_faune_creer_interne`, `sovarka_foret_combat_meute_interne`, `sovarka_foret_morsure_interne`) ;
  `sovarka_foret_couper` (le membre coupe pour lui), `sovarka_foret_issue_combat_interne` (butin au chef une fois, par loup abattu) ;
  `combat_rapport_lignes_interne` ; **remplacements contrôlés dans des fonctions communes** : `militaire_bataille_rapport`
  (`combat_rapport_lignes_v1`), `militaire_bataille_appliquer` (`foret_morsure_v1`), `militaire_bataille_combattants`
  (`foret_meute_griffes_v1`), `combat_ouvrir_interne` (`foret_meute_engagements_v1`), `combat_finaliser_interne` (`foret_meute_issue_v1`),
  `militaire_bataille_etat` (`foret_meute_nom_v1`) ; forêt : `sovarka_foret_aller`, `sovarka_foret_lire` (`foret_groupe_membres_v1`),
  `sovarka_foret_rencontre` (`foret_meute_retrait_v1`, `foret_journal_groupe_v1`). Batailles militaires inchangées.

- `20261122230000_sante_socle` : `sante_parametres` (MJ : `admin_sante_parametres_lire/fixer`), `sante_param`, `sante_facteur_robustesse`,
  `sante_perte_combat_interne`, `sante_modulation_moral`, `sante_gagner_interne`, `sante_perdre_interne`, table `personnage_evenements`
  + `personnage_evenement_ajouter_interne` + RPC `personnage_evenements_lire`, accroche `sante_reveil_interne`.
- `20261122231000_sante_combat` : `sante_combat_coup_pj_interne` ; remplacements contrôlés dans des **fonctions communes** :
  `militaire_bataille_appliquer` (`sante_combat_*`), `police_combat_personnage_interne` (`sante_police_*`),
  `militaire_bataille_neutralisation_terminale_interne` (`sante_coma_pa_v1`), `militaire_bataille_round` (`foret_meute_derniere_fuite_v1`,
  `combat_rapport_etats_fin_v1`), 20 gardes « Santé ≤ 0 » retirées (`sante_zero_libre_*`, liste dans RELAIS), `impact_marquer_traite`
  et 5 lecteurs de `stats_affaiblies` (`sante_sans_*`) ; réécrites : `combat_rapport_lignes_interne`, `sovarka_foret_issue_combat_interne`
  (butin par loup tué, reste d'une pile au sas) ; nouvelles : `combat_etat_ligne_interne`, `combat_rapport_etats_rafraichir_interne`,
  `sovarka_foret_meute_derniere_fuite_interne` ; réglage `aliments_parametres.foret_meute_fuite_apres_morts` = 2.
- `20261122232000_sante_consommation` : tables `sante_repas_categories`, `sante_sommeil_lieux`, `sante_sommeils` ; 15 fonctions de
  production modifiées (`sante_conso_*`) : `maladie_verre_interne`, `tournee_cloturer_boire`, `commerce_vendre_produit`,
  `consommer_sur_place_commerce`, `inventaire_consommer`, `restaurant_diner_servir`, `diner_commerce_servir_interne`,
  `service_etage_commander`, `hotel_service_etage_commander`, `marche_krasnov_manger`, `pa_repos_nocturne` (Santé du sommeil + réveil),
  `clinique_nuitee_marquer_repos`, `clinique_nuitee_consommer`, `recevoir_soin`, `ordre_generique_executer` ; nouvel ordre `sante_se_nourrir`.
- `20261122233000_sante_maladies_medicaments` : `maladies_parametres.perte_sante` et `guerison_spontanee`, maladie `mst` ; tables
  `escort_relations`, `mst_en_attente`, `medicaments_stocks` ; remplacements contrôlés `maladie_contracter_interne`, `admin_maladie_modifier`,
  `escort_intimite` (`sante_maladies_v1_*`) ; réécrites `sante_reveil_interne`, `pharmacie_etat`, `pharmacie_acheter_interne` ;
  nouvelles `mst_relation_interne`, `produire_medicament`, `usine_medicaments_etat` et fonctions d'appui.
- `20261122234000_medecin_montrer` : table `medecin_propositions` ; RPC `medecin_etat`, `medecin_proposer`, `medecin_repondre`,
  `medecin_propositions_lire`, `objet_montrer`, `sante_paliers_lire` ; `personnages_meme_lieu_interne`, `piece_plein_air_interne` ;
  remplacements contrôlés `inspecter_piece`, `desinstaller_lire`, `desinstaller_materiel` (`plein_air_*`) ; `ordres_couts`
  medecin_diagnostiquer (1 PA), medecin_soigner (2 PA).
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
