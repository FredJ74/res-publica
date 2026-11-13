-- Repas de la clinique privée : admission des clients disposant d'une nuitée payée.
-- Prix et gain conservés (1 PA + 30 FR/PSK, +4 PA au prochain Dormir).
-- Les hospitalisations médicales et le repos nocturne ne sont pas modifiés.
-- Contrôle serveur : réservation valide et chambre attribuée au même personnage.
ALTER TABLE public.clinique_nuitees ADD COLUMN IF NOT EXISTS repas_le date;
COMMENT ON COLUMN public.clinique_nuitees.repas_le
 IS 'Dernier repas servi pendant la réservation ; au plus un repas par jour civil (Europe/Paris).';

CREATE OR REPLACE FUNCTION public.hospitalisation_repas_prendre()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text; p public.personnages_donnees%ROWTYPE; v_j integer; aujourdhui text;
 v_pa integer; v_cost integer; paiement jsonb; v_fn text; v_bonus integer;
 v_nuit public.clinique_nuitees%ROWTYPE;
BEGIN
 moi := public.mon_personnage();
 IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name = moi FOR UPDATE;
 v_j := public.hospitalisation_jour_pa0(p.hospitalisation);
 IF v_j IS NULL AND p.country IN ('republic','soviet')
    AND p.current_city='capitale'
    AND p.current_building='clinique-privee'
    AND p.current_room ~ '^chambre_([1-9]|10)$'
    AND (p.hospitalisation IS NULL OR p.hospitalisation='null'::jsonb)
 THEN
   -- Le client d'une nuitée réservée est un occupant légitime, pas un patient hospitalisé.
   -- Vérifier conjointement le titre de réservation ET l'occupation réelle de sa chambre.
   SELECT * INTO v_nuit FROM public.clinique_nuitees
    WHERE personnage=moi AND country=p.country AND city='capitale'
      AND room_id=p.current_room AND consommee_le IS NULL AND annulee_le IS NULL
    ORDER BY id DESC LIMIT 1 FOR UPDATE;
   IF NOT FOUND OR NOT EXISTS (
     SELECT 1 FROM public.locations_actives l
      WHERE l.id=p.country||':clinique-privee:'||p.current_room||':capitale'
        AND l.country=p.country AND l.data->>'locataire'=moi
        AND l.data->>'reservationClinique'='true'
        AND l.data->>'roomId'=p.current_room
   ) THEN
     RETURN jsonb_build_object('ok',false,'raison','non_hospitalise');
   END IF;
   aujourdhui := (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text;
   IF v_nuit.repas_le=aujourdhui::date THEN
     RETURN jsonb_build_object('ok',false,'raison','repas_deja_pris'); END IF;
   SELECT pa,cost INTO v_pa,v_cost FROM public.ordres_couts
     WHERE fn='repas_clinique' ORDER BY cost DESC LIMIT 1;
   IF v_pa IS NULL OR v_pa<>1 OR v_cost<>30 THEN
     RETURN jsonb_build_object('ok',false,'raison','cout_non_declare','fn','repas_clinique'); END IF;
   paiement:=public.payer_ordre_interne(moi,'repas_clinique',v_pa,v_cost);
   IF NOT coalesce((paiement->>'ok')::boolean,false) THEN RETURN paiement; END IF;
   UPDATE public.clinique_nuitees SET repas_le=aujourdhui::date WHERE id=v_nuit.id;
   -- Ce crédit est consommé une seule fois par pa_repos_nocturne au prochain Dormir autorisé ;
   -- ne jamais créer une fausse hospitalisation pour le client d'une chambre privée.
   UPDATE public.personnages_donnees
      SET bonus_pa_differe=coalesce(bonus_pa_differe,0)+4
    WHERE name=moi RETURNING pa INTO v_pa;
   RETURN jsonb_build_object('ok',true,'mode','nuitee','pa',v_pa,
     'cout',v_cost,'bonus_lendemain',4,
     'liquide',(SELECT liquide FROM public.personnages_donnees WHERE name=moi),
     'arg',(SELECT arg FROM public.personnages_donnees WHERE name=moi));
 END IF;
 IF v_j IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_hospitalise'); END IF;
 IF p.current_building = 'clinique-privee' THEN v_fn := 'repas_clinique'; v_bonus := 4;
 ELSIF coalesce(p.current_building,'') LIKE 'dispensaire-public%' THEN v_fn := 'repas_hopital'; v_bonus := 2;
 ELSE RETURN jsonb_build_object('ok',false,'raison','pas_a_l_hopital'); END IF;
 aujourdhui := (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text;
 IF p.hospitalisation->>'repasLe' = aujourdhui THEN
  RETURN jsonb_build_object('ok',false,'raison','repas_deja_pris'); END IF;
 SELECT pa, cost INTO v_pa, v_cost FROM public.ordres_couts WHERE fn = v_fn ORDER BY cost DESC LIMIT 1;
 IF v_pa IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','cout_non_declare','fn',v_fn); END IF;
 paiement := public.payer_ordre_interne(moi, v_fn, v_pa, v_cost);
 IF NOT coalesce((paiement->>'ok')::boolean,false) THEN RETURN paiement; END IF;
 UPDATE public.personnages_donnees
    SET hospitalisation = hospitalisation || jsonb_build_object('repasLe', aujourdhui, 'repasBonus', v_bonus)
  WHERE name = moi RETURNING pa INTO v_pa;
 RETURN jsonb_build_object('ok',true,'pa',v_pa,'cout',v_cost,'bonus_lendemain',v_bonus,'jour',v_j,
   'liquide',(SELECT liquide FROM public.personnages_donnees WHERE name = moi),
   'arg',(SELECT arg FROM public.personnages_donnees WHERE name = moi));
END $function$


REVOKE ALL ON FUNCTION public.hospitalisation_repas_prendre() FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.hospitalisation_repas_prendre() TO authenticated;
