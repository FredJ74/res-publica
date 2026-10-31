-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261029210325.
-- Archivage documentaire seulement ; ne pas rejouer.
-- A APPLIQUER JUSTE APRES LA LIVRAISON DE LA PR #213, apres 20261028210800.
-- La voix « conference » n'est plus enregistrable que par conference_soutenir (lieu, PA, une
-- conference par jour, un seul soutien par candidat). Avec 210800, plus aucun canal de
-- elections_voix_pnj_enregistrer n'est ouvert au navigateur.
DO $do$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.elections_voix_pnj_enregistrer(text,text,text,text,text,text,text)'::regprocedure);
  IF position('conference_interne' IN v_def) = 0 THEN
    v_def := replace(v_def,
      E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''canal_invalide'');\n  END IF;\n',
      E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''canal_invalide'');\n  END IF;\n'
      || E'  IF p_canal = ''conference'' AND coalesce(current_setting(''rp.conference_interne'', true), '''') <> ''on'' THEN\n'
      || E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''canal_reserve_serveur'');\n  END IF;\n');
    IF position('conference_interne' IN v_def) = 0 THEN RAISE EXCEPTION 'elections_voix_pnj_enregistrer : motif introuvable'; END IF;
    EXECUTE v_def;
  END IF;
END $do$;
