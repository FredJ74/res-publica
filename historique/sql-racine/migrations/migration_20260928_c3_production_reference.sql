-- =====================================================================
-- C3 — RECETTE SYSTEME, PRODUCTION, STOCK DE LA REFERENCE
-- =====================================================================
-- Migration appliquee en base : 20260928100652 c3_production_reference_et_recette_systeme
-- (5e des 5 migrations du chantier commerces PJ ; s'applique apres
--  migration_20260928_c2_references_commerciales.sql).
--
-- Ce fichier reproduit A L'IDENTIQUE le SQL applique. Ne pas le rejouer sur une
-- base ou la migration figure deja dans supabase_migrations.
-- =====================================================================

-- QUATRE COUCHES, QUATRE AUTORITES :
--   GENERIQUE  ce que c'est          (referentiel L2)
--   RECETTE    comment on le fabrique (donnee systeme, 0..N par generique)
--   REFERENCE  comment CE commercant le presente et le vend
--   STOCK      combien il en possede  (data.stockReferences)
--
-- CORRECTION DU MODELE C2. C2 avait retire recetteId de la reference, sur la base
-- d'une formulation qui decrivait mal le modele. La relation est rétablie, mais
-- PAS l'ancienne abstraction : la recette n'est plus l'identite mecanique de la
-- reference. L'identite reste generique_id ; la recette dit seulement COMMENT
-- cette reference est produite.
--
-- LE PJ NE CREE NI NE MODIFIE AUCUNE RECETTE. Il choisit laquelle des recettes
-- systeme de son generique il commercialise, et ce choix est FIGE a la creation :
-- pour commercialiser une autre recette du meme generique, il cree une autre
-- reference.
--
-- CONTRAINTE SERVEUR : recette.generique_id = reference.generique_id. Le client ne
-- peut jamais fournir une association contradictoire -- et il ne fournit d'ailleurs
-- ni matiere, ni PA, ni rendement : le serveur part du reference_id et retrouve
-- tout lui-meme.

-- ---------------------------------------------------------------------------
-- 1. RACCORDEMENT DES RECETTES SYSTEME AU GENERIQUE — VERTICALE TEMOIN SEULEMENT
-- ---------------------------------------------------------------------------
-- SEULES LES TROIS RECETTES DE SOUVENIR SONT RACCORDEES. Cet arbitrage est
-- explicitement valide : elles appartiennent bien au meme generique et ne
-- justifient aucun generique artificiel.
--
-- LES 22 AUTRES CORRESPONDANCES recette_id DE L2 NE SONT PAS RACCORDEES, et
-- chacune a une raison precise -- aucune n'est laissee de cote par negligence :
--
--   19 recettes de biens CONSOMMES SUR PLACE (boisson x5, encas x2, plat-simple x2,
--      plat-elabore x4, menu-gastronomique x6). Leur generique ne declare aucun
--      regime d'objet : produire remplirait un stock que l'achat refuserait
--      (generique_regime_indetermine). Le mode de commercialisation n'est pas
--      arbitre, donc on ne raccorde pas.
--
--    3 recettes de vetements (casquette_montrouge, echarpe_luthecia, tshirt_psm).
--      Les objets historiques issus de ces recettes portent bonusIntegrationVille
--      ou un bonus ENT REELLEMENT lu par getStatEffective. Un objet produit par un
--      PJ ne les porterait pas : deux objets de la meme recette auraient des effets
--      differents. C'est un arbitrage de game design, pas un detail technique.
--
-- ET LES 12 RECETTES SANS CORRESPONDANCE recette_id restent egalement dehors :
--    9 cartes postales -- l'objet exige etatCarte='vierge' pour etre ecrit, champ
--      qu'aucun constructeur serveur ne pose ;
--    3 aliments a emporter -- l'objet exige dateAchat (fraicheur), meme probleme.
--
-- AJOUTER UNE RECETTE DEMAIN NE DEMANDE AUCUN CODE : il suffit de poser
-- recettes_commerce.generique_id. Le moteur decouvre les recettes d'un generique
-- par cette seule colonne.
update public.recettes_commerce set generique_id = 'souvenir'
 where id in ('porte_cle_palais_luthecia', 'garde_republien_plomb', 'figurine_maxence_monfils');

-- ---------------------------------------------------------------------------
-- 2. RECETTES SYSTEME D'UN GENERIQUE — LECTURE DERIVEE
-- ---------------------------------------------------------------------------
create or replace function public.generique_recettes_systeme(p_generique_id text)
returns table (recette_id text, label text, pa integer, portions integer, materiaux jsonb)
language sql
stable
as $$
  select r.id, r.label, r.pa, r.portions, coalesce(r.materiaux, '{}'::jsonb)
    from public.recettes_commerce r
   where r.generique_id = p_generique_id
   order by r.id;
$$;

comment on function public.generique_recettes_systeme(text) is
  'Recettes systeme d''un generique L2, 0 a N. Un generique sans recette n''est pas fabrique : il relevera d''un autre mode d''obtention, et aucune recette ne lui est inventee.';

revoke all on function public.generique_recettes_systeme(text) from public, anon, authenticated;
grant execute on function public.generique_recettes_systeme(text) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. COUT DE REVIENT — DESORMAIS ADOSSE A LA RECETTE DE LA REFERENCE
-- ---------------------------------------------------------------------------
-- L'ambiguite « plusieurs recettes pour un generique » DISPARAIT : la reference
-- nomme sa recette. C'est le gain direct de la correction de modele.
--
-- METHODE COMPTABLE : le COUT MOYEN UNITE PONDERE deja en vigueur, jamais une
-- nouvelle methode. commerce_acheter_matiere maintient
--   coutMoyenMatieres[m] = (moyen_ancien x stock_ancien + prix_paye x qte) / (stock_ancien + qte)
-- Consommer de la matiere ne change pas cette moyenne, ce qui est le comportement
-- correct d'un CMUP. Deux lots achetes a 10 puis 20 FR donnent donc un cout de
-- revient assis sur la moyenne ponderee, et non sur le prix du dernier lot.
--
-- FORMULE, sans aucun arrondi intermediaire :
--   cout du lot   = somme(quantite x cout moyen reellement paye) + PA x valeur du PA
--   cout unitaire = cout du lot / quantite produite
drop function if exists public.fonds_cout_revient_reference(text, text);

create or replace function public.fonds_cout_revient_reference(
  p_fonds_id text, p_reference_id text)
returns jsonb
language plpgsql
stable
set search_path to 'public'
as $$
DECLARE
  v_data jsonb; v_ref jsonb; v_pays text; v_r record;
  v_couts jsonb; v_m text; v_q jsonb; v_cm numeric;
  v_mat numeric := 0; v_pa_val numeric; v_unit numeric; v_coef numeric;
BEGIN
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('disponible', false, 'raison', 'fonds_absent');
  END IF;
  v_ref := v_data->'references'->p_reference_id;
  IF v_ref IS NULL THEN
    RETURN jsonb_build_object('disponible', false, 'raison', 'reference_absente');
  END IF;
  IF coalesce(v_ref->>'recette_id','') = '' THEN
    RETURN jsonb_build_object('disponible', false, 'raison', 'reference_sans_recette');
  END IF;
  v_pays  := v_data->'implantation'->>'country';
  v_couts := coalesce(v_data->'coutMoyenMatieres', '{}'::jsonb);

  SELECT * INTO v_r FROM public.recettes_commerce WHERE id = v_ref->>'recette_id';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('disponible', false, 'raison', 'recette_inexistante');
  END IF;
  IF v_r.generique_id IS DISTINCT FROM (v_ref->>'generique_id') THEN
    RETURN jsonb_build_object('disponible', false, 'raison', 'recette_hors_generique',
                              'recetteGenerique', v_r.generique_id,
                              'referenceGenerique', v_ref->>'generique_id');
  END IF;
  IF coalesce(v_r.portions, 0) <= 0 THEN
    RETURN jsonb_build_object('disponible', false, 'raison', 'rendement_non_declare');
  END IF;

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
    'disponible', true, 'recette', v_r.id, 'generique', v_r.generique_id, 'pays', v_pays,
    'coutMatieres', v_mat, 'pa', coalesce(v_r.pa, 0), 'valeurPa', v_pa_val,
    'portions', v_r.portions, 'coutLot', v_mat + coalesce(v_r.pa,0) * v_pa_val,
    'coutUnitaire', v_unit, 'coefficient', v_coef,
    'prixMaximum', ceil(v_unit * v_coef));
END;
$$;

comment on function public.fonds_cout_revient_reference(text,text) is
  'Cout de revient unitaire d''une reference et plafond de prix qui en decoule, calcules depuis SA recette systeme et le cout moyen pondere reellement paye par le fonds. Rend disponible=false avec un motif precis plutot qu''un cout approche.';

revoke all on function public.fonds_cout_revient_reference(text,text) from public, anon, authenticated;
grant execute on function public.fonds_cout_revient_reference(text,text) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. CREATION D'UNE REFERENCE — AVEC SA RECETTE SYSTEME
-- ---------------------------------------------------------------------------
-- L'ancienne signature a 5 arguments est SUPPRIMEE : la laisser permettrait de
-- creer une reference sans recette sur un generique fabrique, donc une reference
-- structurellement improductible.
--
-- REGLE : si le generique possede au moins une recette systeme, le choix est
-- OBLIGATOIRE. S'il n'en possede aucune, en fournir une est refuse. Le champ reste
-- facultatif dans le modele -- tous les generiques ne sont pas fabriques.
drop function if exists public.fonds_reference_creer(text, text, text, text, text);

create or replace function public.fonds_reference_creer(
  p_acteur text, p_fonds_id text, p_generique_id text, p_recette_id text,
  p_nom text, p_description text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE
  v_data jsonb; v_nom text := btrim(coalesce(p_nom, ''));
  v_desc text := nullif(btrim(coalesce(p_description, '')), '');
  v_rec  text := nullif(btrim(coalesce(p_recette_id, '')), '');
  v_ref_id text; v_gen record; v_n integer; v_nb_recettes integer; v_r record;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_fonds_id,'') = '' OR coalesce(p_generique_id,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF v_nom = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'nom_absent'); END IF;
  IF length(v_nom) > 80 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_trop_long', 'maximum', 80); END IF;
  IF v_desc IS NOT NULL AND length(v_desc) > 400 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'description_trop_longue', 'maximum', 400); END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF coalesce(v_data->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM p_acteur
     AND (v_data->>'proprietaire') IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;

  SELECT * INTO v_gen FROM public.fonds_generiques_accessibles(p_fonds_id)
   WHERE generique_id = p_generique_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'generique_hors_perimetre',
                              'generique', p_generique_id,
                              'typesAutorises', coalesce(v_data->'typesAutorises','[]'::jsonb));
  END IF;

  SELECT count(*) INTO v_nb_recettes FROM public.recettes_commerce WHERE generique_id = p_generique_id;
  IF v_nb_recettes > 0 AND v_rec IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'recette_systeme_requise',
                              'recettes', (select jsonb_agg(jsonb_build_object('id', recette_id, 'label', label))
                                             from public.generique_recettes_systeme(p_generique_id)));
  END IF;
  IF v_nb_recettes = 0 AND v_rec IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'generique_sans_recette');
  END IF;
  IF v_rec IS NOT NULL THEN
    SELECT * INTO v_r FROM public.recettes_commerce WHERE id = v_rec;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'recette_inexistante'); END IF;
    IF v_r.generique_id IS DISTINCT FROM p_generique_id THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'recette_hors_generique',
                                'recetteGenerique', v_r.generique_id,
                                'generiqueDemande', p_generique_id); END IF;
  END IF;

  SELECT count(*) INTO v_n FROM jsonb_each(coalesce(v_data->'references','{}'::jsonb));
  v_ref_id := 'ref-' || replace(gen_random_uuid()::text, '-', '');
  v_data := jsonb_set(v_data, ARRAY['references', v_ref_id], jsonb_strip_nulls(jsonb_build_object(
    'generique_id', v_gen.generique_id,
    'recette_id',   v_rec,
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
                            'recette_id', v_rec, 'famille', v_gen.famille, 'nom', v_nom,
                            'active', false, 'prixVente', 0, 'references', v_n + 1);
END;
$$;

comment on function public.fonds_reference_creer(text,text,text,text,text,text) is
  'Cree une reference commerciale sur un generique autorise par les types L2 du fonds, avec la recette systeme choisie parmi celles de ce generique. Le choix de recette est obligatoire des lors que le generique en possede, et FIGE : commercialiser une autre recette demande une autre reference.';

revoke all on function public.fonds_reference_creer(text,text,text,text,text,text) from public, anon, authenticated;
grant execute on function public.fonds_reference_creer(text,text,text,text,text,text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. PRIX — RACCORDE A LA NOUVELLE SIGNATURE DU COUT
-- ---------------------------------------------------------------------------
create or replace function public.fonds_reference_prix(
  p_acteur text, p_fonds_id text, p_reference_id text, p_prix integer)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE
  v_data jsonb; v_ref jsonb; v_cout jsonb; v_prix integer := floor(coalesce(p_prix, 0));
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

  v_cout := public.fonds_cout_revient_reference(p_fonds_id, p_reference_id);
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

revoke all on function public.fonds_reference_prix(text,text,text,integer) from public, anon, authenticated;
grant execute on function public.fonds_reference_prix(text,text,text,integer) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 6. JOURNAL DES PRODUCTIONS — CLE D'IDEMPOTENCE ET COUT REEL DU LOT
-- ---------------------------------------------------------------------------
-- DEUX BESOINS REELS, UNE SEULE TABLE, ET ELLE A SON LECTEUR ET SON ECRIVAIN
-- DES AUJOURD'HUI :
--   - la cle de requete y est posee et RELUE avant tout debit : c'est la garde
--     d'idempotence, robuste parce qu'elle est une contrainte de cle primaire et
--     non un verrou d'interface ;
--   - le cout reellement supporte par le lot y est conserve, ce qui permettra de
--     rendre compte d'une production passee sans dependre de la moyenne courante.
--
-- FERMEE AUX CLIENTS : RLS active, aucune policy, aucun grant. Seules les fonctions
-- SECURITY DEFINER y touchent. On n'ouvre pas une lecture sans lecteur reel.
create table if not exists public.productions_references (
  requete       text primary key,
  fonds_id      text not null,
  reference_id  text not null,
  generique_id  text not null,
  recette_id    text not null,
  acteur        text not null,
  quantite      integer not null,
  pa            integer not null,
  matieres      jsonb   not null,
  cout_matieres numeric not null,
  cout_lot      numeric not null,
  cout_unitaire numeric not null,
  cree_le       timestamptz not null default now()
);

comment on table public.productions_references is
  'Journal des productions de references PJ. La cle primaire requete est la garde d''idempotence, verifiee avant tout debit. Conserve le cout REELLEMENT supporte par chaque lot. Ferme aux clients : ecriture et lecture par les RPC seules.';

create index if not exists idx_productions_references_fonds
  on public.productions_references (fonds_id, reference_id);

alter table public.productions_references enable row level security;
revoke all on public.productions_references from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 7. PRODUCTION
-- ---------------------------------------------------------------------------
-- LE CLIENT NE FOURNIT AUCUNE PROPRIETE MECANIQUE. Il demande « produis cette
-- reference » et rien d'autre : le serveur part du reference_id et retrouve
-- lui-meme le generique, la recette, les matieres, les PA et le rendement.
--
-- ORDRE DES OPERATIONS, ET C'EST LA GARANTIE :
--   1. attestation d'acteur
--   2. format de la cle de requete
--   3. VERROU du fonds, puis controles de fonds et de reference
--   4. chargement de la recette et controle recette.generique = reference.generique
--   5. le generique doit TOUJOURS relever des types du fonds
--   6. GARDE D'IDEMPOTENCE -- avant tout debit
--   7. VERROU du personnage, controle des PA
--   8. controle de CHAQUE matiere : quantite ET cout moyen connu
--   9. debits (matieres, PA), credit du stock, journal -- une seule transaction
--
-- AUCUNE PRODUCTION PARTIELLE : tout est dans la meme transaction PL/pgSQL. Si le
-- debit des PA ou l'ecriture du stock echoue, les matieres ne sont pas consommees.
--
-- PAS DE SALAIRE VERSE. Le moteur historique verse au producteur un salaire egal a
-- la valeur des PA, prelevee sur la caisse. Pour un fonds PJ ou l'acteur EST le
-- proprietaire, cela reviendrait a se payer avec son propre argent : une sortie de
-- caisse et une entree personnelle de meme montant, qui gonflent l'historique sans
-- rien changer. La doctrine du moteur dormant est explicite sur ce point
-- (plateau-commerce.js:404-413 : « un proprietaire qui travaille lui-meme ne recoit
-- rien »). Le travail garde en revanche sa VALEUR COMPTABLE dans le cout de
-- revient. Aucun mouvement d'argent n'est donc invente ici.
--
-- ALTERNATIVES DE MATIERES : aucune recette existante n'en declare -- materiaux est
-- un objet plat {matiere: quantite}. Aucun moteur d'alternatives n'est donc
-- construit, et rien n'est choisi a la place du joueur.
--
-- LE CMUP N'EST PAS TOUCHE. Consommer de la matiere au cout moyen laisse la moyenne
-- inchangee : c'est le comportement correct d'un cout moyen pondere, et c'est la
-- methode deja en vigueur. Aucune nouvelle methode comptable n'est introduite.
create or replace function public.fonds_reference_produire(
  p_requete text, p_acteur text, p_fonds_id text, p_reference_id text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE
  v_data jsonb; v_ref jsonb; v_r record; v_gen record;
  v_sm jsonb; v_couts jsonb; v_m text; v_q jsonb;
  v_besoin numeric; v_dispo numeric; v_cm numeric;
  v_mat numeric := 0; v_pa_val numeric; v_pa_requis integer;
  v_nom_pj text; v_pa integer; v_manque jsonb := '[]'::jsonb;
  v_stock_avant integer; v_quantite integer; v_cout_lot numeric; v_unit numeric;
  v_deja record;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_requete IS NULL OR p_requete !~ '^prod-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;
  IF coalesce(p_fonds_id,'') = '' OR coalesce(p_reference_id,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF coalesce(v_data->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM p_acteur
     AND (v_data->>'proprietaire') IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;

  v_ref := v_data->'references'->p_reference_id;
  IF v_ref IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reference_absente'); END IF;
  IF coalesce(v_ref->>'recette_id','') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_sans_recette'); END IF;

  SELECT * INTO v_r FROM public.recettes_commerce WHERE id = v_ref->>'recette_id';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'recette_inexistante'); END IF;
  IF v_r.generique_id IS DISTINCT FROM (v_ref->>'generique_id') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'recette_hors_generique',
                              'recetteGenerique', v_r.generique_id,
                              'referenceGenerique', v_ref->>'generique_id'); END IF;
  IF coalesce(v_r.portions, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rendement_non_declare'); END IF;

  SELECT * INTO v_gen FROM public.fonds_generiques_accessibles(p_fonds_id)
   WHERE generique_id = v_ref->>'generique_id';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'generique_hors_perimetre',
                              'generique', v_ref->>'generique_id'); END IF;

  -- GARDE D'IDEMPOTENCE, avant tout debit
  SELECT * INTO v_deja FROM public.productions_references WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'quantite', v_deja.quantite, 'coutUnitaire', v_deja.cout_unitaire);
  END IF;

  v_nom_pj := CASE WHEN left(p_acteur,3) = 'pj:' THEN substr(p_acteur,4) ELSE p_acteur END;
  SELECT coalesce(pa, 0) INTO v_pa FROM public.personnages_donnees
   WHERE name = v_nom_pj FOR UPDATE;
  IF v_pa IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_pa_requis := greatest(0, coalesce(v_r.pa, 0));
  IF v_pa < v_pa_requis THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants',
                              'requis', v_pa_requis, 'disponibles', v_pa); END IF;

  SELECT valeur::numeric INTO v_pa_val FROM public.entreprises_constantes
   WHERE cle = 'cout_main_oeuvre_pa_alimentaire';
  IF v_pa_val IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'valeur_pa_non_declaree'); END IF;

  v_sm    := coalesce(v_data->'stockMatieres', '{}'::jsonb);
  v_couts := coalesce(v_data->'coutMoyenMatieres', '{}'::jsonb);
  FOR v_m, v_q IN SELECT key, value FROM jsonb_each(coalesce(v_r.materiaux, '{}'::jsonb)) LOOP
    v_besoin := (v_q#>>'{}')::numeric;
    v_dispo  := coalesce((v_sm->>v_m)::numeric, 0);
    IF v_dispo < v_besoin THEN
      v_manque := v_manque || jsonb_build_object('matiere', v_m, 'requis', v_besoin, 'dispo', v_dispo);
    END IF;
    v_cm := (v_couts->>v_m)::numeric;
    IF v_cm IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cout_matiere_inconnu', 'matiere', v_m);
    END IF;
    v_mat := v_mat + v_besoin * v_cm;
  END LOOP;
  IF jsonb_array_length(v_manque) > 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matieres_insuffisantes',
                              'manquantes', v_manque);
  END IF;

  -- DEBITS ET CREDIT, une seule transaction
  FOR v_m, v_q IN SELECT key, value FROM jsonb_each(coalesce(v_r.materiaux, '{}'::jsonb)) LOOP
    v_sm := jsonb_set(v_sm, ARRAY[v_m],
              to_jsonb(coalesce((v_sm->>v_m)::numeric, 0) - (v_q#>>'{}')::numeric));
  END LOOP;

  v_quantite    := v_r.portions;
  v_stock_avant := greatest(0, coalesce((v_data->'stockReferences'->>p_reference_id)::numeric, 0))::integer;
  v_cout_lot    := v_mat + v_pa_requis * v_pa_val;
  v_unit        := v_cout_lot / v_quantite;

  v_data := jsonb_set(v_data, '{stockMatieres}', v_sm);
  v_data := jsonb_set(v_data, ARRAY['stockReferences', p_reference_id],
              to_jsonb(v_stock_avant + v_quantite), true);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;

  UPDATE public.personnages_donnees SET pa = v_pa - v_pa_requis WHERE name = v_nom_pj;

  INSERT INTO public.productions_references
    (requete, fonds_id, reference_id, generique_id, recette_id, acteur,
     quantite, pa, matieres, cout_matieres, cout_lot, cout_unitaire)
  VALUES (p_requete, p_fonds_id, p_reference_id, v_r.generique_id, v_r.id, p_acteur,
     v_quantite, v_pa_requis, coalesce(v_r.materiaux, '{}'::jsonb), v_mat, v_cout_lot, v_unit);

  RETURN jsonb_build_object('ok', true, 'rejeu', false,
    'referenceId', p_reference_id, 'recette', v_r.id, 'generique', v_r.generique_id,
    'quantite', v_quantite, 'stockAvant', v_stock_avant, 'stockApres', v_stock_avant + v_quantite,
    'paPreleves', v_pa_requis, 'paRestants', v_pa - v_pa_requis,
    'coutMatieres', v_mat, 'coutLot', v_cout_lot, 'coutUnitaire', v_unit,
    'matieresConsommees', coalesce(v_r.materiaux, '{}'::jsonb));
END;
$$;

comment on function public.fonds_reference_produire(text,text,text,text) is
  'Produit une reference PJ depuis SA recette systeme. Le client ne fournit ni matiere, ni PA, ni rendement : le serveur part du reference_id et retrouve tout. Idempotent par cle de requete, verifiee avant tout debit. Aucune production partielle : matieres, PA, stock et journal sont dans la meme transaction. Aucun salaire n''est verse -- le travail garde sa valeur comptable dans le cout de revient.';

revoke all on function public.fonds_reference_produire(text,text,text,text) from public, anon, authenticated;
grant execute on function public.fonds_reference_produire(text,text,text,text) to authenticated, service_role;
