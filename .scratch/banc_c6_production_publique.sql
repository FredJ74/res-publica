-- ===========================================================================
-- BANC C6 bis — PRODUCTION PUBLIQUE, MATIERES PAR ACTIVITE, ACCEPTATION
-- 29 septembre 2026. Se termine par un RAISE : transaction annulee, zero residu.
-- Couvre le parcours T-shirt du cahier des charges (§14) et les refus du §15.
-- Aucun personnage ni commerce de production n'est modifie durablement.
-- ===========================================================================
DO $banc$
DECLARE
  R text := ''; n_ok int := 0; n_ko int := 0;
  F constant text := 'zzc6b-fonds';
  IMPL constant jsonb := jsonb_build_object('country','republic','city','capitale',
        'buildingId','centre-commercial','roomId','boutique_milieu','bailId','zzc6b-bail');
  u_arnie uuid; u_mars uuid; u_phil uuid;
  v jsonb; v2 jsonb; REF_ID text; n int;
  pa_av int; arg_av numeric; liq_av numeric; caisse_av numeric;
  pa_ap int; arg_ap numeric; liq_ap numeric; caisse_ap numeric;
  stk numeric; mat numeric; mat2 numeric;
BEGIN
  SELECT user_id INTO u_arnie FROM public.personnages_donnees WHERE name='Arnie';
  SELECT user_id INTO u_mars  FROM public.personnages_donnees WHERE name='Marsault';
  SELECT user_id INTO u_phil  FROM public.personnages_donnees WHERE name='Phileas Frogg';

  -- ---------- FIXTURE : un fonds de banc, trois personnages reels empruntes ----
  INSERT INTO public.entreprises (id, data) VALUES (F, jsonb_build_object(
    'id', F, 'version', 2, 'type', 'fonds_commerce', 'statut', 'actif',
    'proprietaire', 'Arnie', 'enseigne', 'Banc C6 bis', 'caisse', 1000,
    'implantation', IMPL,
    'typesAutorises', '["commerce-non-alimentaire","vetements"]'::jsonb,
    'references', '{}'::jsonb, 'stockReferences', '{}'::jsonb, 'coutMoyenReferences', '{}'::jsonb,
    'stockMatieres', '{}'::jsonb, 'coutMoyenMatieres', '{}'::jsonb, 'stockProduits', '{}'::jsonb,
    'parametres', '{}'::jsonb, 'historique', '[]'::jsonb));

  UPDATE public.personnages_donnees SET country='republic', current_city='capitale',
     current_building='centre-commercial', current_room='boutique_milieu',
     pa=10, arg=500, liquide=500,
     inventory='[{"name":"Textile","stackable":true,"stackKey":"textile","qty":50}]'::jsonb
   WHERE name IN ('Arnie','Marsault');
  -- Phileas reste a Montrouge : il sert aux deux tests d'absence physique.
  UPDATE public.personnages_donnees SET country='republic', current_city='ville_b',
     current_building=NULL, current_room=NULL, pa=10,
     inventory='[{"name":"Textile","stackable":true,"stackKey":"textile","qty":50}]'::jsonb
   WHERE name='Phileas Frogg';

  -- ===== §14.2 LES QUATRE MATIERES, AVANT TOUTE REFERENCE =====
  SELECT count(*) INTO n FROM public.fonds_matieres_accessibles(F);
  IF n = 4
     AND EXISTS (SELECT 1 FROM public.fonds_matieres_accessibles(F) m WHERE m.matiere='bois')
     AND EXISTS (SELECT 1 FROM public.fonds_matieres_accessibles(F) m WHERE m.matiere='textile')
     AND EXISTS (SELECT 1 FROM public.fonds_matieres_accessibles(F) m WHERE m.matiere='metal')
     AND EXISTS (SELECT 1 FROM public.fonds_matieres_accessibles(F) m WHERE m.matiere='produits_exotiques')
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    02 bois, metal, produits_exotiques et textile, AVANT toute reference';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] 02 ' || n || ' matieres'; END IF;

  -- ===== §14.3 / §5 ACCEPTE A HAUTEUR DE 2 PAR DEFAUT (C7, 29/09) =====
  -- REGLE CHANGEE, ASSERTION CHANGEE. C6 bis ouvrait une matiere accessible a
  -- `acceptee = false` : il fallait deux reglages pour une seule decision. C7 en
  -- fait une seule grandeur -- le stock maximum, 2 par defaut, 0 pour refuser --
  -- et l'acceptation s'en deduit. On verifie donc la nouvelle regle, pas la
  -- disparition de l'ancienne : un defaut de 2, accepte.
  IF EXISTS (SELECT 1 FROM public.fonds_matieres_accessibles(F) m
              WHERE m.matiere='textile' AND m.maximum = 2 AND m.acceptee = true)
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    03 textile accessible, stock maximum 2 par defaut';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] 03 defaut du textile incorrect'; END IF;

  -- §10 : le serveur est autoritaire, meme par appel direct. Le refus se dit
  -- maintenant par un maximum a zero, et il tient au meme endroit qu'avant.
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_arnie,'role','authenticated')::text, true);
  v := public.fonds_matiere_parametres('Arnie',F,'textile',20,0,true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_mars,'role','authenticated')::text, true);
  v := public.fonds_matiere_apporter('appro-zzb001','Marsault',F,'textile',5,'vente');
  v2 := public.fonds_matiere_apporter('appro-zzb002','Marsault',F,'textile',5,'don');
  IF v->>'raison'='matiere_non_acceptee' AND v2->>'raison'='matiere_non_acceptee'
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    03b vente ET don refuses serveur sur matiere a maximum 0';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] 03b -> ' || v::text || ' / ' || v2::text; END IF;

  -- ===== §14.4 LE PROPRIETAIRE PARAMETRE =====
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_arnie,'role','authenticated')::text, true);
  v := public.fonds_matiere_parametres('Arnie',F,'textile',20,20,true);
  IF (v->>'ok')::boolean AND (v->>'prixAchat')::numeric=20 AND (v->>'maximum')::int=20
     AND (v->>'acceptee')::boolean = true
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    04 textile : accepte, max 20, rachat 20 FR';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] 04 -> ' || v::text; END IF;

  -- ===== §14.5 / §11 LE VISITEUR VEND PUIS DONNE =====
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_mars,'role','authenticated')::text, true);
  SELECT arg, liquide INTO arg_av, liq_av FROM public.personnages_donnees WHERE name='Marsault';
  v := public.fonds_matiere_apporter('appro-zzb010','Marsault',F,'textile',10,'vente');
  SELECT arg, liquide INTO arg_ap, liq_ap FROM public.personnages_donnees WHERE name='Marsault';
  SELECT (data->>'caisse')::numeric, (data->'stockMatieres'->>'textile')::numeric
    INTO caisse_ap, stk FROM public.entreprises WHERE id=F;
  IF (v->>'ok')::boolean AND (v->>'quantite')::int=10 AND (v->>'montant')::numeric=200
     AND arg_ap=arg_av+200 AND liq_ap=liq_av+200 AND caisse_ap=800 AND stk=10
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    05 vente 10 x 20 FR : 200 FR transferes, caisse 1000->800, stock 10';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] 05 -> ' || v::text || ' caisse=' || caisse_ap || ' stock=' || stk; END IF;

  SELECT arg INTO arg_av FROM public.personnages_donnees WHERE name='Marsault';
  v := public.fonds_matiere_apporter('appro-zzb011','Marsault',F,'textile',4,'don');
  SELECT arg INTO arg_ap FROM public.personnages_donnees WHERE name='Marsault';
  SELECT (data->>'caisse')::numeric, (data->'stockMatieres'->>'textile')::numeric
    INTO caisse_ap, stk FROM public.entreprises WHERE id=F;
  IF (v->>'ok')::boolean AND (v->>'quantite')::int=4 AND (v->>'montant')::numeric=0
     AND arg_ap=arg_av AND caisse_ap=800 AND stk=14
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    05b don de 4 : aucun mouvement d''argent, stock 14';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] 05b -> ' || v::text; END IF;

  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_phil,'role','authenticated')::text, true);
  v := public.fonds_matiere_apporter('appro-zzb012','Phileas Frogg',F,'textile',2,'vente');
  IF v->>'raison'='pas_sur_place'
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    15a apport a distance refuse (pas_sur_place)';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] 15a -> ' || v::text; END IF;

  -- ===== §14.8-9 / §12 LA FORME S'APPELLE « T-SHIRT », LE LEGACY EST INTACT =====
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_arnie,'role','authenticated')::text, true);
  IF EXISTS (SELECT 1 FROM public.generique_recettes_systeme('haut') s
              WHERE s.recette_id='tshirt_psm' AND s.label='T-shirt'
                AND s.pa=1 AND s.portions=6 AND s.materiaux = '{"textile":2}'::jsonb)
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    08/09 forme nommee « T-shirt » : 2 textile + 1 PA -> 6 unites';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] 08 libelle de forme'; END IF;
  IF EXISTS (SELECT 1 FROM public.recettes_commerce
              WHERE id='tshirt_psm' AND label='T-shirt de Port-Sainte-Marie')
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    12a le libelle historique est intact pour le legacy';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] 12a libelle historique altere'; END IF;

  -- ===== FORMES C6 : UNE SEULE CARTE POSTALE, SEPT FORMES AU TOTAL =====
  SELECT count(*) INTO n FROM public.generique_recettes_systeme('carte-postale');
  IF n = 1 AND EXISTS (SELECT 1 FROM public.generique_recettes_systeme('carte-postale') s
                        WHERE s.label='Carte postale' AND s.portions=16
                          AND s.materiaux='{"bois":1}'::jsonb)
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    F1 une SEULE forme « Carte postale » proposee en C6 (1 bois -> 16)';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] F1 ' || n || ' formes de carte postale'; END IF;

  -- Les huit autres restent en base, intactes, avec leur libelle historique.
  SELECT count(*) INTO n FROM public.recettes_commerce
   WHERE generique_id='carte-postale' AND label LIKE 'Carte postale — %'
     AND materiaux='{"bois":1}'::jsonb AND portions=16 AND pa=1;
  IF n = 9
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    F2 les 9 recettes historiques intactes en base pour le legacy';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] F2 ' || n || ' recettes historiques conformes'; END IF;

  -- Et le marche legacy les voit toujours toutes les trois par ville.
  SELECT count(*) INTO n FROM public.entreprises e
   WHERE e.data->>'type'='marche'
     AND (SELECT count(*) FROM jsonb_array_elements_text(e.data->'carte') c
           WHERE c LIKE 'carte\_%') = 3;
  IF n = 3
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    F3 les 3 marches gardent leurs 3 cartes postales chacun';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] F3 ' || n || ' marches conformes'; END IF;

  -- Les sept formes attendues, et rien d'autre.
  SELECT count(*) INTO n FROM (
    SELECT s.label FROM public.generique_recettes_systeme('haut') s
    UNION ALL SELECT s.label FROM public.generique_recettes_systeme('souvenir') s
    UNION ALL SELECT s.label FROM public.generique_recettes_systeme('carte-postale') s
    UNION ALL SELECT s.label FROM public.generique_recettes_systeme('accessoire-vestimentaire') s
  ) t WHERE t.label IN ('T-shirt','Casquette','Écharpe','Porte-clé','Figurine',
                        'Figurine en plomb','Carte postale');
  IF n = 7
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    F4 les 7 formes C6 exactement : T-shirt, Casquette, Écharpe, Porte-clé, Figurine, Figurine en plomb, Carte postale';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] F4 ' || n || ' formes reconnues sur 7'; END IF;

  -- Aucun libelle historique n'a ete ecrase par un libelle de forme.
  SELECT count(*) INTO n FROM public.recettes_commerce
   WHERE id IN ('tshirt_psm','casquette_montrouge','echarpe_luthecia','porte_cle_palais_luthecia',
                'figurine_maxence_monfils','garde_republien_plomb','carte_luthecia_institutions')
     AND label IN ('T-shirt de Port-Sainte-Marie','Casquette de cheminot','Écharpe en soie',
                   'Porte-clé du Palais présidentiel','Figurine de Maxence Monfils',
                   'Garde républien en plomb','Carte postale — Institutions de Luthécia');
  IF n = 7
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    F5 les 7 libelles historiques sont intacts';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] F5 ' || n || ' libelles historiques intacts sur 7'; END IF;

  -- Les quatre matieres survivent au filtrage des formes.
  SELECT count(*) INTO n FROM public.fonds_matieres_accessibles(F);
  IF n = 4
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    F6 le filtrage des formes ne fait disparaitre aucune matiere (4)';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] F6 ' || n || ' matieres apres filtrage'; END IF;

  -- ===== §14.13 LA REFERENCE COMMERCIALE =====
  v := public.fonds_reference_creer('Arnie', F, 'haut', 'tshirt_psm',
        'Votez Arnie, le meilleur president, ever', 'Coton bio, promesses incluses');
  REF_ID := v->>'referenceId';
  IF (v->>'ok')::boolean AND REF_ID IS NOT NULL
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    13 reference creee dans la limite freemium (4 max)';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] 13 -> ' || v::text; END IF;

  -- ===== §14.16-21 UN VISITEUR PRODUIT POUR LE COMMERCE =====
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_mars,'role','authenticated')::text, true);
  SELECT pa, arg, liquide INTO pa_av, arg_av, liq_av FROM public.personnages_donnees WHERE name='Marsault';
  SELECT (data->>'caisse')::numeric INTO caisse_av FROM public.entreprises WHERE id=F;
  v := public.fonds_reference_produire('prod-zzb100','Marsault',F,REF_ID);
  SELECT pa, arg, liquide INTO pa_ap, arg_ap, liq_ap FROM public.personnages_donnees WHERE name='Marsault';
  SELECT (data->>'caisse')::numeric, (data->'stockReferences'->>REF_ID)::numeric,
         (data->'stockMatieres'->>'textile')::numeric
    INTO caisse_ap, stk, mat FROM public.entreprises WHERE id=F;
  IF (v->>'ok')::boolean AND (v->>'quantite')::int=6 AND (v->>'salaire')::numeric=50
     AND pa_ap=pa_av-1 AND arg_ap=arg_av+50 AND liq_ap=liq_av+50
     AND caisse_ap=caisse_av-50 AND stk=6 AND mat=12
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    16-21 visiteur : -1 PA, +50 FR ; commerce : -2 textile, -50 FR, +6 unites';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] 16-21 -> ' || v::text || ' paM=' || pa_ap || '/' || pa_av
                       || ' argM=' || arg_ap || '/' || arg_av || ' caisse=' || caisse_ap || ' stock=' || stk || ' textile=' || mat; END IF;

  -- ===== §14.24 IDEMPOTENCE =====
  v2 := public.fonds_reference_produire('prod-zzb100','Marsault',F,REF_ID);
  SELECT pa, arg INTO pa_av, arg_av FROM public.personnages_donnees WHERE name='Marsault';
  SELECT (data->>'caisse')::numeric, (data->'stockReferences'->>REF_ID)::numeric,
         (data->'stockMatieres'->>'textile')::numeric
    INTO caisse_ap, stk, mat2 FROM public.entreprises WHERE id=F;
  IF (v2->>'rejeu')::boolean AND pa_av=pa_ap AND arg_av=arg_ap
     AND caisse_ap=caisse_av-50 AND stk=6 AND mat2=12
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    24 rejeu : aucun second PA, salaire, textile ni produit';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] 24 -> ' || v2::text; END IF;

  -- ===== §14.22 MAXIMUM 5 / STOCK 0 : LE LOT DE 6 EST REFUSE EN ENTIER =====
  UPDATE public.entreprises SET data = jsonb_set(data, ARRAY['stockReferences', REF_ID], to_jsonb(0))
   WHERE id=F;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_arnie,'role','authenticated')::text, true);
  PERFORM public.fonds_reference_stock_max('Arnie', F, REF_ID, 5);
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_mars,'role','authenticated')::text, true);
  SELECT pa INTO pa_av FROM public.personnages_donnees WHERE name='Marsault';
  SELECT (data->>'caisse')::numeric, (data->'stockMatieres'->>'textile')::numeric
    INTO caisse_av, mat FROM public.entreprises WHERE id=F;
  v := public.fonds_reference_produire('prod-zzb200','Marsault',F,REF_ID);
  SELECT pa INTO pa_ap FROM public.personnages_donnees WHERE name='Marsault';
  SELECT (data->>'caisse')::numeric, (data->'stockMatieres'->>'textile')::numeric
    INTO caisse_ap, mat2 FROM public.entreprises WHERE id=F;
  IF v->>'raison'='stock_max_reference_depasse' AND (v->>'rendement')::int=6
     AND (v->>'maximum')::int=5 AND pa_ap=pa_av AND caisse_ap=caisse_av AND mat2=mat
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    22 maximum 5 / stock 0 : lot de 6 refuse en entier, rien preleve';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] 22 -> ' || v::text || ' pa=' || pa_ap || '/' || pa_av; END IF;

  -- ===== §14.23 / §2 MAXIMUM 0 = ILLIMITE =====
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_arnie,'role','authenticated')::text, true);
  PERFORM public.fonds_reference_stock_max('Arnie', F, REF_ID, 0);
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_mars,'role','authenticated')::text, true);
  v := public.fonds_reference_produire('prod-zzb300','Marsault',F,REF_ID);
  IF (v->>'ok')::boolean AND (v->>'quantite')::int=6
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    23 maximum 0 = illimite : la production passe';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] 23 -> ' || v::text; END IF;

  -- ===== §15 LES QUATRE REFUS, TOUJOURS AVANT LA PREMIERE ECRITURE =====
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_phil,'role','authenticated')::text, true);
  v := public.fonds_reference_produire('prod-zzb400','Phileas Frogg',F,REF_ID);
  IF v->>'raison'='pas_sur_place'
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    15b production a distance refusee (pas_sur_place)';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] 15b -> ' || v::text; END IF;

  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_mars,'role','authenticated')::text, true);
  UPDATE public.personnages_donnees SET pa=0 WHERE name='Marsault';
  SELECT (data->>'caisse')::numeric, (data->'stockMatieres'->>'textile')::numeric
    INTO caisse_av, mat FROM public.entreprises WHERE id=F;
  v := public.fonds_reference_produire('prod-zzb500','Marsault',F,REF_ID);
  SELECT (data->>'caisse')::numeric, (data->'stockMatieres'->>'textile')::numeric
    INTO caisse_ap, mat2 FROM public.entreprises WHERE id=F;
  IF v->>'raison'='pa_insuffisants' AND caisse_ap=caisse_av AND mat2=mat
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    15c PA insuffisants : refus avant toute consommation';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] 15c -> ' || v::text; END IF;
  UPDATE public.personnages_donnees SET pa=10 WHERE name='Marsault';

  UPDATE public.entreprises SET data = data || jsonb_build_object('caisse', 10) WHERE id=F;
  SELECT (data->'stockMatieres'->>'textile')::numeric INTO mat FROM public.entreprises WHERE id=F;
  SELECT pa INTO pa_av FROM public.personnages_donnees WHERE name='Marsault';
  v := public.fonds_reference_produire('prod-zzb600','Marsault',F,REF_ID);
  SELECT (data->>'caisse')::numeric, (data->'stockMatieres'->>'textile')::numeric
    INTO caisse_ap, mat2 FROM public.entreprises WHERE id=F;
  SELECT pa INTO pa_ap FROM public.personnages_donnees WHERE name='Marsault';
  IF v->>'raison'='caisse_insuffisante' AND caisse_ap=10 AND mat2=mat AND pa_ap=pa_av
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    15d caisse incapable de payer : refus avant PA, matiere et produit';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] 15d -> ' || v::text || ' caisse=' || caisse_ap; END IF;
  UPDATE public.entreprises SET data = data || jsonb_build_object('caisse', 1000) WHERE id=F;

  UPDATE public.entreprises SET data = jsonb_set(data, '{stockMatieres,textile}', to_jsonb(1)) WHERE id=F;
  SELECT pa INTO pa_av FROM public.personnages_donnees WHERE name='Marsault';
  v := public.fonds_reference_produire('prod-zzb700','Marsault',F,REF_ID);
  SELECT pa INTO pa_ap FROM public.personnages_donnees WHERE name='Marsault';
  SELECT (data->>'caisse')::numeric INTO caisse_ap FROM public.entreprises WHERE id=F;
  IF v->>'raison'='matieres_insuffisantes' AND pa_ap=pa_av AND caisse_ap=1000
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    15e matieres insuffisantes : refus avant PA et salaire';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] 15e -> ' || v::text; END IF;

  -- ===== §3 LE PROPRIETAIRE PRODUIT PAR LA MEME RPC =====
  UPDATE public.entreprises SET data = jsonb_set(data, '{stockMatieres,textile}', to_jsonb(20)) WHERE id=F;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_arnie,'role','authenticated')::text, true);
  SELECT pa, arg INTO pa_av, arg_av FROM public.personnages_donnees WHERE name='Arnie';
  v := public.fonds_reference_produire('prod-zzb800','Arnie',F,REF_ID);
  SELECT pa, arg INTO pa_ap, arg_ap FROM public.personnages_donnees WHERE name='Arnie';
  IF (v->>'ok')::boolean AND pa_ap=pa_av-1 AND arg_ap=arg_av+50
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    03c le proprietaire produit par la MEME RPC (-1 PA, +50 FR de sa caisse)';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] 03c -> ' || v::text; END IF;

  -- ===== §4 REFUSER UNE MATIERE N'EFFACE PAS LE STOCK DETENU =====
  -- C7 : le refus se dit par un maximum a zero. Le troisieme argument est ignore
  -- par le serveur -- on l'envoie a `true` pour le prouver : c'est le CHIFFRE qui
  -- decide, et rien d'autre.
  v := public.fonds_matiere_parametres('Arnie',F,'textile',20,0,true);
  SELECT (data->'stockMatieres'->>'textile')::numeric INTO stk FROM public.entreprises WHERE id=F;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_mars,'role','authenticated')::text, true);
  v2 := public.fonds_matiere_apporter('appro-zzb900','Marsault',F,'textile',1,'vente');
  IF (v->>'ok')::boolean AND (v->>'acceptee')::boolean=false
     AND v2->>'raison'='matiere_non_acceptee' AND stk > 0
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    04b maximum 0 ferme les apports SANS effacer le stock detenu';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] 04b -> ' || v::text || ' / ' || v2::text || ' stock=' || stk; END IF;

  -- ===== §4 UNE MATIERE ETRANGERE AUX ACTIVITES RESTE HORS DE PORTEE =====
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_arnie,'role','authenticated')::text, true);
  v := public.fonds_matiere_parametres('Arnie',F,'poisson',10,10,true);
  IF v->>'raison'='matiere_hors_activites'
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    04c une matiere etrangere aux activites n''est pas parametrable';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] 04c -> ' || v::text; END IF;

  -- =========================================================================
  -- C7 — LA CAISSE : APPORT ET PRELEVEMENT, EN NUMERAIRE ET SOUS IDENTITE
  -- =========================================================================
  -- Les deux primitives existaient sans interface depuis le socle. Elles sont
  -- branchees par C7, et corrigees au passage : identite exigee, `arg` ET
  -- `liquide` bouges ensemble, plus rien sous la cle anon.
  UPDATE public.entreprises SET data = data || jsonb_build_object('caisse', 1000) WHERE id=F;
  UPDATE public.personnages_donnees SET arg=500, liquide=500 WHERE name='Arnie';
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_arnie,'role','authenticated')::text, true);

  v := public.alimenter_caisse_fonds('Arnie', F, 200);
  SELECT arg, liquide INTO arg_ap, liq_ap FROM public.personnages_donnees WHERE name='Arnie';
  SELECT (data->>'caisse')::numeric INTO caisse_ap FROM public.entreprises WHERE id=F;
  IF (v->>'ok')::boolean AND (v->>'caisse')::numeric=1200
     AND caisse_ap=1200 AND arg_ap=300 AND liq_ap=300
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    C7a apport de 200 : caisse 1000->1200, arg ET liquide 500->300';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C7a -> ' || v::text || ' arg=' || arg_ap || ' liq=' || liq_ap; END IF;

  -- UNE CAISSE CONTIENT DES ESPECES : au-dela du liquide detenu, rien ne bouge.
  v := public.alimenter_caisse_fonds('Arnie', F, 9999);
  SELECT arg, liquide INTO arg_ap, liq_ap FROM public.personnages_donnees WHERE name='Arnie';
  SELECT (data->>'caisse')::numeric INTO caisse_ap FROM public.entreprises WHERE id=F;
  IF v->>'raison'='liquide_insuffisant' AND caisse_ap=1200 AND arg_ap=300 AND liq_ap=300
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    C7b apport au-dela des especes refuse, rien preleve';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C7b -> ' || v::text; END IF;

  v := public.retirer_caisse_fonds('Arnie', F, 300);
  SELECT arg, liquide INTO arg_ap, liq_ap FROM public.personnages_donnees WHERE name='Arnie';
  SELECT (data->>'caisse')::numeric INTO caisse_ap FROM public.entreprises WHERE id=F;
  IF (v->>'ok')::boolean AND caisse_ap=900 AND arg_ap=600 AND liq_ap=600
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    C7c prelevement de 300 : caisse 1200->900, arg ET liquide 300->600';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C7c -> ' || v::text || ' arg=' || arg_ap || ' liq=' || liq_ap; END IF;

  v := public.retirer_caisse_fonds('Arnie', F, 99999);
  SELECT (data->>'caisse')::numeric INTO caisse_ap FROM public.entreprises WHERE id=F;
  IF v->>'raison'='caisse_insuffisante' AND caisse_ap=900
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    C7d prelevement au-dela de la caisse refuse, caisse intacte';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C7d -> ' || v::text; END IF;

  -- LA CAISSE N'EST PAS UN BIEN COMMUN : un tiers present sur place n'y touche pas.
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_mars,'role','authenticated')::text, true);
  v := public.retirer_caisse_fonds('Marsault', F, 100);
  SELECT (data->>'caisse')::numeric INTO caisse_ap FROM public.entreprises WHERE id=F;
  IF v->>'raison'='pas_proprietaire' AND caisse_ap=900
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    C7e un tiers ne preleve pas la caisse d''un autre';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C7e -> ' || v::text; END IF;

  -- L'IDENTITE FAIT LOI. Le nom de l'acteur etait cru sur parole avant C7 : ce
  -- test-ci est la preuve que la porte est fermee, et il doit LEVER.
  --
  -- PIEGE DU BANC, CONSTATE LE 29/09 : poser request.jwt.claims NE SUFFIT PAS.
  -- est_mon_personnage commence par est_appel_serveur(), qui regarde le ROLE SQL
  -- courant : un banc lance en `postgres` (c'est le cas depuis psql comme depuis
  -- l'outil de migration) est un appel serveur, et exiger_acteur laisse TOUT
  -- passer. Le test paraissait alors echouer -- il ne testait rien. Il faut
  -- prendre reellement le role `authenticated`, celui du joueur.
  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    v := public.retirer_caisse_fonds('Arnie', F, 100);
    n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C7f Marsault a preleve la caisse d''Arnie -> ' || v::text;
  EXCEPTION WHEN insufficient_privilege THEN
    n_ok:=n_ok+1; R := R || E'\n  [OK]    C7f usurper l''acteur est refuse (exiger_acteur)';
  END;

  RAISE EXCEPTION E'\n===== BANC C6 bis + C7 — PRODUCTION PUBLIQUE ET CAISSE =====%\n\n  %/% reussis, % echec(s).\n(transaction annulee, aucun residu)',
    R, n_ok, n_ok+n_ko, n_ko;
END $banc$;
