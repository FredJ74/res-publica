-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919172408
-- Nom original      : contre_espionnage_memoire
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-19 17:24:08 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6fd4224247181c8eecd9aa8369eaa009
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
-- LOT 1 — Memoire institutionnelle du contre-espionnage.
--
-- AUCUNE TABLE NOUVELLE : tout vit dans renseignements_connus, dont la
-- migration d'origine avait justement prevu ce cas (« fait_objectif_ref est une
-- reference LEGERE et OPTIONNELLE, ex. "actions_tracables:123" »).
--
-- TITULAIRE = L'ETAT, pas la personne. Le GD exige que la connaissance ne
-- disparaisse pas quand le Commissaire quitte son poste. `titulaire` est du
-- texte libre sans cle etrangere : on y met 'etat:<pays>'. Extension
-- semantique, pas structurelle. Le prefixe 'etat:' ne peut pas entrer en
-- collision avec un nom de personnage (les noms du jeu n'en contiennent pas).
--
-- UNE LIGNE PAR PALIER ATTEINT (4 au maximum par Etat et par couverture) :
-- l'historique dit QUAND chaque niveau a ete acquis et SUR QUELLE TRACE, et la
-- regle « une connaissance acquise n'est jamais perdue » devient un simple
-- max(). Le niveau est porte par `categorie` (colonne libre, sans CHECK).
--
-- mode_acquisition = 'interrogatoire' : valeur DEJA EXISTANTE du CHECK, et sa
-- definition documentee est « obtenu sous l'autorite d'un enqueteur habilite
-- (commissaire/juge en V1) ». Aucune migration de contrainte necessaire.
--
-- NON-EXPIRATION : le GD veut que ces renseignements n'expirent pas, alors que
-- jour_expiration est NOT NULL et compare a state.day, compteur PRIVE et
-- divergent de chaque joueur. On pose donc une sentinelle volontairement
-- inatteignable (2147483647) : la ligne reste eternellement valide pour tous
-- les lecteurs, sans qu'aucun jour de jeu n'ait a etre devine.

-- Identite reelle validee par le GD (le conseiller et le garde restent a definir).
INSERT INTO public.renseignement_identites_reelles (role, vrai_nom, dup) VALUES
  ('coordinateur', 'Yannick Helle', 12)
ON CONFLICT (role) DO UPDATE SET vrai_nom = EXCLUDED.vrai_nom, dup = EXCLUDED.dup;

-- Le premier consommateur qui filtre reellement par `cible` existe desormais :
-- l'index que la migration d'origine avait explicitement remis a plus tard.
CREATE INDEX IF NOT EXISTS idx_renseignements_cible_categorie
  ON public.renseignements_connus (cible, categorie);

-- --------------------------------------------------------------------------
-- Niveau deja connu par un Etat sur une couverture. 0 = rien.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.contre_espionnage_niveau_connu(
  p_pays text, p_couverture text)
RETURNS integer
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(max(substring(r.categorie from 'contre_espionnage_niveau_(\d)')::integer), 0)
    FROM public.renseignements_connus r
   WHERE r.titulaire = 'etat:' || p_pays
     AND r.cible = p_couverture
     AND r.categorie LIKE 'contre_espionnage_niveau_%';
$function$;

-- --------------------------------------------------------------------------
-- Memorise les paliers nouvellement atteints. Idempotent : ne reecrit jamais un
-- palier deja acquis, et ne DEGRADE jamais le dossier (une enquete ulterieure
-- moins bonne n'enleve rien). Renvoie le niveau final.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.contre_espionnage_memoriser(
  p_pays text, p_couverture text, p_niveau integer,
  p_vrai_nom text, p_pays_agent text, p_instructeur text, p_ref text)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_jamais constant integer := 2147483647;
  v_connu integer; v_n integer; v_texte text;
BEGIN
  v_connu := public.contre_espionnage_niveau_connu(p_pays, p_couverture);
  IF coalesce(p_niveau, 0) <= v_connu THEN
    RETURN v_connu;                      -- rien de neuf : le dossier est intact
  END IF;

  FOR v_n IN (v_connu + 1) .. p_niveau LOOP
    v_texte := CASE v_n
      WHEN 1 THEN 'L''identite publique « ' || p_couverture || ' » est une fausse identite.'
      WHEN 2 THEN '« ' || p_couverture || ' » est un agent etranger.'
      WHEN 3 THEN 'Sous l''identite « ' || p_couverture || ' » se cache ' || coalesce(p_vrai_nom, 'un inconnu') || '.'
      WHEN 4 THEN '« ' || p_couverture || ' » travaille pour ' || coalesce(p_pays_agent, 'une puissance etrangere') || '.'
    END;
    INSERT INTO public.renseignements_connus
      (id, titulaire, contenu, cible, categorie, source, mode_acquisition,
       fait_objectif_ref, jour_acquisition, jour_derniere_reactivation, jour_expiration)
    VALUES ('ce_' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' || v_n
              || '_' || substr(md5(random()::text), 1, 6),
            'etat:' || p_pays, v_texte, p_couverture,
            'contre_espionnage_niveau_' || v_n,
            coalesce(p_instructeur, 'enquete'), 'interrogatoire',
            p_ref, 0, 0, c_jamais);
  END LOOP;
  RETURN p_niveau;
END;
$function$;

-- --------------------------------------------------------------------------
-- LECTURE CONTROLEE. Aucun endpoint ne permet de lire arbitrairement
-- renseignements_connus : cette fonction n'accepte AUCUN parametre d'identite.
-- Elle derive le lecteur de acteur_poste_courant() et ne rend que les dossiers
-- de SON Etat.
--   * Ministre de l'Interieur = memoire nationale : tous les dossiers du pays ;
--   * Commissaire = enqueteur operationnel local : les memes dossiers, sans
--     qu'aucune transmission manuelle ne soit necessaire (le GD refuse que le
--     ministre serve de facteur).
-- Tout autre poste : refus.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.contre_espionnage_dossiers()
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_poste text; v_pays text; v_res jsonb;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_poste IS NULL OR v_poste NOT IN ('min_int', 'commissaire') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'couverture', d.cible,
           'niveau', d.niveau,
           'faits', d.faits) ORDER BY d.cible), '[]'::jsonb)
    INTO v_res
    FROM (
      SELECT r.cible,
             max(substring(r.categorie from 'contre_espionnage_niveau_(\d)')::integer) AS niveau,
             jsonb_agg(r.contenu ORDER BY r.categorie) AS faits
        FROM public.renseignements_connus r
       WHERE r.titulaire = 'etat:' || v_pays
         AND r.categorie LIKE 'contre_espionnage_niveau_%'
       GROUP BY r.cible
    ) d;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'poste', v_poste, 'dossiers', v_res);
END;
$function$;

REVOKE ALL ON FUNCTION public.contre_espionnage_niveau_connu(text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.contre_espionnage_memoriser(text,text,integer,text,text,text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_niveau_connu(text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_memoriser(text,text,integer,text,text,text,text) TO service_role;

REVOKE ALL ON FUNCTION public.contre_espionnage_dossiers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_dossiers() TO authenticated, service_role;
