-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920120926
-- Nom original      : juges_par_ville_autorite_nationale
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 12:09:26 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : fcc4342f9549f933a10490b6b8753479
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
-- ARBITRAGE GD DU 20 SEPTEMBRE 2026 : UN JUGE PAR TRIBUNAL
-- ---------------------------------------------------------------------------
-- Luthecia, Montrouge et Port-Sainte-Marie ont chacune leur tribunal, donc leur
-- juge. Le MINISTRE DE LA JUSTICE nomme les trois. La fonction reste dans la
-- chaine nationale de la Justice : ce n'est PAS un poste municipal, et le maire
-- n'acquiert aucune autorite sur le juge de sa ville.
--
-- CE QUE LA REGLE EXISTANTE NE SAVAIT PAS EXPRIMER. La colonne `scope` servait
-- a DEUX choses a la fois : ou le poste s'exerce, ET si l'autorite qui nomme est
-- elle-meme territoriale. Pour le commissaire les deux coincident (siege en
-- ville, nomme par le maire DE CETTE VILLE), et poste_autorite_de() exigeait donc
-- que l'autorite porte la meme ville que le poste a pourvoir. Appliquee telle
-- quelle au juge, cette regle aurait rendu la nomination IMPOSSIBLE : le Ministre
-- de la Justice est national, sa fiche ne porte aucune ville, la comparaison
-- aurait toujours echoue. Le poste aurait existe sans que personne ne puisse le
-- pourvoir -- exactement le genre de fenetre qu'il faut eviter.
--
-- On separe donc les deux notions. `autorite_scope` vaut par defaut exactement
-- `scope` : AUCUNE regle existante ne change de comportement. Seul le juge
-- declare un siege en ville et une autorite nationale.

ALTER TABLE public.postes_nommes_regles
  ADD COLUMN IF NOT EXISTS autorite_scope text;

UPDATE public.postes_nommes_regles SET autorite_scope = scope WHERE autorite_scope IS NULL;

UPDATE public.postes_nommes_regles
   SET scope = 'ville', autorite_scope = 'pays'
 WHERE poste_id = 'juge';

DROP FUNCTION IF EXISTS public.poste_autorite_de(text, text);

CREATE FUNCTION public.poste_autorite_de(p_poste text, p_city text)
RETURNS TABLE(nom text, pays text, autorite text, scope text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_nom text; v_pays text; v_poste jsonb; v_regle record;
BEGIN
  SELECT d.name, d.country, d.poste INTO v_nom, v_pays, v_poste
    FROM public.personnages_donnees d WHERE d.user_id = auth.uid() LIMIT 1;
  IF v_nom IS NULL THEN RETURN; END IF;

  SELECT * INTO v_regle FROM public.postes_nommes_regles r WHERE r.poste_id = p_poste;
  IF NOT FOUND OR v_regle.nomme_par IS NULL THEN RETURN; END IF;

  -- Le poste porte par la fiche est deja atteste (trigger) : on peut s'y fier.
  IF (v_poste ->> 'id') IS DISTINCT FROM v_regle.nomme_par THEN RETURN; END IF;

  -- L'AUTORITE est-elle territoriale ? C'est autorite_scope qui le dit, plus
  -- scope : un juge siege en ville mais est nomme par un ministre national.
  IF coalesce(v_regle.autorite_scope, v_regle.scope) = 'ville'
     AND (v_poste ->> 'city') IS DISTINCT FROM p_city THEN
    RETURN;
  END IF;

  RETURN QUERY SELECT v_nom, v_pays, v_regle.nomme_par, v_regle.scope;
END;
$$;
REVOKE ALL ON FUNCTION public.poste_autorite_de(text, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.poste_autorite_de(text, text) TO authenticated, service_role;

-- La caisse payeuse suit le siege : chaque juge est paye par SON tribunal. Le
-- defaut 'capitale' pose au lot precedent (quand le juge etait national) n'a
-- plus lieu d'etre : un juge porte desormais toujours sa ville, et un poste sans
-- ville ne doit pas etre paye par une caisse choisie par defaut.
UPDATE public.salaires_caisses SET ville_defaut = NULL WHERE poste_id = 'juge';