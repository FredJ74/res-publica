-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927135314
-- Nom original      : socle_pnj_institution_police_et_classe
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 13:53:14 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : fe86515d57a469e86430d73311b66dba
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
-- LOT 3a — L'INSTITUTION POLICE, SA CLASSE, SES CARACTERISTIQUES (27 septembre 2026)
--
-- Meme patron que le douanier, avec UNE difference de fond : la police est MULTI-VILLE. Le
-- perimetre porte donc la ville, et l'autorite est le Commissaire DE CETTE VILLE -- pas
-- n'importe quel Commissaire du pays. C'est exactement ce que la garde d'ecriture exige deja
-- (`poste->>'city' = p_ville`), et que l'autorite de caisse, elle, ne verifiait pas.

INSERT INTO public.pnj_familles_classes (famille, classe, note) VALUES
  ('policier', 'beta', 'Raccordee au lot 3. 12 PA presents, jamais debites. Multi-ville : le '
                    || 'perimetre porte la ville, l''autorite est le Commissaire de cette ville.')
ON CONFLICT (famille) DO UPDATE SET classe = EXCLUDED.classe, note = EXCLUDED.note;

-- Arbitrage du concepteur : INT 10, CHA 8, VOL 12, PER 12, DUP 8, ENT 10.
-- PER et VOL reprennent exactement les valeurs historiques des fiches.
CREATE OR REPLACE FUNCTION public.police_caracteristiques_metier()
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT jsonb_build_object('INT',10,'CHA',8,'VOL',12,'PER',12,'DUP',8,'ENT',10);
$$;

CREATE OR REPLACE FUNCTION public.police_pnj_id(p_pays text, p_ville text, p_matricule text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT 'police-' || p_pays || '-' || p_ville || '-' || p_matricule;
$$;

-- LE RESOLVEUR D'AUTORITE. Le perimetre est '<ville>:<batiment>'. L'autorite est le PJ portant
-- le poste `commissaire` AVEC CETTE VILLE. Un Commissaire d'une autre ville n'a aucune autorite
-- ici -- c'est la porte historique, reproduite sans la durcir ni l'elargir.
-- Un titulaire PNJ du poste n'est pas une autorite : tant qu'aucun PJ ne le porte, l'autorite
-- est A PERSONNE. Meme doctrine que la reserve militaire et que la douane.
CREATE OR REPLACE FUNCTION public.police_autorite_de_perimetre(p_pays text, p_perimetre text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_ville text; v_bat text; v_nom text;
BEGIN
  IF p_perimetre IS NULL OR position(':' in p_perimetre) = 0 THEN RETURN NULL; END IF;
  v_ville := split_part(p_perimetre, ':', 1);
  v_bat   := split_part(p_perimetre, ':', 2);
  IF v_bat NOT IN ('commissariat','commissariat-local') THEN RETURN NULL; END IF;
  SELECT pd.name INTO v_nom
    FROM public.personnages_donnees pd
   WHERE COALESCE(pd.country, 'republic') = p_pays
     AND pd.poste->>'id' = 'commissaire'
     AND pd.poste->>'city' = v_ville
   ORDER BY pd.name
   LIMIT 1;
  RETURN v_nom;
END; $$;

INSERT INTO public.pnj_institutions (institution, resolveur, note) VALUES
  ('police', 'police_autorite_de_perimetre',
   'Perimetre = ''<ville>:<batiment>'' du commissariat. Autorite : le PJ portant le poste '
   'commissaire DANS CETTE VILLE. Un Commissaire d''une autre ville n''a aucune autorite.')
ON CONFLICT (institution) DO UPDATE SET resolveur = EXCLUDED.resolveur, note = EXCLUDED.note;

REVOKE ALL ON FUNCTION public.police_caracteristiques_metier()        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.police_pnj_id(text,text,text)           FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.police_autorite_de_perimetre(text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.police_autorite_de_perimetre(text,text) TO service_role;