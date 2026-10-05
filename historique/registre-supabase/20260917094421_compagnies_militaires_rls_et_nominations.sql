-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917094421
-- Nom original      : compagnies_militaires_rls_et_nominations
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 09:44:21 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 2c8b3013eed86775d39898f041a00a78
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
-- CHAINE MILITAIRE — FERMETURE DE L'ANGLE MORT (17 septembre 2026, passe 3).
-- Hierarchie validee : Ministre de la Defense (min_def) -> Commandant -> Capitaines -> Lieutenants.
--
-- CE QUI EST DEJA JUSTE, ET QU'ON NE TOUCHE PAS :
--   * capitaine et lieutenant ne sont PAS dans postes_nommes_regles, et c'est CORRECT. Le registre
--     generique ne sait porter que des postes scalaires (un id plat, une portee pays/ville) ; il n'a
--     aucune notion d'instance parente. Or un capitaine est attache a UNE compagnie et un lieutenant
--     a UNE section. Les y faire entrer perdrait ce rattachement -- et leur accorderait au passage la
--     protection de 3 jours, que le game design reserve au seul Commandant.
--   * poste_est_atteste traite DEJA capitaine/lieutenant a part, en les lisant directement dans
--     compagnies_militaires (capitaineNom, sections[].lieutenantNom). L'attestation est donc bonne.
--   * commandant est dans le registre generique : il herite correctement de la protection 3 jours.
--
-- L'ANGLE MORT REEL, ET LE SEUL : compagnies_militaires avait la RLS DESACTIVEE. La table que
-- poste_est_atteste traite comme source de verite etait donc en ecriture ouverte a tous. N'importe
-- quel appel REST direct pouvait y ecrire capitaineNom ou lieutenantNom, puis faire attester ce
-- poste par le trigger -- qui constate loyalement que le nom figure bien dans la compagnie. La
-- preuve etait formellement correcte ; la donnee prouvee ne l'etait pas.
-- Toutes les gardes « vous devez etre Commandant/Capitaine » vivaient cote client uniquement.
--
-- CE LOT pose la RLS et ouvre exactement les ecritures que la hierarchie autorise.

ALTER TABLE public.compagnies_militaires ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ecriture publique compagnies" ON public.compagnies_militaires;
DROP POLICY IF EXISTS "Lecture publique compagnies" ON public.compagnies_militaires;
DROP POLICY IF EXISTS "Maj publique compagnies"      ON public.compagnies_militaires;

-- Lecture : ouverte. L'organigramme militaire est une information publique du jeu, et plusieurs
-- ecrans le consultent sans etre dans la chaine de commandement.
CREATE POLICY "compagnies lecture" ON public.compagnies_militaires
  FOR SELECT TO anon, authenticated USING (true);

-- Creation d'une compagnie : le Commandant de CE pays, et lui seul (ordre recruter_compagnie,
-- data.js requiresPost:'commandant'). La regle existait deja cote client ; elle devient reelle.
CREATE POLICY "compagnies creation par le commandant" ON public.compagnies_militaires
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.personnages_donnees p
             WHERE p.user_id = auth.uid()
               AND p.poste->>'id' = 'commandant'
               AND p.country = (data::jsonb)->>'pays')
  );

-- Modification : le Commandant du pays (recrutement de section, reorganisation), OU le Capitaine
-- DE CETTE COMPAGNIE (repartition d'armement, gestion de ses sections). Un capitaine ne peut donc
-- pas toucher la compagnie d'un autre : la politique est evaluee LIGNE PAR LIGNE.
-- La nomination d'un capitaine ou d'un lieutenant n'est deliberement PAS couverte ici : elle passe
-- par les RPC attestees ci-dessous, parce que celui qui accepte une nomination n'occupe pas encore
-- le poste et ne peut donc satisfaire aucune de ces deux conditions.
CREATE POLICY "compagnies maj par la chaine de commandement" ON public.compagnies_militaires
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.personnages_donnees p
             WHERE p.user_id = auth.uid()
               AND p.country = (data::jsonb)->>'pays'
               AND (p.poste->>'id' = 'commandant'
                    OR (p.poste->>'id' = 'capitaine' AND p.name = (data::jsonb)->>'capitaineNom')))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.personnages_donnees p
             WHERE p.user_id = auth.uid()
               AND p.country = (data::jsonb)->>'pays'
               AND (p.poste->>'id' = 'commandant'
                    OR (p.poste->>'id' = 'capitaine' AND p.name = (data::jsonb)->>'capitaineNom')))
  );

-- Aucune politique DELETE : une compagnie ne se supprime pas depuis le navigateur.

-- ---------------------------------------------------------------------------------------
-- NOMINATIONS MILITAIRES. Meme mecanique en deux temps que les postes nommes generiques
-- (proposition puis acceptation par le destinataire, nominations_en_attente), mais dans une table
-- dediee : la table generique n'a pas de colonne pour le rattachement structurel
-- (compagnie, section) qui fait justement tout le sens de ces deux grades.
-- Aucune regle de jeu nouvelle : meme flux, meme autorite, meme acceptation volontaire.
-- ---------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.nominations_militaires (
  id            text PRIMARY KEY,
  pays          text NOT NULL,
  grade         text NOT NULL CHECK (grade IN ('capitaine','lieutenant')),
  compagnie_id  text NOT NULL,
  section_id    text,
  destinataire  text NOT NULL,
  par           text NOT NULL,
  traitee       boolean NOT NULL DEFAULT false,
  cree_le       timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.nominations_militaires ENABLE ROW LEVEL SECURITY;

-- Chacun ne voit que les nominations qui le concernent (ou celles qu'il a emises).
CREATE POLICY "nominations militaires lecture interessee" ON public.nominations_militaires
  FOR SELECT TO authenticated
  USING (destinataire = public.mon_personnage() OR par = public.mon_personnage());
-- Aucune ecriture cliente : tout passe par les RPC attestees.