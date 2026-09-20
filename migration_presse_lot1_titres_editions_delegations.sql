-- ===========================================================================
-- PRESSE — LOT 1 : TITRES, EDITIONS RATTACHEES, DELEGATIONS (20 septembre 2026)
--
-- Applique en production sous le nom presse_lot1_titres_editions_delegations.
-- Ce fichier est le reflet fidele de ce qui tourne : chaque corps de fonction
-- a ete compare a la base par empreinte avant commit.
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

-- ===========================================================================
-- CORRECTIF DU MEME LOT (applique sous le nom
-- presse_lot1_quatre_titres_et_purge_delegations) :
--   1. les quatre titres historiques, et la fin du regime transitoire ;
--   2. la purge automatique des delegations devenues invalides.
-- ===========================================================================

-- --------------------------------------------------------------------------
-- LE NOM D'UN GROUPE DEVIENT FACULTATIF.
--
-- « La Tribune de Republia » est le SEUL nom de groupe de presse attesté dans
-- le depot (plateau-communication.js:2141, :2283, :2500 ; api/journal-interview
-- .js:160). Les trois autres empires ne possedent qu'un nom de TITRE. Plutot
-- que d'inventer trois noms de groupe, la colonne devient nullable : un groupe
-- peut exister sans nom jusqu'a son bapteme. Aucune invention, et le
-- durcissement de journal_id reste possible.
-- --------------------------------------------------------------------------
ALTER TABLE public.groupes_presse ALTER COLUMN nom DROP NOT NULL;

-- --------------------------------------------------------------------------
-- LES TROIS GROUPES HISTORIQUES MANQUANTS, SANS NOM ET SANS MEMBRE.
-- Aucun PJ, aucun directeur, aucun PNJ promu membre attesté.
-- --------------------------------------------------------------------------
INSERT INTO public.groupes_presse (id, pays, nom) VALUES
 ('narco_groupe-presse-historique',   'narco',   NULL),
 ('soviet_groupe-presse-historique',  'soviet',  NULL),
 ('khalija_groupe-presse-historique', 'khalija', NULL)
ON CONFLICT (id) DO NOTHING;

-- --------------------------------------------------------------------------
-- LES TROIS TITRES HISTORIQUES. Noms valides par le game design, tous
-- garantis automatiques comme L'Autruche Entravee.
-- --------------------------------------------------------------------------
INSERT INTO public.journaux (id, groupe_id, pays, nom, slug, garanti_automatique) VALUES
 ('narco_el-narco-times',   'narco_groupe-presse-historique',   'narco',
  'El Narco Times',   'el-narco-times',  true),
 ('soviet_la-pravdovka',    'soviet_groupe-presse-historique',  'soviet',
  'La Pravdovka',     'la-pravdovka',    true),
 ('khalija_le-minaret-dore','khalija_groupe-presse-historique', 'khalija',
  'Le Minaret Doré',  'le-minaret-dore', true)
ON CONFLICT (id) DO NOTHING;

-- --------------------------------------------------------------------------
-- RATTACHEMENT DE TOUTES LES EDITIONS ORPHELINES, contenu inchange.
-- --------------------------------------------------------------------------
UPDATE public.journal_editions e
   SET journal_id = j.id
  FROM public.journaux j
 WHERE e.journal_id IS NULL
   AND j.pays = e.country
   AND j.garanti_automatique;

-- --------------------------------------------------------------------------
-- DURCISSEMENT. Le regime transitoire disparait : plus aucune edition ne peut
-- exister sans titre, et l'unicite porte desormais sur le couple (titre, date)
-- et lui seul. Plusieurs titres d'un meme pays peuvent donc publier le meme
-- jour, ce que l'ancienne regle par pays interdisait structurellement.
-- --------------------------------------------------------------------------
ALTER TABLE public.journal_editions ALTER COLUMN journal_id SET NOT NULL;

DROP INDEX IF EXISTS public.journal_editions_pays_date_sans_titre;
DROP INDEX IF EXISTS public.journal_editions_titre_date_unique;

ALTER TABLE public.journal_editions
  DROP CONSTRAINT IF EXISTS journal_editions_journal_date_unique;
ALTER TABLE public.journal_editions
  ADD CONSTRAINT journal_editions_journal_date_unique UNIQUE (journal_id, date_edition);

-- ===========================================================================
-- PURGE DES DELEGATIONS DEVENUES INVALIDES
--
-- Une delegation confere un pouvoir reel sur un titre : elle ne survit pas a
-- la perte du grade qui permet de l'exercer. La regle est portee par un
-- trigger sur presse_membres, et non par un appelant : aucun chemin futur de
-- changement de grade -- promotion, retrogradation, passation, depart -- ne
-- peut laisser subsister un pouvoir editorial invalide.
--
-- Grades autorises a detenir une delegation : redacteur_chef, et directeur
-- lorsqu'elle lui a ete explicitement accordee. Journaliste et correspondant
-- ne le sont pas.
--
-- Le DELETE est couvert lui aussi : quitter le groupe, ou en etre retire,
-- retire les delegations sur les titres de ce groupe -- un non-membre ne peut
-- pas garder un pouvoir editorial que la RPC d'attribution lui refuserait.
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.presse_delegations_purger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.grade IN ('redacteur_chef','directeur') THEN
    RETURN NULL;
  END IF;

  DELETE FROM public.journaux_redacteurs r
   USING public.journaux j
   WHERE r.journal_id = j.id
     AND j.groupe_id  = OLD.groupe_id
     AND r.personnage = OLD.personnage;

  RETURN NULL;
END;
$function$;

DROP TRIGGER IF EXISTS trg_presse_delegations_purger_grade ON public.presse_membres;
CREATE TRIGGER trg_presse_delegations_purger_grade
  AFTER UPDATE OF grade ON public.presse_membres
  FOR EACH ROW EXECUTE FUNCTION public.presse_delegations_purger();

DROP TRIGGER IF EXISTS trg_presse_delegations_purger_depart ON public.presse_membres;
CREATE TRIGGER trg_presse_delegations_purger_depart
  AFTER DELETE ON public.presse_membres
  FOR EACH ROW EXECUTE FUNCTION public.presse_delegations_purger();

REVOKE ALL ON FUNCTION public.presse_delegations_purger() FROM PUBLIC, anon, authenticated;

-- ===========================================================================
-- BAPTEME DES TROIS GROUPES HISTORIQUES (applique sous le nom
-- presse_lot1_noms_des_groupes_historiques)
--
-- Arbitrage GD : pour les trois empires dont le depot ne fournissait aucun nom
-- de groupe attesté, le groupe porte le nom de son titre. La colonne nom reste
-- NULLABLE : un groupe fonde par un PJ pourra exister avant d'etre baptise, et
-- rien dans le modele ne depend de sa presence.
-- ===========================================================================
UPDATE public.groupes_presse g
   SET nom = j.nom
  FROM public.journaux j
 WHERE j.groupe_id = g.id
   AND j.garanti_automatique
   AND g.nom IS NULL;
