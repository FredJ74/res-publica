-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261029210322.
-- Archivage documentaire seulement ; ne pas rejouer.
-- A APPLIQUER JUSTE APRES LA LIVRAISON DE LA PR #213, avec 20261028210000 a 210700.
-- La voix « jean_lou » n'est plus enregistrable que par jean_lou_tract_distribuer (jet, tract et
-- quete serveur). Un joueur ne peut plus s'ajouter seul des voix par ce canal. Le canal
-- « conference » est inchange (chantier des elections).
DO $do$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.elections_voix_pnj_enregistrer(text,text,text,text,text,text,text)'::regprocedure);
  IF position('canal_reserve_serveur' IN v_def) = 0 THEN
    v_def := replace(v_def,
      E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''canal_invalide'');\n  END IF;\n',
      E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''canal_invalide'');\n  END IF;\n'
      || E'  IF p_canal = ''jean_lou'' AND coalesce(current_setting(''rp.jean_lou_interne'', true), '''') <> ''on'' THEN\n'
      || E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''canal_reserve_serveur'');\n  END IF;\n');
    IF position('canal_reserve_serveur' IN v_def) = 0 THEN RAISE EXCEPTION 'elections_voix_pnj_enregistrer : motif introuvable'; END IF;
    EXECUTE v_def;
  END IF;
END $do$;
