-- Banc de prévol, lecture seule : garde de migration et contrôles des deux villes.
DO $test$
DECLARE s text; n integer;
BEGIN
  s := pg_get_functiondef('public.militaire_ordre_collectif(text,text,text,text,text[])'::regprocedure);
  n := (length(s) - length(replace(s,'  IF v_a_distance THEN','')))
       / length('  IF v_a_distance THEN');
  IF n <> 1 AND position('radio_hors_ville' IN s)=0 THEN
    RAISE EXCEPTION 'ancre_radio_non_rejouable: %',n;
  END IF;
  IF position('v_radio_chef' IN s)=0 OR position('v_radio_leader' IN s)=0 THEN
    RAISE EXCEPTION 'radio_anciennes_gardes_absentes';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_attribute
      WHERE attrelid='public.personnages_donnees'::regclass
        AND attname='current_city' AND NOT attisdropped) THEN
    RAISE EXCEPTION 'champ_ville_pj_absent';
  END IF;
  RAISE NOTICE 'OK : ancre du contrôle de ville et deux radios présentes';
END $test$;
