-- =====================================================================
-- PRODUIRE UNE FUITE -- NOUVELLE MECANIQUE (12 septembre 2026)
-- =====================================================================
-- L'ancienne mecanique est abandonnee : elle inventait une rumeur par IA, annoncait -10 INF/-10 POP
-- qu'elle n'appliquait a personne, envoyait un « mail a la cible » qui partait en realite au
-- lanceur, et appelait une detection judiciaire inoperante.
--
-- La nouvelle repose UNIQUEMENT sur les traces d'actions illegales reellement enregistrees :
--   - personnages.historique_crimes (traces privees du personnage, client ou serveur) ;
--   - actions_tracables (traces publiques/objectives).
-- Sont eligibles les traces qu'elles aient ou non ete decouvertes par la justice : une fuite peut
-- reveler une affaire que la justice n'a jamais vue.
--
-- REGLE FERME : une trace ne peut fuiter qu'UNE SEULE FOIS. La trace elle-meme n'est ni modifiee ni
-- supprimee -- elle reste disponible pour une enquete ou une procedure. C'est un REGISTRE SEPARE
-- (cette table) qui memorise qu'elle a deja fait l'objet d'une fuite. L'unicite est portee par une
-- contrainte UNIQUE : deux clics simultanes ne peuvent pas publier deux fois la meme trace.
--
-- SECRET DES SOURCES : l'auteur est enregistre pour l'audit mais n'est JAMAIS publie. La
-- publication est attribuee a « Cellule enquete de la redaction ». Aucune detection du
-- commanditaire, aucune consequence judiciaire pour lui.
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.fuites_journalistiques (
  id           bigserial PRIMARY KEY,
  trace_cle    text NOT NULL UNIQUE,        -- identite stable de la trace : une fuite par trace
  source       text NOT NULL CHECK (source IN ('historique_crimes', 'actions_tracables')),
  cible        text NOT NULL,               -- le PJ dont l'affaire est revelee
  auteur       text NOT NULL,               -- commanditaire : audit uniquement, jamais publie
  faits        jsonb NOT NULL,              -- les faits bruts de la trace, seule source du texte
  pays         text,
  ville        text,
  contenu      text,                        -- redaction journalistique, ecrite juste apres
  chronique_id text,                        -- ligne chronique_nationale correspondante
  cree_le      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS fuites_journalistiques_cible ON public.fuites_journalistiques (cible, cree_le DESC);
ALTER TABLE public.fuites_journalistiques ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.fuites_journalistiques FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.fuites_journalistiques TO anon, authenticated;
DROP POLICY IF EXISTS fuites_journalistiques_lecture ON public.fuites_journalistiques;
CREATE POLICY fuites_journalistiques_lecture ON public.fuites_journalistiques FOR SELECT USING (true);
-- Aucune politique d'ecriture : seules les fonctions SECURITY DEFINER ci-dessous ecrivent.

-- ------------------------------------------------------------------ TRACES ELIGIBLES
-- Vue unifiee des traces d'actions illegales d'un personnage, quelle que soit leur origine, avec
-- une cle stable. Les traces DEJA fuitees sont exclues ici meme : c'est la seule definition de
-- l'eligibilite, partagee par la reservation et par les tests.
CREATE OR REPLACE FUNCTION public.fuite_traces_eligibles(p_cible text)
RETURNS TABLE (trace_cle text, source text, faits jsonb)
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  WITH hist AS (
    SELECT
      'historique_crimes:' || md5(p_cible || '|' || COALESCE(t.value ->> 'id', '')
        || '|' || COALESCE(t.value ->> 'acte', '') || '|' || COALESCE(t.value ->> 'cible', '')
        || '|' || COALESCE(t.value ->> 'jour', '') || '|' || COALESCE(t.value ->> 'ts', '')) AS trace_cle,
      'historique_crimes'::text AS source,
      jsonb_build_object(
        'acte', t.value ->> 'acte',
        'victime', t.value ->> 'cible',
        'jour', t.value -> 'jour',
        'categorie', t.value ->> 'categorie',
        'quantite', t.value -> 'quantite',
        'loi', t.value ->> 'loiTitre',
        'origine', COALESCE(t.value ->> 'origine', 'personnage'),
        'decouverte_justice', false) AS faits
      FROM public.personnages p
      CROSS JOIN LATERAL jsonb_array_elements(
        CASE WHEN jsonb_typeof(p.historique_crimes) = 'array' THEN p.historique_crimes ELSE '[]'::jsonb END) AS t(value)
     WHERE p.name = p_cible AND COALESCE(t.value ->> 'acte', '') <> ''
  ), publiques AS (
    SELECT
      'actions_tracables:' || a.id AS trace_cle,
      'actions_tracables'::text AS source,
      jsonb_build_object(
        'acte', a.type_action,
        'victime', a.cible,
        'jour', a.jour,
        'ville', a.city,
        'origine', 'action_tracable',
        'decouverte_justice', COALESCE(a.decouvert, false)) AS faits
      FROM public.actions_tracables a
     WHERE a.auteur = p_cible AND COALESCE(a.type_action, '') <> ''
  ), toutes AS (
    SELECT * FROM hist UNION ALL SELECT * FROM publiques
  )
  SELECT t.trace_cle, t.source, t.faits
    FROM toutes t
   WHERE NOT EXISTS (SELECT 1 FROM public.fuites_journalistiques f WHERE f.trace_cle = t.trace_cle);
$$;

-- ------------------------------------------------------------------ RESERVATION
-- Choisit UNE trace eligible au hasard et la reserve. p_instant n'existe pas : rien ici ne depend
-- de l'heure. Idempotent sur l'id de requete (un rejeu renvoie le meme resultat, sans seconde
-- reservation). Le verrou par cible serialise deux demandes simultanees ; la contrainte UNIQUE
-- reste le dernier rempart, meme entre deux cibles differentes portant la meme trace.
CREATE OR REPLACE FUNCTION public.fuite_reserver(p_requete text, p_joueur text, p_cible text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rej   jsonb;
  v_p     record;
  v_c     record;
  v_t     record;
  v_id    bigint;
BEGIN
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_joueur, 'fuite');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF COALESCE(btrim(p_cible), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'cible_invalide'));
  END IF;

  SELECT pa, country, current_city INTO v_p FROM public.personnages WHERE name = p_joueur;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'joueur_introuvable'));
  END IF;
  SELECT country INTO v_c FROM public.personnages WHERE name = p_cible;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'cible_introuvable'));
  END IF;
  -- 2 PA, verifies sur les PA ENREGISTRES : le client les debite au lancement de l'action.
  IF COALESCE(v_p.pa, 0) < 2 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'));
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('fuite|' || p_cible));

  SELECT * INTO v_t FROM public.fuite_traces_eligibles(p_cible) ORDER BY random() LIMIT 1;
  IF NOT FOUND THEN
    -- Aucune trace exploitable : l'enquete n'a rien trouve. Les PA restent consommes, et AUCUNE
    -- affaire n'est inventee.
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', true, 'trouve', false));
  END IF;

  INSERT INTO public.fuites_journalistiques (trace_cle, source, cible, auteur, faits, pays, ville)
  VALUES (v_t.trace_cle, v_t.source, p_cible, p_joueur, v_t.faits, v_c.country, v_p.current_city)
  ON CONFLICT (trace_cle) DO NOTHING
  RETURNING id INTO v_id;
  IF v_id IS NULL THEN
    -- Une autre demande vient de reserver cette trace : rien n'est publie deux fois.
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', true, 'trouve', false, 'raison', 'trace_deja_prise'));
  END IF;

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'trouve', true, 'fuite_id', v_id, 'source', v_t.source, 'faits', v_t.faits, 'cible', p_cible));
END;
$$;

-- ------------------------------------------------------------------ PUBLICATION
-- Enregistre la redaction et depose le fait dans chronique_nationale, le point d'entree editorial
-- deja lu par la collecte du Journal. L'auteur public est la redaction : le commanditaire n'apparait
-- nulle part. Rejouable sans doublon (la ligne de chronique n'est ecrite qu'une fois).
CREATE OR REPLACE FUNCTION public.fuite_publier(p_fuite_id bigint, p_contenu text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_f    record;
  v_cid  text;
BEGIN
  SELECT * INTO v_f FROM public.fuites_journalistiques WHERE id = p_fuite_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fuite_introuvable');
  END IF;
  IF v_f.chronique_id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'chronique_id', v_f.chronique_id);
  END IF;

  v_cid := 'chronique-fuite-' || p_fuite_id::text;
  BEGIN
    INSERT INTO public.chronique_nationale (id, country, city, type, personnages, libelle, data, source_ref)
    VALUES (v_cid, v_f.pays, v_f.ville, 'fuite_journalistique',
            jsonb_build_array(v_f.cible),
            COALESCE(NULLIF(btrim(p_contenu), ''), 'Révélations concernant ' || v_f.cible || '.'),
            jsonb_build_object('cible', v_f.cible, 'source', v_f.source, 'faits', v_f.faits,
                               'auteur_public', 'Cellule enquête de la rédaction'),
            'fuite-' || p_fuite_id::text);
  EXCEPTION WHEN unique_violation THEN
    NULL;   -- deja deposee : on garde la ligne existante
  END;

  UPDATE public.fuites_journalistiques
     SET contenu = COALESCE(NULLIF(btrim(p_contenu), ''), contenu), chronique_id = v_cid
   WHERE id = p_fuite_id;

  RETURN jsonb_build_object('ok', true, 'chronique_id', v_cid);
END;
$$;

REVOKE ALL ON FUNCTION public.fuite_traces_eligibles(text)        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fuite_reserver(text, text, text)    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fuite_publier(bigint, text)         FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fuite_traces_eligibles(text)      TO service_role;
GRANT EXECUTE ON FUNCTION public.fuite_reserver(text, text, text)  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fuite_publier(bigint, text)       TO anon, authenticated, service_role;
