-- SOVARKA : DEMANDE DE LOCATION DEPUIS LE LOCAL (décision de Fred, 06/11/2026, GAME-DESIGN-NOVOMIRSK.md).
-- Dans un local libre d'un centre de Sovarka, le bouton « Demande de location » ouvre une lettre
-- adressée à la mairie qui décrit le bien ; à l'envoi, la demande rejoint la liste du maire
-- (« Dossiers commerciaux »), avec le nom du PJ demandeur et le local souhaité.
-- Même dossier que la demande déposée à la mairie (sovarka_demandes, une demande active par ville),
-- même coût (ordre sovarka_demander_local, 1 PA). Le maire accepte avec la fonction existante
-- sovarka_demande_accepter ; seul le local souhaité est désormais connu.
-- Les quatre locaux des Galeries de Novomirsk prennent les noms donnés par Fred (deux grands, deux moyens).

ALTER TABLE public.sovarka_demandes ADD COLUMN IF NOT EXISTS local_souhaite_batiment text;
ALTER TABLE public.sovarka_demandes ADD COLUMN IF NOT EXISTS local_souhaite_piece text;

UPDATE public.sovarka_locaux l SET label = v.label
  FROM (VALUES ('vitrine_principale','Grand local A'), ('boutique_milieu','Grand local B'),
               ('arriere_boutique','Local moyen A'), ('cave_reserve','Local moyen B')) v(piece, label)
 WHERE l.pays = 'soviet' AND l.ville = 'capitale' AND l.batiment = 'centre-commercial' AND l.piece = v.piece;

CREATE OR REPLACE FUNCTION public.sovarka_demande_location(p_batiment text, p_piece text, p_activite text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); p record; l public.sovarka_locaux; r jsonb; v_id text;
  v_activite text := btrim(coalesce(p_activite,'')); v_projet text;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF length(v_activite) > 200 THEN RETURN jsonb_build_object('ok',false,'raison','projet_invalide'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = moi FOR UPDATE;
  IF p.country IS DISTINCT FROM 'soviet' OR p.current_building IS DISTINCT FROM p_batiment OR p.current_room IS DISTINCT FROM p_piece THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_dans_le_local'); END IF;
  SELECT * INTO l FROM public.sovarka_locaux
   WHERE pays = 'soviet' AND ville = p.current_city AND batiment = p_batiment AND piece = p_piece AND origine <> 'pnj';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','local_introuvable'); END IF;
  IF l.demande_id IS NOT NULL OR public.sovarka_exploitant_interne(l.ville, l.batiment, l.piece) IS NOT NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','local_non_libre'); END IF;
  IF EXISTS (SELECT 1 FROM public.sovarka_demandes WHERE pays='soviet' AND ville=p.current_city AND demandeur=moi
              AND statut IN ('en_attente','acceptee','attribuee')) THEN
    RETURN jsonb_build_object('ok',false,'raison','demande_deja_en_cours'); END IF;
  r := public.payer_ordre(moi, 'sovarka_demander_local', 1, 0);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN RETURN r; END IF;
  v_projet := CASE WHEN length(v_activite) >= 3 THEN v_activite ELSE 'Location du local : '||l.label END;
  v_id := 'sovarka-demande-'||p.current_city||'-'||regexp_replace(moi,'[^a-zA-Z0-9]','','g')||'-'||floor(extract(epoch FROM clock_timestamp())*1000);
  INSERT INTO public.sovarka_demandes (id, ville, demandeur, projet, local_souhaite_batiment, local_souhaite_piece)
  VALUES (v_id, p.current_city, moi, v_projet, l.batiment, l.piece);
  RETURN r || jsonb_build_object('ok',true,'demandeId',v_id,'local',l.label);
END $$;

REVOKE ALL ON FUNCTION public.sovarka_demande_location(text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_demande_location(text,text,text) TO authenticated;

-- Preuves structurelles.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='sovarka_demandes'
                  AND column_name='local_souhaite_piece') THEN RAISE EXCEPTION 'colonne local_souhaite_piece absente'; END IF;
  IF has_function_privilege('anon', 'public.sovarka_demande_location(text,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'sovarka_demande_location ouverte à anon'; END IF;
  IF (SELECT count(*) FROM public.sovarka_locaux WHERE pays='soviet' AND ville='capitale' AND batiment='centre-commercial'
       AND label IN ('Grand local A','Grand local B','Local moyen A','Local moyen B')) <> 4 THEN
    RAISE EXCEPTION 'noms des locaux des Galeries non posés'; END IF;
END $$;
