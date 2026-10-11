-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011161526 (UTC), nom
-- `assemblee_presidence_fenetre_de_convocation`.
-- Le registre passe de 658 a 659 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 0e71868311db56f38edf796211acefd9, 8344 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LA CONVOCATION A UNE FENETRE, ET ELLE EST EN BASE
--
-- L'arbitrage dit « lundi a 00h01 ». Si la convocation n'avait pour seule garde que « aucun
-- scrutin deja ouvert », un cron quotidien aurait ouvert une election NEUVE chaque mardi, puisque
-- celle du lundi venait de se clore a 23 heures. Le calendrier doit donc etre une regle de BASE,
-- comme la fenetre du mercredi soir l'est deja -- et non une condition ecrite dans un fichier de
-- cron, ou personne ne la relirait.
-- LA FENETRE EST LE LUNDI ENTIER, heure de Paris. Pas « 00h01 a 00h05 » : un cron en retard, une
-- fonction trop lente, un redeploiement -- et l'Assemblee resterait sans President pour la
-- semaine. Le lundi entier laisse rattraper sans jamais permettre d'ouvrir un autre jour. La
-- CLOTURE, elle, reste exactement le lundi 23 heures. Et un second scrutin le meme jour est
-- refuse : deux passes du cron ne doivent pas rouvrir une election deja depouillee.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- LA CONVOCATION A UNE FENETRE, ET ELLE EST EN BASE (11 octobre 2026)
-- =================================================================================================
-- L'ARBITRAGE DIT « LUNDI A 00H01 ». Si la convocation n'avait pour seule garde que « aucun scrutin
-- deja ouvert », un cron quotidien aurait ouvert une election NEUVE chaque mardi, puisque celle du
-- lundi venait de se clore a 23 heures. Le calendrier doit donc etre une regle de BASE, comme la
-- fenetre du mercredi soir l'est deja (`assemblee_fenetre_ouverture`) -- et non une condition
-- ecrite dans un fichier de cron, ou personne ne la relirait.
--
-- LA FENETRE EST LE LUNDI ENTIER, heure de Paris. Pas « 00h01 a 00h05 » : un cron en retard, une
-- fonction qui a mis trop de temps, un redeploiement -- et l'Assemblee resterait sans President
-- pour la semaine. Le lundi entier laisse rattraper sans jamais permettre d'ouvrir un autre jour.
-- La CLOTURE, elle, reste exactement le lundi 23 heures.
-- =================================================================================================

CREATE OR REPLACE FUNCTION public.assemblee_presidence_fenetre_convocation(p_instant timestamptz)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT extract(isodow FROM (p_instant AT TIME ZONE 'Europe/Paris')) = 1;
$function$;

COMMENT ON FUNCTION public.assemblee_presidence_fenetre_convocation(timestamptz) IS
  'La fenetre de convocation de l election presidentielle : le LUNDI, heure de Paris. Le lundi entier et non la seule minute de 00h01, pour qu un cron en retard puisse rattraper -- sans jamais permettre d ouvrir un scrutin un autre jour. La cloture reste le lundi 23h00 (arbitrage du 11 octobre 2026).';

CREATE OR REPLACE FUNCTION public.assemblee_presidence_convoquer(p_pays text, p_cause text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id text; v_cloture timestamptz; v_elig jsonb; v_pres text; v_n integer := 0;
  v_d record; v_heure text;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;
  IF coalesce(p_cause,'') NOT IN ('renouvellement','deux_boycotts') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cause_inconnue');
  END IF;
  -- LE CALENDRIER EST UNE REGLE DE BASE. Sans elle, un cron quotidien ouvrirait une election par
  -- jour -- celle du lundi venant de se clore a 23 heures.
  IF NOT public.assemblee_presidence_fenetre_convocation(now()) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_fenetre_convocation');
  END IF;

  IF EXISTS (SELECT 1 FROM public.assemblee_presidence_scrutins
              WHERE pays = p_pays AND statut = 'ouvert') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_deja_ouvert');
  END IF;
  -- UN SEUL SCRUTIN PAR LUNDI. Deux passes du cron le meme jour ne doivent pas rouvrir une
  -- election qui vient d'etre depouillee -- ni effacer son resultat.
  IF EXISTS (SELECT 1 FROM public.assemblee_presidence_scrutins
              WHERE pays = p_pays
                AND (ouvert_le AT TIME ZONE 'Europe/Paris')::date
                    = (now() AT TIME ZONE 'Europe/Paris')::date) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_deja_tenu_aujourd_hui');
  END IF;

  -- LES NEUF, FIGES A L'OUVERTURE. Si un siege change de main pendant la semaine, le scrutin garde
  -- la liste devant laquelle les deputes ont vote : on ne deplace pas les regles en cours de route.
  SELECT coalesce(jsonb_agg(jsonb_build_object('depute', e.depute, 'ville', e.ville,
                                               'rang', e.rang, 'est_pnj', e.est_pnj)
                            ORDER BY e.ville, e.rang), '[]'::jsonb)
    INTO v_elig FROM public.assemblee_presidence_eligibles(p_pays) e;
  IF jsonb_array_length(v_elig) <> 9 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'composition_incomplete',
                              'sieges', jsonb_array_length(v_elig));
  END IF;

  v_cloture := public.assemblee_presidence_prochaine_cloture();
  v_pres := public.assemblee_president(p_pays);
  v_id := 'presidence-' || p_pays || '-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISS');

  INSERT INTO public.assemblee_presidence_scrutins
    (id, pays, cause, cloture_ts, eligibles, president_sortant)
  VALUES (v_id, p_pays, p_cause, v_cloture, v_elig, v_pres);

  -- L'ELECTION EXCEPTIONNELLE EN ATTENTE EST HONOREE PAR CELLE-CI, quelle que soit sa cause : la
  -- presidence vient d'etre remise en jeu, il n'y a plus rien a rattraper.
  UPDATE public.assemblee_presidence_dues
     SET honore_le = clock_timestamp(), scrutin_id = v_id
   WHERE pays = p_pays AND honore_le IS NULL;

  -- LE COURRIER DE CONVOCATION. Il part aux neuf -- mais seuls les deputes JOUEURS ont une boite :
  -- les PNJ n'ont aucune fiche de personnage, et leur ecrire serait ecrire a personne.
  v_heure := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
  FOR v_d IN SELECT e.depute, e.ville FROM public.assemblee_presidence_eligibles(p_pays) e
              WHERE NOT e.est_pnj
  LOOP
    PERFORM public.mail_systeme_poser_interne(
      'Secrétariat de l''Assemblée nationale', v_d.depute,
      'Convocation — élection du Président de l''Assemblée',
      'L''Assemblée nationale élit son Président. Les neuf députés sont éligibles : vous pouvez '
      || 'voter pour n''importe lequel d''entre eux, y compris vous-même. Le scrutin est ouvert '
      || 'jusqu''au lundi 23h00, à un seul tour, et le décompte est visible pendant toute sa '
      || 'durée. En cas d''égalité en tête, le départage se fera à la courte paille.',
      v_heure);
    v_n := v_n + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'scrutin', v_id, 'cause', p_cause,
                            'cloture_ts', v_cloture, 'convoques', v_n,
                            'eligibles', jsonb_array_length(v_elig));
END;
$function$;

REVOKE ALL ON FUNCTION public.assemblee_presidence_convoquer(text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assemblee_presidence_convoquer(text,text) FROM anon;
REVOKE ALL ON FUNCTION public.assemblee_presidence_convoquer(text,text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.assemblee_presidence_convoquer(text,text) TO service_role;
REVOKE ALL ON FUNCTION public.assemblee_presidence_fenetre_convocation(timestamptz) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assemblee_presidence_fenetre_convocation(timestamptz) FROM anon;
GRANT EXECUTE ON FUNCTION public.assemblee_presidence_fenetre_convocation(timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assemblee_presidence_fenetre_convocation(timestamptz) TO service_role;

DO $$
DECLARE v_src text;
BEGIN
  -- P1 : LA FENETRE EST LE LUNDI, EN HEURE DE PARIS, et elle est verifiee sur des instants reels.
  IF NOT public.assemblee_presidence_fenetre_convocation('2026-10-12 00:01:00+02'::timestamptz) THEN
    RAISE EXCEPTION 'P1a : le lundi 00h01 de Paris est hors fenetre';
  END IF;
  IF NOT public.assemblee_presidence_fenetre_convocation('2026-10-12 22:00:00+02'::timestamptz) THEN
    RAISE EXCEPTION 'P1b : le lundi soir est hors fenetre';
  END IF;
  IF public.assemblee_presidence_fenetre_convocation('2026-10-13 00:01:00+02'::timestamptz) THEN
    RAISE EXCEPTION 'P1c : le mardi est dans la fenetre';
  END IF;
  IF public.assemblee_presidence_fenetre_convocation('2026-10-11 23:30:00+02'::timestamptz) THEN
    RAISE EXCEPTION 'P1d : le dimanche soir est dans la fenetre';
  END IF;

  -- P2 : LA CONVOCATION HONORE LA FENETRE, ET REFUSE UN SECOND SCRUTIN LE MEME JOUR.
  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_presidence_convoquer';
  IF v_src NOT LIKE '%hors_fenetre_convocation%' THEN
    RAISE EXCEPTION 'P2a : la convocation ignore le calendrier';
  END IF;
  IF v_src NOT LIKE '%scrutin_deja_tenu_aujourd_hui%' THEN
    RAISE EXCEPTION 'P2b : deux passes du cron pourraient rouvrir une election deja depouillee';
  END IF;

  RAISE NOTICE 'Fenetre de convocation : les 2 preuves structurelles passent.';
END $$;
