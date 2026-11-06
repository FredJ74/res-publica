-- Trading national : livraison terrestre à l'entrepôt de la ville choisie (décision de Fred, 04/11/2026).
-- Avant : tout achat de trading et toute offre d'achat servie à un PJ partaient « par bateau » vers
-- le port industriel de Port-Sainte-Marie, même entre deux villes de Républia (Montrouge n'a pas de
-- port). Désormais, à l'intérieur d'un pays : caisse livrée par camion ou train à l'entrepôt
-- logistique de la ville choisie par l'acheteur, sans douane, même délai qu'avant (24 h, arrivée
-- constatée par la passe de minuit), retirée à la Salle des ventes par « Réceptionner une caisse ».
-- Le bateau reste réservé à l'international (pas encore ouvert : on ne trade que dans son pays).
-- Un courrier dit où et à partir de quand retirer la caisse.

-- 1. Entrepôt de livraison : celui demandé (s'il existe dans le pays), sinon celui de la ville où
--    se trouve l'acheteur, sinon celui de la capitale.
CREATE OR REPLACE FUNCTION public.trading_livraison_entrepot_interne(p_pays text, p_livraison text, p_nom text)
RETURNS TABLE (ville text, building_id text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $f$
  SELECT ep.ville, ep.building_id FROM public.entrepots_par_ville ep
   ORDER BY (p_pays || '_' || ep.ville || '_' || ep.building_id = p_livraison) DESC,
            (ep.ville = (SELECT current_city FROM public.personnages_donnees WHERE name = p_nom)) DESC,
            (ep.ville = 'capitale') DESC, ep.ville
   LIMIT 1;
$f$;
REVOKE ALL ON FUNCTION public.trading_livraison_entrepot_interne(text, text, text) FROM PUBLIC, anon, authenticated;

-- 2. Courrier de livraison. La passe de minuit (23 h UTC) constate l'arrivée : la caisse est
--    retirable à partir du premier passage qui suit l'heure prévue.
CREATE OR REPLACE FUNCTION public.trading_livraison_courrier_interne(p_dest text, p_ville text, p_prevue timestamptz, p_objet text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $f$
DECLARE v_passe timestamp; v_nom text;
BEGIN
  v_passe := date_trunc('day', p_prevue AT TIME ZONE 'UTC') + interval '23 hours';
  IF v_passe < (p_prevue AT TIME ZONE 'UTC') THEN v_passe := v_passe + interval '1 day'; END IF;
  v_nom := CASE p_ville WHEN 'capitale' THEN 'Luthécia' WHEN 'ville_a' THEN 'Port-Sainte-Marie'
                        WHEN 'ville_b' THEN 'Montrouge' ELSE p_ville END;
  PERFORM public.mail_systeme_poser_interne('Entrepôt Logistique', p_dest,
    'Livraison en route vers l''entrepôt de ' || v_nom,
    p_objet || ' Une caisse vous est livrée par voie terrestre à l''Entrepôt Logistique de ' || v_nom ||
    '. Elle sera disponible à partir du ' ||
    to_char((v_passe AT TIME ZONE 'UTC') AT TIME ZONE 'Europe/Paris', 'DD/MM à HH24') ||
    ' h : rendez-vous à la Salle des ventes de l''entrepôt, ordre « Réceptionner une caisse ».');
EXCEPTION WHEN others THEN
  RAISE WARNING 'courrier_livraison_indisponible: %', SQLSTATE;
END $f$;
REVOKE ALL ON FUNCTION public.trading_livraison_courrier_interne(text, text, timestamptz, text) FROM PUBLIC, anon, authenticated;

-- 3. trading_acheter : nouveau paramètre p_livraison (facultatif), destination terrestre.
DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.trading_acheter(text,text,text,integer)'::regprocedure);
  v_new := replace(v_def, 'p_quantite integer)', 'p_quantite integer, p_livraison text DEFAULT NULL::text)');
  v_new := replace(v_new, 'v_caisse uuid; v_objet jsonb;', 'v_caisse uuid; v_objet jsonb; v_dest record; v_prevue timestamptz;');
  v_new := replace(v_new,
$a$  INSERT INTO public.caisses_fret (leader, pays_origine, ville_origine, building_origine, destinataire, pays_destination,
      ville_destination, building_destination, statut, declaration_douaniere, valeur_declaree, receptionnaires_autorises,
      dedouanee, date_dedouanement, date_fermeture, date_depart, date_arrivee_prevue)
  VALUES (v_moi, m.country, v_ville, v_bat, v_moi, m.country, 'ville_a', 'port-sainte-marie', 'en_transit',
      'Matières premières — achat de trading (' || v_org.nom || ')', v_total, ARRAY[v_moi],
      true, now(), now(), now(), now() + interval '1 day')
  RETURNING id INTO v_caisse;$a$,
$n$  -- Livraison terrestre nationale (décision de Fred, 04/11/2026) : entrepôt de la ville choisie.
  SELECT * INTO v_dest FROM public.trading_livraison_entrepot_interne(m.country, p_livraison, v_moi);
  v_prevue := now() + interval '1 day';
  INSERT INTO public.caisses_fret (leader, pays_origine, ville_origine, building_origine, destinataire, pays_destination,
      ville_destination, building_destination, statut, declaration_douaniere, valeur_declaree, receptionnaires_autorises,
      dedouanee, date_dedouanement, date_fermeture, date_depart, date_arrivee_prevue)
  VALUES (v_moi, m.country, v_ville, v_bat, v_moi, m.country, v_dest.ville, v_dest.building_id, 'en_transit',
      'Matières premières — achat de trading (' || v_org.nom || ')', v_total, ARRAY[v_moi],
      true, now(), now(), now(), v_prevue)
  RETURNING id INTO v_caisse;
  PERFORM public.trading_livraison_courrier_interne(v_moi, v_dest.ville, v_prevue,
    'Achat de trading : ' || p_quantite || ' × ' || p_ressource || ' pour ' || v_org.nom || '.');$n$);
  v_new := replace(v_new, $a$'pa', m.pa - 1, 'arrivee', 'port-sainte-marie');$a$,
    $n$'pa', m.pa - 1, 'arrivee', v_dest.building_id, 'ville_livraison', v_dest.ville, 'disponible_apres', v_prevue);$n$);
  IF v_new = v_def OR position('v_dest.building_id' in v_new) = 0 OR position('''ville_livraison''' in v_new) = 0
     OR position('p_livraison text DEFAULT' in v_new) = 0 THEN
    RAISE EXCEPTION 'patch trading_acheter non applique : un fragment ne correspond pas';
  END IF;
  DROP FUNCTION public.trading_acheter(text, text, text, integer);
  EXECUTE v_new;
END $mig$;
REVOKE ALL ON FUNCTION public.trading_acheter(text, text, text, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.trading_acheter(text, text, text, integer, text) TO authenticated, service_role;

-- 4. Offre d'achat servie à un PJ : même livraison terrestre, à l'entrepôt de la ville où se
--    trouve l'auteur de l'offre.
DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.offre_achat_servir(uuid,integer,text,text,text)'::regprocedure);
  v_new := replace(v_def,
$a$    SELECT v_moi, o.pays, pd.current_city, pd.current_building, o.auteur, o.pays, 'ville_a', 'port-sainte-marie', 'en_transit',
        'Matières premières — offre d''achat servie par ' || v_vendeur, v_montant, ARRAY[o.auteur],
        true, now(), now(), now(), now() + interval '1 day'
      FROM public.personnages_donnees pd WHERE pd.name = v_moi
    RETURNING id INTO v_caisse;$a$,
$n$    SELECT v_moi, o.pays, pd.current_city, pd.current_building, o.auteur, o.pays, d.ville, d.building_id, 'en_transit',
        'Matières premières — offre d''achat servie par ' || v_vendeur, v_montant, ARRAY[o.auteur],
        true, now(), now(), now(), now() + interval '1 day'
      FROM public.personnages_donnees pd,
           public.trading_livraison_entrepot_interne(o.pays, NULL, o.auteur) d
     WHERE pd.name = v_moi
    RETURNING id INTO v_caisse;
    -- Livraison terrestre nationale (décision de Fred, 04/11/2026) : courrier à l'auteur de l'offre.
    PERFORM public.trading_livraison_courrier_interne(o.auteur, c.ville_destination, c.date_arrivee_prevue,
        'Votre offre d''achat a été servie : ' || q || ' × ' || o.ressource || ' par ' || v_vendeur || '.')
       FROM public.caisses_fret c WHERE c.id = v_caisse;$n$);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch offre_achat_servir non applique : le fragment ne correspond pas'; END IF;
  EXECUTE v_new;
END $mig$;

-- 5. Retrait : à l'entrepôt logistique, la caisse se retire à la Salle des ventes ; au port,
--    toujours dans la pièce « entrepot ».
DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.fret_objet_agir(uuid,uuid,text,uuid,integer,integer,bigint)'::regprocedure);
  v_new := replace(v_def,
$a$    (c.pays_destination,c.ville_destination,c.building_destination,'entrepot') THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;$a$,
$n$    (c.pays_destination,c.ville_destination,c.building_destination,
     CASE WHEN c.building_destination LIKE 'entrepot-logistique-%' THEN 'salle_ventes' ELSE 'entrepot' END)
    THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;$n$);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch fret_objet_agir non applique : le fragment ne correspond pas'; END IF;
  EXECUTE v_new;
END $mig$;
