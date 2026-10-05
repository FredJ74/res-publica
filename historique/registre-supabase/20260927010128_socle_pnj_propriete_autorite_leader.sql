-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927010128
-- Nom original      : socle_pnj_propriete_autorite_leader
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 01:01:28 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : a2635f62e5af9e52fd2c1180200461be
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
-- PROPRIETE / AUTORITE / LEADER : TROIS CONCEPTS, TROIS MECANISMES (27 septembre 2026)
--
-- CE QUI ETAIT FAUX. Le socle portait `proprietaire_poste='lieutenant'` pour les 96 soldats, et
-- pnj_administrateur resolvait par pnj_titulaire_du_poste(pays, poste) ... LIMIT 1 SANS ORDER BY.
-- Consequences etablies par l'audit :
--   * avec deux Lieutenants, le « proprietaire » d'un soldat devenait NON DETERMINISTE ;
--   * un Lieutenant arbitraire obtenait l'autorite sur les 96 soldats du pays, RESERVE COMPRISE ;
--   * verifie en base : pnj_peut_commander('Vince Kubrick', <reserviste>) renvoyait TRUE, alors
--     que le modele historique refuse au Lieutenant toute autorite sur la reserve.
-- Le socle avait perdu le lien perimetre <-> autorite que le blob, lui, tient correctement.
--
-- LE MODELE POSE ICI, et ce qu'il refuse de savoir.
--
-- 1) PROPRIETE -- deux formes exclusives, toujours renseignee.
--    personnelle    : proprietaire_pj
--    institutionnelle : proprietaire_institution + proprietaire_perimetre
--    Ces deux dernieres sont des chaines OPAQUES. Le socle ne les interprete JAMAIS : il ne
--    sait pas ce qu'est un « lieutenant », une « section » ni un « commissariat ». Il sait
--    seulement qu'une institution possede, sur un perimetre que le metier a nomme.
--
-- 2) AUTORITE -- resolue par le METIER, jamais devinee par le socle.
--    Une table de registre associe chaque institution au nom d'une fonction de resolution
--    fournie par sa couche metier. pnj_autorite_de() l'appelle dynamiquement. Si l'institution
--    n'est pas enregistree, ou si le resolveur rend NULL, alors L'AUTORITE EST A PERSONNE --
--    et c'est un etat PARFAITEMENT VALIDE, pas une erreur.
--
--    PROPRIETE INSTITUTIONNELLE N'IMPLIQUE PAS AUTORITE HUMAINE. Un poste vacant laisse ses
--    PNJ exister, proprietes de l'institution, sans que personne ne les administre. Aucune
--    fonction generique ne doit alors designer un titulaire arbitraire -- c'est precisement le
--    defaut que corrige cette migration.
--
-- 3) LEADER -- conduite physique UNIQUEMENT.
--    Le leader entraine le groupe dans ses deplacements et peut le denouer. Il n'acquiert
--    JAMAIS de droit patrimonial : ni inventaire, ni argent, ni cession.
--
-- D'OU LA SEPARATION DES DROITS. pnj_peut_commander melangeait administration et conduite ; elle
-- est SUPPRIMEE et remplacee par deux predicats qui ne se recouvrent pas :
--    pnj_peut_administrer -> patrimoine et propriete   (proprietaire ou detenteur de l'autorite)
--    pnj_peut_conduire    -> mouvement et groupe       (les precedents, OU le leader courant)

-- ---------------------------------------------------------------------------------------
-- LE REGISTRE DES INSTITUTIONS
-- ---------------------------------------------------------------------------------------
CREATE TABLE public.pnj_institutions (
  institution text PRIMARY KEY,
  resolveur   text NOT NULL,   -- nom d'une fonction (p_pays text, p_perimetre text) -> text
  note        text
);
REVOKE ALL ON public.pnj_institutions FROM PUBLIC, anon, authenticated;

COMMENT ON TABLE public.pnj_institutions IS
  'Registre des institutions proprietaires de PNJ. `resolveur` nomme une fonction metier de '
  'signature (p_pays text, p_perimetre text) RETURNS text qui rend le nom du PJ detenant '
  'actuellement l''autorite sur ce perimetre, ou NULL si personne. Le socle n''interprete ni '
  'l''institution ni le perimetre : il delegue. Une institution absente du registre, ou un '
  'resolveur rendant NULL, signifie « aucune autorite humaine aujourd''hui » -- etat valide.';

-- ---------------------------------------------------------------------------------------
-- LES COLONNES DE PROPRIETE
-- ---------------------------------------------------------------------------------------
ALTER TABLE public.pnj_membres
  ADD COLUMN IF NOT EXISTS proprietaire_institution text,
  ADD COLUMN IF NOT EXISTS proprietaire_perimetre   text;

COMMENT ON COLUMN public.pnj_membres.proprietaire_institution IS
  'Cle OPAQUE de l''institution proprietaire, referencant pnj_institutions. Le socle ne '
  'l''interprete jamais.';
COMMENT ON COLUMN public.pnj_membres.proprietaire_perimetre IS
  'Cle OPAQUE du perimetre au sein de l''institution, nommee par le metier (une section, une '
  'reserve, une ville...). C''est ce qui manquait : sans elle, tout titulaire du poste heritait '
  'de tous les PNJ de l''institution.';

-- Reprise des donnees : les soldats en SECTION appartiennent a leur section ; ceux en RESERVE
-- appartiennent a la reserve de leur compagnie. Le perimetre est nomme par le metier militaire.
UPDATE public.pnj_membres m
   SET proprietaire_institution = 'militaire',
       proprietaire_perimetre = CASE
         WHEN sm.en_reserve THEN regexp_replace(m.id, '-[^-]+-[0-9]+$', '') || ':reserve'
         ELSE sm.section_id END
  FROM public.pnj_soldats_metier sm
 WHERE sm.pnj_id = m.id AND m.famille = 'soldat';

-- Les anciennes colonnes disparaissent : deux sources de verite sur la propriete, jamais.
ALTER TABLE public.pnj_membres DROP CONSTRAINT IF EXISTS pnj_propriete_exclusive;
ALTER TABLE public.pnj_membres DROP COLUMN IF EXISTS proprietaire_poste;
ALTER TABLE public.pnj_membres DROP COLUMN IF EXISTS proprietaire_poste_ville;

-- I7 revisite : exactement une forme de propriete, et l'institutionnelle exige son perimetre.
ALTER TABLE public.pnj_membres ADD CONSTRAINT pnj_propriete_exclusive CHECK (
  (proprietaire_pj IS NOT NULL
     AND proprietaire_institution IS NULL AND proprietaire_perimetre IS NULL)
  OR (proprietaire_pj IS NULL
     AND proprietaire_institution IS NOT NULL AND proprietaire_perimetre IS NOT NULL));

DROP INDEX IF EXISTS idx_pnj_prop_poste;
CREATE INDEX idx_pnj_prop_institution ON public.pnj_membres(
  pays, proprietaire_institution, proprietaire_perimetre)
  WHERE proprietaire_institution IS NOT NULL;

-- ---------------------------------------------------------------------------------------
-- LA RESOLUTION D'AUTORITE : le socle delegue, il ne devine pas.
-- ---------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pnj_autorite_de(p_pnj_id text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE m record; v_res text; v_nom text;
BEGIN
  SELECT proprietaire_pj, proprietaire_institution, proprietaire_perimetre, pays
    INTO m FROM public.pnj_membres WHERE id = p_pnj_id;
  IF NOT FOUND THEN RETURN NULL; END IF;
  -- Propriete personnelle : le proprietaire EST le detenteur de l'autorite.
  IF m.proprietaire_pj IS NOT NULL THEN RETURN m.proprietaire_pj; END IF;
  -- Propriete institutionnelle : on demande au metier. S'il n'y a pas de resolveur, personne.
  SELECT resolveur INTO v_res FROM public.pnj_institutions
   WHERE institution = m.proprietaire_institution;
  IF v_res IS NULL THEN RETURN NULL; END IF;
  EXECUTE format('SELECT %I($1, $2)', v_res) INTO v_nom
    USING m.pays, m.proprietaire_perimetre;
  RETURN v_nom;   -- NULL est une reponse legitime : aucune autorite humaine aujourd'hui.
END; $$;

-- DROIT PATRIMONIAL : inventaire, argent, cession. Le leader n'y a AUCUNE part.
CREATE OR REPLACE FUNCTION public.pnj_peut_administrer(p_moi text, p_pnj_id text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT p_moi IS NOT NULL AND p_moi = public.pnj_autorite_de(p_pnj_id);
$$;

-- DROIT DE CONDUITE : mouvement et composition du groupe. L'administrateur l'a aussi, car il
-- doit pouvoir reprendre son PNJ a un leader.
CREATE OR REPLACE FUNCTION public.pnj_peut_conduire(p_moi text, p_pnj_id text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT p_moi IS NOT NULL AND (
           public.pnj_peut_administrer(p_moi, p_pnj_id)
        OR p_moi = (SELECT leader_pj FROM public.pnj_membres WHERE id = p_pnj_id));
$$;

-- pnj_administrateur devient un simple alias de lecture, conserve pour ne pas casser les
-- appelants ; pnj_peut_commander DISPARAIT, elle melangeait les deux droits.
CREATE OR REPLACE FUNCTION public.pnj_administrateur(p_id text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.pnj_autorite_de(p_id);
$$;
DROP FUNCTION IF EXISTS public.pnj_peut_commander(text, text);

REVOKE ALL ON FUNCTION public.pnj_autorite_de(text)              FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_peut_administrer(text,text)    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_peut_conduire(text,text)       FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_administrateur(text)           FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pnj_autorite_de(text)           TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_peut_administrer(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_peut_conduire(text,text)    TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_administrateur(text)        TO service_role;