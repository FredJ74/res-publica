-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261028212358.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 28/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261028212358.
-- Eprouvee au role authenticated en transaction annulee : 34 vols reussis, victime 5000 -> 2584 et
-- voleur 0 -> 2416, pile de 40 bois et revolver passes chez le voleur, aucune ligne non traitee.
-- ============================================================================
-- VOL ENTRE JOUEURS : TRANSFERT IMMEDIAT PAR LE SERVEUR (28 octobre 2026, Claude)
-- ============================================================================
-- crime_voler creditait le voleur tout de suite, mais la PERTE de la victime n'etait appliquee
-- que par l'ecran de la victime (recupererVolsEnAttente) : un tricheur ne perdait jamais rien ; et
-- pour un objet, c'etait l'ecran de la victime qui le livrait au voleur, avec l'objet qu'il
-- voulait. Desormais, dans la meme transaction que le jet :
--   * argent : debite chez la victime, credite au voleur ;
--   * matiere : retiree de la pile de la victime, deposee chez le voleur (depot automatique) ;
--   * objet : retire de l'inventaire de la victime, depose tel quel chez le voleur.
-- La ligne vols_en_attente reste inscrite (historique), mais deja TRAITEE : l'ancien ecran ne
-- l'applique donc pas une seconde fois. Compatible avec le jeu en ligne.
-- Idempotente. Aucun acte de joueur.
-- ============================================================================
DO $do$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.crime_voler(text,text,boolean,integer,integer)'::regprocedure);
  IF position('TRANSFERT IMMEDIAT' IN v_def) = 0 THEN
    v_def := replace(v_def, E'  v_desc text; v_msg text := NULL; v_perte integer; v_jour integer; v_quand text;\n',
      E'  v_desc text; v_msg text := NULL; v_perte integer; v_jour integer; v_quand text;\n  v_pos integer; v_dep jsonb;\n');
    v_def := replace(v_def,
      E'  INSERT INTO public.vols_en_attente (id, victime, voleur, type_butin, montant, objet_id, traite)\n'
      || E'  VALUES (''vol-'' || replace(gen_random_uuid()::text, ''-'', ''''), p_cible, v_moi, v_vol_type, v_montant, v_vol_obj, false);\n'
      || E'  IF v_butin = ''argent'' THEN\n'
      || E'    UPDATE public.personnages_donnees SET arg = coalesce(arg, 0) + v_montant WHERE name = v_moi;\n'
      || E'  END IF;\n',
      E'  -- TRANSFERT IMMEDIAT PAR LE SERVEUR (28/10/2026) : la victime perd, le voleur recoit, ici.\n'
      || E'  IF v_butin = ''argent'' THEN\n'
      || E'    UPDATE public.personnages_donnees SET arg = greatest(0, coalesce(arg, 0) - v_montant) WHERE name = p_cible;\n'
      || E'    UPDATE public.personnages_donnees SET arg = coalesce(arg, 0) + v_montant WHERE name = v_moi;\n'
      || E'  ELSE\n'
      || E'    SELECT (o - 1)::integer INTO v_pos FROM jsonb_array_elements(c.inventory) WITH ORDINALITY x(e, o)\n'
      || E'     WHERE CASE WHEN v_vol_type = ''matiere'' THEN coalesce((e ->> ''stackable'')::boolean, false) AND e ->> ''stackKey'' = v_vol_obj\n'
      || E'                ELSE e ->> ''id'' = v_vol_obj END ORDER BY o LIMIT 1;\n'
      || E'    IF v_pos IS NULL THEN\n'
      || E'      RETURN jsonb_build_object(''ok'', true, ''issue'', ''rien'', ''jet'', v_jet, ''arg'', m.arg) || jsonb_build_object(''paie'', v_paie);\n'
      || E'    END IF;\n'
      || E'    IF v_vol_type = ''matiere'' THEN\n'
      || E'      v_montant := least(v_montant, greatest(0, floor(coalesce((c.inventory -> v_pos ->> ''qty'')::numeric, 1)))::integer);\n'
      || E'      UPDATE public.personnages_donnees\n'
      || E'         SET inventory = CASE WHEN coalesce((inventory -> v_pos ->> ''qty'')::numeric, 1) - v_montant <= 0 THEN inventory - v_pos\n'
      || E'                              ELSE jsonb_set(inventory, ARRAY[v_pos::text, ''qty''], to_jsonb(coalesce((inventory -> v_pos ->> ''qty'')::numeric, 1) - v_montant)) END\n'
      || E'       WHERE name = p_cible;\n'
      || E'      v_dep := public.inventaire_deposer_interne(v_moi, jsonb_build_object(''name'', coalesce(v_objet ->> ''name'', v_vol_obj), ''icon'', v_objet -> ''icon'',\n'
      || E'                 ''stackable'', true, ''stackKey'', v_vol_obj, ''qty'', v_montant), true);\n'
      || E'    ELSE\n'
      || E'      UPDATE public.personnages_donnees SET inventory = inventory - v_pos WHERE name = p_cible;\n'
      || E'      v_dep := public.inventaire_deposer_interne(v_moi, c.inventory -> v_pos, true);\n'
      || E'    END IF;\n'
      || E'    IF (v_dep ->> ''ok'')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION ''crime_voler: depot refuse %'', v_dep; END IF;\n'
      || E'  END IF;\n'
      || E'  INSERT INTO public.vols_en_attente (id, victime, voleur, type_butin, montant, objet_id, traite)\n'
      || E'  VALUES (''vol-'' || replace(gen_random_uuid()::text, ''-'', ''''), p_cible, v_moi, v_vol_type, v_montant, v_vol_obj, true);\n');
    v_def := replace(v_def,
      E'    ''jet'', v_jet, ''arg'', (SELECT arg FROM public.personnages_donnees WHERE name = v_moi)) || jsonb_build_object(''paie'', v_paie);',
      E'    ''jet'', v_jet, ''arg'', (SELECT arg FROM public.personnages_donnees WHERE name = v_moi)) || jsonb_build_object(''paie'', v_paie)\n'
      || E'    || (SELECT jsonb_build_object(''inventory'', inventory, ''revision'', inventory_revision, ''livre'', true) FROM public.personnages_donnees WHERE name = v_moi);');
    IF position('TRANSFERT IMMEDIAT' IN v_def) = 0 OR position('''livre'', true' IN v_def) = 0 THEN
      RAISE EXCEPTION 'crime_voler : motifs introuvables'; END IF;
    EXECUTE v_def;
  END IF;
END $do$;
