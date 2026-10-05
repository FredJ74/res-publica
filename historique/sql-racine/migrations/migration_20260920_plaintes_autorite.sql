-- =============================================================================
-- LES AFFAIRES JUDICIAIRES : AUTORITE, JURIDICTION, ET VERDICT EPINGLE
-- =============================================================================
-- Date d'application en production : 20 septembre 2026.
--
-- CE FICHIER EST UN RATTRAPAGE DE VERSIONNEMENT. Il reproduit l'ETAT FINAL
-- present en production, pas l'historique de la session.
--
-- MIGRATIONS DE PRODUCTION ABSORBEES, DANS L'ORDRE CHRONOLOGIQUE :
--   20260920123804  plaintes_autorite_et_juridiction
--       cree affaire_autorite_de(text) et affaire_me_concerne(text) ; remplace
--       les politiques plaintes_insertion_affaires / plaintes_maj_affaires ;
--       cree jugements_insertion_juge sur public.jugements.
--   20260920123900  plaintes_champs_judiciaires_epingles
--       cree plaintes_epingler_verdict() et pose le trigger
--       trg_plaintes_epingler_verdict sur public.plaintes_en_cours.
--
-- L'ORDRE EST STRUCTURANT : plaintes_epingler_verdict() appelle
-- affaire_autorite_de(), definie dans la section 1. Ne pas reordonner.
--
-- SUR LE DROP POLICY DE LA SECTION 1. La migration 123804 fait bien
-- DROP POLICY IF EXISTS puis CREATE POLICY sur les deux memes noms
-- (plaintes_insertion_affaires, plaintes_maj_affaires) -- mais le DROP vise les
-- politiques HOMONYMES POSEES PAR UN LOT ANTERIEUR, pas une reecriture interne :
-- il n'y a qu'UN SEUL CREATE par nom dans cette migration. Les definitions
-- ci-dessous ont ete relues dans pg_policies (cmd / roles / qual / with_check)
-- et correspondent a ce que la production porte aujourd'hui.
--
-- DEPENDANCES A REJOUER AVANT CE FICHIER
-- -----------------------------------------------------------------------------
--   * migration_justice_fermeture.sql -- c'est le lot judiciaire de reference :
--     il documente `jugements` (colonne data, justice_condamner,
--     justice_executer_condamnation) et la doctrine detentions/QHS sur laquelle
--     ces politiques se posent.
--   * public.plaintes_en_cours et public.jugements existent deja, RLS active,
--     avec leurs politiques de LECTURE publique (plaintes_lecture,
--     jugements_lecture). Ce fichier ne les recree pas et n'y touche pas.
--   * public.mon_personnage() et public.est_appel_serveur() : socle du
--     chantier B, puis 20260919231313 (est_appel_serveur fail closed). Aucun de
--     ces deux socles n'a de fichier dedie dans le depot.
--   * public.personnages_donnees : socle du chantier B.
--
-- CE QUI N'EXISTE PAS DANS CE LOT
-- -----------------------------------------------------------------------------
-- Aucune reparation ponctuelle de donnees : les deux migrations n'ecrivent
-- aucun UPDATE ni DELETE sur des lignes metier.


-- =============================================================================
-- 1. 20260920123804 — QUI PEUT TOUCHER UNE AFFAIRE, ET DANS QUELLE VILLE
-- =============================================================================
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


-- =============================================================================
-- 2. 20260920123900 — L'ACCUSE PEUT SE DEFENDRE, PAS SE JUGER
-- =============================================================================
-- §6.3 — L'ACCUSE PEUT SE DEFENDRE, PAS SE JUGER
-- ---------------------------------------------------------------------------
-- La politique posee juste avant ouvre la ligne de l'affaire a l'accuse : il en
-- a besoin pour ecrire sa defense (doDefense). Mais une politique RLS raisonne
-- par LIGNE, pas par champ : elle lui ouvrait donc aussi `status` et
-- `sentence`. Le banc l'a montre immediatement -- l'accuse pouvait ecrire
-- « status: jugee, sentence: relaxe » sur sa propre affaire. Refermer un exploit
-- en en ouvrant un plus etroit n'est pas le refermer.
--
-- Le bon outil n'est pas une politique mais un TRIGGER, exactement la doctrine
-- deja employee sur la fiche du personnage (personnages_vue_modifier) : on ne
-- REFUSE pas l'ecriture, on EPINGLE les champs que l'auteur n'a pas le droit de
-- changer. La defense passe, le verdict ne bouge pas.
--
-- Qui peut toucher au verdict : l'autorite judiciaire de la ville de l'affaire,
-- et le serveur. Personne d'autre -- pas meme le plaignant.

CREATE OR REPLACE FUNCTION public.plaintes_epingler_verdict()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_old jsonb; v_new jsonb; v_cle text;
  -- Champs qui disent l'issue judiciaire. Tout le reste (defense, pieces,
  -- circonstances) reste librement modifiable par les parties.
  v_verdict constant text[] := ARRAY['status','sentence','peine','jugement','juge',
                                     'circonstanceAttenuante','aggravation'];
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  IF public.affaire_autorite_de(NEW.city) THEN RETURN NEW; END IF;

  -- L'auteur n'est pas l'autorite judiciaire : on restaure les champs de verdict
  -- tels qu'ils etaient. Si l'un d'eux est illisible, on ne prend aucun risque.
  IF OLD.data IS NULL OR left(btrim(OLD.data), 1) <> '{'
     OR NEW.data IS NULL OR left(btrim(NEW.data), 1) <> '{' THEN
    RETURN NEW;
  END IF;

  BEGIN
    v_old := OLD.data::jsonb;
    v_new := NEW.data::jsonb;
  EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
  END;

  FOREACH v_cle IN ARRAY v_verdict LOOP
    IF (v_new -> v_cle) IS DISTINCT FROM (v_old -> v_cle) THEN
      IF (v_old ? v_cle) THEN
        v_new := jsonb_set(v_new, ARRAY[v_cle], v_old -> v_cle);
      ELSE
        v_new := v_new - v_cle;   -- le champ n'existait pas : il n'apparait pas
      END IF;
    END IF;
  END LOOP;

  NEW.data := v_new::text;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_plaintes_epingler_verdict ON public.plaintes_en_cours;
CREATE TRIGGER trg_plaintes_epingler_verdict
  BEFORE UPDATE ON public.plaintes_en_cours
  FOR EACH ROW EXECUTE FUNCTION public.plaintes_epingler_verdict();
