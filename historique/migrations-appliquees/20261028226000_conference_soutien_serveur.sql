-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261028214335.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 28/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261028214335.
-- Eprouvee au role authenticated en transaction annulee : 3 voix et 2 PA, deuxieme conference du
-- jour refusee, candidat inconnu refuse, candidat deja soutenu refuse.
-- ============================================================================
-- CONFERENCE DE SOUTIEN A UN CANDIDAT : PAR LE SERVEUR (28 octobre 2026, Claude)
-- ============================================================================
-- « Donner une conference » (amphi de l'universite, 2 PA) convertit 3 electeurs PNJ pour un
-- candidat. Les voix etaient ecrites par elections_voix_pnj_enregistrer, canal « conference »,
-- avec une cle choisie par l'ecran : un joueur pouvait donc s'ajouter autant de voix qu'il voulait,
-- sans PA ni conference. Les limites (une conference par jour, un seul soutien par candidat)
-- n'existaient qu'a l'ecran.
-- conference_soutenir fait tout dans une transaction, avec les memes regles : lieu, 2 PA, une
-- conference par jour (heure de Paris), un seul soutien par candidat et par scrutin, 3 voix.
-- Le canal « conference » sera reserve au serveur apres la livraison (20261028210900).
-- Idempotente. Aucun acte de joueur.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.conferences_jours (
  acteur text NOT NULL, jour date NOT NULL, PRIMARY KEY (acteur, jour)
);
ALTER TABLE public.conferences_jours ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.conferences_jours FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.conference_soutenir(p_cycle text, p_candidat text, p_pa integer, p_cost integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.personnages_donnees; v_cycle text; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_paie jsonb; r jsonb; v_d jsonb; v_conv integer := 0; v_base text := replace(gen_random_uuid()::text, '-', '');
BEGIN
  SELECT * INTO a FROM public.personnages_donnees WHERE name = public.mon_personnage() FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF a.current_building IS DISTINCT FROM 'universite' OR a.current_room IS DISTINCT FROM 'amphi' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF coalesce(btrim(p_cycle), '') = '' OR coalesce(btrim(p_candidat), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  v_cycle := a.country || '_' || p_cycle;
  SELECT data::jsonb INTO v_d FROM public.cycles_electoraux WHERE id = v_cycle;
  IF v_d IS NULL OR jsonb_typeof(v_d) <> 'object' THEN RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_introuvable'); END IF;
  -- Memes conditions que l'enregistrement d'une voix, verifiees AVANT tout prelevement.
  IF coalesce((v_d ->> 'resultatsTraites')::boolean, false) OR jsonb_typeof(v_d -> 'dateResultats') <> 'number'
     OR floor(extract(epoch FROM now()) * 1000) >= (v_d ->> 'dateResultats')::numeric OR jsonb_typeof(v_d -> 'dateVote') <> 'number' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_clos'); END IF;
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_d -> 'candidats', '[]'::jsonb)) c WHERE c ->> 'nom' = p_candidat) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidat_hors_scrutin'); END IF;
  IF EXISTS (SELECT 1 FROM public.conferences_jours WHERE acteur = a.name AND jour = v_jour) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_fait_aujourdhui'); END IF;
  IF EXISTS (SELECT 1 FROM public.elections_tracts_pnj WHERE cycle_id = v_cycle AND canal = 'conference' AND candidat = p_candidat) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_soutenu'); END IF;
  v_paie := public.payer_ordre(a.name, 'donner_conf', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  INSERT INTO public.conferences_jours VALUES (a.name, v_jour);
  PERFORM set_config('rp.conference_interne', 'on', true);
  FOR i IN 0..2 LOOP
    r := public.elections_voix_pnj_enregistrer('conf-' || v_base || '-' || i, a.name, v_cycle, p_candidat,
           'Un auditeur de la conférence', 'conference', 'conference:' || a.name || ':' || p_candidat || ':' || i);
    IF coalesce((r ->> 'ok')::boolean, false) THEN v_conv := v_conv + 1; END IF;
  END LOOP;
  PERFORM set_config('rp.conference_interne', '', true);
  RETURN jsonb_build_object('ok', true, 'convertis', v_conv, 'tour', r -> 'tour') || jsonb_build_object('paie', v_paie);
END; $function$;
REVOKE ALL ON FUNCTION public.conference_soutenir(text, text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.conference_soutenir(text, text, integer, integer) TO authenticated;
