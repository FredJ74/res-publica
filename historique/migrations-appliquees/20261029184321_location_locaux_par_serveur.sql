-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261029184321.
-- Archivage documentaire seulement ; ne pas rejouer.
-- =====================================================================================
-- LOCATION DES LOCAUX À LOYER FIXE PAR LE SERVEUR — trois villes (29/10/2026, Claude).
-- NON APPLIQUÉE : application coordonnée avec ChatGPT (intégration).
--
-- DÉFAUT REPRODUIT au rôle authenticated : le bail d'un local de centre (commercial, artisanal,
-- d'affaires), d'une suite de La Republica ou du coffre de la Banque nationale était ÉCRIT PAR
-- L'ÉCRAN dans `locations_actives` ; la base ne vérifiait que « je suis le locataire ». Un
-- joueur absent de Montrouge s'y est inscrit locataire de la Vitrine Principale à 1 FR/jour avec
-- +99 POP/INF, sans payer de premier loyer (l'écran le débitait ailleurs, sans destinataire).
--
-- CORRECTIF, sans nouveau moteur :
-- 1. `locaux_loyers_referentiel` : les 13 locaux de data.js (louer_local + locationData), valables
--    pour TOUTES les villes (ville '*'), plus les spécificités de Luthécia (4 postes d'open space,
--    open space unique non louable) et le box portuaire (15 FR, plusieurs par joueur : prix imposé,
--    bail encore écrit par l'écran, `signature_serveur = false`). Équivalence prouvée par outils/bancs/banc-locaux-loyers.cjs.
-- 2. `local_louer` : lieu RÉEL du joueur, local libre, organisation dont il est membre, 1 PA par
--    payer_ordre, premier loyer par le moteur commun `prelever_loyer_bail` (banque puis espèces,
--    caisse municipale) — tout ou rien, reçu idempotent.
-- 3. Garde immédiate, compatible avec l'écran en ligne : tout bail de ces locaux écrit par le
--    navigateur reçoit le prix, les bonus et le libellé du référentiel.
-- Fermeture de l'écriture navigateur après livraison : 20261029190100.
-- =====================================================================================
CREATE TABLE IF NOT EXISTS public.locaux_loyers_referentiel (
  batiment text NOT NULL, piece text NOT NULL, ville text NOT NULL DEFAULT '*',
  prix integer NOT NULL CHECK (prix >= 0), bonus_pop integer NOT NULL DEFAULT 0,
  bonus_inf integer NOT NULL DEFAULT 0, bonus_dis integer NOT NULL DEFAULT 0,
  label text NOT NULL, louable boolean NOT NULL DEFAULT true,
  signature_serveur boolean NOT NULL DEFAULT true,
  PRIMARY KEY (batiment, piece, ville));
ALTER TABLE public.locaux_loyers_referentiel ADD COLUMN IF NOT EXISTS signature_serveur boolean NOT NULL DEFAULT true;
ALTER TABLE public.locaux_loyers_referentiel ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.locaux_loyers_referentiel FROM anon, authenticated;
INSERT INTO public.locaux_loyers_referentiel (batiment,piece,ville,prix,bonus_pop,bonus_inf,bonus_dis,label,louable) VALUES
 ('hotel-republica','suite_privee','*',500,0,8,10,'Suite Privée',true),
 ('hotel-republica','suite_presidentielle','*',500,8,8,2,'Suite Présidentielle',true),
 ('banque-nationale','coffre_privatif','*',600,0,4,12,'Coffre Privatif',true),
 ('centre-commercial','vitrine_principale','*',800,10,5,0,'Vitrine Principale',true),
 ('centre-commercial','boutique_milieu','*',400,5,3,0,'Boutique Milieu',true),
 ('centre-commercial','arriere_boutique','*',150,2,1,0,'Arrière-Boutique',true),
 ('centre-commercial','cave_reserve','*',80,0,1,5,'Cave / Réserve',true),
 ('centre-artisanal','echoppe_facade','*',600,12,2,0,'Échoppe Façade',true),
 ('centre-artisanal','atelier_milieu','*',300,6,2,0,'Atelier Central',true),
 ('centre-artisanal','reserve_arriere','*',100,2,1,2,'Réserve Arrière',true),
 ('centre-affaires','bureau_prestige','*',1000,3,12,8,'Bureau Prestige',true),
 ('centre-affaires','bureau_standard','*',500,1,6,5,'Bureau Standard',true),
 ('centre-affaires','open_space','*',200,2,3,1,'Open Space',true),
 ('centre-affaires','open_space','capitale',200,2,3,1,'Open Space',false),
 ('centre-affaires','open_space_a','capitale',200,2,3,1,'Open Space A',true),
 ('centre-affaires','open_space_b','capitale',200,2,3,1,'Open Space B',true),
 ('centre-affaires','open_space_c','capitale',200,2,3,1,'Open Space C',true),
 ('centre-affaires','open_space_d','capitale',200,2,3,1,'Open Space D',true),
 ('port-sainte-marie','box-portuaire','*',15,0,0,0,'Box portuaire',true)
ON CONFLICT (batiment,piece,ville) DO UPDATE SET signature_serveur=(EXCLUDED.piece<>'box-portuaire'), prix=EXCLUDED.prix, bonus_pop=EXCLUDED.bonus_pop,
  bonus_inf=EXCLUDED.bonus_inf, bonus_dis=EXCLUDED.bonus_dis, label=EXCLUDED.label, louable=EXCLUDED.louable;

CREATE TABLE IF NOT EXISTS public.locations_recus (
  acteur text NOT NULL, requete uuid NOT NULL, bail_id text NOT NULL, resultat jsonb NOT NULL,
  cree_le timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (acteur, requete));
ALTER TABLE public.locations_recus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.locations_recus FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.local_referentiel_interne(p_batiment text, p_piece text, p_ville text)
RETURNS public.locaux_loyers_referentiel LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ SELECT * FROM public.locaux_loyers_referentiel
       WHERE batiment = p_batiment AND piece = p_piece AND ville IN (p_ville, '*')
       ORDER BY (ville = '*') LIMIT 1 $$;
REVOKE ALL ON FUNCTION public.local_referentiel_interne(text,text,text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.local_louer(p_requete uuid, p_orga text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); p record; ref public.locaux_loyers_referentiel; a record;
  k text; bail jsonb; r jsonb; v text; orga text := nullif(btrim(coalesce(p_orga,'')),'');
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = moi FOR UPDATE;
  SELECT * INTO a FROM public.locations_recus WHERE acteur = moi AND requete = p_requete;
  IF FOUND THEN RETURN a.resultat || jsonb_build_object('rejeu',true); END IF;
  IF coalesce(p.hp,0) <= 0 OR EXISTS(SELECT 1 FROM public.detention_active(moi))
     OR coalesce(p.hospitalisation->>'dateFinParis','') > (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN
    RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible'); END IF;
  ref := public.local_referentiel_interne(p.current_building, p.current_room, p.current_city);
  IF ref.batiment IS NULL OR NOT ref.louable OR NOT ref.signature_serveur THEN RETURN jsonb_build_object('ok',false,'raison','pas_un_local_a_louer'); END IF;
  k := coalesce(p.country,'republic')||':'||p.current_building||':'||p.current_room||':'||p.current_city;
  PERFORM 1 FROM public.locations_actives WHERE id = k OR id LIKE k||':%' FOR UPDATE;
  IF FOUND THEN RETURN jsonb_build_object('ok',false,'raison','local_occupe'); END IF;
  IF orga IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.organisations o WHERE o.id = orga
       AND (o.data::jsonb->>'chef' = moi OR EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(o.data::jsonb->'membres')='array' THEN o.data::jsonb->'membres' ELSE '[]' END) m WHERE m->>'nom' = moi))) THEN
    RETURN jsonb_build_object('ok',false,'raison','orga_non_membre'); END IF;
  BEGIN
    r := public.payer_ordre(moi, 'louer_local', 1, 0);
    IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='P0190', MESSAGE=coalesce(r->>'raison','paiement_refuse'); END IF;
    bail := jsonb_build_object('country',coalesce(p.country,'republic'),'city',p.current_city,'buildingId',p.current_building,
      'roomId',p.current_room,'localKey',coalesce(p.country,'republic')||'|'||p.current_city||'|'||p.current_building||'|'||p.current_room,
      'lotId',NULL,'localLabel',ref.label,'batimentLabel',p.current_building,'prix',ref.prix,'bonusPOP',ref.bonus_pop,
      'bonusINF',ref.bonus_inf,'bonusDIS',ref.bonus_dis,'orgaId',coalesce(orga,''),'orgaAutorisee',true,'locataire',moi,
      'depuis',coalesce(p.day,1),'visible',true,
      'destinationLoyer',jsonb_build_object('type','municipal','pays',coalesce(p.country,'republic'),'ville',p.current_city));
    INSERT INTO public.locations_actives(id,country,data) VALUES (k, coalesce(p.country,'republic'), bail);
    v := public.prelever_loyer_bail(k);
    IF v IS DISTINCT FROM 'paye' THEN RAISE EXCEPTION USING ERRCODE='P0190', MESSAGE='fonds_insuffisants'; END IF;
  EXCEPTION WHEN SQLSTATE 'P0190' THEN
    RETURN jsonb_build_object('ok',false,'raison',SQLERRM,'loyer',ref.prix);
  END;
  SELECT jsonb_build_object('ok',true,'bail',l.data,'bailId',k,'loyer',ref.prix,'pa',d.pa,'arg',d.arg,'liquide',d.liquide,
           'solde_national',(SELECT solde FROM public.comptes_bancaires WHERE personnage=moi AND banque='nationale' LIMIT 1))
    INTO r FROM public.locations_actives l, public.personnages_donnees d WHERE l.id = k AND d.name = moi;
  INSERT INTO public.locations_recus VALUES (moi, p_requete, k, r - 'pa' - 'arg' - 'liquide' - 'solde_national');
  RETURN r;
END;
$function$;
REVOKE ALL ON FUNCTION public.local_louer(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.local_louer(uuid,text) TO authenticated;

-- 3. Garde immédiate : un bail de ces locaux écrit par le navigateur prend les valeurs du référentiel.
CREATE OR REPLACE FUNCTION public.location_local_tarif_attester()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE ref public.locaux_loyers_referentiel;
BEGIN
  IF public.est_appel_serveur() OR NEW.data IS NULL THEN RETURN NEW; END IF;
  ref := public.local_referentiel_interne(NEW.data->>'buildingId', NEW.data->>'roomId', NEW.data->>'city');
  IF ref.batiment IS NULL THEN RETURN NEW; END IF;
  IF NOT ref.louable THEN RAISE EXCEPTION 'pas_un_local_a_louer' USING ERRCODE = '42501'; END IF;
  NEW.data := NEW.data || jsonb_build_object('prix',ref.prix,'bonusPOP',ref.bonus_pop,'bonusINF',ref.bonus_inf,
                'bonusDIS',ref.bonus_dis);
  RETURN NEW;
END;
$function$;
DROP TRIGGER IF EXISTS location_local_tarif_attester ON public.locations_actives;
CREATE TRIGGER location_local_tarif_attester BEFORE INSERT OR UPDATE ON public.locations_actives
  FOR EACH ROW EXECUTE FUNCTION public.location_local_tarif_attester();
