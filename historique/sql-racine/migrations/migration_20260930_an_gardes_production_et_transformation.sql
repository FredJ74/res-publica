-- ===========================================================================
-- LES DEUX DIMENSIONS QUI MANQUAIENT : PRODUIRE ET TRANSFORMER (30/09/2026)
-- Migration Supabase appliquee : 20260930165006 an_gardes_production_et_transformation
-- ---------------------------------------------------------------------------
-- La garde economique commune ne connaissait que trois verbes : vendre, acheter,
-- donner. L'arbitrage en ajoute deux :
--   PRODUCTION      -- bloquee des qu'une loi applicable vise la matiere (cas A ET B)
--   TRANSFORMATION  -- bloquee SEULEMENT si la loi l'a votee (cas B)
-- Elles rejoignent la MEME fonction, avec le meme parametre `mode` : il n'y a
-- toujours qu'un seul endroit du serveur qui sache ce qu'une loi interdit.
--
-- Rappel de l'arbitrage, inchange : conserver, consommer et DONNER restent
-- toujours possibles, et les mecaniques clandestines ne passent pas par cette
-- garde. Le bloc de gardes final le VERIFIE, plutot que de l'esperer.
-- ===========================================================================

create or replace function public.matiere_refus_circuit_legal(
  p_acteur text, p_matiere text, p_mode text)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_pays text; v_loi jsonb; v_mode text := lower(btrim(coalesce(p_mode, '')));
BEGIN
  IF coalesce(p_acteur, '') = '' OR coalesce(p_matiere, '') = '' THEN RETURN NULL; END IF;

  -- LE DON N'EST PAS UN CIRCUIT ECONOMIQUE. Seul endroit du serveur ou cette
  -- exception est ecrite. Un transfert gratuit reste possible, et sa trace au
  -- registre est justement ce qui rendra une filiere reperable.
  IF v_mode = 'don' THEN RETURN NULL; END IF;

  -- LA JURIDICTION EST CELLE DU PERSONNAGE, LUE EN BASE. Jamais un pays transmis
  -- par l'appelant : plusieurs des RPC gardees ici recoivent le leur du navigateur.
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = p_acteur;
  IF v_pays IS NULL THEN RETURN NULL; END IF;

  -- assemblee_loi_en_vigueur n'est vraie que pour une loi ADOPTEE **ET MISE EN
  -- APPLICATION** depuis le 30 septembre 2026 : une loi votee que le Ministre de
  -- l'Interieur n'a pas encore prononcee ne bloque donc rien.
  v_loi := public.assemblee_loi_en_vigueur(v_pays,
             jsonb_build_object('stackKey', p_matiere), now());
  IF v_loi IS NULL THEN RETURN NULL; END IF;

  -- LA TRANSFORMATION EST LA SEULE DIMENSION VOTEE. Un stock deja possede reste
  -- transformable, sauf si l'Assemblee l'a expressement interdit (cas B). Le
  -- niveau vient de la loi, jamais du client ni du ministre.
  IF v_mode = 'transformation'
     AND coalesce((v_loi -> 'portee' ->> 'transformation_stock_interdite')::boolean, false) IS NOT TRUE THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object('ok', false, 'raison', 'matiere_interdite',
                            'matiere', p_matiere, 'mode', v_mode, 'loi', v_loi);
END $fn$;

comment on function public.matiere_refus_circuit_legal(text, text, text) is
  'Garde COMMUNE des circuits economiques legaux portant sur une matiere premiere. Rend NULL si le mouvement est licite, sinon le refus complet (raison matiere_interdite, avec la loi). Modes : don (TOUJOURS licite -- l''Assemblee ferme les circuits legaux, elle ne rend pas la matiere intransferable), vente et achat (bloques), production (bloquee), transformation (bloquee SEULEMENT si la loi a vote le cas B, data.portee.transformation_stock_interdite). La juridiction est celle du personnage, lue dans personnages_donnees et jamais recue de l''appelant. Une loi adoptee mais non appliquee ne bloque rien.';

revoke all on function public.matiere_refus_circuit_legal(text, text, text) from public, anon;
grant execute on function public.matiere_refus_circuit_legal(text, text, text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- LES TROIS MOTEURS DE FABRICATION, GARDES PAR INSERTION
-- ---------------------------------------------------------------------------
-- POURQUOI PAR INSERTION ET NON PAR REECRITURE : ces fonctions portent des
-- regles anciennes (plafonds, CMUP, salaires, portions, chaines d'usine) qu'une
-- reecriture de memoire risquerait de perdre -- et le fichier de migration de
-- fonds_matiere_apporter avait deja diverge de la production. On lit donc le
-- corps REEL, on verifie l'ancre, on insere, et on verifie le resultat. Chaque
-- bloc est idempotent : rejoue, il ne fait rien.
DO $poser$
DECLARE
  v_def text; v_ancre text; v_garde text; v_n integer;
BEGIN
  -- ======== 1. commerce_produire : TRANSFORMATION des matieres de la recette ===
  -- Couvre les commerces historiques ET l'armurerie (les deux branches de la
  -- fonction ont rempli v_materiaux a ce point).
  SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname='public' AND p.proname='commerce_produire' AND p.prokind='f';
  IF v_def IS NULL THEN RAISE EXCEPTION 'commerce_produire introuvable'; END IF;
  IF v_def NOT LIKE '%matiere_refus_circuit_legal_lot%' THEN
    v_ancre := E'  v_sm := COALESCE(v_data->''stockMatieres'',''{}''::jsonb);\n  FOR v_m, v_q IN SELECT key, value FROM jsonb_each(v_materiaux) LOOP';
    v_n := (length(v_def) - length(replace(v_def, v_ancre, ''))) / length(v_ancre);
    IF v_n <> 1 THEN RAISE EXCEPTION 'commerce_produire : ancre trouvee % fois', v_n; END IF;
    v_garde :=
      E'  -- TRANSFORMATION D''UN STOCK (30 septembre 2026). Une loi appliquee peut\n' ||
      E'  -- interdire de transformer la matiere en produits finis (cas B). Le stock\n' ||
      E'  -- reste possede et consommable : seule la fabrication est fermee. Verifie\n' ||
      E'  -- avant toute lecture de stock et toute ecriture.\n' ||
      E'  IF public.matiere_refus_circuit_legal_lot(p_acteur, v_materiaux, ''transformation'') IS NOT NULL THEN\n' ||
      E'    RETURN public.matiere_refus_circuit_legal_lot(p_acteur, v_materiaux, ''transformation'');\n' ||
      E'  END IF;\n' || v_ancre;
    EXECUTE replace(v_def, v_ancre, v_garde);
  END IF;

  -- ======== 2. fonds_reference_produire_lots : TRANSFORMATION, moteur fonds PJ ==
  SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname='public' AND p.proname='fonds_reference_produire_lots' AND p.prokind='f';
  IF v_def IS NULL THEN RAISE EXCEPTION 'fonds_reference_produire_lots introuvable'; END IF;
  IF v_def NOT LIKE '%matiere_refus_circuit_legal_lot%' THEN
    v_ancre := E'  v_sm    := coalesce(v_data->''stockMatieres'', ''{}''::jsonb);';
    v_n := (length(v_def) - length(replace(v_def, v_ancre, ''))) / length(v_ancre);
    IF v_n <> 1 THEN RAISE EXCEPTION 'fonds_reference_produire_lots : ancre trouvee % fois', v_n; END IF;
    -- v_nom_pj, deja calcule plus haut, retire l'eventuel prefixe « pj: » : c'est
    -- le nom reel du personnage, celui que la garde sait resoudre en pays.
    v_garde :=
      E'  -- TRANSFORMATION D''UN STOCK (30 septembre 2026), cote fonds PJ. Meme regle\n' ||
      E'  -- et meme garde que le moteur historique : le niveau vient de la loi votee.\n' ||
      E'  IF public.matiere_refus_circuit_legal_lot(v_nom_pj, coalesce(v_r.materiaux, ''{}''::jsonb), ''transformation'') IS NOT NULL THEN\n' ||
      E'    RETURN public.matiere_refus_circuit_legal_lot(v_nom_pj, coalesce(v_r.materiaux, ''{}''::jsonb), ''transformation'');\n' ||
      E'  END IF;\n' || v_ancre;
    EXECUTE replace(v_def, v_ancre, v_garde);
  END IF;

  -- ======== 3. produire_en_usine : PRODUCTION de la sortie + TRANSFORMATION de
  --            l'entree. Cinq matieres du jeu sont reellement FABRIQUEES par une
  --            chaine d'usine (alcool, carburant, desinfectant, medicaments,
  --            tabac) : c'est le seul point de passage SERVEUR de production d'une
  --            matiere premiere. La recolte, elle, n'en a aucun -- dette consignee
  --            au rapport du chantier.
  SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname='public' AND p.proname='produire_en_usine' AND p.prokind='f';
  IF v_def IS NULL THEN RAISE EXCEPTION 'produire_en_usine introuvable'; END IF;
  IF v_def NOT LIKE '%matiere_refus_circuit_legal%' THEN
    v_ancre := E'  IF v_ville IS NULL THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''chaine_inconnue''); END IF;';
    v_n := (length(v_def) - length(replace(v_def, v_ancre, ''))) / length(v_ancre);
    IF v_n <> 1 THEN RAISE EXCEPTION 'produire_en_usine : ancre trouvee % fois', v_n; END IF;
    v_garde := v_ancre || E'\n' ||
      E'\n' ||
      E'  -- PRODUCTION LEGALE (30 septembre 2026). Une loi appliquee visant la matiere\n' ||
      E'  -- PRODUITE ferme la chaine : on ne fabrique plus legalement ce qui est\n' ||
      E'  -- interdit, dans les deux cas A et B.\n' ||
      E'  IF public.matiere_refus_circuit_legal(p_acteur, p_produit, ''production'') IS NOT NULL THEN\n' ||
      E'    RETURN public.matiere_refus_circuit_legal(p_acteur, p_produit, ''production'');\n' ||
      E'  END IF;\n' ||
      E'  -- TRANSFORMATION. La chaine CONSOMME aussi une matiere : si c''est elle qui\n' ||
      E'  -- est interdite et que la loi a vote le cas B, la chaine s''arrete aussi.\n' ||
      E'  IF public.matiere_refus_circuit_legal(p_acteur, v_matiere, ''transformation'') IS NOT NULL THEN\n' ||
      E'    RETURN public.matiere_refus_circuit_legal(p_acteur, v_matiere, ''transformation'');\n' ||
      E'  END IF;';
    EXECUTE replace(v_def, v_ancre, v_garde);
  END IF;
END $poser$;

-- ---------------------------------------------------------------------------
-- GARDES FINALES
-- ---------------------------------------------------------------------------
DO $garde$
DECLARE n integer; nom text;
BEGIN
  -- a) Les trois moteurs de fabrication consultent la garde.
  FOREACH nom IN ARRAY ARRAY['commerce_produire', 'fonds_reference_produire_lots', 'produire_en_usine']
  LOOP
    SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname='public' AND p.proname = nom AND p.prokind='f'
       AND pg_get_functiondef(p.oid) LIKE '%matiere_refus_circuit_legal%';
    IF n <> 1 THEN RAISE EXCEPTION '% ne consulte pas la garde de transformation', nom; END IF;
  END LOOP;

  -- b) produire_en_usine garde BIEN les deux dimensions.
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname='public' AND p.proname='produire_en_usine' AND p.prokind='f'
     AND pg_get_functiondef(p.oid) LIKE '%''production''%'
     AND pg_get_functiondef(p.oid) LIKE '%''transformation''%';
  IF n <> 1 THEN RAISE EXCEPTION 'produire_en_usine ne garde pas les deux dimensions'; END IF;

  -- c) Les SIX circuits d'achat/vente gardes la veille le sont toujours.
  FOREACH nom IN ARRAY ARRAY['commerce_apporter_matiere', 'fonds_matiere_apporter',
                             'vendre_matiere_a_usine', 'vendre_ressource_medicale',
                             'acheter_a_entrepot', 'acheter_a_la_criee']
  LOOP
    SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname='public' AND p.proname = nom AND p.prokind='f'
       AND pg_get_functiondef(p.oid) LIKE '%matiere_refus_circuit_legal%';
    IF n <> 1 THEN RAISE EXCEPTION '% a perdu sa garde legale', nom; END IF;
  END LOOP;

  -- d) La garde connait bien les quatre modes, et le don reste exempte.
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname='public' AND p.proname='matiere_refus_circuit_legal'
     AND pg_get_functiondef(p.oid) LIKE '%v_mode = ''don'' THEN RETURN NULL%'
     AND pg_get_functiondef(p.oid) LIKE '%transformation_stock_interdite%';
  IF n <> 1 THEN RAISE EXCEPTION 'la garde ne traite pas don + transformation'; END IF;

  -- e) LE CLANDESTIN ET LA CONSOMMATION RESTENT LIBRES. C'est une exigence de
  --    game design, pas un detail : on la verifie plutot que de l'esperer.
  FOREACH nom IN ARRAY ARRAY['assemblee_achat_illegal', 'inventaire_consommer',
                             'militaire_ration_consommer', 'militaire_terminal_manger',
                             'inventaire_donner', 'pnj_objet_transferer']
  LOOP
    SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname='public' AND p.proname = nom AND p.prokind='f'
       AND pg_get_functiondef(p.oid) LIKE '%matiere_refus_circuit_legal%';
    IF n <> 0 THEN RAISE EXCEPTION '% a ete gardee par erreur : circuit clandestin ou usage personnel', nom; END IF;
  END LOOP;

  SELECT count(*) INTO n FROM public.assemblee_propositions WHERE id LIKE 'zzbanc-%';
  IF n <> 0 THEN RAISE EXCEPTION '% loi(s) de test en base', n; END IF;
END $garde$;
