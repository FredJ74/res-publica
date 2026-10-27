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

 -- Le repos journalier reste le socle existant.
 -- Le bonus est credite et la nuit consommee par une seule RPC apres retour positif du sommeil.
END;$patch$;

-- Remplace la porte historique destructive par un credit atomique et rejouable.
-- Une réponse perdue ne consomme jamais une seconde nuit le meme jour.
CREATE OR REPLACE FUNCTION public.pa_bonus_chambre(p_acteur text,p_batiment text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE p record;
BEGIN
 PERFORM public.exiger_acteur(p_acteur);
 SELECT current_building INTO p FROM public.personnages_donnees WHERE name=p_acteur FOR UPDATE;
 IF NOT FOUND OR p.current_building IS DISTINCT FROM p_batiment THEN
 RETURN jsonb_build_object('ok',false,'raison','pas_dans_hotel');
 END IF;
 RETURN public.hotel_nuitee_consommation_interne(p_acteur);
END;$f$;
COMMIT;
