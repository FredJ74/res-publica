-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920132204
-- Nom original      : clubs_miroir_et_electeurs
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 13:22:04 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 50da3e552377eee98580a0bf47f140dd
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
-- §6.3 — SCRUTIN DES CLUBS : LE MIROIR ET LA RESOLUTION DES ELECTEURS
-- ---------------------------------------------------------------------------
-- EXPLOIT MESURE : un joueur ordinaire pouvait ecrire { president: lui-meme }
-- dans presidents_clubs.
--
-- LES REGLES DE JEU NE CHANGENT PAS. Une candidature a la fois ; president en
-- poste protege 8 jours ; scrutin de 2 jours ; trois electeurs -- chef des
-- supporters, maire, capitaine ; depouillement des que les trois ont vote ou a
-- l'echeance ; silence = accord ; elu a 2 voix sur 3. Tout est repris a
-- l'identique de plateau-organisations-quetes.js.
--
-- CE QUI CHANGE : LE CLIENT NE FOURNIT PLUS AUCUNE IDENTITE D'ELECTEUR. C'etait
-- la faille de fond : la candidature embarquait un instantane des trois
-- electeurs ECRIT PAR LE PROPOSANT, et comme le silence vaut accord, y inscrire
-- trois noms quelconques suffisait a etre elu sans qu'aucun d'eux ne vote.
-- Le serveur resout desormais les trois lui-meme, au moment du depot, et c'est
-- SON instantane qui fait foi.
--
-- MIROIR DES CLUBS. valeurBase entre dans la regle du capitaine (seuil
-- d'insuffisance). Recopie ici depuis data.js, comme les autres miroirs
-- declares du projet. A regenerer si data.js change -- une divergence rendrait
-- le capitaine serveur different du capitaine affiche.

CREATE TABLE IF NOT EXISTS public.clubs_sportifs_regles (
  club_id     text PRIMARY KEY,
  nom         text NOT NULL,
  country     text NOT NULL,
  city        text NOT NULL,
  valeur_base integer NOT NULL
);
ALTER TABLE public.clubs_sportifs_regles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.clubs_sportifs_regles FROM anon, authenticated, public;

INSERT INTO public.clubs_sportifs_regles (club_id, nom, country, city, valeur_base) VALUES
  ('olympique-luthecia','Olympique de Luthécia','republic','capitale',72),
  ('brise-mariannaise','La Brise Mariannaise','republic','ville_a',60),
  ('cheminote-montrouge','Union Cheminote de Montrouge','republic','ville_b',63),
  ('rojos-cartel','Estudiantes de la Ciudad','narco','capitale',68),
  ('fronterizos-unidos','Atlético Puerto Negro','narco','ville_a',58),
  ('jaguares-selva','Independiente de Villa Sangre','narco','ville_b',61),
  ('dynamo-novomirsk','Dynamo Novomirsk','soviet','capitale',74),
  ('spartak-sibirsk','Partizan de Starovka','soviet','ville_a',57),
  ('kolkhoze-ouvrier','Étoile Rouge de Krasnov','soviet','ville_b',59),
  ('nadi-al-madina','Shabab Al Madina','khalija','capitale',70),
  ('al-baraka-fc','Oasis City FC','khalija','ville_a',56),
  ('sharq-al-nour','Al-Petrol United FC','khalija','ville_b',62)
ON CONFLICT (club_id) DO UPDATE
  SET nom = EXCLUDED.nom, country = EXCLUDED.country,
      city = EXCLUDED.city, valeur_base = EXCLUDED.valeur_base;

-- LE CAPITAINE. Portage fidele de calculerClassementClub + getCapitaine :
-- licencies du club, total defense + technique + endurance, tri decroissant,
-- statut 'titulaire' pour les 11 premiers non blesses dont le total depasse la
-- moitie de la valeur du club ; le capitaine est le PREMIER titulaire.
-- TITULAIRES_MAX = 11 (plateau-organisations-quetes.js). Aucune regle modifiee.
CREATE OR REPLACE FUNCTION public.club_capitaine(p_club text)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_valeur integer; v_jour integer; v_nom text;
BEGIN
  SELECT valeur_base INTO v_valeur FROM public.clubs_sportifs_regles WHERE club_id = p_club;
  IF v_valeur IS NULL THEN RETURN NULL; END IF;
  v_jour := public.jour_de_jeu_pays((SELECT country FROM public.clubs_sportifs_regles WHERE club_id = p_club));

  SELECT nom INTO v_nom FROM (
    SELECT d.name AS nom,
           coalesce((d.performance_sportive ->> 'defense')::numeric, 0)
         + coalesce((d.performance_sportive ->> 'technique')::numeric, 0)
         + coalesce((d.performance_sportive ->> 'endurance')::numeric, 0) AS total,
           coalesce((d.blessure_sportive ->> 'jusquauJour')::int, -1) > v_jour AS blesse
      FROM public.personnages_donnees d
     WHERE (d.licence_sportive ->> 'clubId') = p_club
  ) t
   WHERE NOT t.blesse AND t.total > v_valeur * 0.5
   ORDER BY t.total DESC
   LIMIT 1;

  RETURN v_nom;   -- NULL => capitaine PNJ par defaut, comme cote client
END;
$$;
REVOKE ALL ON FUNCTION public.club_capitaine(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.club_capitaine(text) TO authenticated, service_role;

-- LES TROIS ELECTEURS, resolus par le serveur seul.
CREATE OR REPLACE FUNCTION public.club_electeurs(p_club text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE c record; v_chef text; v_maire text; v_cap text;
BEGIN
  SELECT * INTO c FROM public.clubs_sportifs_regles WHERE club_id = p_club;
  IF NOT FOUND THEN RETURN NULL; END IF;

  -- Chef de l'organisation de supporters de la ville du club.
  SELECT (o.data::jsonb ->> 'chef') INTO v_chef
    FROM public.organisations o
   WHERE (o.data::jsonb ->> 'type') = 'supporters'
     AND (o.data::jsonb ->> 'country') = c.country
     AND (o.data::jsonb ->> 'city') = c.city
   LIMIT 1;

  -- Maire de la ville -- un PJ seulement, comme cote client (maireInfo.estPJ).
  SELECT d.name INTO v_maire
    FROM public.personnages_donnees d
   WHERE (d.poste ->> 'id') = 'maire'
     AND (d.poste ->> 'city') = c.city
     AND coalesce(d.country, 'republic') = c.country
   LIMIT 1;

  v_cap := public.club_capitaine(p_club);

  RETURN jsonb_build_object('chefSupporters', v_chef, 'maire', v_maire, 'capitaine', v_cap);
END;
$$;
REVOKE ALL ON FUNCTION public.club_electeurs(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.club_electeurs(text) TO authenticated, service_role;