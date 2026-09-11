-- =====================================================================
-- ANCIENS CIRCUITS DE VOIX PNJ : MIGRATION DU STOCKAGE (12 septembre 2026)
-- =====================================================================
-- PROBLEME CORRIGE, ET RIEN D'AUTRE : trois circuits (prospectus du bureau de vote, conference a
-- l'universite, mission Jean-Lou) ecrivaient leur resultat dans cycle.votesPNJ puis reecrivaient
-- LE BLOB ENTIER de cycles_electoraux depuis le client, sans verrou ni relecture. Deux joueurs
-- agissant en meme temps s'ecrasaient mutuellement : des voix disparaissaient silencieusement.
--
-- Ces voix vont desormais dans la meme table atomique que les tracts electoraux
-- (elections_tracts_pnj), ou la contrainte UNIQUE (cycle_id, tour, pnj_cle) rend le double vote
-- impossible et ou le depouillement (client ET cron) les additionne deja.
--
-- AUCUNE REGLE DE JEU N'EST TOUCHEE : couts, probabilites (le prospectus et la conference restent
-- a reussite garantie, Jean-Lou garde son jet client), effets, restrictions de phase et de
-- geographie, textes et conditions restent exactement ceux d'aujourd'hui et restent verifies la ou
-- ils l'etaient (cote client). Cette RPC n'est qu'un registre : elle refuse seulement ce que le
-- blob refusait deja (PNJ ayant deja vote pour ce tour, scrutin inconnu, candidat hors scrutin).
--
-- Effet de bord VOULU et documente : un PNJ deja engage par un tract ne peut plus recevoir un
-- prospectus (et reciproquement). Les deux mecanismes se lisaient auparavant dans deux registres
-- differents et pouvaient donc faire voter deux fois la meme personne.
-- =====================================================================

ALTER TABLE public.elections_tracts_pnj
  ADD COLUMN IF NOT EXISTS canal text NOT NULL DEFAULT 'tract';

COMMENT ON COLUMN public.elections_tracts_pnj.canal IS
  'tract | prospectus | conference | jean_lou -- origine de la voix, pour l''audit uniquement.';

CREATE OR REPLACE FUNCTION public.elections_voix_pnj_enregistrer(
  p_requete  text,
  p_joueur   text,
  p_cycle_id text,
  p_candidat text,
  p_pnj_nom  text,
  p_canal    text,
  p_cle      text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rej  jsonb;
  v_p    record;
  v_c    record;
  v_d    jsonb;
  v_tour bigint;
  v_nom  text;
  v_cle  text;
BEGIN
  IF p_canal NOT IN ('prospectus', 'conference', 'jean_lou') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'canal_invalide');
  END IF;
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_joueur, 'voix_pnj');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF COALESCE(btrim(p_candidat), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'parametres_invalides'));
  END IF;

  SELECT country, current_city INTO v_p FROM public.personnages WHERE name = p_joueur;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'joueur_introuvable'));
  END IF;

  SELECT id, country, data INTO v_c FROM public.cycles_electoraux WHERE id = p_cycle_id;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_introuvable'));
  END IF;
  BEGIN v_d := v_c.data::jsonb; EXCEPTION WHEN OTHERS THEN v_d := NULL; END;
  IF v_d IS NULL OR jsonb_typeof(v_d) <> 'object' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_illisible'));
  END IF;
  IF COALESCE((v_d ->> 'resultatsTraites')::boolean, false) OR COALESCE(v_d ->> 'phase', '') IN ('mandat', 'vacant') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_clos'));
  END IF;
  v_tour := CASE WHEN jsonb_typeof(v_d -> 'dateVote') = 'number' THEN (v_d ->> 'dateVote')::numeric::bigint END;
  IF v_tour IS NULL THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_sans_date'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(COALESCE(v_d -> 'candidats', '[]'::jsonb)) c WHERE c ->> 'nom' = p_candidat) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'candidat_hors_scrutin'));
  END IF;

  -- Cle d'identite : explicite pour les electeurs synthetiques d'une conference, sinon le PNJ reel
  -- normalise exactement comme pour les tracts (pays + ville du joueur + nom).
  IF p_cle IS NOT NULL AND btrim(p_cle) <> '' THEN
    v_cle := btrim(p_cle);
    v_nom := COALESCE(NULLIF(btrim(COALESCE(p_pnj_nom, '')), ''), v_cle);
  ELSE
    v_nom := public.tracts_electoraux_nom_pnj(p_pnj_nom);
    IF v_nom = '' THEN
      RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pnj_invalide'));
    END IF;
    v_cle := COALESCE(v_c.country, v_p.country, '') || ':' || COALESCE(v_p.current_city, '') || ':' || v_nom;
    v_nom := p_pnj_nom;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('voix_pnj|' || p_cycle_id || '|' || v_tour || '|' || v_cle));
  IF EXISTS (SELECT 1 FROM public.elections_tracts_pnj WHERE cycle_id = p_cycle_id AND tour = v_tour AND pnj_cle = v_cle)
     OR (jsonb_typeof(v_d -> 'votesPNJ') = 'object' AND ((v_d -> 'votesPNJ') ? v_nom
         OR (v_d -> 'votesPNJ') ? replace(COALESCE(p_pnj_nom, ''), '''', ''))) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_vote'));
  END IF;

  INSERT INTO public.elections_tracts_pnj (cycle_id, tour, pnj_cle, pnj_nom, candidat, sens, effet, joueur, canal)
  VALUES (p_cycle_id, v_tour, v_cle, v_nom, p_candidat, 1, 1, p_joueur, p_canal);

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'effet', 1, 'tour', v_tour, 'cle', v_cle, 'canal', p_canal));
END;
$$;

REVOKE ALL ON FUNCTION public.elections_voix_pnj_enregistrer(text, text, text, text, text, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.elections_voix_pnj_enregistrer(text, text, text, text, text, text, text) TO anon, authenticated, service_role;
