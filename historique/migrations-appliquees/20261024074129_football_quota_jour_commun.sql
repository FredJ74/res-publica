-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261024074129.
-- Archivage documentaire seulement ; ne pas rejouer.
-- Quota commun Europe/Paris : les dates reelles rendent inutile toute reecriture historique.
-- Les deux entrainements deja effectues aujourd'hui restent comptes, meme apres sommeil.
CREATE INDEX IF NOT EXISTS entrainements_football_perso_date ON public.entrainements_football(personnage,cree_le);

CREATE OR REPLACE FUNCTION public.football_entrainements_compter_interne(p_personnage text,p_date date)
RETURNS integer LANGUAGE sql STABLE SET search_path=public,pg_temp AS $function$
 SELECT count(*)::integer FROM public.entrainements_football e
 WHERE e.personnage=p_personnage
  AND e.cree_le >= (p_date::timestamp AT TIME ZONE 'Europe/Paris')
  AND e.cree_le < ((p_date+1)::timestamp AT TIME ZONE 'Europe/Paris');
$function$;
REVOKE ALL ON FUNCTION public.football_entrainements_compter_interne(text,date) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.football_entrainement_consommer(p_stat text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE c_max constant integer := 2;
        v_moi text; v_jour integer; v_nb integer; v_paie jsonb; v_id text;
BEGIN
  IF p_stat NOT IN ('defense','technique','endurance') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stat_invalide');
  END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- DOUBLE CLIC : le second appel attend ici, puis constate la limite.
  PERFORM pg_advisory_xact_lock(hashtext('football_entrainement|' || v_moi));

  SELECT public.jour_de_jeu_pays(d.country) INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF v_jour IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  v_nb := public.football_entrainements_compter_interne(v_moi,(now() AT TIME ZONE 'Europe/Paris')::date);

  IF v_nb >= c_max THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'limite_quotidienne_atteinte',
                              'nb', v_nb, 'max', c_max, 'jour', v_jour);
  END IF;

  -- LE PAIEMENT EN DERNIER, ET PAR L'AUTORITE HABITUELLE (miroir des couts + verrou).
  v_paie := public.payer_ordre(v_moi, 'tenue_entrainement', 2, 0);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'paiement_refuse'));
  END IF;

  v_id := 'ef-' || (extract(epoch from clock_timestamp())*1000)::bigint
               || '-' || substr(md5(random()::text), 1, 6);
  INSERT INTO public.entrainements_football (id, personnage, jour, stat)
  VALUES (v_id, v_moi, v_jour, p_stat);

  RETURN jsonb_build_object('ok', true, 'nb', v_nb + 1, 'max', c_max,
                            'jour', v_jour, 'pa', v_paie->'pa');
END;
$function$;

CREATE OR REPLACE FUNCTION public.football_entrainements_du_jour()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE c_max constant integer := 2; v_moi text; v_jour integer; v_nb integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT public.jour_de_jeu_pays(d.country) INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF v_jour IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;
  v_nb := public.football_entrainements_compter_interne(v_moi,(now() AT TIME ZONE 'Europe/Paris')::date);
  RETURN jsonb_build_object('ok', true, 'nb', v_nb, 'max', c_max, 'jour', v_jour);
END;
$function$;

REVOKE ALL ON FUNCTION public.football_entrainements_du_jour(),public.football_entrainement_consommer(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.football_entrainements_du_jour(),public.football_entrainement_consommer(text) TO authenticated;

