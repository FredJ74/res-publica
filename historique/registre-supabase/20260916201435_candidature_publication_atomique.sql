-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916201435
-- Nom original      : candidature_publication_atomique
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-16 20:14:35 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 4b827522f8b9e30ecc70a713f4fe5649
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
-- UNE CANDIDATURE N'EXISTE QU'AVEC SON PROGRAMME PUBLIE (16 septembre 2026).
--
-- DECISION DE JEU : le clic « Se porter candidat » n'inscrit plus personne. Il ouvre la redaction
-- du programme ; c'est la PUBLICATION qui vaut candidature. Fermer l'editeur ne coute rien et ne
-- declare personne.
--
-- Cette fonction est donc le point unique ou tout se joue, dans UNE SEULE TRANSACTION :
-- eligibilite, periode, cout, candidature, topic. Si quoi que ce soit echoue, rien ne reste --
-- ni candidature, ni PA debites, ni topic officiel abandonne.
--
-- GENERIQUE PAR CONSTRUCTION : rien n'est propre a une ville. Le pays vient de la fiche du
-- candidat, la ville est celle du scrutin (p_city), et un poste national ignore simplement la
-- ville. Luthecia, Montrouge et Port-Sainte-Marie empruntent exactement le meme chemin.
--
-- CE QUI EST REUTILISE, ET NON REECRIT :
--   * le declencheur trg_candidatures_cloture verifie deja la periode a l'INSERT -- on le laisse
--     faire : son exception annule toute la transaction, donc le topic et les PA avec ;
--   * payer_ordre preleve les 2 PA de 'deposer_candidature', avec le miroir des couts ;
--   * l'identifiant de candidature garde exactement la forme du client
--     (pays_cle_nom[_scrutin]) : deux depots au meme scrutin entrent en conflit de cle primaire.
--
-- MIROIR DES REGLES : postes_electifs_regles est GENERE depuis le vrai data.js par
-- .scratch/generer_postes_electifs.py (empreinte 2390eb52a42ae6a6). Sans lui le serveur ne
-- pourrait pas verifier l'influence minimale et devrait croire le navigateur.

CREATE TABLE IF NOT EXISTS public.postes_electifs_regles (
  poste_id     text PRIMARY KEY,
  nom          text NOT NULL,
  scope        text NOT NULL,          -- national | departemental | local
  niveau       text NOT NULL,          -- national | ville
  min_inf      integer NOT NULL DEFAULT 0,
  nb_par_ville integer
);
INSERT INTO public.postes_electifs_regles (poste_id, nom, scope, niveau, min_inf, nb_par_ville) VALUES
  ('president', 'Président', 'national', 'national', 10, NULL),
  ('chef_syndicat', 'Chef Syndical', 'national', 'national', 5, NULL),
  ('depute', 'Député', 'departemental', 'ville', 5, 3),
  ('maire', 'Maire', 'local', 'ville', 3, NULL)
ON CONFLICT (poste_id) DO UPDATE
  SET nom = EXCLUDED.nom, scope = EXCLUDED.scope, niveau = EXCLUDED.niveau,
      min_inf = EXCLUDED.min_inf, nb_par_ville = EXCLUDED.nb_par_ville;

ALTER TABLE public.postes_electifs_regles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS postes_electifs_regles_lecture ON public.postes_electifs_regles;
CREATE POLICY postes_electifs_regles_lecture ON public.postes_electifs_regles
  FOR SELECT TO anon, authenticated USING (true);
REVOKE INSERT, UPDATE, DELETE ON public.postes_electifs_regles FROM PUBLIC, anon, authenticated;

-- Le lien candidature <-> programme, sans ambiguite et sans dupliquer la candidature.
ALTER TABLE public.candidatures ADD COLUMN IF NOT EXISTS topic_id text;

CREATE OR REPLACE FUNCTION public.candidature_publier(
  p_poste text, p_city text, p_cle_scrutin numeric, p_titre text, p_contenu text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_nom text; v_pays text; v_inf numeric; v_poste record; v_fiche record;
  v_ville text; v_cle text; v_id text; v_topic text; v_forum text; v_temps text;
  v_paiement jsonb; v_titre text; v_contenu text;
BEGIN
  v_nom := public.mon_personnage();
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT * INTO v_fiche FROM public.personnages_donnees WHERE name = v_nom;
  v_pays := v_fiche.country;

  SELECT * INTO v_poste FROM public.postes_electifs_regles WHERE poste_id = p_poste;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_inconnu');
  END IF;

  -- ELIGIBILITE, exactement les regles existantes.
  -- 1. domiciliation dans l'empire
  IF coalesce(v_fiche.domicile->>'country', v_pays) IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'non_domicilie');
  END IF;
  -- 2. influence minimale du poste
  v_inf := CASE WHEN jsonb_typeof(v_fiche.resources->'inf') = 'number'
                THEN (v_fiche.resources->>'inf')::numeric ELSE 0 END;
  IF v_inf < v_poste.min_inf THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'influence_insuffisante',
                              'requis', v_poste.min_inf, 'reel', v_inf);
  END IF;
  -- 3. cumul interdit president <-> maire, et depute deja en fonction
  IF p_poste = 'depute' THEN
    IF v_fiche.poste_depute IS NOT NULL AND jsonb_typeof(v_fiche.poste_depute) = 'object' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'deja_depute');
    END IF;
  ELSIF v_fiche.poste->>'id' IS NOT NULL AND v_fiche.poste->>'id' <> p_poste THEN
    IF (v_fiche.poste->>'id' = 'president' AND p_poste = 'maire')
       OR (v_fiche.poste->>'id' = 'maire' AND p_poste = 'president') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cumul_interdit');
    END IF;
  END IF;

  -- La ville n'a de sens que pour un poste de ville ; un poste national l'ignore.
  v_ville := CASE WHEN v_poste.niveau = 'ville' THEN nullif(p_city, '') ELSE NULL END;
  v_cle := p_poste || CASE WHEN v_ville IS NOT NULL THEN '_' || v_ville ELSE '' END;
  v_id := v_pays || '_' || v_cle || '_' || v_nom
          || CASE WHEN p_cle_scrutin IS NOT NULL THEN '_' || p_cle_scrutin::bigint::text ELSE '' END;

  IF EXISTS (SELECT 1 FROM public.candidatures WHERE id = v_id) THEN
    RETURN jsonb_build_object('ok', true, 'deja_candidat', true, 'id', v_id,
                              'topic_id', (SELECT topic_id FROM public.candidatures WHERE id = v_id));
  END IF;

  -- LE COUT : 2 PA, par la primitive commune, avec le miroir des couts.
  v_paiement := public.payer_ordre(v_nom, 'deposer_candidature', 2, 0);
  IF NOT coalesce((v_paiement->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paiement->>'raison', 'paiement_refuse'));
  END IF;

  -- LE PROGRAMME. Aucune exigence de longueur : c'est un acte public, pas un concours.
  v_contenu := coalesce(nullif(btrim(p_contenu), ''), '(programme vide)');
  v_titre := coalesce(nullif(btrim(p_titre), ''),
                      '🗳️ Programme de ' || v_nom || ' — ' || v_poste.nom);
  v_topic := 'topic-programme-' || v_id;
  -- Forum LOCAL pour un scrutin de ville, NATIONAL pour un scrutin national. Le forum local est
  -- le meme identifiant partout : c'est le pays + la ville portes par le sujet qui le situent.
  v_forum := CASE WHEN v_poste.niveau = 'ville' THEN 'local' ELSE 'national' END;
  v_temps := to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY" · "HH24"h"MI');

  -- L'INSERTION DANS candidatures PASSE PAR trg_candidatures_cloture : hors periode, il leve, et
  -- toute la transaction tombe -- y compris le paiement et le sujet ci-dessous.
  INSERT INTO public.candidatures (id, country, poste_id, city, nom, programme, archetype,
                                   created_at, topic_id)
  VALUES (v_id, v_pays, p_poste, v_ville, v_nom, v_contenu, v_fiche.archetype, now(), v_topic);

  PERFORM set_config('rp.programme_officiel', '1', true);
  INSERT INTO public.forum_topics
    (id, forum_id, title, author, country, time, views, replies, last_post_author, last_post_time,
     author_is_org, author_secret)
  VALUES (v_topic, v_forum, v_titre, v_nom, v_pays, v_temps, 1, 0, v_nom, v_temps, false, false)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.forum_posts (id, topic_id, author, content, time)
  VALUES (v_topic || '-prog', v_topic, v_nom, v_contenu, v_temps)
  ON CONFLICT (id) DO NOTHING;
  PERFORM set_config('rp.programme_officiel', '0', true);

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'topic_id', v_topic, 'forum', v_forum,
                            'poste', p_poste, 'city', v_ville, 'pa', v_paiement->'pa');
END; $$;

REVOKE ALL ON FUNCTION public.candidature_publier(text, text, numeric, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.candidature_publier(text, text, numeric, text, text) TO authenticated;

-- UN FAUX PROGRAMME OFFICIEL EST IMPOSSIBLE : l'identifiant reserve n'est inscriptible que par
-- la fonction ci-dessus. Sans cela, n'importe qui pourrait fabriquer le sujet qu'un calendrier
-- irait ensuite presenter comme le programme d'un candidat.
CREATE OR REPLACE FUNCTION public.forum_verrou_programme_officiel()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  IF coalesce(current_setting('rp.programme_officiel', true), '') = '1' THEN RETURN NEW; END IF;
  IF NEW.id LIKE 'topic-programme-%' THEN RETURN NULL; END IF;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_forum_verrou_programme ON public.forum_topics;
CREATE TRIGGER trg_forum_verrou_programme
  BEFORE INSERT ON public.forum_topics
  FOR EACH ROW EXECUTE FUNCTION public.forum_verrou_programme_officiel();