-- Actions réservées aux comptes CONFIRMÉS (décision de Fred du 20/11/2026). On joue librement sans adresse confirmée
-- (migration 20261120210000), mais l'adresse confirmée (auth.users.email_confirmed_at) est exigée pour :
--  • se porter candidat à une élection (toutes, tous empires) : candidature_refus_nationalite_interne, contrôle commun
--    déjà appelé par candidature_deposer et candidature_publier_interne ;
--  • être nommé à un poste : poste_attribuer_interne (acceptation de nomination, candidature spontanée, attribution
--    directe) et ambassade_nommer (chemin à part) ;
--  • créer un parti ou une organisation : organisation_vie_commande, action « fonder » ;
--  • acheter du premium : contrôle commun compte_confirmation_refus_interne(nom, 'premium'), à appeler par le futur achat.
-- Motifs : 'compte_non_confirme' (l'intéressé lui-même : l'écran propose « Renvoyer l'e-mail ») ;
-- 'titulaire_compte_non_confirme' (une autorité nomme quelqu'un qui n'a pas confirmé).
-- Un PNJ (pas de compte) n'est jamais concerné. Idempotente (raccords marqués compte_confirme_actions_v1).
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- Le compte qui porte ce personnage a-t-il confirmé son adresse ? (un personnage sans compte, PNJ compris : oui)
CREATE OR REPLACE FUNCTION public.compte_confirme_interne(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT NOT EXISTS (SELECT 1 FROM public.personnages_donnees d JOIN auth.users u ON u.id = d.user_id
                      WHERE d.name = p_nom AND u.email_confirmed_at IS NULL);
$$;
-- Contrôle commun : NULL si l'action est permise, sinon le refus à rendre tel quel.
CREATE OR REPLACE FUNCTION public.compte_confirmation_refus_interne(p_nom text, p_action text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN public.compte_confirme_interne(p_nom) THEN NULL
    ELSE jsonb_build_object('ok', false, 'action', p_action,
      'raison', CASE WHEN p_nom IS NOT DISTINCT FROM public.mon_personnage() THEN 'compte_non_confirme' ELSE 'titulaire_compte_non_confirme' END)
  END;
$$;
REVOKE ALL ON FUNCTION public.compte_confirme_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.compte_confirmation_refus_interne(text, text) FROM PUBLIC, anon, authenticated;

-- Candidature à une élection
SELECT pg_temp.rp_raccorder('public.candidature_refus_nationalite_interne(text,text,text,text)'::regprocedure,
  $a$IF NOT FOUND THEN RETURN 'personnage_introuvable'; END IF;$a$,
  $b$IF NOT FOUND THEN RETURN 'personnage_introuvable'; END IF;
  IF NOT public.compte_confirme_interne(p_nom) THEN RETURN 'compte_non_confirme'; END IF; /* compte_confirme_actions_v1 */$b$,
  'compte_confirme_actions_v1');
-- Nomination à un poste
SELECT pg_temp.rp_raccorder('public.poste_attribuer_interne(text,text,text,text,text)'::regprocedure,
  $a$  SELECT h.habilitation INTO v_hab FROM public.habilitations_postes h WHERE h.poste_id = p_poste;$a$,
  $b$  IF public.compte_confirmation_refus_interne(p_titulaire, 'nomination') IS NOT NULL THEN /* compte_confirme_actions_v1 */
    RETURN public.compte_confirmation_refus_interne(p_titulaire, 'nomination');
  END IF;
  SELECT h.habilitation INTO v_hab FROM public.habilitations_postes h WHERE h.poste_id = p_poste;$b$,
  'compte_confirme_actions_v1');
SELECT pg_temp.rp_raccorder('public.ambassade_nommer(text,text)'::regprocedure,
  $a$  IF v_data ->> 'ambassadeur' = v_p THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_en_poste'); END IF;$a$,
  $b$  IF v_data ->> 'ambassadeur' = v_p THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_en_poste'); END IF;
  IF public.compte_confirmation_refus_interne(v_p, 'nomination') IS NOT NULL THEN /* compte_confirme_actions_v1 */
    RETURN public.compte_confirmation_refus_interne(v_p, 'nomination'); END IF;$b$,
  'compte_confirme_actions_v1');
-- Fondation d'un parti ou d'une organisation
SELECT pg_temp.rp_raccorder('public.organisation_vie_commande(text,text,text,jsonb)'::regprocedure,
  $a$IF p_action = 'fonder' THEN$a$,
  $b$IF p_action = 'fonder' THEN
    IF public.compte_confirmation_refus_interne(v_moi, 'fonder') IS NOT NULL THEN /* compte_confirme_actions_v1 */
      RETURN public.compte_confirmation_refus_interne(v_moi, 'fonder'); END IF;$b$,
  'compte_confirme_actions_v1');

COMMIT;
