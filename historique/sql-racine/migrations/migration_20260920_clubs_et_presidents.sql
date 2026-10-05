-- =============================================================================
-- PRESIDENCE DES CLUBS : MIROIR, ELECTEURS RESOLUS PAR LE SERVEUR, FERMETURE
-- =============================================================================
-- Date d'application en production : 20 septembre 2026.
--
-- CE FICHIER EST UN RATTRAPAGE DE VERSIONNEMENT. Il reproduit l'ETAT FINAL
-- present en production, pas l'historique de la session.
--
-- MIGRATIONS DE PRODUCTION ABSORBEES, DANS L'ORDRE CHRONOLOGIQUE :
--   20260920132204  clubs_miroir_et_electeurs
--       cree la table public.clubs_sportifs_regles (RLS active, REVOKE total,
--       12 lignes de reference) ; cree club_capitaine(text) et
--       club_electeurs(text).
--   20260920132241  club_president_scrutin_serveur
--       cree les trois portes du scrutin : club_president_postuler,
--       club_president_voter, club_president_cloturer.
--   20260920132455  fermeture_presidents_clubs
--       remplace les politiques publiques de public.presidents_clubs par la
--       seule presidents_clubs_lecture, active la RLS, revoque
--       INSERT/UPDATE/DELETE.
--
-- L'ORDRE EST STRUCTURANT : les trois RPC du scrutin lisent
-- clubs_sportifs_regles et appellent club_electeurs, qui appelle
-- club_capitaine. La fermeture vient EN DERNIER, une fois les portes ouvertes.
--
-- DEPENDANCES A REJOUER AVANT CE FICHIER
-- -----------------------------------------------------------------------------
--   * migration_championnat_rls.sql -- lot football de reference ; il traite le
--     meme domaine (championnat, paris) et ferme les tables voisines.
--   * public.presidents_clubs (colonnes id, data jsonb, updated_at) existe
--     deja : AUCUN migration_*.sql du depot ne la cree, elle vient d'un socle
--     hors depot. Signale tel quel, elle n'est pas inventee ici.
--   * public.jour_de_jeu_pays(text) : migration de production 20260920100857
--     (temps_reel_jour_de_jeu). Egalement utilisee par
--     migration_20260920_guerre_treve_chaine.sql.
--   * public.mon_personnage() : socle du chantier B (auth / RLS), sans fichier
--     dedie dans le depot.
--   * public.organisations et public.personnages_donnees : socle du jeu.
--
-- CE QUI N'EXISTE PAS DANS CE LOT
-- -----------------------------------------------------------------------------
-- Aucune reparation ponctuelle de donnees sur presidents_clubs : les trois
-- migrations n'y font ni INSERT ni UPDATE ponctuel -- verifie sur le texte
-- d'origine des trois. La premiere ligne d'un club y est creee par
-- club_president_postuler, au depot de la premiere candidature.
--
-- MIROIR A REGENERER SI data.js CHANGE : les 12 lignes de
-- clubs_sportifs_regles recopient data.js. Une divergence rendrait le capitaine
-- serveur different du capitaine affiche.


-- =============================================================================
-- 1. 20260920132204 — LE MIROIR DES CLUBS ET LA RESOLUTION DES ELECTEURS
-- =============================================================================
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

-- Les 12 lignes ci-dessous ont ete REGENEREES DEPUIS LA BASE le 20 septembre
-- 2026 (format(%L) sur les cinq colonnes reelles) : elles sont, au caractere
-- pres, ce que la production contient. L'ordre est celui du club_id ; la
-- migration d'origine les listait par pays, sans consequence.
INSERT INTO public.clubs_sportifs_regles (club_id, nom, country, city, valeur_base) VALUES
  ('al-baraka-fc','Oasis City FC','khalija','ville_a',56),
  ('brise-mariannaise','La Brise Mariannaise','republic','ville_a',60),
  ('cheminote-montrouge','Union Cheminote de Montrouge','republic','ville_b',63),
  ('dynamo-novomirsk','Dynamo Novomirsk','soviet','capitale',74),
  ('fronterizos-unidos','Atlético Puerto Negro','narco','ville_a',58),
  ('jaguares-selva','Independiente de Villa Sangre','narco','ville_b',61),
  ('kolkhoze-ouvrier','Étoile Rouge de Krasnov','soviet','ville_b',59),
  ('nadi-al-madina','Shabab Al Madina','khalija','capitale',70),
  ('olympique-luthecia','Olympique de Luthécia','republic','capitale',72),
  ('rojos-cartel','Estudiantes de la Ciudad','narco','capitale',68),
  ('sharq-al-nour','Al-Petrol United FC','khalija','ville_b',62),
  ('spartak-sibirsk','Partizan de Starovka','soviet','ville_a',57)
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


-- =============================================================================
-- 2. 20260920132241 — LE SCRUTIN DE LA PRESIDENCE DE CLUB PASSE AU SERVEUR
-- =============================================================================
-- §6.3 — LE SCRUTIN DE LA PRESIDENCE DE CLUB PASSE AU SERVEUR
-- ---------------------------------------------------------------------------
-- Trois portes, et elles seules. Les regles de jeu sont reprises a l'identique ;
-- ce qui change est QUI les applique.

-- 1. DEPOSER SA CANDIDATURE -------------------------------------------------
CREATE OR REPLACE FUNCTION public.club_president_postuler(p_club text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_moi text; c record; v_data jsonb; v_jour integer; v_elect jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT * INTO c FROM public.clubs_sportifs_regles WHERE club_id = p_club;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'club_inconnu');
  END IF;
  v_jour := public.jour_de_jeu_pays(c.country);

  SELECT coalesce(data, '{}'::jsonb) INTO v_data
    FROM public.presidents_clubs WHERE id = p_club FOR UPDATE;
  v_data := coalesce(v_data, '{}'::jsonb);

  IF (v_data -> 'candidature') IS NOT NULL AND jsonb_typeof(v_data -> 'candidature') = 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidature_en_cours');
  END IF;

  -- Protection du president en poste : 8 jours, regle existante.
  IF (v_data ->> 'president') IS NOT NULL
     AND (v_data ->> 'president') <> v_moi
     AND (v_data ->> 'dateElection') IS NOT NULL
     AND (v_jour - (v_data ->> 'dateElection')::int) < 8 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_protege',
                              'jours_restants', 8 - (v_jour - (v_data ->> 'dateElection')::int));
  END IF;

  -- LES ELECTEURS SONT RESOLUS ICI, PAR LE SERVEUR. Aucune identite transmise.
  v_elect := public.club_electeurs(p_club);

  v_data := v_data || jsonb_build_object('candidature', jsonb_build_object(
    'candidat',   v_moi,
    'dateDebut',  v_jour,
    'dateLimite', v_jour + 2,
    'votes',      '{}'::jsonb,
    'electeurs',  v_elect));

  INSERT INTO public.presidents_clubs (id, data, updated_at)
  VALUES (p_club, v_data, now())
  ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data, updated_at = now();

  RETURN jsonb_build_object('ok', true, 'candidat', v_moi,
                            'dateLimite', v_jour + 2, 'electeurs', v_elect);
END;
$$;

-- 2. VOTER -------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.club_president_voter(p_club text, p_vote boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_moi text; v_data jsonb; v_cand jsonb; v_elect jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(data, '{}'::jsonb) INTO v_data
    FROM public.presidents_clubs WHERE id = p_club FOR UPDATE;
  IF v_data IS NULL OR jsonb_typeof(v_data -> 'candidature') <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_candidature');
  END IF;
  v_cand  := v_data -> 'candidature';
  v_elect := v_cand -> 'electeurs';

  -- Seul un des trois electeurs vote. L'instantane est celui du SERVEUR.
  IF v_moi IS DISTINCT FROM (v_elect ->> 'chefSupporters')
     AND v_moi IS DISTINCT FROM (v_elect ->> 'maire')
     AND v_moi IS DISTINCT FROM (v_elect ->> 'capitaine') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'non_electeur');
  END IF;

  -- Un seul vote par electeur.
  IF (v_cand -> 'votes') ? v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_vote');
  END IF;

  v_cand := jsonb_set(v_cand, ARRAY['votes', v_moi], to_jsonb(coalesce(p_vote, false)), true);
  UPDATE public.presidents_clubs
     SET data = v_data || jsonb_build_object('candidature', v_cand), updated_at = now()
   WHERE id = p_club;

  RETURN jsonb_build_object('ok', true, 'vote', coalesce(p_vote, false));
END;
$$;

-- 3. DEPOUILLER --------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.club_president_cloturer(p_club text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_data jsonb; v_cand jsonb; v_elect jsonb; v_votes jsonb;
  v_jour integer; c record; v_nom text; v_pour int := 0; v_total int := 0;
  v_valide boolean; v_tous boolean := true;
  v_noms text[];
BEGIN
  SELECT * INTO c FROM public.clubs_sportifs_regles WHERE club_id = p_club;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'club_inconnu');
  END IF;
  v_jour := public.jour_de_jeu_pays(c.country);

  SELECT coalesce(data, '{}'::jsonb) INTO v_data
    FROM public.presidents_clubs WHERE id = p_club FOR UPDATE;
  IF v_data IS NULL OR jsonb_typeof(v_data -> 'candidature') <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_candidature');
  END IF;
  v_cand  := v_data -> 'candidature';
  v_elect := v_cand -> 'electeurs';
  v_votes := coalesce(v_cand -> 'votes', '{}'::jsonb);

  v_noms := ARRAY(SELECT x FROM unnest(ARRAY[
      v_elect ->> 'chefSupporters', v_elect ->> 'maire', v_elect ->> 'capitaine']) x
     WHERE x IS NOT NULL AND btrim(x) <> '');

  FOREACH v_nom IN ARRAY v_noms LOOP
    v_total := v_total + 1;
    IF NOT (v_votes ? v_nom) THEN v_tous := false; END IF;
  END LOOP;

  -- Depouillement des que tous ont vote OU a l'echeance. Pas avant.
  IF NOT v_tous AND v_jour < (v_cand ->> 'dateLimite')::int THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_en_cours',
                              'votes', jsonb_array_length(
                                 coalesce(jsonb_path_query_array(v_votes, '$.keyvalue().key'), '[]'::jsonb)),
                              'attendus', v_total, 'dateLimite', (v_cand ->> 'dateLimite')::int);
  END IF;

  -- SILENCE = ACCORD : les votes manquants comptent pour « oui ».
  FOREACH v_nom IN ARRAY v_noms LOOP
    IF NOT (v_votes ? v_nom) THEN
      v_pour := v_pour + 1;
    ELSIF coalesce((v_votes ->> v_nom)::boolean, false) THEN
      v_pour := v_pour + 1;
    END IF;
  END LOOP;

  v_valide := (v_pour >= 2);

  IF v_valide THEN
    v_data := v_data || jsonb_build_object(
      'president',    v_cand ->> 'candidat',
      'dateElection', v_jour);
  END IF;
  v_data := v_data || jsonb_build_object('candidature', 'null'::jsonb);

  UPDATE public.presidents_clubs SET data = v_data, updated_at = now() WHERE id = p_club;

  RETURN jsonb_build_object('ok', true, 'elu', v_valide,
                            'candidat', v_cand ->> 'candidat',
                            'pour', v_pour, 'electeurs', v_total);
END;
$$;

REVOKE ALL ON FUNCTION public.club_president_postuler(text) FROM public, anon;
REVOKE ALL ON FUNCTION public.club_president_voter(text, boolean) FROM public, anon;
REVOKE ALL ON FUNCTION public.club_president_cloturer(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.club_president_postuler(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.club_president_voter(text, boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.club_president_cloturer(text) TO authenticated, service_role;


-- =============================================================================
-- 3. 20260920132455 — FERMETURE DE presidents_clubs
-- =============================================================================
-- §6.3 — FERMETURE DE presidents_clubs
-- ---------------------------------------------------------------------------
-- SEQUENCEMENT RESPECTE : les trois portes serveur existent et sont testees, le
-- client a ete migre, et les deux wrappers d'ecriture directe (sbSavePresidentClub,
-- getElecteursClub) n'ont plus aucun appelant -- verifie.
--
-- chargerPresidentClub() a par ailleurs cesse d'ECRIRE a la lecture : elle creait
-- la ligne quand elle n'existait pas. La ligne est desormais creee par le serveur,
-- au depot de la premiere candidature.
--
-- La LECTURE reste ouverte : le nom du president d'un club est une information
-- publique, affichee au bureau du president et lue par le circuit des transferts.
--
-- Les politiques existantes etaient en USING (true) / WITH CHECK (true) : les
-- laisser aurait rendu l'activation de la RLS purement decorative.

DROP POLICY IF EXISTS "Ecriture publique presidents clubs" ON public.presidents_clubs;
DROP POLICY IF EXISTS "Lecture publique presidents clubs"  ON public.presidents_clubs;
DROP POLICY IF EXISTS "Maj publique presidents clubs"      ON public.presidents_clubs;

CREATE POLICY presidents_clubs_lecture ON public.presidents_clubs
  FOR SELECT TO anon, authenticated USING (true);

ALTER TABLE public.presidents_clubs ENABLE ROW LEVEL SECURITY;
REVOKE INSERT, UPDATE, DELETE ON public.presidents_clubs FROM anon, authenticated, public;
