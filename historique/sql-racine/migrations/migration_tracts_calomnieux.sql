-- =====================================================================
-- TRACTS CALOMNIEUX -- MECANIQUE DE PERSUASION INDIVIDUELLE (12 septembre 2026)
-- =====================================================================
-- Regles fixees (a ne pas rediscuter) :
--   - un tract calomnieux n'est PAS un tract electoral : aucun lien avec un scrutin, utilisable en
--     permanence, contre n'importe quel PJ (candidat ou non, absent, autre ville, autre empire) ;
--   - chaque tentative = 1 tract + 1 PA + 1 PNJ precis + 1 jet ;
--   - taux = 45 + CHA + floor(INF/4) - 2 x max(0, VOL_PNJ - 10), borne [0, 85], VOL_PNJ = 10 par
--     defaut (meme fonction que les tracts electoraux, aucune formule dupliquee) ;
--   - reussite : POP -5 ET INF -2 sur le PJ cible, bornes [0, 100], en une seule ecriture atomique ;
--   - une reussite verrouille le triplet PNJ x cible x jour (heure de Paris) : ce PNJ ne peut plus
--     etre convaincu contre CETTE cible aujourd'hui, mais reste disponible contre une autre cible,
--     et redevient disponible le lendemain ;
--   - echec normal : aucun effet, tract et PA consommes, le meme PNJ est immediatement retentable ;
--   - echec critique = 10 % des ECHECS (et non 10 % des tentatives) : aucun effet, tract et PA
--     consommes, le calomnieur est identifie et poursuivi ;
--   - juridiction competente = pays de RESIDENCE DU PJ VICTIME AU MOMENT DES FAITS, gele dans
--     l'affaire. Aucune extradition automatique ; un changement ulterieur de residence de la victime
--     ne deplace pas l'affaire.
--
-- Traitement judiciaire, sans seconde justice : le jeu possede deja deux mecanismes et un seul est
-- retenu par acte.
--   a) faits commis DANS le pays competent : flagrant delit immediat, exactement le circuit
--      preexistant (destruction des lots detenus + 1 jour de detention + registre detentions).
--      C'est le client qui l'execute, comme aujourd'hui ; la RPC se contente de le prescrire.
--   b) faits commis HORS du pays competent : aucune arrestation sur place (regle fixee), la RPC
--      inscrit un mandat dans personnages.recherche avec country = pays competent. Les mecanismes
--      ordinaires (verifierArrestationRecherchePolice, chasse a l'homme) filtrent deja sur ce
--      champ : le calomnieur ne risque rien la ou il est, et peut etre arrete s'il entre dans le
--      pays competent. Un seul des deux traitements est applique par acte.
-- =====================================================================

-- ------------------------------------------------------------------ 1. INF EN DELTA
-- Extension du trigger de fusion existant (POP) a l'influence : le tract calomnieux la modifie
-- desormais cote serveur, une sauvegarde cliente ancienne ne doit pas plus l'ecraser que la POP.
-- Meme contrat : resources.infBase = derniere INF envoyee par ce client, jamais stockee.
CREATE OR REPLACE FUNCTION public.personnages_fusionner_pop()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_base numeric;
  v_old  numeric;
BEGIN
  IF jsonb_typeof(NEW.resources) = 'object' AND NEW.resources ? 'popBase' THEN
    v_base := CASE WHEN jsonb_typeof(NEW.resources -> 'popBase') = 'number' THEN (NEW.resources ->> 'popBase')::numeric END;
    NEW.resources := NEW.resources - 'popBase';   -- jamais stocke
    IF TG_OP = 'UPDATE' AND v_base IS NOT NULL AND jsonb_typeof(NEW.resources -> 'pop') = 'number' THEN
      v_old := CASE WHEN jsonb_typeof(OLD.resources -> 'pop') = 'number' THEN (OLD.resources ->> 'pop')::numeric ELSE v_base END;
      -- Valeur courante de la base + ce que CE client a change depuis sa derniere sauvegarde.
      NEW.resources := jsonb_set(NEW.resources, '{pop}',
        to_jsonb(GREATEST(0, LEAST(100, v_old + ((NEW.resources ->> 'pop')::numeric - v_base)))));
    END IF;
  END IF;
  IF jsonb_typeof(NEW.resources) = 'object' AND NEW.resources ? 'infBase' THEN
    v_base := CASE WHEN jsonb_typeof(NEW.resources -> 'infBase') = 'number' THEN (NEW.resources ->> 'infBase')::numeric END;
    NEW.resources := NEW.resources - 'infBase';   -- jamais stocke
    IF TG_OP = 'UPDATE' AND v_base IS NOT NULL AND jsonb_typeof(NEW.resources -> 'inf') = 'number' THEN
      v_old := CASE WHEN jsonb_typeof(OLD.resources -> 'inf') = 'number' THEN (OLD.resources ->> 'inf')::numeric ELSE v_base END;
      NEW.resources := jsonb_set(NEW.resources, '{inf}',
        to_jsonb(GREATEST(0, LEAST(100, v_old + ((NEW.resources ->> 'inf')::numeric - v_base)))));
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.personnages_fusionner_pop() FROM PUBLIC, anon, authenticated;

-- ------------------------------------------------------------------ 2. REGISTRE DES ACTES
-- Une ligne par tentative reelle (reussite, echec, echec critique) : c'est a la fois le verrou
-- PNJ x cible x jour, la trace de l'acte et la juridiction gelee.
CREATE TABLE IF NOT EXISTS public.calomnies_actes (
  id             bigserial PRIMARY KEY,
  auteur         text NOT NULL,
  cible          text NOT NULL,              -- PJ vise par la calomnie
  pnj_cle        text NOT NULL,              -- '<pays>:<ville>:<nom normalise>'
  pnj_nom        text NOT NULL,
  jour_paris     date NOT NULL,              -- jour calendaire de l'acte, heure de Paris
  resultat       text NOT NULL CHECK (resultat IN ('reussite', 'echec', 'echec_critique')),
  pays_faits     text,                       -- pays ou l'acte a ete commis
  ville_faits    text,
  pays_competent text NOT NULL,              -- residence de la victime AU MOMENT DES FAITS (gelee)
  jet            smallint,
  taux           smallint,
  cree_le        timestamptz NOT NULL DEFAULT now()
);
-- Le verrou du game design : une seule REUSSITE par PNJ, par cible et par jour.
CREATE UNIQUE INDEX IF NOT EXISTS calomnies_actes_verrou
  ON public.calomnies_actes (pnj_cle, cible, jour_paris) WHERE resultat = 'reussite';
CREATE INDEX IF NOT EXISTS calomnies_actes_cible ON public.calomnies_actes (cible, cree_le DESC);
ALTER TABLE public.calomnies_actes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.calomnies_actes FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.calomnies_actes TO anon, authenticated;
DROP POLICY IF EXISTS calomnies_actes_lecture ON public.calomnies_actes;
CREATE POLICY calomnies_actes_lecture ON public.calomnies_actes FOR SELECT USING (true);
-- Aucune politique d'ecriture : seule la fonction SECURITY DEFINER ci-dessous ecrit.

-- ------------------------------------------------------------------ 3. EFFET POP + INF ATOMIQUE
-- Un seul UPDATE, donc un seul verrou de ligne : deux calomnies simultanees se cumulent au lieu de
-- s'ecraser. Ne touche que resources.pop et resources.inf, jamais le reste du personnage, jamais
-- updated_at (ce n'est pas une sauvegarde).
CREATE OR REPLACE FUNCTION public.calomnie_appliquer_effet(p_cible text, p_pop integer, p_inf integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_res jsonb;
BEGIN
  UPDATE public.personnages
     SET resources = jsonb_set(
           jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END,
                     '{pop}', to_jsonb(GREATEST(0, LEAST(100,
                       COALESCE(CASE WHEN jsonb_typeof(resources -> 'pop') = 'number' THEN (resources ->> 'pop')::numeric END, 50) + p_pop)))),
           '{inf}', to_jsonb(GREATEST(0, LEAST(100,
             COALESCE(CASE WHEN jsonb_typeof(resources -> 'inf') = 'number' THEN (resources ->> 'inf')::numeric END, 0) + p_inf))))
   WHERE name = p_cible
   RETURNING resources INTO v_res;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;
  RETURN jsonb_build_object('ok', true, 'pop', v_res -> 'pop', 'inf', v_res -> 'inf');
END;
$$;

-- ------------------------------------------------------------------ 4. MANDAT DANS LE PAYS COMPETENT
-- Ecrit une entree de recherche sur le calomnieur, au format « condamnation » deja traite par
-- verifierArrestationRecherchePolice et par la chasse a l'homme, avec le champ country qui porte
-- toute la competence territoriale (ces deux mecanismes filtrent deja dessus : aucune extradition).
-- Append sous verrou de ligne : jamais une relecture/reecriture depuis un client.
CREATE OR REPLACE FUNCTION public.calomnie_inscrire_mandat(p_auteur text, p_cible text, p_pays text, p_ville_faits text, p_instant timestamptz)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_entree jsonb;
BEGIN
  v_entree := jsonb_build_object(
    'id', 'rech-calomnie-' || md5(p_auteur || '|' || p_cible || '|' || p_pays || '|' || extract(epoch FROM p_instant)::text),
    'type', 'condamnation',
    'origine', 'serveur',
    'country', p_pays,
    'motifs', jsonb_build_array(jsonb_build_object(
      'type', 'Distribution de tracts calomnieux',
      'jours', 1,
      'source', 'calomnie_juridiction_victime',
      'cible', p_cible,
      'city', p_ville_faits,
      'date_evenement', to_char(p_instant AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))),
    'issue_judiciaire', 'Mandat d''arret pour calomnie envers un resident (faits commis a l''etranger)',
    'autorite', 'Parquet',
    'jour_condamnation', null);
  UPDATE public.personnages
     SET recherche = CASE WHEN jsonb_typeof(recherche) = 'array' THEN recherche ELSE '[]'::jsonb END || v_entree
   WHERE name = p_auteur;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'auteur_introuvable');
  END IF;
  RETURN jsonb_build_object('ok', true, 'mandat', v_entree);
END;
$$;

-- ------------------------------------------------------------------ 5. MOTEUR
-- p_instant est injectable pour les tests ; jamais expose au client.
CREATE OR REPLACE FUNCTION public.calomnie_distribuer_interne(
  p_requete text,
  p_joueur  text,
  p_cible   text,
  p_pnj_nom text,
  p_vol_pnj integer,
  p_instant timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rej    jsonb;
  v_p      record;
  v_v      record;
  v_inv    jsonb;
  v_nom    text;
  v_cle    text;
  v_jour   date;
  v_pays   text;
  v_taux   integer;
  v_jet    integer;
  v_jet2   integer;
  v_effet  jsonb;
  v_mandat jsonb;
  v_res    text;
BEGIN
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_joueur, 'tract_calomnieux');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF COALESCE(btrim(p_cible), '') = '' OR p_cible = p_joueur THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'cible_invalide'));
  END IF;

  SELECT country, current_city, stats, resources, inventory, pa INTO v_p
    FROM public.personnages WHERE name = p_joueur;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'joueur_introuvable'));
  END IF;

  -- La cible est un PJ reel. Sa residence AU MOMENT DES FAITS fixe la juridiction, pour toujours.
  SELECT country, domicile INTO v_v FROM public.personnages WHERE name = p_cible;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'cible_introuvable'));
  END IF;
  v_pays := COALESCE(NULLIF(btrim(COALESCE(v_v.domicile ->> 'country', '')), ''), v_v.country);
  IF COALESCE(btrim(v_pays), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'juridiction_indeterminee'));
  END IF;

  -- Le joueur detient bien un lot de tracts calomnieux contre CETTE cible.
  v_inv := CASE WHEN jsonb_typeof(v_p.inventory) = 'array' THEN v_p.inventory ELSE '[]'::jsonb END;
  IF NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_inv) i
     WHERE i ->> 'type' = 'tract_calomnieux' AND i ->> 'cible' = p_cible
       AND jsonb_typeof(i -> 'quantite') = 'number' AND (i ->> 'quantite')::numeric >= 1
  ) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'tract_absent'));
  END IF;

  -- 1 PA par tentative individuelle (PA enregistres ; le client les debite a la tentative).
  IF COALESCE(v_p.pa, 0) < 1 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'));
  END IF;

  -- Identite du PNJ : meme normalisation que les tracts electoraux (pays + ville du joueur + nom).
  v_nom := public.tracts_electoraux_nom_pnj(p_pnj_nom);
  IF v_nom = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pnj_invalide'));
  END IF;
  v_cle := COALESCE(v_p.country, '') || ':' || COALESCE(v_p.current_city, '') || ':' || v_nom;
  v_jour := (p_instant AT TIME ZONE 'Europe/Paris')::date;

  -- Verrou du triplet : un seul joueur a la fois sur ce PNJ pour cette cible aujourd'hui.
  PERFORM pg_advisory_xact_lock(hashtext('calomnie|' || v_cle || '|' || p_cible || '|' || v_jour::text));
  IF EXISTS (SELECT 1 FROM public.calomnies_actes
              WHERE pnj_cle = v_cle AND cible = p_cible AND jour_paris = v_jour AND resultat = 'reussite') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_convaincu'));
  END IF;

  -- Jet : meme formule et meme fonction que les tracts electoraux.
  v_taux := public.tracts_electoraux_taux(
    public.assemblee_stat_base(v_p.stats, 'CHA'),
    CASE WHEN jsonb_typeof(v_p.resources -> 'inf') = 'number' THEN (v_p.resources ->> 'inf')::numeric ELSE 0 END,
    LEAST(30, GREATEST(0, COALESCE(p_vol_pnj, 10))));
  v_jet := floor(random() * 100)::integer + 1;

  IF v_jet <= v_taux THEN
    v_res := 'reussite';
  ELSE
    -- 10 % des ECHECS sont critiques (et non 10 % des tentatives).
    v_jet2 := floor(random() * 100)::integer + 1;
    v_res := CASE WHEN v_jet2 <= 10 THEN 'echec_critique' ELSE 'echec' END;
  END IF;

  INSERT INTO public.calomnies_actes (auteur, cible, pnj_cle, pnj_nom, jour_paris, resultat,
                                      pays_faits, ville_faits, pays_competent, jet, taux)
  VALUES (p_joueur, p_cible, v_cle, p_pnj_nom, v_jour, v_res,
          v_p.country, v_p.current_city, v_pays, v_jet, v_taux);

  IF v_res = 'reussite' THEN
    v_effet := public.calomnie_appliquer_effet(p_cible, -5, -2);
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', true, 'reussi', true, 'critique', false, 'consomme', 1, 'pa', 1,
      'jet', v_jet, 'taux', v_taux, 'pop', v_effet -> 'pop', 'inf', v_effet -> 'inf',
      'juridiction', v_pays));
  END IF;

  IF v_res = 'echec' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', true, 'reussi', false, 'critique', false, 'consomme', 1, 'pa', 1,
      'jet', v_jet, 'taux', v_taux, 'juridiction', v_pays));
  END IF;

  -- Echec critique : UNE seule procedure, choisie par la juridiction competente.
  IF v_pays IS NOT DISTINCT FROM v_p.country THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', true, 'reussi', false, 'critique', true, 'consomme', 1, 'pa', 1,
      'jet', v_jet, 'taux', v_taux, 'juridiction', v_pays, 'poursuite', 'flagrant_delit'));
  END IF;
  v_mandat := public.calomnie_inscrire_mandat(p_joueur, p_cible, v_pays, v_p.current_city, p_instant);
  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'reussi', false, 'critique', true, 'consomme', 1, 'pa', 1,
    'jet', v_jet, 'taux', v_taux, 'juridiction', v_pays, 'poursuite', 'mandat',
    -- L'entree elle-meme, pour que le client la reflete dans SON state.recherche : sans cela sa
    -- prochaine sauvegarde (qui reecrit recherche en entier) effacerait le mandat.
    'mandat', COALESCE(v_mandat -> 'mandat', 'null'::jsonb)));
END;
$$;

-- Point d'entree du client : instant = now(), rien d'autre ne change.
CREATE OR REPLACE FUNCTION public.calomnie_distribuer(
  p_requete text,
  p_joueur  text,
  p_cible   text,
  p_pnj_nom text,
  p_vol_pnj integer DEFAULT 10
)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.calomnie_distribuer_interne(p_requete, p_joueur, p_cible, p_pnj_nom, p_vol_pnj, now());
$$;

REVOKE ALL ON FUNCTION public.calomnie_appliquer_effet(text, integer, integer)                     FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.calomnie_inscrire_mandat(text, text, text, text, timestamptz)        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.calomnie_distribuer_interne(text, text, text, text, integer, timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.calomnie_distribuer(text, text, text, text, integer)                 FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.calomnie_appliquer_effet(text, integer, integer)                   TO service_role;
GRANT EXECUTE ON FUNCTION public.calomnie_inscrire_mandat(text, text, text, text, timestamptz)      TO service_role;
GRANT EXECUTE ON FUNCTION public.calomnie_distribuer_interne(text, text, text, text, integer, timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.calomnie_distribuer(text, text, text, text, integer)               TO anon, authenticated, service_role;
