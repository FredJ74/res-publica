-- Pouvoir en Sovarka, étape 5 (Fred, 07/11/2026, GAME-DESIGN-NOVOMIRSK.md) :
-- les sièges du Soviet Suprême (9) sont répartis entre les partis à la semaine à la gloire
-- (sovarka_gloire_proclamer, cycle soviet_gloire_partis, data.gloire.sieges) ; chaque chef de
-- parti désigne ses députés parmi les membres de son parti, à l'hémicycle du Soviet Suprême.
-- Les désignations vivent dans data.gloire.deputes { partiId: [noms] } ; la fiche du député
-- porte poste_depute. À la proclamation suivante, les députés sortants perdent leur siège.

-- État lisible par l'écran : sièges, désignations, parti et rôle du joueur.
CREATE OR REPLACE FUNCTION public.sovarka_soviet_etat()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_moi text; v_g jsonb; v_parti text; v_chef boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(data::jsonb -> 'gloire', '{}'::jsonb) INTO v_g FROM public.cycles_electoraux WHERE id = 'soviet_gloire_partis';
  v_parti := public.sovarka_parti_de(v_moi);
  v_chef := EXISTS (SELECT 1 FROM public.organisations o WHERE o.id = v_parti AND o.data::jsonb ->> 'chef' = v_moi);
  RETURN jsonb_build_object('ok', true,
    'vainqueur', v_g -> 'vainqueurNom', 'scores', coalesce(v_g -> 'scores', '[]'::jsonb),
    'sieges', coalesce(v_g -> 'sieges', '{}'::jsonb), 'deputes', coalesce(v_g -> 'deputes', '{}'::jsonb),
    'monParti', v_parti, 'chef', v_chef,
    'membres', CASE WHEN v_chef THEN (
        SELECT coalesce(jsonb_agg(DISTINCT d.name), '[]'::jsonb) FROM public.personnages_donnees d
          JOIN public.organisations o ON o.id = v_parti
         WHERE d.name = o.data::jsonb ->> 'chef'
            OR d.name IN (SELECT m ->> 'nom' FROM jsonb_array_elements(
                 CASE WHEN jsonb_typeof(o.data::jsonb -> 'membres') = 'array' THEN o.data::jsonb -> 'membres' ELSE '[]'::jsonb END) m))
      ELSE '[]'::jsonb END);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_soviet_etat() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_soviet_etat() TO authenticated;

-- Désigner (ou retirer, p_retirer) un député du parti dont on est le chef.
CREATE OR REPLACE FUNCTION public.sovarka_depute_designer(p_nom text, p_retirer boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_moi text; v_parti text; v_d jsonb; v_g jsonb; v_liste jsonb; v_sieges integer;
        v_fiche record; v_nom text := btrim(coalesce(p_nom, ''));
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT o.id INTO v_parti FROM public.organisations o
   WHERE o.data::jsonb ->> 'type' = 'politique'
     AND coalesce(o.data::jsonb ->> 'country', o.country_origine) = 'soviet'
     AND o.data::jsonb ->> 'chef' = v_moi
   ORDER BY o.created_at LIMIT 1;
  IF v_parti IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_chef_de_parti'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees
                  WHERE name = v_moi AND country = 'soviet' AND current_building = 'assemblee') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  SELECT data::jsonb INTO v_d FROM public.cycles_electoraux WHERE id = 'soviet_gloire_partis' FOR UPDATE;
  v_g := coalesce(v_d -> 'gloire', '{}'::jsonb);
  v_sieges := coalesce((v_g -> 'sieges' ->> v_parti)::integer, 0);
  v_liste := CASE WHEN jsonb_typeof(v_g -> 'deputes' -> v_parti) = 'array' THEN v_g -> 'deputes' -> v_parti ELSE '[]'::jsonb END;

  IF p_retirer THEN
    IF NOT v_liste ? v_nom THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_depute_du_parti'); END IF;
    v_liste := v_liste - v_nom;
    UPDATE public.personnages_donnees SET poste_depute = NULL
     WHERE name = v_nom AND poste_depute ->> 'country' = 'soviet';
    PERFORM public.mail_systeme_envoyer('Système', v_nom, 'Soviet Suprême',
      v_moi || ', chef de votre parti, vous a retiré votre siège de député du Soviet Suprême.');
  ELSE
    IF v_sieges <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_siege'); END IF;
    IF jsonb_array_length(v_liste) >= v_sieges THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'sieges_pourvus', 'sieges', v_sieges);
    END IF;
    SELECT name, poste_depute INTO v_fiche FROM public.personnages_donnees WHERE name = v_nom FOR UPDATE;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
    IF public.sovarka_parti_de(v_nom) IS DISTINCT FROM v_parti THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'hors_parti');
    END IF;
    IF v_fiche.poste_depute IS NOT NULL AND jsonb_typeof(v_fiche.poste_depute) = 'object' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'deja_depute');
    END IF;
    v_liste := v_liste || to_jsonb(v_nom);
    -- Registre (cycle) d'abord : personnages_attester_poste n'accepte la fiche qu'attestée.
    v_g := jsonb_set(v_g, '{deputes}', coalesce(v_g -> 'deputes', '{}'::jsonb) || jsonb_build_object(v_parti, v_liste));
    v_d := jsonb_set(v_d, '{gloire}', v_g);
    UPDATE public.cycles_electoraux SET data = v_d::text, updated_at = now() WHERE id = 'soviet_gloire_partis';
    UPDATE public.personnages_donnees
       SET poste_depute = jsonb_build_object('id', 'depute', 'name', 'Député du Soviet Suprême',
                                             'city', NULL, 'country', 'soviet', 'designePar', v_moi)
     WHERE name = v_nom;
    PERFORM public.mail_systeme_envoyer('Système', v_nom, 'Soviet Suprême',
      v_moi || ', chef de votre parti, vous a désigné(e) député(e) du Soviet Suprême.');
  END IF;

  IF p_retirer THEN
    v_g := jsonb_set(v_g, '{deputes}', coalesce(v_g -> 'deputes', '{}'::jsonb) || jsonb_build_object(v_parti, v_liste));
    UPDATE public.cycles_electoraux SET data = jsonb_set(v_d, '{gloire}', v_g)::text, updated_at = now()
     WHERE id = 'soviet_gloire_partis';
  END IF;
  RETURN jsonb_build_object('ok', true, 'parti', v_parti, 'deputes', v_liste, 'sieges', v_sieges);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_depute_designer(text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_depute_designer(text, boolean) TO authenticated;

-- À la proclamation, les députés de la législature sortante perdent leur siège.
DO $patch$
DECLARE v_source text;
  v_ancre text := $a$  PERFORM public.sovarka_gloire_synchroniser();
$a$;
BEGIN
  SELECT pg_get_functiondef('public.sovarka_gloire_proclamer(bigint)'::regprocedure) INTO v_source;
  IF v_source IS NULL OR strpos(v_source, v_ancre) = 0 OR strpos(v_source, 'poste_depute') > 0 THEN
    RAISE EXCEPTION 'sovarka_gloire_proclamer_version_inattendue';
  END IF;
  EXECUTE replace(v_source, v_ancre, v_ancre || $g$  -- Législature sortante (étape 5) : sièges rendus avant la nouvelle répartition.
  UPDATE public.personnages_donnees d SET poste_depute = NULL
   WHERE d.poste_depute ->> 'country' = 'soviet'
     AND d.name IN (SELECT jsonb_array_elements_text(l.value)
                      FROM public.cycles_electoraux c,
                           jsonb_each(coalesce(c.data::jsonb -> 'gloire' -> 'deputes', '{}'::jsonb)) l
                     WHERE c.id = 'soviet_gloire_partis' AND jsonb_typeof(l.value) = 'array');
$g$);
END $patch$;

-- Attestation d'un député de Sovarka : il figure parmi les désignations de la législature en
-- cours, quel que soit le pays où il se trouve (le siège est national, la fiche porte le pays).
DO $patch$
DECLARE v_source text;
  v_ancre text := $a$  IF v_id = 'depute' THEN
$a$;
BEGIN
  SELECT pg_get_functiondef('public.poste_est_atteste(text,jsonb,text)'::regprocedure) INTO v_source;
  IF v_source IS NULL OR strpos(v_source, v_ancre) = 0 OR strpos(v_source, 'soviet_gloire_partis') > 0 THEN
    RAISE EXCEPTION 'poste_est_atteste_version_inattendue';
  END IF;
  EXECUTE replace(v_source, v_ancre, $g$  IF v_id = 'depute' AND p_poste ->> 'country' = 'soviet' THEN
    RETURN EXISTS (SELECT 1 FROM public.cycles_electoraux c,
                          jsonb_each(coalesce(c.data::jsonb -> 'gloire' -> 'deputes', '{}'::jsonb)) l
                    WHERE c.id = 'soviet_gloire_partis' AND jsonb_typeof(l.value) = 'array'
                      AND l.value ? p_nom);
  END IF;
$g$ || v_ancre);
END $patch$;
