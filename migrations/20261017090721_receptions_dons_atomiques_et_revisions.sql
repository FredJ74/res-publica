-- NON DEPLOYEE. Depend de 20261017090342. Aucun raccordement partiel en production.
BEGIN;
DO $definitions_preparees$
DECLARE r record; p pg_proc%rowtype;
BEGIN
 FOR r IN SELECT * FROM (VALUES ('hg_fin_revision()','84136e597ca59fecf0ee6a3ea808b9d6'),
('hg_fin_etat(text)','564fb7824872946e33f2286a06f64fd7'),
('hg_fin_dons_recevoir(uuid,text,jsonb)','bda01a34e6a43db3dd1e2803b159bc83')) t(signature,empreinte) LOOP
  SELECT * INTO p FROM pg_proc WHERE oid=to_regprocedure('public.'||r.signature);
  IF FOUND AND (md5(p.prosrc)<>r.empreinte OR p.proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp']) THEN
   RAISE EXCEPTION 'definition financiere preexistante non examinee : %',r.signature;
  END IF;
 END LOOP;
END;
$definitions_preparees$;
ALTER TABLE public.personnages_donnees ADD COLUMN IF NOT EXISTS revision_financiere bigint NOT NULL DEFAULT 0;
CREATE OR REPLACE FUNCTION public.hg_fin_revision() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
BEGIN
 IF (NEW.arg,NEW.liquide,NEW.banque) IS DISTINCT FROM (OLD.arg,OLD.liquide,OLD.banque) THEN
  NEW.revision_financiere:=OLD.revision_financiere+1;
 ELSE NEW.revision_financiere:=OLD.revision_financiere; END IF;
 RETURN NEW;
END;
$function$;
DROP TRIGGER IF EXISTS hg_fin_revision ON public.personnages_donnees;
CREATE TRIGGER hg_fin_revision BEFORE UPDATE ON public.personnages_donnees
FOR EACH ROW EXECUTE FUNCTION public.hg_fin_revision();

CREATE TABLE IF NOT EXISTS public.hg_fin_requetes (
 utilisateur uuid NOT NULL,
 requete uuid NOT NULL,
 personnage text NOT NULL,
 corps jsonb NOT NULL,
 resultat jsonb NOT NULL,
 cree_le timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(utilisateur,requete)
);
COMMENT ON TABLE public.hg_fin_requetes IS 'HG recus financiers prives v1';
ALTER TABLE public.hg_fin_requetes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.hg_fin_requetes FROM PUBLIC,anon,authenticated;
-- Les recus ne sont jamais modifiables par le navigateur, meme celui du proprietaire.
CREATE OR REPLACE FUNCTION public.hg_fin_etat(p_personnage text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE p public.personnages_donnees%rowtype; v jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'authentification_requise' USING ERRCODE='42501'; END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=p_personnage AND user_id=auth.uid() FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'personnage_non_possede' USING ERRCODE='42501'; END IF;
 -- Une seule photographie SQL pour les comptes; aucun delta financier cote client.
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'banque',banque,'pays',pays,'solde',public.hg_fr_texte(solde)) ORDER BY id),'[]') INTO v
 FROM public.comptes_bancaires WHERE personnage=p.name;
 RETURN jsonb_build_object('version',2,'personnage',p.name,'revision',p.revision_financiere::text,
   'arg',public.hg_fr_texte(p.arg),'liquide',public.hg_fr_texte(p.liquide),'banque',public.hg_fr_texte(p.banque),'comptes',v);
END;
$function$;
CREATE OR REPLACE FUNCTION public.hg_fin_dons_recevoir(p_requete uuid,p_personnage text,p_dons jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE v_etat jsonb; v_corps jsonb; v_recu public.hg_fin_requetes%rowtype;
 v_don record; v_total numeric:=0; v_nombre integer:=0; v_id bigint; v_ids bigint[];
BEGIN
 IF p_requete IS NULL THEN RAISE EXCEPTION 'requete_requise' USING ERRCODE='22023'; END IF;
 -- Le verrou du personnage serialise les onglets avant les dons et le recu.
 v_etat:=public.hg_fin_etat(p_personnage);
 IF p_dons IS NULL OR jsonb_typeof(p_dons)<>'array' OR jsonb_array_length(p_dons)>200 THEN
  RAISE EXCEPTION 'liste_dons_invalide' USING ERRCODE='22023';
 END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_dons) e WHERE jsonb_typeof(e)<>'string' OR e#>>'{}' !~ '^[1-9][0-9]*$') THEN
  RAISE EXCEPTION 'identifiant_don_invalide' USING ERRCODE='22023';
 END IF;
 SELECT array_agg(DISTINCT x ORDER BY x) INTO v_ids FROM
  (SELECT (e#>>'{}')::bigint x FROM jsonb_array_elements(p_dons) e) s;
 v_corps:=jsonb_build_object('operation','dons_recevoir','personnage',p_personnage,'dons',coalesce(to_jsonb(v_ids),'[]'));
 -- Une meme cle de requete ne peut changer ni d'acteur ni de corps.
 PERFORM pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_requete::text,0));
 SELECT * INTO v_recu FROM public.hg_fin_requetes WHERE utilisateur=auth.uid() AND requete=p_requete;
 IF FOUND THEN
  IF v_recu.corps IS DISTINCT FROM v_corps THEN RAISE EXCEPTION 'requete_reutilisee' USING ERRCODE='22023'; END IF;
  RETURN jsonb_build_object('ok',true,'resultat',v_recu.resultat,'etat',public.hg_fin_etat(p_personnage),'rejeu',true);
 END IF;
 -- Refus integral d'une liste qui contient un don inexistant ou non possede.
 IF EXISTS(SELECT 1 FROM unnest(v_ids) x WHERE NOT EXISTS(
   SELECT 1 FROM public.dons_en_attente d WHERE d.id=x AND d.destinataire=p_personnage)) THEN
  RAISE EXCEPTION 'don_non_possede' USING ERRCODE='42501';
 END IF;
 FOR v_don IN SELECT * FROM public.dons_en_attente
  WHERE id=ANY(v_ids) AND destinataire=p_personnage ORDER BY id FOR UPDATE
 LOOP
  IF v_don.montant IS NULL OR v_don.montant<=0 THEN RAISE EXCEPTION 'don_montant_invalide'; END IF;
  IF coalesce(v_don.traite,false)=false THEN
   v_total:=v_total+v_don.montant;v_nombre:=v_nombre+1;
   UPDATE public.dons_en_attente SET traite=true WHERE id=v_don.id;
  END IF;
 END LOOP;
 -- Allocation historique conservee : la reception ancienne incrementait arg seul.
 UPDATE public.personnages_donnees SET arg=coalesce(arg,0)+v_total WHERE name=p_personnage AND v_total<>0;
 IF (SELECT arg FROM public.personnages_donnees WHERE name=p_personnage)
  IS DISTINCT FROM coalesce((v_etat->>'arg')::numeric,0)+v_total THEN
  RAISE EXCEPTION 'don_credit_non_applique';
 END IF;
 INSERT INTO public.hg_fin_requetes(utilisateur,requete,personnage,corps,resultat)
 VALUES(auth.uid(),p_requete,p_personnage,v_corps,jsonb_build_object('montant',public.hg_fr_texte(v_total),'nombre',v_nombre));
 RETURN jsonb_build_object('ok',true,'resultat',jsonb_build_object('montant',public.hg_fr_texte(v_total),'nombre',v_nombre),
   'etat',public.hg_fin_etat(p_personnage),'rejeu',false);
END;
$function$;
REVOKE ALL ON FUNCTION public.hg_fin_revision(),public.hg_fin_etat(text),public.hg_fin_dons_recevoir(uuid,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.hg_fin_etat(text),public.hg_fin_dons_recevoir(uuid,text,jsonb) TO authenticated;
-- Retrait de l'ancien marquage qui pouvait supprimer le droit au don avant le credit.
-- La suppression d'un don non traite est egalement fermee; le nettoyage passe au serveur.
REVOKE UPDATE,DELETE ON public.dons_en_attente FROM PUBLIC,anon,authenticated;
DO $droits$
BEGIN
 IF EXISTS(SELECT 1 FROM information_schema.column_privileges WHERE table_schema='public' AND table_name='dons_en_attente'
  AND grantee IN ('PUBLIC','anon','authenticated') AND privilege_type IN ('UPDATE','INSERT')) THEN
  RAISE EXCEPTION 'dons: droits residuels par colonne a examiner';
 END IF;
END;
$droits$;
COMMIT;
