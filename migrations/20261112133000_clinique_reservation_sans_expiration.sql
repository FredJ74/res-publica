-- Décision game design : la chambre de clinique reste payée et attribuée
-- tant que le joueur n'a pas effectué le premier Dormir validé dans CETTE chambre.
-- La réservation est autorisée même si le repos du jour est déjà consommé.
-- Aucun nouveau prix, PA, soin ou effet économique ; aucune donnée joueur effacée.
-- Reprise déterministe après une perte de réponse et compatibilité avec les transferts hospitaliers.

CREATE OR REPLACE FUNCTION public.clinique_nuitee_reserver()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $func$
DECLARE
 v_nom text; p record; v_jour date := (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date;
 v_salle text; v_cle text; v_id text; v_debit boolean; v_nuit public.clinique_nuitees%ROWTYPE;
BEGIN
 v_nom:=public.mon_personnage();
 IF v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 -- Même verrou et même ordre pour les dix chambres de chaque pays ; un joueur ne peut
 -- acheter deux nuitées et deux joueurs ne peuvent occuper une même chambre.
 PERFORM pg_advisory_xact_lock(hashtextextended('clinique_nuitee:'||v_nom,0));
 SELECT * INTO p FROM public.personnages_donnees WHERE name=v_nom FOR UPDATE;
 IF NOT FOUND OR p.country NOT IN ('republic','soviet') OR p.current_city<>'capitale'
   OR p.current_building<>'clinique-privee' OR p.current_room<>'reception_clinique'
 THEN RETURN jsonb_build_object('ok',false,'raison','pas_a_accueil'); END IF;
 IF (p.hospitalisation IS NOT NULL AND jsonb_typeof(p.hospitalisation)='object'
     AND COALESCE(NULLIF(p.hospitalisation->>'dateFinParis','')::date,v_jour)>=v_jour)
 THEN RETURN jsonb_build_object('ok',false,'raison','deja_hospitalise'); END IF;
 IF p.est_emprisonne IS NOT NULL AND p.est_emprisonne<>'null'::jsonb
 THEN RETURN jsonb_build_object('ok',false,'raison','indisponible'); END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('clinique_nuitee_pays:'||p.country,0));

 -- Une réservation reste active sans limite de jours jusqu'au sommeil dans la chambre.
 -- Aucune expiration automatique, aucun débit supplémentaire : l'accès est exclusif.

 SELECT * INTO v_nuit FROM public.clinique_nuitees
  WHERE personnage=v_nom AND consommee_le IS NULL AND annulee_le IS NULL
  LIMIT 1;
 IF FOUND THEN RETURN jsonb_build_object('ok',true,'deja_reservee',true,
   'chambre',v_nuit.room_id,'prix',150,'country',p.country,
   'liquide',p.liquide,'arg',p.arg); END IF;

 FOR v_salle IN SELECT 'chambre_'||i::text FROM generate_series(1,10) i LOOP
   v_cle:=p.country||':clinique-privee:'||v_salle||':capitale';
   INSERT INTO public.locations_actives(id,country,data)
   VALUES(v_cle,p.country,jsonb_build_object(
     'buildingId','clinique-privee','roomId',v_salle,'city','capitale',
     'country',p.country,'locataire',v_nom,'depuis',v_jour::text,
     'prix',0,'visible',true,'chambreClinique',true,
     'reservationClinique',true,'visitesAutorisees',false))
   ON CONFLICT(id) DO NOTHING RETURNING id INTO v_id;
   IF v_id IS NOT NULL THEN EXIT; END IF;
 END LOOP;
 IF v_id IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','complet'); END IF;

 -- Paiement dans la transaction de réservation ; priorité banque nationale puis liquide.
 v_debit:=public.helvetia_debiter_fonds_ordinaires(v_nom,150,'nationale');
 IF NOT v_debit THEN
    DELETE FROM public.locations_actives
      WHERE id=v_id AND country=p.country AND data->>'locataire'=v_nom
        AND data->>'reservationClinique'='true';
    RETURN jsonb_build_object('ok',false,'raison','fonds_insuffisants');
 END IF;
 INSERT INTO public.clinique_nuitees(personnage,country,room_id,reservee_le)
 VALUES(v_nom,p.country,v_salle,v_jour);
 RETURN jsonb_build_object('ok',true,'chambre',v_salle,'prix',150,
   'country',p.country,'liquide',(SELECT liquide FROM public.personnages_donnees WHERE name=v_nom),
   'arg',(SELECT arg FROM public.personnages_donnees WHERE name=v_nom));
END;$func$;

CREATE OR REPLACE FUNCTION public.clinique_nuitee_consommer()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $func$
DECLARE
 v_nom text; p record; n public.clinique_nuitees%ROWTYPE;
 v_jour date := (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date;
 v_pa integer; v_hp integer; v_moral integer;
BEGIN
 v_nom:=public.mon_personnage();
 IF v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=v_nom FOR UPDATE;
 IF NOT FOUND OR p.country NOT IN ('republic','soviet')
   THEN RETURN jsonb_build_object('ok',false,'raison','hors_pays'); END IF;
 SELECT * INTO n FROM public.clinique_nuitees
  WHERE personnage=v_nom AND country=p.country AND consommee_le IS NULL AND annulee_le IS NULL
  LIMIT 1 FOR UPDATE;
 IF NOT FOUND THEN
   IF EXISTS (SELECT 1 FROM public.clinique_nuitees
     WHERE personnage=v_nom AND country=p.country AND consommee_le=v_jour)
   THEN RETURN jsonb_build_object('ok',true,'rejeu',true,'pa',p.pa,'hp',p.hp,'moral',p.moral); END IF;
   RETURN jsonb_build_object('ok',false,'raison','aucune_reservation');
 END IF;
 IF p.pa_repos_le IS DISTINCT FROM v_jour OR n.dormie_le IS DISTINCT FROM v_jour
 THEN RETURN jsonb_build_object('ok',false,'raison','repos_non_valide'); END IF;
 IF p.current_city<>'capitale' OR p.current_building<>'clinique-privee'
   OR p.current_room<>n.room_id OR p.country<>n.country
 THEN RETURN jsonb_build_object('ok',false,'raison','hors_chambre'); END IF;
 IF p.hospitalisation IS NOT NULL AND jsonb_typeof(p.hospitalisation)='object'
    AND COALESCE(NULLIF(p.hospitalisation->>'dateFinParis','')::date,v_jour)>=v_jour
 THEN RETURN jsonb_build_object('ok',false,'raison','hospitalise'); END IF;
 IF NOT EXISTS (SELECT 1 FROM public.locations_actives
   WHERE id=p.country||':clinique-privee:'||n.room_id||':capitale'
   AND country=p.country AND data->>'reservationClinique'='true'
   AND data->>'locataire'=v_nom)
 THEN RETURN jsonb_build_object('ok',false,'raison','chambre_non_attribuee'); END IF;
 UPDATE public.personnages_donnees SET
    pa=LEAST(30,GREATEST(0,COALESCE(pa,0)+2)),
    hp=LEAST(100,GREATEST(0,COALESCE(hp,0)+10)),
    moral=LEAST(100,GREATEST(0,COALESCE(moral,0)+3)),
    updated_at=now()
 WHERE name=v_nom RETURNING pa,hp,moral INTO v_pa,v_hp,v_moral;
 UPDATE public.clinique_nuitees SET consommee_le=v_jour WHERE id=n.id;
 DELETE FROM public.locations_actives
   WHERE id=p.country||':clinique-privee:'||n.room_id||':capitale'
   AND country=p.country AND data->>'reservationClinique'='true'
   AND data->>'locataire'=v_nom;
 RETURN jsonb_build_object('ok',true,'rejeu',false,'chambre',n.room_id,
   'pa',v_pa,'hp',v_hp,'moral',v_moral,'bonus_pa',2,'bonus_hp',10,'bonus_moral',3);
END;$func$;

CREATE OR REPLACE FUNCTION public.clinique_nuitee_marquer_repos()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $trigger$
DECLARE v_jour date := (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
 IF NEW.pa_repos_le IS DISTINCT FROM OLD.pa_repos_le
    AND NEW.pa_repos_le=v_jour
    AND NEW.country IN ('republic','soviet') AND NEW.current_city='capitale'
    AND NEW.current_building='clinique-privee'
    AND NEW.current_room ~ '^chambre_([1-9]|10)$'
    AND NOT (NEW.hospitalisation IS NOT NULL AND jsonb_typeof(NEW.hospitalisation)='object'
      AND COALESCE(NULLIF(NEW.hospitalisation->>'dateFinParis','')::date,v_jour)>=v_jour)
 THEN
  UPDATE public.clinique_nuitees n SET dormie_le=v_jour
   WHERE n.personnage=NEW.name AND n.country=NEW.country AND n.room_id=NEW.current_room
     AND n.consommee_le IS NULL AND n.annulee_le IS NULL
     AND EXISTS (SELECT 1 FROM public.locations_actives l
       WHERE l.id=NEW.country||':clinique-privee:'||NEW.current_room||':capitale'
       AND l.country=NEW.country AND l.data->>'locataire'=NEW.name
       AND l.data->>'reservationClinique'='true');
 END IF;
 RETURN NEW;
END;$trigger$;
