-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913122656
-- Nom original      : chantier_b_liaison_proprietaire_personnage
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 12:26:56 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 8a96baa1b01b723611a2796ed2ef0d5f
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- ============================================================================
-- CHANTIER B — LIAISON AUTOMATIQUE DU PERSONNAGE A SON COMPTE
-- 14 septembre 2026. Option C retenue : compte anonyme automatique, puis
-- securisation facultative. Le lien doit donc se faire SANS que le joueur
-- fasse quoi que ce soit, et sans que le client puisse le choisir.
-- ============================================================================

-- 1) A la creation : le personnage appartient au compte qui l'a cree. Pose par
--    la base, jamais par le client -- un payload qui pretendrait fixer user_id
--    lui-meme serait ignore. auth.uid() est NULL pour service_role (cron,
--    endpoints /api/*) : leurs insertions restent possibles et non rattachees.
CREATE OR REPLACE FUNCTION public.personnages_lier_proprietaire()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- L'autorite est auth.uid(), jamais NEW.user_id fourni par l'appelant.
    IF auth.uid() IS NOT NULL THEN
      NEW.user_id := auth.uid();
    ELSE
      NEW.user_id := NULL;
    END IF;
    RETURN NEW;
  END IF;

  -- 2) A la mise a jour : user_id est IMMUABLE cote client. Seul le serveur
  --    (service_role) peut le changer -- transfert de personnage, reparation.
  --    Sans ca, un joueur pourrait s'attribuer le personnage d'un autre d'un
  --    simple PATCH, ce qui reduirait a neant tout le reste du chantier.
  IF NEW.user_id IS DISTINCT FROM OLD.user_id AND NOT public.est_appel_serveur() THEN
    NEW.user_id := OLD.user_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_personnages_lier_proprietaire ON public.personnages;
CREATE TRIGGER trg_personnages_lier_proprietaire
  BEFORE INSERT OR UPDATE ON public.personnages
  FOR EACH ROW EXECUTE FUNCTION public.personnages_lier_proprietaire();

-- 3) RATTACHEMENT DES PERSONNAGES ANTERIEURS A L'AUTHENTIFICATION.
--    FENETRE TRANSITOIRE, A FERMER A LA REINITIALISATION DE LA BETA.
--    Un personnage cree avant l'authentification n'a pas de proprietaire : rien
--    en base ne peut prouver a qui il appartient. Cette RPC permet a un compte
--    d'en revendiquer un, sous trois garde-fous : le personnage doit etre
--    libre, le compte ne doit pas deja posseder un personnage, et l'operation
--    est definitive. C'est volontairement une PERMISSION DE PREMIER ARRIVE :
--    elle n'est acceptable que parce que la bete sera reinitialisee, et elle
--    doit etre revoquee ce jour-la (voir le rapport de bascule).
CREATE OR REPLACE FUNCTION public.rattacher_personnage(p_nom text)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_uid uuid; v_deja text; v_libre boolean;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'non_authentifie');
  END IF;

  SELECT name INTO v_deja FROM public.personnages WHERE user_id = v_uid LIMIT 1;
  IF v_deja IS NOT NULL THEN
    RETURN jsonb_build_object('ok', v_deja = p_nom, 'raison',
      CASE WHEN v_deja = p_nom THEN 'deja_rattache' ELSE 'compte_deja_pourvu' END,
      'personnage', v_deja);
  END IF;

  SELECT (user_id IS NULL) INTO v_libre FROM public.personnages WHERE name = p_nom FOR UPDATE;
  IF v_libre IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;
  IF NOT v_libre THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_deja_possede');
  END IF;

  UPDATE public.personnages SET user_id = v_uid WHERE name = p_nom;
  RETURN jsonb_build_object('ok', true, 'raison', 'rattache', 'personnage', p_nom);
END;
$$;

REVOKE ALL ON FUNCTION public.rattacher_personnage(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rattacher_personnage(text) TO authenticated;

COMMENT ON FUNCTION public.rattacher_personnage(text) IS
  'TRANSITOIRE : rattache un personnage sans proprietaire au compte connecte. A REVOQUER lors de la reinitialisation de la beta.';