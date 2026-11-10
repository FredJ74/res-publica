-- Paris sur les phases finales du championnat, en réutilisant paris_sportifs,
-- le calendrier et les résultats canoniques du serveur. Aucun résultat calculé côté client.
-- Une mise = au plus un débit : identifiant déterministe et verrou transactionnel.
CREATE OR REPLACE FUNCTION public.football_pari_playoff_engager(
 p_manche text,p_home text,p_away text,p_choix text,p_mise integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $football$
DECLARE
 v_moi text; v_s jsonb; v_p jsonb; v_paires jsonb; v_pair jsonb;
 v_saison integer; v_kickoff timestamptz; v_id text; v_arg numeric;
 v_paie jsonb;
BEGIN
 v_moi:=public.mon_personnage();
 IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 IF p_manche NOT IN ('quarts_aller','quarts_retour','demies_aller','demies_retour','finale')
   OR p_manche IS NULL OR p_choix NOT IN ('domicile','nul','adversaire') OR p_choix IS NULL
   OR p_mise IS NULL OR p_mise<10 OR p_mise>1000000
   OR p_home IS NULL OR p_away IS NULL OR p_home=p_away
 THEN RETURN jsonb_build_object('ok',false,'raison','mise_ou_pronostic_invalide'); END IF;
 SELECT data INTO v_s FROM public.championnat WHERE id=2 FOR SHARE;
 IF v_s IS NULL OR v_s->'playoffs' IS NULL OR v_s#>>'{playoffs,etape}' IS DISTINCT FROM p_manche
 THEN RETURN jsonb_build_object('ok',false,'raison','manche_indisponible'); END IF;
 v_p:=v_s->'playoffs';
 IF nullif(v_p->>'prochainKickoffISO','') IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','date_absente'); END IF;
 v_kickoff:=(v_p->>'prochainKickoffISO')::timestamptz;
 IF now()>=v_kickoff THEN RETURN jsonb_build_object('ok',false,'raison','match_deja_commence'); END IF;
 IF p_manche='finale' THEN
   v_paires:=jsonb_build_array(v_p#>'{finale,paire}');
 ELSIF p_manche LIKE 'quarts_%' THEN
   v_paires:=v_p#>'{quarts,paires}';
 ELSE
   v_paires:=v_p#>'{demies,paires}';
 END IF;
 IF v_paires IS NULL OR jsonb_typeof(v_paires)<>'array' THEN
   RETURN jsonb_build_object('ok',false,'raison','calendrier_invalide'); END IF;
 SELECT e INTO v_pair FROM jsonb_array_elements(v_paires) e
  WHERE jsonb_typeof(e)='array' AND jsonb_array_length(e)=2
    AND (CASE WHEN p_manche IN ('quarts_retour','demies_retour') THEN e->>1 ELSE e->>0 END)=p_home
    AND (CASE WHEN p_manche IN ('quarts_retour','demies_retour') THEN e->>0 ELSE e->>1 END)=p_away
  LIMIT 1;
 IF v_pair IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','match_inconnu'); END IF;
 v_saison:=(v_s->>'numero')::integer;
 v_id:='pari:playoff:'||v_moi||':'||v_saison||':'||p_manche||':'||p_home||':'||p_away;
 PERFORM pg_advisory_xact_lock(hashtextextended(v_id,0));
 IF EXISTS(SELECT 1 FROM public.paris_sportifs WHERE id=v_id) THEN
   RETURN jsonb_build_object('ok',false,'raison','pari_deja_engage');
 END IF;
 SELECT arg INTO v_arg FROM public.personnages_donnees WHERE name=v_moi FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_introuvable'); END IF;
 IF coalesce(v_arg,0)<p_mise THEN RETURN jsonb_build_object('ok',false,'raison','fonds_insuffisants'); END IF;
 -- Les PA et la mise sont débités dans la même transaction que le ticket.
 v_paie:=public.payer_ordre(v_moi,'parier_match',1,0);
 IF (v_paie->>'ok')::boolean IS DISTINCT FROM true THEN RETURN v_paie; END IF;
 PERFORM public.argent_debiter_interne(v_moi,p_mise,'liquide_puis_nationale');
 INSERT INTO public.paris_sportifs (id,resolu,data)
 VALUES(v_id,false,jsonb_build_object('joueur',v_moi,'homeId',p_home,'awayId',p_away,
   'choix',p_choix,'mise',p_mise,'saisonNumero',v_saison,'playoffManche',p_manche));
 SELECT arg INTO v_arg FROM public.personnages_donnees WHERE name=v_moi;
 RETURN jsonb_build_object('ok',true,'id',v_id,'mise',p_mise,'saison',v_saison,'arg',v_arg,
   'paiement',v_paie);
END $football$;
REVOKE ALL ON FUNCTION public.football_pari_playoff_engager(text,text,text,text,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.football_pari_playoff_engager(text,text,text,text,integer) TO authenticated;

-- Règlement atomique et rejouable après enregistrement du résultat officiel.
-- Un appel prématuré n'accomplit aucune écriture ni aucun règlement.
CREATE OR REPLACE FUNCTION public.football_pari_playoff_resoudre(p_manche text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $football$
DECLARE
 v_s jsonb; v_p jsonb; v_resultats jsonb; v_m jsonb; v_pari record;
 v_saison integer; v_reel text; v_cote numeric; v_gain integer; v_gagne boolean;
 v_n integer:=0; v_payes integer:=0; v_total integer:=0; v_detail jsonb:='[]'::jsonb;
BEGIN
 IF auth.uid() IS NULL AND NOT public.est_appel_serveur() THEN
   RETURN jsonb_build_object('ok',false,'raison','appelant_non_authentifie');
 END IF;
 IF p_manche NOT IN ('quarts_aller','quarts_retour','demies_aller','demies_retour','finale') OR p_manche IS NULL
 THEN RETURN jsonb_build_object('ok',false,'raison','manche_invalide'); END IF;
 SELECT data INTO v_s FROM public.championnat WHERE id=2;
 IF v_s IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','championnat_absent');END IF;
 v_p:=v_s->'playoffs'; v_saison:=coalesce((v_s->>'numero')::integer,0);
 IF v_p IS NULL THEN RETURN jsonb_build_object('ok',true,'regles',0,'detail','[]'::jsonb); END IF;
 v_resultats:=CASE p_manche
   WHEN 'quarts_aller' THEN v_p#>'{quarts,aller}'
   WHEN 'quarts_retour' THEN v_p#>'{quarts,retour}'
   WHEN 'demies_aller' THEN v_p#>'{demies,aller}'
   WHEN 'demies_retour' THEN v_p#>'{demies,retour}'
   WHEN 'finale' THEN CASE WHEN v_p#>'{finale,resultat}' IS NULL THEN NULL
       ELSE jsonb_build_array(v_p#>'{finale,resultat}') END
   END;
 IF v_resultats IS NULL OR jsonb_typeof(v_resultats)<>'array'
 THEN RETURN jsonb_build_object('ok',true,'regles',0,'detail','[]'::jsonb);END IF;
 FOR v_pari IN
   SELECT id,data FROM public.paris_sportifs
   WHERE resolu=false AND data->>'playoffManche'=p_manche
     AND (data->>'saisonNumero')::integer=v_saison
   FOR UPDATE SKIP LOCKED
 LOOP
   SELECT m INTO v_m FROM jsonb_array_elements(v_resultats) m
   WHERE m->>'home'=v_pari.data->>'homeId' AND m->>'away'=v_pari.data->>'awayId';
   CONTINUE WHEN v_m IS NULL OR v_m->>'scoreHome' IS NULL OR v_m->>'scoreAway' IS NULL;
   v_reel:=CASE WHEN (v_m->>'scoreHome')::integer>(v_m->>'scoreAway')::integer THEN 'domicile'
         WHEN (v_m->>'scoreHome')::integer<(v_m->>'scoreAway')::integer THEN 'adversaire'
         ELSE 'nul' END;
   v_gagne:=v_reel=(v_pari.data->>'choix');
   v_cote:=CASE v_pari.data->>'choix' WHEN 'domicile' THEN 2.5 WHEN 'nul' THEN 3.5 WHEN 'adversaire' THEN 3 ELSE NULL END;
   CONTINUE WHEN v_cote IS NULL;
   v_gain:=CASE WHEN v_gagne THEN round((v_pari.data->>'mise')::numeric*v_cote)::integer ELSE 0 END;
   UPDATE public.paris_sportifs SET resolu=true WHERE id=v_pari.id;
   IF v_gain>0 THEN
     PERFORM public.argent_crediter_interne(v_pari.data->>'joueur',v_gain,'liquide');
     v_payes:=v_payes+1; v_total:=v_total+v_gain;
   END IF;
   v_n:=v_n+1;
   v_detail:=v_detail||jsonb_build_array(jsonb_build_object('id',v_pari.id,'joueur',v_pari.data->>'joueur',
       'gagne',v_gagne,'gain',v_gain,'homeId',v_pari.data->>'homeId','awayId',v_pari.data->>'awayId'));
 END LOOP;
 RETURN jsonb_build_object('ok',true,'manche',p_manche,'regles',v_n,'payes',v_payes,'total',v_total,'detail',v_detail);
END $football$;
REVOKE ALL ON FUNCTION public.football_pari_playoff_resoudre(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.football_pari_playoff_resoudre(text) TO authenticated;
