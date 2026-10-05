-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913212715
-- Nom original      : chantier_c_phase3_prix_rachat_et_propriete
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 21:27:15 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 04a4b9198e35760738e9627f752a85dd
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
-- CHANTIER C / PHASE 3 — FAMILLE 6 : PROPRIETE, COMPROMIS, RACHAT, PREEMPTION.
-- Miroir des prix de rachat, genere depuis PRIX_RACHAT_COMMERCE / PRIX_RACHAT_ARMURERIE /
-- PRIX_RACHAT_IMPRIMERIE / ACOMPTE_COMPROMIS / PLAFOND_PRET_COMPROMIS.
CREATE TABLE IF NOT EXISTS public.entreprises_prix_rachat (
  batiment text PRIMARY KEY, prix numeric NOT NULL);
ALTER TABLE public.entreprises_prix_rachat ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "prix_rachat lecture" ON public.entreprises_prix_rachat;
CREATE POLICY "prix_rachat lecture" ON public.entreprises_prix_rachat FOR SELECT USING (true);
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.entreprises_prix_rachat FROM anon, authenticated;
GRANT SELECT ON public.entreprises_prix_rachat TO anon, authenticated;

DELETE FROM public.entreprises_prix_rachat;
INSERT INTO public.entreprises_prix_rachat (batiment, prix) VALUES
  ('bar-des-pecheurs', 180000),
  ('brasserie-voyageurs-montrouge', 120000),
  ('cafe-gare-montrouge', 180000),
  ('cafe-tabac-cheminots-montrouge', 180000),
  ('hotel-mineur', 80000),
  ('hotel-republica', 380000);

INSERT INTO public.entreprises_constantes (cle, valeur) VALUES
  ('prix_rachat_armurerie', 130000),
  ('prix_rachat_imprimerie', 180000),
  ('acompte_compromis', 1000),
  ('plafond_pret_compromis', 150000)
ON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur;

-- Prix de rachat d'une entreprise, arrete par le serveur : armurerie et imprimerie au forfait,
-- commerce selon son batiment. Aucun prix transmis par le navigateur n'est utilise.
CREATE OR REPLACE FUNCTION public.entreprise_prix_rachat(p_data jsonb)
RETURNS numeric
LANGUAGE plpgsql STABLE SET search_path = public AS $$
DECLARE v_prix numeric; v_type text; v_bat text;
BEGIN
  v_type := COALESCE(p_data->>'type','');
  v_bat  := COALESCE(p_data->>'buildingId','');
  IF v_type = 'armurerie' THEN
    SELECT valeur INTO v_prix FROM public.entreprises_constantes WHERE cle = 'prix_rachat_armurerie';
    RETURN v_prix;
  END IF;
  IF v_type = 'imprimerie' THEN
    SELECT valeur INTO v_prix FROM public.entreprises_constantes WHERE cle = 'prix_rachat_imprimerie';
    RETURN v_prix;
  END IF;
  SELECT prix INTO v_prix FROM public.entreprises_prix_rachat WHERE batiment = v_bat;
  RETURN v_prix;
END; $$;

-- Taux de pret de la banque nationale, meme formule que getTauxPret('nationale') : 5 + IE/10.
-- Pour Republia l'IE national est la moyenne des IE des trois villes, lus dans indices_villes ;
-- ailleurs, le jeu n'a qu'un indice par defaut (aucun indice national persiste cote serveur).
CREATE OR REPLACE FUNCTION public.taux_pret_nationale(p_pays text)
RETURNS numeric
LANGUAGE plpgsql STABLE SET search_path = public AS $$
DECLARE v_ie numeric;
BEGIN
  IF p_pays = 'republic' THEN
    SELECT round(avg(COALESCE((data->>'ie')::numeric, 50)))
      INTO v_ie FROM public.indices_villes
     WHERE id IN ('republic_capitale','republic_ville_a','republic_ville_b');
  END IF;
  RETURN 5 + COALESCE(v_ie, 50) / 10;
END; $$;

REVOKE EXECUTE ON FUNCTION public.entreprise_prix_rachat(jsonb) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.taux_pret_nationale(text) FROM PUBLIC, anon, authenticated;
