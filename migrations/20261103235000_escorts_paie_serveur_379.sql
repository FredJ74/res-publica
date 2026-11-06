-- #379, lot 3b (Claude, 03/11/2026) : paie quotidienne des escorts décidée par le serveur.
-- Règle existante de l'écran (payerEscorts, au réveil), inchangée :
--   * chaque escort active est payée de son tarif du jour sur les fonds ordinaires ;
--   * si les fonds ne suffisent pas : elle porte plainte et quitte le service, -20 POP.
--     (Le -15 DIS, le courrier du tribunal et l'article restent à l'écran.)
-- Avant : le navigateur se débitait lui-même et posait le -20 POP ; le serveur ne débitait rien.
-- Désormais : un seul appel au réveil, une transaction, un reçu par escort et par jour réel.
-- Dépend de 20261103230000 (jauges_effet_appliquer_interne).

DO $prevol$
BEGIN
 IF to_regprocedure('public.jauges_effet_appliquer_interne(text,integer,integer,integer)') IS NULL THEN
  RAISE EXCEPTION '379_lot3b_lot_presidence_absent'; END IF;
 IF to_regprocedure('public.debiter_fonds_ordinaires(text,numeric)') IS NULL
    OR to_regclass('public.pnj_employes_metier') IS NULL THEN
  RAISE EXCEPTION '379_lot3b_socle_employes_absent'; END IF;
END $prevol$;

CREATE TABLE IF NOT EXISTS public.escorts_paies_recus(
  pnj_id text NOT NULL,
  jour date NOT NULL,
  employeur text NOT NULL,
  tarif integer NOT NULL,
  paye boolean NOT NULL,
  cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(pnj_id,jour));
ALTER TABLE public.escorts_paies_recus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.escorts_paies_recus FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.escorts_payer_jour()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $f$
DECLARE moi text:=public.mon_personnage(); a public.personnages_donnees;
  v_jour date:=(now() AT TIME ZONE 'Europe/Paris')::date; e record; v_pay jsonb; v_paye boolean;
  v_paies jsonb:='[]'::jsonb; v_malus integer:=0;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT * INTO a FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
  FOR e IN
    SELECT m.id, m.nom, greatest(0,coalesce(em.cout_jour,0))::integer tarif
      FROM public.pnj_membres m JOIN public.pnj_employes_metier em ON em.pnj_id=m.id
     WHERE m.famille='employe' AND m.proprietaire_pj=moi AND m.statut='actif' AND em.job='escort'
       AND NOT EXISTS(SELECT 1 FROM public.escorts_paies_recus r WHERE r.pnj_id=m.id AND r.jour=v_jour)
     ORDER BY m.id FOR UPDATE OF m
  LOOP
    v_pay:=public.debiter_fonds_ordinaires(moi,e.tarif);
    v_paye:=coalesce((v_pay->>'ok')::boolean,false);
    IF NOT v_paye THEN
      -- Même départ que employe_liberer(…, 'impaye'), dans la même transaction que le malus.
      UPDATE public.pnj_membres
         SET statut='disparu',leader_pj=NULL,leader_pnj_id=NULL,
             ville=NULL,building_id=NULL,room_id=NULL,rue_noeud_id=NULL,maj_le=now()
       WHERE id=e.id;
      v_malus:=v_malus-20;
    END IF;
    INSERT INTO public.escorts_paies_recus(pnj_id,jour,employeur,tarif,paye) VALUES(e.id,v_jour,moi,e.tarif,v_paye);
    v_paies:=v_paies||jsonb_build_array(jsonb_build_object('pnj_id',e.id,'nom',e.nom,'tarif',e.tarif,'paye',v_paye));
  END LOOP;
  IF v_malus<>0 THEN PERFORM public.jauges_effet_appliquer_interne(moi,v_malus,0,0); END IF;
  SELECT * INTO a FROM public.personnages_donnees WHERE name=moi;
  RETURN jsonb_build_object('ok',true,'acteur',moi,'jour',v_jour,'paies',v_paies,'gain_pop',v_malus,
    'pop',a.resources->'pop','inf',a.resources->'inf','arg',a.arg,'liquide',a.liquide,
    'solde_national',coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=moi AND banque='nationale'),0));
END;$f$;
REVOKE ALL ON FUNCTION public.escorts_payer_jour() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.escorts_payer_jour() TO authenticated;
NOTIFY pgrst,'reload schema';
