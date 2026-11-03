-- =============================================================================================
-- SUCCESSIONS : OUVERTURE ET RÉPONSE PAR LE SERVEUR (Claude, 03/11/2026)
-- =============================================================================================
-- Relevé du 03/11 (RELAIS.md, point 4) : la table `successions` était écrivable par tout joueur
-- identifié (politiques `acteur_identifie()` seules, aucun trigger). Un joueur pouvait donc :
--   . inventer la succession d'un vivant, puis geler ses terrains et entreprises (les portes de
--     gel ne vérifient que l'existence d'une succession « en attente » de ce défunt) ;
--   . s'attribuer une part d'argent de son choix, que la passe de nuit verse ensuite ;
--   . réécrire la chaîne d'une succession réelle pour se désigner bénéficiaire.
--
-- Deux portes remplacent les écritures de l'écran, règles d'origine conservées :
--   . succession_ouvrir() : le défunt est TOUJOURS l'appelant ; reprise stricte d'une succession
--     déjà en attente (rien n'est recalculé) ; sinon photographie au serveur : testament actif,
--     conjoint (mariage actif, existence revalidée), terrains et entreprises possédés, argent =
--     somme réelle des comptes bancaires, droits 33 % (90 % État, reste notaire), parts d'argent
--     du testament (reliquat d'arrondi à la première part), chaînes principal → remplaçant →
--     conjoint légal, délai de 10 jours réels.
--   . succession_repondre(p_succession, p_disposition, p_reponse) : seul le bénéficiaire de l'étape
--     courante, avant l'échéance ; une renonciation convoque l'étape suivante.
-- Puis INSERT et UPDATE de `successions` sont fermés à l'écran (la passe de nuit, au rôle
-- service, n'est pas concernée).
-- =============================================================================================

CREATE OR REPLACE FUNCTION public.succession_personnage_existe_interne(p_nom text)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT nullif(btrim(coalesce(p_nom, '')), '') IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_nom);
$function$;

-- Première étape d'une chaîne : principal → remplaçant → conjoint légal → aucune.
CREATE OR REPLACE FUNCTION public.succession_chaine_initiale_interne(p_principal text, p_remplacant text, p_conjoint text)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_role text; v_benef text;
  v_convoque text := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
  v_expire text := to_char((now() + interval '10 days') AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
BEGIN
  IF public.succession_personnage_existe_interne(p_principal) THEN v_role := 'principal'; v_benef := p_principal;
  ELSIF public.succession_personnage_existe_interne(p_remplacant) THEN v_role := 'remplacant'; v_benef := p_remplacant;
  ELSIF nullif(p_conjoint, '') IS NOT NULL THEN v_role := 'legal_conjoint'; v_benef := p_conjoint;
  ELSE RETURN '[]'::jsonb; END IF;
  RETURN jsonb_build_array(jsonb_build_object('role', v_role, 'beneficiaire', v_benef,
    'convoque_le', v_convoque, 'expires_at', v_expire, 'reponse', NULL, 'repondu_le', NULL));
END $function$;

CREATE OR REPLACE FUNCTION public.succession_ouvrir()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; s public.successions%ROWTYPE; v_test public.testaments%ROWTYPE;
  v_mariage public.mariages%ROWTYPE; v_conjoint text; v_contenu jsonb; v_biens jsonb := '{}'::jsonb;
  v_disp jsonb := '[]'::jsonb; v_brut integer; v_droits integer; v_etat integer; v_notaire integer; v_net integer;
  r record; b jsonb; v_parts jsonb; v_n integer; v_i integer; v_m integer; v_distribue integer := 0; v_montants integer[];
  v_id text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT * INTO v_mariage FROM public.mariages
   WHERE statut = 'actif' AND (conjoint1 = v_moi OR conjoint2 = v_moi) ORDER BY created_at DESC LIMIT 1;

  -- Reprise stricte d'une ouverture interrompue : rien n'est recalculé.
  SELECT * INTO s FROM public.successions WHERE defunt = v_moi AND statut = 'en_attente' FOR UPDATE;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'reprise', true, 'succession_id', s.id, 'dispositions', s.dispositions,
      'conjoint', s.conjoint, 'testament_id', s.testament_id, 'mariage_id', v_mariage.id);
  END IF;

  SELECT * INTO v_test FROM public.testaments WHERE testateur = v_moi AND statut = 'actif' ORDER BY created_at DESC LIMIT 1;
  v_contenu := CASE WHEN jsonb_typeof(v_test.contenu) = 'object' THEN v_test.contenu ELSE '{}'::jsonb END;
  IF jsonb_typeof(v_contenu -> 'biens') = 'array' THEN
    FOR b IN SELECT * FROM jsonb_array_elements(v_contenu -> 'biens') LOOP
      IF nullif(b ->> 'id', '') IS NOT NULL THEN v_biens := v_biens || jsonb_build_object(b ->> 'id', b); END IF;
    END LOOP;
  END IF;

  IF v_mariage.id IS NOT NULL THEN
    v_conjoint := CASE WHEN v_mariage.conjoint1 = v_moi THEN v_mariage.conjoint2 ELSE v_mariage.conjoint1 END;
    IF NOT public.succession_personnage_existe_interne(v_conjoint) THEN v_conjoint := NULL; END IF;
  END IF;

  -- Terrains, bâtiments et locaux possédés.
  FOR r IN SELECT building_id FROM public.terrains_etat
            WHERE country = v_pays AND proprietaire = v_moi ORDER BY building_id LOOP
    b := v_biens -> r.building_id;
    v_disp := v_disp || jsonb_build_array(jsonb_build_object('id', r.building_id, 'type', 'terrain',
      'libelle', r.building_id, 'remplacant_prevu', nullif(b ->> 'remplacant', ''),
      'chaine', public.succession_chaine_initiale_interne(b ->> 'beneficiaire', b ->> 'remplacant', v_conjoint),
      'etat', 'en_attente', 'resultat', NULL, 'regle', false));
  END LOOP;
  -- Entreprises possédées.
  FOR r IN SELECT id FROM public.entreprises
            WHERE data ->> 'proprietaire' = v_moi AND coalesce(data ->> 'country', v_pays) = v_pays ORDER BY id LOOP
    b := v_biens -> r.id;
    v_disp := v_disp || jsonb_build_array(jsonb_build_object('id', r.id, 'type', 'entreprise',
      'libelle', r.id, 'remplacant_prevu', nullif(b ->> 'remplacant', ''),
      'chaine', public.succession_chaine_initiale_interne(b ->> 'beneficiaire', b ->> 'remplacant', v_conjoint),
      'etat', 'en_attente', 'resultat', NULL, 'regle', false));
  END LOOP;

  -- Fiscalité globale, calculée une seule fois sur la somme réelle des comptes bancaires.
  SELECT coalesce(sum(greatest(0, solde)), 0)::integer INTO v_brut FROM public.comptes_bancaires WHERE personnage = v_moi;
  v_droits := floor(v_brut * 0.33)::integer;
  v_etat := floor(v_droits * 0.90)::integer;
  v_notaire := v_droits - v_etat;
  v_net := v_brut - v_droits;

  IF v_net > 0 THEN
    SELECT coalesce(jsonb_agg(p ORDER BY o), '[]'::jsonb) INTO v_parts
      FROM jsonb_array_elements(CASE WHEN jsonb_typeof(v_contenu -> 'argent') = 'array' THEN v_contenu -> 'argent' ELSE '[]'::jsonb END)
           WITH ORDINALITY AS t(p, o)
     WHERE nullif(p ->> 'beneficiaire', '') IS NOT NULL
       AND jsonb_typeof(p -> 'pourcentage') = 'number' AND (p ->> 'pourcentage')::numeric > 0;
    v_n := jsonb_array_length(v_parts);
    IF v_n > 0 THEN
      v_montants := array_fill(0, ARRAY[v_n]);
      FOR v_i IN 2..v_n LOOP
        v_m := floor(v_net * ((v_parts -> (v_i - 1) ->> 'pourcentage')::numeric / 100))::integer;
        v_montants[v_i] := v_m; v_distribue := v_distribue + v_m;
      END LOOP;
      v_montants[1] := v_net - v_distribue;  -- reliquat d'arrondi à la première part
      FOR v_i IN 1..v_n LOOP
        b := v_parts -> (v_i - 1);
        v_disp := v_disp || jsonb_build_array(jsonb_build_object('id', 'argent-' || v_i, 'type', 'argent',
          'part_nette', v_montants[v_i], 'remplacant_prevu', nullif(b ->> 'remplacant', ''),
          'chaine', public.succession_chaine_initiale_interne(b ->> 'beneficiaire', b ->> 'remplacant', v_conjoint),
          'etat', 'en_attente', 'resultat', NULL, 'regle', false));
      END LOOP;
    ELSE
      v_disp := v_disp || jsonb_build_array(jsonb_build_object('id', 'argent-1', 'type', 'argent',
        'part_nette', v_net, 'remplacant_prevu', NULL,
        'chaine', public.succession_chaine_initiale_interne(NULL, NULL, v_conjoint),
        'etat', 'en_attente', 'resultat', NULL, 'regle', false));
    END IF;
  END IF;

  v_id := 'succession-' || floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint;
  INSERT INTO public.successions (id, defunt, country, testament_id, statut, conjoint,
    argent_brut_total, droits_total, part_etat, part_notaire, argent_net_total, dispositions)
  VALUES (v_id, v_moi, v_pays, v_test.id, 'en_attente', v_conjoint, v_brut, v_droits, v_etat, v_notaire, v_net, v_disp);

  RETURN jsonb_build_object('ok', true, 'reprise', false, 'succession_id', v_id, 'dispositions', v_disp,
    'conjoint', v_conjoint, 'testament_id', v_test.id, 'mariage_id', v_mariage.id,
    'argent_brut_total', v_brut, 'argent_net_total', v_net);
END $function$;

CREATE OR REPLACE FUNCTION public.succession_repondre(p_succession text, p_disposition text, p_reponse text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; s public.successions%ROWTYPE; v_idx integer; d jsonb; v_chaine jsonb; v_etape jsonb; v_n integer;
  v_roles text[]; v_suiv jsonb; v_now text := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
  v_expire text := to_char((now() + interval '10 days') AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_reponse IS NULL OR p_reponse NOT IN ('accepte', 'renonce') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reponse_invalide'); END IF;
  SELECT * INTO s FROM public.successions WHERE id = p_succession FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'succession_introuvable'); END IF;
  IF s.statut IS DISTINCT FROM 'en_attente' THEN RETURN jsonb_build_object('ok', false, 'raison', 'succession_reglee'); END IF;
  SELECT o - 1, e INTO v_idx, d FROM jsonb_array_elements(coalesce(s.dispositions, '[]'::jsonb)) WITH ORDINALITY t(e, o)
   WHERE e ->> 'id' = p_disposition LIMIT 1;
  IF d IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'disposition_introuvable'); END IF;
  v_chaine := CASE WHEN jsonb_typeof(d -> 'chaine') = 'array' THEN d -> 'chaine' ELSE '[]'::jsonb END;
  v_n := jsonb_array_length(v_chaine);
  v_etape := v_chaine -> (v_n - 1);
  IF v_etape IS NULL OR v_etape ->> 'beneficiaire' IS DISTINCT FROM v_moi 
     OR coalesce(jsonb_typeof(v_etape -> 'reponse'), 'null') <> 'null' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_concerne'); END IF;
  IF (v_etape ->> 'expires_at')::timestamptz < now() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_expire'); END IF;

  v_etape := v_etape || jsonb_build_object('reponse', p_reponse, 'repondu_le', v_now);
  v_chaine := jsonb_set(v_chaine, ARRAY[(v_n - 1)::text], v_etape);
  IF p_reponse = 'renonce' THEN
    SELECT coalesce(array_agg(e ->> 'role'), '{}') INTO v_roles FROM jsonb_array_elements(v_chaine) e;
    IF v_etape ->> 'role' = 'principal' AND nullif(d ->> 'remplacant_prevu', '') IS NOT NULL
       AND NOT ('remplacant' = ANY (v_roles)) AND public.succession_personnage_existe_interne(d ->> 'remplacant_prevu') THEN
      v_suiv := jsonb_build_object('role', 'remplacant', 'beneficiaire', d ->> 'remplacant_prevu');
    ELSIF v_etape ->> 'role' <> 'legal_conjoint' AND nullif(s.conjoint, '') IS NOT NULL AND NOT ('legal_conjoint' = ANY (v_roles)) THEN
      v_suiv := jsonb_build_object('role', 'legal_conjoint', 'beneficiaire', s.conjoint);
    END IF;
    IF v_suiv IS NOT NULL THEN
      v_chaine := v_chaine || jsonb_build_array(v_suiv || jsonb_build_object('convoque_le', v_now, 'expires_at', v_expire,
                                                                             'reponse', NULL, 'repondu_le', NULL));
    END IF;
  END IF;
  UPDATE public.successions
     SET dispositions = jsonb_set(dispositions, ARRAY[v_idx::text], d || jsonb_build_object('chaine', v_chaine))
   WHERE id = p_succession;
  RETURN jsonb_build_object('ok', true, 'reponse', p_reponse, 'nouveau_convoque', v_suiv ->> 'beneficiaire',
    'defunt', s.defunt);
END $function$;

REVOKE ALL ON FUNCTION public.succession_personnage_existe_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.succession_chaine_initiale_interne(text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.succession_ouvrir() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.succession_repondre(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.succession_ouvrir() TO authenticated;
GRANT EXECUTE ON FUNCTION public.succession_repondre(text, text, text) TO authenticated;

DROP POLICY IF EXISTS successions_ecriture_acteur ON public.successions;
DROP POLICY IF EXISTS successions_maj_acteur ON public.successions;
REVOKE INSERT, UPDATE, DELETE ON public.successions FROM anon, authenticated;
