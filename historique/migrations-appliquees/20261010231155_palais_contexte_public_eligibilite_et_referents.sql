-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261010231155 (UTC), nom `palais_contexte_public_eligibilite_et_referents`.
-- Le registre passe de 637 a 638 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 a6e242993c206875d8fad82052b34377, 16683 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- CE QU'ELLE FERME, ET POURQUOI C'EST UNE SEULE MIGRATION
--
-- Trois fermetures nees du MEME audit -- celui du Palais presidentiel --, et aucune propre au
-- Palais : c'est ce qui justifie de les tenir ensemble.
--
-- 1. LE CONTEXTE PUBLIC DU DIALOGUE. Aucun des 211 profils PNJ ne recevait la fonction de son
--    interlocuteur : le President PNJ ne pouvait pas savoir qu'il parlait au ministre de la
--    Defense, et Martial Bouterin pas davantage. `pnj_contexte_public()` est le TROISIEME canal
--    du dialogue, a cote de la memoire sociale et de la memoire pedagogique, et il ne rend que
--    le nom et les fonctions officielles ATTESTEES -- rien d'autre, la liste des exclusions est
--    ecrite dans le corps de la fonction pour qu'un ajout se voie dans un diff.
--
-- 2. L'ELIGIBILITE PRESIDENTIELLE AU SERVEUR. `candidature_deposer` -- le chemin REELLEMENT
--    emprunte -- ne verifiait ni l'influence minimale, ni la domiciliation, ni le cumul
--    president/maire : une candidature presidentielle a 0 INF passait par la console. Les trois
--    controles sont repris A LA LETTRE de `candidature_publier`, qui les appliquait deja sur
--    l'autre porte. Aucune regle neuve : la meme regle aux deux portes.
--
-- 3. LES QUATRE FONCTIONS DU PALAIS SONT DECLAREES, et trois de leurs PNJ deviennent des
--    referents a la liste fermee. Sans leur ligne, `referent_pedagogie_noter` rendait
--    « referent: false » sans rien ecrire : ils auraient eu une voix et aucun souvenir de ce
--    qu'ils ont deja explique.
--
-- UNE PREUVE A ETE CORRIGEE AVANT L'APPLICATION, et la lecon vaut d'etre gardee : P2 verifie que
-- le contexte public ne LIT aucune donnee interdite, en relisant `pg_proc.prosrc`. Or prosrc rend
-- le source COMMENTAIRES COMPRIS, et le commentaire qui enumere justement les champs interdits
-- faisait echouer la preuve sur sa propre documentation. On ne prouve pas une regle sur de la
-- prose : les lignes de commentaire sont desormais otees avant la comparaison.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- PALAIS PRESIDENTIEL -- LOT 1 : CE QU'UN PNJ SAIT, CE QUE LE SERVEUR EXIGE (10 octobre 2026)
-- =================================================================================================
-- Trois fermetures, toutes nees de l'audit du Palais presidentiel, et aucune propre au Palais :
--
-- 1. LE CONTEXTE PUBLIC DU DIALOGUE. L'audit a etabli qu'AUCUN des 180 PNJ ne recoit la fonction
--    de son interlocuteur : `api/chat.js` ne transmet qu'un identifiant de profil, et les deux
--    seuls contextes serveur -- `pnj_social_contexte` (rencontres, familiarite) et
--    `referent_pedagogie_contexte` (ce qui a deja ete explique) -- ne portent ni nom officiel ni
--    poste. Le President PNJ ne pouvait donc pas savoir qu'il parlait au Ministre de la Defense,
--    et Martial Bouterin pas davantage.
--    `pnj_contexte_public()` est le troisieme canal, GENERIQUE : il rend le NOM et la ou les
--    FONCTIONS OFFICIELLES de l'appelant, et RIEN D'AUTRE. Ni ville de domicile, ni carriere, ni
--    influence, ni popularite, ni condamnation, ni historique -- l'arbitrage est explicite sur ce
--    point, et la fonction est ecrite pour qu'un ajout futur soit un acte volontaire et visible.
--    Aucune rencontre prealable n'est requise : une fonction officielle est publique.
--
-- 2. L'ELIGIBILITE PRESIDENTIELLE EST VERIFIEE AU SERVEUR. `candidature_deposer` -- le chemin
--    REELLEMENT emprunte par le depot de candidature -- ne verifiait ni l'influence minimale, ni
--    la domiciliation, ni le cumul president/maire : les trois ne vivaient qu'au navigateur. Une
--    candidature presidentielle a 0 INF passait par la console. Les trois controles sont ajoutes,
--    repris A LA LETTRE de `candidature_publier`, qui les applique deja sur l'autre chemin (la
--    publication du programme au forum) : aucune regle nouvelle, la meme regle aux deux portes.
--    Le systeme electoral n'est pas touche : la Presidence reste un poste ELU, mandat de cinq
--    semaines, et une election presidentielle reste concurrentielle meme quand un PJ l'occupe.
--
-- 3. LES FONCTIONS PNJ DU PALAIS SONT DECLAREES. `president`, `secretaire_general`, `porteparole`
--    et `protocole` n'etaient dans aucune ligne de `pnj_fonctions` : ils etaient gamma par le
--    DEFAUT de `pnj_classe_decor`, jamais par declaration. Ce silence est ce qui a laisse le
--    President PNJ dans la liste des masques, alors que la table dit deja pour le Commissaire et
--    le Grand Pretre que « reprise de fonction n'est pas disparition ».
--    Trois des quatre deviennent en outre des REFERENTS : Huguette Papier (la Presidence et sa
--    memoire), le Porte-parole (la communication presidentielle) et Gerard Tamponneau (le
--    protocole). Un referent explique son domaine ; il ne detient aucun pouvoir du poste.
-- =================================================================================================

-- -------------------------------------------------------------------------------------------------
-- 1. LE CONTEXTE PUBLIC : NOM ET FONCTION OFFICIELLE, RIEN D'AUTRE
-- -------------------------------------------------------------------------------------------------
-- POURQUOI UNE FONCTION DEDIEE ET NON UN CHAMP AJOUTE A pnj_social_contexte. Les trois contextes
-- sont de natures differentes, et les melanger effacerait une distinction de game design :
--   . le contexte PUBLIC est un fait du monde -- tout le monde sait qui est ministre ;
--   . la memoire SOCIALE est une relation -- elle se construit, elle peut ne pas exister ;
--   . la memoire PEDAGOGIQUE est un historique d'explications -- elle appartient aux referents.
-- Un PNJ peut avoir le premier sans les deux autres, et c'est le cas de la quasi-totalite d'entre
-- eux.
--
-- LE DEPUTE EST UNE SECONDE FONCTION, PAS UN REMPLACEMENT : un ministre peut etre depute, et la
-- fiche porte les deux dans deux colonnes distinctes. Les deux sont donc rendues.
CREATE OR REPLACE FUNCTION public.pnj_contexte_public()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; f record; v_fonctions jsonb := '[]'::jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- LES POSTES SONT LUS SUR LA FICHE, et la fiche est ATTESTEE : le declencheur
  -- personnages_attester_poste refuse tout poste qui ne vient pas du depouillement, du registre
  -- des nominations ou de la compagnie. On ne peut donc pas se declarer ministre pour impressionner
  -- un PNJ.
  SELECT poste, poste_depute INTO f FROM public.personnages_donnees WHERE name = v_moi;

  IF f.poste IS NOT NULL AND jsonb_typeof(f.poste) = 'object'
     AND coalesce(f.poste->>'name', '') <> '' THEN
    v_fonctions := v_fonctions || jsonb_build_array(f.poste->>'name');
  END IF;
  IF f.poste_depute IS NOT NULL AND jsonb_typeof(f.poste_depute) = 'object'
     AND coalesce(f.poste_depute->>'name', '') <> '' THEN
    v_fonctions := v_fonctions || jsonb_build_array(f.poste_depute->>'name');
  END IF;

  -- CE QUE CETTE FONCTION NE RENDRA JAMAIS SANS UN ARBITRAGE EXPLICITE : la ville ou l on habite,
  -- la carriere, l influence, la popularite, les condamnations, l histoire personnelle, l argent
  -- et les possessions. La liste est ecrite ici pour qu'un ajout se voie dans un diff.
  RETURN jsonb_build_object('ok', true, 'nom', v_moi, 'fonctions', v_fonctions);
END;
$function$;

COMMENT ON FUNCTION public.pnj_contexte_public() IS
  'Contexte PUBLIC de l appelant pour un dialogue PNJ : son nom et ses fonctions officielles attestees, rien d autre. Troisieme canal, distinct de la memoire sociale et de la memoire pedagogique (arbitrage du 10 octobre 2026).';

REVOKE ALL ON FUNCTION public.pnj_contexte_public() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pnj_contexte_public() TO authenticated;
GRANT EXECUTE ON FUNCTION public.pnj_contexte_public() TO service_role;

-- -------------------------------------------------------------------------------------------------
-- 2. L'ELIGIBILITE, A LA PORTE REELLEMENT EMPRUNTEE
-- -------------------------------------------------------------------------------------------------
-- Les trois controles sont copies de candidature_publier, dans le meme ordre et avec les memes
-- raisons rendues, pour qu'un refus se lise pareil des deux cotes. Ils viennent AVANT toute
-- ecriture : un refus n'ecrit rien, pas meme la ligne attestee.
CREATE OR REPLACE FUNCTION public.candidature_deposer(p_poste text, p_city text, p_cle_scrutin numeric, p_candidat jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_cle text; v_id_cand text; v_id_cycle text;
  v_data jsonb; v_cands jsonb; v_n integer; v_city text;
  v_fiche record; v_poste record; v_inf numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF p_candidat IS NULL OR jsonb_typeof(p_candidat) <> 'object'
     OR coalesce(p_candidat ->> 'nom', '') <> v_moi THEN
    -- ON NE SE PORTE CANDIDAT QUE POUR SOI. Le client transmettait son propre nom dans l'objet :
    -- le serveur le relit, et refuse qu'il en nomme un autre.
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_nom');
  END IF;

  SELECT * INTO v_fiche FROM public.personnages_donnees WHERE name = v_moi;
  v_pays := v_fiche.country;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_inconnu');
  END IF;

  -- L'ELIGIBILITE EST DESORMAIS VERIFIEE ICI (10 octobre 2026). Elle ne vivait qu'au navigateur
  -- sur ce chemin : une candidature presidentielle a 0 INF passait par la console. Les trois
  -- regles sont celles de candidature_publier, a la lettre.
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

  -- LA CLE DU CYCLE EST CELLE DU CLIENT, A LA LETTRE : <poste> ou <poste>_<ville>. Elle est
  -- reconstruite ici, et non recue, pour qu'un client ne puisse pas viser un autre scrutin.
  v_city := nullif(btrim(coalesce(p_city, '')), '');
  v_cle := p_poste || CASE WHEN v_city IS NOT NULL THEN '_' || v_city ELSE '' END;
  v_id_cycle := v_pays || '_' || v_cle;

  SELECT c.data::jsonb INTO v_data FROM public.cycles_electoraux c
   WHERE c.id = v_id_cycle FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cycle_introuvable', 'cle', v_id_cycle);
  END IF;

  v_cands := CASE WHEN jsonb_typeof(v_data -> 'candidats') = 'array'
                  THEN v_data -> 'candidats' ELSE '[]'::jsonb END;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_cands) e WHERE e ->> 'nom' = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_candidat');
  END IF;

  v_id_cand := v_pays || '_' || v_cle || '_' || v_moi
    || CASE WHEN p_cle_scrutin IS NOT NULL THEN '_' || trim(to_char(p_cle_scrutin, 'FM999999999999999'))
            ELSE '' END;

  INSERT INTO public.candidatures (id, country, poste_id, city, nom, programme, archetype, created_at)
  VALUES (v_id_cand, v_pays, p_poste, v_city, v_moi,
          p_candidat ->> 'programme', p_candidat ->> 'archetype', now())
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_candidat');
  END IF;

  -- LE BULLETIN, DANS LA MEME TRANSACTION QUE LA LIGNE ATTESTEE.
  v_data := jsonb_set(v_data, '{candidats}', v_cands || jsonb_build_array(p_candidat), true);
  UPDATE public.cycles_electoraux SET data = v_data::text, updated_at = now()
   WHERE id = v_id_cycle;

  RETURN jsonb_build_object('ok', true, 'id', v_id_cand, 'cycle', v_data);
END;
$function$;

-- -------------------------------------------------------------------------------------------------
-- 3. LES QUATRE FONCTIONS DU PALAIS, DECLAREES
-- -------------------------------------------------------------------------------------------------
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES
  ('president', 'gamma', false, false, 'institutionnel',
   'Gamma fixe, fonction remplacable par un PJ. Le President PNJ RESTE present si un joueur est elu : il devient Secretaire general adjoint de la Presidence. Existence et titularite sont deux choses -- meme principe que le Commissaire et le Grand Pretre. Le titre affiche est recalcule a l entree dans la piece.'),
  ('secretaire_general', 'gamma', false, false, 'referent',
   'Huguette Papier, Secretaire generale de la Presidence. Gamma fixe et REFERENTE : la Presidence, ses pouvoirs reels et leurs limites, et la memoire des mandats. Aucune autorite : elle conseille, elle ne decide pas.'),
  ('porteparole', 'gamma', false, false, 'referent',
   'Porte-parole presidentiel, en Salle de presse. Gamma fixe et REFERENT de la COMMUNICATION presidentielle : conference de presse, propagande d Etat, dementi. Les ordres restent exerces par le President. Ne pas en faire un referent de toute la politique.'),
  ('protocole', 'gamma', false, false, 'referent',
   'Gerard Tamponneau, Chef du protocole presidentiel. Gamma fixe et REFERENT du protocole, des receptions, de l art de recevoir et de la diplomatie. Il n explique pas la communication presidentielle : il y envoie.')
ON CONFLICT (fonction) DO UPDATE
   SET classe_decor = EXCLUDED.classe_decor, metier_beta = EXCLUDED.metier_beta,
       recrutable = EXCLUDED.recrutable, role_fonctionnel = EXCLUDED.role_fonctionnel,
       note = EXCLUDED.note;

-- LES TROIS REFERENTS DU PALAIS REJOIGNENT LA LISTE FERMEE. Sans leur ligne,
-- referent_pedagogie_noter rend « referent: false » sans rien ecrire : ils auraient une voix et
-- aucun souvenir de ce qu'ils ont deja explique (meme piege qu'au Commandant Tom Hawak).
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES
  ('huguette_papier',  'presidence — pouvoirs, limites et memoire des mandats', 'republic'),
  ('porte_parole_presidentiel', 'communication presidentielle', 'republic'),
  ('gerard_tamponneau', 'protocole, receptions et diplomatie', 'republic')
ON CONFLICT (referent_id) DO UPDATE
   SET domaine = EXCLUDED.domaine, pays = EXCLUDED.pays;

-- -------------------------------------------------------------------------------------------------
-- PREUVES STRUCTURELLES
-- -------------------------------------------------------------------------------------------------
DO $$
DECLARE v_n integer;
BEGIN
  -- P1 : le canal public existe, est SECURITY DEFINER a search_path fige, et ouvert au navigateur.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'pnj_contexte_public' AND p.prosecdef
     AND array_to_string(coalesce(p.proconfig,'{}'), ',') LIKE '%search_path%'
     AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
     AND NOT has_function_privilege('anon', p.oid, 'EXECUTE');
  IF v_n <> 1 THEN RAISE EXCEPTION 'P1 : le canal de contexte public est mal pose'; END IF;

  -- P2 : il ne LIT aucune des donnees que l arbitrage exclut. Le corps est relu, COMMENTAIRES
  -- RETIRES : pg_proc.prosrc rend le source commentaires compris, et le commentaire qui enumere
  -- justement les champs interdits faisait echouer cette preuve sur sa propre documentation. On
  -- ne prouve pas une regle sur de la prose : les lignes de commentaire sont otees, et c'est le
  -- CODE qui est interroge.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace,
       LATERAL (SELECT coalesce(string_agg(l, E'\n'), '') AS code
                  FROM regexp_split_to_table(p.prosrc, E'\n') AS l
                 WHERE l !~ '^[[:space:]]*--') AS sans_commentaire
   WHERE n.nspname = 'public' AND p.proname = 'pnj_contexte_public'
     AND (sans_commentaire.code LIKE '%resources%' OR sans_commentaire.code LIKE '%career%'
          OR sans_commentaire.code LIKE '%carriere%' OR sans_commentaire.code LIKE '%domicile%'
          OR sans_commentaire.code LIKE '%historique%' OR sans_commentaire.code LIKE '%popularite%');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P2 : le contexte public lit une donnee non autorisee'; END IF;

  -- P3 : les trois controles d eligibilite sont dans le CORPS de la porte reellement empruntee.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'candidature_deposer'
     AND p.prosrc LIKE '%influence_insuffisante%'
     AND p.prosrc LIKE '%non_domicilie%'
     AND p.prosrc LIKE '%cumul_interdit%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P3 : candidature_deposer ne verifie pas l eligibilite'; END IF;

  -- P4 : les quatre fonctions du Palais sont declarees, et toutes gamma.
  SELECT count(*) INTO v_n FROM public.pnj_fonctions
   WHERE fonction IN ('president','secretaire_general','porteparole','protocole')
     AND classe_decor = 'gamma' AND NOT recrutable;
  IF v_n <> 4 THEN RAISE EXCEPTION 'P4 : les fonctions du Palais ne sont pas declarees (%)', v_n; END IF;

  -- P5 : trois referents de plus, et le compte exact.
  SELECT count(*) INTO v_n FROM public.pnj_referents;
  IF v_n <> 22 THEN RAISE EXCEPTION 'P5 : % referents au lieu de 22', v_n; END IF;

  RAISE NOTICE 'Palais lot 1 : les 5 preuves structurelles passent.';
END $$;
