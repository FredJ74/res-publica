-- EN ATTENTE : catalogue reel, ACL et dependances a relire avant application MCP.
-- Remplace la premiere preparation NON APPLIQUEE : ne restaure aucun corps archive.
-- Le MD5 19a5... est communique par le proprietaire depuis Supabase, pas mesure ici.
-- Transformation du corps installe : seul le bloc de debit change de place.
-- Les ajouts alimentaires et toutes les autres instructions restent octet pour octet.
DO $migration$
DECLARE
  v_oid oid := to_regprocedure('public.acheter_produit_commerce(text,text,text,text,integer)');
  v_corps text;
  v_definition text;
  v_nouveau text;
  v_original text;
  v_bloc constant text := $bloc$  IF NOT public.mouvement_titulaire(p_acheteur, -v_montant) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
  END IF;

$bloc$;
  v_ancre constant text := '  IF v_gen.individualise THEN';
  v_trace constant text := '  -- HG debit deplace avant livraison (20261016070541).';
  v_md5_autorises constant text[] := ARRAY[
    '19f6cb294da782dbbf962028a1e315de', -- archive, seulement pour le banc local
    '19a5c3c718d4109b98fe94a8eb5ebf30'  -- observation Supabase transmise, source a relire
  ];
  v_acl aclitem[];
  v_owner oid;
BEGIN
  SELECT prosrc, pg_get_functiondef(oid), proacl, proowner
    INTO v_corps, v_definition, v_acl, v_owner FROM pg_proc WHERE oid=v_oid;
  IF v_corps IS NULL THEN
    RAISE EXCEPTION 'achat_commerce_definition_a_reexaminer_avant_migration';
  END IF;
  -- Un rejeu n'est accepte que si l'inversion EXACTE redonne un corps autorise.
  IF strpos(v_corps, v_trace) > 0 THEN
    IF length(v_corps)-length(replace(v_corps,v_trace,'')) <> length(v_trace)
       OR strpos(v_corps,v_bloc || v_ancre)=0 THEN
      RAISE EXCEPTION 'achat_commerce_definition_a_reexaminer_avant_migration';
    END IF;
    v_original := replace(replace(v_corps,v_bloc || v_ancre,v_ancre),v_trace,v_bloc);
    IF NOT md5(v_original)=ANY(v_md5_autorises) THEN
      RAISE EXCEPTION 'achat_commerce_definition_a_reexaminer_avant_migration';
    END IF;
    RETURN;
  END IF;
  IF NOT md5(v_corps)=ANY(v_md5_autorises) THEN
    RAISE EXCEPTION 'achat_commerce_definition_a_reexaminer_avant_migration';
  END IF;
  -- Un seul bloc de debit et une seule ancre : ne pas deviner le nouveau code.
  IF length(v_corps)-length(replace(v_corps,v_bloc,'')) <> length(v_bloc)
     OR length(v_corps)-length(replace(v_corps,v_ancre,'')) <> length(v_ancre)
     OR strpos(v_corps,v_bloc) < strpos(v_corps,'INSERT INTO public.objets_recus')
     OR strpos(v_corps,'INSERT INTO public.objets_recus')=0 THEN
    RAISE EXCEPTION 'achat_commerce_structure_a_reexaminer_avant_migration';
  END IF;
  v_nouveau := replace(replace(v_corps,v_bloc,v_trace),v_ancre,v_bloc || v_ancre);
  -- Preuve de reversibilite : pas de modification de prix, taxes, objets ou autorite.
  IF replace(replace(v_nouveau,v_bloc || v_ancre,v_ancre),v_trace,v_bloc) <> v_corps
     OR strpos(v_nouveau,v_bloc) > strpos(v_nouveau,'INSERT INTO public.objets_recus') THEN
    RAISE EXCEPTION 'achat_commerce_transformation_invalide';
  END IF;
  IF length(v_definition)-length(replace(v_definition,v_corps,'')) <> length(v_corps) THEN
    RAISE EXCEPTION 'achat_commerce_definition_ambigue';
  END IF;
  EXECUTE replace(v_definition,v_corps,v_nouveau);
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE oid=v_oid AND prosrc=v_nouveau
                  AND proacl IS NOT DISTINCT FROM v_acl AND proowner=v_owner) THEN
    RAISE EXCEPTION 'achat_commerce_definition_ou_droits_modifies';
  END IF;
END;
$migration$;
