-- #135 : portée universelle des liaisons radio : même ville uniquement.
-- Patch ciblé de la RPC militaire existante, sans moteur radio concurrent.
-- Sûr à rejouer : refuse une définition non reconnue et n'écrit aucune donnée PJ.
DO $radio$
DECLARE s text; a text; b text;
BEGIN
  s := pg_get_functiondef('public.militaire_ordre_collectif(text,text,text,text,text[])'::regprocedure);
  a := '  IF v_a_distance THEN';
  b := '  IF v_a_distance THEN'
    || chr(10) || '    -- Une radio ne transmet jamais un ordre entre deux villes.'
    || chr(10) || '    IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees appelant'
    || chr(10) || '                   JOIN public.personnages_donnees receveur'
    || chr(10) || '                     ON receveur.name = v_leader'
    || chr(10) || '                  WHERE appelant.name = v_moi'
    || chr(10) || '                    AND appelant.country = receveur.country'
    || chr(10) || '                    AND appelant.current_city IS NOT NULL'
    || chr(10) || '                    AND appelant.current_city = receveur.current_city) THEN'
    || chr(10) || '      RETURN jsonb_build_object(''ok'',false,''raison'',''radio_hors_ville'');'
    || chr(10) || '    END IF;';
  IF position(b IN s)>0 THEN RETURN; END IF;
  IF position('radio_hors_ville' IN s)>0 THEN
    RAISE EXCEPTION 'ordre_radio_garde_inattendue'; END IF;
  IF (length(s)-length(replace(s,a,'')))/length(a) <> 1 THEN
    RAISE EXCEPTION 'ordre_radio_definition_non_examinee';
  END IF;
  EXECUTE replace(s,a,b);
END $radio$;
