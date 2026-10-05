-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260928094258
-- Nom original      : c2_references_commerciales
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-28 09:42:58 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : dbe5c4d4740a2c0f97d29ed20c1fab63
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
-- C2 — REFERENCES COMMERCIALES
-- =====================================================================
-- Une reference commerciale est l'HABILLAGE d'un generique L2 par un commercant.
-- Elle ne cree aucune mecanique : elle nomme, decrit et tarife ce que le
-- referentiel a deja defini.
--
-- TROIS COUCHES, TROIS AUTORITES, AUCUNE DUPLICATION :
--   L2                 dit ce qu'est reellement l'objet
--   RECETTE SYSTEME    dit comment ce generique est fabrique, quand il l'est
--   REFERENCE          dit comment CE commercant le presente et le vend
--   STOCK              dira combien il peut effectivement en vendre
--
-- LE PJ NE CREE NI NE MODIFIE AUCUNE RECETTE. Les recettes sont des donnees
-- systeme. La reference ne porte donc AUCUN recetteId : la recette est DERIVEE du
-- generique. C'est la correction de la relation conceptuelle du moteur dormant,
-- qui indexait historiquement les references par recette.
--
-- LE STOCK SORT DE LA REFERENCE. Le modele dormant logeait stock et stockMax dans
-- la reference elle-meme. Une reference est un modele commercial, pas un compteur :
-- les melanger obligerait chaque futur instantane de transaction a se souvenir
-- d'exclure un compteur vivant. Le stock vit desormais dans data.stockReferences,
-- a cote de stockProduits (legacy), et acheter_produit_commerce y est raccorde.
-- C'est la seule adaptation de C0 faite ici, et elle est strictement necessaire au
-- modele.
--
-- AUCUNE TABLE N'EST CREEE. Les references vivent dans entreprises.data.references,
-- structure que le moteur dormant avait deja prevue et que acheter_produit_commerce
-- LIT DEJA depuis C0 : ce lot en fournit l'ECRIVAIN reel qui manquait.

-- ---------------------------------------------------------------------------
-- 1. COEFFICIENT DE PRIX MAXIMAL — UNE POLITIQUE PAR PAYS, PAS UN FORK DE MOTEUR
-- ---------------------------------------------------------------------------
-- Le plafond du prix libre d'un PJ est un coefficient applique au cout de revient
-- unitaire. Ce coefficient est une POLITIQUE ECONOMIQUE DE PAYS, pas une constante
-- du moteur : deux empires peuvent legitimement encadrer differemment la marge
-- commerciale, sans qu'aucune ligne de moteur soit dupliquee.
--
-- REPUBLIA : x4, valeur arbitree.
-- LES AUTRES EMPIRES : AUCUNE VALEUR. Rien n'est arbitre pour Sovarka, Al Khalija
-- ni Narcossia, et on n'en invente pas. La fonction rend NULL, et toute fixation
-- de prix dans ces pays est refusee explicitement -- meme doctrine que
-- prix_ressource_selon_stock, dont le corps porte « jamais de tarif invente ».
--
-- Ajouter un pays demain = UNE LIGNE DE DONNEES, aucun code.
insert into public.entreprises_constantes (cle, valeur) values
  ('coef_prix_max_pj_republic', 4)
on conflict (cle) do nothing;

create or replace function public.coef_prix_max_pj(p_pays text)
returns numeric
language sql
stable
as $$
  select valeur::numeric
    from public.entreprises_constantes
   where cle = 'coef_prix_max_pj_' || coalesce(nullif(btrim(p_pays), ''), '__aucun__');
$$;

comment on function public.coef_prix_max_pj(text) is
  'Coefficient de plafond du prix libre d''un commercant PJ, applique au cout de revient unitaire. Politique economique PAR PAYS, lue dans entreprises_constantes. Rend NULL pour un pays dont le coefficient n''a pas ete arbitre : aucune valeur n''est jamais inventee, et la fixation de prix y est alors refusee.';

revoke all on function public.coef_prix_max_pj(text) from public, anon, authenticated;
grant execute on function public.coef_prix_max_pj(text) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. PLAFOND DE REFERENCES ACTIVES — CONFIGURABLE
-- ---------------------------------------------------------------------------
-- VALEUR PROVISOIRE, reprise de PLAFOND_REFERENCES_ACTIVES_BASE = 6
-- (plateau-commerce.js:314, dormant). Rien n'est arrete. Le plafond porte sur les
-- references ACTIVES : desactiver une reference libere une place sans rien perdre.
insert into public.entreprises_constantes (cle, valeur) values
  ('references_actives_max_base', 6)
on conflict (cle) do nothing;

create or replace function public.fonds_references_max(p_proprietaire text)
returns integer
language sql
stable
as $$
  select greatest(1, coalesce(
    (select valeur::integer from public.entreprises_constantes
      where cle = 'references_actives_max_base'), 6));
$$;

revoke all on function public.fonds_references_max(text) from public, anon, authenticated;
grant execute on function public.fonds_references_max(text) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. GENERIQUES ACCESSIBLES A UN FONDS — DERIVES, JAMAIS ENVOYES PAR LE CLIENT
-- ---------------------------------------------------------------------------
-- FONDS -> typesAutorises -> generiques. La cascade est une jointure sur le
-- referentiel : aucune table type <-> famille, aucune liste stockee.
--
-- DISTINCT EST LA REGLE, PAS UN DETAIL. Un generique atteignable par plusieurs
-- types du meme fonds (article-de-supporter l'est par « Commerce non alimentaire »
-- et par « Sport & loisirs ») doit apparaitre UNE SEULE FOIS, et il n'existe
-- qu'une seule identite mecanique pour lui quel que soit le chemin emprunte.
create or replace function public.fonds_generiques_accessibles(p_fonds_id text)
returns table (generique_id text, libelle text, famille_id text, famille text, types text[])
language sql
stable
as $$
  with f as (select data as d from public.entreprises where id = p_fonds_id),
  t as (select jsonb_array_elements_text(coalesce((select d->'typesAutorises' from f), '[]'::jsonb)) as type_id)
  select g.id, g.libelle, g.famille_id, fam.libelle,
         array_agg(distinct ty.id order by ty.id)
    from t
    join public.catalogue_generique_type gt on gt.type_id = t.type_id
    join public.catalogue_generiques g      on g.id = gt.generique_id
    join public.catalogue_familles fam      on fam.id = g.famille_id
    join public.catalogue_types ty          on ty.id = gt.type_id
   group by g.id, g.libelle, g.famille_id, fam.libelle
   order by fam.libelle, g.libelle;
$$;

comment on function public.fonds_generiques_accessibles(text) is
  'Generiques qu''un fonds peut exploiter, derives de ses types L2 par jointure sur le referentiel. Un generique atteignable par plusieurs types n''apparait qu''une fois. Source unique de la regle d''autorisation : fonds_reference_creer l''appelle.';

revoke all on function public.fonds_generiques_accessibles(text) from public, anon, authenticated;
grant execute on function public.fonds_generiques_accessibles(text) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. COUT DE REVIENT D'UNE REFERENCE — OU RIEN
-- ---------------------------------------------------------------------------
-- FORMULE CANONIQUE, celle deja en vigueur dans le moteur historique :
--   cout du lot      = somme(quantite_matiere x cout moyen REELLEMENT paye)
--                      + (PA de la recette x valeur du PA)
--   cout unitaire    = cout du lot / quantite produite
-- Aucun arrondi intermediaire : tout est numeric jusqu'au bout. La QUANTITE
-- PRODUITE est au denominateur, c'est le levier d'equilibrage et il n'est jamais
-- omis.
--
-- POURQUOI NE PAS APPELER commerce_cout_revient_portion : cette fonction historique
-- fait COALESCE(cout_matiere, 0) sur une matiere dont le cout moyen est inconnu.
-- C'est acceptable pour un commerce PNJ, qui a necessairement achete ses matieres
-- avant de produire. Ce ne l'est pas pour VALIDER UN PRIX : une matiere inconnue
-- ferait silencieusement tomber le cout, donc le plafond, donc ouvrirait la porte
-- exacte que le plafond doit fermer. On reprend la formule, on ajoute la garde de
-- completude, on n'invente aucune valeur.
--
-- VALEUR DU PA : lue dans entreprises_constantes, meme cle que le moteur historique
-- pour qu'il n'existe qu'une source. Le nom de cette cle est trompeur
-- (cout_main_oeuvre_pa_alimentaire alors qu'elle sert toutes les recettes de
-- recettes_commerce) ; la renommer touche le calcul du prix PNJ en production et
-- releve d'un lot dedie.
--
-- RACCORDEMENT GENERIQUE -> RECETTE : la colonne recettes_commerce.generique_id,
-- posee en L2 a cet effet, est la SEULE source acceptee. Elle est aujourd'hui
-- entierement NULL : aucun generique n'a donc de recette systeme, et cette fonction
-- rend « indisponible » pour tous. C'est le prerequis de C3, et non un cout a
-- inventer. catalogue_correspondance_legacy n'est PAS une source valable ici : elle
-- sert a RESOUDRE un objet vers son generique, pas a declarer quelle recette le
-- fabrique.
create or replace function public.fonds_cout_revient_reference(
  p_fonds_id text, p_generique_id text)
returns jsonb
language plpgsql
stable
set search_path to 'public'
as $$
DECLARE
  v_data    jsonb;
  v_pays    text;
  v_n       integer;
  v_r       record;
  v_couts   jsonb;
  v_m       text;
  v_q       jsonb;
  v_cm      numeric;
  v_mat     numeric := 0;
  v_pa_val  numeric;
  v_unit    numeric;
  v_coef    numeric;
BEGIN
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('disponible', false, 'raison', 'fonds_absent');
  END IF;
  v_pays  := v_data->'implantation'->>'country';
  v_couts := coalesce(v_data->'coutMoyenMatieres', '{}'::jsonb);

  SELECT count(*) INTO v_n FROM public.recettes_commerce WHERE generique_id = p_generique_id;
  IF v_n = 0 THEN
    RETURN jsonb_build_object('disponible', false, 'raison', 'recette_systeme_absente');
  END IF;
  IF v_n > 1 THEN
    RETURN jsonb_build_object('disponible', false, 'raison', 'recette_systeme_ambigue',
                              'recettes', v_n);
  END IF;
  SELECT * INTO v_r FROM public.recettes_commerce WHERE generique_id = p_generique_id;
  IF coalesce(v_r.portions, 0) <= 0 THEN
    RETURN jsonb_build_object('disponible', false, 'raison', 'rendement_non_declare');
  END IF;

  -- Garde de completude : toute matiere de la recette doit avoir un cout moyen
  -- REELLEMENT paye par ce fonds. Sinon le cout serait sous-estime.
  FOR v_m, v_q IN SELECT key, value FROM jsonb_each(coalesce(v_r.materiaux, '{}'::jsonb)) LOOP
    v_cm := (v_couts->>v_m)::numeric;
    IF v_cm IS NULL THEN
      RETURN jsonb_build_object('disponible', false, 'raison', 'cout_matiere_inconnu',
                                'matiere', v_m);
    END IF;
    v_mat := v_mat + (v_q#>>'{}')::numeric * v_cm;
  END LOOP;

  SELECT valeur::numeric INTO v_pa_val FROM public.entreprises_constantes
   WHERE cle = 'cout_main_oeuvre_pa_alimentaire';
  IF v_pa_val IS NULL THEN
    RETURN jsonb_build_object('disponible', false, 'raison', 'valeur_pa_non_declaree');
  END IF;

  v_unit := (v_mat + coalesce(v_r.pa, 0) * v_pa_val) / v_r.portions;
  v_coef := public.coef_prix_max_pj(v_pays);
  IF v_coef IS NULL THEN
    RETURN jsonb_build_object('disponible', false, 'raison', 'coefficient_pays_non_defini',
                              'pays', v_pays, 'coutUnitaire', v_unit);
  END IF;

  RETURN jsonb_build_object(
    'disponible', true, 'recette', v_r.id, 'pays', v_pays,
    'coutMatieres', v_mat, 'pa', coalesce(v_r.pa, 0), 'valeurPa', v_pa_val,
    'portions', v_r.portions, 'coutUnitaire', v_unit,
    'coefficient', v_coef, 'prixMaximum', ceil(v_unit * v_coef));
END;
$$;

comment on function public.fonds_cout_revient_reference(text,text) is
  'Cout de revient unitaire d''un generique pour un fonds donne, et plafond de prix qui en decoule. Rend disponible=false avec un motif precis plutot qu''un cout approche : une matiere au cout inconnu, une recette absente ou ambigue, ou un pays sans coefficient arbitre n''autorisent aucun prix.';

revoke all on function public.fonds_cout_revient_reference(text,text) from public, anon, authenticated;
grant execute on function public.fonds_cout_revient_reference(text,text) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. CREATION D'UNE REFERENCE
-- ---------------------------------------------------------------------------
-- LE SERVEUR VERIFIE L'AUTORISATION, il ne croit aucune liste du navigateur : le
-- generique doit figurer parmi ceux que les types L2 du fonds rendent accessibles.
-- Un appel direct avec un generique hors perimetre echoue.
--
-- LA REFERENCE NAIT INACTIVE ET SANS PRIX. Elle n'est donc pas vendable tant que
-- son proprietaire ne l'a pas tarifee puis activee -- et tarifer exige un cout de
-- revient calculable. Aucune vente ne peut donc reposer sur un prix non valide.
--
-- BORNES DE TEXTE : 80 et 400 caracteres, reprises de
-- NOM_REFERENCE_LONGUEUR_MAX / DESCRIPTION_REFERENCE_LONGUEUR_MAX
-- (plateau-alimentaire.js:266-267). Elles sont posees ICI, en un seul point : la
-- validation fait autorite cote serveur, tout controle d'interface ne sera qu'un
-- confort.
create or replace function public.fonds_reference_creer(
  p_acteur text, p_fonds_id text, p_generique_id text,
  p_nom text, p_description text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE
  v_data  jsonb;
  v_nom   text := btrim(coalesce(p_nom, ''));
  v_desc  text := nullif(btrim(coalesce(p_description, '')), '');
  v_ref_id text;
  v_gen   record;
  v_n     integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_fonds_id,'') = '' OR coalesce(p_generique_id,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF v_nom = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_absent');
  END IF;
  IF length(v_nom) > 80 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_trop_long', 'maximum', 80);
  END IF;
  IF v_desc IS NOT NULL AND length(v_desc) > 400 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'description_trop_longue', 'maximum', 400);
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent');
  END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj');
  END IF;
  IF coalesce(v_data->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif');
  END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM p_acteur
     AND (v_data->>'proprietaire') IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire');
  END IF;

  -- autorisation derivee du referentiel, jamais crue du client
  SELECT * INTO v_gen FROM public.fonds_generiques_accessibles(p_fonds_id)
   WHERE generique_id = p_generique_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'generique_hors_perimetre',
                              'generique', p_generique_id,
                              'typesAutorises', coalesce(v_data->'typesAutorises','[]'::jsonb));
  END IF;

  -- plafond : il porte sur le nombre TOTAL de references portees par le fonds,
  -- la place etant liberee par une desactivation seulement si le plafond d'actives
  -- est celui qui est oppose (voir fonds_reference_activer).
  SELECT count(*) INTO v_n FROM jsonb_each(coalesce(v_data->'references','{}'::jsonb));

  v_ref_id := 'ref-' || replace(gen_random_uuid()::text, '-', '');
  v_data := jsonb_set(v_data, ARRAY['references', v_ref_id], jsonb_strip_nulls(jsonb_build_object(
    'generique_id', v_gen.generique_id,
    'variante_id',  null,
    'nom',          v_nom,
    'description',  v_desc,
    'image',        null,
    'prixVente',    0,
    'active',       false,
    'creee_le',     to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS')
  )));
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'referenceId', v_ref_id,
                            'generique_id', v_gen.generique_id, 'generique', v_gen.libelle,
                            'famille', v_gen.famille, 'nom', v_nom,
                            'active', false, 'prixVente', 0,
                            'references', v_n + 1);
END;
$$;

comment on function public.fonds_reference_creer(text,text,text,text,text) is
  'Cree une reference commerciale sur un generique autorise par les types L2 du fonds. Le serveur derive lui-meme le perimetre : un generique hors perimetre est refuse, meme par appel direct. La reference nait INACTIVE et SANS PRIX, donc non vendable.';

revoke all on function public.fonds_reference_creer(text,text,text,text,text) from public, anon, authenticated;
grant execute on function public.fonds_reference_creer(text,text,text,text,text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 6. MODIFICATION — HABILLAGE SEULEMENT
-- ---------------------------------------------------------------------------
-- Nom et description, rien d'autre. generique_id, variante_id et toute propriete
-- mecanique sont INTOUCHABLES : cette fonction ne les lit meme pas depuis ses
-- parametres, elle n'en accepte aucun. On ne peut donc pas transformer un Souvenir
-- en Arme en reecrivant un champ. Si changer de generique doit un jour etre
-- possible, ce sera par une nouvelle reference ou un workflow explicite.
--
-- NULL = INCHANGE, pour qu'un ecran puisse ne toucher qu'un seul champ.
create or replace function public.fonds_reference_modifier(
  p_acteur text, p_fonds_id text, p_reference_id text,
  p_nom text, p_description text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE
  v_data jsonb;
  v_ref  jsonb;
  v_nom  text;
  v_desc text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM p_acteur
     AND (v_data->>'proprietaire') IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  v_ref := v_data->'references'->p_reference_id;
  IF v_ref IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reference_absente'); END IF;

  IF p_nom IS NOT NULL THEN
    v_nom := btrim(p_nom);
    IF v_nom = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'nom_absent'); END IF;
    IF length(v_nom) > 80 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'nom_trop_long', 'maximum', 80); END IF;
    v_ref := jsonb_set(v_ref, '{nom}', to_jsonb(v_nom));
  END IF;
  IF p_description IS NOT NULL THEN
    v_desc := nullif(btrim(p_description), '');
    IF v_desc IS NOT NULL AND length(v_desc) > 400 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'description_trop_longue', 'maximum', 400); END IF;
    v_ref := CASE WHEN v_desc IS NULL THEN v_ref - 'description'
                  ELSE jsonb_set(v_ref, '{description}', to_jsonb(v_desc)) END;
  END IF;
  v_ref  := jsonb_set(v_ref, '{modifiee_le}',
              to_jsonb(to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS')));
  v_data := jsonb_set(v_data, ARRAY['references', p_reference_id], v_ref);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'referenceId', p_reference_id,
                            'nom', v_ref->>'nom', 'description', v_ref->>'description',
                            'generique_id', v_ref->>'generique_id');
END;
$$;

comment on function public.fonds_reference_modifier(text,text,text,text,text) is
  'Modifie l''habillage commercial d''une reference : nom et description uniquement. N''accepte aucun parametre mecanique -- generique_id et variante_id sont structurellement inatteignables par cette porte.';

revoke all on function public.fonds_reference_modifier(text,text,text,text,text) from public, anon, authenticated;
grant execute on function public.fonds_reference_modifier(text,text,text,text,text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 7. PRIX — PLAFOND SERVEUR, JAMAIS UNE VALIDATION D'INTERFACE
-- ---------------------------------------------------------------------------
-- prix <= cout de revient unitaire x coefficient du PAYS. Un appel direct qui
-- depasse echoue. Si le cout n'est pas calculable, AUCUN prix n'est accepte : on
-- ne remplace pas un cout absent par zero, et on n'invente aucun plafond.
create or replace function public.fonds_reference_prix(
  p_acteur text, p_fonds_id text, p_reference_id text, p_prix integer)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE
  v_data jsonb;
  v_ref  jsonb;
  v_cout jsonb;
  v_prix integer := floor(coalesce(p_prix, 0));
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM p_acteur
     AND (v_data->>'proprietaire') IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  v_ref := v_data->'references'->p_reference_id;
  IF v_ref IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reference_absente'); END IF;
  IF v_prix <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'prix_invalide'); END IF;

  v_cout := public.fonds_cout_revient_reference(p_fonds_id, v_ref->>'generique_id');
  IF (v_cout->>'disponible')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_de_revient_indisponible',
                              'detail', v_cout);
  END IF;
  IF v_prix > (v_cout->>'prixMaximum')::numeric THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prix_au_dessus_du_plafond',
                              'maximum', (v_cout->>'prixMaximum')::numeric,
                              'coutUnitaire', (v_cout->>'coutUnitaire')::numeric,
                              'coefficient', (v_cout->>'coefficient')::numeric);
  END IF;

  v_ref  := jsonb_set(v_ref, '{prixVente}', to_jsonb(v_prix));
  v_ref  := jsonb_set(v_ref, '{modifiee_le}',
              to_jsonb(to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS')));
  v_data := jsonb_set(v_data, ARRAY['references', p_reference_id], v_ref);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'referenceId', p_reference_id, 'prixVente', v_prix,
                            'maximum', (v_cout->>'prixMaximum')::numeric,
                            'coutUnitaire', (v_cout->>'coutUnitaire')::numeric);
END;
$$;

comment on function public.fonds_reference_prix(text,text,text,integer) is
  'Fixe le prix de vente d''une reference. Plafond SERVEUR : cout de revient unitaire x coefficient du pays. Refuse tout prix lorsque le cout n''est pas calculable -- jamais de cout suppose a zero, jamais de plafond invente.';

revoke all on function public.fonds_reference_prix(text,text,text,integer) from public, anon, authenticated;
grant execute on function public.fonds_reference_prix(text,text,text,integer) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 8. ACTIVATION — RETIRER DE LA VENTE SANS RIEN PERDRE
-- ---------------------------------------------------------------------------
-- On ne SUPPRIME jamais une reference : une transaction passee doit pouvoir
-- continuer a la designer. On la retire de la vente. Le plafond porte sur les
-- references ACTIVES, donc desactiver libere une place.
--
-- Une reference sans prix ne peut pas etre activee : sinon elle serait « en vente »
-- tout en etant invendable (acheter_produit_commerce refuserait prix_non_fixe).
create or replace function public.fonds_reference_activer(
  p_acteur text, p_fonds_id text, p_reference_id text, p_active boolean)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE
  v_data jsonb;
  v_ref  jsonb;
  v_max  integer;
  v_actives integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM p_acteur
     AND (v_data->>'proprietaire') IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  v_ref := v_data->'references'->p_reference_id;
  IF v_ref IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reference_absente'); END IF;

  IF coalesce(p_active, false) THEN
    IF coalesce((v_ref->>'prixVente')::numeric, 0) <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'prix_non_fixe');
    END IF;
    v_max := public.fonds_references_max(v_data->>'proprietaire');
    SELECT count(*) INTO v_actives
      FROM jsonb_each(coalesce(v_data->'references','{}'::jsonb)) e
     WHERE coalesce((e.value->>'active')::boolean, false)
       AND e.key <> p_reference_id;
    IF v_actives >= v_max THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'plafond_references_atteint',
                                'maximum', v_max);
    END IF;
  END IF;

  v_ref  := jsonb_set(v_ref, '{active}', to_jsonb(coalesce(p_active, false)));
  v_ref  := jsonb_set(v_ref, '{modifiee_le}',
              to_jsonb(to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS')));
  v_data := jsonb_set(v_data, ARRAY['references', p_reference_id], v_ref);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'referenceId', p_reference_id,
                            'active', coalesce(p_active, false));
END;
$$;

comment on function public.fonds_reference_activer(text,text,text,boolean) is
  'Met une reference en vente ou la retire, sans jamais la supprimer : une transaction passee doit pouvoir continuer a la designer. Le plafond porte sur les references actives. Une reference sans prix ne peut pas etre activee.';

revoke all on function public.fonds_reference_activer(text,text,text,boolean) from public, anon, authenticated;
grant execute on function public.fonds_reference_activer(text,text,text,boolean) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 9. LE STOCK SORT DE LA REFERENCE
-- ---------------------------------------------------------------------------
-- Seule adaptation de C0, strictement necessaire au modele : acheter_produit_commerce
-- lisait et decrementait v_ref->>'stock'. Le stock vit desormais dans
-- data.stockReferences[referenceId], a cote de stockProduits (legacy). La reference
-- redevient un pur modele commercial, ce qui rendra l'instantane de transaction (C4)
-- trivialement propre : figer une reference n'embarquera jamais un compteur vivant.
--
-- Le reste de la fonction est INCHANGE, y compris la garde de rejeu et la
-- construction serveur de l'objet depuis L2.
create or replace function public.acheter_produit_commerce(
  p_requete      text,
  p_acheteur     text,
  p_fonds_id     text,
  p_reference_id text,
  p_quantite     integer
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE
  v_fonds       jsonb;
  v_ref         jsonb;
  v_gen         record;
  v_var_id      text := null;
  v_var_libelle text := null;
  v_prix        integer;
  v_stock       integer;
  v_veut        integer := GREATEST(0, COALESCE(p_quantite, 0));
  v_qte         integer;
  v_montant     integer;
  v_arg         numeric;
  v_objet       jsonb;
  v_livre       jsonb;
  v_ids         text[] := '{}';
  v_id          text;
  v_destinataire text;
  v_enseigne    text;
  i             integer;
BEGIN
  PERFORM public.exiger_acteur(p_acheteur);

  IF p_requete IS NULL OR p_requete !~ '^achat-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;
  IF COALESCE(p_acheteur,'') = '' OR COALESCE(p_fonds_id,'') = ''
     OR COALESCE(p_reference_id,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF v_veut <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  IF NOT public.mouvement_titulaire(p_acheteur, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_absent');
  END IF;

  SELECT data INTO v_fonds FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_fonds IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent');
  END IF;
  IF COALESCE(v_fonds->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif');
  END IF;

  v_ref := v_fonds->'references'->p_reference_id;
  IF v_ref IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_absente');
  END IF;
  IF COALESCE((v_ref->>'active')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_inactive');
  END IF;
  v_prix  := GREATEST(0, COALESCE((v_ref->>'prixVente')::numeric, 0))::integer;
  -- LE STOCK N'EST PLUS DANS LA REFERENCE
  v_stock := GREATEST(0, COALESCE((v_fonds->'stockReferences'->>p_reference_id)::numeric, 0))::integer;
  IF v_prix <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prix_non_fixe');
  END IF;
  IF v_stock <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rupture_de_stock');
  END IF;

  IF COALESCE(v_ref->>'generique_id','') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_sans_generique');
  END IF;
  SELECT g.id, g.libelle, g.regime, g.est_service, g.empilable, g.individualise,
         g.encombrement, g.consommable, g.equipable
    INTO v_gen
    FROM public.catalogue_generiques g
   WHERE g.id = v_ref->>'generique_id';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'generique_inconnu');
  END IF;
  IF v_gen.est_service THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'generique_est_un_service');
  END IF;
  IF NOT v_gen.individualise AND NOT v_gen.empilable THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'generique_regime_indetermine');
  END IF;
  IF COALESCE(v_ref->>'variante_id','') <> '' THEN
    SELECT v.id, v.libelle INTO v_var_id, v_var_libelle
      FROM public.catalogue_variantes v
     WHERE v.id = v_ref->>'variante_id' AND v.generique_id = v_gen.id;
    IF v_var_id IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'variante_incoherente');
    END IF;
  END IF;

  IF left(p_acheteur, 5) = 'orga:' THEN
    SELECT GREATEST(0, COALESCE((data::jsonb->>'caisse')::numeric, 0)) INTO v_arg
      FROM public.organisations WHERE id = substr(p_acheteur, 6);
  ELSE
    SELECT COALESCE(arg, 0) INTO v_arg FROM public.personnages
     WHERE name = CASE WHEN left(p_acheteur,3) = 'pj:' THEN substr(p_acheteur,4) ELSE p_acheteur END;
  END IF;
  IF v_arg IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_absent');
  END IF;
  v_qte := LEAST(v_veut, v_stock, floor(v_arg / v_prix)::integer);
  IF v_qte <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'prixUnitaire', v_prix);
  END IF;
  v_montant := v_qte * v_prix;

  IF EXISTS (SELECT 1 FROM public.objets_recus
              WHERE id = p_requete OR id LIKE p_requete || '-%') THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree');
  END IF;

  v_destinataire := CASE WHEN left(p_acheteur,3) = 'pj:' THEN substr(p_acheteur,4) ELSE p_acheteur END;
  v_enseigne     := COALESCE(NULLIF(btrim(v_fonds->>'enseigne'), ''), 'Commerce');
  v_objet := jsonb_strip_nulls(jsonb_build_object(
    'type',         p_reference_id,
    'generique_id', v_gen.id,
    'variante_id',  v_var_id,
    'name',         COALESCE(NULLIF(btrim(v_ref->>'nom'), ''),
                             COALESCE(v_var_libelle, v_gen.libelle)),
    'desc',         NULLIF(btrim(v_ref->>'description'), ''),
    'icon',         COALESCE(NULLIF(btrim(v_ref->>'icon'), ''), 'ti-package'),
    'imageUrl',     NULLIF(btrim(v_ref->>'image'), ''),
    'legal',        CASE WHEN v_gen.regime = 'illegal' THEN false ELSE true END,
    'provenance',   jsonb_build_object(
                      'fondsId',     p_fonds_id,
                      'referenceId', p_reference_id,
                      'createur',    v_fonds->>'proprietaire',
                      'etapes',      '[]'::jsonb)
  ));

  IF v_gen.individualise THEN
    FOR i IN 1..v_qte LOOP
      v_id := p_requete || '-' || i;
      v_livre := v_objet
                 || jsonb_build_object('qty', 1)
                 || CASE WHEN v_gen.encombrement IS NOT NULL
                         THEN jsonb_build_object('encombrement', v_gen.encombrement)
                         ELSE '{}'::jsonb END
                 || jsonb_build_object('exemplaire', jsonb_build_object('id', v_id));
      INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
      VALUES (v_id, v_destinataire, v_enseigne, to_jsonb(v_livre::text))
      ON CONFLICT (id) DO NOTHING;
      v_ids := v_ids || v_id;
    END LOOP;
  ELSE
    v_id    := p_requete;
    v_livre := v_objet || jsonb_build_object(
                 'stackable', true, 'stackKey', p_reference_id, 'qty', v_qte);
    INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
    VALUES (v_id, v_destinataire, v_enseigne, to_jsonb(v_livre::text))
    ON CONFLICT (id) DO NOTHING;
    v_ids := v_ids || v_id;
  END IF;

  IF NOT public.mouvement_titulaire(p_acheteur, -v_montant) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
  END IF;
  v_fonds := jsonb_set(v_fonds, ARRAY['stockReferences', p_reference_id],
               to_jsonb(v_stock - v_qte), true);
  v_fonds := jsonb_set(v_fonds, '{caisse}',
               to_jsonb(GREATEST(0, COALESCE((v_fonds->>'caisse')::numeric, 0)) + v_montant));
  UPDATE public.entreprises SET data = v_fonds, updated_at = now() WHERE id = p_fonds_id;

  RETURN jsonb_build_object(
    'ok', true, 'rejeu', false,
    'quantite', v_qte, 'prixUnitaire', v_prix, 'montant', v_montant,
    'stockRestant', v_stock - v_qte,
    'generique_id', v_gen.id, 'variante_id', v_var_id,
    'livraisons', to_jsonb(v_ids));
END;
$$;

revoke all on function public.acheter_produit_commerce(text,text,text,text,integer) from public, anon, authenticated;
grant execute on function public.acheter_produit_commerce(text,text,text,text,integer) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 10. LE FONDS PORTE DESORMAIS UNE CLE DE STOCK PAR REFERENCE
-- ---------------------------------------------------------------------------
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
    'typesAutorises',  '[]'::jsonb,
    'references',      '{}'::jsonb,
    'stockReferences', '{}'::jsonb,
    'stockMatieres',   '{}'::jsonb,
    'stockProduits',   '{}'::jsonb,
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