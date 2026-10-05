-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260928085753
-- Nom original      : c1_fonds_local_existant_et_types_l2
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-28 08:57:53 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 34d04f19cc0c6bf204d9f05f55f846cb
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =====================================================================
-- C1 — LOCAL EXISTANT <-> FONDS PJ <-> TYPES L2
-- =====================================================================
-- Le referentiel L2 devient l'autorite taxonomique des commerces PJ. Le modele
-- dormant « UN FONDS = UNE FAMILLE_COMMERCE » n'est ni branche ni supprime : il
-- reste en place, inerte pour les fonds neufs, et son sort est documente plus bas.
--
-- AUCUNE DEPENDANCE AU FUTUR MOTEUR IMMOBILIER : ce lot s'appuie exclusivement sur
-- les locaux LOCATIFS DEJA EXISTANTS des trois centres, dont les baux vivent deja
-- dans locations_actives. Aucun lot dynamique, aucune subdivision, aucun terrain.
--
-- CE LOT N'EXPOSE RIEN AUX JOUEURS : aucun ordre de data.js n'est ajoute ni
-- deplace, aucun ecran n'est cree. L'ordre gerer_fonds_commerce reste pose sur la
-- piece `terrain`, ou aucun bail ne peut exister -- sa relocalisation sur les
-- locaux des centres releve de l'interface proprietaire (C5).
--
-- AUCUNE TABLE N'EST CREEE. Les types autorises d'un fonds vivent dans
-- entreprises.data, comme tout le reste de ce blob ; la cascade type -> famille ->
-- generique est DERIVEE du referentiel et n'a besoin d'aucune table de jointure.

-- ---------------------------------------------------------------------------
-- 1. VOCATION D'UN LOCAL — DERIVEE, JAMAIS STOCKEE
-- ---------------------------------------------------------------------------
-- Les locaux locatifs sont definis dans data.js (BUILDINGS[batiment].rooms[piece],
-- marqueur isLocationRoom + locationData). Les recopier en base creerait une
-- seconde source de verite susceptible de deriver -- defaut que ce projet combat
-- systematiquement. On DERIVE donc la vocation du batiment porteur, exactement
-- comme bail_destination_attestee derive la destination du loyer.
--
-- RELEVE DU 28 SEPTEMBRE 2026 — 18 pieces isLocationRoom dans data.js, dont
-- 10 dans les trois centres et 8 qui ne sont pas des locaux d'activite :
--   centre-commercial : vitrine_principale (800), boutique_milieu (400),
--                       arriere_boutique (150), cave_reserve (80)
--   centre-artisanal  : echoppe_facade (600), atelier_milieu (300),
--                       reserve_arriere (100)
--   centre-affaires   : bureau_prestige (1000), bureau_standard (500),
--                       open_space (200)
--   HORS PERIMETRE    : 2 suites d'hotel, 1 coffre de banque, 1 salle de reunion,
--                       4 appartements de Montrouge (logement, pas activite).
--
-- CE QUE CETTE FONCTION FAIT, ET CE QU'ELLE NE FAIT PAS.
-- Elle dit si un local peut heberger un fonds de commerce, et de quelle vocation
-- releve le centre qui l'accueille. Elle NE decide PAS quels types L2 sont permis
-- dans quel centre : aucune matrice type x centre n'est posee ici. Cette
-- compatibilite fine est un arbitrage de game design qui n'est pas rendu, et la
-- vocation n'est donc pour l'instant qu'une information portee, jamais opposee.
create or replace function public.local_vocation_commerciale(p_building_id text)
returns text
language sql
immutable
as $$
  select case p_building_id
    when 'centre-commercial' then 'commerce'
    when 'centre-artisanal'  then 'artisanat'
    when 'centre-affaires'   then 'services'
    else null
  end;
$$;

comment on function public.local_vocation_commerciale(text) is
  'Vocation commerciale d''un local locatif, derivee de son batiment. NULL = le local ne peut pas heberger un fonds de commerce (logement, suite d''hotel, coffre, salle de reunion). N''exprime AUCUNE contrainte de type L2 : la compatibilite fine type x centre n''est pas arbitree.';

revoke all on function public.local_vocation_commerciale(text) from public, anon, authenticated;
grant execute on function public.local_vocation_commerciale(text) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. PLAFOND DE TYPES — CONFIGURABLE, JAMAIS CODE EN DUR
-- ---------------------------------------------------------------------------
-- VALEUR PROVISOIRE, PAS UNE REGLE DE JEU ARRETEE. Le nombre d'offre de base a
-- ete evoque a 2, avec un premium eventuel a 3, mais rien n'est chiffre
-- definitivement. La valeur ne figure qu'ICI : la changer ne demande aucune
-- migration et ne touche aucune recette.
--
-- LE PREMIUM N'EST PAS ENCORE MODELISE. fonds_types_max() est le point unique ou
-- une differenciation par offre viendra se brancher : elle recevra le proprietaire
-- et pourra consulter son statut. Aujourd'hui elle rend la valeur de base pour
-- tout le monde -- aucun statut d'abonnement n'existe en base, et en inventer un
-- serait anticiper.
insert into public.entreprises_constantes (cle, valeur) values
  ('types_commerce_max_base', 2)
on conflict (cle) do nothing;

create or replace function public.fonds_types_max(p_proprietaire text)
returns integer
language sql
stable
as $$
  select greatest(1, coalesce(
    (select valeur::integer from public.entreprises_constantes
      where cle = 'types_commerce_max_base'), 2));
$$;

comment on function public.fonds_types_max(text) is
  'Nombre maximal de types de commerce L2 qu''un fonds peut declarer. Lu dans entreprises_constantes, jamais code en dur. Point d''extension unique pour une future differenciation par offre : le proprietaire est deja recu en parametre, mais aucun statut d''abonnement n''existe encore en base.';

revoke all on function public.fonds_types_max(text) from public, anon, authenticated;
grant execute on function public.fonds_types_max(text) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. CREATION D'UN FONDS SUR UN LOCAL EXISTANT
-- ---------------------------------------------------------------------------
-- TROIS AJOUTS, tous additifs, signature inchangee :
--
--   a) CONTRAINTE MINIMALE DE COHERENCE. Le serveur ne verifiait AUCUNE vocation :
--      un fonds de commerce pouvait naitre dans une suite d'hotel, un coffre de
--      banque ou un appartement. C'est la seule incoherence manifeste que ce lot
--      ferme, et elle ne repose sur aucune decision nouvelle -- seulement sur le
--      fait, deja etabli, que les trois centres sont les lieux d'activite.
--
--   b) references INITIALISEE A VIDE. acheter_produit_commerce lit
--      data->'references' ; sans cette cle, tout achat echouait pour une raison
--      structurelle (reference_absente) et non metier. La cle existe desormais des
--      la creation. Elle reste VIDE : l'ecriture des references est C2.
--
--   c) typesAutorises INITIALISE A VIDE, et la vocation du local recopiee dans
--      l'implantation. Un fonds neuf ne declare donc aucun type tant que son
--      proprietaire n'en a pas choisi (fonds_definir_types).
--
-- CE QUI N'EST PAS AJOUTE : aucun champ `famille`. Les fonds neufs ne relevent
-- plus de FAMILLES_COMMERCE, et familleDe(fonds) rendra null pour eux -- c'est
-- voulu, l'autorite taxonomique est L2. Consequence a connaitre pour C3 :
-- verdictProduction (plateau-commerce.js) refuserait 'famille_inconnue' sur un
-- fonds neuf. Il faudra l'adapter aux types L2, pas lui redonner une famille.
create or replace function public.creer_fonds_commerce(
  p_proprietaire text, p_bail_id text, p_fonds_id text, p_apport integer, p_enseigne text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
DECLARE
  v_bail jsonb;
  v_apport integer := GREATEST(0, COALESCE(p_apport, 0));
  v_lot text;
  v_deja integer;
  v_vocation text;
BEGIN
  PERFORM public.exiger_acteur(p_proprietaire);
  IF COALESCE(p_proprietaire, '') = '' OR COALESCE(p_bail_id, '') = '' OR COALESCE(p_fonds_id, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF v_apport > 0 THEN
    IF NOT mouvement_titulaire(p_proprietaire, -v_apport) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
    END IF;
  ELSE
    IF NOT mouvement_titulaire(p_proprietaire, 0) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'proprietaire_absent');
    END IF;
  END IF;
  SELECT count(*) INTO v_deja FROM entreprises WHERE id = p_fonds_id;
  IF v_deja > 0 THEN RAISE EXCEPTION 'fonds_id_deja_pris'; END IF;
  SELECT data INTO v_bail FROM locations_actives WHERE id = p_bail_id FOR UPDATE;
  IF v_bail IS NULL THEN RAISE EXCEPTION 'bail_absent'; END IF;
  IF (v_bail ->> 'locataire') IS DISTINCT FROM p_proprietaire
     AND ('pj:' || COALESCE(v_bail ->> 'locataire', '')) IS DISTINCT FROM p_proprietaire THEN
    RAISE EXCEPTION 'pas_titulaire';
  END IF;

  -- (a) le local doit pouvoir heberger une activite
  v_vocation := public.local_vocation_commerciale(v_bail ->> 'buildingId');
  IF v_vocation IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'local_non_commercial',
                              'batiment', v_bail ->> 'buildingId');
  END IF;

  SELECT count(*) INTO v_deja FROM entreprises
   WHERE data -> 'implantation' ->> 'bailId' = p_bail_id
     AND COALESCE(data ->> 'statut', 'actif') = 'actif';
  IF v_deja > 0 THEN RAISE EXCEPTION 'fonds_deja_present'; END IF;
  v_lot := v_bail ->> 'lotId';
  INSERT INTO entreprises (id, data, updated_at)
  VALUES (p_fonds_id, jsonb_build_object(
    'id', p_fonds_id,
    'version', 2,
    'type', 'fonds_commerce',
    'enseigne', COALESCE(NULLIF(btrim(COALESCE(p_enseigne, '')), ''), 'Fonds de commerce'),
    'proprietaire', p_proprietaire,
    'statut', 'actif',
    'caisse', v_apport,
    'implantation', jsonb_build_object(
      'country', v_bail ->> 'country', 'city', v_bail ->> 'city',
      'buildingId', v_bail ->> 'buildingId', 'roomId', v_bail ->> 'roomId',
      'lotId', v_lot, 'localKey', v_bail ->> 'localKey', 'bailId', p_bail_id,
      'vocation', v_vocation),
    'typesAutorises', '[]'::jsonb,
    'references',     '{}'::jsonb,
    'stockMatieres',  '{}'::jsonb,
    'stockProduits',  '{}'::jsonb,
    'historique', jsonb_build_array(jsonb_build_object(
      'evenement', 'creation', 'proprietaire', p_proprietaire, 'apport', v_apport,
      'horodatage', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS')))
  ), now());
  UPDATE locations_actives SET data = v_bail || jsonb_build_object('fondsId', p_fonds_id) WHERE id = p_bail_id;
  RETURN jsonb_build_object('ok', true, 'fondsId', p_fonds_id, 'caisse', v_apport,
                            'apport', v_apport, 'proprietaire', p_proprietaire,
                            'vocation', v_vocation, 'typesMax', public.fonds_types_max(p_proprietaire));
END;
$function$;

revoke all on function public.creer_fonds_commerce(text,text,text,integer,text) from public, anon, authenticated;
grant execute on function public.creer_fonds_commerce(text,text,text,integer,text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. TYPES L2 D'UN FONDS — PLUSIEURS, ET SEULEMENT DU REFERENTIEL
-- ---------------------------------------------------------------------------
-- Un fonds declare un ou PLUSIEURS types de commerce, tous pris dans
-- catalogue_types. Le referentiel est la seule autorite : un type inconnu est
-- refuse, jamais cree a la volee.
--
-- ORDRE ET DOUBLONS : la liste est normalisee (doublons retires, ordre du
-- referentiel) pour qu'une meme selection produise toujours la meme donnee.
--
-- REMPLACEMENT, PAS AJOUT : l'appel pose la liste complete. C'est ce qui permet
-- a un futur ecran de presenter des cases a cocher sans avoir a diffier.
create or replace function public.fonds_definir_types(
  p_acteur text, p_fonds_id text, p_types text[])
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE
  v_data      jsonb;
  v_demandes  text[];
  v_connus    text[];
  v_inconnus  text[];
  v_max       integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF COALESCE(p_fonds_id, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent');
  END IF;
  IF COALESCE((v_data ->> 'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj');
  END IF;
  IF COALESCE(v_data ->> 'statut', 'actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif');
  END IF;
  IF (v_data ->> 'proprietaire') IS DISTINCT FROM p_acteur
     AND (v_data ->> 'proprietaire') IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire');
  END IF;

  -- normalisation : doublons retires, ordre du referentiel
  SELECT array_agg(t.id ORDER BY t.ordre) INTO v_connus
    FROM public.catalogue_types t
   WHERE t.id = ANY (COALESCE(p_types, '{}'));
  v_connus := COALESCE(v_connus, '{}');

  SELECT array_agg(DISTINCT x) INTO v_inconnus
    FROM unnest(COALESCE(p_types, '{}')) AS x
   WHERE NOT EXISTS (SELECT 1 FROM public.catalogue_types t WHERE t.id = x);
  IF v_inconnus IS NOT NULL AND array_length(v_inconnus, 1) > 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'type_inconnu', 'types', to_jsonb(v_inconnus));
  END IF;

  v_max := public.fonds_types_max(v_data ->> 'proprietaire');
  IF array_length(v_connus, 1) IS NOT NULL AND array_length(v_connus, 1) > v_max THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'trop_de_types',
                              'maximum', v_max, 'demandes', array_length(v_connus, 1));
  END IF;

  v_data := jsonb_set(v_data, '{typesAutorises}', to_jsonb(v_connus));
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'fondsId', p_fonds_id,
                            'typesAutorises', to_jsonb(v_connus), 'maximum', v_max);
END;
$$;

comment on function public.fonds_definir_types(text,text,text[]) is
  'Declare les types de commerce L2 d''un fonds PJ. Plusieurs types possibles, tous valides contre catalogue_types, plafond lu dans entreprises_constantes. Remplace la liste complete. Reserve au proprietaire du fonds.';

revoke all on function public.fonds_definir_types(text,text,text[]) from public, anon, authenticated;
grant execute on function public.fonds_definir_types(text,text,text[]) to authenticated, service_role;