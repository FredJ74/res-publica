-- LOT DE KRASNOV (1re partie), point 8 (Fred, 20/11/2026) : le vol dans les archives d'écoute suit les règles communes du
-- vol. GAME-DESIGN-KRASNOV-LOT-20261120.md.
--  • Jet : formule commune (crim_voler_taux_interne, butin « au hasard ») : DIS du voleur contre le meilleur PER présent
--    (PJ ou groupe présents, sinon l'opérateur du centre, PER par défaut du vol), +15 pour la carrière criminelle, bornes
--    communes du vol. Pas de bonus de lieu : la difficulté ne vient que des personnes présentes (ISN et hommes armés
--    du lieu ne comptent plus pour cet acte).
--  • Échec : inaperçu une fois sur deux (rien de plus que les PA) ; sinon repéré (crime détecté) ; une fois sur dix, la
--    bagarre éclate avec l'opérateur : perdue, c'est l'arrestation en flagrant délit (barème commun, ×2 en Sovarka,
--    interrogatoire à Novomirsk) ; gagnée, le voleur s'enfuit, repéré.
-- Idempotente.
BEGIN;

CREATE OR REPLACE FUNCTION public.sovarka_ecoute_archives_voler(p_requete text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); p record; c text; v_paie jsonb; v_taux integer; v_roll integer;
        r public.sovarka_ecoutes_rapports; v jsonb; x record; t jsonb; v_per numeric; v_bagarre boolean; v_perdue boolean;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_requete), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('sovarka:vol_archives:' || a, 0));
  SELECT * INTO x FROM public.sovarka_ecoutes_vols WHERE acteur = a AND requete = p_requete;
  IF FOUND THEN RETURN x.resultat || jsonb_build_object('rejeu', true) || public.crime_etat_acteur_interne(a); END IF;
  SELECT country, current_city, current_building, current_room, resources, stats INTO p FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  c := CASE WHEN p.country = 'soviet' THEN public.sovarka_ecoute_centre_interne(p.current_city, p.current_building) END;
  IF c IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF c = 'novomirsk' AND p.current_room IS DISTINCT FROM 'salle_ecoutes' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF public.sovarka_titulaire_interne('min_def') IS NOT DISTINCT FROM a THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ministre_defense'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.sovarka_ecoutes_rapports WHERE centre = c AND jour >= public.sovarka_jour_paris() - 30) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'archives_vides'); END IF;
  v_paie := public.payer_ordre(a, 'voler_archives_ecoute', 2, 0);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  /* vol_archives_regles_communes_v3 (Fred, 20/11/2026) : DIS contre le meilleur PER présent, opérateur compris. */
  t := public.crim_temoin_interne(a, NULL);
  v_per := greatest(public.crim_param_interne('vol_per_defaut', 8), coalesce((t ->> 'per')::numeric, 0));
  v_taux := least(public.crim_param_interne('vol_max', 85)::integer, greatest(public.crim_param_interne('vol_min', 5)::integer,
    public.crim_voler_taux_interne('hasard', public.crim_stat_interne(a, 'dis', 50), v_per, public.crim_carriere_interne(a))));
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll > v_taux THEN
    IF random() < 0.5 THEN
      v := jsonb_build_object('ok', true, 'reussi', false, 'inapercu', true, 'taux', v_taux, 'jet', v_roll, 'pa', v_paie->'pa');
    ELSE
      PERFORM public.crime_detecter_interne(a, 'voler_archives_ecoute', false);
      v_bagarre := random() < 0.10;
      v_perdue := v_bagarre AND random() < 0.5;
      v := jsonb_build_object('ok', true, 'reussi', false, 'repere', true, 'bagarre', v_bagarre, 'taux', v_taux, 'jet', v_roll, 'pa', v_paie->'pa');
      IF v_perdue THEN
        v := v || jsonb_build_object('arrestation', public.arrestation_flagrant_interne(a, 'voler_archives_ecoute', false, 'vol_archives_ecoute',
          'Surpris en train de fouiller les archives d''écoute, après une bagarre perdue avec l''opérateur',
          public.crim_peine_jours_interne('voler_archives_ecoute', p.country)));
        IF c = 'novomirsk' AND coalesce((v->'arrestation'->>'ok')::boolean, false) THEN
          PERFORM public.renseignement_interrogatoire_placer_interne(a);
          v := v || jsonb_build_object('interrogatoire', true);
        END IF;
      END IF;
    END IF;
  ELSE
    SELECT * INTO r FROM public.sovarka_ecoutes_rapports WHERE centre = c AND jour >= public.sovarka_jour_paris() - 30
     ORDER BY random() LIMIT 1;
    PERFORM public.crime_tracer_interne(a, 'voler_archives_ecoute', 'archives d''écoute de ' || initcap(c));
    PERFORM public.mail_systeme_poser_interne('Archives volées', a,
      'Rapport d''écoute dérobé — ' || initcap(r.centre) || ', ' || to_char(r.jour, 'DD/MM'),
      public.sovarka_ecoute_rapport_texte_interne(r));
    v := jsonb_build_object('ok', true, 'reussi', true, 'taux', v_taux, 'jet', v_roll, 'pa', v_paie->'pa',
      'centre', r.centre, 'jour', r.jour, 'nb', jsonb_array_length(r.mails));
  END IF;
  INSERT INTO public.sovarka_ecoutes_vols (acteur, requete, resultat) VALUES (a, p_requete, v);
  RETURN v || public.crime_etat_acteur_interne(a);
END $function$;

COMMIT;
