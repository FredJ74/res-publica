-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261027183230.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027183230 (lot explique dans 20261027120000).
-- Eprouvee au role authenticated : poison consomme, poison_start depose avec type et statistiques, second essai refuse.
-- Empoisonner par le serveur : crime_empoisonner. Idempotente. Aucun acte de joueur.

-- 2. Empoisonner.
CREATE OR REPLACE FUNCTION public.crime_empoisonner(p_cible text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; c record; v_pos integer; v_type text; v_taux integer; v_roll integer; v_palier text;
  v_stats jsonb; v_repere boolean := false; v_quand text; v_msg text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_cible), '') = '' OR p_cible = v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  SELECT * INTO m FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT name, country, current_city, current_building, current_room INTO c FROM public.personnages_donnees WHERE name = p_cible;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  IF c.country IS DISTINCT FROM m.country OR c.current_city IS DISTINCT FROM m.current_city
     OR c.current_building IS DISTINCT FROM m.current_building OR c.current_room IS DISTINCT FROM m.current_room THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit'); END IF;
  SELECT (o.ord - 1)::integer, o.item ->> 'poisonType' INTO v_pos, v_type
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(m.inventory) = 'array' THEN m.inventory ELSE '[]'::jsonb END) WITH ORDINALITY o(item, ord)
   WHERE o.item ->> 'type' = 'poison' ORDER BY o.ord LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'poison_manquant'); END IF;
  v_type := CASE WHEN v_type IN ('parapluie', 'ghb', 'polonium', 'vipere') THEN v_type ELSE 'parapluie' END;
  UPDATE public.personnages_donnees SET inventory = inventory - v_pos WHERE name = v_moi;

  v_taux := greatest(5, 40 - 5 + CASE m.country WHEN 'narco' THEN 20 WHEN 'soviet' THEN -10 ELSE 0 END
            + CASE WHEN m.career = 'criminal_c' THEN 15 ELSE 0 END - public.crime_malus_isn_interne(m.country, m.current_city));
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll <= v_taux / 2.0 THEN v_palier := 'totale';
  ELSIF v_roll <= v_taux THEN v_palier := 'partielle';
  ELSIF v_roll <= v_taux + (100 - v_taux) / 2.0 THEN v_palier := 'echec_partiel';
  ELSE v_palier := 'echec_total'; END IF;

  IF v_palier <> 'echec_total' THEN
    SELECT jsonb_agg(s) INTO v_stats FROM (SELECT s FROM unnest(ARRAY['INT','CHA','VOL','PER','DUP','ENT']) s ORDER BY random() LIMIT 2) x;
    INSERT INTO public.impacts_indices_attente (id, victime, indice, delta, palier, traite, details)
    VALUES ('poison-' || gen_random_uuid(), p_cible, 'poison_start', 0, v_palier, false,
            jsonb_build_object('poisonType', v_type, 'statsTouchees', v_stats));
    v_quand := to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI');
    v_msg := CASE v_type
      WHEN 'ghb' THEN 'Votre esprit devient confus. Vous avez la tête qui tourne et vos sens sont perturbés. Vous avez l''impression d''avoir été drogué(e), mais par qui ? Vous perdez 2 PA.'
      WHEN 'polonium' THEN 'Vous vous sentez subitement faible. En passant la main dans vos cheveux, ils se décrochent par paquets de votre crâne, comme si vous aviez été mis(e) en contact avec quelque chose de radioactif. Vous perdez 2 PA.'
      WHEN 'vipere' THEN 'Vous ressentez une violente douleur au niveau du mollet. Deux petits trous douloureux et rouges sont visibles. Un serpent vous aurait-il mordu(e) ? Vous perdez 2 PA.'
      ELSE 'Quelque chose vous pique dans le dos. Une douleur irradie dans tout votre corps et s''intensifie d''heure en heure. Était-ce en lien avec cette personne qui vous a touché avec le bout de son parapluie et s''est excusée ? Vous perdez 2 PA.' END;
    PERFORM public.mail_systeme_poser_interne('Événement mystérieux', p_cible, 'Vous vous sentez mal...', v_msg, v_quand);
    PERFORM public.annonce_publique_interne(m.country, 'MYSTÈRE : ' || p_cible || ' se sent soudainement très mal...');
    PERFORM public.crime_tracer_interne(v_moi, 'empoisonnement', p_cible);
    PERFORM public.crime_trace_rumeur_interne(v_moi, 'empoisonnement', p_cible);
    v_repere := public.crime_detecter_interne(v_moi, 'empoisonnement', true);
  ELSE
    PERFORM public.crime_rechercher_interne(v_moi, 'tentative_empoisonnement', 'crime');
    v_repere := true;
  END IF;
  RETURN jsonb_build_object('ok', true, 'palier', v_palier, 'reussi', v_palier IN ('totale', 'partielle'), 'repere', v_repere,
    'taux', v_taux, 'jet', v_roll, 'inventaire', (SELECT inventory FROM public.personnages_donnees WHERE name = v_moi));
END; $function$;

REVOKE ALL ON FUNCTION public.crime_empoisonner(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crime_empoisonner(text) TO authenticated;
