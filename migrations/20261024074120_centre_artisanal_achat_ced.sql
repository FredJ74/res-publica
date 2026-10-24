-- Achat autorise le 24 octobre : une boulette, 50 FR, aucun effet de consommation ajoute.
-- Aucun acte de joueur n'est execute par cette migration.
CREATE TABLE IF NOT EXISTS public.pnj_ced_achats_recus (
 acteur uuid NOT NULL, requete uuid NOT NULL, prix integer NOT NULL CHECK(prix=50),
 cree_le timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(acteur,requete)
);
ALTER TABLE public.pnj_ced_achats_recus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pnj_ced_achats_recus FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE public.pnj_ced_achats_recus IS 'HG achat Ced atomique v1 : recus techniques, sans donnees initiales';

CREATE OR REPLACE FUNCTION public.pnj_ced_acheter(p_requete uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE acteur text; p public.personnages_donnees%rowtype; rejeu boolean; inv jsonb;
BEGIN
 acteur:=public.mon_personnage();
 IF auth.uid() IS NULL OR acteur IS NULL THEN
  RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');
 END IF;
 IF p_requete IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_invalide'); END IF;
 -- Meme verrou/revision que reception, dons et sauvegardes : jamais un ajout local.
 PERFORM public.inventaire_reception_etat(acteur);
 SELECT * INTO p FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 SELECT EXISTS(SELECT 1 FROM public.pnj_ced_achats_recus r
  WHERE r.acteur=p.id AND r.requete=p_requete) INTO rejeu;
 IF NOT rejeu THEN
  IF p.country IS DISTINCT FROM 'republic' OR p.current_city IS DISTINCT FROM 'capitale'
   OR p.current_building IS DISTINCT FROM 'centre-artisanal' OR p.current_room IS DISTINCT FROM 'travees' THEN
   RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');
  END IF;
  IF public.inventaire_place_restante(p.inventory)<1 THEN
   RETURN jsonb_build_object('ok',false,'raison','inventaire_plein');
  END IF;
  IF public.helvetia_debiter_fonds_ordinaires(acteur,50) IS NOT TRUE THEN
   RETURN jsonb_build_object('ok',false,'raison','fonds_insuffisants');
  END IF;
  inv:=p.inventory||jsonb_build_array(jsonb_build_object(
   'id','ced-'||p.id::text||'-'||p_requete::text,'type','drogue','name','Boulette de shit',
   'icon','ti-leaf','desc','Une boulette de résine de cannabis. Marchandise illégale.',
   'legal',false,'stackable',false,'encombrement',1));
  UPDATE public.personnages_donnees SET inventory=inv WHERE id=p.id;
  SELECT * INTO p FROM public.personnages_donnees WHERE id=p.id;
  IF p.inventory IS DISTINCT FROM inv THEN RAISE EXCEPTION 'inventaire_ecriture_non_appliquee'; END IF;
  -- Jour commun et instant reel : la preuve n'est pas datee par le cache du joueur.
  INSERT INTO public.actions_tracables(id,auteur,cible,type_action,country,city,jour,jour_expiration)
   VALUES('ced-'||p.id::text||'-'||p_requete::text,acteur,'Céd'' Labone','achat_drogue',
    p.country,p.current_city,public.jour_de_jeu_pays(p.country),public.jour_de_jeu_pays(p.country)+7);
  INSERT INTO public.pnj_ced_achats_recus(acteur,requete,prix) VALUES(p.id,p_requete,50);
 END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE id=p.id;
 RETURN jsonb_build_object('ok',true,'rejeu',rejeu,'prix',50,'inventory',p.inventory,'revision',p.inventory_revision,
  'paiement',jsonb_build_object('pa',p.pa,'arg',p.arg,'liquide',p.liquide,'solde_national',
   coalesce((SELECT cb.solde FROM public.comptes_bancaires cb WHERE cb.personnage=acteur AND cb.banque='nationale'),0)));
END;$function$;
REVOKE ALL ON FUNCTION public.pnj_ced_acheter(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.pnj_ced_acheter(uuid) TO authenticated;
