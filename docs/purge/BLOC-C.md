# Mission « Purge » — bloc C (fenêtre du chantier) — Claude, 24/11/2026

Branche `claude/purge-c-20261124` (depuis main `f73a9ebd`). Décisions consignées à leur source : fin de
`GAME-DESIGN-CHANTIERS-IMAGES-20261120.md` (consigne de Fred mot pour mot + mise en œuvre) ; renvoi ajouté au point 6 de
`GAME-DESIGN-MISSION-SOIR-20261121.md`.

## Suivi des décisions

| Date | Décision | État | Issue | Source |
|---|---|---|---|---|
| 24/11/2026 | C.1 Résumé permanent en haut : « Encore X heures à faire aujourd'hui » + « ? », matériaux du jour (valeurs lues sur le serveur) ; emplacement du climat juste dessous, vide, pour le bloc D | en cours (branche, migration à appliquer) | | GAME-DESIGN-CHANTIERS-IMAGES-20261120.md (fin) |
| 24/11/2026 | C.2 « Travailler sur ce chantier » dans l'onglet principal « Participer » : heures avec − et +, plafond et salaire du serveur, gain affiché avant validation | en cours (branche, migration à appliquer) | | idem |
| 24/11/2026 | C.3 « Vendre mes matériaux au chantier » : une carte par matériau, « Vendre … » et « Donner … gratuitement » en deux boutons distincts, quantité − et +, plafonds du serveur | en cours (branche, migration à appliquer) | | idem |
| 24/11/2026 | C.4 « Gérer mon chantier » (propriétaire) : vue à part dans la même fenêtre, une ligne par réglage avec son seul bouton, « ← Retour au chantier » | en cours (branche) | | idem |
| 24/11/2026 | C.5 Plus de tableau à colonnes, cartes, couleurs du jeu dans `style.css` (plus de style injecté ni de couleur en dur dans le JS), onglets « Participer » / « Avancement » jamais coupés, texte ≥ texte courant | en cours (branche) | | idem |
| 24/11/2026 | C.6 Lot 3 de Luthécia : description « Lot de la Châtaigneraie (2300 m²) … » renommée « Terrain à bâtir » (le libellé n'existe que dans `data.js` ; rien en base, aucun renvoi) | en cours (branche) | | idem |

## Commits

- `8e5d927e`, `6b71690d` C.6 — `fa4fb216` lecture serveur — `d4934e20` C.1 — `4eb9b071` C.2 — `b2eb1720` C.3 — `5fbef823` C.4 —
  `5a10d191` C.5 — `194a82c4` source du game design et renvoi redirigé.

## Migration à appliquer

- `migrations/20261124120000_chantier_fenetre_lire.sql` : nouvelle fonction de LECTURE `public.chantier_fenetre_lire(p_terrain_id text)`
  (SECURITY DEFINER, `mon_personnage()`, EXECUTE pour `authenticated` seulement). Aucune table, donnée ni fonction existante modifiée.
  Le plafond d'heures et le salaire viennent de la vraie `chantier_travailler` rejouée dans une sous-transaction annulée
  (SQLSTATE `RPLS0`) : la lecture ne peut pas diverger de l'action. Heures du jour : mêmes formules que `chantier_travailler`
  + `chantier_avance_heures_interne`. Matériaux : règle de prix de `vendre_materiaux_chantier`, plafond = manque du jour,
  possédé, trésorerie. Éprouvée sur PGlite (`banc-purge-c-chantier-pglite-20261124.cjs`, 6 cas dont « lecture sans effet »).
- **À appliquer avec le client** : sans elle, la fenêtre affiche « Le chantier ne répond pas » et ne propose ni travail ni vente.
- Contrôle en lecture après application : `SELECT p.oid::regprocedure, has_function_privilege('anon', p.oid, 'EXECUTE') anon,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') auth FROM pg_proc p WHERE proname = 'chantier_fenetre_lire';`
  (anon = false, auth = true) ; puis, connecté comme Arnie sur le terrain 3, la fenêtre doit montrer « Encore … heures » et
  `terrains_etat` / `personnages_donnees` d'Arnie inchangés après ouverture (`updated_at` identique).
- Baseline (Codex) : ajouter `chantier_fenetre_lire` au domaine économie à la prochaine régénération.

## Pour Codex (textes français nouveaux ou changés, à traduire)

- `plateau-chantier-vue.js`, objet **`TXTC`** (nouveau, toutes les clés) : `r_heures`, `r_heures_avance`, `r_heures_aucune`,
  `r_heures_attente`, `r_heures_aide`, `r_materiaux`, `r_mat`, `r_mat_aide`, `r_lecture_ko`, `aide`, `o_participer`, `o_avancement`,
  `w_titre`, `w_salaire`, `w_moins`, `w_plus`, `w_heures`, `w_gain`, `w_bouton`, `w_plafond`, `w_salaire_aide`, `x_aucune_heure_ouverte`,
  `x_pa_insuffisants`, `x_tresorerie_insuffisante`, `x_chantier_intemperies`, `x_pas_sur_place`, `x_acteur_incapacite`,
  `x_acteur_detenu`, `x_terrain_gele`, `x_defaut`, `v_titre`, `v_prix`, `v_note`, `v_moins`, `v_plus`, `v_vendre`, `v_donner`,
  `v_complet`, `v_aucun`, `v_treso`, `v_ferme`, `v_prix_aide`, `g_gerer`, `g_retour`, `g_tableau`, `g_reglages`, `g_prix_m`,
  `g_prix_aide`, `g_salaire_aide`, `g_fonds_aide`.
- `plateau-chantier-vue.js`, `TXT4.j_manque` : changé (« onglet « Participer », « Vendre mes matériaux au chantier » » au lieu de
  « onglet « Stock de matériaux » »).
- Plus affichés (à ne plus traduire) : `TXT4.o_etat`, `o_stock`, `o_main`, `o_gestion`, `s_*`, `m_main`, `m_nb`, `m_pa`, `m_travailler`,
  `m_aucune`, `m_sans_pa`, `m_sans_treso`, `m_gain`, `m_avance`.
- `data.js`, `BUILDINGS['terrain-a-batir-3'].rooms.terrain.desc` : « Terrain à bâtir ».

## Questions de game design rencontrées (non tranchées)

- Les deux onglets « Participer » / « Avancement » sont mon interprétation de « Travailler… dans la fenêtre principale » et
  « onglets non coupés » ; le contenu de l'ancien onglet « État » (image, jauges, journal) est gardé dans « Avancement ». À juger en jeu.
- « Donner » gardé comme bouton séparé dans chaque carte de matériau (la consigne ne nomme que « Vendre »). Faut-il le retirer ?
- C.6 : seule la description de la pièce a été renommée ; le nom du bâtiment « Terrain a batir - Lot 3 (La Châtaigneraie) » et
  son nom court « Lot 3 — Châtaigneraie » (titres, scènes PNJ générées) sont inchangés. Faut-il aussi les renommer ?
- Les lots 2 et 3 de Luthécia annonçaient tous deux 2 300 m² dans leur description ; la surface réelle est en base
  (`terrains_etat.data->surface`), non vérifiée ici.

## Bancs

- Verts en local : `banc-purge-c-chantier-20261124.cjs` (2), `banc-purge-c-chantier-navigateur-20261124.cjs` (4, Chrome, 390 et
  1280 px), `banc-purge-c-chantier-pglite-20261124.cjs` (6, PGlite), `banc-chantier-vue-navigateur-20261121.cjs` (4, mis à jour à la
  nouvelle consigne, sans désactivation), `banc-construction-commandes`, `banc-chantier-rue-terrains-etats-20261122`,
  `banc-terrains-plan-20261122`, `banc-terrains-plan-navigateur-20261122`, `banc-chantier-avance-pglite-20261121`,
  `banc-crue-chantier-pglite-20261123`, `test-ecritures-fiche-serveur`, `test-purge-migrations-219`, `test-serrures-client`.
- Ajoutés au workflow `chantier-construction-20261121.yml`.
- PGlite local emprunté en lecture seule à `~/ResPublica-nationalite/outils/vercel/node_modules` (PGLITE_DIR).

## Ce qui reste

- Climat (bloc D) : remplir `#chantier-zone-climat` (sous le résumé, caché par défaut) par `window.chantierZoneClimat(zone, contexte)`
  ou l'événement `rp:chantier-fenetre` (`detail.zone`, `detail.lecture`, `detail.chantier`, `detail.terrain`). La raison serveur
  `chantier_intemperies` est déjà nommée dans la carte « Travailler » ; aucune logique climat codée ici.
- Appliquer la migration, puis essai en jeu par Fred (Arnie, terrain 3 de Luthécia).
