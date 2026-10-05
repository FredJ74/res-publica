-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927163429
-- Nom original      : socle_pnj_referentiel_profils_metiers_fixes
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 16:34:29 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 3c484af6ac7103c4c6ef204e067ab672
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
-- CHECKPOINT A1 — LES CARACTERISTIQUES SONT FIXES ET APPARTIENNENT AU METIER
--
-- Le modele abandonne les tirages aleatoires a l'embauche. Les caracteristiques d'un PNJ sont
-- connues d'avance, identiques pour tous les PNJ du meme metier, et lisibles a une seule adresse.
--
-- LA CLE EST LE METIER, PAS LA FAMILLE -- et c'est le point de l'architecture. Escort, informateur
-- et codetenu sont trois METIERS de la meme famille `employe` : trois profils distincts, une seule
-- famille. Inversement le metier ne dit rien de la classe : `douanier` designe ici le profil des
-- effectifs Beta du service, et Prosper Tampon exercera la meme fonction en restant Gamma.
--
-- LE REFERENTIEL CIBLE EST EXCLUSIVEMENT INT / CHA / VOL / PER / DUP / ENT. L'ancien FOR n'est pas
-- reinterprete : il n'a pas d'equivalent ici, et aucune de ces valeurs n'en derive.
CREATE TABLE IF NOT EXISTS public.pnj_metiers_profils (
  metier   text PRIMARY KEY,
  car_int  integer NOT NULL, car_cha integer NOT NULL, car_vol integer NOT NULL,
  car_per  integer NOT NULL, car_dup integer NOT NULL, car_ent integer NOT NULL,
  note     text,
  CONSTRAINT pnj_metiers_profils_bornes CHECK (
    car_int BETWEEN 0 AND 100 AND car_cha BETWEEN 0 AND 100 AND car_vol BETWEEN 0 AND 100 AND
    car_per BETWEEN 0 AND 100 AND car_dup BETWEEN 0 AND 100 AND car_ent BETWEEN 0 AND 100));

ALTER TABLE public.pnj_metiers_profils ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.pnj_metiers_profils FROM anon, authenticated, PUBLIC;

COMMENT ON TABLE public.pnj_metiers_profils IS
  'Profils de caracteristiques FIXES par METIER (pas par famille, pas par classe). Source unique : '
  'aucun recrutement ne doit plus tirer de caracteristique au hasard.';

INSERT INTO public.pnj_metiers_profils (metier, car_int, car_cha, car_vol, car_per, car_dup, car_ent, note) VALUES
  ('soldat',      9,  8, 12, 10,  8, 12, 'Famille soldat, classe alpha. Profil arbitre le 27/09/2026 : '
    || 'comble les six caracteristiques qui manquaient aux 96 hommes depuis le lot 1.'),
  ('escort',     10, 15, 10, 10, 12, 10, 'Metier de la famille employe, classe beta. Remplace le tirage '
    || 'aleatoire CHA 12-18 / DUP 10-16 / INT 8-14 de confirmerRecrutementEscort.'),
  ('informateur',10, 10,  8, 15, 12,  8, 'Metier de la famille employe, classe beta. Remplace le tirage '
    || 'aleatoire PER 12-18 de doRecruterInformateurPNJ.'),
  ('codetenu',   10, 10, 10, 12, 12, 10, 'Metier de la famille employe, classe beta. Profil conserve pour '
    || 'le futur : le metier n''est PAS active, aucun PNJ du jeu ne porte job=codetenu.'),
  ('militant',    9, 12, 15,  9,  8, 12, 'Famille militant, classe beta. Profil conserve : le recrutement '
    || 'existe mais sa seule utilite (blocus syndical) est morte en amont.'),
  ('douanier',   10,  8, 12, 12,  8, 10, 'Metier des effectifs du service des Douanes, classe beta. '
    || 'Valeurs identiques a celles deja posees au lot 2 : cette ligne devient leur source unique.'),
  ('policier',   10,  8, 12, 12,  8, 10, 'Metier des effectifs de police, classe beta. Valeurs identiques '
    || 'a celles deja posees au lot 3 : cette ligne devient leur source unique.')
ON CONFLICT (metier) DO UPDATE SET
  car_int = EXCLUDED.car_int, car_cha = EXCLUDED.car_cha, car_vol = EXCLUDED.car_vol,
  car_per = EXCLUDED.car_per, car_dup = EXCLUDED.car_dup, car_ent = EXCLUDED.car_ent,
  note = EXCLUDED.note;

-- Lecture du profil. Rend NULL pour un metier inconnu : le metier doit etre declare, jamais devine.
CREATE OR REPLACE FUNCTION public.pnj_metier_profil(p_metier text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('INT', p.car_int, 'CHA', p.car_cha, 'VOL', p.car_vol,
                            'PER', p.car_per, 'DUP', p.car_dup, 'ENT', p.car_ent)
    FROM public.pnj_metiers_profils p WHERE p.metier = p_metier;
$$;

-- Le METIER d'un PNJ. Pour la famille `employe`, il vit dans pnj_employes_metier.job -- c'est la
-- que trois metiers se partagent une famille. Pour les autres, la famille EST le metier.
CREATE OR REPLACE FUNCTION public.pnj_metier_de(p_pnj_id text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN m.famille = 'employe'
              THEN (SELECT e.job FROM public.pnj_employes_metier e WHERE e.pnj_id = m.id)
              ELSE m.famille END
    FROM public.pnj_membres m WHERE m.id = p_pnj_id;
$$;

-- Les deux resolveurs metier existants delaissent leurs valeurs en dur et lisent le referentiel.
-- Valeurs rigoureusement identiques a celles qu'ils portaient : aucun changement de comportement.
CREATE OR REPLACE FUNCTION public.douane_caracteristiques_metier()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.pnj_metier_profil('douanier');
$$;
CREATE OR REPLACE FUNCTION public.police_caracteristiques_metier()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.pnj_metier_profil('policier');
$$;

-- LES 96 SOLDATS RECOIVENT ENFIN LEUR PROFIL. Verifie avant ecriture : aucune fonction du schema ne
-- LIT ces colonnes pour decider quoi que ce soit (seuls les miroirs douane/police les ecrivent, et
-- leurs comparateurs les comparent). Ce remplissage est donc sans effet de jeu aujourd'hui.
UPDATE public.pnj_membres m
   SET car_int = p.car_int, car_cha = p.car_cha, car_vol = p.car_vol,
       car_per = p.car_per, car_dup = p.car_dup, car_ent = p.car_ent, maj_le = now()
  FROM public.pnj_metiers_profils p
 WHERE p.metier = 'soldat' AND m.famille = 'soldat';

REVOKE ALL ON FUNCTION public.pnj_metier_profil(text) FROM authenticated, anon;
REVOKE ALL ON FUNCTION public.pnj_metier_de(text)     FROM authenticated, anon;