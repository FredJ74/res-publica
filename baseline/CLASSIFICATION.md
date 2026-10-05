# Classification des données du monde initial

> Chantier 2C. **Aucune donnée n'a été modifiée** : ce document classe, il ne
> transforme rien. Aucun fichier de seed n'existe encore.

Pour chacune des **252 tables**, ce chantier répond à une seule question : *cette
donnée doit-elle exister dans une installation neuve du jeu ?*

La réponse machine est dans `classification-donnees.csv`, une ligne par table,
séparateur `;`. Ce document explique les décisions et rassemble ce qui reste à
arbitrer.

## Les catégories

| | Catégorie | Définition |
|---|---|---|
| **A** | socle générique | nécessaire au moteur, indépendant de tout empire |
| **B** | contenu initial d'empire | définit l'état voulu d'un empire neuf (Républia, référence) |
| **C** | état vivant | produit par les joueurs, le temps, l'économie, les historiques |
| **D** | mixte | contient les deux, ou mêle moteur et contenu faute de dimension empire |

## Les stratégies

| Stratégie | Ce que 2E devra faire |
|---|---|
| `seed_complet` | reprendre toutes les lignes telles quelles |
| `seed_filtre` | reprendre certaines lignes ou certaines colonnes seulement |
| `reconstruction_explicite` | **la base actuelle n'est pas la référence** : l'état initial voulu doit être écrit |
| `structure_seule` | créer la table vide |
| `hors_baseline` | ne pas créer du tout (artefacts de bascule, tables mortes) |

## Répartition

| Catégorie | Tables | Part |
|---|---|---|
| A — socle générique | **36** | 14,3 % |
| B — contenu initial d'empire | **22** | 8,7 % |
| C — état vivant | **173** | 68,7 % |
| D — mixte | **21** | 8,3 % |

| Stratégie | Tables |
|---|---|
| `structure_seule` | 170 |
| `seed_complet` | 57 |
| `reconstruction_explicite` | 15 |
| `hors_baseline` | 6 |
| `seed_filtre` | 4 |

**76 tables entrent dans le seed.** Les deux tiers du schéma naissent vides.

> Ces chiffres intègrent les arbitrages du 5 octobre 2026 (voir plus bas). Avant
> eux, la répartition était A 36 / B 21 / C 169 / D 26 et la surface de seed
> comptait 80 tables. Quatre tables en sont sorties parce que leur contenu est
> **engendré par les mécanismes du jeu** et non posé par un seed ; une y est
> entrée parce que ses valeurs sont désormais décidées.

### Par domaine

| Domaine | A | B | C | D | Total |
|---|---|---|---|---|---|
| économie | 12 | 3 | 14 | 11 | 40 |
| personnage et présence | 0 | 3 | 25 | 1 | 29 |
| militaire | 0 | 3 | 20 | 2 | 25 |
| socle PNJ | 8 | 3 | 11 | 3 | 25 |
| finances publiques | 10 | 0 | 9 | 4 | 23 |
| presse | 0 | 2 | 13 | 0 | 15 |
| politique et élections | 0 | 2 | 11 | 1 | 14 |
| assemblée | 2 | 0 | 8 | 1 | 11 |
| justice | 0 | 0 | 9 | 1 | 10 |
| renseignement | 0 | 2 | 8 | 0 | 10 |
| immobilier et territoire | 0 | 0 | 8 | 2 | 10 |
| communication | 1 | 0 | 9 | 0 | 10 |
| sport | 0 | 2 | 7 | 0 | 9 |
| banque | 0 | 0 | 8 | 0 | 8 |
| postes et institutions | 3 | 1 | 3 | 0 | 7 |
| divers et technique | 0 | 0 | 6 | 0 | 6 |

## Comment la décision a été prise

Jamais sur le nom seul. Trois signaux croisés, tous relevés dans la base ou le
dépôt et repris dans le CSV :

1. **Le nombre de lignes réel** (`count(*)`, jamais `reltuples`).
2. **Le nombre de migrations qui y font un `INSERT` de niveau migration** —
   calculé sur les 539 migrations archivées plus les 184 fichiers du dépôt, **avec
   neutralisation des corps de fonction**. Un `INSERT` écrit *dans* une RPC n'est
   pas un seed : c'est du code. Sans cette précaution, `mails` et `detentions`
   passeraient pour des tables semées. 81 tables sur 252 portent un vrai seed.
3. **Qui écrit en jeu** : fonctions citant la table, déclencheurs, droits
   d'écriture du client.

Une table semée par migration, qu'aucune fonction n'écrit et sans dimension
d'empire est du socle. Semée et portant une colonne `pays` ou des noms propres,
c'est du contenu. Semée **et** écrite en jeu, c'est mixte.

## Les décisions de game design déjà prises, et leur effet

| Décision | Effet sur la classification |
|---|---|
| Les PNJ existent dès l'initialisation, dans leur **état initial voulu** | `pnj_membres`, `pnj_soldats_metier`, `pnj_possessions` passent en **D / seed filtré** : l'identité est semée, le vécu ne l'est pas |
| Les institutions reçoivent leurs **dotations initiales** | `caisses_batiments` passe en **D / reconstruction explicite** : la ligne existe, le solde est à écrire |
| Les **postes institutionnels PNJ** sont occupés dès le départ | `titulaires_pnj` passe en **B / seed filtré** : les titulaires PNJ, jamais un titulaire PJ hérité de la bêta |
| Les **élections** repartent de zéro | `cycles_electoraux`, `candidatures`, `votes_electoraux` → **C / structure seule** |
| Le **championnat** repart de zéro | `championnat`, `championnat_tentatives`, `entrainements_football` → **C / structure seule** |

## Les PNJ, en détail

Le socle PNJ se lit à six niveaux, et seuls les trois premiers entrent dans un
monde neuf.

| Niveau | Tables | Catégorie |
|---|---|---|
| **Règles du socle** — classes, axes d'autorité, profils de métier, fonctions du décor, institutions propriétaires, règles de mouvement | `pnj_familles_classes`, `pnj_axes_autorite`, `pnj_metiers_profils`, `pnj_fonctions`, `pnj_institutions`, `pnj_mouvement_individuel` | **A**, seed complet |
| **Identités authored** — référents, candidats à l'embauche, employeurs, escorts, passeurs, couvertures et identités réelles du renseignement | `pnj_referents`, `pnj_candidats_catalogue`, `pnj_employeurs`, `escorts_catalogue`, `escorts_agences`, `contacts_organisations_passeurs`, `renseignement_couvertures`, `renseignement_identites_reelles` | **B**, seed complet |
| **Postes institutionnels** | `titulaires_pnj`, `assemblee_sieges` | **B / D**, seed filtré |
| **Population et métier** — les 105 membres, les 96 soldats, les possessions | `pnj_membres`, `pnj_soldats_metier`, `pnj_possessions` | **D**, seed filtré |
| **Miroirs dérivés** — recalculés au premier passage | `pnj_force_publique_metier`, `pnj_employes_metier`, `pnj_militants_metier` | **C**, structure seule |
| **Vécu** — relations sociales, mémoire pédagogique, confidente, événements | `pnj_social_relations`, `pnj_referents_pedagogie`, `pnj_social_escort_choisi`, `pnj_evenements` | **C**, structure seule |

La frontière délicate est dans `pnj_membres` : la famille, la classe, le métier et
le propriétaire sont du contenu ; la position, le leader courant, les PA et la mort
sont du vécu. **Les tables `zz_snap_cka_*` existent précisément parce que cette
frontière a déjà posé problème lors de la bascule du 27 septembre.** Elles sont
classées `hors_baseline`.

## L'économie, en détail

| Nature | Tables | Catégorie |
|---|---|---|
| **Paramètres purs** — constantes, prix de rachat, chaînes, paliers, dotations de type | `entreprises_constantes`, `entreprises_prix_rachat`, `chaines_production_usine`, `chantiers_paliers`, `chantiers_besoins_jour`, `commerces_types`, `commerces_dotations`, `usines_rachat_config` | **A**, seed complet |
| **Miroirs de `data.js`** — à **régénérer**, jamais à copier | `ordres_couts` (405), `ressources_economie`, `pa_bonus_differes`, `postes_nommes_regles` | **A**, reconstruction explicite |
| **Catalogue d'objets** — générique dans sa forme, Républia dans son contenu | les 6 tables `catalogue_*`, `recettes_commerce` | **D**, seed complet + séparation à prévoir |
| **Implantations** — commerces, entrepôts, structures médicales, imprimeries | `entreprises`, `entrepots_par_ville`, `structures_medicales`, `imprimeries_declarees` | **D / B** |
| **Soldes et budgets** — l'état initial voulu est à écrire | `caisses_batiments`, `budgets_nationaux`, `budgets_municipaux`, `budgets_clubs` | **D**, reconstruction explicite |
| **Journaux et preuves** — idempotence, ventes, apports, écarts | `apports_matieres`, `productions_references`, `ventes_snapshots`, `entrepot_journal`, `ordres_couts_ecarts`, `ordres_couts_inconnus`, `fonds_debits`, `caisses_mouvements_clients` | **C**, structure seule |

Les quatre tables `*_empreinte` sont en `structure_seule` : elles seront recalculées
à la pose du seed, jamais copiées.

## Ce qui est implicitement Républia faute de dimension empire

Ces tables n'ont **aucune colonne `pays`** et portent pourtant du contenu propre à
Républia. Elles alimentent le futur chantier de séparation moteur/contenu.

| Table | Lignes | Ce qui est spécifique |
|---|---|---|
| `catalogue_generique_type` | 88 | identifiants `menu_psm`, `tshirt_psm`, `casquette_montrouge` |
| `catalogue_generiques` | 84 | idem |
| `catalogue_correspondance_legacy` | 58 | correspondances vers d'anciens identifiants Républia |
| `catalogue_familles` | 40 | — forme générique, seed Républia |
| `recettes_commerce` | 37 | identifiants de lieux Républia |
| `militaire_armes_bonus` | 16 | la colonne `note` porte « habillage Port-Sainte-Marie » |
| `catalogue_types` | 14 | — |
| `catalogue_variantes` | 6 | — |
| `entrepots_par_ville` | 5 | 5 entrepôts de Républia |
| `niveaux_prison` | 4 | 4 niveaux, aucun rattachement d'empire |
| `structures_medicales` | 3 | 3 structures de Républia |

## Données dont l'état initial voulu ne peut pas être déduit de la base

Dix-sept tables sont marquées `reconstruction_explicite`. Pour chacune, **le
contenu actuel n'est pas une référence** et le seed devra être écrit, pas copié.

Le cas le plus net est `dotations_amorcage_caisses`. Ses 159 lignes ressemblent à
un barème de dotation, mais ses colonnes `solde_avant`, `montant_verse`,
`solde_apres` et `applique_ts` en font un **journal d'idempotence** : elles disent
ce qui *a été* versé, pas ce qui *doit l'être*. C'est pourtant la seule trace
chiffrée existante. Le barème d'un monde neuf doit être écrit ailleurs.

## Arbitrages rendus le 5 octobre 2026

| Décision | Effet |
|---|---|
| Les recettes ont une granularité **ville**, pas empire | `recettes_production` passe **D → B**. **Dette de dimensionnement** : la table ne porte que `pays`, aucune colonne ville — la granularité voulue n'est pas exprimable en l'état. `recettes_commerce`, elle, porte déjà `villes_autorisees` (26 recettes sur 37 y sont restreintes) |
| Les dotations d'amorçage sont définies **par empire** | `caisses_batiments` et `dotations_amorcage_caisses` restent en reconstruction explicite ; les montants de Républia seront fixés à la construction de son état initial |
| Les **directeurs d'usine PNJ** sont en poste dès le départ | `directeurs_usine` passe **D → B**, seed complet |
| Les clubs partagent les **mêmes règles**, qui relèvent du socle | `clubs_sportifs_regles` passe **D → B** — car la table *ne contient aucune règle* : c'est un doublon du référentiel des clubs (voir ci-dessous) |
| Un monde neuf comporte des **organisations préexistantes** | `organisations` reste **C / structure seule** : les organisations institutionnelles existent mais le moteur les crée paresseusement, elles ne se sèment pas |

### Deuxième série d'arbitrages, rendus le 5 octobre 2026 au soir

Les sept décisions que le chantier 2E avait consignées comme ouvertes ont été
rendues. Leur trace complète est dans `DIFFERENCES-DELIBEREES.json`, bloc
`arbitrages_du_5_octobre_2026`.

| Décision | Effet sur la classification |
|---|---|
| Les 96 soldats actuels ont été engendrés **pour tester la carrière militaire** pendant la bêta. Ils restent dans la base de bêta et ne font pas partie de l'état initial. | `pnj_membres`, `pnj_soldats_metier`, `pnj_possessions` passent **D → C** et `seed_filtre` → `structure_seule`. Aucun seed. |
| Un monde neuf commence avec **0 compagnie et 0 section**. Les compagnies naissent de la chaîne de jeu : ministre de la Défense, Commandant PJ, transfert vers la caserne, création (20 000 FR), Capitaine, Lieutenants. | `compagnies_militaires` passe **D → C** et reconstruction explicite → `structure_seule`. Il n'existe **aucune table de sections** : une section vit dans le blob de sa compagnie. |
| `produits_manufactures` est un **catalogue**, pas un stock, à la granularité **ville**. | Passe **D → B**. Reste en reconstruction explicite : la nature est tranchée, le contenu reste à écrire. **Pas de dette de dimensionnement** ici — la table porte déjà une colonne `ville`. |
| Les **dotations initiales** seront fixées sur tableau. | Une seule valeur inscrite : `republic_gouvernement-min_def` = **35 000 FR**. Le reste est listé dans `arbitrages/dotations-initiales-republia.csv`. |
| L'**état initial des lieux** sera fixé sur tableau. | `arbitrages/etat-initial-republia.csv`. Périmètre réel de Républia corrigé : 14 bâtiments, 14 commerces, 4 terrains — et non 38 / 20 / 5, qui étaient des comptes de lignes tous empires confondus. |
| Indices des **trois villes de Républia** : IE 50, ISN 30, Moral 50. | `indices_villes` passe reconstruction explicite → `seed_filtre` et reçoit un **vrai seed de 3 lignes**. La 4ᵉ ligne, `republic_zzville-cmr`, est de test et est écartée. Valide pour Républia **uniquement**. |
| Chaque ville de Républia doit avoir **son propre juge PNJ**, et aucun quatrième juge à `city = NULL`. | **Rien n'a été supprimé.** Les quatre lignes ont été relevées et le vestige identifié (`republic_juge_national`) ; la suppression attend validation. Le seed porte toujours les 16 lignes, l'anomalie signalée en en-tête. |

### Troisième série d'arbitrages, rendus le 5 octobre 2026

| Décision | Effet |
|---|---|
| Les **cinq** indices des trois villes de Républia : IE 50, ISN 30, Moral 50, **Piété 40, Social 45**. | Le seed `indices_villes` est validé sur les cinq valeurs. Il n'y a plus aucune valeur supposée dedans. Républia uniquement. |
| Les **trois juges de ville** sont conservés, le quatrième juge national est un vestige. | Le seed de `titulaires_pnj` écarte `republic_juge_national` : un monde neuf naît avec **15 titulaires**, dont 3 juges municipaux distincts. Rien n'est supprimé en production. |
| Les **17 dotations de matières premières**, identiques dans les trois villes. | Les 17 valeurs sont préremplies dans le tableau d'arbitrage et consignées dans `seeds/99_a-construire/batiments_etat.sql`. Le seed n'est pas encore écrit : le stock vit dans le même blob que la caisse de l'entrepôt, qui reste à arbitrer. |

## Exigences de game design consignées, non développées

Elles vivent dans `DIFFERENCES-DELIBEREES.json`, bloc
`exigences_de_game_design_a_construire`, pour ne pas se perdre entre deux
chantiers. Ce ne sont pas des dettes découvertes au passage : ce sont des
demandes explicites du game designer.

1. **Outil MJ — substitution aux échelons militaires.** Si le jeu compte trop
   peu de PJ pour remplir la chaîne Commandant → Capitaine → Lieutenants,
   l'administrateur doit pouvoir s'y substituer. Aucune fonction du schéma ne le
   permet aujourd'hui.
2. **Outil MJ — ajout exceptionnel de matières premières.** Filet de sécurité
   administratif : ne remplace pas la chaîne d'approvisionnement, ne devient pas
   une production automatique, ne masque pas un dysfonctionnement économique.
   Les stocks vivent aujourd'hui dans **trois** endroits distincts — le blob
   `entrepot` de `batiments_etat`, `budgets_nationaux.caserneMatieres`, et le
   `stockMatieres` de chaque entreprise — et il n'existe pas de porte unique.
3. **Audit futur de la chaîne d'approvisionnement automatique.** À mener après
   le chantier Supabase. Sept observations de passage sont déjà consignées pour
   lui servir de point de départ, dont l'accumulation de 11 386 unités de bois
   au port de Port-Sainte-Marie et la répartition municipale qu'aucune fonction
   serveur ne lit.
4. **Mécanisme de rattachement chef ↔ organisation**, sans lequel les deux loges
   ne peuvent pas naître constituées.

### Duplication constatée : `clubs_sportifs_regles`

Malgré son nom, la table ne contient aucune règle. Ses colonnes sont
`club_id, nom, country, city, valeur_base`, et ses **12 lignes sont les 12 mêmes
clubs que `clubs_football`** — mêmes identifiants, mêmes noms, mêmes pays et villes,
12 sur 12 en commun. Seule `valeur_base` n'y figure pas en double. Le nommage
diverge en outre entre les deux tables : `pays`/`ville` d'un côté, `country`/`city`
de l'autre. Fusion à traiter hors 2C.

### Les organisations préexistantes de Républia

Un monde neuf comporte des organisations préexistantes, et elles sont de **deux
natures distinctes**. La table `organisations` est donc classée **D**, en
reconstruction explicite.

**Celles que le moteur crée paresseusement** — authored, mais jamais semées : il
les matérialise à la première sollicitation.

| Organisation | Identifiant | Création |
|---|---|---|
| Club de supporters, un par ville | `orga_supporters_<pays>_<ville>` | `doRejoindreClubSupporters` (`plateau-organisations-quetes.js:7720`), à la première adhésion |
| Syndicat des Dockers de Port-Sainte-Marie | `orga_syndicat_dockers_republic_ville_a` | `chargerOuCreerSyndicatDockersPSM` (`:7824`), à l'entrée dans le bureau syndical |

**Les deux loges maçonniques** — Luthécia et Montrouge. Décision de game design :
elles doivent **naître constituées**, et non être fondées plus tard par les
joueurs. Chacune doit posséder un **chef PNJ initial**, parce que la mécanique de
prise de pouvoir suppose qu'une organisation a déjà un chef.

Les deux locaux existent bel et bien :

| Ville | Déclaration | Nom | Particularité |
|---|---|---|---|
| Luthécia | `data.js:191` (liste `buildings` de `capitale`), contexte `data.js:348` | « Loge Maçonnique de Luthecia » | surcharge `persons` propre |
| Montrouge | `data.js:849` (liste `buildings` de `ville_b`), contexte `data.js:1147` | « Loge maçonnique de Montrouge » | images propres, **aucune surcharge `persons`** |

Des PNJ y sont posés, par la définition de bâtiment partagée (`data.js:3134`) :
`Le Portier` (gardien), `Frere Gardien` (membre), et **`Vénérable Maître Duval`,
rôle explicite « PNJ - Chef de la Loge »**, dans le Bureau du Vénérable Maître.
La surcharge de Luthécia ajoute **`Frère Jacques D'Equerre (PNJ)`, rôle « Grand
Maître »** — le grade le plus élevé du type `loge`, dont les grades Républia sont
Apprenti / Compagnon / Maître / Grand Maître — et `Frère Maurice Compas (PNJ)`,
Trésorier. D'Equerre possède même une personnalité définie (`plateau-core.js:36`).

**Mais aucun de ces PNJ n'est rattaché à une ligne `organisations`.** Ce sont des
personnages de décor : le lien « chef d'organisation » n'existe pas en base, et
**aucune auto-création n'existe pour les loges**. Cet état ne correspond pas au
game design voulu.

> **État initial à construire.** Pour Montrouge, le chef désigné par les données
> est `Vénérable Maître Duval`. Pour Luthécia, **deux candidats coexistent** :
> `Vénérable Maître Duval` par la définition par défaut du bâtiment, et
> `Frère Jacques D'Equerre` par la surcharge de la ville. Rien n'est inventé ici :
> le choix reste à trancher, et le mécanisme de constitution des loges reste à
> écrire — hors 2C.

### Dette technique conservée

`organisationInstitutionnelle()` (`plateau-gouvernement.js:1304`) reconnaît une
structure du moteur à l'absence de `fondateur`, ou au drapeau `institutionnelle`.
Or ce drapeau **n'est posé nulle part dans tout le JavaScript**, et les deux
structures auto-créées posent toutes deux un `fondateur` PNJ. La fonction rend donc
`false` pour elles, et `organisationDissolvable()` **ne les protège pas** alors
qu'elle est faite pour cela. Constat conservé, non corrigé.

## `rp_transitions` : un mécanisme transitoire, pas une règle

Deux drapeaux, lus par une seule fonction, `rp_transition_active(cle)`, qui rend
**`false` quand la clé est absente**. Conséquence directe : une table **vide** se
comporte exactement comme la production d'aujourd'hui, les deux drapeaux y étant à
`false`.

Les deux clés ont des **polarités opposées** :

| Clé | Posée le | État | Ce que « actif » signifie |
|---|---|---|---|
| `mails_expediteurs_tolerance` | 20/09/2026 | inactif | actif = **permissif** (une identité déclarée suffit). Inactif = contrôle strict |
| `argent_verrou` | 20/09/2026 | inactif | actif = **verrou appliqué** (la hausse est annulée). Inactif = la hausse passe |

Deux fonctions seulement les consultent : `mail_expediteur_autorise` et le
déclencheur `personnages_vue_modifier`. Aucune policy, aucun cron, aucun appel
JavaScript direct.

**Conséquence en jeu, aujourd'hui.** Dans `personnages_vue_modifier`, une hausse
de `pa`, `stats`, `banque` ou `qualifications` envoyée par le client est **toujours**
annulée. Une hausse de `arg` ou de `liquide` est **journalisée dans
`fiche_hausses_observees` puis acceptée**, et ne serait annulée que si
`argent_verrou` était actif. Les hausses de `hp` et `day` sont journalisées sans
jamais être annulées.

La note portée par la ligne dit pourquoi : *« À ACTIVER AU PUSH, une fois les 24
sites de crédit routés »*. Le verrou ne peut pas être armé tant que des gains
légitimes passent encore par le client.

> **Décision.** `rp_transitions` n'est **ni une règle pérenne du moteur, ni du
> contenu d'empire** : c'est un mécanisme transitoire lié à la sécurisation
> progressive des anciennes écritures client. Ses deux lignes ne doivent donc pas
> être promues en règle du socle. Le comportement actuel est **conservé** tant que
> les chemins légitimes ne sont pas tous migrés côté serveur, et `argent_verrou`
> **ne doit surtout pas être activé prématurément**. L'objectif architectural est
> de pouvoir **supprimer cette tolérance** une fois les écritures légitimes
> correctement routées.

## Contrôles

    python3 outils/baseline/verifier-classification.py

Sept contrôles : 252 tables classées, aucun doublon, empreinte de la liste
conforme au catalogue, toute table `D` justifiée, toute table semée justifiée,
aucune table d'état vivant en seed complet, vocabulaire fermé respecté.
