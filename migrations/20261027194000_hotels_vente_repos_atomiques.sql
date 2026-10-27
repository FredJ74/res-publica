-- #63 Raccorder le stock de nuitees aux paiements et au repos, sans paiement client parallele.
BEGIN;
DO $patch$
DECLARE d text; a integer;b integer; old text;neu text;
BEGIN
 -- Republica: conserver toutes les lignes de caisse, taxe et stock existantes;
 -- remplacer seulement l'affectation qui ecrasait la nuit precedente.
 SELECT pg_get_functiondef('public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)'::regprocedure) INTO d;
 IF position('hotel_nuitee_ajouter_interne' IN d)=0 THEN
 a:=strpos(d,'  IF public.restaurant_luthecia_est_commerce(v_data) AND p_ordre=''reserver_chambre_hotel'' THEN');
 IF a=0 THEN RAISE EXCEPTION 'hotel_republica_source_inconnue';END IF;
 b:=strpos(substr(d,a),'  END IF;');
 IF b=0 THEN RAISE EXCEPTION 'hotel_republica_bloc_inconnu';END IF;
 d:=substr(d,1,a-1)||
 '  IF public.restaurant_luthecia_est_commerce(v_data) AND p_ordre=''reserver_chambre_hotel'' THEN'||chr(10)||
 '    PERFORM public.hotel_nuitee_ajouter_interne(p_acteur,''hotel-republica'');'||chr(10)||
 '  END IF;'||substr(d,a+b-1+length('  END IF;'));
 EXECUTE d;
 END IF;

 -- Autres hotels: le droit est cree DANS la transaction qui preleve,
 -- calcule la taxe et credite la caisse; aucune course de sauvegarde navigateur.
 SELECT pg_get_functiondef('public.vente_structure_encaisser(text,integer,integer,text,text)'::regprocedure) INTO d;
 IF position('hotel_nuitee_ajouter_interne' IN d)=0 THEN
 old:='  RETURN jsonb_build_object('||chr(10)||'    ''ok'', true,';
 IF strpos(d,old)=0 OR (length(d)-length(replace(d,old,'')))<>length(old) THEN
 RAISE EXCEPTION 'hotel_vente_structure_source_inconnue';END IF;
 neu:='  IF p_fn = ''reserver_chambre_hotel'' THEN'||chr(10)||
 '    PERFORM public.hotel_nuitee_ajouter_interne(v_acteur,(SELECT current_building FROM public.personnages_donnees WHERE name=v_acteur));'||chr(10)||
 '  END IF;'||chr(10)||chr(10)||old;
 EXECUTE replace(d,old,neu);
 END IF;

 -- Consommation et attribution de +PA/+moral liees au meme commit que le
 -- seul repos journalier autorise (France/Paris). Un refus ne mange rien.
 SELECT pg_get_functiondef('public.pa_repos_nocturne(text)'::regprocedure) INTO d;
 IF position('hotel_nuitee_consommation_interne' IN d)=0 THEN
 old:='  v_pa integer; v_qhs jsonb;';neu:='  v_pa integer; v_chambre jsonb; v_qhs jsonb;';
 IF strpos(d,old)=0 THEN RAISE EXCEPTION 'hotel_repos_variables_inconnues';END IF;
 d:=replace(d,old,neu);
 old:='  RETURN jsonb_build_object(''ok'', true, ''pa'', v_nouveau, ''bonus_consomme'', v_bonus,';
 neu:='  v_chambre:=public.hotel_nuitee_consommation_interne(p_acteur);'||chr(10)||
 '  IF coalesce((v_chambre->>''ok'')::boolean,false) THEN v_nouveau:=(v_chambre->>''pa'')::integer; END IF;'||chr(10)||
 '  RETURN jsonb_build_object(''ok'', true, ''pa'', v_nouveau, ''hotel'', v_chambre, ''bonus_consomme'', v_bonus,';
 IF strpos(d,old)=0 THEN RAISE EXCEPTION 'hotel_repos_retour_inconnu';END IF;
 EXECUTE replace(d,old,neu);
 END IF;
END;$patch$;

-- Compatibilite: l'ancienne porte NE peut plus consommer une seconde nuit;
-- toute consommation passe dans la transaction du repos.
CREATE OR REPLACE FUNCTION public.pa_bonus_chambre(p_acteur text,p_batiment text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
BEGIN
 PERFORM public.exiger_acteur(p_acteur);
 RETURN jsonb_build_object('ok',false,'raison','bonus_inclus_dans_repos');
END;$f$;
COMMIT;