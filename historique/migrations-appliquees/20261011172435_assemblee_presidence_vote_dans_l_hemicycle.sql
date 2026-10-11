-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011172435 (UTC), nom
-- `assemblee_presidence_vote_dans_l_hemicycle`.
-- Le registre passe de 661 a 662 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 81fdb3b201f85422334f22336434aa6b, 12197 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- ON N ELIT PAS SON PRESIDENT DEPUIS LE HALL
--
-- Un depute joueur ne peut voter a l'election du President de l'Assemblee que s'il est
-- PHYSIQUEMENT present dans l'hemicycle -- exactement comme pour un vote legislatif, qui refuse
-- deja `hors_lieu`. La convocation du lundi prend donc un sens physique : il faut venir.
-- LA POSITION EST LUE EN BASE, JAMAIS DECLAREE. `acteur_present_sur_site` est la regle de
-- localisation unique du projet ; `assemblee_dans_hemicycle` n'en est que l'application nommee. La
-- signature de la porte ne bouge pas -- deux parametres, le nom vote et l'identifiant de requete --
-- donc un client ne peut pas declarer ou il se trouve.
-- L'ORDRE DES REFUS EST UNE INFORMATION. La garde de rejeu passe d'abord : un bulletin depose puis
-- une reponse perdue doit se retrouver, meme si le depute a quitte l'hemicycle entre-temps. Le
-- mandat ensuite : un non-depute present s'entend dire qu'il n'est pas depute, pas qu'il est mal
-- place. La presence enfin.
-- ET LA REGLE VAUT POUR L'ELECTION EXCEPTIONNELLE declenchee par deux boycotts, sans traitement
-- particulier : c'est la MEME porte, et une preuve verifie qu'elle ne regarde pas la cause du
-- scrutin.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- ASSEMBLEE NATIONALE -- QUATRIEME PASSE, §5 : ON N'ELIT PAS SON PRESIDENT DEPUIS LE HALL
-- 11 octobre 2026
--
-- L'ARBITRAGE. Un depute PJ ne peut voter a l'election presidentielle que s'il est PHYSIQUEMENT
-- PRESENT DANS L'HEMICYCLE -- exactement comme pour un vote legislatif. La convocation du lundi
-- prend donc un sens physique : il faut venir. Depuis le hall de l'Assemblee : refuse. De chez
-- soi, d'une autre ville, d'un autre pays : refuse. Dans l'hemicycle : accepte, si les autres
-- conditions sont reunies. Cette regle vaut AUSSI pour une election exceptionnelle declenchee
-- apres deux episodes de boycott -- et elle le vaut sans traitement particulier, parce que la
-- porte de vote est la meme pour les deux causes de scrutin.
--
-- LA POSITION EST LUE EN BASE, JAMAIS DECLAREE. public.acteur_present_sur_site() est la regle de
-- localisation unique du projet : elle lit le pays, la ville, le batiment et la PIECE sur la
-- fiche serveur du personnage. assemblee_dans_hemicycle() n'en est que l'application nommee
-- (capitale / assemblee / hemicycle). Aucun parametre de position n'est ajoute a la porte : le
-- client ne peut donc pas declarer ou il se trouve, et il n'y a rien a falsifier.
--
-- L'ORDRE DES REFUS EST VOLONTAIRE. La presence est verifiee APRES le mandat (« pas_depute ») et
-- AVANT le scrutin : un non-depute present dans l'hemicycle doit s'entendre dire qu'il n'est pas
-- depute, pas qu'il est mal place. Elle est verifiee avant « deja_vote » pour la meme raison :
-- la cause la plus structurante d'abord.
--
-- LA GARDE D'IDEMPOTENCE RESTE LA PREMIERE DE TOUTES. Un bulletin depose puis une reponse perdue :
-- le rejeu doit retrouver le bulletin, meme si le depute a entre-temps quitte l'hemicycle. Placer
-- le controle de presence avant la garde aurait transforme une reponse perdue en refus.

CREATE OR REPLACE FUNCTION public.assemblee_presidence_voter(p_pour text, p_requete text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_moi text; v_pays text; s record; d record; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;

  -- LA GARDE, AVANT TOUTE ECRITURE : une reponse perdue et rejouee ne depose pas deux bulletins.
  SELECT * INTO d FROM public.assemblee_presidence_bulletins WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'pour', d.pour);
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT public.assemblee_est_depute(v_pays, v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_depute'); END IF;

  -- §5 : LA PRESENCE PHYSIQUE, LUE EN BASE. Le hall ne suffit pas, et la convocation du lundi
  -- cesse d'etre une formalite : il faut etre assis dans l'hemicycle pour elire son President.
  IF NOT public.assemblee_dans_hemicycle(v_pays, v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_hemicycle'); END IF;

  SELECT * INTO s FROM public.assemblee_presidence_scrutins
   WHERE pays = v_pays AND statut = 'ouvert' FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_scrutin_ouvert'); END IF;
  -- L'HEURE DU SERVEUR, ET ELLE SEULE. Un bulletin arrive apres 23h00 est refuse meme si le
  -- depouillement n'a pas encore tourne.
  IF now() >= s.cloture_ts THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_clos', 'cloture_ts', s.cloture_ts); END IF;

  -- LE NOM VOTE DOIT ETRE L'UN DES NEUF FIGES A L'OUVERTURE. C'est ce qui interdit d'elire un
  -- dixieme parlementaire, ou quelqu'un qui n'est pas depute du tout.
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(s.eligibles) e
                  WHERE e ->> 'depute' = p_pour) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_eligible', 'pour', p_pour); END IF;

  -- UN SEUL BULLETIN. Le double vote est REFUSE, et la voix deja deposee reste celle qui compte.
  IF EXISTS (SELECT 1 FROM public.assemblee_presidence_bulletins
              WHERE scrutin_id = s.id AND votant = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_vote'); END IF;

  INSERT INTO public.assemblee_presidence_bulletins (scrutin_id, votant, pour, requete)
  VALUES (s.id, v_moi, p_pour, p_requete);

  SELECT count(*) INTO v_n FROM public.assemblee_presidence_bulletins WHERE scrutin_id = s.id;
  RETURN jsonb_build_object('ok', true, 'scrutin', s.id, 'pour', p_pour, 'bulletins', v_n);
END;
$$;

-- ============================================================================================
-- L'ETAT DIT OU LE DEPUTE SE TROUVE
-- ============================================================================================
-- Pour que l'ecran puisse DIRE pourquoi le bouton ne vote pas, au lieu de laisser le joueur
-- essuyer un refus. La verite reste celle de la porte : cet etat informe, il n'autorise rien.
CREATE OR REPLACE FUNCTION public.assemblee_presidence_etat()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_moi text; v_pays text; s record; v_depute boolean; v_revoir jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  v_depute := public.assemblee_est_depute(v_pays, v_moi);

  SELECT * INTO s FROM public.assemblee_presidence_scrutins
   WHERE pays = v_pays AND statut = 'ouvert';

  SELECT to_jsonb(z) INTO v_revoir FROM (
    SELECT c.id, c.elu, c.egalite, c.decompte, c.cause, c.clos_le, c.eligibles
      FROM public.assemblee_presidence_scrutins c
     WHERE c.pays = v_pays AND c.statut = 'clos' AND c.egalite IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM public.assemblee_presidence_tirage_vu v
                        WHERE v.scrutin_id = c.id AND v.personnage = v_moi)
     ORDER BY c.clos_le DESC LIMIT 1) z;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays,
    'je_suis_depute', v_depute,
    -- §5 : LA MEME LECTURE QUE CELLE DE LA PORTE. L'ecran n'en deduit aucun droit ; il s'en sert
    -- pour expliquer, et c'est tout.
    'je_suis_dans_hemicycle', public.assemblee_dans_hemicycle(v_pays, v_moi),
    'president', public.assemblee_president(v_pays),
    'eligibles', (SELECT coalesce(jsonb_agg(jsonb_build_object('depute', e.depute,
                           'ville', e.ville, 'rang', e.rang, 'est_pnj', e.est_pnj)
                         ORDER BY e.ville, e.rang), '[]'::jsonb)
                    FROM public.assemblee_presidence_eligibles(v_pays) e),
    'scrutin', CASE WHEN s.id IS NULL THEN NULL ELSE jsonb_build_object(
        'id', s.id, 'cause', s.cause, 'ouvert_le', s.ouvert_le, 'cloture_ts', s.cloture_ts,
        'eligibles', s.eligibles,
        'mon_bulletin', (SELECT b.pour FROM public.assemblee_presidence_bulletins b
                          WHERE b.scrutin_id = s.id AND b.votant = v_moi),
        -- LE DECOMPTE EN DIRECT, zero voix comprise : sans les zeros, l'egalite serait illisible.
        'decompte', (SELECT coalesce(jsonb_agg(jsonb_build_object('depute', x.depute, 'voix', x.voix)
                             ORDER BY x.voix DESC, x.depute), '[]'::jsonb)
                       FROM (SELECT e ->> 'depute' AS depute,
                                    (SELECT count(*) FROM public.assemblee_presidence_bulletins b
                                      WHERE b.scrutin_id = s.id AND b.pour = e ->> 'depute')::integer AS voix
                               FROM jsonb_array_elements(s.eligibles) e) x),
        'bulletins', (SELECT count(*) FROM public.assemblee_presidence_bulletins b
                       WHERE b.scrutin_id = s.id)) END,
    'a_revoir', v_revoir,
    -- UNE ELECTION EXCEPTIONNELLE EST-ELLE DUE ? Un fait, pas une menace.
    'election_due', (SELECT to_jsonb(y) FROM (
        SELECT u.cause, u.du_le FROM public.assemblee_presidence_dues u
         WHERE u.pays = v_pays AND u.honore_le IS NULL LIMIT 1) y));
END;
$$;

-- ============================================================================================
-- PREUVES STRUCTURELLES
-- ============================================================================================
DO $$
DECLARE v_txt text; v_n integer;
BEGIN
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_presidence_voter';

  -- 1. LA PORTE REGARDE L'HEMICYCLE, et refuse avec un motif nomme.
  IF v_txt NOT LIKE '%assemblee_dans_hemicycle%' THEN
    RAISE EXCEPTION 'PREUVE 1 : le vote presidentiel ne regarde pas la presence';
  END IF;
  IF v_txt NOT LIKE '%hors_hemicycle%' THEN
    RAISE EXCEPTION 'PREUVE 1 bis : le refus de presence n''a pas de motif nomme';
  END IF;

  -- 2. AUCUNE POSITION DECLAREE PAR LE CLIENT. La signature de la porte n'a pas bouge : deux
  --    parametres, le nom vote et l'identifiant de requete. Ni piece, ni batiment, ni ville.
  SELECT pg_get_function_identity_arguments(p.oid) INTO v_txt
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_presidence_voter';
  IF v_txt <> 'p_pour text, p_requete text' THEN
    RAISE EXCEPTION 'PREUVE 2 : la porte de vote accepte une position (%)', v_txt;
  END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_presidence_voter';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'PREUVE 2 bis : % signatures de vote presidentiel -- une surcharge sans '
                    'controle de presence survivrait', v_n;
  END IF;

  -- 3. LA PRESENCE EST LUE PAR LA REGLE UNIQUE DU PROJET, qui lit la fiche serveur.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_dans_hemicycle';
  IF v_txt NOT LIKE '%acteur_present_sur_site%' OR v_txt NOT LIKE '%hemicycle%' THEN
    RAISE EXCEPTION 'PREUVE 3 : assemblee_dans_hemicycle n''est plus la regle de localisation';
  END IF;

  -- 4. LA GARDE D'IDEMPOTENCE PRECEDE LE CONTROLE DE PRESENCE. Un rejeu doit aboutir meme si le
  --    depute a quitte l'hemicycle entre-temps.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_presidence_voter';
  IF position('requete_deja_honoree' in v_txt) > position('hors_hemicycle' in v_txt) THEN
    RAISE EXCEPTION 'PREUVE 4 : la presence est verifiee avant la garde de rejeu';
  END IF;

  -- 5. LE MANDAT EST VERIFIE AVANT LA PRESENCE : un non-depute s'entend dire qu'il n'est pas
  --    depute, pas qu'il est mal place.
  IF position('pas_depute' in v_txt) > position('hors_hemicycle' in v_txt) THEN
    RAISE EXCEPTION 'PREUVE 5 : la presence est verifiee avant le mandat';
  END IF;

  -- 6. UNE SEULE PORTE DE VOTE POUR LES DEUX CAUSES DE SCRUTIN. L'election exceptionnelle
  --    declenchee par deux boycotts passe par la MEME fonction : la regle de presence n'a donc
  --    aucun chemin par lequel l'eviter. On le prouve en verifiant que la porte ne regarde PAS
  --    la cause du scrutin pour decider quoi que ce soit.
  IF v_txt LIKE '%s.cause%' THEN
    RAISE EXCEPTION 'PREUVE 6 : la porte de vote distingue les causes de scrutin';
  END IF;

  -- 7. L'ETAT RENSEIGNE L'ECRAN, sans jamais devenir une autorisation.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_presidence_etat';
  IF v_txt NOT LIKE '%je_suis_dans_hemicycle%' THEN
    RAISE EXCEPTION 'PREUVE 7 : l''etat de presidence ne dit pas ou se trouve le depute';
  END IF;

  RAISE NOTICE 'LES 7 PREUVES DE §5 SONT VERTES.';
END $$;
