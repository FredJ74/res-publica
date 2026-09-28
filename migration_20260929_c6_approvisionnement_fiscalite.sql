-- ===========================================================================
-- C6 — APPROVISIONNEMENT, PRESENCE PHYSIQUE ET FISCALITE DES COMMERCES PJ
-- 29 septembre 2026
-- ===========================================================================
--
-- CE QUE CE LOT FERME. La verticale C1-C5 savait tout faire SAUF entrer de la
-- matiere premiere : fonds_reference_produire lit data->'stockMatieres', mais
-- aucune RPC ne savait l'ecrire pour un fonds version 2. Le commerce d'Arnie
-- possede donc une reference « Porte-cle du palais presidentiel » dont la
-- recette systeme demande 1 Metal, et zero Metal. La chaine etait coupee la,
-- et nulle part ailleurs.
--
-- CE QU'ON NE REFAIT PAS. Le CMUP, le cout de revient, le plafond de prix par
-- pays, l'idempotence par cle de requete, la preuve immuable, la construction
-- serveur de l'objet : tout cela existe et fonctionne. On s'y RACCORDE.
--
-- SOCLE COMMUN vs COUCHE PAYS. Le moteur ne connait ni Republia ni aucun autre
-- empire. Deux grandeurs seulement sont des politiques de pays, et toutes deux
-- vivent en DONNEES dans entreprises_constantes, jamais dans du code :
--   - le coefficient de plafond de prix (coef_prix_max_pj, deja la, C2) ;
--   - le plafond de stock de matiere (fonds_plafond_stock_matiere, ci-dessous).
-- Ajouter un empire demain, c'est une ligne de donnees, pas une ligne de code.

-- ---------------------------------------------------------------------------
-- 1. COUCHE PAYS — PLAFOND DE STOCK DE MATIERE
-- ---------------------------------------------------------------------------
-- Republia : 20, valeur arbitree pour C6. Elle se trouve coincider avec la
-- constante stock_max_commerce du moteur legacy, mais ce n'est PAS la meme
-- grandeur et elles ne doivent pas etre confondues : celle-ci est une politique
-- economique de pays, celle-la une limite technique d'un autre moteur.
--
-- LES AUTRES EMPIRES : AUCUNE VALEUR, et on n'en invente pas. La fonction rend
-- NULL et l'approvisionnement y est refuse explicitement -- meme doctrine que
-- coef_prix_max_pj et que prix_ressource_selon_stock (« jamais de tarif
-- invente »). Un refus nomme vaut mieux qu'un chiffre invente.
insert into public.entreprises_constantes (cle, valeur) values
  ('stock_max_matiere_republic', 20)
on conflict (cle) do nothing;

create or replace function public.fonds_plafond_stock_matiere(p_pays text)
returns integer
language sql
stable
as $$
  select valeur::integer
    from public.entreprises_constantes
   where cle = 'stock_max_matiere_' || coalesce(nullif(btrim(p_pays), ''), '__aucun__');
$$;

comment on function public.fonds_plafond_stock_matiere(text) is
  'Plafond de stock d''une matiere premiere dans un fonds de commerce PJ. Politique economique PAR PAYS, lue dans entreprises_constantes. Rend NULL pour un pays non arbitre : aucune valeur n''est inventee, l''approvisionnement y est refuse.';

revoke all on function public.fonds_plafond_stock_matiere(text) from public, anon, authenticated;
grant execute on function public.fonds_plafond_stock_matiere(text) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. PRESENCE PHYSIQUE — LE SOCLE DE L'ECONOMIE MATERIELLE
-- ---------------------------------------------------------------------------
-- CONSTAT DU 29 SEPTEMBRE : aucune RPC du moteur C1-C5 ne verifiait ou se
-- trouve le joueur. acheter_produit_commerce appelait mouvement_titulaire(x, 0),
-- qui teste l'EXISTENCE du titulaire, jamais sa POSITION. On pouvait donc
-- acheter dans une boutique de Luthecia depuis Montrouge.
--
-- POURQUOI C'EST STRUCTURANT, et pas un detail de confort : sans presence
-- physique, il n'y a ni transport, ni difference de prix entre villes, ni
-- commerce international, ni penurie, ni contrebande. Les comportements
-- economiques que le jeu veut faire emerger reposent tous sur le fait qu'une
-- marchandise doit etre PORTEE quelque part.
--
-- On compare la position du personnage a l'implantation du fonds, exactement
-- comme pnj_co_present compare un joueur a un PNJ. Meme source, meme doctrine.
create or replace function public.fonds_acteur_present(p_acteur text, p_implantation jsonb)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE a record;
BEGIN
  IF p_acteur IS NULL OR p_implantation IS NULL THEN RETURN false; END IF;
  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = p_acteur;
  IF NOT FOUND OR a.current_city IS NULL THEN RETURN false; END IF;
  RETURN coalesce(
       a.country          IS NOT DISTINCT FROM (p_implantation->>'country')
   AND a.current_city     IS NOT DISTINCT FROM (p_implantation->>'city')
   AND a.current_building IS NOT DISTINCT FROM (p_implantation->>'buildingId')
   AND a.current_room     IS NOT DISTINCT FROM (p_implantation->>'roomId'), false);
END; $$;

comment on function public.fonds_acteur_present(text, jsonb) is
  'Vrai si le personnage se trouve physiquement dans le local ou le fonds est implante. Compare personnages_donnees.current_* a data->implantation, comme pnj_co_present.';

revoke all on function public.fonds_acteur_present(text, jsonb) from public, anon, authenticated;
grant execute on function public.fonds_acteur_present(text, jsonb) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. LES MATIERES RECHERCHEES SE DEDUISENT DES RECETTES
-- ---------------------------------------------------------------------------
-- ARBITRAGE : la source autoritaire est la RECETTE SYSTEME de chaque reference
-- du fonds. Aucune seconde liste « matiere <-> commerce » n'est maintenue : une
-- liste manuelle finirait par diverger des recettes, et il faudrait alors
-- arbitrer laquelle a raison. Ici la question ne se pose pas.
--
-- Toutes les references comptent, y compris celles RETIREES de la vente : une
-- reference desactivee consomme toujours de la matiere quand on la produit.
create or replace function public.fonds_matieres_recherchees(p_fonds_id text)
returns table (
  matiere        text,
  stock          numeric,
  maximum        integer,
  plafond_pays   integer,
  prix_achat     numeric,
  place_restante integer
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
DECLARE
  v_data jsonb; v_pays text; v_plafond integer;
BEGIN
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id;
  IF v_data IS NULL OR coalesce((v_data->>'version')::numeric, 0) < 2 THEN RETURN; END IF;
  v_pays    := v_data->'implantation'->>'country';
  v_plafond := public.fonds_plafond_stock_matiere(v_pays);

  RETURN QUERY
  WITH recettes AS (
    SELECT DISTINCT e.value->>'recette_id' AS rid
      FROM jsonb_each(coalesce(v_data->'references', '{}'::jsonb)) e
     WHERE nullif(btrim(coalesce(e.value->>'recette_id', '')), '') IS NOT NULL
  ), matieres AS (
    SELECT DISTINCT m.key AS cle
      FROM recettes r
      JOIN public.recettes_commerce rc ON rc.id = r.rid,
           jsonb_each(coalesce(rc.materiaux, '{}'::jsonb)) m
  )
  SELECT x.cle,
         x.stk,
         x.maxi,
         v_plafond,
         coalesce((v_data->'parametres'->'prixAchatMatiere'->>x.cle)::numeric,
                  (SELECT re.prix_achat_fournisseur FROM public.ressources_economie re WHERE re.cle = x.cle)),
         GREATEST(0, x.maxi - x.stk)::integer
    FROM (
      SELECT m.cle,
             GREATEST(0, coalesce((v_data->'stockMatieres'->>m.cle)::numeric, 0)) AS stk,
             LEAST(coalesce((v_data->'parametres'->'stockMaxMatieres'->>m.cle)::integer, coalesce(v_plafond, 0)),
                   coalesce(v_plafond, 0))::integer AS maxi
        FROM matieres m
    ) x
   ORDER BY x.cle;
END; $$;

comment on function public.fonds_matieres_recherchees(text) is
  'Matieres premieres qu''un fonds PJ recherche, DEDUITES des recettes systeme de ses references (actives ou non). Rend pour chacune le stock, le maximum choisi par le proprietaire, le plafond du pays, le prix de rachat affiche et la place restante.';

revoke all on function public.fonds_matieres_recherchees(text) from public, anon, authenticated;
grant execute on function public.fonds_matieres_recherchees(text) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. PARAMETRES DE RACHAT — LE PROPRIETAIRE DECIDE
-- ---------------------------------------------------------------------------
-- ARBITRAGE : le prix de rachat est LIBRE. La fourchette 0,5x-1,5x du moteur
-- legacy n'est pas reprise -- elle n'existait d'ailleurs que dans le navigateur,
-- donc elle ne protegeait rien. Payer cher pour attirer des fournisseurs est un
-- acte de jeu, pas une anomalie a brider. Seule contrainte : un prix negatif
-- n'a pas de sens.
--
-- Le maximum, lui, est borne par la politique du pays (0..plafond).
create or replace function public.fonds_matiere_parametres(
  p_acteur text, p_fonds_id text, p_matiere text,
  p_prix_achat numeric, p_maximum integer)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE
  v_data jsonb; v_pays text; v_plafond integer; v_par jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_fonds_id,'') = '' OR coalesce(btrim(p_matiere),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF coalesce(v_data->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM p_acteur
     AND (v_data->>'proprietaire') IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;

  -- La matiere doit etre l'une de celles que les recettes du fonds consomment :
  -- on ne tarife pas une matiere dont le commerce n'a aucun usage.
  IF NOT EXISTS (SELECT 1 FROM public.fonds_matieres_recherchees(p_fonds_id) m
                  WHERE m.matiere = btrim(p_matiere)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_non_recherchee'); END IF;

  v_pays    := v_data->'implantation'->>'country';
  v_plafond := public.fonds_plafond_stock_matiere(v_pays);
  IF v_plafond IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_matiere_non_defini', 'pays', v_pays); END IF;

  IF p_prix_achat IS NULL OR p_prix_achat < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prix_invalide'); END IF;
  IF p_maximum IS NULL OR p_maximum < 0 OR p_maximum > v_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'maximum_invalide',
                              'minimum', 0, 'maximum', v_plafond); END IF;

  v_par := coalesce(v_data->'parametres', '{}'::jsonb);
  v_par := jsonb_set(v_par, ARRAY['prixAchatMatiere'],
             jsonb_set(coalesce(v_par->'prixAchatMatiere','{}'::jsonb),
                       ARRAY[btrim(p_matiere)], to_jsonb(round(p_prix_achat, 2))), true);
  v_par := jsonb_set(v_par, ARRAY['stockMaxMatieres'],
             jsonb_set(coalesce(v_par->'stockMaxMatieres','{}'::jsonb),
                       ARRAY[btrim(p_matiere)], to_jsonb(p_maximum)), true);

  UPDATE public.entreprises
     SET data = jsonb_set(v_data, '{parametres}', v_par, true), updated_at = now()
   WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'matiere', btrim(p_matiere),
                            'prixAchat', round(p_prix_achat, 2), 'maximum', p_maximum,
                            'plafondPays', v_plafond);
END; $$;

comment on function public.fonds_matiere_parametres(text, text, text, numeric, integer) is
  'Le proprietaire fixe le prix de rachat (libre, >= 0) et le stock maximum (0..plafond du pays) d''une matiere de son fonds. Ecrit uniquement data->parametres->prixAchatMatiere et ->stockMaxMatieres.';

revoke all on function public.fonds_matiere_parametres(text, text, text, numeric, integer) from public, anon, authenticated;
grant execute on function public.fonds_matiere_parametres(text, text, text, numeric, integer) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. MAXIMUM DE STOCK PAR ARTICLE — GRANDEUR DISTINCTE
-- ---------------------------------------------------------------------------
-- DEUX MAXIMUMS, DEUX ESPACES DE NOMS. Le moteur legacy range le maximum des
-- matieres ET celui des produits dans la meme cle parametres.stockMax : ca
-- « marche » parce que les identifiants ne se croisent pas, mais c'est un
-- accident, pas une regle. Ici stockMaxMatieres et stockMaxReferences sont
-- separes, definitivement.
--
-- NON BRANCHE A LA PRODUCTION, VOLONTAIREMENT. Le comportement d'une recette
-- dont le rendement depasserait le maximum (refuser le lot ? produire une part ?
-- tolerer le depassement ?) n'est PAS arbitre. On stocke et on affiche la
-- valeur ; fonds_reference_produire n'est pas touchee. Trancher seul reviendrait
-- a inventer une regle de jeu.
create or replace function public.fonds_reference_stock_max(
  p_acteur text, p_fonds_id text, p_reference_id text, p_maximum integer)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE v_data jsonb; v_par jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_fonds_id,'') = '' OR coalesce(p_reference_id,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF p_maximum IS NULL OR p_maximum < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'maximum_invalide'); END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM p_acteur
     AND (v_data->>'proprietaire') IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  IF v_data->'references'->p_reference_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_absente'); END IF;

  v_par := coalesce(v_data->'parametres', '{}'::jsonb);
  v_par := jsonb_set(v_par, ARRAY['stockMaxReferences'],
             jsonb_set(coalesce(v_par->'stockMaxReferences','{}'::jsonb),
                       ARRAY[p_reference_id], to_jsonb(p_maximum)), true);

  UPDATE public.entreprises
     SET data = jsonb_set(v_data, '{parametres}', v_par, true), updated_at = now()
   WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'referenceId', p_reference_id, 'maximum', p_maximum);
END; $$;

comment on function public.fonds_reference_stock_max(text, text, text, integer) is
  'Stock maximum souhaite pour UNE reference (data->parametres->stockMaxReferences). Grandeur DISTINCTE du maximum des matieres. Stockee et affichee ; volontairement non opposee a la production tant que le comportement du depassement par le rendement d''une recette n''est pas arbitre.';

revoke all on function public.fonds_reference_stock_max(text, text, text, integer) from public, anon, authenticated;
grant execute on function public.fonds_reference_stock_max(text, text, text, integer) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 6. JOURNAL D'APPORT — IDEMPOTENCE PAR CLE DE REQUETE
-- ---------------------------------------------------------------------------
-- Meme dispositif que ventes_snapshots et productions_references : la cle de
-- requete est fabriquee par le client A L'OUVERTURE de l'ecran, et la contrainte
-- de cle primaire fait le reste. Un double clic rejoue la meme cle et ne peut
-- donc apporter la marchandise qu'une fois.
create table if not exists public.apports_matieres (
  requete        text primary key,
  cree_le        timestamptz not null default now(),
  fonds_id       text not null,
  acteur         text not null,
  matiere        text not null,
  mode           text not null check (mode in ('vente', 'don')),
  quantite       integer not null check (quantite > 0),
  prix_unitaire  numeric not null default 0,
  montant        numeric not null default 0
);

create index if not exists apports_matieres_fonds_idx on public.apports_matieres (fonds_id, cree_le desc);

alter table public.apports_matieres enable row level security;
revoke all on table public.apports_matieres from public, anon, authenticated;
grant select on table public.apports_matieres to service_role;

comment on table public.apports_matieres is
  'Journal des apports de matiere premiere a un fonds PJ (vente ou don). La cle de requete porte l''idempotence. Ecrit uniquement par fonds_matiere_apporter (SECURITY DEFINER) ; ferme au client.';

-- ---------------------------------------------------------------------------
-- 7. APPORT DE MATIERE — VENTE ET DON, UNE SEULE PORTE
-- ---------------------------------------------------------------------------
-- UNE SEULE RPC POUR DEUX GESTES. Vendre et donner ne different que par le prix
-- (celui du commerce, ou zero) et par le mouvement d'argent. Tout le reste --
-- presence, matiere acceptee, possession reelle, capacite, CMUP, verrous,
-- idempotence -- est rigoureusement identique. En faire deux fonctions, c'est
-- se condamner a corriger deux fois chaque defaut.
--
-- LE DON ET LE CMUP. Un apport gratuit entre dans la moyenne ponderee a un cout
-- de zero : il DILUE le cout moyen, il ne le laisse pas inchange. C'est la
-- verite comptable -- la matiere recue sans rien payer abaisse reellement le
-- cout de revient du commerce -- et c'est aussi la seule ecriture qui ne
-- fabrique pas de valeur a partir de rien.
--
-- ON BORNE, ON NE JETTE PAS. Si le joueur en propose plus que la place, la
-- caisse ou son propre stock ne le permettent, on realise la part possible et on
-- l'annonce. Refuser en bloc une vente de 700 Metal parce qu'il n'y a de la
-- place que pour 13 serait hostile sans rien proteger. Si la part possible est
-- nulle, le refus est nomme.
create or replace function public.fonds_matiere_apporter(
  p_requete text, p_acteur text, p_fonds_id text,
  p_matiere text, p_qte integer, p_mode text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE
  v_deja   record;
  v_data   jsonb;
  v_mat    text := btrim(coalesce(p_matiere, ''));
  v_mode   text := lower(btrim(coalesce(p_mode, 'vente')));
  v_veut   integer := GREATEST(0, coalesce(p_qte, 0));
  v_m      record;
  v_inv    jsonb; v_jour integer;
  v_detenu numeric; v_capacite integer; v_payable integer;
  v_prix   numeric; v_qte integer; v_montant numeric;
  v_caisse numeric; v_stock numeric; v_cmup numeric; v_nouveau numeric;
  v_sm jsonb; v_cmm jsonb; v_inv_apres jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  IF p_requete IS NULL OR p_requete !~ '^appro-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  IF v_mode NOT IN ('vente', 'don') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mode_invalide'); END IF;
  IF coalesce(p_fonds_id,'') = '' OR v_mat = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  -- Refus strict des quantites nulles, negatives ou non entieres.
  IF v_veut <= 0 OR v_veut IS DISTINCT FROM p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;

  -- REJEU : on rend le meme verdict sans rien refaire.
  SELECT * INTO v_deja FROM public.apports_matieres WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'quantite', v_deja.quantite, 'prixUnitaire', v_deja.prix_unitaire,
                              'montant', v_deja.montant, 'mode', v_deja.mode);
  END IF;

  -- ORDRE DES VERROUS : entreprises puis personnages_donnees, comme
  -- acheter_produit_commerce et commerce_acheter_matiere. Un ordre unique dans
  -- tout le domaine commerce est ce qui empeche deux transactions croisees de
  -- s'attendre mutuellement.
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF coalesce(v_data->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;

  -- PRESENCE PHYSIQUE. La marchandise doit etre portee sur place.
  IF NOT public.fonds_acteur_present(p_acteur, v_data->'implantation') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;

  -- MATIERE ACCEPTEE : deduite des recettes, jamais d'une liste tenue a la main.
  SELECT * INTO v_m FROM public.fonds_matieres_recherchees(p_fonds_id) m WHERE m.matiere = v_mat;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_non_recherchee', 'matiere', v_mat); END IF;
  IF v_m.plafond_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_matiere_non_defini',
                              'pays', v_data->'implantation'->>'country'); END IF;

  SELECT coalesce(inventory,'[]'::jsonb), coalesce(day,1) INTO v_inv, v_jour
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  v_detenu := public.inventaire_quantite(v_inv, v_mat);
  IF v_detenu <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_personnel_insuffisant', 'detenu', v_detenu); END IF;

  v_capacite := v_m.place_restante;
  IF v_capacite <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein',
                              'stock', v_m.stock, 'maximum', v_m.maximum); END IF;

  v_prix   := CASE WHEN v_mode = 'don' THEN 0 ELSE GREATEST(0, coalesce(v_m.prix_achat, 0)) END;
  v_caisse := GREATEST(0, coalesce((v_data->>'caisse')::numeric, 0));

  -- Combien la caisse peut-elle reellement payer ? Un prix nul ne borne rien.
  v_payable := CASE WHEN v_prix <= 0 THEN v_veut ELSE floor(v_caisse / v_prix)::integer END;
  v_qte := LEAST(v_veut, floor(v_detenu)::integer, v_capacite, v_payable);

  IF v_qte <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante',
                              'caisse', v_caisse, 'prixUnitaire', v_prix); END IF;

  v_montant := round(v_prix * v_qte, 2);

  -- MOUVEMENT D'ARGENT (vente seulement). La caisse du commerce paie, le
  -- patrimoine personnel du vendeur encaisse : deux patrimoines distincts, y
  -- compris quand c'est le proprietaire qui se vend a lui-meme.
  -- LE VENDEUR EST PAYE EN ESPECES, SUR PLACE. On crediterait volontiers par
  -- mouvement_titulaire, mais celui-ci ne touche que `arg` (la fortune) sans
  -- `liquide` (ce qui est reellement depensable) : l'invariant du jeu
  -- arg = liquide + comptes bancaires serait rompu et le vendeur repartirait
  -- avec de l'argent qu'il ne pourrait pas depenser. On credite donc les deux,
  -- comme le fait commerce_acheter_matiere depuis toujours.
  IF v_montant > 0 THEN
    UPDATE public.personnages_donnees
       SET arg     = COALESCE(arg, 0)     + v_montant,
           liquide = COALESCE(liquide, 0) + v_montant,
           updated_at = now()
     WHERE name = p_acteur;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'vendeur_introuvable'); END IF;
  END IF;

  -- CMUP : cout moyen ponderee sur ce que le commerce a REELLEMENT paye.
  v_sm    := coalesce(v_data->'stockMatieres', '{}'::jsonb);
  v_cmm   := coalesce(v_data->'coutMoyenMatieres', '{}'::jsonb);
  v_stock := GREATEST(0, coalesce((v_sm->>v_mat)::numeric, 0));
  v_cmup  := coalesce((v_cmm->>v_mat)::numeric, 0);
  v_nouveau := round(((v_cmup * v_stock) + (v_prix * v_qte)) / (v_stock + v_qte), 4);

  v_inv_apres := public.inventaire_retirer(v_inv, v_mat, v_qte);
  UPDATE public.personnages_donnees
     SET inventory = v_inv_apres, updated_at = now()
   WHERE name = p_acteur;

  v_data := v_data
    || jsonb_build_object(
         'stockMatieres',     jsonb_set(v_sm,  ARRAY[v_mat], to_jsonb(v_stock + v_qte)),
         'coutMoyenMatieres', jsonb_set(v_cmm, ARRAY[v_mat], to_jsonb(v_nouveau)))
    || jsonb_build_object('caisse', v_caisse - v_montant);

  v_data := public.entreprise_ajouter_historique(v_data, -v_montant,
    CASE WHEN v_mode = 'don' THEN 'Don de matiere (' ELSE 'Achat de matiere (' END
    || v_mat || ' x' || v_qte || ') — ' || p_acteur, v_jour);

  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;

  INSERT INTO public.apports_matieres
    (requete, fonds_id, acteur, matiere, mode, quantite, prix_unitaire, montant)
  VALUES (p_requete, p_fonds_id, p_acteur, v_mat, v_mode, v_qte, v_prix, v_montant);

  RETURN jsonb_build_object('ok', true, 'mode', v_mode, 'matiere', v_mat,
    'quantite', v_qte, 'demandee', v_veut, 'prixUnitaire', v_prix, 'montant', v_montant,
    'stock', v_stock + v_qte, 'maximum', v_m.maximum,
    'placeRestante', GREATEST(0, v_m.maximum - (v_stock + v_qte))::integer,
    'coutMoyen', v_nouveau, 'caisse', v_caisse - v_montant, 'inventory', v_inv_apres);
END; $$;

comment on function public.fonds_matiere_apporter(text, text, text, text, integer, text) is
  'Apport d''une matiere premiere a un fonds PJ, par vente (prix fixe par le proprietaire) ou par don (prix 0). Exige la presence physique. Deduit la matiere acceptee des recettes des references. Borne la quantite par la possession reelle, la place restante et la caisse. Met a jour le CMUP matiere. Idempotente par cle de requete.';

revoke all on function public.fonds_matiere_apporter(text, text, text, text, integer, text) from public, anon, authenticated;
grant execute on function public.fonds_matiere_apporter(text, text, text, text, integer, text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 8. LIMITE FREEMIUM DES REFERENCES : 6 -> 4
-- ---------------------------------------------------------------------------
-- La valeur de C2 etait explicitement provisoire. L'arbitrage la fixe a 4 pour
-- un commerce gratuit. On ne DETRUIT rien : un fonds qui en compterait deja
-- davantage les conserve, et seules les CREATIONS suivantes sont refusees.
update public.entreprises_constantes set valeur = 4 where cle = 'references_actives_max_base';
insert into public.entreprises_constantes (cle, valeur) values ('references_actives_max_base', 4)
on conflict (cle) do nothing;

-- ---------------------------------------------------------------------------
-- 9. CREATION DE REFERENCE — PLAFOND FREEMIUM
-- ---------------------------------------------------------------------------
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
  -- PLAFOND FREEMIUM (C6). La valeur de C2 etait explicitement provisoire ; elle
  -- est desormais arbitree a 4 pour un commerce gratuit, et lue dans
  -- entreprises_constantes pour qu'un statut Premium puisse la relever demain
  -- sans toucher une ligne de moteur. Fail closed a la CREATION : on refuse la
  -- reference suivante, on ne detruit JAMAIS une reference deja existante.
  IF v_n >= public.fonds_references_max(v_data->>'proprietaire') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_references_atteint',
                              'maximum', public.fonds_references_max(v_data->>'proprietaire'),
                              'references', v_n);
  END IF;
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
revoke all on function public.fonds_reference_creer(text,text,text,text,text,text) from public, anon, authenticated;
grant execute on function public.fonds_reference_creer(text,text,text,text,text,text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 10. ACHAT CLIENT — PRESENCE PHYSIQUE ET FISCALITE
-- ---------------------------------------------------------------------------
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
  v_acces       record;
  v_var_id      text := null;
  v_var_libelle text := null;
  v_prix        integer;
  v_stock       integer;
  v_veut        integer := GREATEST(0, COALESCE(p_quantite, 0));
  v_qte         integer;
  v_montant     integer;
  v_taxe        jsonb;
  v_net         numeric;
  v_arg         numeric;
  v_cout        jsonb;
  v_objet       jsonb;
  v_livre       jsonb;
  v_fiche       jsonb;
  v_ids         text[] := '{}';
  v_id          text;
  v_destinataire text;
  v_enseigne    text;
  v_types       jsonb;
  v_deja        record;
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
  IF v_veut <= 0 OR v_veut IS DISTINCT FROM p_quantite THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;

  SELECT * INTO v_deja FROM public.ventes_snapshots WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'venteId', v_deja.id, 'quantite', v_deja.quantite,
                              'montant', v_deja.montant_total);
  END IF;

  IF NOT public.mouvement_titulaire(p_acheteur, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_absent');
  END IF;

  SELECT data INTO v_fonds FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_fonds IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent');
  END IF;
  IF COALESCE((v_fonds->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj');
  END IF;
  IF COALESCE(v_fonds->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif');
  END IF;

  -- PRESENCE PHYSIQUE (C6). On n'achete que dans la boutique ou l'on se tient.
  -- Sans cette regle, il n'y a ni transport, ni ecart de prix entre villes, ni
  -- penurie : toute l'economie materielle du jeu repose dessus.
  IF NOT public.fonds_acteur_present(p_acheteur, v_fonds->'implantation') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  v_ref := v_fonds->'references'->p_reference_id;
  IF v_ref IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_absente');
  END IF;
  IF COALESCE((v_ref->>'active')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_inactive');
  END IF;
  v_prix  := GREATEST(0, COALESCE((v_ref->>'prixVente')::numeric, 0))::integer;
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
         g.encombrement, g.famille_id
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

  SELECT * INTO v_acces FROM public.fonds_generiques_accessibles(p_fonds_id)
   WHERE generique_id = v_gen.id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'generique_hors_perimetre',
                              'generique', v_gen.id);
  END IF;

  IF COALESCE(v_ref->>'recette_id','') <> '' THEN
    IF NOT EXISTS (SELECT 1 FROM public.recettes_commerce
                    WHERE id = v_ref->>'recette_id' AND generique_id = v_gen.id) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'recette_hors_generique',
                                'recette', v_ref->>'recette_id', 'generique', v_gen.id);
    END IF;
  END IF;

  IF COALESCE(v_ref->>'variante_id','') <> '' THEN
    SELECT v.id, v.libelle INTO v_var_id, v_var_libelle
      FROM public.catalogue_variantes v
     WHERE v.id = v_ref->>'variante_id' AND v.generique_id = v_gen.id;
    IF v_var_id IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'variante_incoherente');
    END IF;
  END IF;

  -- REVALIDATION DU PRIX contre le cout du STOCK REELLEMENT DETENU
  v_cout := public.fonds_cout_revient_reference(p_fonds_id, p_reference_id);
  IF (v_cout->>'disponible')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_de_revient_indisponible',
                              'detail', v_cout);
  END IF;
  IF v_prix > (v_cout->>'prixMaximum')::numeric THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prix_devenu_hors_plafond',
                              'prix', v_prix, 'maximum', (v_cout->>'prixMaximum')::numeric,
                              'coutUnitaire', (v_cout->>'coutUnitaire')::numeric,
                              'coefficient', (v_cout->>'coefficient')::numeric);
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
  IF v_veut > v_stock THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant',
                              'demande', v_veut, 'stock', v_stock);
  END IF;
  v_qte := v_veut;
  v_montant := v_qte * v_prix;
  IF v_arg < v_montant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'requis', v_montant, 'disponibles', v_arg);
  END IF;

  v_destinataire := CASE WHEN left(p_acheteur,3) = 'pj:' THEN substr(p_acheteur,4) ELSE p_acheteur END;
  v_enseigne     := COALESCE(NULLIF(btrim(v_fonds->>'enseigne'), ''), 'Commerce');
  v_objet := jsonb_strip_nulls(jsonb_build_object(
    'type',         p_reference_id,
    'generique_id', v_gen.id,
    'recette_id',   NULLIF(btrim(COALESCE(v_ref->>'recette_id','')), ''),
    'variante_id',  v_var_id,
    'name',         COALESCE(NULLIF(btrim(v_ref->>'nom'), ''),
                             COALESCE(v_var_libelle, v_gen.libelle)),
    'desc',         NULLIF(btrim(v_ref->>'description'), ''),
    'icon',         'ti-package',
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

  -- LA VENTE FAIT BAISSER LA QUANTITE, JAMAIS LE COUT MOYEN.
  v_fonds := jsonb_set(v_fonds, ARRAY['stockReferences', p_reference_id],
               to_jsonb(v_stock - v_qte), true);
  IF (v_stock - v_qte) <= 0 THEN
    v_fonds := jsonb_set(v_fonds, '{coutMoyenReferences}',
                 coalesce(v_fonds->'coutMoyenReferences', '{}'::jsonb) - p_reference_id, true);
  END IF;
  -- FISCALITE (C6). La vente d'un commerce PJ est soumise a la fiscalite
  -- commerciale COMMUNE, celle qu'applique deja commerce_vendre_produit. Le
  -- moteur ne connait aucun taux : appliquer_taxe_transaction lit le taux LOCAL
  -- dans budgets_municipaux et le taux NATIONAL dans budgets_nationaux -- la
  -- couche pays/ville est donc en donnees, pas en code. Le commerce encaisse le
  -- NET, l'acheteur paie le prix affiche. Meme transaction que la vente : si le
  -- prelevement echoue, la vente entiere est annulee, jamais l'inverse.
  v_taxe := public.appliquer_taxe_transaction(
              v_fonds->'implantation'->>'country',
              v_fonds->'implantation'->>'city',
              v_montant);
  v_net  := COALESCE((v_taxe->>'net')::numeric, v_montant);
  v_fonds := jsonb_set(v_fonds, '{caisse}',
               to_jsonb(GREATEST(0, COALESCE((v_fonds->>'caisse')::numeric, 0)) + v_net));
  UPDATE public.entreprises SET data = v_fonds, updated_at = now() WHERE id = p_fonds_id;

  v_fiche := public.objet_fiche_officielle(v_livre);
  SELECT jsonb_agg(ty.libelle ORDER BY ty.ordre) INTO v_types
    FROM public.catalogue_generique_type gt
    JOIN public.catalogue_types ty ON ty.id = gt.type_id
   WHERE gt.generique_id = v_gen.id;

  INSERT INTO public.ventes_snapshots
    (requete, jour_paris, acheteur, vendeur, fonds_id, pays,
     reference_id, nom_commercial, description_commerciale,
     generique_id, recette_id, variante_id, famille, types,
     quantite, prix_unitaire, montant_total, fiche_officielle)
  VALUES (p_requete,
     to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD'),
     p_acheteur, v_fonds->>'proprietaire', p_fonds_id, v_fonds->'implantation'->>'country',
     p_reference_id,
     COALESCE(NULLIF(btrim(v_ref->>'nom'), ''), COALESCE(v_var_libelle, v_gen.libelle)),
     NULLIF(btrim(v_ref->>'description'), ''),
     v_gen.id, NULLIF(btrim(COALESCE(v_ref->>'recette_id','')), ''), v_var_id,
     v_acces.famille, v_types,
     v_qte, v_prix, v_montant, v_fiche);

  RETURN jsonb_build_object(
    'ok', true, 'rejeu', false,
    'quantite', v_qte, 'prixUnitaire', v_prix, 'montant', v_montant,
    'stockRestant', v_stock - v_qte,
    'coutUnitaireStock', (v_cout->>'coutUnitaire')::numeric,
    'generique_id', v_gen.id, 'recette_id', v_ref->>'recette_id', 'variante_id', v_var_id,
    'livraisons', to_jsonb(v_ids),
    'venteId', (SELECT id FROM public.ventes_snapshots WHERE requete = p_requete),
    'net', v_net, 'taxeLocale', (v_taxe->>'taxeLocale')::numeric,
    'taxeNationale', (v_taxe->>'taxeNationale')::numeric);
END;
$$;
revoke all on function public.acheter_produit_commerce(text,text,text,text,integer) from public, anon, authenticated;
grant execute on function public.acheter_produit_commerce(text,text,text,text,integer) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 11. PLAFOND DU CATALOGUE — UNE SEULE SEMANTIQUE
-- ---------------------------------------------------------------------------
-- La cle s'appelait 'references_actives_max_base' : elle ne mesure plus les
-- references ACTIVES mais le CATALOGUE du commerce. Un nom qui ment est une
-- dette ; on le corrige en meme temps que la regle.
insert into public.entreprises_constantes (cle, valeur) values ('references_max_base', 4)
on conflict (cle) do update set valeur = 4;

delete from public.entreprises_constantes where cle = 'references_actives_max_base';

create or replace function public.fonds_references_max(p_proprietaire text)
returns integer
language sql
stable
as $$
  select greatest(1, coalesce(
    (select valeur::integer from public.entreprises_constantes
      where cle = 'references_max_base'), 4));
$$;

comment on function public.fonds_references_max(text) is
  'Nombre maximum de references qu''un commerce peut POSSEDER (son catalogue), gratuit = 4. Oppose une seule fois, a la creation. Retirer une reference de la vente ne libere aucune place : elle appartient toujours au commerce. Le parametre proprietaire est conserve pour qu''un statut Premium puisse relever ce plafond sans changer d''appelants.';

-- ---------------------------------------------------------------------------
-- 12. MISE EN VENTE — SUPPRESSION DU PLAFOND CONCURRENT
-- ---------------------------------------------------------------------------
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
    -- PLUS DE PLAFOND A L'ACTIVATION (C6). Il en existait un, sur les references
    -- ACTIVES, et il entrait en concurrence avec le plafond du CATALOGUE pose a la
    -- creation. Deux semantiques pour une meme limite, c'est une faille : on
    -- creait 4 produits, on en desactivait un, on en creait un cinquieme, et le
    -- commerce finissait avec 5 references en jonglant. La limite gratuite porte
    -- desormais sur le CATALOGUE, une seule fois, a la creation. Retirer une
    -- reference de la vente ne libere donc aucune place -- elle appartient
    -- toujours au commerce.
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

revoke all on function public.fonds_reference_activer(text,text,text,boolean) from public, anon, authenticated;
grant execute on function public.fonds_reference_activer(text,text,text,boolean) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 13. PRODUCTION — LE LOT COMPLET OU RIEN
-- ---------------------------------------------------------------------------
create or replace function public.fonds_reference_produire(
  p_requete text, p_acteur text, p_fonds_id text, p_reference_id text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE
  v_max_ref integer;
  v_data jsonb; v_ref jsonb; v_r record; v_gen record;
  v_sm jsonb; v_couts jsonb; v_m text; v_q jsonb;
  v_besoin numeric; v_dispo numeric; v_cm numeric;
  v_mat numeric := 0; v_pa_val numeric; v_pa_requis integer;
  v_nom_pj text; v_pa integer; v_manque jsonb := '[]'::jsonb;
  v_stock_avant integer; v_quantite integer; v_cout_lot numeric; v_unit numeric;
  v_cmup_avant numeric; v_cmup_apres numeric;
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

  -- STOCK MAXIMUM DE L'ARTICLE (C6). Le rendement d'une recette est officiel et
  -- INDIVISIBLE : on ne fabrique pas « juste ce qui rentre », sinon le rendement
  -- annonce au joueur cesserait d'etre vrai. Si le lot complet ferait depasser le
  -- maximum choisi par le proprietaire, on refuse le lot ENTIER -- et on rend les
  -- trois chiffres qui permettent de le comprendre : stock, rendement, maximum.
  -- Le controle a lieu AVANT la consommation des matieres : un refus ne coute rien.
  -- Un maximum absent ou nul signifie « pas de limite ».
  v_max_ref := nullif((v_data->'parametres'->'stockMaxReferences'->>p_reference_id)::integer, 0);
  IF v_max_ref IS NOT NULL
     AND greatest(0, coalesce((v_data->'stockReferences'->>p_reference_id)::numeric, 0))::integer
         + v_r.portions > v_max_ref THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_max_reference_depasse',
      'stock', greatest(0, coalesce((v_data->'stockReferences'->>p_reference_id)::numeric, 0))::integer,
      'rendement', v_r.portions, 'maximum', v_max_ref);
  END IF;

  FOR v_m, v_q IN SELECT key, value FROM jsonb_each(coalesce(v_r.materiaux, '{}'::jsonb)) LOOP
    v_sm := jsonb_set(v_sm, ARRAY[v_m],
              to_jsonb(coalesce((v_sm->>v_m)::numeric, 0) - (v_q#>>'{}')::numeric));
  END LOOP;

  v_quantite    := v_r.portions;
  v_stock_avant := greatest(0, coalesce((v_data->'stockReferences'->>p_reference_id)::numeric, 0))::integer;
  v_cout_lot    := v_mat + v_pa_requis * v_pa_val;
  v_unit        := v_cout_lot / v_quantite;

  -- CMUP DU PRODUIT FINI : moyenne ponderee de l'ancien stock et du nouveau lot.
  -- Stock precedent nul -> le cout du nouveau lot est le seul a compter, et aucune
  -- ancienne valeur comptable ne peut fausser le nouveau stock.
  v_cmup_avant := (v_data->'coutMoyenReferences'->>p_reference_id)::numeric;
  IF v_stock_avant <= 0 OR v_cmup_avant IS NULL THEN
    v_cmup_apres := v_unit;
  ELSE
    v_cmup_apres := (v_stock_avant * v_cmup_avant + v_cout_lot) / (v_stock_avant + v_quantite);
  END IF;

  v_data := jsonb_set(v_data, '{stockMatieres}', v_sm);
  v_data := jsonb_set(v_data, ARRAY['stockReferences', p_reference_id],
              to_jsonb(v_stock_avant + v_quantite), true);
  v_data := jsonb_set(v_data, ARRAY['coutMoyenReferences', p_reference_id],
              to_jsonb(v_cmup_apres), true);
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
    'coutMatieres', v_mat, 'coutLot', v_cout_lot, 'coutUnitaireLot', v_unit,
    'cmupAvant', v_cmup_avant, 'cmupApres', v_cmup_apres,
    'matieresConsommees', coalesce(v_r.materiaux, '{}'::jsonb));
END;
$$;

revoke all on function public.fonds_reference_produire(text,text,text,text) from public, anon, authenticated;
grant execute on function public.fonds_reference_produire(text,text,text,text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 14. RACCORDEMENT DES RECETTES « OBJET » AU REFERENTIEL L2
-- ---------------------------------------------------------------------------
-- Le referentiel L2 comptait 84 generiques et UN SEUL raccorde a une recette.
-- Le joueur pouvait donc choisir un generique, aller au bout du parcours et
-- lire « Ce produit ne se fabrique pas » -- c'est ce qu'a montre le test du
-- T-shirt.
--
-- Aucune correspondance n'est ecrite a la main : elles sont LUES dans
-- catalogue_correspondance_legacy, la table produite par l'audit L2, dont
-- chaque ligne porte sa preuve en colonne source_audit.
--
-- PERIMETRE STRICT : categorie = 'objet' et generique_id encore nul. La
-- restauration (boisson/menu/plat/petit_dej/snack) et l'armurerie
-- (recettes_production) ne sont pas touchees : leurs verticales sont fermees.

-- 1. Correspondances NOMINATIVES (motif 'recette_id') : une ligne d'audit par
--    recette, la preuve la plus forte. T-shirt, echarpe, casquette.
update public.recettes_commerce r
   set generique_id = c.generique_id
  from public.catalogue_correspondance_legacy c
 where c.motif = 'recette_id'
   and c.valeur = r.id
   and r.categorie = 'objet'
   and r.generique_id is null;

-- 2. Correspondance par FAMILLE, limitee explicitement a la carte postale : les
--    neuf cartes portent toutes famille_produit_marche = 'carte_postale'.
--    On n'etend PAS ce mecanisme a la famille 'aliment' : le choix entre les
--    generiques 'encas' et 'encas-a-emporter' n'est pas arbitre, et ces trois
--    produits relevent de la restauration, verticale non ouverte.
update public.recettes_commerce r
   set generique_id = c.generique_id
  from public.catalogue_correspondance_legacy c
 where c.motif = 'famille_produit_marche'
   and c.valeur = 'carte_postale'
   and c.valeur = r.famille_produit_marche
   and r.categorie = 'objet'
   and r.generique_id is null;

-- ---------------------------------------------------------------------------
-- 15. FILTRAGE STRUCTUREL : ON NE PROPOSE QUE CE QUI SE FABRIQUE
-- ---------------------------------------------------------------------------
-- Correction structurelle et SANS LISTE : un generique n'est propose que s'il
-- existe au moins une recette systeme qui le produise. La verite decoule des
-- donnees -- raccorder demain une recette a un nouveau generique le rendra
-- proposable sans toucher une ligne de code, ici ou dans l'interface.
create or replace function public.fonds_generiques_accessibles(p_fonds_id text)
returns table (generique_id text, libelle text, famille_id text, famille text, types text[])
language sql
stable
security definer
set search_path to 'public'
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
   where exists (select 1 from public.recettes_commerce r where r.generique_id = g.id)
   group by g.id, g.libelle, g.famille_id, fam.libelle
   order by fam.libelle, g.libelle;
$$;

comment on function public.fonds_generiques_accessibles(text) is
  'Generiques qu''un fonds peut decliner en references : croisement de ses typesAutorises avec le referentiel L2, RESTREINT aux generiques pour lesquels il existe au moins une recette systeme. Un generique sans recette n''est jamais propose : le joueur ne peut plus aboutir a un produit non fabricable.';

revoke all on function public.fonds_generiques_accessibles(text) from public, anon, authenticated;
grant execute on function public.fonds_generiques_accessibles(text) to anon, authenticated, service_role;
