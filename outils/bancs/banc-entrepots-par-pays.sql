-- Banc annule : migration 20261104230000_entrepots_par_pays + parcours. Doit finir sur 'BANC ...' (exception = rien ne reste).
-- Attendu (04/11/2026) : republic=(capitale,entrepot-logistique-luthecia) | soviet=(capitale,entrepot-logistique-novomirsk) | narco=- | dir_rep=republic_capitale_... | dir_sov=soviet_capitale_entrepot-logistique-novomirsk | republic_en_dur=0
BEGIN;
-- Entrepots logistiques : le pays entre dans la cle (socle, avant les autres empires).
-- Jusqu'ici `entrepots_par_ville` n'avait que (ville, building_id) : 'capitale' designait
-- l'entrepot de Luthecia pour tous les pays. Un entrepot a Novomirsk (soviet, capitale)
-- aurait ete confondu avec celui de Luthecia par les huit fonctions qui lisent la table.
-- Idempotente : rejouee, elle ne change rien (chaque patch verifie son propre etat).

ALTER TABLE public.entrepots_par_ville ADD COLUMN IF NOT EXISTS pays text;
UPDATE public.entrepots_par_ville SET pays = 'republic' WHERE pays IS NULL;
ALTER TABLE public.entrepots_par_ville ALTER COLUMN pays SET NOT NULL;

DO $cle$
BEGIN
  IF (SELECT array_agg(a.attname::text ORDER BY a.attname)
        FROM pg_constraint c JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)
       WHERE c.conname = 'entrepots_par_ville_pkey') IS DISTINCT FROM ARRAY['pays','ville'] THEN
    ALTER TABLE public.entrepots_par_ville DROP CONSTRAINT IF EXISTS entrepots_par_ville_pkey;
    ALTER TABLE public.entrepots_par_ville ADD CONSTRAINT entrepots_par_ville_pkey PRIMARY KEY (pays, ville);
  END IF;
END $cle$;

-- Patch en place : chaque fragment doit etre trouve, sauf si la fonction porte deja le nouveau.
CREATE OR REPLACE FUNCTION pg_temp.patcher(p_fn regprocedure, p_ancien text, p_nouveau text)
RETURNS void LANGUAGE plpgsql AS $p$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef(p_fn);
  IF position(p_nouveau IN v_def) > 0 THEN RETURN; END IF;
  v_new := replace(v_def, p_ancien, p_nouveau);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch non applique sur % : fragment absent', p_fn; END IF;
  EXECUTE v_new;
END $p$;

SELECT pg_temp.patcher('public.chantier_jour_traiter(text)'::regprocedure,
  $a$FROM public.entrepots_par_ville WHERE ville=etat->>'city';$a$,
  $n$FROM public.entrepots_par_ville WHERE pays=r.country AND ville=etat->>'city';$n$);

SELECT pg_temp.patcher('public.chantier_commande(text,text,text,jsonb)'::regprocedure,
  $a$FROM public.entrepots_par_ville WHERE ville=etat->>'city';$a$,
  $n$FROM public.entrepots_par_ville WHERE pays=t.country AND ville=etat->>'city';$n$);

SELECT pg_temp.patcher('public.trading_livraison_entrepot_interne(text,text,text)'::regprocedure,
  $a$FROM public.entrepots_par_ville ep
   ORDER BY$a$,
  $n$FROM public.entrepots_par_ville ep
   WHERE ep.pays = p_pays
   ORDER BY$n$);

SELECT pg_temp.patcher('public.trading_acheter(text,text,text,integer,text)'::regprocedure,
  $a$WHERE m.country || '_' || ep.ville || '_' || ep.building_id = p_entrepot;$a$,
  $n$WHERE ep.pays = m.country AND m.country || '_' || ep.ville || '_' || ep.building_id = p_entrepot;$n$);

-- Le pays de l'entrepot du directeur est celui du directeur, jamais celui que l'ecran transmet.
SELECT pg_temp.patcher('public.fixer_prix_entrepot(text,text,jsonb)'::regprocedure,
  $a$SELECT building_id INTO v_bat FROM public.entrepots_par_ville WHERE ville = v_ville;$a$,
  $n$SELECT e.building_id, e.pays INTO v_bat, p_pays FROM public.entrepots_par_ville e
    JOIN public.personnages_donnees pd ON pd.name = p_acteur AND pd.country = e.pays
   WHERE e.ville = v_ville;$n$);

SELECT pg_temp.patcher('public.entrepot_du_directeur(text)'::regprocedure,
  $a$SELECT 'republic_' || e.ville || '_' || e.building_id, e.ville, e.building_id
    FROM public.personnages_donnees p
    JOIN public.entrepots_par_ville e ON e.ville = p.poste->>'city'$a$,
  $n$SELECT e.pays || '_' || e.ville || '_' || e.building_id, e.ville, e.building_id
    FROM public.personnages_donnees p
    JOIN public.entrepots_par_ville e ON e.pays = p.country AND e.ville = p.poste->>'city'$n$);

SELECT pg_temp.patcher('public.trading_cours()'::regprocedure,
  $a$FROM public.entrepots_par_ville ep
        CROSS JOIN LATERAL$a$,
  $n$FROM public.entrepots_par_ville ep
        CROSS JOIN LATERAL (SELECT 1 WHERE ep.pays = v_pays) filtre_pays
        CROSS JOIN LATERAL$n$);

SELECT pg_temp.patcher('public.offres_achat_lire()'::regprocedure,
  $a$WHERE o.pays || '_' || ep.ville$a$,
  $n$WHERE ep.pays = o.pays AND o.pays || '_' || ep.ville$n$);

-- Commandes entre entrepots : l'embargo se juge depuis le pays de l'entrepot qui commande,
-- et un entrepot ne s'approvisionne aupres d'un autre entrepot que dans son propre pays
-- (l'international passe par les fournisseurs etrangers). Le produit d'une vente du port va a
-- la caisse de CE port, et non plus toujours a celle de Port-Sainte-Marie.
SELECT pg_temp.patcher('public.entrepot_commander(text,text,integer,text,text)'::regprocedure,
  $a$IF public.embargo_actif('republic', p_fournisseur_id) THEN$a$,
  $n$IF public.embargo_actif(split_part(v_dest_id, '_', 1), p_fournisseur_id) THEN$n$);

SELECT pg_temp.patcher('public.entrepot_commander(text,text,integer,text,text)'::regprocedure,
  $a$    RETURN jsonb_build_object('ok', false, 'raison', 'fournisseur_est_soi_meme');
  END IF;$a$,
  $n$    RETURN jsonb_build_object('ok', false, 'raison', 'fournisseur_est_soi_meme');
  END IF;
  IF p_fournisseur_type IN ('entrepot', 'port') AND split_part(p_fournisseur_id, '_', 1) <> split_part(v_dest_id, '_', 1) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fournisseur_autre_pays');
  END IF;$n$);

SELECT pg_temp.patcher('public.entrepot_commander(text,text,integer,text,text)'::regprocedure,
  $a$PERFORM public.caisse_institution_mouvement('republic_port-sainte-marie',$a$,
  $n$PERFORM public.caisse_institution_mouvement((SELECT b.country || '_' || b.building_id FROM public.batiments_etat b WHERE b.id = p_fournisseur_id),$n$);
INSERT INTO public.entrepots_par_ville(pays, ville, building_id) VALUES ('soviet','capitale','entrepot-logistique-novomirsk') ON CONFLICT DO NOTHING;
DO $b$
DECLARE v text := ''; v_dir text;
BEGIN
  v := v || 'republic=' || coalesce((SELECT string_agg(x::text, ',') FROM public.trading_livraison_entrepot_interne('republic','','zz') x),'-');
  v := v || ' | soviet=' || coalesce((SELECT string_agg(x::text, ',') FROM public.trading_livraison_entrepot_interne('soviet','','zz') x),'-');
  v := v || ' | narco=' || coalesce((SELECT string_agg(x::text, ',') FROM public.trading_livraison_entrepot_interne('narco','','zz') x),'-');
  SELECT name INTO v_dir FROM public.personnages_donnees WHERE country='republic' LIMIT 1;
  UPDATE public.personnages_donnees SET poste = jsonb_build_object('id','directeur_entrepot','city','capitale') WHERE name = v_dir;
  v := v || ' | dir_rep=' || coalesce((SELECT entrepot_id FROM public.entrepot_du_directeur(v_dir)),'-');
  UPDATE public.personnages_donnees SET country = 'soviet' WHERE name = v_dir;
  v := v || ' | dir_sov=' || coalesce((SELECT entrepot_id FROM public.entrepot_du_directeur(v_dir)),'-');
  v := v || ' | republic_en_dur=' || (SELECT count(*) FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname IN ('entrepot_du_directeur','entrepot_commander') AND prosrc ~ '''republic');
  RAISE EXCEPTION 'BANC %', v;
END $b$;
ROLLBACK;
