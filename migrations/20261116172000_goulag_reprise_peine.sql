-- Reprise de l'exécution de la peine gelée, uniquement à l'incarcération
-- effective d'un évadé, sans peine supplémentaire automatique.
ALTER TABLE public.sovarka_goulag_traversees
 ADD COLUMN IF NOT EXISTS peine_reprise_le timestamptz,
 ADD COLUMN IF NOT EXISTS nouvelle_detention_id text;

DO $reprise$
DECLARE code text; ancre text; ajout text;
BEGIN
 code:=pg_get_functiondef('public.detention_ouvrir_interne(text,text,integer,text,text,jsonb,text,text,jsonb)'::regprocedure);
 IF strpos(code,'goulag_reprise_peine_gelee_20261116')>0 THEN RETURN; END IF;
 ancre:=E'  RETURN jsonb_build_object(''ok'',true,''detention_id'',v_id,''jour_debut'',v_jour_cible,''jour_fin'',v_jour_cible+p_jours);';
 ajout:=E'  -- goulag_reprise_peine_gelee_20261116 : la condamnation précédente n a pas diminué pendant la fuite.\n'
  ||E'  DECLARE v_goulag_restant numeric; v_goulag_recherche text; v_goulag_supp integer;\n'
  ||E'  BEGIN\n'
  ||E'   IF p_country = ''soviet'' THEN\n'
  ||E'    SELECT t.peine_gelee_secondes,t.recherche_id INTO v_goulag_restant,v_goulag_recherche\n'
  ||E'      FROM public.sovarka_goulag_traversees t\n'
  ||E'      WHERE t.nom=p_nom AND NOT t.en_cours AND t.statut=''detenu''\n'
  ||E'        AND t.peine_gelee_secondes>0 AND t.peine_reprise_le IS NULL FOR UPDATE;\n'
  ||E'    IF FOUND THEN\n'
  ||E'      v_goulag_supp:=ceil(v_goulag_restant::numeric/86400)::integer;\n'
  ||E'      UPDATE public.detentions SET jour_fin=jour_fin+v_goulag_supp,\n'
  ||E'        detention_precedente_id=coalesce(detention_precedente_id,\n'
  ||E'          (SELECT detention_id FROM public.sovarka_goulag_traversees WHERE nom=p_nom)),\n'
  ||E'        reliquat_jours=v_goulag_supp WHERE id=v_id;\n'
  ||E'      UPDATE public.personnages_donnees SET est_emprisonne=\n'
  ||E'        jsonb_set(jsonb_set(est_emprisonne,''{jours}'',\n'
  ||E'          to_jsonb(p_jours::numeric+v_goulag_restant::numeric/86400)),\n'
  ||E'          ''{jourFin}'',to_jsonb(v_jour_cible+p_jours+v_goulag_supp)) WHERE name=p_nom;\n'
  ||E'      UPDATE public.sovarka_goulag_traversees SET peine_reprise_le=now(),\n'
  ||E'        nouvelle_detention_id=v_id,actualise_le=now() WHERE nom=p_nom;\n'
  ||E'      UPDATE public.sovarka_goulag_refuges SET termine=true,actualise_le=now() WHERE nom=p_nom;\n'
  ||E'      IF v_goulag_recherche IS NOT NULL THEN\n'
  ||E'        PERFORM public.recherche_retirer_par_id(p_nom,v_goulag_recherche);\n'
  ||E'      END IF;\n'
  ||E'    END IF;\n'
  ||E'   END IF;\n'
  ||E'  END;\n'
  ||E'  RETURN jsonb_build_object(''ok'',true,''detention_id'',v_id,''jour_debut'',v_jour_cible,\n'
  ||E'     ''jour_fin'',(SELECT jour_fin FROM public.detentions WHERE id=v_id));';
 IF (length(code)-length(replace(code,ancre,'')))<>length(ancre) THEN
  RAISE EXCEPTION 'detention_ouvrir_interne_ancre_inattendue'; END IF;
 EXECUTE replace(code,ancre,ajout);
END $reprise$;
