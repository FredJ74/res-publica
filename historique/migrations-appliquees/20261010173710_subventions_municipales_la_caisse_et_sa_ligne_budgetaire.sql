-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010173710 (UTC), nom `subventions_municipales_la_caisse_et_sa_ligne_budgetaire`.
-- Le registre passe de 623 a 624 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 3f0ec3708a6c7042c6602fc3f47451cd, 7704 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CHAINE 7, ETAGE 1 -- L'ENVELOPPE MUNICIPALE DES SUBVENTIONS
--
-- Trois choses et rien de plus : le motif de caisse `subventions` en PREFIXE avec une liste de
-- postes VIDE -- ce qui vaut `caisse_reservee_au_serveur`, donc le maire ne debite jamais
-- l'enveloppe a la main -- les trois caisses municipales de Republia a zero, et une quatrieme
-- ligne de repartition par mairie a 0 %, sur le precedent exact du QHS : la ligne existe et est
-- editable, mais ne deplace pas un franc avant que le maire ne le decide. AUCUN flux existant ne
-- change, et seule Republia est semee -- inventer une enveloppe aux trois autres empires serait
-- inventer un parametre economique.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHAINE 7, ETAGE 1 -- L'ENVELOPPE MUNICIPALE DES SUBVENTIONS (arbitrage du 10 octobre 2026)
--
-- LE PRINCIPE EST ARBITRE : une commune peut subventionner les organisations eligibles de son
-- territoire. C'est un levier politique, et il passe par le circuit budgetaire EXISTANT -- pas par
-- un second mecanisme.
--
-- TROIS CHOSES, ET RIEN DE PLUS :
--
--   1. UNE REGLE D'AUTORITE DE CAISSE. `caisses_autorites` recoit le motif `subventions`, en
--      PREFIXE, avec une liste de postes VIDE. Un tableau vide n'est pas un oubli : c'est
--      `caisse_reservee_au_serveur` dans `caisse_refus_autorite`. Le maire ne peut donc PAS
--      debiter cette caisse a la main -- ni par la primitive, ni par un client modifie. Elle ne
--      se vide que par la porte des subventions, qui viendra avec son laissez-passer.
--      Le prefixe fait que `subventions_<ville>` est de portee VILLE pour `caisse_territoire`,
--      a condition que `<ville>` passe `ville_est_reelle` -- la meme regle que les mairies.
--
--   2. TROIS CAISSES, A ZERO. Une par commune de Republia. Elles sont CUMULATIVES par
--      construction : `caisse_institution_mouvement` ajoute un delta a un solde, il ne le
--      remplace pas. L'argent non depense reste donc disponible les jours suivants, et un
--      changement de maire n'y touche pas -- la caisse appartient a la commune, pas au titulaire.
--
--   3. UNE QUATRIEME LIGNE DE REPARTITION PAR MAIRIE, A 0 %. Le maire la montera lui-meme depuis
--      l'ecran qu'il connait deja (`repartition_budget_local`). La part a 0 % par defaut est le
--      precedent EXACT du QHS (registre du 8 octobre) : la ligne existe, elle est visible, elle
--      est editable, et elle ne deplace pas un franc tant que personne ne l'a decidee. Les trois
--      villes restent donc a 40/40/20/0 = 100 %, et AUCUN flux existant ne change.
--
-- CE QUE CETTE MIGRATION NE FAIT PAS, ET C'EST DELIBERE :
--   * elle ne touche NI la caisse du stade (`stade_<ville>`, un batiment municipal qui a ses
--     propres depenses) NI la caisse d'un club : l'enveloppe est une caisse municipale DISTINCTE ;
--   * elle ne seme que REPUBLIA. Les trois autres empires n'ont aucune ligne de
--     `repartitions_budgetaires` aujourd'hui, et leur inventer une enveloppe de subventions serait
--     inventer un parametre economique. Absence de configuration n'est pas un repli sur Republia ;
--   * elle ne connecte PAS `budgets_municipaux.data.indices.associatif`, qui reste hors perimetre.

INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES
  ('subventions', true, '{}',
   'Enveloppe municipale des subventions aux organisations eligibles. Liste de postes VIDE = '
   'caisse_reservee_au_serveur : le maire ne la debite jamais a la main, seulement par la porte '
   'des subventions. Prefixe pour que subventions_<ville> soit de portee VILLE.')
ON CONFLICT (motif) DO NOTHING;

INSERT INTO public.caisses_batiments (id, data, updated_at) VALUES
  ('republic_subventions_capitale', jsonb_build_object('solde', 0), now()),
  ('republic_subventions_ville_a',  jsonb_build_object('solde', 0), now()),
  ('republic_subventions_ville_b',  jsonb_build_object('solde', 0), now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.repartitions_budgetaires
  (pays, source, beneficiaire, poste_autorite, rang, libelle, note,
   part_numerateur, part_denominateur) VALUES
  ('republic', 'mairie-capitale', 'subventions_capitale', 'maire', 4, 'Subventions',
   'ARBITRAGE DU 10 OCTOBRE 2026 : la commune peut subventionner les organisations eligibles de '
   'son territoire. Part a 0 % PAR DEFAUT -- meme precedent que le QHS : la ligne existe et est '
   'editable, elle ne deplace rien tant que le maire ne l''a pas decidee. La caisse est '
   'CUMULATIVE et appartient a la commune, pas au maire.', 0, 100),
  ('republic', 'mairie_ville_a', 'subventions_ville_a', 'maire', 4, 'Subventions',
   'ARBITRAGE DU 10 OCTOBRE 2026 : voir la ligne de Luthecia. Part a 0 % par defaut.', 0, 100),
  ('republic', 'mairie_ville_b', 'subventions_ville_b', 'maire', 4, 'Subventions',
   'ARBITRAGE DU 10 OCTOBRE 2026 : voir la ligne de Luthecia. Part a 0 % par defaut.', 0, 100)
ON CONFLICT (pays, source, beneficiaire) DO NOTHING;

DO $p$
DECLARE r record; v integer; v_portee text; v_ville text; v_num numeric; v_den numeric;
BEGIN
  -- P1 : la regle d'autorite existe, en prefixe, et RESERVE LA CAISSE AU SERVEUR.
  SELECT * INTO r FROM public.caisses_autorites WHERE motif = 'subventions';
  IF NOT FOUND THEN RAISE EXCEPTION 'P1 : la regle d''autorite est absente'; END IF;
  IF NOT r.est_prefixe THEN RAISE EXCEPTION 'P1 : la regle n''est pas un prefixe'; END IF;
  IF coalesce(array_length(r.postes_debit, 1), 0) <> 0 THEN
    RAISE EXCEPTION 'P1 : % poste(s) peuvent debiter l''enveloppe -- elle doit etre vide',
      array_length(r.postes_debit, 1);
  END IF;

  -- P2 : chaque caisse est de portee VILLE, et sa ville est la bonne.
  FOR r IN SELECT * FROM (VALUES ('capitale'), ('ville_a'), ('ville_b')) v(ville) LOOP
    SELECT t.portee, t.ville INTO v_portee, v_ville
      FROM public.caisse_territoire('republic_subventions_' || r.ville, 'republic') t;
    IF v_portee <> 'ville' OR v_ville <> r.ville THEN
      RAISE EXCEPTION 'P2 : subventions_% est de portee % (ville %)', r.ville, v_portee, v_ville;
    END IF;
  END LOOP;

  -- P3 : un acteur CLIENT ne peut pas debiter l'enveloppe. On interroge la regle, pas la chance.
  IF public.caisse_refus_autorite('republic_subventions_capitale', 'republic')
     IS DISTINCT FROM 'caisse_reservee_au_serveur' THEN
    RAISE EXCEPTION 'P3 : l''enveloppe n''est pas reservee au serveur -- %',
      public.caisse_refus_autorite('republic_subventions_capitale', 'republic');
  END IF;

  -- P4 : les trois caisses existent, a zero.
  SELECT count(*) INTO v FROM public.caisses_batiments
   WHERE id LIKE 'republic_subventions_%' AND (data->>'solde')::numeric = 0;
  IF v <> 3 THEN RAISE EXCEPTION 'P4 : % caisse(s) d''enveloppe a zero au lieu de 3', v; END IF;

  -- P5 : LES TROIS SOMMES RESTENT A 100 % EXACTEMENT. C'est la preuve qu'aucun flux ne change.
  FOR r IN SELECT * FROM (VALUES ('mairie-capitale'), ('mairie_ville_a'), ('mairie_ville_b')) v(src) LOOP
    SELECT numerateur, denominateur INTO v_num, v_den
      FROM public.budget_part_totale('republic', r.src);
    IF v_num <> v_den THEN
      RAISE EXCEPTION 'P5 : la somme de % vaut %/% et non 100 %%', r.src, v_num, v_den;
    END IF;
  END LOOP;

  -- P6 : la ligne est a 0 %, visible, et sous l'autorite du maire.
  SELECT count(*) INTO v FROM public.repartitions_budgetaires
   WHERE pays = 'republic' AND beneficiaire LIKE 'subventions\_%'
     AND libelle = 'Subventions' AND poste_autorite = 'maire'
     AND part_numerateur = 0 AND part_denominateur = 100;
  IF v <> 3 THEN RAISE EXCEPTION 'P6 : % ligne(s) de subvention conforme(s) au lieu de 3', v; END IF;

  -- P7 : NI LE STADE NI UN CLUB N'EST DEVENU BENEFICIAIRE D'UNE REPARTITION.
  IF EXISTS (SELECT 1 FROM public.repartitions_budgetaires
              WHERE beneficiaire LIKE 'stade%'
                 OR beneficiaire IN (SELECT id FROM public.clubs_football)) THEN
    RAISE EXCEPTION 'P7 : une caisse de stade ou de club a ete detournee en beneficiaire';
  END IF;

  -- P8 : AUCUN AUTRE EMPIRE N'A RECU DE LIGNE. Absence de configuration n'est pas un repli.
  IF EXISTS (SELECT 1 FROM public.repartitions_budgetaires
              WHERE pays <> 'republic' AND beneficiaire LIKE 'subventions\_%') THEN
    RAISE EXCEPTION 'P8 : un autre empire a recu une enveloppe de subventions non arbitree';
  END IF;

  RAISE NOTICE 'Enveloppe des subventions : 8 preuves structurelles vertes.';
END $p$;
