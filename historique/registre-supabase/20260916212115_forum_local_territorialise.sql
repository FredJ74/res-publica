-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916212115
-- Nom original      : forum_local_territorialise
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 21:21:15 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : bd1204e83c450471175d8426ccdf3b92
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
-- LE FORUM LOCAL DEVIENT CELUI DE CHAQUE VILLE (16 septembre 2026).
--
-- LE DEFAUT. forum_id = 'local' etait un identifiant UNIQUE et GLOBAL : les trois villes de
-- Republia partageaient le meme « Forum Local », et un programme municipal de Montrouge
-- paraissait a cote de celui de Luthecia. La lecture (sbLoadForumTopics) ne filtre que sur
-- forum_id, et forum_topics n'a pas de colonne ville.
--
-- L'ARCHITECTURE RETENUE : 'local_<ville>', exactement le schema deja en place pour
-- 'tribunal_<ville>'. La cle territoriale est donc PERSISTEE dans la donnee elle-meme, et le
-- cloisonnement est acquis par la requete de lecture, pas par un filtre de confort cote client.
-- Rien n'est code pour Republia : la ville vient des donnees de jeu, si bien que Sovarka et
-- Krasnov fonctionneront sans une ligne de plus.
--
-- CE QUE LE SERVEUR GARANTIT. Un client ne peut pas publier dans le Local d'une autre ville : le
-- declencheur ci-dessous relit la ville du personnage de l'appelant et refuse toute insertion
-- dans un 'local_<autre ville>'. La lecture, elle, reste publique -- un forum de ville est un
-- lieu public du jeu, et l'ancien 'local' l'etait deja.
--
-- LES PROGRAMMES MUNICIPAUX suivent LA VILLE DU SCRUTIN, jamais celle ou se trouve le candidat
-- au moment ou il redige : c'est la juridiction de l'election qui fait foi.

CREATE OR REPLACE FUNCTION public.forum_verrou_local_territorial()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_acteur text; v_ville text; v_ville_sujet text;
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  -- Les publications institutionnelles passent par une RPC, qui pose ce laissez-passer.
  IF coalesce(current_setting('rp.publication_ligue', true), '') = '1'
     OR coalesce(current_setting('rp.programme_officiel', true), '') = '1' THEN
    RETURN NEW;
  END IF;
  IF NEW.forum_id IS NULL OR NEW.forum_id NOT LIKE 'local\_%' THEN RETURN NEW; END IF;

  v_acteur := public.mon_personnage();
  IF v_acteur IS NULL THEN RETURN NULL; END IF;
  SELECT current_city INTO v_ville FROM public.personnages_donnees WHERE name = v_acteur;
  v_ville_sujet := substring(NEW.forum_id from 7);      -- ce qui suit 'local_'

  -- On ne publie que dans le Local de la ville ou l'on se trouve reellement.
  IF coalesce(v_ville, '') IS DISTINCT FROM coalesce(v_ville_sujet, '') THEN
    RETURN NULL;
  END IF;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_forum_local_territorial ON public.forum_topics;
CREATE TRIGGER trg_forum_local_territorial
  BEFORE INSERT ON public.forum_topics
  FOR EACH ROW EXECUTE FUNCTION public.forum_verrou_local_territorial();

-- La publication d'un programme municipal vise le Local de la ville DU SCRUTIN.
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

  IF coalesce(v_fiche.domicile->>'country', v_pays) IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'non_domicilie');
  END IF;
  v_inf := CASE WHEN jsonb_typeof(v_fiche.resources->'inf') = 'number'
                THEN (v_fiche.resources->>'inf')::numeric ELSE 0 END;
  IF v_inf < v_poste.min_inf THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'influence_insuffisante',
                              'requis', v_poste.min_inf, 'reel', v_inf);
  END IF;
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

  v_ville := CASE WHEN v_poste.niveau = 'ville' THEN nullif(p_city, '') ELSE NULL END;
  v_cle := p_poste || CASE WHEN v_ville IS NOT NULL THEN '_' || v_ville ELSE '' END;
  v_id := v_pays || '_' || v_cle || '_' || v_nom
          || CASE WHEN p_cle_scrutin IS NOT NULL THEN '_' || p_cle_scrutin::bigint::text ELSE '' END;

  IF EXISTS (SELECT 1 FROM public.candidatures WHERE id = v_id) THEN
    RETURN jsonb_build_object('ok', true, 'deja_candidat', true, 'id', v_id,
                              'topic_id', (SELECT topic_id FROM public.candidatures WHERE id = v_id));
  END IF;

  v_paiement := public.payer_ordre(v_nom, 'deposer_candidature', 2, 0);
  IF NOT coalesce((v_paiement->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paiement->>'raison', 'paiement_refuse'));
  END IF;

  v_contenu := coalesce(nullif(btrim(p_contenu), ''), '(programme vide)');
  v_titre := coalesce(nullif(btrim(p_titre), ''),
                      '🗳️ Programme de ' || v_nom || ' — ' || v_poste.nom);
  v_topic := 'topic-programme-' || v_id;
  -- LE FORUM DE LA JURIDICTION DU SCRUTIN. Un scrutin de ville publie dans le Local de CETTE
  -- ville -- pas celui ou le candidat se trouve ; un scrutin national publie au National.
  v_forum := CASE WHEN v_poste.niveau = 'ville' AND v_ville IS NOT NULL
                  THEN 'local_' || v_ville ELSE 'national' END;
  v_temps := to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY" · "HH24"h"MI');

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