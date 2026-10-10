-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010175550 (UTC), nom `subventions_l_expiration_nocturne_et_les_deux_lectures`.
-- Le registre passe de 629 a 630 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 68031d525e0131c5c992873214367fcf, 9604 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CHAINE 7, §3 ET §6 -- L'EXPIRATION NOCTURNE ET LES DEUX LECTURES
--
-- `subventions_expirer` n'est PAS un `acte_nocturne`, et l'en-tete dit pourquoi : l'expiration est
-- idempotente par nature -- son UPDATE ne trouve que les propositions encore `proposee` et echues
-- -- de sorte qu'une revendication serait une ceremonie sans effet, et une ceremonie inutile finit
-- par etre prise pour une garantie. Elle ne deplace aucun argent : la reserve etant une SOMME, le
-- changement de statut la libere, donc il n'y a rien a rater. La trace publique est la ligne
-- elle-meme, sans table d'archive recopiee. Les deux lectures s'ajoutent : l'enveloppe vue par son
-- maire, et les propositions qu'un gestionnaire de caisse peut trancher -- par le MEME resolveur
-- que la porte de reponse, pour que l'interface ne montre jamais un bouton qu'elle refuserait.
--
-- NOTE D'ARCHIVE : le corps contient deux coquilles, « paralelle » et « divergeer ». Elles sont
-- conservees -- une archive doit dire la verite sur ce qui a ete applique.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHAINE 7, §3 et §6 -- L'EXPIRATION ET LES LECTURES (10 octobre 2026)
--
-- POURQUOI L'EXPIRATION N'EST PAS UN `acte_nocturne`. La brique `actes_nocturnes` existe pour
-- rendre idempotent un acte qui ne l'est pas -- une taxe prelevee deux fois, une mensualite
-- payee deux fois. L'expiration, elle, est idempotente PAR NATURE : son UPDATE ne trouve que les
-- propositions encore `proposee` dont l'echeance est passee, et un second passage n'en trouve
-- plus aucune. Ajouter une revendication serait de la ceremonie sans effet -- et une ceremonie
-- inutile finit par etre prise pour une garantie.
--
-- L'EXPIRATION NE DEPLACE AUCUN ARGENT, ET C'EST TOUT L'INTERET DU MODELE. Comme la reserve est
-- la SOMME des propositions en attente, changer le statut libere le montant sans une seule
-- ecriture financiere. Il n'y a donc rien a rater : pas de debit a compenser, pas de credit a
-- annuler, pas de fenetre entre deux ecritures.
--
-- LA TRACE PUBLIQUE EST LA LIGNE ELLE-MEME. « Un non-dit de trois jours doit aussi laisser une
-- trace publique » : la proposition expiree reste en base avec sa date, son maire, son
-- beneficiaire, son montant et son statut, et la policy de lecture la rend publique des qu'elle
-- est close. Aucune table d'archive paralelle n'est creee -- une archive recopiee est une archive
-- qui peut divergeer de la realite.

CREATE OR REPLACE FUNCTION public.subventions_expirer(p_pays text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_jour integer; v_n integer := 0; v_total numeric := 0;
BEGIN
  v_jour := public.jour_de_jeu_pays(p_pays);
  IF v_jour IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jour_indetermine', 'pays', p_pays); END IF;

  WITH closes AS (
    UPDATE public.subventions_municipales
       SET statut = 'expiree', clos_le = now()
     WHERE pays = p_pays AND statut = 'proposee' AND v_jour >= jour_echeance
    RETURNING montant)
  SELECT count(*), coalesce(sum(montant), 0) INTO v_n, v_total FROM closes;

  RETURN jsonb_build_object('ok', true, 'pays', p_pays, 'jour', v_jour,
                            'expirees', v_n, 'montant_libere', v_total);
END $$;

COMMENT ON FUNCTION public.subventions_expirer(text) IS
  'Cloture les propositions dont l''echeance est atteinte. Idempotente par nature -- aucune '
  'revendication nocturne n''est necessaire. Ne deplace aucun argent : la reserve etant la somme '
  'des propositions en attente, le changement de statut suffit a la liberer. Reservee au serveur.';

CREATE OR REPLACE FUNCTION public.subvention_enveloppe_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_moi text; v_poste text; v_ville text; v_pays text;
  v_caisse text; v_solde numeric; v_reserve numeric; v_jour integer;
  v_part numeric; v_attente jsonb; v_eligibles jsonb;
BEGIN
  -- L'ENVELOPPE VUE PAR SON MAIRE. Reservee a lui : les propositions encore en attente ne sont
  -- pas publiques (seules les issues le sont, arbitrage §5), et le solde comme la reserve n'ont
  -- de sens que pour celui qui engage les fonds.
  SELECT a.nom, a.poste_id, coalesce(a.poste_city, ''), a.pays
    INTO v_moi, v_poste, v_ville, v_pays FROM public.acteur_poste_courant() a LIMIT 1;
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF v_poste IS DISTINCT FROM 'maire' OR v_ville = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                              'poste_requis', 'maire'); END IF;

  v_caisse := v_pays || '_subventions_' || v_ville;
  SELECT coalesce((b.data->>'solde')::numeric, 0) INTO v_solde
    FROM public.caisses_batiments b WHERE b.id = v_caisse;
  IF v_solde IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'enveloppe_absente', 'caisse', v_caisse); END IF;

  SELECT coalesce(sum(s.montant), 0) INTO v_reserve FROM public.subventions_municipales s
   WHERE s.pays = v_pays AND s.ville = v_ville AND s.statut = 'proposee';

  -- LA PART BUDGETAIRE DE L'ETAGE 1, pour que le maire voie d'un coup d'oeil ce qui alimente
  -- l'enveloppe et ce qu'il en reste.
  SELECT round(r.part_numerateur * 100 / r.part_denominateur, 4) INTO v_part
    FROM public.repartitions_budgetaires r
   WHERE r.pays = v_pays AND r.beneficiaire = 'subventions_' || v_ville
     AND r.part_numerateur IS NOT NULL;

  v_jour := public.jour_de_jeu_pays(v_pays);

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', s.id, 'beneficiaire', s.beneficiaire, 'beneficiaire_nom', s.beneficiaire_nom,
           'famille', s.famille, 'montant', s.montant, 'jour', s.jour,
           'jour_echeance', s.jour_echeance, 'jours_restants', s.jour_echeance - v_jour)
           ORDER BY s.created_at), '[]'::jsonb) INTO v_attente
    FROM public.subventions_municipales s
   WHERE s.pays = v_pays AND s.ville = v_ville AND s.statut = 'proposee';

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'famille', l.famille, 'libelle_famille', l.libelle_famille,
           'id', l.organisation_id, 'nom', l.nom, 'peut_repondre', l.caisse_connue)), '[]'::jsonb)
    INTO v_eligibles
    FROM public.subvention_organisations_locales(v_pays, v_ville) l;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'ville', v_ville, 'jour', v_jour,
    'caisse', v_caisse, 'solde', v_solde, 'reserve', v_reserve,
    'disponible', v_solde - v_reserve, 'part_budgetaire_pct', coalesce(v_part, 0),
    'en_attente', v_attente, 'eligibles', v_eligibles);
END $$;

COMMENT ON FUNCTION public.subvention_enveloppe_lire() IS
  'Etage 2, vue du maire : solde de l''enveloppe, sommes reservees, disponible reel, propositions '
  'en attente, organisations localement eligibles et part budgetaire de l''etage 1. La ville et '
  'le poste ne sont pas recus du client, ils sont lus.';

CREATE OR REPLACE FUNCTION public.subventions_recues_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_moi text; v_recues jsonb;
BEGIN
  -- CE QUE JE PEUX ACCEPTER OU REFUSER. La question n'est pas « de quelle organisation suis-je
  -- membre » mais « pour laquelle suis-je GESTIONNAIRE DE CAISSE » -- et c'est le meme resolveur
  -- que la porte de reponse appliquera, donc l'interface ne peut pas montrer un bouton que la
  -- porte refuserait.
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', s.id, 'commune', s.ville, 'pays', s.pays, 'maire', s.maire,
           'famille', s.famille, 'beneficiaire', s.beneficiaire,
           'beneficiaire_nom', s.beneficiaire_nom, 'montant', s.montant,
           'jour', s.jour, 'jour_echeance', s.jour_echeance,
           'jours_restants', s.jour_echeance - public.jour_de_jeu_pays(s.pays))
           ORDER BY s.created_at), '[]'::jsonb) INTO v_recues
    FROM public.subventions_municipales s
   WHERE s.statut = 'proposee'
     AND public.subvention_gestionnaire(s.famille, s.beneficiaire) = v_moi;

  RETURN jsonb_build_object('ok', true, 'gestionnaire', v_moi, 'recues', v_recues);
END $$;

COMMENT ON FUNCTION public.subventions_recues_lire() IS
  'Les propositions qu''un joueur peut accepter ou refuser, parce qu''il est gestionnaire de la '
  'caisse de l''organisation beneficiaire. Meme resolveur que la porte de reponse : l''interface '
  'ne peut pas proposer une action que la porte refuserait.';

GRANT EXECUTE ON FUNCTION public.subvention_enveloppe_lire() TO authenticated;
GRANT EXECUTE ON FUNCTION public.subventions_recues_lire() TO authenticated;

DO $p$
DECLARE v integer;
BEGIN
  -- P1 : L'EXPIRATION EST RESERVEE AU SERVEUR. Un client qui pourrait l'appeler pourrait liberer
  -- la reserve d'une commune a volonte.
  IF has_function_privilege('authenticated', 'public.subventions_expirer(text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.subventions_expirer(text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'P1 : un client peut declencher l''expiration des subventions';
  END IF;

  -- P2 : les deux lectures sont appelables par un client authentifie, jamais par anon.
  IF NOT has_function_privilege('authenticated', 'public.subvention_enveloppe_lire()', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.subventions_recues_lire()', 'EXECUTE') THEN
    RAISE EXCEPTION 'P2a : les lectures ne sont pas accessibles a un joueur authentifie'; END IF;
  IF has_function_privilege('anon', 'public.subvention_enveloppe_lire()', 'EXECUTE')
     OR has_function_privilege('anon', 'public.subventions_recues_lire()', 'EXECUTE') THEN
    RAISE EXCEPTION 'P2b : anon peut lire une enveloppe ou des propositions en attente'; END IF;

  -- P3 : l'expiration tourne sur une base sans proposition et ne ment pas sur son resultat.
  IF (public.subventions_expirer('republic')->>'expirees')::integer <> 0 THEN
    RAISE EXCEPTION 'P3 : l''expiration annonce des clotures sur une table vide'; END IF;

  -- P4 : les quatre fonctions de la chaine sont en place.
  SELECT count(*) INTO v FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname IN
     ('subvention_proposer','subvention_repondre','subventions_expirer',
      'subvention_enveloppe_lire','subventions_recues_lire');
  IF v <> 5 THEN RAISE EXCEPTION 'P4 : % fonction(s) de la chaine au lieu de 5', v; END IF;

  RAISE NOTICE 'Expiration et lectures : 4 preuves structurelles vertes.';
END $p$;
