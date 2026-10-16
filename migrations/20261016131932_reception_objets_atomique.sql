-- PREPARATION UNIQUEMENT : NE PAS APPLIQUER EN PRODUCTION DANS CETTE MISSION.
-- Preflight catalogue/RLS/PostgREST et revue des ecrivains requis ; aucun acte metier ici.
DO $versions$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('public.inventaire_revision_garder()','b5a289fa6f6a6bab6b8cd9bddfc4f86d'),
    ('public.inventaire_reception_etat(text)','9b24e1da4500bd7b2711d028f1358fe3'),
    ('public.inventaire_sauver_revision(text,bigint,jsonb)','29f14a3dcf61822af6baf74b3e220330'),
    ('public.inventaire_reclamer_livraison(text,text,uuid,bigint)','951585fb6bcb1e80bf6affa2fc5a6d8a')
  ) x(signature,empreinte) LOOP
    IF to_regprocedure(r.signature) IS NOT NULL AND NOT EXISTS
      (SELECT 1 FROM pg_proc WHERE oid=to_regprocedure(r.signature)
       AND md5(prosrc)=r.empreinte AND prosecdef AND proconfig=ARRAY['search_path=public, pg_temp']) THEN
      RAISE EXCEPTION 'reception_definition_inconnue: %',r.signature;
    END IF;
  END LOOP;
  IF to_regclass('public.inventaire_livraisons_recues') IS NOT NULL
     AND obj_description(to_regclass('public.inventaire_livraisons_recues'),'pg_class')
       IS DISTINCT FROM 'HG reception atomique v1' THEN
    RAISE EXCEPTION 'reception_registre_inconnu';
  END IF;
  IF to_regclass('public.inventaire_livraisons_recues') IS NOT NULL AND
    (SELECT count(*) FROM pg_attribute WHERE attrelid=to_regclass('public.inventaire_livraisons_recues')
      AND attnum>0 AND NOT attisdropped) <> 4 THEN
    RAISE EXCEPTION 'reception_registre_schema_inconnu';
  END IF;
  IF to_regclass('public.inventaire_livraisons_recues') IS NOT NULL THEN
    FOR r IN SELECT * FROM (VALUES ('jeton','uuid'),('id','text'),('destinataire','text'),
      ('recue_le','timestamptz')) x(colonne,ty) LOOP
      IF NOT EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid=to_regclass('public.inventaire_livraisons_recues')
        AND attname=r.colonne AND atttypid=r.ty::regtype AND attnotnull AND NOT attisdropped) THEN
        RAISE EXCEPTION 'reception_registre_schema_inconnu';
      END IF;
    END LOOP;
  END IF;
END;
$versions$;

DO $schema$
DECLARE v record;
BEGIN
  IF (SELECT relkind FROM pg_class WHERE oid=to_regclass('public.personnages_donnees')) <> 'r'
     OR (SELECT relkind FROM pg_class WHERE oid=to_regclass('public.personnages')) <> 'v'
     OR NOT coalesce((SELECT relrowsecurity FROM pg_class WHERE oid=to_regclass('public.objets_recus')),false) THEN
    RAISE EXCEPTION 'reception_schema_a_reexaminer';
  END IF;
  FOR v IN SELECT * FROM (VALUES
    ('personnages_donnees','name','text'),('personnages_donnees','user_id','uuid'),
    ('personnages_donnees','inventory','jsonb'),('objets_recus','id','text'),
    ('objets_recus','destinataire','text'),('objets_recus','data','jsonb')) x(t,c,ty)
  LOOP
    IF NOT EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid=to_regclass('public.'||v.t)
      AND attname=v.c AND atttypid=v.ty::regtype AND NOT attisdropped) THEN
      RAISE EXCEPTION 'reception_colonne_incompatible: %.%',v.t,v.c;
    END IF;
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM pg_index WHERE indrelid='public.personnages_donnees'::regclass
    AND indisunique AND indisvalid AND indpred IS NULL AND indnkeyatts=1
    AND indkey[0]=(SELECT attnum FROM pg_attribute WHERE attrelid=indrelid AND attname='name'))
    OR NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.objets_recus'::regclass
    AND contype='p' AND conkey=ARRAY[(SELECT attnum FROM pg_attribute WHERE attrelid=conrelid AND attname='id')]) THEN
    RAISE EXCEPTION 'reception_unicites_a_reexaminer';
  END IF;
  IF EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid='public.personnages_donnees'::regclass
    AND attname='inventory_revision' AND NOT attisdropped)
    AND col_description('public.personnages_donnees'::regclass,
      (SELECT attnum FROM pg_attribute WHERE attrelid='public.personnages_donnees'::regclass AND attname='inventory_revision'))
      IS DISTINCT FROM 'HG reception atomique v1' THEN
    RAISE EXCEPTION 'reception_revision_inconnue';
  END IF;
  IF EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid='public.personnages_donnees'::regclass
    AND attname='inventory_revision' AND NOT attisdropped AND (atttypid<>'bigint'::regtype OR NOT attnotnull)) THEN
    RAISE EXCEPTION 'reception_revision_schema_inconnu';
  END IF;
  IF EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid='public.objets_recus'::regclass
    AND attname='reception_token' AND NOT attisdropped
    AND (atttypid<>'uuid'::regtype OR NOT attnotnull
      OR col_description(attrelid,attnum) IS DISTINCT FROM 'HG reception atomique v1')) THEN
    RAISE EXCEPTION 'reception_jeton_schema_inconnu';
  END IF;
  -- Le gardien doit etre le dernier BEFORE UPDATE ; aucun declencheur inconnu apres lui.
  IF EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.personnages_donnees'::regclass
    AND NOT tgisinternal AND tgenabled<>'D' AND tgtype & 2=2 AND tgtype & 16=16
    AND tgname>'zzzz_hg_inventory_revision') THEN
    RAISE EXCEPTION 'reception_ordre_triggers_a_reexaminer';
  END IF;
  IF EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.personnages_donnees'::regclass
    AND tgname='zzzz_hg_inventory_revision' AND (tgtype<>19 OR tgenabled<>'O'
      OR tgfoid IS DISTINCT FROM to_regprocedure('public.inventaire_revision_garder()'))) THEN
    RAISE EXCEPTION 'reception_trigger_inconnu';
  END IF;
END;
$schema$;

ALTER TABLE public.objets_recus ADD COLUMN IF NOT EXISTS reception_token uuid NOT NULL DEFAULT gen_random_uuid();
COMMENT ON COLUMN public.objets_recus.reception_token IS 'HG reception atomique v1';
CREATE UNIQUE INDEX IF NOT EXISTS objets_recus_reception_token_uidx ON public.objets_recus(reception_token);
ALTER TABLE public.personnages_donnees ADD COLUMN IF NOT EXISTS inventory_revision bigint NOT NULL DEFAULT 0;
COMMENT ON COLUMN public.personnages_donnees.inventory_revision IS 'HG reception atomique v1';
CREATE TABLE IF NOT EXISTS public.inventaire_livraisons_recues (
  jeton uuid PRIMARY KEY, id text NOT NULL, destinataire text NOT NULL, recue_le timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.inventaire_livraisons_recues IS 'HG reception atomique v1';
ALTER TABLE public.inventaire_livraisons_recues ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.inventaire_livraisons_recues FROM PUBLIC,anon,authenticated;

-- Les chemins PostgREST sont des GUC du serveur, pas des entetes fournis par le joueur.
-- Sans contexte RPC fiable pour un role client, aucun remplacement d'inventaire n'est permis.
CREATE OR REPLACE FUNCTION public.inventaire_revision_garder() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
BEGIN
  IF coalesce(nullif(current_setting('role',true),'none'),session_user) IN ('anon','authenticated')
     AND coalesce(current_setting('request.path',true),'') NOT LIKE '/rpc/%' THEN
    NEW.inventory := OLD.inventory;
  END IF;
  NEW.inventory_revision := OLD.inventory_revision
    + CASE WHEN NEW.inventory IS DISTINCT FROM OLD.inventory THEN 1 ELSE 0 END;
  RETURN NEW;
END;
$function$;
DROP TRIGGER IF EXISTS zzzz_hg_inventory_revision ON public.personnages_donnees;
CREATE TRIGGER zzzz_hg_inventory_revision BEFORE UPDATE ON public.personnages_donnees
 FOR EACH ROW EXECUTE FUNCTION public.inventaire_revision_garder();
REVOKE ALL ON FUNCTION public.inventaire_revision_garder() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.inventaire_reception_etat(p_acteur text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE v public.personnages_donnees%rowtype;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'acteur_non_authentifie' USING ERRCODE='42501'; END IF;
  PERFORM public.exiger_acteur(p_acteur);
  SELECT * INTO v FROM public.personnages_donnees WHERE name=p_acteur FOR UPDATE;
  IF NOT FOUND OR v.user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'personnage_non_possede' USING ERRCODE='42501';
  END IF;
  IF jsonb_typeof(v.inventory) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'inventaire_format_a_reexaminer';
  END IF;
  RETURN jsonb_build_object('ok',true,'contrat',1,'inventory',v.inventory,'revision',v.inventory_revision);
END;
$function$;

-- Sauvegarde ciblee des ajouts legacy, sous la meme revision que la reception.
CREATE OR REPLACE FUNCTION public.inventaire_sauver_revision(p_acteur text,p_revision bigint,p_inventory jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE v public.personnages_donnees%rowtype;
BEGIN
  PERFORM public.inventaire_reception_etat(p_acteur); -- autorite + verrou personnage d'abord
  SELECT * INTO v FROM public.personnages_donnees WHERE name=p_acteur;
  IF jsonb_typeof(p_inventory) IS DISTINCT FROM 'array' THEN
    RETURN jsonb_build_object('ok',false,'raison','inventaire_invalide');
  END IF;
  -- Aucun rebasage d'un snapshot different. Un etat deja exact ne reecrit rien.
  IF p_inventory IS DISTINCT FROM v.inventory THEN
    IF p_revision IS DISTINCT FROM v.inventory_revision THEN
      RETURN jsonb_build_object('ok',false,'raison','inventaire_perime','revision',v.inventory_revision);
    END IF;
    UPDATE public.personnages_donnees SET inventory=p_inventory WHERE name=p_acteur
      RETURNING * INTO v;
    IF v.inventory IS DISTINCT FROM p_inventory OR v.inventory_revision IS DISTINCT FROM p_revision+1 THEN
      RAISE EXCEPTION 'inventaire_ecriture_non_appliquee';
    END IF;
  END IF;
  RETURN jsonb_build_object('ok',true,'contrat',1,'inventory',v.inventory,'revision',v.inventory_revision);
END;
$function$;

CREATE OR REPLACE FUNCTION public.inventaire_reclamer_livraison(p_acteur text,p_id text,p_jeton uuid,p_revision bigint) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE
  v public.personnages_donnees%rowtype; l public.objets_recus%rowtype;
  o jsonb; inv jsonb; e jsonb; pos integer := -1; i integer := 0; q numeric;
BEGIN
  PERFORM public.inventaire_reception_etat(p_acteur);
  SELECT * INTO v FROM public.personnages_donnees WHERE name=p_acteur;
  IF EXISTS(SELECT 1 FROM public.inventaire_livraisons_recues WHERE jeton=p_jeton AND id=p_id AND destinataire=p_acteur) THEN
    RETURN jsonb_build_object('ok',true,'contrat',1,'rejeu',true,'inventory',v.inventory,'revision',v.inventory_revision);
  END IF;
  SELECT * INTO l FROM public.objets_recus WHERE id=p_id AND reception_token=p_jeton FOR UPDATE;
  IF NOT FOUND OR l.destinataire IS DISTINCT FROM p_acteur THEN
    RETURN jsonb_build_object('ok',false,'raison','livraison_absente');
  END IF;
  IF p_revision IS DISTINCT FROM v.inventory_revision THEN
    RETURN jsonb_build_object('ok',false,'raison','inventaire_perime','revision',v.inventory_revision);
  END IF;
  o := CASE WHEN jsonb_typeof(l.data)='string' THEN (l.data #>> '{}')::jsonb ELSE l.data END;
  IF jsonb_typeof(o) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'livraison_format_invalide'; END IF;
  inv := v.inventory;
  -- Memes priorites que recevoirLotTracts puis recevoirObjetAutomatique : premier lot seulement.
  IF p_id LIKE 'don-tracts-%' THEN
    FOR e IN SELECT value FROM jsonb_array_elements(inv) LOOP
      IF e->'type' IS NOT DISTINCT FROM o->'type' AND e->'cible' IS NOT DISTINCT FROM o->'cible'
       AND coalesce(e->>'tractType','')=coalesce(o->>'tractType','')
       AND (coalesce(e->'legal','true')<>'false'::jsonb)=(coalesce(o->'legal','true')<>'false'::jsonb)
       AND coalesce(e->'origineQuete','null') IN ('null','false','0','""')
       AND coalesce(o->'origineQuete','null') IN ('null','false','0','""') THEN
        pos:=i; EXIT;
      END IF;
      i:=i+1;
    END LOOP;
    IF pos>=0 THEN
      q:=coalesce((inv->pos->>'quantite')::numeric,0)+coalesce((o->>'quantite')::numeric,0);
      inv:=jsonb_set(inv,ARRAY[pos::text,'quantite'],to_jsonb(q));
    END IF;
  END IF;
  IF pos<0 AND o->'stackable'='true'::jsonb AND coalesce(o->>'stackKey','')<>'' THEN
    q:=coalesce(nullif((o->>'qty')::numeric,0),1);
    IF q<=0 THEN RAISE EXCEPTION 'livraison_quantite_invalide'; END IF;
    i:=0;
    FOR e IN SELECT value FROM jsonb_array_elements(inv) LOOP
      IF e->'stackable'='true'::jsonb AND e->>'stackKey'=o->>'stackKey' THEN pos:=i;EXIT;END IF;
      i:=i+1;
    END LOOP;
    IF pos>=0 THEN
      inv:=jsonb_set(inv,ARRAY[pos::text,'qty'],to_jsonb(coalesce(nullif((inv->pos->>'qty')::numeric,0),1)+q));
    ELSE
      inv:=inv||jsonb_build_array(o||jsonb_build_object('qty',q)); pos:=jsonb_array_length(inv)-1;
    END IF;
  END IF;
  IF pos<0 THEN inv:=inv||jsonb_build_array(o); END IF;
  -- Surcharge permise, aucun plafonnement ni changement des metadonnees d'un objet nouveau.
  UPDATE public.personnages_donnees SET inventory=inv WHERE name=p_acteur RETURNING * INTO v;
  IF v.inventory IS DISTINCT FROM inv THEN
    RAISE EXCEPTION 'inventaire_ecriture_non_appliquee';
  END IF;
  INSERT INTO public.inventaire_livraisons_recues(jeton,id,destinataire) VALUES(p_jeton,p_id,p_acteur);
  DELETE FROM public.objets_recus WHERE id=p_id AND reception_token=p_jeton AND destinataire=p_acteur;
  RETURN jsonb_build_object('ok',true,'contrat',1,'rejeu',false,'inventory',v.inventory,
    'revision',v.inventory_revision,'objet',o,'expediteur',l.expediteur);
END;
$function$;

REVOKE ALL ON FUNCTION public.inventaire_reception_etat(text),
 public.inventaire_sauver_revision(text,bigint,jsonb),public.inventaire_reclamer_livraison(text,text,uuid,bigint)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.inventaire_reception_etat(text),
 public.inventaire_sauver_revision(text,bigint,jsonb),public.inventaire_reclamer_livraison(text,text,uuid,bigint)
 TO authenticated;
-- Anciennes pages : aucune suppression sans insertion atomique ; pas de purge des files.
REVOKE DELETE ON public.objets_recus FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.tracts_reclamer_don(text,text) FROM PUBLIC,anon,authenticated;
DO $droits$
BEGIN
 IF has_table_privilege('authenticated','public.objets_recus','DELETE')
    OR has_function_privilege('authenticated','public.tracts_reclamer_don(text,text)','EXECUTE') THEN
   RAISE EXCEPTION 'reception_ancien_circuit_encore_accessible';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_index WHERE indrelid='public.objets_recus'::regclass
   AND indisunique AND indisvalid AND indpred IS NULL AND indnkeyatts=1
   AND indkey[0]=(SELECT attnum FROM pg_attribute WHERE attrelid=indrelid AND attname='reception_token')) THEN
   RAISE EXCEPTION 'reception_jeton_non_unique';
 END IF;
END;
$droits$;
