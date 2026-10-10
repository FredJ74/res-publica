-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010084647 (UTC), nom `souvenir_accueil_la_fuite_a_sa_cle_de_journee`.
-- Le registre passe de 599 a 600 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 75747cd03387de2fda8be526f51d3f6c, 7495 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CHANTIER 6, RELIQUAT : LES SOUVENIRS D'ACCUEIL SE DEFENDENT SEULS
--
-- Le dernier defaut grave du chantier 6. Chaque fuite insere un `evenements_globaux` « SCANDALE »
-- NOMINATIF et IRREVERSIBLE, et son seul rempart etait le registre `joursCron` -- une ligne
-- unique, lue-fusionnee-reecrite sans atomicite, 18 fois par nuit. La frontiere anti-rejeu devient
-- LE SOUVENIR (`jour_tirage`), pas la passe. Le tirage, le marquage et l'annonce sont dans une
-- seule transaction, et les deux marquages sont des compare-and-swap.
--
-- CE QUE LA PASSE REELLE DU 10 OCTOBRE A MONTRE (constate apres coup, cron_journal) :
--   souvenirs_accueil -> statut ok, { "fuites": 0, "marquages_echoues": 0 }
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHANTIER 6, RELIQUAT -- LES SOUVENIRS D'ACCUEIL SE DEFENDENT SEULS (10 octobre 2026)
--
-- CE QUI RESTAIT, ET POURQUOI C'ETAIT LE DERNIER DEFAUT GRAVE DU CHANTIER. Le lot du 7 octobre a
-- fait passer cette tache par tacheQuotidienne() et a rendu le marquage `revele` verifiable. Mais
-- le paragraphe 4 de l'audit canonique le disait sans detour : SON SEUL REMPART EST LE REGISTRE
-- `joursCron` -- une ligne unique, lue-fusionnee-reecrite sans atomicite, ecrite et relue 18 fois
-- par nuit. « La frontiere devrait etre LE SOUVENIR -- une colonne jour_tirage -- pas la passe. »
--
-- L'enjeu n'est pas comptable. Chaque fuite insere un `evenements_globaux` « SCANDALE »
-- NOMINATIF et IRREVERSIBLE : il nomme un joueur et l'objet qu'il a recupere. Un second tirage
-- le meme soir double la probabilite qu'un secret fuite, et rien dans la donnee ne s'y oppose.
--
-- TROIS DEFAUTS SUBSISTAIENT, et les voici nommes.
--   1. AUCUNE GARDE SUR LA DONNEE. Deux passes dans la meme nuit relancaient un tirage par
--      souvenir. Le registre de journee est un garde-fou de PASSE, pas de SOUVENIR.
--   2. LE MARQUAGE N'ETAIT PAS UN COMPARE-AND-SWAP. `sbUpdate(..., 'id=eq.X', {revele:true})`
--      ne filtre PAS sur `revele=eq.false` : deux marquages concurrents reussissent tous les
--      deux, et chacun annonce son scandale.
--   3. LE TIRAGE ETAIT DANS LE NAVIGATEUR DU CRON, et le marquage puis l'annonce etaient DEUX
--      requetes HTTP. Le hasard qui determine un resultat autoritaire doit vivre dans la
--      transaction qui en porte les consequences.
--
-- CE QUE LA PORTE FAIT. `jour_tirage` devient la frontiere exacte que l'audit reclamait : un
-- souvenir est tire AU PLUS UNE FOIS PAR JOURNEE, que le registre ait tenu ou non. Le tirage, le
-- marquage et l'annonce publique sont dans une seule transaction, sous verrou de ligne.
--
-- AUCUNE REGLE DE JEU N'EST MODIFIEE. La probabilite reste `0,05 + random() * 0,05`, tiree puis
-- comparee a un second tirage, exactement comme dans le navigateur. Le texte du scandale, son
-- pays, sa ville et son jour sont repris caractere pour caractere. Dans le fonctionnement normal
-- -- une passe par nuit -- le comportement est identique ; la garde ne mord qu'au rejeu.
--
-- CE QUE LA PORTE NE FAIT PAS, ET C'EST DELIBERE : elle ne nettoie pas les souvenirs expires.
-- `jour_expiration` existe, aucun code ne le lit, et decider ce que devient un souvenir de plus
-- de douze jours est un arbitrage de game design. Le lot du 7 octobre l'avait deja consigne.

ALTER TABLE public.souvenirs_accueil ADD COLUMN IF NOT EXISTS jour_tirage date;

COMMENT ON COLUMN public.souvenirs_accueil.jour_tirage IS
  'Journee du dernier tirage de fuite. La frontiere anti-rejeu est LE SOUVENIR, pas la passe : '
  'souvenir_accueil_tirer refuse un second tirage le meme jour meme si le registre joursCron a '
  'ete perdu. NULL = jamais tire.';

CREATE OR REPLACE FUNCTION public.souvenir_accueil_tirer(p_souvenir_id text, p_jour date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  s public.souvenirs_accueil; v_chance numeric; v_jet numeric; v_n integer;
BEGIN
  IF p_jour IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jour_manquant');
  END IF;

  SELECT * INTO s FROM public.souvenirs_accueil WHERE id = p_souvenir_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'souvenir_introuvable');
  END IF;

  -- Un souvenir deja revele ne refuit pas. Ce n'est pas une erreur : c'est le cas normal d'une
  -- liste lue avant qu'une autre passe ne la consomme.
  IF coalesce(s.revele, false) THEN
    RETURN jsonb_build_object('ok', true, 'action', 'deja_revele');
  END IF;

  -- LA GARDE QUE L'AUDIT RECLAMAIT : la frontiere est le souvenir, pas la passe.
  IF s.jour_tirage = p_jour THEN
    RETURN jsonb_build_object('ok', true, 'action', 'deja_tire');
  END IF;

  -- LE HASARD EST DANS LA TRANSACTION QUI EN PORTE LES CONSEQUENCES. Memes deux tirages, memes
  -- bornes, meme comparaison que dans le navigateur : 5 % a 10 %.
  v_chance := 0.05 + random() * 0.05;
  v_jet := random();

  IF v_jet >= v_chance THEN
    UPDATE public.souvenirs_accueil SET jour_tirage = p_jour
     WHERE id = p_souvenir_id AND revele IS NOT TRUE;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n <> 1 THEN RAISE EXCEPTION 'souvenir_accueil_tirer : marquage de journee non pris'; END IF;
    RETURN jsonb_build_object('ok', true, 'action', 'pas_de_fuite');
  END IF;

  -- LE MARQUAGE EST UN COMPARE-AND-SWAP, et l'annonce est dans la meme transaction que lui.
  UPDATE public.souvenirs_accueil SET revele = true, jour_tirage = p_jour
   WHERE id = p_souvenir_id AND revele IS NOT TRUE;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', true, 'action', 'deja_revele');
  END IF;

  INSERT INTO public.evenements_globaux (country, city, texte, jour)
  VALUES ('republic', NULL,
          '📰 SCANDALE : un journaliste révèle que ' || s.pj_nom || ' a récupéré "'
            || s.objet_nom || '" au service des objets trouvés de l''Assemblée.',
          NULL);

  RETURN jsonb_build_object('ok', true, 'action', 'fuite', 'pj', s.pj_nom, 'objet', s.objet_nom);
END; $fn$;

REVOKE ALL ON FUNCTION public.souvenir_accueil_tirer(text, date) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.souvenir_accueil_tirer(text, date) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.souvenir_accueil_tirer(text, date) TO service_role;

DO $$
DECLARE v_def text; v_acl text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema='public' AND table_name='souvenirs_accueil'
                    AND column_name='jour_tirage' AND data_type='date') THEN
    RAISE EXCEPTION 'P1 : la colonne jour_tirage est absente ou du mauvais type'; END IF;
  SELECT pg_get_functiondef(p.oid),
         coalesce(array_to_string(p.proacl::text[], ' | '), '(defaut)')
    INTO v_def, v_acl
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname='public' AND p.proname='souvenir_accueil_tirer';
  IF v_def IS NULL THEN RAISE EXCEPTION 'P2 : la porte est absente'; END IF;
  IF v_acl <> 'postgres=X/postgres | service_role=X/postgres' THEN
    RAISE EXCEPTION 'P3 : la porte n''est pas reservee au serveur -- %', v_acl; END IF;
  -- P4 : les DEUX marquages sont des compare-and-swap sur revele.
  IF (length(v_def) - length(replace(v_def, 'AND revele IS NOT TRUE', ''))) / 22 <> 2 THEN
    RAISE EXCEPTION 'P4 : % compare-and-swap au lieu de 2',
      (length(v_def) - length(replace(v_def, 'AND revele IS NOT TRUE', ''))) / 22; END IF;
  -- P5 : la probabilite du jeu est inchangee, et le tirage est DANS la porte.
  IF v_def NOT LIKE '%0.05 + random() * 0.05%' THEN
    RAISE EXCEPTION 'P5 : la probabilite de fuite a change'; END IF;
  -- P6 : l'annonce est dans la porte, et une seule.
  IF (length(v_def) - length(replace(v_def, 'INSERT INTO public.evenements_globaux', ''))) / 37 <> 1 THEN
    RAISE EXCEPTION 'P6 : l''annonce n''est pas unique dans le corps'; END IF;
  -- P7 : aucun souvenir en base, donc cette migration ne touche aucune donnee de joueur.
  IF (SELECT count(*) FROM public.souvenirs_accueil) <> 0 THEN
    RAISE EXCEPTION 'P7 : % souvenir(s) en base -- a verifier avant d''aller plus loin',
      (SELECT count(*) FROM public.souvenirs_accueil); END IF;
  RAISE NOTICE 'souvenir_accueil_tirer : 7 preuves structurelles conformes.';
END $$;
