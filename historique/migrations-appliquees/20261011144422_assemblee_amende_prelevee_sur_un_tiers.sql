-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011144422 (UTC), nom
-- `assemblee_amende_prelevee_sur_un_tiers`.
-- Le registre passe de 652 a 653 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 3916e711274ab97f238afbfc7c2ecca4, 10754 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- UNE AMENDE SE PRELEVE SUR LA POCHE D'UN AUTRE
--
-- SECOND DEFAUT DE LA MEME FAMILLE, trouve par le banc. `assemblee_sanctionner` appelait
-- `assemblee_debiter_joueur`, qui ecrit par la VUE `personnages` : son trigger refuse la fiche
-- d'autrui hors appel serveur. Et cette porte avait raison -- elle a ete ecrite pour un joueur
-- qui paie SON action, jamais pour un President qui prend 100 FR dans la poche d'un autre. On ne
-- la change donc pas : on cesse de lui demander ce qu'elle n'a jamais promis.
-- LA PRIMITIVE EXISTAIT : `helvetia_debiter_fonds_ordinaires` fait exactement cela -- liquide
-- puis Banque nationale, ecriture directe, et `false` sans rien toucher si les fonds manquent.
-- DETTE SIGNALEE, HORS DE CE CHANTIER : cette primitive est GENERIQUE mais porte le nom d'UNE
-- mecanique. Le bon correctif est un renommage avec ses appelants, dans une passe separee. La
-- recopier ici aurait ete pire : une 43e copie executee de la meme cascade.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- UNE AMENDE SE PRELEVE SUR LA POCHE D'UN AUTRE (11 octobre 2026)
-- =================================================================================================
-- LE SECOND DEFAUT DE LA MEME FAMILLE, trouve par le banc. `assemblee_sanctionner` appelait
-- `assemblee_debiter_joueur`, qui ecrit par la VUE `personnages` : le trigger de cette vue refuse
-- toute ecriture sur la fiche d'AUTRUI hors appel serveur. Et cette porte avait raison de faire
-- ainsi -- elle a ete ecrite pour un joueur qui paie SON action (marchander un vote, reveiller un
-- depute), jamais pour un President qui prend 100 FR dans la poche d'un autre. On ne la change donc
-- pas : on cesse de lui demander ce qu'elle n'a jamais promis.
--
-- ET LE JEU AVAIT DEJA LA PRIMITIVE. `helvetia_debiter_fonds_ordinaires(personnage, montant)`
-- fait exactement, et seulement, ce qu'il faut : liquide d'abord, complement sur la Banque
-- nationale, ecriture directe dans `personnages_donnees` -- donc sans passer par la vue -- et
-- surtout un retour `false` qui NE TOUCHE A RIEN quand les fonds manquent. Elle est reservee au
-- serveur, ce qui convient : seule une fonction SECURITY DEFINER peut l'appeler.
--
-- DETTE SIGNALEE, ET ELLE N'EST PAS DE CE CHANTIER : cette primitive est GENERIQUE mais porte le
-- nom d'UNE mecanique, la banque Helvetia. Un futur arbitrage sur Helvetia pourrait donc changer en
-- silence le prelevement d'une amende parlementaire. Le bon correctif est un simple renommage en
-- `debiter_fonds_ordinaires` avec ses appelants -- une passe separee. En attendant, la recopier ici
-- aurait ete pire : ce serait une 43e copie executee de la meme cascade, le defaut que le chantier
-- des fonctions recopiees cherche precisement a reduire.
--
-- L'ORDRE DES EFFETS NE CHANGE PAS, et c'est lui qui interdit le demi-effet : le debit d'abord
-- (un manque de fonds est un refus LEGITIME, il n'ecrit rien), puis le credit de la caisse dans la
-- meme transaction, puis la popularite -- dont l'echec leve une exception qui annule le debit ET
-- le credit. Il n'existe aucun ordre dans lequel 100 FR partent sans arriver.
-- =================================================================================================

CREATE OR REPLACE FUNCTION public.assemblee_sanctionner(p_depute text, p_motif text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  POP_SANCTION constant integer := -20;
  AMENDE       constant integer := 100;
  v_moi text; v_pays text; v_m text; v_id text; v_chron text; v_rappel text;
  v_caisse text; v_paye boolean; v_pop jsonb; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;

  -- LA GARDE, AVANT TOUT DEBIT. Une sanction rejouee prelevait 200 FR et 40 points.
  SELECT * INTO d FROM public.assemblee_disciplines WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'sanction', d.id, 'cible', d.cible, 'pop', d.pop_delta,
                              'amende', d.amende, 'caisse', d.caisse_creditee,
                              'rappel_consomme', d.rappel_id);
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;
  v_m := nullif(btrim(coalesce(p_motif, '')), '');
  IF v_m IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motif_obligatoire'); END IF;
  IF NOT public.assemblee_est_depute(v_pays, p_depute) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_pas_deputee'); END IF;

  -- LE RAPPEL PREALABLE, NON ENCORE CONSOMME, LE PLUS ANCIEN D'ABORD. Verrouille : deux sanctions
  -- simultanees ne peuvent pas elire le meme rappel.
  SELECT x.id INTO v_rappel FROM public.assemblee_disciplines x
   WHERE x.pays = v_pays AND x.genre = 'rappel' AND x.cible = p_depute
     AND x.president = v_moi
     AND NOT EXISTS (SELECT 1 FROM public.assemblee_disciplines s WHERE s.rappel_id = x.id)
   ORDER BY x.fait_le
   FOR UPDATE
   LIMIT 1;
  IF v_rappel IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_rappel_a_consommer'); END IF;

  -- L'ARGENT D'ABORD, SUR LA POCHE DU DEPUTE. Primitive generique du jeu : liquide puis Banque
  -- nationale, ecriture directe, et `false` sans rien toucher si les fonds manquent.
  v_paye := public.helvetia_debiter_fonds_ordinaires(p_depute, AMENDE);
  IF v_paye IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'montant_requis', AMENDE, 'cible', p_depute);
  END IF;
  v_caisse := v_pays || '_assemblee';
  PERFORM public.assemblee_crediter_caisse(v_caisse, AMENDE);

  -- PUIS LA POPULARITE, par le registre des causes. Un refus ici est une incoherence, pas une
  -- regle : on annule tout, donc l'amende repart dans la poche du depute et la caisse ne garde rien.
  v_pop := public.personnage_ajuster_pop_inf(v_moi, p_depute, POP_SANCTION, NULL, 'assemblee_sanction');
  IF coalesce((v_pop->>'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'assemblee_sanction_popularite_refusee: %', coalesce(v_pop->>'raison', 'inconnue');
  END IF;

  v_id    := 'sanction-' || left(md5(p_requete), 20);
  v_chron := 'chronique-assemblee_sanction-' || left(md5(p_requete), 20);

  INSERT INTO public.assemblee_disciplines
    (id, pays, genre, president, president_fonction, cible, cible_fonction, motif, pop_delta,
     amende, caisse_creditee, rappel_id, chronique_id, requete)
  VALUES (v_id, v_pays, 'sanction', v_moi, 'president_assemblee', p_depute, 'depute', v_m,
          POP_SANCTION, AMENDE, v_caisse, v_rappel, v_chron, p_requete);

  INSERT INTO public.chronique_nationale
    (id, country, type, city, personnages, libelle, data, source_ref)
  VALUES (v_chron, v_pays, 'assemblee_sanction', 'capitale',
          jsonb_build_array(v_moi, p_depute),
          'Le President de l''Assemblee a sanctionne ' || p_depute || '.',
          jsonb_build_object('president', v_moi, 'cible', p_depute, 'motif', v_m,
                             'pop', POP_SANCTION, 'amende', AMENDE, 'caisse', v_caisse,
                             'rappel', v_rappel, 'discipline', v_id),
          v_id);

  RETURN jsonb_build_object('ok', true, 'sanction', v_id, 'rappel_consomme', v_rappel,
                            'cible', p_depute, 'pop', POP_SANCTION, 'amende', AMENDE,
                            'caisse', v_caisse, 'pop_cible', v_pop -> 'pop');
END;
$function$;

REVOKE ALL ON FUNCTION public.assemblee_sanctionner(text,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assemblee_sanctionner(text,text,text) FROM anon;
GRANT EXECUTE ON FUNCTION public.assemblee_sanctionner(text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assemblee_sanctionner(text,text,text) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- PREUVES STRUCTURELLES
-- -------------------------------------------------------------------------------------------------
DO $$
DECLARE v_src text; v_n integer;
BEGIN
  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_sanctionner';

  -- P1 : ELLE NE PASSE PLUS PAR LA PORTE QUI ECRIT PAR LA VUE. C'etait le defaut : le trigger de
  -- `personnages` refuse la fiche d'autrui, et une amende vise par definition quelqu'un d'autre.
  IF v_src LIKE '%assemblee_debiter_joueur%' THEN
    RAISE EXCEPTION 'P1 : la sanction debite encore par la vue personnages';
  END IF;
  IF v_src NOT LIKE '%helvetia_debiter_fonds_ordinaires%' THEN
    RAISE EXCEPTION 'P1b : la sanction ne passe pas par la primitive de debit d un tiers';
  END IF;

  -- P2 : AUCUNE COPIE DE LA CASCADE. Si la sanction se mettait a lire les soldes et a les ecrire
  -- elle-meme, elle deviendrait la 43e copie executee de la meme regle -- le defaut exact que le
  -- chantier des fonctions recopiees cherche a reduire.
  IF v_src LIKE '%comptes_bancaires%' OR v_src LIKE '%SET liquide%' THEN
    RAISE EXCEPTION 'P2 : la sanction recopie la cascade liquide / Banque nationale';
  END IF;

  -- P3 : L'ARGENT AVANT LA POPULARITE, ET LES DEUX AVANT L'ECRITURE. Un manque de fonds est un
  -- refus legitime qui n'ecrit rien ; un refus de popularite est une incoherence qui annule tout.
  IF position('helvetia_debiter_fonds_ordinaires' in v_src)
     > position('personnage_ajuster_pop_inf' in v_src) THEN
    RAISE EXCEPTION 'P3a : la popularite est appliquee avant la verification des fonds';
  END IF;
  IF position('personnage_ajuster_pop_inf' in v_src)
     > position('INSERT INTO public.assemblee_disciplines' in v_src) THEN
    RAISE EXCEPTION 'P3b : la ligne de sanction est ecrite avant que la popularite ne soit appliquee';
  END IF;
  IF v_src NOT LIKE '%RAISE EXCEPTION%popularite_refusee%' THEN
    RAISE EXCEPTION 'P3c : un echec de popularite ne fait plus tout annuler';
  END IF;

  -- P4 : LE CREDIT DE LA CAISSE SUIT IMMEDIATEMENT LE DEBIT, dans la meme transaction. On ne
  -- retire jamais 100 FR sans crediter la caisse de l'Assemblee.
  IF position('helvetia_debiter_fonds_ordinaires' in v_src)
     > position('assemblee_crediter_caisse' in v_src) THEN
    RAISE EXCEPTION 'P4 : la caisse est creditee avant que le depute ne soit debite';
  END IF;

  -- P5 : LE MONTANT ET LE COUT RESTENT CEUX DE L'ARBITRAGE, en dur et nommes.
  IF v_src NOT LIKE '%AMENDE       constant integer := 100%'
     OR v_src NOT LIKE '%POP_SANCTION constant integer := -20%' THEN
    RAISE EXCEPTION 'P5 : le prix de la sanction a change';
  END IF;

  -- P6 : `assemblee_debiter_joueur` EST INTACTE. Cette migration ne la modifie pas : ses appelants
  -- historiques paient leur PROPRE action, et c'est precisement ce qu'elle garantit.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_debiter_joueur'
     AND p.prosrc LIKE '%UPDATE public.personnages%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P6 : assemblee_debiter_joueur a ete alteree'; END IF;

  RAISE NOTICE 'Amende prelevee sur un tiers : les 6 preuves structurelles passent.';
END $$;
