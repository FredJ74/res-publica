-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261023072924.
-- Archivage documentaire seulement ; ne pas rejouer.
-- #96. La preuve de vente existante EST l'evenement : pas de second moteur de vente.
-- Aucune reprise inventee des enseignes ou proprietaires des ventes historiques.
BEGIN;
ALTER TABLE public.ventes_snapshots ADD COLUMN IF NOT EXISTS journal_titulaire uuid;
ALTER TABLE public.ventes_snapshots ADD COLUMN IF NOT EXISTS journal_enseigne text;
CREATE INDEX IF NOT EXISTS ventes_journal_titulaire ON public.ventes_snapshots(journal_titulaire,vendu_le,id);
CREATE TABLE IF NOT EXISTS public.journal_ventes_lectures(
 titulaire uuid NOT NULL,vente uuid NOT NULL REFERENCES public.ventes_snapshots(id),lu_le timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(titulaire,vente));
ALTER TABLE public.journal_ventes_lectures ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.journal_ventes_lectures FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.vente_journal_preparer()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE fonds jsonb; proprio text;
BEGIN
 SELECT data INTO fonds FROM public.entreprises WHERE id=NEW.fonds_id;
 proprio:=regexp_replace(coalesce(fonds->>'proprietaire',''),'^pj:','');
 -- Seuls les vrais titulaires PJ au moment de la transaction ont un journal personnel.
 NEW.journal_titulaire:=NULL;NEW.journal_enseigne:=NULL;
 IF proprio IS DISTINCT FROM regexp_replace(coalesce(NEW.vendeur,''),'^pj:','') THEN
  -- Un journal facultatif ne doit JAMAIS annuler une vente ni son paiement.
  -- Aucun titulaire de notification n'est designe si les identites divergent.
  RETURN NEW;
 END IF;
 SELECT id INTO NEW.journal_titulaire FROM public.personnages_donnees WHERE name=proprio;
 IF NEW.journal_titulaire IS NOT NULL THEN NEW.journal_enseigne:=coalesce(nullif(fonds->>'enseigne',''),'Commerce');END IF;
 RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION public.vente_journal_preparer() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS vente_journal_snapshot ON public.ventes_snapshots;
CREATE TRIGGER vente_journal_snapshot BEFORE INSERT ON public.ventes_snapshots FOR EACH ROW EXECUTE FUNCTION public.vente_journal_preparer();
CREATE OR REPLACE FUNCTION public.journal_ventes_lire(p_acquitter boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE moi text:=public.mon_personnage();v_titulaire uuid;identifiants uuid[];evenements jsonb;restantes integer;
BEGIN
 IF moi IS NULL THEN RAISE EXCEPTION 'acteur_non_authentifie' USING ERRCODE='42501';END IF;
 SELECT id INTO v_titulaire FROM public.personnages_donnees WHERE name=moi AND user_id=auth.uid();
 IF v_titulaire IS NULL THEN RAISE EXCEPTION 'personnage_non_possede' USING ERRCODE='42501';END IF;
 -- Toutes les ventes restent consultables ; les recus de lecture ne changent jamais la preuve.
 SELECT array_agg(v.id ORDER BY v.vendu_le DESC,v.id),coalesce(jsonb_agg(jsonb_build_object(
  'id',v.id,'ts',v.vendu_le,'acheteur',v.acheteur,'enseigne',v.journal_enseigne,'article',v.nom_commercial,
  'quantite',v.quantite,'prixUnitaire',v.prix_unitaire,'montant',v.montant_total,
  'nonLu',NOT EXISTS(SELECT 1 FROM public.journal_ventes_lectures l WHERE l.titulaire=v_titulaire AND l.vente=v.id))
  ORDER BY v.vendu_le DESC,v.id),'[]'::jsonb)
 INTO identifiants,evenements FROM public.ventes_snapshots v WHERE v.journal_titulaire=v_titulaire;
 IF p_acquitter THEN
  INSERT INTO public.journal_ventes_lectures(titulaire,vente) SELECT v_titulaire,x FROM unnest(identifiants) x ON CONFLICT DO NOTHING;
 END IF;
 SELECT count(*) INTO restantes FROM public.ventes_snapshots v WHERE v.journal_titulaire=v_titulaire
 AND NOT EXISTS(SELECT 1 FROM public.journal_ventes_lectures l WHERE l.titulaire=v_titulaire AND l.vente=v.id);
 RETURN jsonb_build_object('ok',true,'evenements',evenements,'nonLues',restantes);
END $f$;
REVOKE ALL ON FUNCTION public.journal_ventes_lire(boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.journal_ventes_lire(boolean) TO authenticated;
COMMIT;
