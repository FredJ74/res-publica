-- #379 : adaptateurs des ordres existants ; aucun delta choisi par le navigateur.
-- Ne ferme PAS encore les sauvegardes : les autres producteurs doivent être raccordés.
-- BEGIN GARDE HG379
-- Empreinte de la définition PRÉPARÉE ci-dessous, pas d'un relevé de production.
-- Un rejeu est permis ; une installation partielle ou un autre corps exige examen.
DO $prevol_jauges$
DECLARE f regprocedure:=to_regprocedure('public.jauges_ordre_executer(text,uuid,jsonb)');
 t regclass:=to_regclass('public.jauges_actions_recus');forme text[];
BEGIN
 IF(f IS NULL)<>(t IS NULL)THEN RAISE EXCEPTION 'jauges_installation_partielle';END IF;
 IF f IS NOT NULL THEN
  IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=f AND md5(prosrc)='ca8a583886c03d76e9e3b0873ccf2b7b'
     AND prosecdef AND prorettype='jsonb'::regtype AND proconfig=ARRAY['search_path=public, pg_temp'])THEN
   RAISE EXCEPTION 'jauges_definition_a_reexaminer';END IF;
  IF NOT(SELECT relrowsecurity FROM pg_class WHERE oid=t)
     OR EXISTS(SELECT 1 FROM pg_policy WHERE polrelid=t)THEN
   RAISE EXCEPTION 'jauges_recus_autorite_a_reexaminer';END IF;
  SELECT array_agg(attname::text||':'||format_type(atttypid,atttypmod)||':'||attnotnull::text ORDER BY attnum)
   INTO forme FROM pg_attribute WHERE attrelid=t AND attnum>0 AND NOT attisdropped;
  IF forme IS DISTINCT FROM ARRAY['acteur:text:true','requete:uuid:true','ordre:text:true','contexte:jsonb:true','resultat:jsonb:true','cree_le:timestamp with time zone:true']
     OR NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid=t AND contype='p'AND conkey=ARRAY[1,2]::smallint[])THEN
   RAISE EXCEPTION 'jauges_recus_schema_a_reexaminer';END IF;
 END IF;
END;$prevol_jauges$;
-- END GARDE HG379
CREATE TABLE IF NOT EXISTS public.jauges_actions_recus (
  acteur text NOT NULL,
  requete uuid NOT NULL,
  ordre text NOT NULL,
  contexte jsonb NOT NULL,
  resultat jsonb NOT NULL,
  cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (acteur, requete)
);
ALTER TABLE public.jauges_actions_recus ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.jauges_ordre_executer(p_ordre text,p_requete uuid,p_contexte jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp
AS $function$
DECLARE a public.personnages_donnees; rec public.jauges_actions_recus;
  pa_cout integer; argent_cout integer:=0; pop_gain integer:=0; inf_gain integer:=0;
  paiement jsonb; perimetre jsonb; sortie jsonb; ressources jsonb; publication jsonb;
  contexte_recu jsonb;
BEGIN
  IF p_requete IS NULL OR p_contexte IS NULL OR jsonb_typeof(p_contexte)<>'object' THEN
    RETURN jsonb_build_object('ok',false,'raison','requete_invalide'); END IF;
  SELECT * INTO a FROM public.personnages_donnees WHERE name=public.mon_personnage() FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  contexte_recu:=CASE WHEN p_ordre IN('forum_publier','commanditer_sondage') THEN jsonb_build_object('sha256',encode(sha256(convert_to(p_contexte::text,'UTF8')),'hex')) ELSE p_contexte END;
  SELECT * INTO rec FROM public.jauges_actions_recus WHERE acteur=a.name AND requete=p_requete;
  IF FOUND THEN
    IF rec.ordre IS DISTINCT FROM p_ordre OR rec.contexte IS DISTINCT FROM contexte_recu THEN
      RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee'); END IF;
    IF p_ordre='campagne_securite'THEN
      rec.resultat:=rec.resultat||jsonb_build_object(
       'solde_caisse',(SELECT data->'solde'FROM public.caisses_batiments WHERE id=rec.resultat->>'caisse'),
       'isn_ville',(SELECT data->'isn'FROM public.indices_villes WHERE id=(rec.resultat->>'pays')||'_'||(rec.resultat->>'ville')));
    END IF;
    IF p_ordre='objectifs_actualiser' THEN
      rec.resultat:=rec.resultat||jsonb_build_object('objectifs_completes',(SELECT acquis FROM public.jauges_objectifs_etats WHERE acteur=a.name));
    END IF;
    -- Le verdict d'action est stable ; la fiche retournée est celle d'aujourd'hui.
    RETURN rec.resultat || jsonb_build_object('rejeu',true,'pop',a.resources->'pop','inf',a.resources->'inf',
      'pa',a.pa,'hp',a.hp,'moral',a.moral,'arg',a.arg,'liquide',a.liquide,
      'solde_national',coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=a.name AND banque='nationale'),0));
  END IF;
  CASE p_ordre
  WHEN 'commanditer_sondage' THEN
    IF a.current_building IS DISTINCT FROM 'palais-gouvernement'OR a.current_room IS DISTINCT FROM 'bureau_min_info'OR a.current_city IS DISTINCT FROM 'capitale'THEN
      RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
    IF a.poste->>'id'IS DISTINCT FROM 'min_info'THEN RETURN jsonb_build_object('ok',false,'raison','poste_requis');END IF;
    IF p_contexte-ARRAY['texte']<>'{}'::jsonb OR jsonb_typeof(p_contexte->'texte')IS DISTINCT FROM 'string'
       OR nullif(btrim(p_contexte->>'texte'),'')IS NULL THEN
      RETURN jsonb_build_object('ok',false,'raison','contexte_invalide');END IF;
    -- Même forum, mêmes déclencheurs : pas de deuxième moteur de publication.
    -- Un refus après paiement annule tout le sous-bloc avant de rendre le verdict.
    BEGIN
      paiement:=public.payer_ordre(a.name,p_ordre,1,200);
      IF NOT coalesce((paiement->>'ok')::boolean,false)THEN RETURN paiement;END IF;
      publication:=public.forum_publication_jauges_interne(a.name,p_requete,
        jsonb_build_object('forum','national','titre','Sondage — '||btrim(p_contexte->>'texte'),
          'contenu',btrim(p_contexte->>'texte')));
      IF NOT coalesce((publication->>'ok')::boolean,false)THEN
        RAISE EXCEPTION 'sondage_publication_refusee' USING ERRCODE='23514';END IF;
    EXCEPTION WHEN check_violation THEN
      RETURN jsonb_build_object('ok',false,'raison','publication_refusee');
    END;
    -- Le bonus de cet ordre est +5 INF, sans bonus supplémentaire de forum.
    pa_cout:=NULL;inf_gain:=5;
  WHEN 'objectifs_actualiser' THEN
    IF p_contexte<>'{}'::jsonb THEN RETURN jsonb_build_object('ok',false,'raison','contexte_invalide');END IF;
    IF to_regprocedure('public.objectifs_secrets_actualiser_interne(text)')IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','ordre_non_raccorde');END IF;
    publication:=public.objectifs_secrets_actualiser_interne(a.name);
    IF coalesce((publication->>'ok')::boolean,false)IS NOT TRUE THEN RETURN publication;END IF;
    inf_gain:=(publication->>'gain_inf')::integer;pa_cout:=NULL;
  WHEN 'forum_publier' THEN
    IF to_regprocedure('public.forum_publication_jauges_interne(text,uuid,jsonb)') IS NULL THEN
      RETURN jsonb_build_object('ok',false,'raison','ordre_non_raccorde'); END IF;
    publication:=public.forum_publication_jauges_interne(a.name,p_requete,p_contexte);
    IF coalesce((publication->>'ok')::boolean,false) IS NOT TRUE THEN RETURN publication;END IF;
    pop_gain:=(publication->>'gain_pop')::integer;
    pa_cout:=NULL; -- publier au forum ne coûte aucun PA : règle préexistante.
  WHEN 'campagne_securite'THEN
    IF p_contexte<>'{}'::jsonb THEN RETURN jsonb_build_object('ok',false,'raison','contexte_invalide');END IF;
    IF to_regprocedure('public.mairie_campagne_securite_interne(text)')IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','ordre_non_raccorde');END IF;
    publication:=public.mairie_campagne_securite_interne(a.name);
    IF NOT coalesce((publication->>'ok')::boolean,false)THEN RETURN publication;END IF;
    pa_cout:=NULL;pop_gain:=-3;
  WHEN 'ecouter_rumeurs' THEN
    IF p_contexte<>'{}'::jsonb THEN RETURN jsonb_build_object('ok',false,'raison','contexte_invalide');END IF;
    IF to_regprocedure('public.rumeur_ecoute_jauges_interne(text)')IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','ordre_non_raccorde');END IF;
    publication:=public.rumeur_ecoute_jauges_interne(a.name);
    IF NOT coalesce((publication->>'ok')::boolean,false)THEN RETURN publication;END IF;
    pa_cout:=(publication->>'pa_cout')::integer;inf_gain:=(publication->>'gain_inf')::integer;
  WHEN 'consommer_buvette' THEN
    IF p_contexte<>'{}'::jsonb THEN RETURN jsonb_build_object('ok',false,'raison','contexte_invalide');END IF;
    IF a.current_building IS DISTINCT FROM 'stade'OR a.current_room IS DISTINCT FROM 'buvette'
       OR NOT EXISTS(SELECT 1 FROM public.villes WHERE pays=a.country AND ville=a.current_city)THEN
      RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
    -- Même vente à la structure : débit, taxes et recette du stade, pas un second paiement.
    publication:=public.vente_structure_encaisser('consommer_buvette',1,50,a.country||'_stade_'||a.current_city,a.current_city);
    IF NOT coalesce((publication->>'ok')::boolean,false)THEN RETURN publication;END IF;
    pa_cout:=NULL;pop_gain:=2;
  WHEN 'observer_debats' THEN
    IF a.current_building IS DISTINCT FROM 'assemblee'OR a.current_room IS DISTINCT FROM 'hemicycle'OR a.current_city IS DISTINCT FROM 'capitale' THEN
      RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
    IF p_contexte<>'{}'::jsonb THEN RETURN jsonb_build_object('ok',false,'raison','contexte_invalide');END IF;
    pa_cout:=1; inf_gain:=CASE WHEN a.career='press' THEN 1 ELSE 0 END;
  WHEN 'consulter_dossiers_gouv' THEN
    IF a.current_building IS DISTINCT FROM 'palais-gouvernement'OR a.current_room IS DISTINCT FROM 'archives_gouv'OR a.current_city IS DISTINCT FROM 'capitale' THEN
      RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
    IF nullif(a.poste->>'id','') IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','poste_requis'); END IF;
    IF p_contexte<>'{}'::jsonb THEN RETURN jsonb_build_object('ok',false,'raison','contexte_invalide');END IF;
    pa_cout:=2; inf_gain:=2;
  WHEN 'inspecter_troupes' THEN
    IF p_contexte NOT IN ('{"niveau":"revue"}'::jsonb,'{"niveau":"detaillee"}'::jsonb) THEN
      RETURN jsonb_build_object('ok',false,'raison','contexte_invalide');END IF;
    perimetre:=public.militaire_inspection_perimetre();
    IF coalesce((perimetre->>'ok')::boolean,false) IS NOT TRUE THEN RETURN perimetre; END IF;
    pa_cout:=CASE WHEN p_contexte->>'niveau'='revue' THEN 1 ELSE 2 END;
    inf_gain:=CASE WHEN p_contexte->>'niveau'='revue' THEN 3 ELSE 5 END;
  WHEN 'greve_faim' THEN
    IF a.current_building IS DISTINCT FROM 'qhs-prison'OR a.current_room IS DISTINCT FROM 'cellules_qhs' OR jsonb_typeof(a.est_emprisonne) IS DISTINCT FROM 'object'
       OR a.est_emprisonne='{}'::jsonb THEN RETURN jsonb_build_object('ok',false,'raison','detention_requise');END IF;
    IF p_contexte<>'{}'::jsonb THEN RETURN jsonb_build_object('ok',false,'raison','contexte_invalide');END IF;
    pa_cout:=0;pop_gain:=3;
  ELSE RETURN jsonb_build_object('ok',false,'raison','ordre_non_raccorde');
  END CASE;
  IF pa_cout IS NOT NULL THEN
    paiement:=public.payer_ordre(a.name,p_ordre,pa_cout,argent_cout);
    IF coalesce((paiement->>'ok')::boolean,false) IS NOT TRUE THEN RETURN paiement;END IF;
  END IF;
  -- Relire après le paiement : aucun snapshot antérieur ne remplace les PA ou soldes.
  SELECT * INTO a FROM public.personnages_donnees WHERE name=a.name FOR UPDATE;
  ressources:=coalesce(a.resources,'{}'::jsonb)-'popBase'-'infBase';
  IF pop_gain<>0 THEN ressources:=jsonb_set(ressources,'{pop}',to_jsonb(least(100,greatest(0,coalesce((ressources->>'pop')::numeric,0)+pop_gain))));END IF;
  IF inf_gain<>0 THEN ressources:=jsonb_set(ressources,'{inf}',to_jsonb(least(100,greatest(0,coalesce((ressources->>'inf')::numeric,0)+inf_gain))));END IF;
  UPDATE public.personnages_donnees SET resources=ressources,
    hp=CASE WHEN p_ordre='greve_faim' THEN greatest(1,hp-5) ELSE hp END
    WHERE name=a.name RETURNING * INTO a;
  sortie:=coalesce(publication,'{}'::jsonb)||jsonb_build_object('ok',true,'contrat_jauges',1,'acteur',a.name,'requete',p_requete,'ordre',p_ordre,
    'pop',a.resources->'pop','inf',a.resources->'inf','gain_pop',pop_gain,'gain_inf',inf_gain,
    'pa',a.pa,'hp',a.hp,'moral',a.moral,'arg',a.arg,'liquide',a.liquide,'perimetre',perimetre,
    'solde_national',coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=a.name AND banque='nationale'),0));
  INSERT INTO public.jauges_actions_recus(acteur,requete,ordre,contexte,resultat)VALUES(a.name,p_requete,p_ordre,contexte_recu,sortie);
  RETURN sortie;
END;$function$;
REVOKE ALL ON FUNCTION public.jauges_ordre_executer(text,uuid,jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.jauges_ordre_executer(text,uuid,jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';
