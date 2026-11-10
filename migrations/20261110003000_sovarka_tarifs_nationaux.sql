-- SOVARKA : PRIX COURANTS A L'ECHELLE DU PAYS (decision de Fred du 09/11/2026 au soir, reponse 6 ;
-- GAME-DESIGN-NOVOMIRSK.md, « Reponses de Fred »). Un PA y vaut moins : les prix de Republia sont
-- divises par 2,5 environ. Train 30, bus/taxi 60, soin 10, transfert en clinique 400, licence
-- sportive 60, chambre d'hotel 25, policiers 20 et 40 PSK par jour. Fred ajustera en jeu.
--
-- MECANISME. `ordres_couts` reste le tarif du socle (une ligne par ordre pour les tarifs que le
-- serveur lit lui-meme). La nouvelle table `ordres_couts_pays` porte le tarif NATIONAL d'un ordre
-- pour un pays : quand elle en a un pour le pays du joueur, c'est lui, et lui seul, qui vaut
-- (un joueur de Sovarka ne paie plus le prix de Republia, un joueur de Republia ne peut pas
-- payer le prix de Sovarka). Les cinq fonctions qui lisent un tarif sont raccordees par
-- remplacement cible de leur texte, verifie : aucun autre changement.
BEGIN;

CREATE TABLE IF NOT EXISTS public.ordres_couts_pays (
  fn   text NOT NULL,
  pays text NOT NULL,
  pa   integer NOT NULL CHECK (pa >= 0),
  cost integer NOT NULL CHECK (cost >= 0),
  PRIMARY KEY (fn, pays)
);
ALTER TABLE public.ordres_couts_pays ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ordres_couts_pays_lecture ON public.ordres_couts_pays;
CREATE POLICY ordres_couts_pays_lecture ON public.ordres_couts_pays FOR SELECT USING (true);
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.ordres_couts_pays FROM anon, authenticated;
GRANT SELECT ON public.ordres_couts_pays TO anon, authenticated;

INSERT INTO public.ordres_couts_pays (fn, pays, pa, cost) VALUES
  ('prendre_train',             'soviet', 2,  30),
  ('prendre_bus_taxi',          'soviet', 1,  60),
  ('soin_public',               'soviet', 0,  10),
  ('transfert_clinique_privee', 'soviet', 0, 400),
  ('prendre_licence_sportive',  'soviet', 1,  60),
  ('reserver_chambre_hotel',    'soviet', 0,  25)
ON CONFLICT (fn, pays) DO UPDATE SET pa = EXCLUDED.pa, cost = EXCLUDED.cost;

DO $raccord$
DECLARE d text; avant text; apres text;
BEGIN
  -- 1) payer_ordre_interne : un tarif national, quand il existe pour le pays du joueur, est le seul valable.
  d := pg_get_functiondef('public.payer_ordre_interne(text,text,integer,integer,integer)'::regprocedure);
  IF position('ordres_couts_pays' IN d) = 0 THEN
    avant := E'    INTO v_valide;\n  IF NOT v_valide AND NOT v_acquisition THEN';
    apres := E'    INTO v_valide;\n'
      || E'  -- sovarka_tarifs_nationaux_v1 : tarif national du pays du joueur, seul valable s''il existe.\n'
      || E'  IF EXISTS (SELECT 1 FROM public.ordres_couts_pays o JOIN public.personnages_donnees d\n'
      || E'               ON d.name = p_acteur AND d.country = o.pays WHERE o.fn = v_fn) THEN\n'
      || E'    v_valide := EXISTS (SELECT 1 FROM public.ordres_couts_pays o JOIN public.personnages_donnees d\n'
      || E'               ON d.name = p_acteur AND d.country = o.pays\n'
      || E'               WHERE o.fn = v_fn AND o.pa = coalesce(p_pa,0) AND o.cost = coalesce(p_cost,0));\n'
      || E'  END IF;\n'
      || E'  IF NOT v_valide AND NOT v_acquisition THEN';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'payer_ordre_interne : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;

  -- 2) transport_effectuer : train et bus/taxi au tarif du pays du voyageur.
  d := pg_get_functiondef('public.transport_effectuer(text,text,text,uuid)'::regprocedure);
  IF position('ordres_couts_pays' IN d) = 0 THEN
    avant := E' r:=public.payer_ordre_interne(moi,tarif.fn,tarif.pa,tarif.cost,cardinality(ids)+cardinality(pnjs));';
    apres := E' -- sovarka_tarifs_nationaux_v1\n'
      || E' IF EXISTS(SELECT 1 FROM public.ordres_couts_pays o WHERE o.fn=tarif.fn AND o.pays=p.country) THEN\n'
      || E'  tarif.pa:=(SELECT o.pa FROM public.ordres_couts_pays o WHERE o.fn=tarif.fn AND o.pays=p.country);\n'
      || E'  tarif.cost:=(SELECT o.cost FROM public.ordres_couts_pays o WHERE o.fn=tarif.fn AND o.pays=p.country);\n'
      || E' END IF;\n' || avant;
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'transport_effectuer : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;

  -- 3) recevoir_soin : le soin public au tarif du pays du dispensaire.
  d := pg_get_functiondef('public.recevoir_soin(text,text,text,text,text,integer)'::regprocedure);
  IF position('ordres_couts_pays' IN d) = 0 THEN
    avant := E'  IF NOT EXISTS (SELECT 1 FROM public.ordres_couts\n                 WHERE fn = CASE WHEN p_type=''public'' THEN ''soin_public'' ELSE ''soins'' END\n                   AND cost = coalesce(p_cout,0)) THEN';
    apres := E'  IF CASE WHEN EXISTS (SELECT 1 FROM public.ordres_couts_pays o WHERE o.pays = p_pays\n'
      || E'                AND o.fn = CASE WHEN p_type=''public'' THEN ''soin_public'' ELSE ''soins'' END)\n'
      || E'      THEN NOT EXISTS (SELECT 1 FROM public.ordres_couts_pays o WHERE o.pays = p_pays  -- sovarka_tarifs_nationaux_v1\n'
      || E'                AND o.fn = CASE WHEN p_type=''public'' THEN ''soin_public'' ELSE ''soins'' END AND o.cost = coalesce(p_cout,0))\n'
      || E'      ELSE NOT EXISTS (SELECT 1 FROM public.ordres_couts\n                 WHERE fn = CASE WHEN p_type=''public'' THEN ''soin_public'' ELSE ''soins'' END\n                   AND cost = coalesce(p_cout,0)) END THEN';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'recevoir_soin : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;

  -- 4) Transfert en clinique : au tarif du pays du patient.
  d := pg_get_functiondef('public.hospitalisation_lieu_rejoindre_interne(text,text,text,boolean,boolean)'::regprocedure);
  IF position('ordres_couts_pays' IN d) = 0 THEN
    avant := E'   ORDER BY cost DESC LIMIT 1;\n';
    apres := avant
      || E'  -- sovarka_tarifs_nationaux_v1\n'
      || E'  SELECT coalesce((SELECT o.pa FROM public.ordres_couts_pays o WHERE o.fn = ''transfert_clinique_privee'' AND o.pays = p.country), v_pa),\n'
      || E'         coalesce((SELECT o.cost FROM public.ordres_couts_pays o WHERE o.fn = ''transfert_clinique_privee'' AND o.pays = p.country), v_cost)\n'
      || E'    INTO v_pa, v_cost;\n';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'hospitalisation : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;

  -- 5) Entretien des policiers : 20 et 40 PSK par jour en Sovarka.
  d := pg_get_functiondef('public.police_payer_effectifs(text)'::regprocedure);
  IF position('sovarka_tarifs_nationaux_v1' IN d) = 0 THEN
    avant := E'  c_standard  constant integer := 50;\n  c_cynophile constant integer := 100;';
    apres := E'  -- sovarka_tarifs_nationaux_v1\n'
      || E'  c_standard  constant integer := CASE WHEN p_pays = ''soviet'' THEN 20 ELSE 50 END;\n'
      || E'  c_cynophile constant integer := CASE WHEN p_pays = ''soviet'' THEN 40 ELSE 100 END;';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'police_payer_effectifs : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;
END
$raccord$;

-- Preuves structurelles : les cinq fonctions portent le raccord, la table ses six tarifs.
DO $$
BEGIN
  IF (SELECT count(*) FROM public.ordres_couts_pays WHERE pays = 'soviet') <> 6
     OR position('ordres_couts_pays' IN pg_get_functiondef('public.payer_ordre_interne(text,text,integer,integer,integer)'::regprocedure)) = 0
     OR position('ordres_couts_pays' IN pg_get_functiondef('public.transport_effectuer(text,text,text,uuid)'::regprocedure)) = 0
     OR position('ordres_couts_pays' IN pg_get_functiondef('public.recevoir_soin(text,text,text,text,text,integer)'::regprocedure)) = 0
     OR position('ordres_couts_pays' IN pg_get_functiondef('public.hospitalisation_lieu_rejoindre_interne(text,text,text,boolean,boolean)'::regprocedure)) = 0
     OR position('sovarka_tarifs_nationaux_v1' IN pg_get_functiondef('public.police_payer_effectifs(text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'sovarka_tarifs_nationaux_incomplet';
  END IF;
END $$;

COMMIT;
