-- GENRE DU PERSONNAGE : OBLIGATOIRE A LA CREATION, TRANSMIS AUX PNJ PAR LE SERVEUR (31/10/2026)
-- ---------------------------------------------------------------------------------------------
-- Signalement de Fred : le secrétaire municipal Petit a appelé un personnage masculin
-- « Madame la ministre ». Le canal pnj_contexte_public() ne rendait que le nom et les fonctions.
--
-- 1. personnages_vue_inserer : l'écran exigeait déjà le genre (creation.js, genreValeur), pas le
--    serveur. Une création qui contourne l'écran pouvait se faire sans genre, ou avec un texte
--    arbitraire. Désormais, hors appel serveur : stats.genre est obligatoire, normalisé (espaces)
--    et borné à 24 caractères, comme la saisie « autre » de l'écran. Aucune nouvelle catégorie :
--    'H', 'F', 'NB' ou le texte libre de « autre », vocabulaire existant (creation.js, GENRES).
--    Les fiches existantes ne sont ni modifiées ni complétées (anciennes fiches sans genre :
--    décision de Fred, régularisation non prioritaire en bêta). La restauration de sauvegarde
--    (administration) écrit directement la table et n'est pas concernée.
--    Après création, le genre est déjà figé : personnages_vue_modifier remet stats à sa valeur
--    enregistrée (sauvegarde de l'écran) ou refuse le changement (appel RPC).
--
-- 2. pnj_contexte_public : rend le genre lu sur la fiche du personnage authentifié, NORMALISÉ :
--    'H', 'F', 'neutre' (NB ou texte libre : jamais recopié tel quel vers l'IA), ou null pour une
--    fiche sans genre (le PNJ ne suppose rien). Ajout explicitement demandé par Fred le 31/10.
--
-- Chaque corps est vérifié par son empreinte de production (relevée le 31/10/2026).

DO $migration$
DECLARE
  d text;
  v_source text := $s$    NEW.user_id := v_uid;   -- l'autorite est le compte, jamais le payload
$s$;
  v_cible text := $c$    NEW.user_id := v_uid;   -- l'autorite est le compte, jamais le payload
    -- GENRE OBLIGATOIRE (31/10/2026) : la valeur choisie à la création (creation.js), normalisée
    -- et bornée comme la saisie libre de l'écran. Aucune valeur par défaut n'est inventée.
    IF jsonb_typeof(NEW.stats) IS DISTINCT FROM 'object'
       OR nullif(btrim(regexp_replace(coalesce(NEW.stats->>'genre', ''), '\s+', ' ', 'g')), '') IS NULL
       OR length(btrim(regexp_replace(NEW.stats->>'genre', '\s+', ' ', 'g'))) > 24 THEN
      RAISE EXCEPTION 'genre_requis' USING ERRCODE = '22023',
        DETAIL = 'Le genre du personnage est obligatoire à la création (24 caractères au plus).';
    END IF;
    NEW.stats := jsonb_set(NEW.stats, '{genre}',
      to_jsonb(btrim(regexp_replace(NEW.stats->>'genre', '\s+', ' ', 'g'))));
$c$;
BEGIN
  d := pg_get_functiondef('public.personnages_vue_inserer()'::regprocedure);
  IF position('genre_requis' IN d) > 0 THEN RETURN; END IF;
  IF md5(d) <> '52f4f9fb342ffa3796b081c2a5d22251' THEN
    RAISE EXCEPTION 'personnages_vue_inserer : corps différent de celui relevé le 31/10 (md5 %)', md5(d);
  END IF;
  IF (length(d) - length(replace(d, v_source, ''))) / length(v_source) <> 1 THEN
    RAISE EXCEPTION 'personnages_vue_inserer : point d''insertion absent ou multiple';
  END IF;
  EXECUTE replace(d, v_source, v_cible);
END $migration$;

DO $migration$
DECLARE
  d text;
  v_source1 text := $s$DECLARE v_moi text; f record; v_fonctions jsonb := '[]'::jsonb;
$s$;
  v_cible1 text := $c$DECLARE v_moi text; f record; v_fonctions jsonb := '[]'::jsonb; v_genre text;
$c$;
  v_source2 text := $s$  SELECT poste, poste_depute INTO f FROM public.personnages_donnees WHERE name = v_moi;
$s$;
  v_cible2 text := $c$  SELECT poste, poste_depute, stats INTO f FROM public.personnages_donnees WHERE name = v_moi;

  -- LE GENRE EST LU SUR LA FICHE, jamais reçu du navigateur (31/10/2026, demande de Fred).
  -- Normalisé : 'H' et 'F' choisissent la civilité ; toute autre valeur déclarée ('NB', texte
  -- libre de « autre ») devient 'neutre' et n'est jamais recopiée ; une fiche sans genre rend
  -- null, et le PNJ ne suppose rien.
  v_genre := nullif(btrim(coalesce(f.stats->>'genre', '')), '');
  v_genre := CASE WHEN v_genre IS NULL THEN NULL
                  WHEN v_genre IN ('H', 'F') THEN v_genre
                  ELSE 'neutre' END;
$c$;
  v_source3 text := $s$  RETURN jsonb_build_object('ok', true, 'nom', v_moi, 'fonctions', v_fonctions);
$s$;
  v_cible3 text := $c$  RETURN jsonb_build_object('ok', true, 'nom', v_moi, 'fonctions', v_fonctions, 'genre', v_genre);
$c$;
BEGIN
  d := pg_get_functiondef('public.pnj_contexte_public()'::regprocedure);
  IF position('v_genre' IN d) > 0 THEN RETURN; END IF;
  IF md5(d) <> '7e237302e02b3a6f36b3aad329ded509' THEN
    RAISE EXCEPTION 'pnj_contexte_public : corps différent de celui relevé le 31/10 (md5 %)', md5(d);
  END IF;
  IF (length(d) - length(replace(d, v_source1, ''))) / length(v_source1) <> 1
     OR (length(d) - length(replace(d, v_source2, ''))) / length(v_source2) <> 1
     OR (length(d) - length(replace(d, v_source3, ''))) / length(v_source3) <> 1 THEN
    RAISE EXCEPTION 'pnj_contexte_public : point d''insertion absent ou multiple';
  END IF;
  EXECUTE replace(replace(replace(d, v_source1, v_cible1), v_source2, v_cible2), v_source3, v_cible3);
END $migration$;
