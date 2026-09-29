-- ===========================================================================
-- C7 — GESTION PROPRIETAIRE D'UN COMMERCE PJ : UNE SEULE GRANDEUR PAR REGLAGE
-- 29 septembre 2026
-- ===========================================================================
-- Ce lot ne touche NI le moteur commercial, NI la fiscalite, NI la production,
-- NI l'achat. Il corrige deux defauts d'ERGONOMIE dont l'un a une racine
-- serveur, et il branche deux portes qui existaient sans interface.
--
-- ---------------------------------------------------------------------------
-- DEFAUT 1 — DEUX REGLAGES POUR UNE SEULE DECISION
-- ---------------------------------------------------------------------------
-- C6 bis avait separe « acceptee » (booleen) de « stock maximum » (entier)
-- parce que le chiffre 0 portait deux sens contradictoires : ILLIMITE et
-- REFUSE. La separation reglait l'ambiguite, mais au prix d'une double saisie
-- qui n'apporte rien : un proprietaire qui fixe un maximum accepte la matiere,
-- et un proprietaire qui n'en veut pas n'a pas besoin de deux cases pour le
-- dire.
--
-- L'AMBIGUITE EST LEVEE AUTREMENT, ET DEFINITIVEMENT : « 0 = refuse », point.
-- « Illimite » n'existe plus comme valeur saisissable, et n'a jamais eu de
-- sens reel de toute facon -- le plafond du pays bornait deja tout stock. Un
-- maximum vaut donc entre 0 (« je n'en veux pas ») et le plafond du pays, et
-- l'acceptation n'est plus une donnee : elle se DEDUIT du maximum.
--
-- `acceptee` reste dans le contrat de fonds_matieres_accessibles : c'est la
-- garde que lit fonds_matiere_apporter, et la reecrire serait toucher au
-- moteur d'apport. Elle devient simplement une fonction du maximum, calculee
-- au seul endroit qui la rend. Aucun appelant ne change.
--
-- ---------------------------------------------------------------------------
-- DEFAUT 2 — LA CAISSE N'AVAIT PAS D'ENTREE NI DE SORTIE UTILISABLES
-- ---------------------------------------------------------------------------
-- alimenter_caisse_fonds et retirer_caisse_fonds existent depuis le socle des
-- fonds de commerce, avec leurs deux helpers clients, mais AUCUN ecran ne les
-- appelait. Les brancher telles quelles aurait introduit deux defauts reels :
--   (a) elles passent par mouvement_titulaire, qui ne touche que `arg` sans
--       `liquide`. L'invariant arg = liquide + banques serait rompu : le
--       proprietaire qui preleve 500 FR reparte avec un argent qu'il ne peut
--       pas depenser, et celui qui apporte 500 FR garde un liquide qu'il n'a
--       plus. Meme defaut, meme correction locale que dans C6
--       (fonds_matiere_apporter paie le vendeur sur ses deux colonnes).
--   (b) elles n'appellent pas exiger_acteur et sont ouvertes a `anon` : le nom
--       de l'acteur est cru sur parole. N'importe qui pouvait vider la caisse
--       d'un commerce vers le patrimoine de son proprietaire -- ou, pire,
--       debiter le patrimoine d'un tiers. La faille existait deja ; on ne
--       branche pas une interface par-dessus sans la fermer.
--
-- L'APPORT EST DU NUMERAIRE. Un commerce est un lieu physique et sa caisse
-- contient des especes : on debite donc `liquide`, jamais un solde bancaire, et
-- on refuse si le liquide ne couvre pas. Le prelevement credite symetriquement
-- les deux colonnes. La masse monetaire ne bouge pas d'un FR.
--
-- ---------------------------------------------------------------------------
-- fonds_matieres_recherchees N'EST PAS TOUCHEE : elle ne garde plus rien et ne
-- nourrit plus aucun ecran depuis C6 bis (elle ne sert qu'a la colonne
-- indicative `utilisee`). Elle lit encore « 0 = plafond » ; c'est sans effet.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. REPRISE DE L'EXISTANT — AUCUN COMMERCE NE CHANGE DE COMPORTEMENT
-- ---------------------------------------------------------------------------
-- Changer le sens de 0 SANS reprendre les donnees inverserait la volonte des
-- proprietaires en place : une matiere ouverte « sans limite » (acceptee=true,
-- maximum=0) se fermerait du jour au lendemain. On traduit donc chaque reglage
-- existant dans la nouvelle echelle, en conservant exactement son effet REEL
-- d'hier -- c'est-a-dire la place restante que C6 bis calculait :
--
--   refusee (acceptee absent ou false)  -> 0            (elle etait fermee)
--   acceptee, maximum absent ou 0       -> plafond pays (elle etait illimitee,
--                                                        donc bornee au plafond)
--   acceptee, maximum > 0               -> inchange
--
-- Une matiere JAMAIS parametree n'a aucune cle nulle part : elle ne figure donc
-- pas ici, et prendra le nouveau defaut de 2 a la lecture. C'est voulu -- c'est
-- la regle de jeu arbitree pour ce lot.
--
-- Idempotente : relancer la migration recalcule le meme resultat, puisque toute
-- cle reprise porte desormais un maximum > 0 avec acceptee=true, ou 0.
with reprise as (
  select e.id,
         public.fonds_plafond_stock_matiere(e.data->'implantation'->>'country') as plafond,
         coalesce(e.data->'parametres'->'stockMaxMatieres',  '{}'::jsonb) as maxis,
         coalesce(e.data->'parametres'->'matieresAcceptees', '{}'::jsonb) as oks
    from public.entreprises e
   where coalesce((e.data->>'version')::numeric, 0) >= 2
), cles as (
  select r.id, r.plafond, r.maxis, r.oks, t.cle
    from reprise r
    join lateral (
      select key as cle from jsonb_each(r.maxis)
      union
      select key from jsonb_each(r.oks)
    ) t on true
), traduites as (
  select c.id,
         jsonb_object_agg(c.cle, to_jsonb(
           case
             -- Fermee hier : elle reste fermee, et 0 le dit maintenant tout seul.
             when not coalesce((c.oks->>c.cle)::boolean, false) then 0
             -- Illimitee hier : son effet reel etait le plafond du pays. Sans
             -- plafond arbitre, l'approvisionnement etait de toute facon refuse :
             -- 0 est alors la traduction fidele.
             when coalesce((c.maxis->>c.cle)::integer, 0) = 0 then coalesce(c.plafond, 0)
             -- Bornee hier : on ne touche a rien, sinon pour respecter le plafond.
             else least(greatest(0, (c.maxis->>c.cle)::integer), coalesce(c.plafond, 0))
           end)) as maxis
    from cles c
   group by c.id
)
update public.entreprises e
   set data = jsonb_set(
         jsonb_set(e.data, '{parametres,stockMaxMatieres}', t.maxis, true),
         -- matieresAcceptees devient un MIROIR du maximum, jamais une source.
         -- On le tient a jour pour qu'aucun lecteur ancien ne voie deux verites
         -- contradictoires dans la meme ligne.
         '{parametres,matieresAcceptees}',
         (select coalesce(jsonb_object_agg(k.key, to_jsonb((k.value#>>'{}')::integer > 0)), '{}'::jsonb)
            from jsonb_each(t.maxis) k), true),
       updated_at = now()
  from traduites t
 where t.id = e.id;

-- ---------------------------------------------------------------------------
-- 2. MATIERES ACCESSIBLES — L'ACCEPTATION SE DEDUIT DU MAXIMUM
-- ---------------------------------------------------------------------------
-- Trois changements, et rien d'autre :
--   - un maximum non declare vaut 2 (et non plus 0) ;
--   - `acceptee` est calculee : maximum > 0 ;
--   - la place restante suit la meme echelle, sans cas particulier a 0.
-- Le reste du contrat -- colonnes, ordre, perimetre derive des activites --
-- est repris a l'identique : fonds_matiere_apporter et fonds_matiere_parametres
-- continuent de la lire sans changer d'une ligne.
create or replace function public.fonds_matieres_accessibles(p_fonds_id text)
returns table(matiere text, stock numeric, maximum integer, plafond_pays integer,
              prix_achat numeric, place_restante integer, acceptee boolean, utilisee boolean)
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_data jsonb; v_pays text; v_plafond integer; v_defaut integer;
BEGIN
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id;
  IF v_data IS NULL OR coalesce((v_data->>'version')::numeric, 0) < 2 THEN RETURN; END IF;
  v_pays    := v_data->'implantation'->>'country';
  v_plafond := public.fonds_plafond_stock_matiere(v_pays);
  -- DEFAUT DE JEU : 2. Il ne peut jamais depasser le plafond du pays, et il vaut
  -- 0 -- donc « refusee » -- dans un pays ou aucun plafond n'est arbitre, ce qui
  -- est exactement ce que l'apport y repond deja.
  v_defaut  := LEAST(2, coalesce(v_plafond, 0));

  RETURN QUERY
  WITH acces AS (
    SELECT DISTINCT m.key AS cle
      FROM public.fonds_generiques_accessibles(p_fonds_id) g
      JOIN LATERAL public.generique_recettes_systeme(g.generique_id) s ON true,
           jsonb_each(s.materiaux) m
  ), utilisees AS (
    SELECT DISTINCT m.key AS cle
      FROM jsonb_each(coalesce(v_data->'references', '{}'::jsonb)) e
      JOIN public.recettes_commerce rc ON rc.id = e.value->>'recette_id',
           jsonb_each(coalesce(rc.materiaux, '{}'::jsonb)) m
  )
  SELECT x.cle, x.stk, x.maxi, v_plafond,
         coalesce((v_data->'parametres'->'prixAchatMatiere'->>x.cle)::numeric,
                  (SELECT re.prix_achat_fournisseur FROM public.ressources_economie re
                    WHERE re.cle = x.cle)),
         GREATEST(0, x.maxi - x.stk)::integer,
         -- UNE SEULE GRANDEUR FAIT LOI. Le booleen n'est plus lu en base : il est
         -- rendu, pour que la garde de fonds_matiere_apporter reste inchangee.
         x.maxi > 0,
         EXISTS (SELECT 1 FROM utilisees u WHERE u.cle = x.cle)
    FROM (
      SELECT a.cle,
             GREATEST(0, coalesce((v_data->'stockMatieres'->>a.cle)::numeric, 0)) AS stk,
             LEAST(GREATEST(0, coalesce((v_data->'parametres'->'stockMaxMatieres'->>a.cle)::integer,
                                        v_defaut)),
                   coalesce(v_plafond, 0))::integer AS maxi
        FROM acces a
    ) x
   ORDER BY x.cle;
END; $fn$;

comment on function public.fonds_matieres_accessibles(text) is
  'Matieres qu''un fonds PJ PEUT manipuler, derivees de ses activites (typesAutorises -> generiques -> recettes -> materiaux), avec son stock, son stock maximum et son prix de rachat. LE MAXIMUM EST LA SEULE GRANDEUR : 0 signifie que le commerce refuse la matiere, un maximum non declare vaut 2, et le plafond du pays borne le tout. La colonne acceptee est CALCULEE (maximum > 0) et conservee pour la garde de fonds_matiere_apporter.';

revoke all on function public.fonds_matieres_accessibles(text) from public, anon, authenticated;
grant execute on function public.fonds_matieres_accessibles(text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. PARAMETRAGE D'UNE MATIERE — DEUX REGLAGES, PLUS TROIS
-- ---------------------------------------------------------------------------
-- LA SIGNATURE NE CHANGE PAS, et c'est deliberé : deux fonctions de meme nom
-- feraient repondre PostgREST par une ambiguite (300), et une signature de
-- moins ferait tomber tout client pas encore deploye. p_acceptee est donc
-- CONSERVE et IGNORE -- l'acceptation se deduit du maximum, et le miroir
-- matieresAcceptees est ecrit en consequence. Le jour ou plus aucun client
-- n'enverra ce parametre, on pourra le retirer d'un seul geste.
create or replace function public.fonds_matiere_parametres(
  p_acteur text, p_fonds_id text, p_matiere text,
  p_prix_achat numeric, p_maximum integer, p_acceptee boolean)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_data jsonb; v_pays text; v_plafond integer; v_par jsonb; v_mat text; v_ok boolean;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  v_mat := btrim(coalesce(p_matiere, ''));
  IF coalesce(p_fonds_id,'') = '' OR v_mat = '' THEN
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

  IF NOT EXISTS (SELECT 1 FROM public.fonds_matieres_accessibles(p_fonds_id) m
                  WHERE m.matiere = v_mat) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_hors_activites'); END IF;

  v_pays    := v_data->'implantation'->>'country';
  v_plafond := public.fonds_plafond_stock_matiere(v_pays);
  IF v_plafond IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_matiere_non_defini', 'pays', v_pays); END IF;

  IF p_prix_achat IS NULL OR p_prix_achat < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prix_invalide'); END IF;
  -- 0 = LE COMMERCE N'EN VEUT PAS. C'est desormais le seul sens de ce chiffre.
  IF p_maximum IS NULL OR p_maximum < 0 OR p_maximum > v_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'maximum_invalide',
                              'minimum', 0, 'maximum', v_plafond); END IF;

  v_ok := p_maximum > 0;

  v_par := coalesce(v_data->'parametres', '{}'::jsonb);
  v_par := jsonb_set(v_par, ARRAY['prixAchatMatiere'],
             jsonb_set(coalesce(v_par->'prixAchatMatiere','{}'::jsonb),
                       ARRAY[v_mat], to_jsonb(round(p_prix_achat, 2))), true);
  v_par := jsonb_set(v_par, ARRAY['stockMaxMatieres'],
             jsonb_set(coalesce(v_par->'stockMaxMatieres','{}'::jsonb),
                       ARRAY[v_mat], to_jsonb(p_maximum)), true);
  -- Miroir, pas source : il est ecrit pour rester coherent avec le maximum.
  v_par := jsonb_set(v_par, ARRAY['matieresAcceptees'],
             jsonb_set(coalesce(v_par->'matieresAcceptees','{}'::jsonb),
                       ARRAY[v_mat], to_jsonb(v_ok)), true);

  UPDATE public.entreprises
     SET data = jsonb_set(v_data, '{parametres}', v_par, true), updated_at = now()
   WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'matiere', v_mat,
                            'prixAchat', round(p_prix_achat, 2), 'maximum', p_maximum,
                            'acceptee', v_ok, 'plafondPays', v_plafond);
END; $fn$;

comment on function public.fonds_matiere_parametres(text,text,text,numeric,integer,boolean) is
  'Reglages d''une matiere pour un fonds PJ : prix de rachat libre et stock maximum (0 = le commerce n''en veut pas, borne par le plafond du pays). Le perimetre autorise est celui des ACTIVITES du commerce. p_acceptee est conserve pour la compatibilite de signature mais IGNORE : l''acceptation se deduit du maximum.';

revoke all on function public.fonds_matiere_parametres(text,text,text,numeric,integer,boolean) from public, anon, authenticated;
grant execute on function public.fonds_matiere_parametres(text,text,text,numeric,integer,boolean) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. CAISSE — APPORT ET PRELEVEMENT, EN NUMERAIRE ET SOUS IDENTITE
-- ---------------------------------------------------------------------------
-- Le corps garde sa forme d'origine. Trois choses changent, et seulement elles :
-- l'identite est exigee, le prefixe 'pj:' est tolere sur le proprietaire (les
-- fonds ecrits par C1 portent le nom nu, d'autres chemins le prefixent), et le
-- mouvement d'argent d'un PJ touche `arg` ET `liquide` au lieu de passer par
-- mouvement_titulaire. Une organisation proprietaire continue, elle, de passer
-- par mouvement_titulaire : elle n'a pas de colonne liquide.
create or replace function public.alimenter_caisse_fonds(
  p_acteur text, p_fonds_id text, p_montant integer)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  v_data    jsonb;
  v_m       integer := coalesce(p_montant, 0);
  v_proprio text;
  v_liquide numeric;
  v_caisse  numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_acteur,'') = '' OR coalesce(p_fonds_id,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF v_m <= 0 OR v_m IS DISTINCT FROM p_montant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;

  -- Le fonds est verrouille AVANT le patrimoine, comme au retrait : c'est la
  -- ligne sur laquelle deux mouvements concurrents doivent se serialiser.
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds'); END IF;
  IF coalesce(v_data->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;

  v_proprio := v_data->>'proprietaire';
  IF v_proprio IS DISTINCT FROM p_acteur AND v_proprio IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;

  IF left(coalesce(v_proprio,''), 5) = 'orga:' THEN
    IF NOT public.mouvement_titulaire(v_proprio, -v_m) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
  ELSE
    -- UNE CAISSE CONTIENT DES ESPECES. On ne debite donc pas un solde bancaire :
    -- le liquide doit couvrir l'apport, sinon rien ne bouge et on le dit.
    SELECT coalesce(liquide, 0) INTO v_liquide
      FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
    IF v_liquide IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'proprietaire_absent'); END IF;
    IF v_liquide < v_m THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'liquide_insuffisant',
                                'liquide', v_liquide); END IF;
    UPDATE public.personnages_donnees
       SET arg     = coalesce(arg, 0)     - v_m,
           liquide = coalesce(liquide, 0) - v_m,
           updated_at = now()
     WHERE name = p_acteur;
  END IF;

  v_caisse := GREATEST(0, coalesce((v_data->>'caisse')::numeric, 0));
  UPDATE public.entreprises
     SET data = jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse + v_m)),
         updated_at = now()
   WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'montant', v_m, 'caisse', v_caisse + v_m);
END; $fn$;

comment on function public.alimenter_caisse_fonds(text,text,integer) is
  'Le proprietaire d''un fonds de commerce verse du NUMERAIRE dans sa caisse. Exige l''identite de l''acteur. Debite arg ET liquide (une caisse contient des especes : un solde bancaire n''est pas debitable par cette voie), ou la caisse de l''organisation proprietaire. Transfert reel, jamais une creation de monnaie.';

create or replace function public.retirer_caisse_fonds(
  p_acteur text, p_fonds_id text, p_montant integer)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  v_data    jsonb;
  v_caisse  integer;
  v_m       integer := coalesce(p_montant, 0);
  v_proprio text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_acteur,'') = '' OR coalesce(p_fonds_id,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF v_m <= 0 OR v_m IS DISTINCT FROM p_montant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds'); END IF;
  -- TANT QUE LE FONDS EST A LUI, IL EN DISPOSE : seul un fonds qui n'est plus
  -- exploite ferme cette porte. Frontiere inchangee depuis le socle.
  IF coalesce(v_data->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;

  v_proprio := v_data->>'proprietaire';
  IF v_proprio IS DISTINCT FROM p_acteur AND v_proprio IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;

  v_caisse := GREATEST(0, coalesce((v_data->>'caisse')::numeric, 0))::integer;
  IF v_m > v_caisse THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse); END IF;

  UPDATE public.entreprises
     SET data = jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse - v_m)),
         updated_at = now()
   WHERE id = p_fonds_id;

  IF left(coalesce(v_proprio,''), 5) = 'orga:' THEN
    IF NOT public.mouvement_titulaire(v_proprio, v_m) THEN
      RAISE EXCEPTION 'titulaire_introuvable'; END IF;
  ELSE
    -- Especes prises dans la caisse : les deux colonnes montent ensemble, sinon
    -- le proprietaire repartirait avec un argent qu'il ne pourrait pas depenser.
    UPDATE public.personnages_donnees
       SET arg     = coalesce(arg, 0)     + v_m,
           liquide = coalesce(liquide, 0) + v_m,
           updated_at = now()
     WHERE name = p_acteur;
    IF NOT FOUND THEN RAISE EXCEPTION 'titulaire_introuvable'; END IF;
  END IF;

  RETURN jsonb_build_object('ok', true, 'montant', v_m, 'caisse', v_caisse - v_m);
END; $fn$;

comment on function public.retirer_caisse_fonds(text,text,integer) is
  'Le proprietaire reprend du NUMERAIRE dans la caisse de son fonds. Exige l''identite de l''acteur. Credite arg ET liquide, ou la caisse de l''organisation proprietaire. Ce n''est pas un revenu : ce qui sort de la caisse entre dans le patrimoine, et rien d''autre.';

-- LES DEUX PORTES SORTENT DE `anon`. Le nom de l'acteur y etait cru sur parole :
-- exiger_acteur le verifie desormais, et la cle anonyme n'a plus rien a y faire.
revoke all on function public.alimenter_caisse_fonds(text,text,integer) from public, anon, authenticated;
grant execute on function public.alimenter_caisse_fonds(text,text,integer) to authenticated, service_role;

revoke all on function public.retirer_caisse_fonds(text,text,integer) from public, anon, authenticated;
grant execute on function public.retirer_caisse_fonds(text,text,integer) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. STOCK MAXIMUM D'UN ARTICLE — INCHANGE, ET C'EST VOULU
-- ---------------------------------------------------------------------------
-- fonds_reference_stock_max n'est pas touchee : la grandeur des produits finis
-- existe, elle est opposee a la production (le lot indivisible est refuse en
-- entier au-dela), et « 0 = non defini » y reste son sens. Confondre les deux
-- echelles -- matieres et articles -- est precisement le defaut du moteur
-- legacy que C6 avait pris soin de ne pas reproduire.
