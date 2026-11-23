# Chasse aux images cassées — reprise du 23 novembre 2026

Base finale du rebase : `e9f496cae3cc99d34dabff62bd5134050e25a0a7`. Branche `codex/images-cassees-20261122`, PR #1180 existante. Aucune écriture en production, aucune migration appliquée, aucun seed modifié.

## État avant modification

Premier relevé : main `032ed96630b6539c42a760d2080543286c57e5aa`, base de la branche `b514b1be29978c50b53d9bd232870c1024e4a845`, commit publié initial `94bdb49f`. 22 commits et 119 fichiers arrivés sur main. Le travail non commis a été sauvegardé, puis restauré sélectivement après rebase. À la reprise finale, aucun commit local non poussé avant rebase ; sept fichiers suivis modifiés et sept fichiers nouveaux étaient à terminer.

Fichiers communs entre le commit initial et main : `RELAIS.md`, `data.js`, `plateau-actions-illegales-rumeurs.js`, `plateau-justice-economie.js`, `plateau-personnage.js`, `plateau.html`.

PR ouvertes touchant ces fichiers : #1132 (plateau.html), #994 (RELAIS.md, data.js), #993 (RELAIS.md, data.js). Aucun second chantier images ni seconde PR créé.

Commits de main depuis la base initiale :

- `e00b509a679b` — Décisions de Fred du 22/11 (soir) consignées ; images de chantier de Luthécia (6) rangées et branchées
- `0bba1e82b0ac` — Banc vue du chantier : série d'images de Luthécia complète
- `4d8fa7469bc4` — Accueil des nouveaux joueurs : interview à la première connexion, parcours dans Mes objectifs, bulle des PA (points 23 à 26)
- `e88d3df8d7de` — Santé, point 8 : médicaments des PNJ sur matière première, recettes à l'usine, usines d'État (fonds de roulement, tutelle), antidote
- `825d6f89857a` — Tabac-presse de Krasnov (cigarettes, carte postale, revue) et crue sans blocage (points 27 à 32)
- `7b50c8742f37` — Pays d'un poste : organigrammes et pouvoirs lus dans le registre, jamais la position (B.15-16)
- `5f6819d08c0c` — Santé, Suites (22/11 au soir) : palier 15, repas du Président / de l'hôpital / de la clinique, robustesse sur subir / répression / rébellion, tracts plafonnés, antenne de Starovka, rachat commun des marchés, objectif informateurs
- `e78d0d2d05bb` — Médecin payé en liquide seulement (règle générale du point 5), migration écrite non appliquée, banc PGlite
- `a15da7ac7445` — Merge branch 'claude/sante-suites-20261123'
- `e5b000131c80` — Merge branch 'claude/medicaments-usines-20261123'
- `de32bbce3035` — Merge branch 'claude/postes-pays-20261123'
- `addd5cdb51d6` — Merge branch 'claude/accueil-interview-20261123'
- `b72376948b6f` — Merge branch 'claude/tabac-crue-20261123'
- `52be7da18b0c` — Crue : la réécriture de climat_crue_appliquer_interne garde la correction du pays du poste (pp_crue_min) ; doublure poste_detenu dans le banc
- `18b62c311484` — Accueil : page MJ des réglages (accueil_parametres)
- `d80ca7e95e13` — Ordres regroupés dans les pièces (points 17 à 21) : inspection à trois volets, mairies, partis, syndicat, Fonctions de [poste]
- `0cc520632398` — Merge branch 'claude/ordres-regroupes-20261123'
- `52b2383c30bc` — Tarifs : desinstaller_materiel retiré du catalogue (ordres regroupés), listes en dur et seeds régénérés
- `a2942626107c` — Relais : sept migrations de la mission appliquées en production et contrôlées ; AGENTS : accueil du nouveau personnage
- `d8e6d4733bfd` — Fusion : mission « Suites de Santé, interface et accueil » (sept migrations appliquées)
- `b882274ed07d` — Relevé du point 22 (pièces à plus de 6 ordres) conservé dans le dépôt
- `032ed96630b6` — CI : historique complet pour le banc des missions (sante-suites) ; phrases de carte postale retirées documentées avec leur provenance
- `e9f496cae3cc` — installation d’acorn dans la CI Santé par Claude ; repris au dernier rebase, sans correctif étranger de Codex.

## Résolution des conflits

- `plateau.html` : version intégrale de main, avec tous les scripts et suffixes de version de Claude ; préfixe de cache images ajouté à six scripts et chargement de `plateau-images.js` avant les consommateurs.
- `plateau-personnage.js`, à la restauration du travail non commis : version de main reprise ; les cartes postales recto/verso, légendes, filtrage des destinataires, médecine, repas et registre des postes de Claude sont conservés. Seuls les appels de résolution des images sont réappliqués.
- Second rebase sur `e9f496ca` : aucun conflit. Les huit fichiers de production modifiés sont comparés en entier à main après application des seules transformations images autorisées (`preservation-main.json`). Aucun fichier image, seed, API ou mécanique métier modifié.

## Corrections du premier commit 94bdb49f (réappliquées après rebase)

| Fichier | Avant | Après |
|---|---|---|
| `vercel.json` | `/images/arme-baionnette-soviet.png` | alias vers `/images/arme-baionnette-soviet.webp`, le fichier existe |
| `vercel.json` | `/images/arme-makarov-soviet.png` | alias vers `/images/arme-makarov-soviet.webp`, le fichier existe |
| `vercel.json` | `/images/arme-kalachnikov-soviet.png` | alias vers `/images/arme-kalachnikov-soviet.webp`, le fichier existe |
| `plateau-images.js`, consommé par `plateau-personnage.js` | `https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-fusil-republic.png` | `images/arme-fusil-republic.webp` |
| `plateau-images.js`, consommé par `plateau-personnage.js` | `https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-mitraillette-militaire.png` | `images/arme-mitraillette-militaire.webp` |
| `plateau-images.js`, consommé par `plateau-personnage.js` | `https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-pistolet-militaire.png` | `images/arme-pistolet-militaire.webp` |
| `plateau-images.js`, consommé par `plateau-personnage.js` | `https://raw.githubusercontent.com/FredJ74/res-publica/main/images/calepin-enigme-musee.png` | `images/calepin-enigme-musee.webp` |
| `plateau-images.js`, consommé par `plateau-personnage.js` | `https://raw.githubusercontent.com/FredJ74/res-publica/main/images/stade-brise-mariannaise.png` | `images/stade-brise-mariannaise.webp` |
| `plateau-images.js`, consommé par `plateau-personnage.js` | `https://raw.githubusercontent.com/FredJ74/res-publica/main/images/stade-olympique-luthecia.png` | `images/stade-olympique-luthecia.webp` |
| `plateau-actions-illegales-rumeurs.js` | `images/arme-machette-narco.png` | `imageUrl: null` ; aucune autre photo substituée |
| `plateau-actions-illegales-rumeurs.js` | `images/arme-deserteagle-narco.png` | `imageUrl: null` ; aucune autre photo substituée |
| `plateau-actions-illegales-rumeurs.js` | `images/arme-ak47-narco.png` | `imageUrl: null` ; aucune autre photo substituée |
| `plateau-actions-illegales-rumeurs.js` | `images/arme-jambiya-khalija.png` | `imageUrl: null` ; aucune autre photo substituée |
| `plateau-actions-illegales-rumeurs.js` | `images/arme-pistolet-khalija.png` | `imageUrl: null` ; aucune autre photo substituée |
| `plateau-actions-illegales-rumeurs.js` | `images/arme-fusil-khalija.png` | `imageUrl: null` ; aucune autre photo substituée |
| `plateau-justice-economie.js` | `images/armoire-a-souvenirs.png` | `imageUrl: null` ; aucune autre photo substituée |
| `data.js`, ancien gabarit masqué de Sovarka | `images/bureau-gouv-sovarka.png` | valeur `null`, aucune pièce active concernée |
| `plateau-assemblee.js`, constante sans consommateur | `images/republia-pnj-deputes.png` | déclaration inutilisée retirée |
| `plateau-rue-centrale.js` | `images/terrains/montrouge/rue-etat-2.webp`, `rue-etat-3.webp` | précharges retirées ; image initiale déjà prévue conservée |

## Compléments finalisés pendant la reprise

| Fichier | Avant | Après |
|---|---|---|
| `data.js`, archives gouvernementales, archives parlementaires, sacristie | `https://images.unsplash.com/photo-1568667256549-094345857aff?w=1200&q=80` (404) | `imageUrl: null` ; les surcharges locales existantes restent prioritaires |
| `data.js`, vitrine principale | première propriété `imageUrl` Unsplash `photo-1567449303078-57ad995bd17f` (404), aussitôt écrasée par une seconde propriété | propriété morte retirée ; `images/centre-commercial-republic.webp` inchangée |
| `plateau-personnage.js` | accès direct `item.imageUrl` dans l’armoire et l’autre fenêtre de détail | `imageUrlObjet(item)` ; même résolveur que l’inventaire, objet conservé intact |

Aucun nouveau chemin cassé n’a été trouvé dans les ajouts de Claude. Les six images de chantier de Luthécia sont désormais présentes. Les nouvelles images du tabac-presse et ses fenêtres ne sont pas modifiées. Les anciens tests qui exigeaient les deux précharges absentes de Montrouge sont adaptés au retrait de ces précharges, en gardant les épreuves des trois états. Le contrôle des alias attend précisément 32 alias (29 existants + 3 nouveaux) et vérifie chaque véritable WebP.

## Inventaire et vérifications

- Code : 1308 occurrences, 1046 URL distinctes, dont 1011 variantes locales, dans 29 fichiers ; zéro cible locale absente. Les fichiers doivent être suivis par Git, et la casse est contrôlée.
- Modèles exécutés sans RPC : 3 156 références supplémentaires dans les quatre empires, incluant les noms construits, pièces, PNJ et scènes d’arrivée.
- Chemins dynamiques : 171 situations ; toutes les images obligatoires de forêt et toundra existent. Les 40 candidats facultatifs de chantiers non livrés dans les quatre autres villes ont chacun le repli déjà prévu par le moteur ; aucun de ces mécanismes n’est modifié.
- Lecture initiale de la base le 22/11 : 588 tables, 2 705 colonnes, 472 occurrences de chemins / 118 URL distinctes, sans nom de joueur ni contenu privé publié. Stockage : 23 objets image inventoriés, 22 publics servis en 200, un original privé présent. Il ne s’agit pas d’une relecture atomique ni d’une certification de la base après les migrations de Claude.
- Les neuf cartes postales de Républia sont déjà WebP en base et leurs anciens chemins PNG ont déjà un alias fonctionnel : aucun doublon de correction.
- Tests finaux : 31/31 tests Node ciblés et 3/3 tests Python de collecte sans écriture ; le banc SQL isolé antérieur compte une épreuve supplémentaire. Chromium : 783 rendus par résolution 320/390/1280 px et neuf langues ; 78 images locales de PSM/Centre Multimodal décodées, portrait du chef de cabinet chargé, un fond distant commun à deux bureaux vérifié séparément par HTTP. Aucun PJ connecté, téléphone physique ou trajet réel testé.
- Retour à Luthécia : pas de défaut reproduit sur main ; la fonction serveur lue le 22/11 choisit le Centre Multimodal et efface l’ancienne rue. Le rendu client du reçu serveur conserve cette arrivée malgré un souvenir de rue ancien. Aucune règle de transport modifiée.
- Les formats de 1 056 images locales ont été vérifiés, sans erreur. Les 86 catalogues Brotli sont conformes, aucun catalogue modifié.

## Manques et références laissées en attente

| Fichier ou source | Chemin attendu | Lieu et contenu | Raison |
|---|---|---|
| plateau-actions-illegales-rumeurs.js | `images/arme-machette-narco.png` | Armurerie d’El Estado — Machette | image_a_produire |
| plateau-actions-illegales-rumeurs.js | `images/arme-deserteagle-narco.png` | Armurerie d’El Estado — Desert Eagle | image_a_produire |
| plateau-actions-illegales-rumeurs.js | `images/arme-ak47-narco.png` | Armurerie d’El Estado — AK-47 | image_a_produire |
| plateau-actions-illegales-rumeurs.js | `images/arme-jambiya-khalija.png` | Armurerie d’Al-Khalija — Jambiya | image_a_produire |
| plateau-actions-illegales-rumeurs.js | `images/arme-pistolet-khalija.png` | Armurerie d’Al-Khalija — Pistolet doré | image_a_produire |
| plateau-actions-illegales-rumeurs.js | `images/arme-fusil-khalija.png` | Armurerie d’Al-Khalija — Carabine de précision | image_a_produire |
| plateau-justice-economie.js | `images/armoire-a-souvenirs.png` | Scierie Guy Tarembois / fiche d’objet — Armoire à souvenirs | image_a_produire |
| plateau-rue-centrale.js | `images/terrains/montrouge/rue-etat-2.webp` | Rue des terrains de Montrouge — Rue après une réception de chantier | etat_optionnel_non_produit_image_initiale_conservee |
| plateau-rue-centrale.js | `images/terrains/montrouge/rue-etat-3.webp` | Rue des terrains de Montrouge — Rue après réception de tous les chantiers | etat_optionnel_non_produit_image_initiale_conservee |
| data.js (commentaire, aucune URL appelée) | `images/port-sainte-marie-port-industriel-box-a-louer.png` | Port industriel de Port-Sainte-Marie, Box à louer — Rangée de box individuels grillagés | piece_sans_illustration_pas_un_appel_404 |
| Base : climat_points_eau.image | `images/fontaines/luthecia-fontaine-hotel-de-ville.webp` | Luthécia — Hôtel de Ville — Fontaine ou point d’eau de ce lieu | reserve_au_lot_crue_de_Claude_non_corrige |
| Base : climat_points_eau.image | `images/fontaines/montrouge-fontaine-place-du-rail.webp` | Montrouge — Place du Rail — Fontaine ou point d’eau de ce lieu | reserve_au_lot_crue_de_Claude_non_corrige |
| Base : climat_points_eau.image | `images/fontaines/novomirsk-fontaine-place-peuple.webp` | Novomirsk — Place du Peuple — Fontaine ou point d’eau de ce lieu | reserve_au_lot_crue_de_Claude_non_corrige |
| Base : climat_points_eau.image | `images/fontaines/psm-fontaine-place-armes.webp` | Port-Sainte-Marie — Place d’Armes — Fontaine ou point d’eau de ce lieu | reserve_au_lot_crue_de_Claude_non_corrige |
| Base : climat_points_eau.image | `images/fontaines/starovka-fontaine-mairie.webp` | Starovka — Mairie — Fontaine ou point d’eau de ce lieu | reserve_au_lot_crue_de_Claude_non_corrige |
| data.js | `https://images.unsplash.com/photo-1568667256549-094345857aff?w=1200&q=80` | Luthécia — Sacristie administrative du Tabernacle — Pièce d’archives, confessions et formulaires du Grand Prêtre | ancienne_url_distante_404_aucun_fichier_dedie_identifie |
| data.js | `https://images.unsplash.com/photo-1568667256549-094345857aff?w=1200&q=80` | El Estado — Archives de l’Assemblée — Archives parlementaires d’El Estado | ancienne_url_distante_404_aucun_fichier_dedie_identifie |
| data.js | `https://images.unsplash.com/photo-1568667256549-094345857aff?w=1200&q=80` | Al-Khalija — Archives du gouvernement — Archives gouvernementales d’Al-Khalija | ancienne_url_distante_404_aucun_fichier_dedie_identifie |

Les cinq fontaines restent réservées au lot crue de Claude. Les images distantes fournies dans des contenus de joueurs et les six anciennes URL GitHub enregistrées en base ne sont pas réécrites en production par cette mission : elles restent des données à traiter après arbitrage ou par le SQL ci-dessous. Une réponse 403 d’un site externe ne prouve pas que son image est cassée pour un joueur ; aucune photo générique n’est ajoutée. Un lien Franceinfo archivé dans le journal renvoie 404 : son contenu original n’est pas identifiable, il n’est pas remplacé arbitrairement.

## SQL NON APPLIQUÉ

Fichier : `migrations/20261122210046_correction_chemins_images_non_appliquee.sql`. Seize remplacements exacts, idempotents, six tables. Comptage initial : 76 lignes / 153 occurrences, détaillé dans `lignes-base-lecture-seule.json`. Les 60 éditions peuvent contenir plusieurs anciennes URL ; ce ne sont pas 153 lignes distinctes. Les valeurs numériques, quantités, PA, argent, conditions et textes narratifs restent inchangés. Aucun appel de fonction métier. Seul un banc fictif isolé avait éprouvé l’idempotence et l’annulation ; aucune application en production.

```sql
-- NON APPLIQUÉE — Fred, mission images du 22/11/2026.
-- Claude seul intervient en production. Préparation pour la réconciliation ultérieure.
-- Images uniquement : aucun coût, droit, ordre, inventaire quantitatif, seed ni fonction métier.
-- Remplace des chaînes JSON ENTIÈRES, jamais le contenu narratif d’une chaîne.
-- Idempotente : aucune ancienne valeur => aucune écriture. Une transaction à l’application future.
DO $images$
DECLARE r record; v_anciennes text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('escorts_catalogue','portrait','text','images/escort-h-1-costume-beige.png','images/escort-h-1-costume-beige.webp'),
    ('escorts_catalogue','portrait','text','images/escort-republic.png','images/escort-republic.webp'),
    ('escorts_catalogue','portrait','text','images/escort-f-1-robe-verte.png','images/escort-f-1-robe-verte.webp'),
    ('inventaire_actions_recus','resultat','jsonb','https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-fusil-republic.png','images/arme-fusil-republic.webp'),
    ('journal_editions','faits_sources','jsonb','https://raw.githubusercontent.com/FredJ74/res-publica/main/images/stade-brise-mariannaise.png','images/stade-brise-mariannaise.webp'),
    ('journal_editions','faits_sources','jsonb','https://raw.githubusercontent.com/FredJ74/res-publica/main/images/stade-olympique-luthecia.png','images/stade-olympique-luthecia.webp'),
    ('journal_editions','faits_sources','jsonb','images/stade-brise-mariannaise.png','images/stade-brise-mariannaise.webp'),
    ('journal_editions','faits_sources','jsonb','images/stade-olympique-luthecia.png','images/stade-olympique-luthecia.webp'),
    ('objets_modeles','objet','jsonb','images/arme-baionnette-soviet.png','images/arme-baionnette-soviet.webp'),
    ('objets_modeles','objet','jsonb','images/arme-makarov-soviet.png','images/arme-makarov-soviet.webp'),
    ('objets_modeles','objet','jsonb','images/arme-kalachnikov-soviet.png','images/arme-kalachnikov-soviet.webp'),
    ('personnages_donnees','inventory','jsonb','https://raw.githubusercontent.com/FredJ74/res-publica/main/images/calepin-enigme-musee.png','images/calepin-enigme-musee.webp'),
    ('personnages_donnees','inventory','jsonb','images/calepin-enigme-musee.png','images/calepin-enigme-musee.webp'),
    ('personnages_donnees','inventory','jsonb','https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-fusil-republic.png','images/arme-fusil-republic.webp'),
    ('pnj_possessions','objet','jsonb','https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-mitraillette-militaire.png','images/arme-mitraillette-militaire.webp'),
    ('pnj_possessions','objet','jsonb','https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-pistolet-militaire.png','images/arme-pistolet-militaire.webp')
  ) AS corrections(table_name,column_name,column_type,ancienne,nouvelle)
  LOOP
    IF r.column_type = 'text' THEN
      EXECUTE format('UPDATE public.%I SET %I = $2 WHERE %I = $1',
        r.table_name,r.column_name,r.column_name) USING r.ancienne,r.nouvelle;
    ELSE
      EXECUTE format('UPDATE public.%I SET %I = replace(%I::text,to_jsonb($1::text)::text,to_jsonb($2::text)::text)::jsonb WHERE strpos(%I::text,to_jsonb($1::text)::text) > 0',
        r.table_name,r.column_name,r.column_name,r.column_name) USING r.ancienne,r.nouvelle;
    END IF;
  END LOOP;
END
$images$;
```

## Bancs et livraison

Garde : `banc-images-references-20261122.cjs`, workflow `images-cassees-20261122.yml`, job `images`. Contre-épreuves : absence, casse erronée, cible d’alias absente, fichier non suivi par Git ; HTML/CSS hors du dossier images également contrôlés. La recette navigateur et la collecte SQL sans écriture sont intégrées à ce même workflow. Les chemins construits de forêt/toundra sont vérifiés ; toute nouvelle absence parmi les candidats de chantier, hors des quarante emplacements facultatifs déjà documentés avec un repli existant, fait échouer le banc.

Résultats CI, SHA de fusion, CI de main et diffusion Vercel : preuves finales dans la PR #1180, référencée par RELAIS.md. Ne pas déduire un déploiement du seul commit ni un succès CI d’un banc local.
