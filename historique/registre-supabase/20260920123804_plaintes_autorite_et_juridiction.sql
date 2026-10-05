-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920123804
-- Nom original      : plaintes_autorite_et_juridiction
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 12:38:04 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : a794ce6f667077e6b0f727c9aabaed7c
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
-- §6.3 + POINT 11 — QUI PEUT TOUCHER UNE AFFAIRE, ET DANS QUELLE VILLE
-- ---------------------------------------------------------------------------
-- MESURE FAITE SOUS VERITABLE ROLE authenticated, avant toute correction :
--   * un JOUEUR ORDINAIRE pouvait rendre une sentence -- l'affaire finissait
--     « status: jugee, sentence: relaxe », ecrite par quelqu'un qui n'est ni
--     juge, ni commissaire, ni partie au proces ;
--   * le JUGE DE PORT-SAINTE-MARIE pouvait juger une affaire de LUTHECIA :
--     aucune verification de juridiction, nulle part -- ni client, ni serveur.
--     ouvrirRendreSentence() charge d'ailleurs explicitement « TOUTES les
--     affaires transmises, par n'importe quel commissariat ».
--   * l'insertion dans `jugements` etait refusee (42501) : cette table a la RLS
--     active SANS politique d'insertion. Le registre des jugements n'a donc
--     JAMAIS rien enregistre, en silence -- sbCreerJugement est en .catch(() => {}).
--
-- LES QUATRE PRODUCTEURS LEGITIMES, inventories avant d'ecrire quoi que ce soit :
--   transmettreAffaireAuTribunal  -> le commissaire de la ville
--   doDefense                     -> l'ACCUSE lui-meme
--   appliquerSentence             -> le juge de la ville
--   annulerAffaire                -> le juge de la ville
-- Les quatre sont exprimables en politique : on ferme donc par la, plutot que
-- par quatre migrations de flux qui casseraient la production entre-temps.
--
-- LA JURIDICTION EST STRICTEMENT TERRITORIALE (arbitrage GD) : c'est la VILLE
-- PORTEE PAR LE POSTE qui compte, jamais la position physique du personnage.
-- Un juge de PSM present a Luthecia reste juge de PSM.

CREATE OR REPLACE FUNCTION public.affaire_autorite_de(p_city text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees d
     WHERE d.user_id = auth.uid()
       AND (d.poste ->> 'id') IN ('juge', 'commissaire')
       -- Juridiction : la ville du POSTE doit etre celle de l'affaire.
       -- coalesce a 'capitale' pour les affaires anterieures sans ville.
       AND (d.poste ->> 'city') IS NOT DISTINCT FROM coalesce(p_city, 'capitale')
  );
$$;
REVOKE ALL ON FUNCTION public.affaire_autorite_de(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.affaire_autorite_de(text) TO authenticated, service_role;

-- La partie au proces : l'accuse peut ecrire sa defense sur SA propre affaire.
CREATE OR REPLACE FUNCTION public.affaire_me_concerne(p_data text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_moi text; v_json jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL OR p_data IS NULL OR left(btrim(p_data), 1) <> '{' THEN
    RETURN false;
  END IF;
  BEGIN
    v_json := p_data::jsonb;
  EXCEPTION WHEN OTHERS THEN
    RETURN false;   -- data illisible : on n'accorde rien
  END;
  RETURN (v_json ->> 'cible') = v_moi OR (v_json ->> 'plaignant') = v_moi;
END;
$$;
REVOKE ALL ON FUNCTION public.affaire_me_concerne(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.affaire_me_concerne(text) TO authenticated, service_role;

DROP POLICY IF EXISTS plaintes_insertion_affaires ON public.plaintes_en_cours;
DROP POLICY IF EXISTS plaintes_maj_affaires       ON public.plaintes_en_cours;

-- Le garde-fou historique est CONSERVE : une affaire portant 'commissaire_pj'
-- reste hors de portee d'un client, quelle que soit son autorite. On ne fait
-- qu'ajouter la condition d'autorite par-dessus, jamais l'affaiblir.
CREATE POLICY plaintes_insertion_affaires ON public.plaintes_en_cours
  FOR INSERT TO authenticated
  WITH CHECK (
    (data IS NULL OR left(btrim(data), 1) <> '{' OR NOT ((data)::jsonb ? 'commissaire_pj'))
    AND (public.affaire_autorite_de(city) OR public.affaire_me_concerne(data))
  );

CREATE POLICY plaintes_maj_affaires ON public.plaintes_en_cours
  FOR UPDATE TO authenticated
  USING (
    (data IS NULL OR left(btrim(data), 1) <> '{' OR NOT ((data)::jsonb ? 'commissaire_pj'))
    AND (public.affaire_autorite_de(city) OR public.affaire_me_concerne(data))
  )
  WITH CHECK (
    (data IS NULL OR left(btrim(data), 1) <> '{' OR NOT ((data)::jsonb ? 'commissaire_pj'))
    AND (public.affaire_autorite_de(city) OR public.affaire_me_concerne(data))
  );

-- LE REGISTRE DES JUGEMENTS, qui n'enregistrait rien. On lui donne la politique
-- d'insertion qui lui manquait, bornee a l'autorite judiciaire de la ville du
-- jugement -- et a elle seule.
CREATE POLICY jugements_insertion_juge ON public.jugements
  FOR INSERT TO authenticated
  WITH CHECK (public.affaire_autorite_de(city));