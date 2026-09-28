-- ===========================================================================
-- C6 bis — LE COMMERCE PJ DEVIENT UN LIEU DE TRAVAIL
-- 29 septembre 2026
-- ===========================================================================
--
-- CE QUE CE LOT CORRIGE, APRES LE TEST HUMAIN D'ARNIE.
--
--   1. LES MATIERES PARAMETRABLES etaient deduites des REFERENCES DEJA CREEES.
--      Un proprietaire ne pouvait donc pas preparer son approvisionnement avant
--      d'avoir cree ses produits -- l'ordre exact inverse de celui dans lequel
--      on monte un commerce. Elles se deduisent desormais des ACTIVITES.
--
--   2. UN VISITEUR NE POUVAIT PAS PRODUIRE. C'est pourtant deja la boucle des
--      13 commerces PNJ du jeu : le visiteur apporte ses PA, l'etablissement
--      fournit ses matieres et paie le travail. On ouvre la meme porte, sans
--      inventer un second moteur.
--
--   3. « MAXIMUM = 0 » PORTAIT DEUX SENS. Il voulait dire « illimite », et rien
--      ne permettait de dire « je ne veux pas de cette matiere ». Un booleen
--      explicite prend cette charge, et 0 ne signifie plus jamais qu'une chose.
--
-- CE QU'ON NE REFAIT PAS. Le CMUP, la fiscalite, le plafond de prix, la
-- presence physique, l'idempotence, le journal des apports et des productions :
-- tout cela existe et fonctionne. On s'y raccorde.
--
-- AUCUNE NOUVELLE CAISSE, AUCUN NOUVEAU STOCK, AUCUN NOUVEAU JOURNAL.

-- ---------------------------------------------------------------------------
-- 1. LIBELLE DE FORME — DISTINGUER L'OBJET DE SON HISTOIRE
-- ---------------------------------------------------------------------------
-- `tshirt_psm` s'appelle « T-shirt de Port-Sainte-Marie ». C'est juste au marche
-- de Port-Sainte-Marie, ou cette recette est nee. C'est faux dans la boutique
-- d'Arnie a Luthecia : le joueur y choisit une FORME -- un t-shirt -- qu'il
-- nommera ensuite comme il l'entend.
--
-- LA SOLUTION LA MOINS INTRUSIVE. On n'ecrase aucun libelle historique et on ne
-- renomme aucun identifiant : on AJOUTE une colonne, nulle partout sauf la ou
-- une forme neutre a ete validee. Le moteur legacy continue de lire `label` et
-- ne voit strictement rien. Seule generique_recettes_systeme -- appelee par le
-- seul C6, verifie -- prefere la forme quand elle existe.
alter table public.recettes_commerce add column if not exists label_forme text;

comment on column public.recettes_commerce.label_forme is
  'Nom de la FORME fabriquee, neutre sur le plan narratif et commercial, affiche par C6 quand un joueur choisit comment fabriquer sa reference. NULL = on garde le libelle historique. Le moteur legacy ne lit jamais cette colonne.';

-- LES SEPT FORMES ARBITREES. Un nom de FABRICATION, neutre sur le plan narratif et
-- commercial : le sujet du produit appartient a la reference du joueur, jamais a la
-- recette technique.
update public.recettes_commerce set label_forme = 'T-shirt'           where id = 'tshirt_psm';
update public.recettes_commerce set label_forme = 'Casquette'         where id = 'casquette_montrouge';
update public.recettes_commerce set label_forme = 'Écharpe'           where id = 'echarpe_luthecia';
update public.recettes_commerce set label_forme = 'Porte-clé'         where id = 'porte_cle_palais_luthecia';
update public.recettes_commerce set label_forme = 'Figurine'          where id = 'figurine_maxence_monfils';
-- « Figurine en plomb » et non « Figurine » : deux formes distinctes du meme
-- generique doivent rester distinguables, sans imposer le sujet du produit final.
update public.recettes_commerce set label_forme = 'Figurine en plomb' where id = 'garde_republien_plomb';

-- CARTE POSTALE — UNE SEULE DES NEUF PORTE LA FORME.
--
-- Les neuf recettes historiques sont RIGOUREUSEMENT identiques : 1 bois, 1 PA,
-- 16 unites. Elles ne different que par leur sujet narratif, qui en C6 appartient a
-- la reference du joueur. Neuf formes « Carte postale » identiques dans l'ecran de
-- choix seraient un defaut pire que celui qu'on corrige.
--
-- POURQUOI CELLE-LA. Aucun champ ne designe structurellement une representante : ni
-- les villes, ni les batiments, ni les materiaux ne les separent. Le seul critere
-- objectif trouve dans les donnees est qu'une seule des neuf a REELLEMENT ete
-- produite en jeu -- elle figure dans le `stockProduits` d'un marche. C'est donc la
-- seule eprouvee de bout en bout par le moteur (recette lue, matieres consommees,
-- cout de revient etabli, prix pose). On prefere une recette qui a tourne a une
-- recette jamais executee. Le choix n'a par ailleurs AUCUNE consequence observable :
-- les neuf sont identiques, et C6 n'affiche jamais que « Carte postale ».
update public.recettes_commerce set label_forme = 'Carte postale'
 where id = 'carte_luthecia_institutions';

-- GARANTIE STRUCTURELLE. Un generique ne peut pas offrir deux formes homonymes.
-- C'est la contrainte qui empeche le defaut de revenir par une erreur de saisie --
-- plutot qu'un dedoublonnage silencieux a la lecture, qui la masquerait.
create unique index if not exists recettes_commerce_forme_unique
  on public.recettes_commerce (generique_id, label_forme)
  where label_forme is not null;

-- C6 NE PROPOSE QUE LES FORMES DECLAREES.
-- La regle : des qu'une recette du generique declare une forme, seules celles qui en
-- declarent une sont proposees. Sinon -- generique pas encore arbitre -- toutes le
-- sont, exactement comme avant. Les huit autres cartes postales restent donc en base,
-- intactes et lisibles par le legacy, simplement absentes du parcours de creation C6.
create or replace function public.generique_recettes_systeme(p_generique_id text)
returns table(recette_id text, label text, pa integer, portions integer, materiaux jsonb)
language sql
stable
as $fn$
  with toutes as (
    select r.id, r.label, r.label_forme, r.pa, r.portions,
           coalesce(r.materiaux, '{}'::jsonb) as materiaux
      from public.recettes_commerce r
     where r.generique_id = p_generique_id
  ), arbitre as (
    select exists (select 1 from toutes where nullif(btrim(label_forme), '') is not null) as oui
  )
  select t.id, coalesce(nullif(btrim(t.label_forme), ''), t.label),
         t.pa, t.portions, t.materiaux
    from toutes t, arbitre a
   where NOT a.oui OR nullif(btrim(t.label_forme), '') is not null
   order by t.id;
$fn$;

comment on function public.generique_recettes_systeme(text) is
  'Formes de fabrication qu''un joueur peut choisir pour une reference PJ. Rend le libelle de FORME (label_forme) quand il existe, sinon le libelle historique. Des qu''une recette du generique declare une forme, seules les recettes qui en declarent une sont proposees : plusieurs recettes historiques de meme fabrication ne produisent donc plus plusieurs choix identiques. Le moteur legacy ne lit jamais cette fonction et voit toujours les 9 cartes postales.';

-- ---------------------------------------------------------------------------
-- 2. MATIERES ACCESSIBLES — DERIVEES DES ACTIVITES, PAS DES REFERENCES
-- ---------------------------------------------------------------------------
-- LA CHAINE EXISTAIT DEJA ENTIEREMENT, en deux fonctions qui ne s'etaient
-- jamais parle :
--   typesAutorises -> fonds_generiques_accessibles -> generique_recettes_systeme
--                  -> recettes_commerce.materiaux
-- On les compose. Aucune liste de matieres n'est ecrite nulle part, ni ici ni
-- dans l'interface : ajouter une recette demain suffit a faire apparaitre sa
-- matiere chez tous les commerces dont l'activite la rend fabricable.
--
-- `acceptee` est un CHOIX DU PROPRIETAIRE, jamais une deduction. Une matiere
-- que ses activites rendent accessible reste fermee tant qu'il ne l'ouvre pas.
-- `utilisee` dit si l'une de ses references la consomme reellement : c'est une
-- INDICATION pour lui, jamais une regle.
create or replace function public.fonds_matieres_accessibles(p_fonds_id text)
returns table(matiere text, stock numeric, maximum integer, plafond_pays integer,
              prix_achat numeric, place_restante integer, acceptee boolean, utilisee boolean)
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_data jsonb; v_pays text; v_plafond integer;
BEGIN
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id;
  IF v_data IS NULL OR coalesce((v_data->>'version')::numeric, 0) < 2 THEN RETURN; END IF;
  v_pays    := v_data->'implantation'->>'country';
  v_plafond := public.fonds_plafond_stock_matiere(v_pays);

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
         -- Place restante : un maximum nul veut dire ILLIMITE, la place l'est donc
         -- aussi. On rend le plafond du pays, qui borne de toute facon le stock.
         CASE WHEN x.maxi = 0 THEN GREATEST(0, coalesce(v_plafond, 0) - x.stk)::integer
              ELSE GREATEST(0, x.maxi - x.stk)::integer END,
         coalesce((v_data->'parametres'->'matieresAcceptees'->>x.cle)::boolean, false),
         EXISTS (SELECT 1 FROM utilisees u WHERE u.cle = x.cle)
    FROM (
      SELECT a.cle,
             GREATEST(0, coalesce((v_data->'stockMatieres'->>a.cle)::numeric, 0)) AS stk,
             -- 0 = illimite : on ne le remplace surtout pas par le plafond ici,
             -- sinon l'interface afficherait « 20 » la ou le joueur a choisi 0.
             GREATEST(0, coalesce((v_data->'parametres'->'stockMaxMatieres'->>a.cle)::integer, 0))::integer AS maxi
        FROM acces a
    ) x
   ORDER BY x.cle;
END; $fn$;

comment on function public.fonds_matieres_accessibles(text) is
  'Matieres qu''un fonds PJ PEUT manipuler, derivees de ses activites (typesAutorises -> generiques -> recettes -> materiaux), avec son stock, son maximum (0 = illimite), son prix de rachat, et le booleen d''acceptation choisi par le proprietaire. Remplace fonds_matieres_recherchees comme source de l''ecran de gestion et comme garde des apports.';

revoke all on function public.fonds_matieres_accessibles(text) from public, anon, authenticated;
grant execute on function public.fonds_matieres_accessibles(text) to authenticated, service_role;

-- fonds_matieres_recherchees N'EST PAS SUPPRIMEE : elle repond a une autre
-- question -- « quelles matieres mes references consomment-elles reellement ? »
-- -- qui reste utile et qui alimente la colonne `utilisee` ci-dessus. Elle
-- cesse simplement d'etre le gardien de ce qu'on peut parametrer ou apporter.

-- ---------------------------------------------------------------------------
-- 3. REPRISE DE L'EXISTANT — AUCUN COMMERCE NE DOIT SE FERMER TOUT SEUL
-- ---------------------------------------------------------------------------
-- Introduire un booleen qui vaut `false` par defaut FERMERAIT du jour au
-- lendemain les matieres qu'un proprietaire avait deja ouvertes. On reprend donc
-- explicitement l'existant : toute matiere qu'il avait DEJA parametree (prix ou
-- maximum), ou dont il detient deja du stock, est declaree acceptee.
--
-- C'est la lecture la plus conservatrice possible : elle n'ouvre rien qui ne
-- l'etait, elle ne ferme rien qui l'etait, et elle ne touche aucun stock.
update public.entreprises e
   set data = jsonb_set(e.data, '{parametres,matieresAcceptees}',
         coalesce(e.data->'parametres'->'matieresAcceptees', '{}'::jsonb) ||
         coalesce((
           SELECT jsonb_object_agg(cle, true) FROM (
             SELECT key AS cle FROM jsonb_each(coalesce(e.data->'parametres'->'stockMaxMatieres','{}'::jsonb))
             UNION
             SELECT key FROM jsonb_each(coalesce(e.data->'parametres'->'prixAchatMatiere','{}'::jsonb))
             UNION
             SELECT key FROM jsonb_each(coalesce(e.data->'stockMatieres','{}'::jsonb))
              WHERE (value#>>'{}')::numeric > 0
           ) t), '{}'::jsonb), true),
       updated_at = now()
 where coalesce((e.data->>'version')::numeric, 0) >= 2;

-- ---------------------------------------------------------------------------
-- 4. PARAMETRAGE D'UNE MATIERE — TROIS REGLAGES, UNE SEULE PORTE
-- ---------------------------------------------------------------------------
-- L'ancienne signature a 5 arguments est SUPPRIMEE, pas surchargee : deux
-- fonctions de meme nom feraient repondre PostgREST par une ambiguite (300), et
-- un client a jour ne doit jamais pouvoir toucher l'ancienne porte.
drop function if exists public.fonds_matiere_parametres(text, text, text, numeric, integer);

create or replace function public.fonds_matiere_parametres(
  p_acteur text, p_fonds_id text, p_matiere text,
  p_prix_achat numeric, p_maximum integer, p_acceptee boolean)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_data jsonb; v_pays text; v_plafond integer; v_par jsonb; v_mat text;
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

  -- PERIMETRE ELARGI : on parametre desormais ce que les ACTIVITES rendent
  -- accessible, et non plus seulement ce que les references consomment deja.
  -- C'est tout l'objet de ce lot.
  IF NOT EXISTS (SELECT 1 FROM public.fonds_matieres_accessibles(p_fonds_id) m
                  WHERE m.matiere = v_mat) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_hors_activites'); END IF;

  v_pays    := v_data->'implantation'->>'country';
  v_plafond := public.fonds_plafond_stock_matiere(v_pays);
  IF v_plafond IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_matiere_non_defini', 'pays', v_pays); END IF;

  IF p_prix_achat IS NULL OR p_prix_achat < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prix_invalide'); END IF;
  -- 0 = ILLIMITE, et c'est le seul sens que ce chiffre porte desormais : le refus
  -- d'une matiere se dit par `acceptee`, jamais par un maximum a zero.
  IF p_maximum IS NULL OR p_maximum < 0 OR p_maximum > v_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'maximum_invalide',
                              'minimum', 0, 'maximum', v_plafond); END IF;

  v_par := coalesce(v_data->'parametres', '{}'::jsonb);
  v_par := jsonb_set(v_par, ARRAY['prixAchatMatiere'],
             jsonb_set(coalesce(v_par->'prixAchatMatiere','{}'::jsonb),
                       ARRAY[v_mat], to_jsonb(round(p_prix_achat, 2))), true);
  v_par := jsonb_set(v_par, ARRAY['stockMaxMatieres'],
             jsonb_set(coalesce(v_par->'stockMaxMatieres','{}'::jsonb),
                       ARRAY[v_mat], to_jsonb(p_maximum)), true);
  v_par := jsonb_set(v_par, ARRAY['matieresAcceptees'],
             jsonb_set(coalesce(v_par->'matieresAcceptees','{}'::jsonb),
                       ARRAY[v_mat], to_jsonb(coalesce(p_acceptee, false))), true);

  UPDATE public.entreprises
     SET data = jsonb_set(v_data, '{parametres}', v_par, true), updated_at = now()
   WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'matiere', v_mat,
                            'prixAchat', round(p_prix_achat, 2), 'maximum', p_maximum,
                            'acceptee', coalesce(p_acceptee, false),
                            'illimite', p_maximum = 0, 'plafondPays', v_plafond);
END; $fn$;

comment on function public.fonds_matiere_parametres(text,text,text,numeric,integer,boolean) is
  'Reglages d''une matiere pour un fonds PJ : prix de rachat libre, stock maximum (0 = illimite, borne par le plafond du pays) et acceptation explicite. Le perimetre autorise est celui des ACTIVITES du commerce, pas celui de ses references.';

revoke all on function public.fonds_matiere_parametres(text,text,text,numeric,integer,boolean) from public, anon, authenticated;
grant execute on function public.fonds_matiere_parametres(text,text,text,numeric,integer,boolean) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. APPORT DE MATIERE — LE PERIMETRE SUIT LES ACTIVITES, ET L'ACCEPTATION FAIT LOI
-- ---------------------------------------------------------------------------
-- Trois changements, et rien d'autre : la source du perimetre, la garde
-- d'acceptation, et la place restante quand le maximum est illimite. Tout le
-- reste du corps -- bornage, CMUP, inventaire, caisse, journal, idempotence --
-- est repris a l'identique.
--
-- UNE MATIERE REFUSEE EST REFUSEE PARTOUT. Ne pas l'afficher ne suffit pas :
-- c'est ici, au seul endroit qui ecrit, que le refus doit tenir.
create or replace function public.fonds_matiere_apporter(
  p_requete text, p_acteur text, p_fonds_id text,
  p_matiere text, p_qte integer, p_mode text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
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
  v_sm jsonb; v_cmm jsonb; v_inv_apres jsonb; v_reste integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  IF p_requete IS NULL OR p_requete !~ '^appro-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  IF v_mode NOT IN ('vente', 'don') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mode_invalide'); END IF;
  IF coalesce(p_fonds_id,'') = '' OR v_mat = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF v_veut <= 0 OR v_veut IS DISTINCT FROM p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;

  SELECT * INTO v_deja FROM public.apports_matieres WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'quantite', v_deja.quantite, 'prixUnitaire', v_deja.prix_unitaire,
                              'montant', v_deja.montant, 'mode', v_deja.mode);
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF coalesce(v_data->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;

  IF NOT public.fonds_acteur_present(p_acteur, v_data->'implantation') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;

  -- PERIMETRE : les activites du commerce, plus la decision de son proprietaire.
  SELECT * INTO v_m FROM public.fonds_matieres_accessibles(p_fonds_id) m WHERE m.matiere = v_mat;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_hors_activites', 'matiere', v_mat); END IF;
  IF NOT v_m.acceptee THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_non_acceptee', 'matiere', v_mat); END IF;
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

  v_payable := CASE WHEN v_prix <= 0 THEN v_veut ELSE floor(v_caisse / v_prix)::integer END;
  v_qte := LEAST(v_veut, floor(v_detenu)::integer, v_capacite, v_payable);

  IF v_qte <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante',
                              'caisse', v_caisse, 'prixUnitaire', v_prix); END IF;

  v_montant := round(v_prix * v_qte, 2);

  -- LE VENDEUR EST PAYE EN ESPECES, SUR PLACE. mouvement_titulaire ne touche que
  -- `arg` sans `liquide` : l'invariant arg = liquide + banques serait rompu et le
  -- vendeur repartirait avec un argent qu'il ne pourrait pas depenser. On credite
  -- donc les deux. Correction LOCALE et deliberee, conservee telle quelle ; la
  -- dette generale de mouvement_titulaire reste hors de ce lot.
  IF v_montant > 0 THEN
    UPDATE public.personnages_donnees
       SET arg     = COALESCE(arg, 0)     + v_montant,
           liquide = COALESCE(liquide, 0) + v_montant,
           updated_at = now()
     WHERE name = p_acteur;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'vendeur_introuvable'); END IF;
  END IF;

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

  -- Place restante : un maximum nul est ILLIMITE, la borne est alors celle du pays.
  v_reste := CASE WHEN v_m.maximum = 0
                  THEN GREATEST(0, coalesce(v_m.plafond_pays, 0) - (v_stock + v_qte))::integer
                  ELSE GREATEST(0, v_m.maximum - (v_stock + v_qte))::integer END;

  RETURN jsonb_build_object('ok', true, 'mode', v_mode, 'matiere', v_mat,
    'quantite', v_qte, 'demandee', v_veut, 'prixUnitaire', v_prix, 'montant', v_montant,
    'stock', v_stock + v_qte, 'maximum', v_m.maximum, 'illimite', v_m.maximum = 0,
    'placeRestante', v_reste,
    'coutMoyen', v_nouveau, 'caisse', v_caisse - v_montant, 'inventory', v_inv_apres);
END; $fn$;

comment on function public.fonds_matiere_apporter(text, text, text, text, integer, text) is
  'Apport d''une matiere premiere a un fonds PJ, par vente (prix fixe par le proprietaire) ou par don. Exige la presence physique ET que le proprietaire ait explicitement ACCEPTE cette matiere. Perimetre derive des activites du commerce. Borne la quantite par la possession reelle, la place restante et la caisse. Met a jour le CMUP. Idempotente par cle de requete.';

revoke all on function public.fonds_matiere_apporter(text, text, text, text, integer, text) from public, anon, authenticated;
grant execute on function public.fonds_matiere_apporter(text, text, text, text, integer, text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 6. PRODUCTION — LE COMMERCE DEVIENT UN LIEU DE TRAVAIL
-- ---------------------------------------------------------------------------
-- TROIS CHANGEMENTS, ET LA MEME RPC POUR TOUT LE MONDE.
--
--   a) LE VERROU DE PROPRIETE DISPARAIT. C'est deja la regle des 13 commerces
--      PNJ du jeu : n'importe quel PJ present produit. Le proprietaire garde ses
--      deux portes -- sa gestion et la face publique -- vers cette seule
--      fonction : aucune logique economique n'est dupliquee.
--
--   b) LA PRESENCE PHYSIQUE LE REMPLACE. Elle ne servait a rien tant que seul le
--      proprietaire produisait ; elle devient la garde principale des qu'un
--      inconnu peut travailler ici. Meme predicat que l'achat et l'apport.
--
--   c) LE TRAVAIL EST PAYE. 50 FR par PA reellement depense, pris sur la caisse
--      du commerce. Ce n'est PAS un nouveau tarif : c'est la constante
--      `cout_main_oeuvre_pa_alimentaire` que cette fonction lisait DEJA pour
--      valoriser la main-d'oeuvre dans le cout de revient. La caisse verse donc
--      exactement ce que la comptabilite du lot enregistre -- le salaire et le
--      cout de revient ne peuvent pas diverger, puisqu'ils sont le meme nombre.
--
-- REFUS GLOBAL, TOUJOURS AVANT LA PREMIERE ECRITURE. PA manquants, matieres
-- manquantes, stock maximum atteint, caisse incapable de payer le salaire : dans
-- les quatre cas rien n'est consomme, rien n'est produit, rien n'est verse.
create or replace function public.fonds_reference_produire(
  p_requete text, p_acteur text, p_fonds_id text, p_reference_id text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
DECLARE
  v_max_ref integer;
  v_data jsonb; v_ref jsonb; v_r record; v_gen record;
  v_sm jsonb; v_couts jsonb; v_m text; v_q jsonb;
  v_besoin numeric; v_dispo numeric; v_cm numeric;
  v_mat numeric := 0; v_pa_val numeric; v_pa_requis integer;
  v_nom_pj text; v_pa integer; v_manque jsonb := '[]'::jsonb;
  v_stock_avant integer; v_quantite integer; v_cout_lot numeric; v_unit numeric;
  v_cmup_avant numeric; v_cmup_apres numeric;
  v_deja record; v_salaire numeric; v_caisse numeric; v_jour integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_requete IS NULL OR p_requete !~ '^prod-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;
  IF coalesce(p_fonds_id,'') = '' OR coalesce(p_reference_id,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  v_nom_pj := CASE WHEN left(p_acteur,3) = 'pj:' THEN substr(p_acteur,4) ELSE p_acteur END;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF coalesce(v_data->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;

  -- ON NE TRAVAILLE QUE LA OU L'ON SE TIENT. Remplace le verrou de propriete.
  IF NOT public.fonds_acteur_present(v_nom_pj, v_data->'implantation') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;

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

  SELECT coalesce(pa, 0), coalesce(day, 1) INTO v_pa, v_jour
    FROM public.personnages_donnees WHERE name = v_nom_pj FOR UPDATE;
  IF v_pa IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_pa_requis := greatest(0, coalesce(v_r.pa, 0));
  IF v_pa < v_pa_requis THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants',
                              'requis', v_pa_requis, 'disponibles', v_pa); END IF;

  -- LE MEME NOMBRE SERT DEUX FOIS : valorisation de la main-d'oeuvre dans le
  -- cout de revient, et salaire reellement verse au producteur.
  SELECT valeur::numeric INTO v_pa_val FROM public.entreprises_constantes
   WHERE cle = 'cout_main_oeuvre_pa_alimentaire';
  IF v_pa_val IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'valeur_pa_non_declaree'); END IF;
  v_salaire := round(v_pa_requis * v_pa_val, 2);

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

  -- STOCK MAXIMUM DE L'ARTICLE. Le rendement d'une recette est officiel et
  -- INDIVISIBLE : on ne fabrique pas « juste ce qui rentre », sinon le rendement
  -- annonce au joueur cesserait d'etre vrai. Si le lot complet ferait depasser le
  -- maximum choisi par le proprietaire, on refuse le lot ENTIER -- et on rend les
  -- trois chiffres qui permettent de le comprendre.
  -- Un maximum absent ou NUL signifie « pas de limite ».
  v_max_ref := nullif((v_data->'parametres'->'stockMaxReferences'->>p_reference_id)::integer, 0);
  IF v_max_ref IS NOT NULL
     AND greatest(0, coalesce((v_data->'stockReferences'->>p_reference_id)::numeric, 0))::integer
         + v_r.portions > v_max_ref THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_max_reference_depasse',
      'stock', greatest(0, coalesce((v_data->'stockReferences'->>p_reference_id)::numeric, 0))::integer,
      'rendement', v_r.portions, 'maximum', v_max_ref);
  END IF;

  -- LA CAISSE DOIT POUVOIR PAYER LE LOT ENTIER. Dernier refus avant la premiere
  -- ecriture : pas de paiement partiel, pas de production a credit.
  v_caisse := GREATEST(0, coalesce((v_data->>'caisse')::numeric, 0));
  IF v_caisse < v_salaire THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante',
                              'caisse', v_caisse, 'salaire', v_salaire);
  END IF;

  -- ===== A PARTIR D'ICI, ET SEULEMENT ICI, ON ECRIT =====
  FOR v_m, v_q IN SELECT key, value FROM jsonb_each(coalesce(v_r.materiaux, '{}'::jsonb)) LOOP
    v_sm := jsonb_set(v_sm, ARRAY[v_m],
              to_jsonb(coalesce((v_sm->>v_m)::numeric, 0) - (v_q#>>'{}')::numeric));
  END LOOP;

  v_quantite    := v_r.portions;
  v_stock_avant := greatest(0, coalesce((v_data->'stockReferences'->>p_reference_id)::numeric, 0))::integer;
  v_cout_lot    := v_mat + v_pa_requis * v_pa_val;
  v_unit        := v_cout_lot / v_quantite;

  -- CMUP DU PRODUIT FINI : moyenne ponderee de l'ancien stock et du nouveau lot.
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
  v_data := v_data || jsonb_build_object('caisse', v_caisse - v_salaire);
  v_data := public.entreprise_ajouter_historique(v_data, -v_salaire,
              'Production de ' || coalesce(v_ref->>'nom', p_reference_id)
              || ' (' || v_quantite || ' unites) — ' || v_nom_pj, v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;

  -- LE PRODUCTEUR : ses PA partent, son salaire arrive. Credite en `arg` ET en
  -- `liquide`, pour la meme raison que l'apport de matiere -- il est paye en
  -- especes, sur place, et doit pouvoir depenser ce qu'il gagne.
  UPDATE public.personnages_donnees
     SET pa      = v_pa - v_pa_requis,
         arg     = COALESCE(arg, 0)     + v_salaire,
         liquide = COALESCE(liquide, 0) + v_salaire,
         updated_at = now()
   WHERE name = v_nom_pj;

  INSERT INTO public.productions_references
    (requete, fonds_id, reference_id, generique_id, recette_id, acteur,
     quantite, pa, matieres, cout_matieres, cout_lot, cout_unitaire)
  VALUES (p_requete, p_fonds_id, p_reference_id, v_r.generique_id, v_r.id, p_acteur,
     v_quantite, v_pa_requis, coalesce(v_r.materiaux, '{}'::jsonb), v_mat, v_cout_lot, v_unit);

  RETURN jsonb_build_object('ok', true, 'rejeu', false,
    'referenceId', p_reference_id, 'recette', v_r.id, 'generique', v_r.generique_id,
    'quantite', v_quantite, 'stockAvant', v_stock_avant, 'stockApres', v_stock_avant + v_quantite,
    'paPreleves', v_pa_requis, 'paRestants', v_pa - v_pa_requis,
    'salaire', v_salaire, 'caisse', v_caisse - v_salaire,
    'coutMatieres', v_mat, 'coutLot', v_cout_lot, 'coutUnitaireLot', v_unit,
    'cmupAvant', v_cmup_avant, 'cmupApres', v_cmup_apres,
    'matieresConsommees', coalesce(v_r.materiaux, '{}'::jsonb));
END; $fn$;

comment on function public.fonds_reference_produire(text,text,text,text) is
  'Fabrique un lot d''une reference PJ. Ouverte a TOUT joueur physiquement present : le commerce fournit ses matieres et paie 50 FR par PA depense, le producteur fournit ses PA, le produit va au stock du commerce. Rendement indivisible : PA manquants, matieres manquantes, stock maximum atteint ou caisse incapable de payer le salaire refusent le lot entier avant la premiere ecriture. Idempotente par cle de requete.';

revoke all on function public.fonds_reference_produire(text,text,text,text) from public, anon, authenticated;
grant execute on function public.fonds_reference_produire(text,text,text,text) to authenticated, service_role;
