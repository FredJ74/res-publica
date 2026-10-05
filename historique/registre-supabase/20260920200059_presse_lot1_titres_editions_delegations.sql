-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920200059
-- Nom original      : presse_lot1_titres_editions_delegations
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 20:00:59 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : b1db1c0e463cdb3eda17a20a26d5480a
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
-- ===========================================================================
-- PRESSE — LOT 1 : TITRES, EDITIONS RATTACHEES, DELEGATIONS (20 septembre 2026)
--
-- Pose le modele attesté permettant plusieurs titres et plusieurs editions le
-- meme jour. Ne construit ni kiosque, ni pages, ni articles, ni tresorerie.
-- ===========================================================================

-- Rend possible la cle etrangere composite (groupe_id, pays) ci-dessous : le
-- pays d'un titre ne pourra jamais diverger de celui de son groupe.
ALTER TABLE public.groupes_presse
  DROP CONSTRAINT IF EXISTS groupes_presse_id_pays_unique;
ALTER TABLE public.groupes_presse
  ADD CONSTRAINT groupes_presse_id_pays_unique UNIQUE (id, pays);

CREATE TABLE IF NOT EXISTS public.journaux (
  id                  text PRIMARY KEY,
  groupe_id           text NOT NULL,
  -- Denormalise pour permettre les index par pays ci-dessous, mais la cle
  -- composite garantit la coherence avec le groupe : impossible de creer un
  -- titre narco dans un groupe republic.
  pays                text NOT NULL,
  nom                 text NOT NULL,
  slug                text NOT NULL,
  -- Reserve au titre historique beneficiant de l'edition quotidienne
  -- automatique. JAMAIS accorde par defaut a un titre cree par un PJ.
  garanti_automatique boolean NOT NULL DEFAULT false,
  cree_le             timestamptz NOT NULL DEFAULT now(),
  cree_par            text REFERENCES public.personnages_donnees(name)
                           ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT journaux_groupe_pays_fk
    FOREIGN KEY (groupe_id, pays) REFERENCES public.groupes_presse(id, pays)
    ON DELETE RESTRICT
);

-- Slug unique PAR PAYS et non globalement : deux empires peuvent porter des
-- titres homonymes sans se gener.
CREATE UNIQUE INDEX IF NOT EXISTS journaux_slug_par_pays
  ON public.journaux (pays, slug);

-- Au plus UN titre garanti par pays : la resolution automatique ci-dessous
-- est donc deterministe, sans arbitrage a l'execution.
CREATE UNIQUE INDEX IF NOT EXISTS journaux_un_garanti_par_pays
  ON public.journaux (pays) WHERE garanti_automatique;

CREATE INDEX IF NOT EXISTS journaux_par_groupe ON public.journaux (groupe_id);

-- --------------------------------------------------------------------------
-- DELEGATIONS EDITORIALES — par TITRE ENTIER, jamais par page.
-- Plusieurs detenteurs simultanes sur un meme titre sont attendus : ils
-- s'organisent humainement.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.journaux_redacteurs (
  journal_id  text NOT NULL REFERENCES public.journaux(id) ON DELETE CASCADE,
  personnage  text NOT NULL REFERENCES public.personnages_donnees(name)
                   ON UPDATE CASCADE ON DELETE CASCADE,
  accorde_le  timestamptz NOT NULL DEFAULT now(),
  accorde_par text,
  PRIMARY KEY (journal_id, personnage)
);

CREATE INDEX IF NOT EXISTS journaux_redacteurs_par_personnage
  ON public.journaux_redacteurs (personnage);

-- --------------------------------------------------------------------------
-- FERMETURE. Lecture publique (l'existence d'un titre et le nom de ses
-- redacteurs sont des faits publics), aucune ecriture directe. Le REVOKE est
-- indispensable : les DEFAULT PRIVILEGES du schema re-accordent tout a anon.
-- --------------------------------------------------------------------------
ALTER TABLE public.journaux             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journaux_redacteurs  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.journaux            FROM anon, authenticated;
REVOKE ALL ON public.journaux_redacteurs FROM anon, authenticated;
GRANT SELECT ON public.journaux            TO anon, authenticated;
GRANT SELECT ON public.journaux_redacteurs TO anon, authenticated;

DROP POLICY IF EXISTS journaux_lecture ON public.journaux;
CREATE POLICY journaux_lecture ON public.journaux
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS journaux_redacteurs_lecture ON public.journaux_redacteurs;
CREATE POLICY journaux_redacteurs_lecture ON public.journaux_redacteurs
  FOR SELECT TO anon, authenticated USING (true);

-- ===========================================================================
-- RATTACHEMENT DES EDITIONS A UN TITRE
-- ===========================================================================
ALTER TABLE public.journal_editions
  ADD COLUMN IF NOT EXISTS journal_id text REFERENCES public.journaux(id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS journal_editions_par_journal
  ON public.journal_editions (journal_id, date_edition);

-- --------------------------------------------------------------------------
-- LE PIPELINE AUTOMATIQUE N'EST PAS MODIFIE : il continue d'inserer une
-- edition avec (country, date_edition) et sans titre. C'est ce trigger qui
-- resout le titre garanti du pays -- le rattachement devient une propriete de
-- la table, pas une responsabilite de l'appelant, et aucun des 13 fichiers en
-- attente n'a eu besoin d'etre touche.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.journal_edition_rattacher_au_titre()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_journal text;
BEGIN
  IF NEW.journal_id IS NOT NULL THEN RETURN NEW; END IF;
  SELECT j.id INTO v_journal
    FROM public.journaux j
   WHERE j.pays = NEW.country AND j.garanti_automatique;
  -- Un pays sans titre garanti garde une edition non rattachee : elle reste
  -- alors soumise a l'ancienne regle (un seul numero par pays et par jour).
  NEW.journal_id := v_journal;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_journal_edition_rattacher ON public.journal_editions;
CREATE TRIGGER trg_journal_edition_rattacher
  BEFORE INSERT ON public.journal_editions
  FOR EACH ROW EXECUTE FUNCTION public.journal_edition_rattacher_au_titre();

-- ===========================================================================
-- LE GROUPE ET LE TITRE HISTORIQUES DE REPUBLIA
--
-- Le groupe est cree SANS AUCUN MEMBRE : aucun PJ historique n'existe, et on
-- ne transforme pas un PNJ en membre attesté pour satisfaire la hierarchie.
-- Le groupe peut vivre sans directeur ; sa reprise par des PJ relevera des
-- mecaniques appropriees.
-- ===========================================================================
INSERT INTO public.groupes_presse (id, pays, nom)
VALUES ('republic_tribune-republia', 'republic', 'La Tribune de Républia')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.journaux (id, groupe_id, pays, nom, slug, garanti_automatique)
VALUES ('republic_autruche-entravee', 'republic_tribune-republia', 'republic',
        'L''Autruche Entravée', 'autruche-entravee', true)
ON CONFLICT (id) DO NOTHING;

-- Rattachement des editions historiques de Republia, contenu inchange.
UPDATE public.journal_editions
   SET journal_id = 'republic_autruche-entravee'
 WHERE country = 'republic' AND journal_id IS NULL;

-- ===========================================================================
-- LA CONTRAINTE D'UNICITE
--
-- L'ancienne regle « un seul numero par pays et par jour » interdisait
-- structurellement deux titres le meme jour. Elle est remplacee par deux
-- index partiels complementaires :
--   - les editions RATTACHEES sont uniques par (titre, date) ;
--   - les editions NON RATTACHEES conservent l'ancienne regle par pays,
--     le temps que les autres empires recoivent leurs titres.
-- Aucune donnee n'est detruite, aucune edition en echec n'est touchee.
-- ===========================================================================
ALTER TABLE public.journal_editions
  DROP CONSTRAINT IF EXISTS journal_editions_country_date_unique;

CREATE UNIQUE INDEX IF NOT EXISTS journal_editions_titre_date_unique
  ON public.journal_editions (journal_id, date_edition) WHERE journal_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS journal_editions_pays_date_sans_titre
  ON public.journal_editions (country, date_edition) WHERE journal_id IS NULL;

-- ===========================================================================
-- CREATION D'UN TITRE — reservee au serveur, comme la fondation d'un groupe :
-- l'ecran et les conditions de jeu appartiennent a un lot ulterieur.
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.presse_journal_creer(
  p_journal_id text, p_groupe_id text, p_nom text, p_slug text,
  p_cree_par text DEFAULT NULL, p_garanti_automatique boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pays text;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;
  IF coalesce(btrim(p_journal_id),'') = '' OR coalesce(btrim(p_groupe_id),'') = ''
     OR coalesce(btrim(p_nom),'') = '' OR coalesce(btrim(p_slug),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  SELECT pays INTO v_pays FROM public.groupes_presse WHERE id = p_groupe_id;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'groupe_introuvable');
  END IF;
  IF EXISTS (SELECT 1 FROM public.journaux WHERE id = p_journal_id) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'journal_deja_existant');
  END IF;

  INSERT INTO public.journaux (id, groupe_id, pays, nom, slug, garanti_automatique, cree_par)
  VALUES (p_journal_id, p_groupe_id, v_pays, p_nom, p_slug,
          coalesce(p_garanti_automatique, false), p_cree_par);

  RETURN jsonb_build_object('ok', true, 'journal', p_journal_id, 'pays', v_pays);
END;
$function$;

-- ===========================================================================
-- DELEGATIONS — HELPER D'AUTORITE
-- L'acteur est relu par mon_personnage(), jamais annonce. Le groupe est
-- deduit du TITRE : un directeur ne peut donc agir que sur ses propres titres.
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.presse_directeur_du_journal(p_journal_id text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN NULL; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.journaux j
      JOIN public.presse_membres m ON m.groupe_id = j.groupe_id
     WHERE j.id = p_journal_id AND m.personnage = v_moi AND m.grade = 'directeur'
  ) THEN RETURN NULL; END IF;
  RETURN v_moi;
END;
$function$;

-- --------------------------------------------------------------------------
-- ACCORDER UNE DELEGATION.
-- Le beneficiaire doit appartenir au groupe du titre et porter un grade
-- eligible : 'redacteur_chef', ou 'directeur' s'il se l'accorde
-- explicitement -- le grade de directeur ne la donne jamais d'office.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.presse_delegation_accorder(p_journal_id text, p_personnage text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_directeur text; v_grade text;
BEGIN
  IF coalesce(btrim(p_journal_id),'') = '' OR coalesce(btrim(p_personnage),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  v_directeur := public.presse_directeur_du_journal(p_journal_id);
  IF v_directeur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_directeur');
  END IF;

  SELECT m.grade INTO v_grade
    FROM public.journaux j
    JOIN public.presse_membres m ON m.groupe_id = j.groupe_id
   WHERE j.id = p_journal_id AND m.personnage = p_personnage;
  IF v_grade IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_membre_du_groupe');
  END IF;
  IF v_grade NOT IN ('redacteur_chef','directeur') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'grade_non_eligible',
                              'grade_actuel', v_grade,
                              'eligibles', jsonb_build_array('redacteur_chef','directeur'));
  END IF;

  INSERT INTO public.journaux_redacteurs (journal_id, personnage, accorde_par)
  VALUES (p_journal_id, p_personnage, v_directeur)
  ON CONFLICT (journal_id, personnage) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'journal', p_journal_id,
                            'personnage', p_personnage, 'grade', v_grade);
END;
$function$;

-- --------------------------------------------------------------------------
-- RETIRER UNE DELEGATION. Directeur du groupe du titre uniquement.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.presse_delegation_retirer(p_journal_id text, p_personnage text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_directeur text; v_retirees int;
BEGIN
  v_directeur := public.presse_directeur_du_journal(p_journal_id);
  IF v_directeur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_directeur');
  END IF;

  DELETE FROM public.journaux_redacteurs
   WHERE journal_id = p_journal_id AND personnage = p_personnage;
  GET DIAGNOSTICS v_retirees = ROW_COUNT;

  IF v_retirees = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delegation_absente');
  END IF;
  RETURN jsonb_build_object('ok', true, 'journal', p_journal_id, 'personnage', p_personnage);
END;
$function$;

-- --------------------------------------------------------------------------
-- DROITS D'EXECUTION.
-- --------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.presse_journal_creer(text,text,text,text,text,boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.journal_edition_rattacher_au_titre()                   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.presse_directeur_du_journal(text)                      FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.presse_delegation_accorder(text,text)                  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.presse_delegation_retirer(text,text)                   FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.presse_delegation_accorder(text,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.presse_delegation_retirer(text,text)  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.presse_journal_creer(text,text,text,text,text,boolean) TO service_role;