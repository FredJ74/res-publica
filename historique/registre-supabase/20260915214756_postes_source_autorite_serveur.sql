-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260915214756
-- Nom original      : postes_source_autorite_serveur
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-15 21:47:56 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : efbd13062550d9615893239037c0d254
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
-- AUTORITE DES POSTES — LA PREUVE CESSE D'ETRE AUTO-DECLAREE (15 septembre 2026).
--
-- LA FAILLE. personnages.poste etait ecrit par le client sur sa propre ligne (policy
-- personnages_maj_soi : un joueur peut ecrire sa ligne). Or dix-sept prerogatives serveur s'en
-- servent comme PREUVE d'autorite : exiger_poste() pour justice_prolonger_peine,
-- presidence_gracier, entreprise_preempter / _acte_preemption / _mouvement_fiscal,
-- fixer_repartition_port ; une lecture directe de poste->>'id' pour batiment_etat_sous_cle_ecrire,
-- entrepot_du_directeur, fixer_prix_entrepot, fixer_prix_vente_directe,
-- fixer_repartition_production, percevoir_salaire_directeur, militaire_retrait,
-- assemblee_peut_deposer ; et acteur_poste_courant() pour les quatre RPC du commissariat.
-- Un joueur pouvait donc s'ecrire « president » et gracier, ou « juge » et allonger une peine.
--
-- LA REPONSE, ET POURQUOI ELLE EST PETITE. On ne migre pas dix-sept fonctions une par une : on
-- ferme le point d'ECRITURE. Un trigger n'accepte plus dans personnages.poste qu'une valeur que
-- le serveur peut ATTESTER. Tous les lecteurs existants redeviennent donc fiables sans etre
-- touches, et le client continue d'afficher le poste comme avant.
--
-- TROIS SOURCES D'ATTESTATION, dont deux existaient deja :
--   * postes ELUS (president, maire, chef_syndicat, depute) -> cycles_electoraux, ecrit par le
--     cron au depouillement et deja ferme en ecriture cliente (policy de lecture seule).
--   * postes MILITAIRES (capitaine, lieutenant) -> compagnies_militaires, la table metier.
--   * postes NOMMES -> postes_attribues, cree ici : c'est le seul registre qui manquait.
--
-- BASCULE SANS RISQUE. Aucun des deux personnages reels ne detient de poste (verifie : poste et
-- poste_depute a NULL pour les deux) et les 17 postes sont tenus par des PNJ. Le registre demarre
-- donc vide, aucun etat douteux n'est a conserver, aucune donnee n'est detruite.

-- ---------------------------------------------------------------------------
-- 1. MIROIR DES REGLES DE NOMINATION. Genere depuis le VRAI data.js par
--    .scratch/generer_postes_nommes.py (JavaScriptCore), jamais saisi a la main : sans lui le
--    serveur ne peut pas verifier QUI a le droit de nommer QUOI.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.postes_nommes_regles (
  poste_id  text PRIMARY KEY,
  label     text NOT NULL,
  nomme_par text,
  scope     text NOT NULL CHECK (scope IN ('pays', 'ville'))
);
CREATE TABLE IF NOT EXISTS public.postes_nommes_regles_empreinte (
  seul boolean PRIMARY KEY DEFAULT true CHECK (seul), empreinte text NOT NULL, pose_le timestamptz DEFAULT now()
);

DELETE FROM public.postes_nommes_regles;
INSERT INTO public.postes_nommes_regles (poste_id, label, nomme_par, scope) VALUES
  ('capitaine_port', 'Commandant du Port', 'min_fin', 'pays'),
  ('chef_douanes', 'Chef des Douanes', 'min_int', 'pays'),
  ('commandant', 'Commandant de la Caserne', 'min_def', 'pays'),
  ('commissaire', 'Commissaire', 'maire', 'ville'),
  ('directeur_entrepot', 'Directeur de l''Entrepôt Logistique', 'maire_adjoint', 'ville'),
  ('directeur_pharma', 'Directeur de l''Usine Pharmaceutique', 'min_fin', 'pays'),
  ('directeur_raffinerie', 'Directeur de la Raffinerie', 'min_fin', 'pays'),
  ('directeur_tabac_alcools', 'Directeur du Pôle Tabac & Alcools', 'min_fin', 'pays'),
  ('juge', 'Juge', 'min_just', 'pays'),
  ('maire_adjoint', 'Maire Adjoint', 'maire', 'ville'),
  ('min_ae', 'Ministre des Affaires Etrangeres', 'pm', 'pays'),
  ('min_def', 'Ministre de la Defense', 'pm', 'pays'),
  ('min_fin', 'Ministre des Finances', 'pm', 'pays'),
  ('min_info', 'Ministre de l''Information', 'pm', 'pays'),
  ('min_int', 'Ministre de l''Interieur', 'pm', 'pays'),
  ('min_just', 'Ministre de la Justice', 'pm', 'pays'),
  ('pm', 'Premier Ministre', 'president', 'pays');
INSERT INTO public.postes_nommes_regles_empreinte (seul, empreinte)
VALUES (true, 'a2993a8bc519ea01')
ON CONFLICT (seul) DO UPDATE SET empreinte = EXCLUDED.empreinte, pose_le = now();

ALTER TABLE public.postes_nommes_regles ENABLE ROW LEVEL SECURITY;
CREATE POLICY postes_regles_lecture ON public.postes_nommes_regles
  FOR SELECT TO anon, authenticated USING (true);
REVOKE INSERT, UPDATE, DELETE ON public.postes_nommes_regles FROM anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. LE REGISTRE DES POSTES NOMMES REELLEMENT ATTRIBUES.
--    Lisible par tous (le jeu affiche les titulaires), ecrit par personne d'autre que les RPC.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.postes_attribues (
  id         text PRIMARY KEY,
  country    text NOT NULL,
  poste_id   text NOT NULL,
  city       text,
  titulaire  text NOT NULL,
  depuis     timestamptz NOT NULL DEFAULT now(),
  source     text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS postes_attribues_titulaire ON public.postes_attribues (titulaire);

ALTER TABLE public.postes_attribues ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS postes_attribues_lecture ON public.postes_attribues;
CREATE POLICY postes_attribues_lecture ON public.postes_attribues
  FOR SELECT TO anon, authenticated USING (true);
REVOKE INSERT, UPDATE, DELETE ON public.postes_attribues FROM anon, authenticated;

-- titulaires_pnj etait SANS RLS : n'importe quel client pouvait se declarer titulaire PNJ d'un
-- poste, ce qui fausse getTitulaireActuel et donc toute la cascade de vacance.
ALTER TABLE public.titulaires_pnj ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS titulaires_pnj_lecture ON public.titulaires_pnj;
CREATE POLICY titulaires_pnj_lecture ON public.titulaires_pnj
  FOR SELECT TO anon, authenticated USING (true);
REVOKE INSERT, UPDATE, DELETE ON public.titulaires_pnj FROM anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. L'ATTESTATION. Un poste porte par une fiche est-il atteste par le serveur ?
--    NULL est toujours accepte : perdre un poste (demission, condamnation, fin de mandat,
--    changement de domicile) ne doit jamais etre bloque.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.poste_est_atteste(p_nom text, p_poste jsonb, p_pays text)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_id text; v_city text; v_cycle text;
BEGIN
  IF p_poste IS NULL OR jsonb_typeof(p_poste) = 'null' THEN RETURN true; END IF;
  IF jsonb_typeof(p_poste) <> 'object' THEN RETURN false; END IF;
  v_id   := p_poste ->> 'id';
  v_city := nullif(p_poste ->> 'city', '');
  IF v_id IS NULL OR v_id = '' THEN RETURN false; END IF;

  -- a) POSTES ELUS : la verite est le depouillement, ecrit par le cron.
  IF v_id IN ('president', 'maire', 'chef_syndicat') THEN
    SELECT c.data INTO v_cycle FROM public.cycles_electoraux c
     WHERE c.country = p_pays AND c.poste_id = v_id
       AND c.city IS NOT DISTINCT FROM v_city
     LIMIT 1;
    IF v_cycle IS NULL OR left(btrim(v_cycle), 1) <> '{' THEN RETURN false; END IF;
    RETURN (v_cycle::jsonb ->> 'eluId') = p_nom;
  END IF;

  IF v_id = 'depute' THEN
    SELECT c.data INTO v_cycle FROM public.cycles_electoraux c
     WHERE c.country = p_pays AND c.poste_id = 'depute'
       AND c.city IS NOT DISTINCT FROM v_city
     LIMIT 1;
    IF v_cycle IS NULL OR left(btrim(v_cycle), 1) <> '{' THEN RETURN false; END IF;
    RETURN (v_cycle::jsonb -> 'elus') ? p_nom;
  END IF;

  -- b) POSTES MILITAIRES : la verite est la compagnie.
  IF v_id = 'capitaine' THEN
    RETURN EXISTS (SELECT 1 FROM public.compagnies_militaires m
                    WHERE m.data ->> 'capitaineNom' = p_nom);
  END IF;
  IF v_id = 'lieutenant' THEN
    RETURN EXISTS (SELECT 1 FROM public.compagnies_militaires m,
                        jsonb_array_elements(coalesce(m.data -> 'sections', '[]'::jsonb)) s
                    WHERE s ->> 'lieutenantNom' = p_nom);
  END IF;

  -- c) TOUT LE RESTE : un poste nomme n'existe que s'il est inscrit au registre. Fail closed --
  --    un identifiant inconnu n'est jamais accepte.
  RETURN EXISTS (SELECT 1 FROM public.postes_attribues a
                  WHERE a.titulaire = p_nom AND a.poste_id = v_id
                    AND a.country = p_pays AND a.city IS NOT DISTINCT FROM v_city);
END;
$$;
REVOKE ALL ON FUNCTION public.poste_est_atteste(text, jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.poste_est_atteste(text, jsonb, text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. LE VERROU. Le client peut afficher un poste, il ne peut plus en constituer la preuve.
--    On PRESERVE la valeur precedente au lieu de lever une exception : le client sauvegarde sa
--    fiche entiere a chaque action, et faire echouer toute la sauvegarde pour un champ refuse
--    casserait le jeu. Meme doctrine que personnages_preserver_judiciaire.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.personnages_attester_poste()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;

  IF TG_OP = 'INSERT' THEN
    IF NOT public.poste_est_atteste(NEW.name, NEW.poste, NEW.country) THEN
      NEW.poste := NULL;
    END IF;
    IF NOT public.poste_est_atteste(NEW.name, NEW.poste_depute, NEW.country) THEN
      NEW.poste_depute := NULL;
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.poste IS DISTINCT FROM OLD.poste
     AND NOT public.poste_est_atteste(NEW.name, NEW.poste, NEW.country) THEN
    NEW.poste := OLD.poste;
  END IF;
  IF NEW.poste_depute IS DISTINCT FROM OLD.poste_depute
     AND NOT public.poste_est_atteste(NEW.name, NEW.poste_depute, NEW.country) THEN
    NEW.poste_depute := OLD.poste_depute;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_personnages_attester_poste ON public.personnages_donnees;
CREATE TRIGGER trg_personnages_attester_poste
  BEFORE INSERT OR UPDATE ON public.personnages_donnees
  FOR EACH ROW EXECUTE FUNCTION public.personnages_attester_poste();