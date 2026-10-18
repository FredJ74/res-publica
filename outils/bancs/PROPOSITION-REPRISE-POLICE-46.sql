-- Infrastructure de reprise des interceptions policières (non déployée).
-- Cette migration ne modifie pas encore les procédures d'action : ne pas la déployer isolément.
CREATE TABLE IF NOT EXISTS public.police_action_receipts (
  personnage text NOT NULL,
  rencontre text NOT NULL,
  action text NOT NULL CHECK (action IN ('reddition','fuite','combat')),
  round_key integer NOT NULL DEFAULT 0,
  verdict jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (personnage, rencontre, action, round_key),
  CONSTRAINT police_action_receipts_round_valid CHECK (
    (action = 'combat' AND round_key BETWEEN 1 AND 100)
    OR (action <> 'combat' AND round_key = 0)
  )
);
ALTER TABLE public.police_action_receipts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.police_action_receipts FROM PUBLIC, anon, authenticated;
-- Lecture uniquement par RPC authentifié, aucune écriture directe côté client.
CREATE OR REPLACE FUNCTION public.police_reprise_lire(p_rencontre text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $$
DECLARE
  v_nom text;
  v_i public.police_interceptions%ROWTYPE;
  v_rec jsonb;
  v_round integer;
BEGIN
  v_nom := public.mon_personnage();
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie');
  END IF;
  IF p_rencontre IS NOT NULL AND (length(p_rencontre) < 8 OR length(p_rencontre) > 120) THEN
    RETURN jsonb_build_object('ok',false,'raison','rencontre_invalide');
  END IF;
  SELECT * INTO v_i FROM public.police_interceptions
   WHERE personnage=v_nom
     AND (p_rencontre IS NULL OR rencontre=p_rencontre)
   ORDER BY (expires_at > now()) DESC, expires_at DESC LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok',true,'active',false,'rencontre',null,'dernier_verdict',null);
  END IF;
  SELECT r.verdict, r.round_key INTO v_rec,v_round
    FROM public.police_action_receipts r
   WHERE r.personnage=v_nom AND r.rencontre=v_i.rencontre
   ORDER BY r.created_at DESC,r.round_key DESC LIMIT 1;
  RETURN jsonb_build_object('ok',true,'active',v_i.expires_at>now(),
    'rencontre',v_i.rencontre,'country',v_i.country,'city',v_i.city,
    'building',v_i.building,'room',v_i.room,'street',v_i.street,
    'fuite_tentee',v_i.fuite_tentee,'dernier_verdict',v_rec,'dernier_round',v_round);
END;
$$;
REVOKE ALL ON FUNCTION public.police_reprise_lire(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.police_reprise_lire(text) TO authenticated;
-- ETAPE OBLIGATOIRE AVANT DEPLOIEMENT :
-- Faire enregistrer chaque verdict dans cette table dans la même transaction
-- que ses effets (reddition, fuite, combat), et relire le reçu avant les gardes
-- de rencontre expirée/détention ; tests PostgreSQL concurrence + reconnexion.
