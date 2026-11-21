-- Journal des incidents vus par le client (Fred, 21/11/2026) : filet de sécurité de la première rue.
-- Si la vue de rue reste vide malgré les relances, le client affiche « La ville se charge encore… » + « Réessayer »
-- et enregistre l'incident ici, pour en connaître la fréquence. Types en liste blanche ; au plus un enregistrement
-- par personnage, par type et par minute (un joueur qui insiste sur « Réessayer » ne remplit pas la table).
BEGIN;

CREATE TABLE IF NOT EXISTS public.incidents_client (
  id         bigserial PRIMARY KEY,
  personnage text,
  type       text NOT NULL CHECK (type IN ('rue_vide')),
  detail     jsonb NOT NULL DEFAULT '{}'::jsonb,
  cree_le    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS incidents_client_type_date ON public.incidents_client (type, cree_le DESC);
ALTER TABLE public.incidents_client ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.incidents_client FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.incident_client_noter(p_type text, p_detail jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_type IS DISTINCT FROM 'rue_vide' THEN RETURN jsonb_build_object('ok', false, 'raison', 'type_inconnu'); END IF;
  IF EXISTS (SELECT 1 FROM public.incidents_client WHERE personnage = a AND type = p_type AND cree_le > now() - interval '1 minute') THEN
    RETURN jsonb_build_object('ok', true, 'deja', true);
  END IF;
  INSERT INTO public.incidents_client (personnage, type, detail)
  VALUES (a, p_type, CASE WHEN jsonb_typeof(p_detail) = 'object' AND length(p_detail::text) <= 2000 THEN p_detail ELSE '{}'::jsonb END);
  RETURN jsonb_build_object('ok', true);
END $$;
REVOKE ALL ON FUNCTION public.incident_client_noter(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.incident_client_noter(text, jsonb) TO authenticated;

COMMIT;
