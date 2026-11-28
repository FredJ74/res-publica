-- Mission du 28/11/2026 (après-midi, Claude), étape 5 — interrupteur du blocage des ordres sans accord juridique.
-- La migration 20261128130000 fait refuser par payer_ordre_interne tout ordre d'un compte qui n'a pas accepté les CGU
-- et la politique de confidentialité en vigueur. Appliquée AVANT la mise en ligne de l'écran (fenêtre d'acceptation,
-- case à la création), elle bloquerait les 485 comptes existants sans rien leur expliquer.
-- D'où un interrupteur : juridique_parametres.blocage_ordres, FAUX à l'application. Tant qu'il est faux, seul le refus
-- « conditions_a_accepter » est suspendu (les suspensions de modération s'appliquent toujours). À allumer une fois la
-- branche claude/textes-juridiques-20261128 fusionnée et déployée :
--   UPDATE public.juridique_parametres SET valeur = true, modifie_le = now() WHERE cle = 'blocage_ordres';
-- Rejouable.
BEGIN;

CREATE TABLE IF NOT EXISTS public.juridique_parametres (
  cle text PRIMARY KEY,
  valeur boolean NOT NULL,
  note text,
  modifie_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.juridique_parametres ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.juridique_parametres FROM anon, authenticated;
INSERT INTO public.juridique_parametres (cle, valeur, note)
VALUES ('blocage_ordres', false, 'Refus des ordres tant que les CGU et la confidentialité en vigueur ne sont pas acceptées. À allumer après le déploiement de l''écran.')
ON CONFLICT (cle) DO NOTHING;

CREATE OR REPLACE FUNCTION public.juridique_ordre_refus_interne(p_nom text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_uid uuid; s public.moderation_sanctions; v_a jsonb;
BEGIN
  IF public.est_appel_serveur() OR public.est_administrateur() THEN RETURN NULL; END IF;
  SELECT d.user_id INTO v_uid FROM public.personnages_donnees d WHERE d.name = p_nom;
  IF v_uid IS NULL OR public.est_compte_test(p_nom) THEN RETURN NULL; END IF;
  SELECT * INTO s FROM public.moderation_sanctions m
   WHERE m.user_id = v_uid AND m.type = 'suspension' AND m.levee_le IS NULL AND m.debut <= now() AND m.fin > now()
   ORDER BY m.fin DESC LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compte_suspendu', 'sanction', public.moderation_sanction_json_interne(s));
  END IF;
  -- juridique_interrupteur_v1 : blocage seulement une fois l'écran en ligne.
  IF NOT coalesce((SELECT p.valeur FROM public.juridique_parametres p WHERE p.cle = 'blocage_ordres'), false) THEN RETURN NULL; END IF;
  v_a := public.juridique_textes_a_accepter_interne(v_uid);
  IF jsonb_array_length(v_a) > 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'conditions_a_accepter', 'textes', v_a);
  END IF;
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION public.juridique_ordre_refus_interne(text) FROM PUBLIC, anon, authenticated;

COMMIT;
