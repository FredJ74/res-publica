-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011142032 (UTC), nom `assemblee_seance_qui_est_la`.
-- Le registre passe de 650 a 651 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 320aa1e54442b75ee1796448fb597a43, 8877 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- QUI EST LA, ET QUELS TEXTES SONT DEJA REPORTES
--
-- La porte de lecture de la seance rend desormais deux faits de plus, parce que l'interface
-- avait commence a les deviner -- et qu'un fait serveur devine est un fait serveur perdu.
-- LA LISTE DES DEPUTES ET DE LEUR PRESENCE. Un rappel au reglement n'est possible que contre un
-- depute PHYSIQUEMENT dans l'hemicycle. Sans cette liste, l'ecran devait soit recopier les
-- presents vus par le navigateur -- faire decider le client d'un fait serveur -- soit proposer
-- tout le monde et laisser le refus arriver, ce qui transforme une regle en bug apparent.
-- LES TEXTES DEJA REPORTES. `assemblee_reports` est sous RLS sans policy : le navigateur ne
-- pouvait pas savoir qu'un texte avait deja consomme la prerogative, et proposait un report
-- impossible.
-- RIEN DE PRIVE N'EST AJOUTE : nom, ville du siege, presence, parti -- tout cela est public dans
-- l'enceinte. Une preuve verifie qu'aucun champ d'argent, de popularite, de casier ou de
-- courrier n'apparait, et une autre que la porte n'ecrit toujours nulle part.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- QUI EST LA, ET QUELS TEXTES SONT DEJA REPORTES (11 octobre 2026)
-- =================================================================================================
-- DEUX FAITS QUE L'INTERFACE NE DOIT PAS DEVINER.
--
-- 1. LA LISTE DES DEPUTES ET DE LEUR PRESENCE. Le President ne peut rappeler au reglement qu'un
--    depute PHYSIQUEMENT dans l'hemicycle -- le serveur le verifie et refuse sinon. Mais sans
--    cette liste, l'ecran devait deviner qui proposer, soit en recopiant la liste des presents du
--    navigateur, soit en proposant tout le monde et en laissant le refus arriver. Les deux sont
--    mauvais : le premier fait decider le client d'un fait serveur, le second transforme un refus
--    legitime en bug apparent. La porte rend donc la liste, avec la presence relue en base.
--
-- 2. LES TEXTES DEJA REPORTES. `assemblee_reports` est sous RLS sans policy : le navigateur ne
--    peut pas la lire, et ne pouvait donc pas savoir qu'un texte avait deja consomme la
--    prerogative. L'ecran proposait un report impossible, et le President decouvrait le refus
--    apres avoir clique.
--
-- RIEN DE PRIVE N'EST AJOUTE. La liste porte le nom, la ville du siege, la presence et le parti --
-- tout cela est public dans l'enceinte : on voit qui siege, on voit qui est la, et un parti
-- politique est une organisation declaree. Aucun argent, aucune popularite, aucun casier, aucun
-- message. Une preuve structurelle le verifie.
-- =================================================================================================

CREATE OR REPLACE FUNCTION public.assemblee_seance(p_limite integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_pres text; v_lim integer := least(greatest(coalesce(p_limite,50),1),200);
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  v_pres := public.assemblee_president(v_pays);

  RETURN jsonb_build_object('ok', true, 'pays', v_pays,
    'president', v_pres,
    'je_suis_le_president', (v_pres IS NOT NULL AND v_pres = v_moi),
    'je_suis_depute', public.assemblee_est_depute(v_pays, v_moi),
    'je_suis_dans_hemicycle', public.assemblee_dans_hemicycle(v_pays, v_moi),
    'mon_parti', public.assemblee_parti_de(v_pays, v_moi),
    'suspendue', public.assemblee_suspendue(v_pays),
    -- LES DEPUTES JOUEURS, AVEC LEUR PRESENCE RELUE EN BASE. Les neuf sieges peuvent etre tenus
    -- par des PNJ, qui n'ont aucune fiche de personnage : eux n'apparaissent pas ici, et ne
    -- peuvent par construction ni parler, ni etre rappeles, ni protester.
    'deputes', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                   'depute', o.pj_nom, 'ville', o.city,
                   'dans_hemicycle', public.assemblee_dans_hemicycle(v_pays, o.pj_nom),
                   'parti', public.assemblee_parti_de(v_pays, o.pj_nom))
                 ORDER BY o.city, o.rang), '[]'::jsonb)
       FROM public.assemblee_occupation_sieges(v_pays) o WHERE o.pj_nom IS NOT NULL),
    -- LA FILE, DANS SON ORDRE CHRONOLOGIQUE EXACT. C'est elle que le President doit respecter.
    'file', (SELECT coalesce(jsonb_agg(jsonb_build_object('depute', q.depute, 'depuis', q.demande_le)
              ORDER BY q.demande_le, q.depute), '[]'::jsonb)
       FROM public.assemblee_paroles q WHERE q.pays = v_pays AND NOT q.a_la_parole),
    'orateur', (SELECT q.depute FROM public.assemblee_paroles q
                 WHERE q.pays = v_pays AND q.a_la_parole LIMIT 1),
    'debat', (SELECT coalesce(jsonb_agg(x ORDER BY (x->>'dit_le')), '[]'::jsonb) FROM (
        SELECT jsonb_build_object('id', d.id, 'auteur', d.auteur, 'fonction', d.auteur_fonction,
                 'texte', d.texte, 'autorise', d.autorise, 'dit_le', d.dit_le) AS x
          FROM public.assemblee_debats d WHERE d.pays = v_pays
          ORDER BY d.dit_le DESC LIMIT v_lim) z),
    'dehors', (SELECT coalesce(jsonb_agg(jsonb_build_object('depute', p.depute,
                 'qualifie', p.qualifie, 'motif', p.motif_qualifiant, 'depuis', p.sorti_le)
                 ORDER BY p.sorti_le), '[]'::jsonb)
       FROM public.assemblee_protestations p WHERE p.pays = v_pays),
    'protestataires_qualifies', (SELECT count(*) FROM public.assemblee_protestations p
                                  WHERE p.pays = v_pays AND p.qualifie),
    'seuil_suspension', 5,
    -- CE QUE LE PRESIDENT PEUT SANCTIONNER : les rappels non encore consommes. C'est un fait de
    -- procedure, pas un conseil.
    'rappels_consommables', (SELECT coalesce(jsonb_agg(d.cible ORDER BY d.cible), '[]'::jsonb)
       FROM public.assemblee_disciplines d
      WHERE d.pays = v_pays AND d.genre = 'rappel' AND d.president IS NOT DISTINCT FROM v_pres
        AND NOT EXISTS (SELECT 1 FROM public.assemblee_disciplines s WHERE s.rappel_id = d.id)),
    -- LES TEXTES AYANT DEJA CONSOMME LA PREROGATIVE DE REPORT. La table est fermee au navigateur :
    -- sans cette liste, l'ecran proposerait un report impossible.
    'textes_reportes', (SELECT coalesce(jsonb_agg(r.proposition_id ORDER BY r.proposition_id), '[]'::jsonb)
       FROM public.assemblee_reports r WHERE r.pays = v_pays),
    'episodes_sous_cette_presidence', (SELECT count(*) FROM public.assemblee_suspensions s
       WHERE s.pays = v_pays AND s.cause = 'boycott'
         AND s.president IS NOT DISTINCT FROM v_pres));
END;
$function$;

REVOKE ALL ON FUNCTION public.assemblee_seance(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assemblee_seance(integer) FROM anon;
GRANT EXECUTE ON FUNCTION public.assemblee_seance(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assemblee_seance(integer) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- PREUVES STRUCTURELLES
-- -------------------------------------------------------------------------------------------------
DO $$
DECLARE v_src text; v_n integer;
BEGIN
  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_seance';

  -- P1 : ELLE N'ECRIT RIEN. Une porte de lecture qui ecrirait serait un point d'ecriture non
  -- audite, atteignable par un simple affichage d'ecran.
  IF v_src LIKE '%INSERT INTO%' OR v_src LIKE '%UPDATE %' OR v_src LIKE '%DELETE FROM%' THEN
    RAISE EXCEPTION 'P1 : la lecture de la seance ecrit quelque part';
  END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_seance' AND p.provolatile = 's';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P1b : la lecture de la seance n est plus STABLE'; END IF;

  -- P2 : LES DEUX FAITS NEUFS SONT BIEN RENDUS.
  IF v_src NOT LIKE '%''deputes''%' THEN RAISE EXCEPTION 'P2a : la liste des deputes manque'; END IF;
  IF v_src NOT LIKE '%''textes_reportes''%' THEN RAISE EXCEPTION 'P2b : les textes reportes manquent'; END IF;
  IF v_src NOT LIKE '%assemblee_dans_hemicycle(v_pays, o.pj_nom)%' THEN
    RAISE EXCEPTION 'P2c : la presence des deputes n est pas relue en base';
  END IF;

  -- P3 : AUCUNE DONNEE PRIVEE. Ni argent, ni popularite, ni casier, ni courrier : le debat est
  -- public dans l'enceinte, le reste ne l'est pas.
  IF v_src LIKE '%liquide%' OR v_src LIKE '%personnages_donnees.arg%' OR v_src LIKE '%popularite%'
     OR v_src LIKE '%casier%' OR v_src LIKE '%mails%' OR v_src LIKE '%est_emprisonne%' THEN
    RAISE EXCEPTION 'P3 : une donnee privee est apparue dans la lecture de la seance';
  END IF;

  -- P4 : UN SEUL PARAMETRE, ET C'EST UNE LIMITE. Pas de pays explicite : on ne lit jamais la
  -- seance d'un autre empire en se nommant soi-meme.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_seance'
     AND p.pronargs = 1 AND pg_get_function_identity_arguments(p.oid) = 'p_limite integer';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P4 : la signature de la lecture de seance a change'; END IF;

  -- P5 : FERMEE A anon, OUVERTE AUX JOUEURS IDENTIFIES.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_seance'
     AND NOT has_function_privilege('anon', p.oid, 'EXECUTE')
     AND has_function_privilege('authenticated', p.oid, 'EXECUTE');
  IF v_n <> 1 THEN RAISE EXCEPTION 'P5 : la lecture de la seance est ouverte a anon'; END IF;

  RAISE NOTICE 'Lecture de la seance : les 5 preuves structurelles passent.';
END $$;
