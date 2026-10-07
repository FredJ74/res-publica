-- ===========================================================================
-- BANC C8 — PRODUCTION MULTI-LOTS ET NON-REGRESSION DE L'ANCIENNE PORTE
-- 29 septembre 2026. Se termine par un RAISE : transaction annulee, zero residu.
-- ---------------------------------------------------------------------------
-- LE CAS QUI COMPTE EST C8d. Il prouve qu'une commande de 3 lots dont le 3e
-- manque de matiere ne laisse RIEN derriere elle : c'est exactement le defaut
-- qu'une boucle cliente aurait produit (deux lots faits, PA depenses, caisse
-- entamee, et aucun moyen de revenir en arriere).
--
-- C8j prouve l'autre invariant silencieux : le CMUP du produit fini ne depend
-- pas du decoupage de la commande. Trois lots d'un coup et trois lots un par un
-- donnent le meme cout moyen -- sinon le multi-lots serait un moyen de fausser
-- la comptabilite d'un commerce.
--
-- PIEGE DU BANC (cf. doctrine, regle 9 bis) : lance en `postgres`, exiger_acteur
-- est court-circuite par est_appel_serveur(). C8l prend donc reellement le role
-- `authenticated` et le VERIFIE avant de conclure quoi que ce soit.
-- ===========================================================================
DO $banc$
DECLARE
  R text := ''; n_ok int := 0; n_ko int := 0;
  F  constant text := 'zzc8-fonds';
  F2 constant text := 'zzc8-fonds-2';
  IMPL constant jsonb := jsonb_build_object('country','republic','city','capitale',
        'buildingId','centre-commercial','roomId','boutique_milieu','bailId','zzc8-bail');
  u_arnie uuid; v jsonb; v2 jsonb; RID text; RID2 text; n int;
  pa_av int; pa_ap int; arg_av numeric; arg_ap numeric; liq_av numeric; liq_ap numeric;
  caisse_av numeric; caisse_ap numeric; tex_av numeric; tex_ap numeric;
  stk numeric; cmup1 numeric; cmup2 numeric;
BEGIN
  SELECT user_id INTO u_arnie FROM public.personnages_donnees WHERE name='Arnie';
  PERFORM set_config('request.jwt.claims', json_build_object('sub',u_arnie,'role','authenticated')::text, true);

  UPDATE public.personnages_donnees SET country='republic', current_city='capitale',
     current_building='centre-commercial', current_room='boutique_milieu',
     pa=10, arg=500, liquide=500 WHERE name='Arnie';

  INSERT INTO public.entreprises (id, data) VALUES (F, jsonb_build_object(
    'id', F, 'version', 2, 'type', 'fonds_commerce', 'statut', 'actif',
    'proprietaire', 'Arnie', 'enseigne', 'Banc C8', 'caisse', 5000,
    'implantation', IMPL,
    'typesAutorises', '["commerce-non-alimentaire","vetements"]'::jsonb,
    'references', '{}'::jsonb, 'stockReferences', '{}'::jsonb, 'coutMoyenReferences', '{}'::jsonb,
    'stockMatieres', jsonb_build_object('textile', 100),
    'coutMoyenMatieres', jsonb_build_object('textile', 10),
    'stockProduits', '{}'::jsonb, 'parametres', '{}'::jsonb, 'historique', '[]'::jsonb));

  v := public.fonds_reference_creer('Arnie', F, 'haut', 'tshirt_psm', 'T-shirt du banc', null);
  RID := v->>'referenceId';
  IF RID IS NULL THEN RAISE EXCEPTION 'FIXTURE KO : %', v::text; END IF;

  -- Recette de reference : 2 textile + 1 PA -> 6 unites.
  -- Donc 3 lots = 6 textile, 3 PA, 18 unites, 150 FR de salaire.

  -- ===== C8a TOUT EST PROPORTIONNEL =====
  SELECT pa, arg, liquide INTO pa_av, arg_av, liq_av FROM public.personnages_donnees WHERE name='Arnie';
  SELECT (data->>'caisse')::numeric, (data->'stockMatieres'->>'textile')::numeric
    INTO caisse_av, tex_av FROM public.entreprises WHERE id=F;
  v := public.fonds_reference_produire_lots('prod-zzc8aaa','Arnie',F,RID,3);
  SELECT pa, arg, liquide INTO pa_ap, arg_ap, liq_ap FROM public.personnages_donnees WHERE name='Arnie';
  SELECT (data->>'caisse')::numeric, (data->'stockMatieres'->>'textile')::numeric,
         (data->'stockReferences'->>RID)::numeric
    INTO caisse_ap, tex_ap, stk FROM public.entreprises WHERE id=F;
  IF (v->>'ok')::boolean AND (v->>'lots')::int=3 AND (v->>'quantite')::int=18
     AND (v->>'paPreleves')::int=3 AND (v->>'salaire')::numeric=150
     AND pa_ap=pa_av-3 AND arg_ap=arg_av+150 AND liq_ap=liq_av+150
     AND caisse_ap=caisse_av-150 AND tex_ap=tex_av-6 AND stk=18
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    C8a 3 lots : 18 unites, 6 textile, 3 PA, 150 FR — tout proportionnel';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C8a -> ' || v::text || ' pa=' || pa_ap || ' caisse=' || caisse_ap
                       || ' textile=' || tex_ap || ' stock=' || stk; END IF;

  -- ===== C8b UNE COMMANDE, UNE PREUVE, AUX GRANDEURS AGREGEES =====
  SELECT count(*) INTO n FROM public.productions_references WHERE requete='prod-zzc8aaa';
  IF n = 1 AND EXISTS (SELECT 1 FROM public.productions_references
                        WHERE requete='prod-zzc8aaa' AND quantite=18 AND pa=3
                          AND matieres = '{"textile": 6}'::jsonb)
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    C8b une seule ligne de preuve, quantite 18 / pa 3 / 6 textile';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C8b ' || n || ' ligne(s) de preuve'; END IF;

  -- ===== C8c IDEMPOTENCE D'UNE COMMANDE MULTI-LOTS =====
  v2 := public.fonds_reference_produire_lots('prod-zzc8aaa','Arnie',F,RID,3);
  SELECT pa INTO pa_ap FROM public.personnages_donnees WHERE name='Arnie';
  SELECT (data->'stockReferences'->>RID)::numeric INTO stk FROM public.entreprises WHERE id=F;
  IF (v2->>'rejeu')::boolean AND pa_ap=pa_av-3 AND stk=18
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    C8c rejeu de la meme cle : ni second lot ni second salaire';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C8c -> ' || v2::text; END IF;

  -- ===== C8d ATOMICITE — LE TEST CENTRAL DE CE LOT =====
  UPDATE public.entreprises SET data = jsonb_set(data,'{stockMatieres,textile}','5'::jsonb) WHERE id=F;
  SELECT pa, arg INTO pa_av, arg_av FROM public.personnages_donnees WHERE name='Arnie';
  SELECT (data->>'caisse')::numeric INTO caisse_av FROM public.entreprises WHERE id=F;
  v := public.fonds_reference_produire_lots('prod-zzc8bbb','Arnie',F,RID,3);
  SELECT pa, arg INTO pa_ap, arg_ap FROM public.personnages_donnees WHERE name='Arnie';
  SELECT (data->>'caisse')::numeric, (data->'stockMatieres'->>'textile')::numeric,
         (data->'stockReferences'->>RID)::numeric
    INTO caisse_ap, tex_ap, stk FROM public.entreprises WHERE id=F;
  IF v->>'raison'='matieres_insuffisantes'
     AND (v->'manquantes'->0->>'requis')::numeric=6 AND (v->'manquantes'->0->>'dispo')::numeric=5
     AND pa_ap=pa_av AND arg_ap=arg_av AND caisse_ap=caisse_av AND tex_ap=5 AND stk=18
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    C8d 3 lots pour 2 possibles : refus ENTIER, zero demi-production';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C8d -> ' || v::text || ' pa=' || pa_ap
                       || ' caisse=' || caisse_ap || ' textile=' || tex_ap || ' stock=' || stk; END IF;

  -- ===== C8e/C8f LE STOCK MAXIMUM PORTE SUR LE TOTAL DEMANDE =====
  UPDATE public.entreprises SET data = jsonb_set(jsonb_set(data,'{stockMatieres,textile}','100'::jsonb),
        ARRAY['stockReferences', RID], '0'::jsonb) WHERE id=F;
  PERFORM public.fonds_reference_stock_max('Arnie', F, RID, 10);
  v := public.fonds_reference_produire_lots('prod-zzc8ccc','Arnie',F,RID,3);
  IF v->>'raison'='stock_max_reference_depasse' AND (v->>'rendement')::int=18
     AND (v->>'rendementLot')::int=6 AND (v->>'lots')::int=3 AND (v->>'maximum')::int=10
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    C8e capacite 10 : 3 lots (18) refuses, le total est oppose';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C8e -> ' || v::text; END IF;
  v := public.fonds_reference_produire_lots('prod-zzc8ddd','Arnie',F,RID,1);
  IF (v->>'ok')::boolean AND (v->>'quantite')::int=6
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    C8f le meme produit passe a 1 lot (6 <= 10)';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C8f -> ' || v::text; END IF;

  -- ===== C8g/C8h PA ET CAISSE PORTENT AUSSI SUR LE TOTAL =====
  UPDATE public.entreprises SET data = jsonb_set(jsonb_set(data, ARRAY['stockReferences', RID],'0'::jsonb),
        ARRAY['parametres','stockMaxReferences',RID],'0'::jsonb) WHERE id=F;
  UPDATE public.personnages_donnees SET pa=2 WHERE name='Arnie';
  v := public.fonds_reference_produire_lots('prod-zzc8eee','Arnie',F,RID,3);
  IF v->>'raison'='pa_insuffisants' AND (v->>'requis')::int=3 AND (v->>'disponibles')::int=2
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    C8g PA : le refus porte sur les 3 PA de la commande';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C8g -> ' || v::text; END IF;
  UPDATE public.personnages_donnees SET pa=10 WHERE name='Arnie';
  UPDATE public.entreprises SET data = data || jsonb_build_object('caisse', 100) WHERE id=F;
  v := public.fonds_reference_produire_lots('prod-zzc8fff','Arnie',F,RID,3);
  IF v->>'raison'='caisse_insuffisante' AND (v->>'salaire')::numeric=150
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    C8h caisse 100 / salaire 150 : refus avant toute ecriture';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C8h -> ' || v::text; END IF;
  UPDATE public.entreprises SET data = data || jsonb_build_object('caisse', 5000) WHERE id=F;

  -- ===== C8i BORNES DE FORME DU NOMBRE DE LOTS =====
  v  := public.fonds_reference_produire_lots('prod-zzc8ggg','Arnie',F,RID,0);
  v2 := public.fonds_reference_produire_lots('prod-zzc8hhh','Arnie',F,RID,100);
  IF v->>'raison'='lots_invalides' AND v2->>'raison'='lots_invalides'
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    C8i 0 et 100 lots refuses (borne de forme 1..99)';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C8i -> ' || v::text || ' / ' || v2::text; END IF;

  -- ===== C8j LE CMUP NE DEPEND PAS DU DECOUPAGE DE LA COMMANDE =====
  INSERT INTO public.entreprises (id, data) VALUES (F2, jsonb_build_object(
    'id', F2, 'version', 2, 'type', 'fonds_commerce', 'statut', 'actif',
    'proprietaire', 'Arnie', 'enseigne', 'Banc C8 jumeau', 'caisse', 5000,
    'implantation', IMPL || jsonb_build_object('bailId','zzc8-bail-2'),
    'typesAutorises', '["commerce-non-alimentaire","vetements"]'::jsonb,
    'references', '{}'::jsonb, 'stockReferences', '{}'::jsonb, 'coutMoyenReferences', '{}'::jsonb,
    'stockMatieres', jsonb_build_object('textile', 100),
    'coutMoyenMatieres', jsonb_build_object('textile', 10),
    'stockProduits', '{}'::jsonb, 'parametres', '{}'::jsonb, 'historique', '[]'::jsonb));
  v := public.fonds_reference_creer('Arnie', F2, 'haut', 'tshirt_psm', 'T-shirt jumeau', null);
  RID2 := v->>'referenceId';
  UPDATE public.entreprises SET data = jsonb_set(data, ARRAY['stockReferences', RID],'0'::jsonb) WHERE id=F;
  UPDATE public.entreprises SET data = data #- ARRAY['coutMoyenReferences', RID] WHERE id=F;
  UPDATE public.personnages_donnees SET pa=10 WHERE name='Arnie';
  PERFORM public.fonds_reference_produire_lots('prod-zzc8iii','Arnie',F,RID,3);
  PERFORM public.fonds_reference_produire('prod-zzc8j01','Arnie',F2,RID2);
  PERFORM public.fonds_reference_produire('prod-zzc8j02','Arnie',F2,RID2);
  PERFORM public.fonds_reference_produire('prod-zzc8j03','Arnie',F2,RID2);
  SELECT (data->'coutMoyenReferences'->>RID)::numeric  INTO cmup1 FROM public.entreprises WHERE id=F;
  SELECT (data->'coutMoyenReferences'->>RID2)::numeric INTO cmup2 FROM public.entreprises WHERE id=F2;
  IF cmup1 IS NOT NULL AND cmup1 = cmup2
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    C8j CMUP identique : 3 lots d''un coup = 3 lots un par un (' || cmup1 || ')';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C8j ' || coalesce(cmup1::text,'NULL') || ' vs ' || coalesce(cmup2::text,'NULL'); END IF;

  -- ===== C8k L'ANCIENNE PORTE N'A PAS CHANGE DE COMPORTEMENT =====
  SELECT (data->'stockReferences'->>RID2)::numeric INTO stk FROM public.entreprises WHERE id=F2;
  SELECT pa INTO pa_av FROM public.personnages_donnees WHERE name='Arnie';
  v := public.fonds_reference_produire('prod-zzc8kkk','Arnie',F2,RID2);
  SELECT pa INTO pa_ap FROM public.personnages_donnees WHERE name='Arnie';
  IF (v->>'ok')::boolean AND (v->>'quantite')::int=6 AND (v->>'lots')::int=1
     AND (v->>'salaire')::numeric=50 AND pa_ap=pa_av-1
     AND (SELECT (data->'stockReferences'->>RID2)::numeric FROM public.entreprises WHERE id=F2) = stk+6
    THEN n_ok:=n_ok+1; R := R || E'\n  [OK]    C8k l''ancienne porte fait toujours exactement 1 lot (6 unites, 1 PA, 50 FR)';
    ELSE n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C8k -> ' || v::text; END IF;

  -- ===== C8l L'IDENTITE TIENT SUR LA NOUVELLE PORTE =====
  PERFORM set_config('role', 'authenticated', true);
  IF public.est_appel_serveur() THEN
    n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C8l le banc est reste en appel serveur : le test ne prouve rien';
  ELSE
    BEGIN
      v := public.fonds_reference_produire_lots('prod-zzc8lll','Marsault',F,RID,1);
      n_ko:=n_ko+1; R := R || E'\n  [ECHEC] C8l usurpation acceptee -> ' || v::text;
    EXCEPTION WHEN insufficient_privilege THEN
      n_ok:=n_ok+1; R := R || E'\n  [OK]    C8l usurper l''acteur est refuse sur la porte multi-lots';
    END;
  END IF;

  RAISE EXCEPTION E'\n===== BANC C8 — PRODUCTION MULTI-LOTS — %/% verts =====%\n(transaction annulee)',
    n_ok, n_ok+n_ko, R;
END $banc$;
