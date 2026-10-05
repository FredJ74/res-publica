-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913132443
-- Nom original      : chantier_b_fermeture_rpc_restantes
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 13:24:43 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 42d56117950a2b82b2e60baf49ac7883
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
-- CHANTIER B — LES CINQ RPC RESTANTES
-- 13 septembre 2026.
-- ============================================================================

-- 1) tracts_appliquer_effet_pop : PLUS AUCUN APPELANT.
--    Son enveloppe cliente sbTractAppliquerEffetPop n'est invoquee nulle part --
--    le circuit reel des tracts calomnieux passe par calomnie_distribuer, qui
--    appelle en interne calomnie_appliquer_effet (deja fermee a anon). Laisser
--    celle-ci ouverte, c'est offrir a n'importe quel navigateur le droit de
--    retirer de la POP a n'importe qui.
REVOKE ALL ON FUNCTION public.tracts_appliquer_effet_pop(text, integer) FROM PUBLIC, anon, authenticated;

-- 2) restituer_reliquats_chantier : appelee UNIQUEMENT par le cron
--    (api/cron-minuit.js:1693), jamais par le jeu. Elle rend des materiaux et
--    de l'argent : aucune raison qu'un joueur puisse la declencher.
REVOKE ALL ON FUNCTION public.restituer_reliquats_chantier(text, text) FROM PUBLIC, anon, authenticated;

-- 3) vendre_fonds_commerce : deja reservee au service_role, et le depot le dit
--    explicitement ("NON APPELABLE AUJOURD'HUI, et c'est voulu", supabase.js).
--    On le reaffirme ici pour que ce soit vrai par construction et non par
--    heritage, et parce que son acteur est reellement ambigu (vendeur ou
--    acheteur ?) : tant que le circuit d'offre/acceptation ne tranche pas, elle
--    reste hors de portee du client.
REVOKE ALL ON FUNCTION public.vendre_fonds_commerce(text, text, text, integer) FROM PUBLIC, anon, authenticated;

-- 4) personnage_ajuster_pop_inf : primitive d'effet SUR AUTRUI, sans acteur.
--    Telle quelle, elle permet a quiconque de modifier la popularite de
--    n'importe qui. On en publie une version qui EXIGE un acteur authentifie,
--    et on ferme l'ancienne au client.
--
--    CE QU'ELLE NE FAIT TOUJOURS PAS, et il faut le dire : verifier que le
--    joueur avait le DROIT de produire cet effet-la sur cette cible-la. Cela
--    supposerait de porter les regles de chaque mecanique (rumeur, evenement
--    PNJ, football) cote serveur -- c'est le chantier C. Ce qui est acquis ici :
--    plus d'effet anonyme, et tout effet est attribuable a un compte reel.
--
--    CORRECTIF AU PASSAGE : l'ancienne version ecrivait sur public.personnages,
--    devenue une VUE au cours de ce chantier. On vise desormais la table reelle,
--    ce qui evite de dependre du declencheur INSTEAD OF et de son RETURNING.
--    Les bornes existantes (delta max 100, POP bornee 0-100, defaut 50) sont
--    reprises a l'identique : aucune regle de jeu n'est changee.
CREATE OR REPLACE FUNCTION public.personnage_ajuster_pop_inf(
  p_acteur text, p_cible text, p_pop integer, p_inf integer DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_res jsonb; v_base jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  IF coalesce(btrim(p_cible), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide');
  END IF;
  IF coalesce(abs(p_pop), 0) > 100 OR coalesce(abs(p_inf), 0) > 100 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delta_invalide');
  END IF;

  SELECT jsonb_set(
           CASE WHEN jsonb_typeof(pp.resources) = 'object' THEN pp.resources ELSE '{}'::jsonb END,
           '{pop}', to_jsonb(greatest(0, least(100,
             coalesce(CASE WHEN jsonb_typeof(pp.resources -> 'pop') = 'number'
                           THEN (pp.resources ->> 'pop')::numeric END, 50)
             + coalesce(p_pop, 0)))))
    INTO v_base
    FROM public.personnages_donnees pp WHERE pp.name = p_cible FOR UPDATE;

  IF v_base IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;

  UPDATE public.personnages_donnees
     SET resources = CASE WHEN p_inf IS NULL THEN v_base
            ELSE jsonb_set(v_base, '{inf}', to_jsonb(greatest(0, least(100,
                   coalesce(CASE WHEN jsonb_typeof(v_base -> 'inf') = 'number'
                                 THEN (v_base ->> 'inf')::numeric END, 0) + p_inf))))
          END
   WHERE name = p_cible
   RETURNING resources INTO v_res;

  RETURN jsonb_build_object('ok', true, 'pop', v_res -> 'pop', 'inf', v_res -> 'inf');
END;
$$;
REVOKE ALL ON FUNCTION public.personnage_ajuster_pop_inf(text, text, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.personnage_ajuster_pop_inf(text, text, integer, integer) TO authenticated;

-- L'ancienne signature sans acteur n'est plus atteignable depuis un navigateur.
REVOKE ALL ON FUNCTION public.personnage_ajuster_pop_inf(text, integer, integer) FROM PUBLIC, anon, authenticated;