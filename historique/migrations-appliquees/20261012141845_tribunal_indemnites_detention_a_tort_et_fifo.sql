-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012141845 (UTC), nom
-- `tribunal_indemnites_detention_a_tort_et_fifo`.
-- Le registre passe de 684 a 685 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 8a05fb2bc6aa5961342d7a6be2daaf5f, 20891 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE TRIBUNAL, CHEMIN CRITIQUE (2/6) -- L'INDEMNISATION ET SA DETTE
--
-- MILLE FRANCS PAR JOUR DE PRISON EFFECTIVEMENT PURGE EN TROP, et jamais sur l'ecart theorique
-- entre deux jugements. La cascade est a deux etages et n'est JAMAIS composite : la Justice paie
-- l'integralite ou ne paie RIEN, puis les Finances paient tout si elles peuvent le faire
-- immediatement, sinon la dette reste inscrite.
--
-- LE PRELEVEMENT EST UN DECLENCHEUR, pas un appel pose dans quelques portes : toute HAUSSE du
-- solde de la caisse des Finances paie la file, d'ou qu'elle vienne -- cascade budgetaire, impot,
-- vente, virement. Un etage de plus dans le circuit fiscal aurait suffi a faire oublier la dette.
-- Une BAISSE ne declenche rien, ce qui coupe la recursion que le paiement provoque lui-meme.
--
-- FIFO STRICT : la boucle S'ARRETE des que l'aine ne peut pas etre fini, elle ne passe pas au
-- cadet. Le solde est relu SOUS VERROU a chaque tour, donc deux creances ne peuvent pas etre
-- payees avec le meme argent, et aucune caisse ne devient negative. Le ministre n'a aucune
-- latitude : ni l'ordre, ni le montant, ni le moment.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- L'INDEMNISATION DE LA DETENTION EXECUTEE A TORT, ET SA DETTE
-- 12 octobre 2026 -- §F du cahier des charges
--
-- MILLE FRANCS PAR JOUR DE PRISON EFFECTIVEMENT PURGE EN TROP. L'indemnite ne se calcule jamais
-- sur l'ECART THEORIQUE entre deux jugements : elle se calcule sur ce qui a ETE EXECUTE au-dela
-- de la peine definitive. Huit jours prononces, deux purges, relaxe en appel : deux jours indus.
-- Huit prononces, deux purges, quatre en appel : zero indu, et deux jours restent a purger.
--
-- LA CASCADE DE PAIEMENT EST DEUX ETAGES, ET ELLE N'EST JAMAIS COMPOSITE. A la naissance de la
-- creance, le ministere de la Justice paie l'INTEGRALITE ou ne paie RIEN -- on ne prend pas la
-- moitie chez lui pour completer ailleurs. S'il ne peut pas, la creance passe aux Finances, qui
-- paient integralement si elles peuvent le faire IMMEDIATEMENT ; sinon la dette reste inscrite.
--
-- ENSUITE, LE PRELEVEMENT EST AUTOMATIQUE ET SANS DECISION HUMAINE. Un DECLENCHEUR sur la caisse
-- du ministere des Finances se declenche a chaque HAUSSE de son solde, d'ou qu'elle vienne --
-- cascade budgetaire, impot, vente, virement. C'est pour cela que c'est un declencheur et non un
-- appel pose dans quelques portes : un etage de plus dans le circuit fiscal aurait suffi a faire
-- oublier la dette. Le ministre n'a aucune latitude : ni l'ordre, ni le montant, ni le moment.
--
-- FIFO STRICT. La creance la plus ancienne est reglee ENTIEREMENT avant que la suivante ne recoive
-- un franc. La boucle s'ARRETE -- elle ne passe pas a la suivante -- des que la plus ancienne ne
-- peut pas etre finie : passer outre serait servir un cadet avant son aine.
--
-- LES PAIEMENTS PARTIELS SONT AUTORISES SUR UNE ALIMENTATION, PAS A LA NAISSANCE. C'est la
-- distinction exacte du cahier des charges, et elle porte le parametre `p_partiel`.
--
-- AUCUNE CAISSE NE DEVIENT NEGATIVE : le versement est borne par le solde lu SOUS VERROU, et le
-- solde est relu dans la meme transaction que le debit.
--
-- PREUVES STRUCTURELLES -- 10.

CREATE OR REPLACE FUNCTION public.justice_indemnite_par_jour()
RETURNS integer LANGUAGE sql IMMUTABLE AS $$ SELECT 1000 $$;
COMMENT ON FUNCTION public.justice_indemnite_par_jour() IS
  'L''indemnite d''un jour de prison execute a tort, en francs. Mille. Declaree une seule fois : la porte qui fait naitre la creance est la seule a la lire.';
REVOKE ALL ON FUNCTION public.justice_indemnite_par_jour() FROM PUBLIC;

CREATE TABLE IF NOT EXISTS public.justice_indemnites (
  id             text PRIMARY KEY,
  pays           text NOT NULL,
  beneficiaire   text NOT NULL,
  affaire        text,
  jugement       text,
  jours_indus    integer NOT NULL,
  montant_du     integer NOT NULL,
  montant_paye   integer NOT NULL DEFAULT 0,
  porteur        text NOT NULL,
  etat           text NOT NULL DEFAULT 'due',
  cree_le        timestamptz NOT NULL DEFAULT now(),
  regle_le       timestamptz,
  CONSTRAINT justice_indemnites_jours_positifs   CHECK (jours_indus > 0),
  CONSTRAINT justice_indemnites_montant_positif  CHECK (montant_du > 0),
  CONSTRAINT justice_indemnites_paye_borne       CHECK (montant_paye >= 0 AND montant_paye <= montant_du),
  CONSTRAINT justice_indemnites_porteur_connu    CHECK (porteur IN ('min_just', 'min_fin')),
  CONSTRAINT justice_indemnites_etat_connu       CHECK (etat IN ('due', 'reglee')),
  -- L'ETAT N'EST PAS UNE OPINION : il se deduit du montant paye, et la contrainte interdit qu'il
  -- en diverge. Une creance « reglee » a 0 FR verse serait une dette effacee sans paiement.
  CONSTRAINT justice_indemnites_etat_coherent
    CHECK ((etat = 'reglee') = (montant_paye = montant_du))
);
ALTER TABLE public.justice_indemnites ENABLE ROW LEVEL SECURITY;
-- UNE TABLE NEUVE NAIT OUVERTE : le defaut de la plateforme accorde ALL aux roles clients. Lecon
-- du 12 octobre, et elle vaut pour une table d'argent plus encore que pour les autres.
REVOKE ALL ON TABLE public.justice_indemnites FROM anon, authenticated;
CREATE INDEX IF NOT EXISTS justice_indemnites_file_fifo
  ON public.justice_indemnites (pays, etat, cree_le, id);

COMMENT ON TABLE public.justice_indemnites IS
  'LES CREANCES D''INDEMNISATION pour detention executee a tort : 1 000 FR par jour de prison EFFECTIVEMENT PURGE au-dela de la peine definitive. Chaque ligne porte son du, son paye et donc son reste. Le porteur est le ministere de la Justice quand il a pu payer l''integralite, les Finances sinon -- jamais un paiement composite. La file est FIFO STRICTE : la plus ancienne est reglee entierement avant la suivante.';
COMMENT ON COLUMN public.justice_indemnites.jours_indus IS
  'Jours de prison REELLEMENT PURGES en excedent de la peine definitive. Jamais l''ecart theorique entre deux jugements : un condamne a 8 jours qui n''en a purge que 2 et qui est relaxe est indemnise de 2 jours, pas de 8.';
COMMENT ON COLUMN public.justice_indemnites.porteur IS
  'Qui porte la creance : min_just quand il l''a payee en entier a la naissance, min_fin dans tous les autres cas. Un passage aux Finances est definitif -- on ne revient pas demander a la Justice.';

-- ============================================================================================
-- LA FILE, PAYEE PAR LES FINANCES
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_indemnites_payer_depuis_finances(
  p_pays text, p_partiel boolean DEFAULT true)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caisse text; v_data jsonb; v_solde numeric; v_c record;
  v_reste integer; v_verse integer; v_total integer := 0; v_n integer := 0;
BEGIN
  v_caisse := p_pays || '_gouvernement-min_fin';

  FOR v_c IN
    SELECT i.* FROM public.justice_indemnites i
     WHERE i.pays = p_pays AND i.etat = 'due' AND i.porteur = 'min_fin'
     ORDER BY i.cree_le, i.id
     FOR UPDATE
  LOOP
    -- LE SOLDE EST RELU A CHAQUE TOUR, SOUS VERROU. Le lire une fois avant la boucle ferait
    -- payer deux creances avec le meme argent.
    SELECT data INTO v_data FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
    v_solde := CASE WHEN v_data IS NOT NULL AND jsonb_typeof(v_data -> 'solde') = 'number'
                    THEN (v_data ->> 'solde')::numeric ELSE 0 END;
    IF v_solde <= 0 THEN EXIT; END IF;

    v_reste := v_c.montant_du - v_c.montant_paye;
    v_verse := least(v_reste, floor(v_solde)::integer);
    IF v_verse <= 0 THEN EXIT; END IF;

    -- FIFO STRICT. Si l'aine ne peut pas etre fini et que le partiel n'est pas autorise, on
    -- s'ARRETE : on ne saute pas a la creance suivante, meme si elle serait payable.
    IF v_verse < v_reste AND NOT coalesce(p_partiel, true) THEN EXIT; END IF;

    UPDATE public.caisses_batiments
       SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - v_verse),
           updated_at = now()
     WHERE id = v_caisse;

    -- INCREMENT, jamais « solde relu + montant » : c'est ce calcul qui ecraserait une fortune.
    UPDATE public.personnages_donnees
       SET arg = coalesce(arg, 0) + v_verse
     WHERE name = v_c.beneficiaire;

    UPDATE public.justice_indemnites
       SET montant_paye = v_c.montant_paye + v_verse,
           etat = CASE WHEN v_c.montant_paye + v_verse = v_c.montant_du THEN 'reglee' ELSE 'due' END,
           regle_le = CASE WHEN v_c.montant_paye + v_verse = v_c.montant_du THEN now() ELSE NULL END
     WHERE id = v_c.id;

    v_total := v_total + v_verse;
    v_n := v_n + 1;
    -- L'AINE N'EST PAS FINI : la file s'arrete la, par definition du FIFO strict.
    IF v_c.montant_paye + v_verse < v_c.montant_du THEN EXIT; END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'verse', v_total, 'creances_touchees', v_n);
END;
$$;
COMMENT ON FUNCTION public.justice_indemnites_payer_depuis_finances(text, boolean) IS
  'Regle la file des indemnites portees par les Finances, en FIFO STRICT : la plus ancienne d''abord, et la boucle s''arrete des qu''elle ne peut pas etre finie. `p_partiel` distingue les deux moments du cahier des charges : a la NAISSANCE d''une creance les Finances paient tout ou rien, a chaque ALIMENTATION de leur caisse le versement partiel est autorise. Le solde est relu sous verrou a chaque tour, donc deux creances ne peuvent pas etre payees avec le meme argent, et aucune caisse ne devient negative.';
REVOKE ALL ON FUNCTION public.justice_indemnites_payer_depuis_finances(text, boolean) FROM PUBLIC;

-- ============================================================================================
-- LA NAISSANCE D'UNE CREANCE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_indemnite_naitre(
  p_pays text, p_beneficiaire text, p_affaire text, p_jugement text, p_jours integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_montant integer; v_id text; v_caisse text; v_data jsonb; v_solde numeric;
  v_porteur text; v_paye integer := 0; v_r jsonb;
BEGIN
  IF coalesce(p_jours, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'indemnite', false, 'raison', 'aucun_jour_indu');
  END IF;
  v_montant := p_jours * public.justice_indemnite_par_jour();
  v_id := 'ind-' || substr(md5(coalesce(p_affaire, '') || '|' || p_beneficiaire || '|'
                               || coalesce(p_jugement, '')), 1, 16);
  -- IDEMPOTENCE PAR IDENTIFIANT DERIVE : un jugement d'appel rejoue ne cree pas deux creances.
  IF EXISTS (SELECT 1 FROM public.justice_indemnites WHERE id = v_id) THEN
    RETURN jsonb_build_object('ok', true, 'indemnite', true, 'deja_nee', true, 'id', v_id);
  END IF;

  -- PREMIER ETAGE : LA JUSTICE PAIE TOUT, OU NE PAIE RIEN. Pas de paiement composite -- c'est
  -- une regle explicite, et elle evite qu'une creance soit a cheval sur deux budgets.
  v_caisse := p_pays || '_gouvernement-min_just';
  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
  v_solde := CASE WHEN v_data IS NOT NULL AND jsonb_typeof(v_data -> 'solde') = 'number'
                  THEN (v_data ->> 'solde')::numeric ELSE 0 END;

  IF v_solde >= v_montant THEN
    UPDATE public.caisses_batiments
       SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - v_montant),
           updated_at = now()
     WHERE id = v_caisse;
    UPDATE public.personnages_donnees
       SET arg = coalesce(arg, 0) + v_montant
     WHERE name = p_beneficiaire;
    v_porteur := 'min_just'; v_paye := v_montant;
  ELSE
    -- RIEN N'EST PRELEVE CHEZ LA JUSTICE. La creance change de porteur, definitivement.
    v_porteur := 'min_fin'; v_paye := 0;
  END IF;

  INSERT INTO public.justice_indemnites
    (id, pays, beneficiaire, affaire, jugement, jours_indus, montant_du, montant_paye,
     porteur, etat, regle_le)
  VALUES (v_id, p_pays, p_beneficiaire, p_affaire, p_jugement, p_jours, v_montant, v_paye,
          v_porteur, CASE WHEN v_paye = v_montant THEN 'reglee' ELSE 'due' END,
          CASE WHEN v_paye = v_montant THEN now() ELSE NULL END);

  -- SECOND ETAGE : LES FINANCES PAIENT L'INTEGRALITE, OU LA DETTE RESTE. Le partiel n'est permis
  -- qu'aux alimentations ulterieures de leur caisse -- d'ou `p_partiel => false` ici.
  IF v_porteur = 'min_fin' THEN
    v_r := public.justice_indemnites_payer_depuis_finances(p_pays, false);
  END IF;

  RETURN jsonb_build_object('ok', true, 'indemnite', true, 'id', v_id,
    'jours_indus', p_jours, 'montant', v_montant, 'porteur', v_porteur,
    'paye', (SELECT montant_paye FROM public.justice_indemnites WHERE id = v_id),
    'etat', (SELECT etat FROM public.justice_indemnites WHERE id = v_id));
END;
$$;
COMMENT ON FUNCTION public.justice_indemnite_naitre(text, text, text, text, integer) IS
  'Fait naitre une creance d''indemnisation et tente la cascade : la Justice paie l''INTEGRALITE ou rien du tout, puis les Finances paient l''integralite si elles peuvent le faire immediatement, sinon la dette reste inscrite et sera prelevee a chaque alimentation de leur caisse. Idempotente par identifiant derive : un jugement d''appel rejoue ne cree pas deux creances.';
REVOKE ALL ON FUNCTION public.justice_indemnite_naitre(text, text, text, text, integer) FROM PUBLIC;

-- ============================================================================================
-- LE DECLENCHEUR : TOUTE HAUSSE DE LA CAISSE DES FINANCES PAIE LA FILE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_indemnites_sur_alimentation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_av numeric; v_ap numeric; v_pays text;
BEGIN
  -- RECURSION : le paiement DEBITE cette meme caisse, donc ce declencheur se rappelle. Le garde
  -- est double -- un verrou de portee, et le fait qu'une BAISSE ne declenche rien.
  IF coalesce(current_setting('rp.indemnites_en_cours', true), '') = 'on' THEN
    RETURN NEW;
  END IF;
  IF NEW.id NOT LIKE '%\_gouvernement-min\_fin' THEN RETURN NEW; END IF;

  v_av := CASE WHEN jsonb_typeof(OLD.data -> 'solde') = 'number'
               THEN (OLD.data ->> 'solde')::numeric ELSE 0 END;
  v_ap := CASE WHEN jsonb_typeof(NEW.data -> 'solde') = 'number'
               THEN (NEW.data ->> 'solde')::numeric ELSE 0 END;
  IF v_ap <= v_av THEN RETURN NEW; END IF;

  v_pays := split_part(NEW.id, '_gouvernement-min_fin', 1);
  IF coalesce(v_pays, '') = '' THEN RETURN NEW; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.justice_indemnites
                  WHERE pays = v_pays AND etat = 'due' AND porteur = 'min_fin') THEN
    RETURN NEW;
  END IF;

  PERFORM set_config('rp.indemnites_en_cours', 'on', true);
  PERFORM public.justice_indemnites_payer_depuis_finances(v_pays, true);
  PERFORM set_config('rp.indemnites_en_cours', '', true);
  RETURN NEW;
END;
$$;
COMMENT ON FUNCTION public.justice_indemnites_sur_alimentation() IS
  'A CHAQUE HAUSSE du solde de la caisse du ministere des Finances, la file des indemnites impayees est prelevee automatiquement, en FIFO strict et sans aucune decision humaine. C''est un DECLENCHEUR et non un appel pose dans quelques portes : l''alimentation vient de partout -- cascade budgetaire, impot, vente, virement -- et un etage de plus dans le circuit fiscal aurait suffi a faire oublier la dette. Une BAISSE ne declenche rien, ce qui coupe la recursion que le paiement lui-meme provoquerait.';

DROP TRIGGER IF EXISTS trg_justice_indemnites_sur_alimentation ON public.caisses_batiments;
CREATE TRIGGER trg_justice_indemnites_sur_alimentation
  AFTER UPDATE OF data ON public.caisses_batiments
  FOR EACH ROW EXECUTE FUNCTION public.justice_indemnites_sur_alimentation();

-- ============================================================================================
-- LA LECTURE DU BENEFICIAIRE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.justice_mes_indemnites()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  RETURN jsonb_build_object('ok', true, 'indemnites', coalesce((
    SELECT jsonb_agg(jsonb_build_object(
             'id', i.id, 'affaire', i.affaire, 'jours_indus', i.jours_indus,
             'du', i.montant_du, 'paye', i.montant_paye,
             'reste', i.montant_du - i.montant_paye,
             'porteur', i.porteur, 'etat', i.etat,
             'cree_le', i.cree_le, 'regle_le', i.regle_le) ORDER BY i.cree_le)
      FROM public.justice_indemnites i WHERE i.beneficiaire = v_moi), '[]'::jsonb));
END;
$$;
COMMENT ON FUNCTION public.justice_mes_indemnites() IS
  'Les creances d''indemnisation du joueur courant, avec leur du, leur paye et leur reste. Lecture seule, et de SES creances uniquement : la dette de l''Etat envers un autre joueur n''est pas une information publique.';
REVOKE ALL ON FUNCTION public.justice_mes_indemnites() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.justice_mes_indemnites() TO authenticated;

DO $preuves$
DECLARE v_n integer; v_txt text;
BEGIN
  -- P1 : LA TABLE EST SOUS RLS, SANS POLICY, SANS DROIT CLIENT.
  SELECT count(*) INTO v_n FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname = 'justice_indemnites' AND c.relrowsecurity;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P1 ECHOUEE -- table absente ou sans RLS'; END IF;
  SELECT count(*) INTO v_n FROM pg_class c, aclexplode(c.relacl) a
   WHERE c.oid = 'public.justice_indemnites'::regclass
     AND (SELECT rolname FROM pg_roles WHERE oid = a.grantee) IN ('anon', 'authenticated');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % droit(s) client sur une table d''argent', v_n; END IF;
  SELECT count(*) INTO v_n FROM pg_policy WHERE polrelid = 'public.justice_indemnites'::regclass;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % policy(s)', v_n; END IF;

  -- P2 : L'ETAT NE PEUT PAS DIVERGER DU MONTANT PAYE. Une creance « reglee » a zero verse serait
  -- une dette effacee sans paiement.
  SELECT count(*) INTO v_n FROM pg_constraint
   WHERE conrelid = 'public.justice_indemnites'::regclass
     AND conname IN ('justice_indemnites_etat_coherent', 'justice_indemnites_paye_borne',
                     'justice_indemnites_porteur_connu');
  IF v_n <> 3 THEN RAISE EXCEPTION 'P2 ECHOUEE -- % contrainte(s) de coherence au lieu de 3', v_n; END IF;

  -- P3 : LE TARIF EST DECLARE UNE FOIS, ET IL VAUT MILLE.
  IF public.justice_indemnite_par_jour() <> 1000 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- l''indemnite journaliere ne vaut pas 1000 FR'; END IF;
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_indemnite_naitre';
  IF position('public.justice_indemnite_par_jour()' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le tarif est recopie au lieu d''etre lu'; END IF;

  -- P4 : LA JUSTICE PAIE TOUT OU RIEN. Le seuil est une comparaison au montant ENTIER.
  IF position('IF v_solde >= v_montant THEN' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- la Justice pourrait payer partiellement'; END IF;

  -- P5 : LES FINANCES NE PAIENT PAS PARTIELLEMENT A LA NAISSANCE.
  IF position('justice_indemnites_payer_depuis_finances(p_pays, false)' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- le partiel est autorise des la naissance de la creance'; END IF;

  -- P6 : L'IDEMPOTENCE EST PAR IDENTIFIANT DERIVE.
  IF position('WHERE id = v_id' IN v_txt) = 0 OR position('md5(' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- une creance peut naitre deux fois'; END IF;

  -- P7 : LA FILE EST FIFO ET LE SOLDE EST RELU SOUS VERROU A CHAQUE TOUR.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_indemnites_payer_depuis_finances';
  IF position('ORDER BY i.cree_le, i.id' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- la file n''est pas ordonnee par anciennete'; END IF;
  IF position('FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- le solde n''est pas relu sous verrou dans la boucle'; END IF;

  -- P8 : LE FIFO EST STRICT -- la boucle SORT quand l'aine n'est pas fini, elle ne continue pas.
  IF position('IF v_c.montant_paye + v_verse < v_c.montant_du THEN EXIT; END IF;' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- la file sert un cadet avant son aine'; END IF;

  -- P9 : AUCUNE CAISSE NEGATIVE. Le versement est borne par le solde lu.
  IF position('least(v_reste, floor(v_solde)::integer)' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P9 ECHOUEE -- le versement n''est pas borne par le solde'; END IF;

  -- P10 : LE DECLENCHEUR EST POSE SUR LA CAISSE, NE MORD QUE SUR UNE HAUSSE, ET COUPE SA PROPRE
  -- RECURSION.
  SELECT count(*) INTO v_n FROM pg_trigger t
   WHERE t.tgrelid = 'public.caisses_batiments'::regclass AND NOT t.tgisinternal
     AND t.tgname = 'trg_justice_indemnites_sur_alimentation';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P10 ECHOUEE -- declencheur d''alimentation absent'; END IF;
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'justice_indemnites_sur_alimentation';
  IF position('IF v_ap <= v_av THEN RETURN NEW; END IF;' IN v_txt) = 0
     OR position('rp.indemnites_en_cours' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- le declencheur ne borne pas aux hausses ou ne coupe pas sa recursion'; END IF;

  RAISE NOTICE 'LES 10 PREUVES SONT VERTES.';
END $preuves$;
