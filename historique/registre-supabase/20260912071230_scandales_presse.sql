-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260912071230
-- Nom original      : scandales_presse
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-12 07:12:30 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : e79201d3b2a1db7fe7d1ca4d5fb9bf40
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
-- FABRIQUER UN SCANDALE -- KOMPROMAT (12 septembre 2026)
-- Contrairement a « Produire une fuite » (fait illegal reel, commanditaire secret), le scandale
-- repose sur une accusation fournie par le joueur, et SON AUTEUR EST PUBLIC. Il n'y a donc plus rien
-- a « detecter » : l'ancienne detection automatique et les mandats automatiques disparaissent.
-- L'illegalite viendra plus tard d'une plainte en diffamation de la victime -- ce chantier ne
-- construit PAS ce mecanisme, il persiste seulement tout ce qu'il faudra pour le rattacher.

-- Une seule tentative par jour REEL (Europe/Paris, DST-safe) et par auteur. La tentative est
-- consommee meme si la redaction refuse : c'est la cle primaire qui le garantit, donc aussi contre
-- le double-clic, la concurrence et un client modifie.
CREATE TABLE IF NOT EXISTS public.scandales_tentatives (
  auteur     text NOT NULL,
  jour_paris date NOT NULL,
  cible      text,
  accepte    boolean NOT NULL DEFAULT false,
  cree_le    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (auteur, jour_paris)
);
ALTER TABLE public.scandales_tentatives ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.scandales_tentatives FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.scandales_tentatives TO anon, authenticated;
DROP POLICY IF EXISTS scandales_tentatives_lecture ON public.scandales_tentatives;
CREATE POLICY scandales_tentatives_lecture ON public.scandales_tentatives FOR SELECT USING (true);

-- Tout ce qu'une future plainte en diffamation devra pouvoir citer.
CREATE TABLE IF NOT EXISTS public.scandales_presse (
  id            bigserial PRIMARY KEY,
  auteur        text NOT NULL,              -- PUBLIC : le commanditaire est assume
  cible         text NOT NULL,
  pays          text,
  ville         text,
  accusation    text NOT NULL,              -- texte fourni par le joueur, conserve tel quel
  article       text,                       -- redaction publiee
  chronique_id  text,                       -- reference de publication
  type_contenu  text NOT NULL DEFAULT 'kompromat',
  statut        text NOT NULL DEFAULT 'accepte',   -- accepte | publie | plainte_deposee | juge
  plainte_ref   text,                       -- rattachement d'une future plainte
  effet_applique boolean NOT NULL DEFAULT false,
  jour_paris    date NOT NULL,
  cree_le       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS scandales_presse_cible ON public.scandales_presse (cible, cree_le DESC);
CREATE INDEX IF NOT EXISTS scandales_presse_auteur ON public.scandales_presse (auteur, cree_le DESC);
ALTER TABLE public.scandales_presse ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.scandales_presse FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.scandales_presse TO anon, authenticated;
DROP POLICY IF EXISTS scandales_presse_lecture ON public.scandales_presse;
CREATE POLICY scandales_presse_lecture ON public.scandales_presse FOR SELECT USING (true);

-- Taux d'acceptation : base 35, +15 carriere presse, sinon +10 ministre de l'Information, moins le
-- malus ISN de la ville, plancher 5. Le bonus est calcule ICI, sur les donnees enregistrees.
CREATE OR REPLACE FUNCTION public.scandale_taux(p_career text, p_poste jsonb, p_malus_isn integer)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT GREATEST(5, 35
    + CASE WHEN p_career = 'press' THEN 15
           WHEN COALESCE(p_poste ->> 'id', '') = 'min_info' THEN 10
           ELSE 0 END
    - LEAST(25, GREATEST(0, COALESCE(p_malus_isn, 0))))::integer;
$$;

CREATE OR REPLACE FUNCTION public.scandale_tenter(
  p_requete    text,
  p_joueur     text,
  p_cible      text,
  p_accusation text,
  p_malus_isn  integer DEFAULT 0,
  p_instant    timestamptz DEFAULT now()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rej  jsonb;
  v_p    record;
  v_c    record;
  v_jour date;
  v_taux integer;
  v_jet  integer;
  v_id   bigint;
BEGIN
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_joueur, 'scandale');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF COALESCE(btrim(p_cible), '') = '' OR p_cible = p_joueur OR COALESCE(btrim(p_accusation), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'parametres_invalides'));
  END IF;

  SELECT pa, liquide, banque, career, poste, country, current_city INTO v_p
    FROM public.personnages WHERE name = p_joueur;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'joueur_introuvable'));
  END IF;
  SELECT country INTO v_c FROM public.personnages WHERE name = p_cible;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'cible_introuvable'));
  END IF;

  -- Ressources verifiees AVANT le jet : une acceptation ne doit jamais conduire a un etat impossible.
  IF COALESCE(v_p.pa, 0) < 3 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'));
  END IF;
  IF COALESCE(v_p.liquide, 0) + COALESCE(v_p.banque, 0) < 800 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'));
  END IF;

  v_jour := (p_instant AT TIME ZONE 'Europe/Paris')::date;
  -- La tentative quotidienne est consommee ici, avant meme le jet : refus de la redaction compris.
  INSERT INTO public.scandales_tentatives (auteur, jour_paris, cible)
  VALUES (p_joueur, v_jour, p_cible)
  ON CONFLICT (auteur, jour_paris) DO NOTHING;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_tente_aujourdhui'));
  END IF;

  v_taux := public.scandale_taux(v_p.career, v_p.poste, p_malus_isn);
  v_jet := floor(random() * 100)::integer + 1;
  IF v_jet > v_taux THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', true, 'accepte', false, 'jet', v_jet, 'taux', v_taux));
  END IF;

  INSERT INTO public.scandales_presse (auteur, cible, pays, ville, accusation, jour_paris)
  VALUES (p_joueur, p_cible, v_c.country, v_p.current_city, btrim(p_accusation), v_jour)
  RETURNING id INTO v_id;
  UPDATE public.scandales_tentatives SET accepte = true WHERE auteur = p_joueur AND jour_paris = v_jour;

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'accepte', true, 'jet', v_jet, 'taux', v_taux,
    'scandale_id', v_id, 'pa', 3, 'cout', 800));
END;
$$;

-- Publication : enregistre l'article, depose le fait dans chronique_nationale (auteur PUBLIC) et
-- applique POP -15 / INF -15 a la cible, une seule fois, via la RPC atomique deja en place.
CREATE OR REPLACE FUNCTION public.scandale_publier(p_scandale_id bigint, p_article text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_s    record;
  v_cid  text;
  v_eff  jsonb := NULL;
  v_n    integer;
BEGIN
  SELECT * INTO v_s FROM public.scandales_presse WHERE id = p_scandale_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scandale_introuvable');
  END IF;
  IF v_s.chronique_id IS NOT NULL THEN
    SELECT count(*) INTO v_n FROM public.scandales_presse WHERE auteur = v_s.auteur AND chronique_id IS NOT NULL;
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'chronique_id', v_s.chronique_id, 'total_auteur', v_n);
  END IF;

  v_cid := 'chronique-scandale-' || p_scandale_id::text;
  BEGIN
    INSERT INTO public.chronique_nationale (id, country, city, type, personnages, libelle, data, source_ref)
    VALUES (v_cid, v_s.pays, v_s.ville, 'scandale_presse',
            jsonb_build_array(v_s.cible, v_s.auteur),
            COALESCE(NULLIF(btrim(p_article), ''), v_s.accusation),
            jsonb_build_object('cible', v_s.cible, 'auteur', v_s.auteur, 'auteur_public', v_s.auteur,
                               'type_contenu', 'kompromat', 'accusation', v_s.accusation,
                               'scandale_id', p_scandale_id),
            'scandale-' || p_scandale_id::text);
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;

  IF NOT v_s.effet_applique THEN
    v_eff := public.personnage_ajuster_pop_inf(v_s.cible, -15, -15);
  END IF;

  UPDATE public.scandales_presse
     SET article = COALESCE(NULLIF(btrim(p_article), ''), article),
         chronique_id = v_cid, statut = 'publie', effet_applique = true
   WHERE id = p_scandale_id;

  SELECT count(*) INTO v_n FROM public.scandales_presse WHERE auteur = v_s.auteur AND chronique_id IS NOT NULL;
  RETURN jsonb_build_object('ok', true, 'chronique_id', v_cid, 'effet', v_eff, 'total_auteur', v_n);
END;
$$;

REVOKE ALL ON FUNCTION public.scandale_taux(text, jsonb, integer)                                   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.scandale_tenter(text, text, text, text, integer, timestamptz)        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.scandale_publier(bigint, text)                                       FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.scandale_taux(text, jsonb, integer)                                TO service_role;
GRANT EXECUTE ON FUNCTION public.scandale_tenter(text, text, text, text, integer, timestamptz)     TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.scandale_publier(bigint, text)                                    TO anon, authenticated, service_role;