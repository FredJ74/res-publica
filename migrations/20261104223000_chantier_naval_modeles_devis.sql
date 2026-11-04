-- Contrat 04/11/2026 : deux modèles validés pour Port-Sainte-Marie.
-- Catalogue et devis purement informatifs : PAS de fabrication ni paiement.
CREATE TABLE IF NOT EXISTS public.chantier_naval_modeles (
  code text PRIMARY KEY,
  jours integer NOT NULL CHECK (jours IN (7,10)),
  passagers integer NOT NULL CHECK (passagers BETWEEN 1 AND 20),
  capacite_fret integer NOT NULL CHECK (capacite_fret > 0),
  prix_total_fr integer NOT NULL CHECK (prix_total_fr > 0),
  bois integer NOT NULL CHECK (bois > 0),
  metal integer NOT NULL CHECK (metal > 0),
  derives_petrochimiques integer NOT NULL CHECK (derives_petrochimiques > 0),
  CONSTRAINT chantier_naval_modeles_code CHECK (code IN ('bateau_3','bateau_5'))
);
INSERT INTO public.chantier_naval_modeles
  (code,jours,passagers,capacite_fret,prix_total_fr,bois,metal,derives_petrochimiques)
VALUES
  ('bateau_3',7,3,300,90000,1200,1200,600),
  ('bateau_5',10,5,500,150000,1800,1800,600)
ON CONFLICT (code) DO UPDATE SET
  jours=EXCLUDED.jours,
  passagers=EXCLUDED.passagers,
  capacite_fret=EXCLUDED.capacite_fret,
  prix_total_fr=EXCLUDED.prix_total_fr,
  bois=EXCLUDED.bois,
  metal=EXCLUDED.metal,
  derives_petrochimiques=EXCLUDED.derives_petrochimiques;

INSERT INTO public.ordres_couts (fn,pa,cost) VALUES ('consulter_devis_chantier_naval',0,0) ON CONFLICT DO NOTHING;

ALTER TABLE public.chantier_naval_modeles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.chantier_naval_modeles FROM public,anon,authenticated;

-- Lecture ponctuelle depuis le bureau du chantier naval, sans image ou liste PJ.
-- Côté contrat, les stocks sont des disponibilités publiques à la date de lecture,
-- PAS des ressources appartenant au joueur ou réservées pour sa commande.
CREATE OR REPLACE FUNCTION public.chantier_naval_devis()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO public, pg_temp
AS $naval$
  WITH entrepot AS (
    SELECT coalesce(public.batiment_etat_lire(data)->'entrepot'->'stock','{}'::jsonb) AS stock
    FROM public.batiments_etat
    WHERE id='republic_ville_a_entrepot-logistique-psm'
    LIMIT 1
  ), x AS (
    SELECT m.*, coalesce(e.stock,'{}'::jsonb) AS stock
      FROM public.chantier_naval_modeles m
      LEFT JOIN entrepot e ON true
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'modele',x.code,'passagers',x.passagers,'fret',x.capacite_fret,
    'jours',x.jours,'prix_total_fr',x.prix_total_fr,
    'acompte',x.prix_total_fr*35/100, 'solde',x.prix_total_fr*65/100,
    'recette',jsonb_build_object('bois',x.bois,'metal',x.metal,'derives_petrochimiques',x.derives_petrochimiques),
    'entrepot_psm',jsonb_build_object(
      'bois',coalesce((x.stock->>'bois')::integer,0),
      'metal',coalesce((x.stock->>'metal')::integer,0),
      'derives_petrochimiques',coalesce((x.stock->>'derives_petrochimiques')::integer,0)),
    'manquant_psm',jsonb_build_object(
      'bois',greatest(0,x.bois-coalesce((x.stock->>'bois')::integer,0)),
      'metal',greatest(0,x.metal-coalesce((x.stock->>'metal')::integer,0)),
      'derives_petrochimiques',greatest(0,x.derives_petrochimiques-coalesce((x.stock->>'derives_petrochimiques')::integer,0))),
    'commande_disponible',true, 'fabrication_immediate',false,
    'raison','construction_progressive'
   ) ORDER BY x.passagers),'[]'::jsonb)
  FROM x
  WHERE auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.personnages_donnees p
      WHERE p.user_id = auth.uid()
        AND p.country='republic'
        AND p.current_city='ville_a'
        AND p.current_building='chantier-naval'
    );
$naval$;

REVOKE ALL ON FUNCTION public.chantier_naval_devis() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.chantier_naval_devis() TO authenticated;
