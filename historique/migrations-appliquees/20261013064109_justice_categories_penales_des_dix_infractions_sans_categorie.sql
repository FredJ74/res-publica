-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 13 OCTOBRE 2026
--
-- Registre Supabase : version 20261013064109 (UTC), nom
-- `justice_categories_penales_des_dix_infractions_sans_categorie`.
-- Le registre passe de 701 a 702 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 1ece6fa93b13a4dc849f4067807f47f7, 9944 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- DIX INFRACTIONS SONT CLASSEES, ET AUCUNE PEINE NE BOUGE
--
-- L'ARBITRAGE DES CATEGORIES PENALES. CRIME : assassinat, tentative d'assassinat, tentative
-- d'empoisonnement. DELIT : diffamation, violation du couvre-feu, corruption de fonctionnaire,
-- hooliganisme, achat d'arme non enregistree, possession d'objets prohibes au controle douanier,
-- non-presentation a convocation. Elles avaient toutes une peine de reference et AUCUNE categorie.
--
-- LES PEINES SONT RELEVEES AVANT ET RECOMPAREES APRES (preuve P4). Les dix portent un bareme PROPRE,
-- donc leur duree et leur amende vivent sur leur propre ligne, pas sur celle de leur categorie :
-- les classer ne change rien a ce qu'elles coutent. L'arbitrage interdisait de rebalancer les peines
-- au passage ; la migration le verifie au lieu de le promettre.
--
-- LA CINQUIEME CATEGORIE S'APPELLE `delit`, PARCE QUE C'EST LE MOT DE L'ARBITRAGE. Les deux
-- categories existantes -- delit mineur, delit grave -- portent chacune une GRAVITE deja arbitree :
-- en choisir une aurait prononce une gravite que l'arbitrage n'a pas prononcee. Ses deux nombres
-- sont ceux du delit mineur, donc aucune valeur neuve n'entre dans l'echelle des peines, et une
-- CONTRAINTE garantit que ces deux nombres ne serviront jamais -- aucune infraction sans bareme
-- propre ne peut porter `delit`. Le generateur du code penal refuse la meme chose, cote canon.
--
-- `justification_rejetee` RESTE SANS CATEGORIE, DELIBEREMENT. C'est la onzieme sans categorie, et
-- elle n'est pas dans l'arbitrage : son audit est en cours. Sans categorie, elle reste HORS de la
-- procedure simplifiee, du cote ferme.
--
-- CE QUE LA CATEGORIE CHANGE VRAIMENT : le registre public du greffe nomme desormais une categorie
-- au lieu de rien, et la procedure simplifiee s'OUVRE aux sept delits tout en restant FERMEE aux
-- trois crimes -- qui portent pourtant deux jours de reference, sous le seuil. C'est leur NATURE qui
-- les arrete depuis cette migration, et non plus l'absence de categorie.
--
-- PREUVES STRUCTURELLES -- 14.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- DIX INFRACTIONS AVAIENT UNE PEINE MAIS AUCUNE CATEGORIE PENALE. L'ARBITRAGE LES CLASSE.
--
-- CRIME : assassinat, tentative_assassinat, tentative_empoisonnement.
-- DELIT : diffamation, violation_couvre_feu, corruption_fonctionnaire, hooliganisme,
--         achat_arme_illegal, possession_illegale_douane, non_presentation_convocation.
--
-- AUCUNE PEINE NE BOUGE, ET LA MIGRATION LE PROUVE. Les dix portent un bareme PROPRE
-- (`bareme_propre = true`) : leur duree et leur amende de reference vivent sur leur propre ligne,
-- pas sur celle de leur categorie. Classer une infraction a bareme propre ne change donc
-- strictement rien a ce qu'elle coute. Les onze valeurs sont relevees AVANT et comparees APRES.
--
-- LA CINQUIEME CATEGORIE S'APPELLE `delit`, ET PAS AUTREMENT. L'arbitrage dit « DELIT ». Les deux
-- categories existantes -- `delit_mineur` (2 j / 500 FR) et `delit_grave` (4 j / 1500 FR) --
-- portent chacune une GRAVITE deja arbitree, et en choisir une aurait prononce une gravite que
-- l'arbitrage n'a pas prononcee. Ses deux nombres ne sont PAS un bareme neuf : ce sont ceux de
-- `delit_mineur`, le socle du delit deja arbitre, donc aucune valeur nouvelle n'entre dans
-- l'echelle des peines -- ce que l'arbitrage interdit explicitement. Et une CONTRAINTE garantit
-- que ces deux nombres ne serviront jamais : aucune infraction sans bareme propre ne peut porter
-- `delit`, donc personne n'en herite. Donner a `delit` un bareme generique distinct de celui du
-- delit mineur demanderait un arbitrage ; cette migration ne le prend pas.
--
-- `justification_rejetee` RESTE SANS CATEGORIE, DELIBEREMENT. C'est la onzieme, et elle n'est pas
-- dans l'arbitrage. Son audit est en cours ; lui attribuer une categorie au passage serait
-- decider a sa place. Sans categorie, elle reste HORS de la procedure simplifiee -- le cote
-- ferme.
--
-- CE QUE LA CATEGORIE CHANGE VRAIMENT, pour ces dix : (1) le registre public du greffe nomme
-- desormais une categorie au lieu de rien ; (2) la procedure simplifiee s'OUVRE aux sept delits
-- (elle refusait `categorie IS NULL OR categorie = 'crime'`) et reste FERMEE aux trois crimes.

DO $$
DECLARE v_avant jsonb; v_apres jsonb; v_n integer; v_cat text; v_emp text;
BEGIN
  -- RELEVE AVANT : les onze lignes concernees, peines comprises.
  SELECT jsonb_object_agg(i.id, jsonb_build_array(i.jours_reference, i.amende_reference,
                                                  i.bareme_propre, i.detectable, i.libelle))
    INTO v_avant FROM public.infractions i
   WHERE i.id IN ('assassinat','tentative_assassinat','tentative_empoisonnement',
                  'diffamation','violation_couvre_feu','corruption_fonctionnaire','hooliganisme',
                  'achat_arme_illegal','possession_illegale_douane','non_presentation_convocation',
                  'justification_rejetee');
  IF (SELECT count(*) FROM jsonb_object_keys(v_avant)) <> 11 THEN
    RAISE EXCEPTION 'DECOR ECHOUE -- les onze infractions attendues ne sont pas toutes la';
  END IF;

  INSERT INTO public.infractions_categories (id, libelle, jours_reference, amende_reference)
  VALUES ('delit', 'Delit', 2, 500)
  ON CONFLICT (id) DO UPDATE SET libelle = excluded.libelle,
                                 jours_reference = excluded.jours_reference,
                                 amende_reference = excluded.amende_reference;

  UPDATE public.infractions SET categorie = 'crime'
   WHERE id IN ('assassinat','tentative_assassinat','tentative_empoisonnement');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 3 THEN RAISE EXCEPTION 'DECOR ECHOUE -- % crimes classes au lieu de 3', v_n; END IF;

  UPDATE public.infractions SET categorie = 'delit'
   WHERE id IN ('diffamation','violation_couvre_feu','corruption_fonctionnaire','hooliganisme',
                'achat_arme_illegal','possession_illegale_douane','non_presentation_convocation');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 7 THEN RAISE EXCEPTION 'DECOR ECHOUE -- % delits classes au lieu de 7', v_n; END IF;

  -- P1 -- LES DIX SONT CLASSEES, ET EXACTEMENT COMME L'ARBITRAGE LE DIT.
  SELECT count(*) INTO v_n FROM public.infractions
   WHERE id IN ('assassinat','tentative_assassinat','tentative_empoisonnement')
     AND categorie = 'crime';
  IF v_n <> 3 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % des 3 crimes portent crime', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.infractions
   WHERE id IN ('diffamation','violation_couvre_feu','corruption_fonctionnaire','hooliganisme',
                'achat_arme_illegal','possession_illegale_douane','non_presentation_convocation')
     AND categorie = 'delit';
  IF v_n <> 7 THEN RAISE EXCEPTION 'P2 ECHOUEE -- % des 7 delits portent delit', v_n; END IF;

  -- P3 -- `justification_rejetee` RESTE SANS CATEGORIE.
  SELECT categorie INTO v_cat FROM public.infractions WHERE id = 'justification_rejetee';
  IF v_cat IS NOT NULL THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- justification_rejetee a recu la categorie %', v_cat; END IF;

  -- P4 -- AUCUNE PEINE N'A BOUGE. Comparaison du releve avant et apres, sur les onze lignes.
  SELECT jsonb_object_agg(i.id, jsonb_build_array(i.jours_reference, i.amende_reference,
                                                  i.bareme_propre, i.detectable, i.libelle))
    INTO v_apres FROM public.infractions i
   WHERE i.id IN ('assassinat','tentative_assassinat','tentative_empoisonnement',
                  'diffamation','violation_couvre_feu','corruption_fonctionnaire','hooliganisme',
                  'achat_arme_illegal','possession_illegale_douane','non_presentation_convocation',
                  'justification_rejetee');
  IF v_apres <> v_avant THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- une peine a bouge : % -> %', v_avant, v_apres; END IF;

  -- P5 -- AUCUNE AUTRE INFRACTION N'A CHANGE DE CATEGORIE. Les vingt-huit autres gardent la
  -- leur, et le compte par categorie le dit.
  SELECT count(*) INTO v_n FROM public.infractions WHERE categorie = 'crime';
  IF v_n <> 12 THEN RAISE EXCEPTION 'P5 ECHOUEE -- % crimes au total (9 + 3 attendus)', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.infractions WHERE categorie = 'delit_mineur';
  IF v_n <> 13 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % delits mineurs (13 attendus)', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.infractions WHERE categorie = 'delit_grave';
  IF v_n <> 6 THEN RAISE EXCEPTION 'P7 ECHOUEE -- % delits graves (6 attendus)', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.infractions WHERE categorie IS NULL;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P8 ECHOUEE -- % infractions sans categorie (1 attendue)', v_n; END IF;
END $$;

-- LA CONTRAINTE QUI REND LES DEUX NOMBRES DE `delit` INATTEIGNABLES. Une infraction sans bareme
-- propre tire sa peine de sa categorie ; `delit` n'a pas de bareme arbitre a lui, donc personne
-- ne doit en heriter. Le generateur refuse la meme chose, cote canon.
ALTER TABLE public.infractions
  ADD CONSTRAINT infractions_delit_exige_bareme_propre
  CHECK (categorie <> 'delit' OR bareme_propre);

-- L'EMPREINTE DU MIROIR SUIT LE CANON. Relevee par
-- `python3 outils/generateurs/generer_infractions.py --empreinte` sur plateau-core.js modifie.
UPDATE public.infractions_empreinte SET empreinte = 'a7463ab07be5b9ab', pose_le = now();

DO $$
DECLARE v_n integer; v_p text; v_r text;
BEGIN
  -- P9 -- la contrainte existe et elle MORD.
  SELECT count(*) INTO v_n FROM pg_constraint
   WHERE conrelid = 'public.infractions'::regclass
     AND conname = 'infractions_delit_exige_bareme_propre';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P9 ECHOUEE -- la contrainte est absente'; END IF;
  BEGIN
    INSERT INTO public.infractions (id, libelle, categorie, jours_reference, amende_reference,
                                    bareme_propre, detectable)
    VALUES ('banc_delit_sans_bareme', 'Banc', 'delit', 2, 500, false, false);
    RAISE EXCEPTION 'P10 ECHOUEE -- un delit SANS bareme propre a ete accepte';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- P11 -- le miroir concorde : empreinte posee = empreinte reelle = canon.
  SELECT empreinte INTO v_p FROM public.infractions_empreinte;
  v_r := public.infractions_empreinte_reelle();
  IF v_p <> 'a7463ab07be5b9ab' OR v_r <> v_p THEN
    RAISE EXCEPTION 'P11 ECHOUEE -- posee=% reelle=% canon=a7463ab07be5b9ab', v_p, v_r; END IF;

  -- P12 -- LES TROIS CRIMES NE PASSENT PAS PAR LA PROCEDURE SIMPLIFIEE, et c'est la categorie
  -- qui les arrete, pas la duree : les trois portent 2 jours de reference, sous le seuil.
  SELECT count(*) INTO v_n FROM public.infractions i
   WHERE i.id IN ('assassinat','tentative_assassinat','tentative_empoisonnement')
     AND i.jours_reference <= public.justice_seuil_procedure_simplifiee_jours()
     AND i.categorie = 'crime';
  IF v_n <> 3 THEN
    RAISE EXCEPTION 'P12 ECHOUEE -- % des 3 crimes sont sous le seuil ET classes crime', v_n; END IF;

  -- P13 -- LES SEPT DELITS SONT DESORMAIS ELIGIBLES : categorie presente, non-crime, et duree
  -- sous le seuil. C'est l'effet voulu de l'arbitrage, et il est mesure, pas suppose.
  SELECT count(*) INTO v_n FROM public.infractions i
   WHERE i.id IN ('diffamation','violation_couvre_feu','corruption_fonctionnaire','hooliganisme',
                  'achat_arme_illegal','possession_illegale_douane','non_presentation_convocation')
     AND i.categorie IS NOT NULL AND i.categorie <> 'crime'
     AND i.jours_reference <= public.justice_seuil_procedure_simplifiee_jours();
  IF v_n <> 7 THEN RAISE EXCEPTION 'P13 ECHOUEE -- % des 7 delits sont eligibles', v_n; END IF;

  -- P14 -- la categorie `delit` existe, avec le bareme du delit mineur et rien d'autre.
  SELECT count(*) INTO v_n FROM public.infractions_categories
   WHERE id = 'delit' AND libelle = 'Delit' AND jours_reference = 2 AND amende_reference = 500;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P14 ECHOUEE -- la categorie delit est absente ou differente'; END IF;

  RAISE NOTICE 'LES 14 PREUVES SONT VERTES.';
END $$;
