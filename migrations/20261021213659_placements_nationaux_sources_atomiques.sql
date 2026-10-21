-- PREPAREE UNIQUEMENT #64. Aucun appel financier dans cette migration.
BEGIN;
DO $g$ DECLARE h text;BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.creer_placement_national_interne(text,numeric,int4,text,text)');IF h IS NOT NULL AND h<>'73f9abb074abe4e17024aaa90444a0bb' THEN RAISE EXCEPTION 'definition_non_examinee: creer_placement_national_interne';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.banque_nationale_placer(text,text,text,int4)');IF h IS NOT NULL AND h<>'06e299e17b3534f26f97300f46d7e608' THEN RAISE EXCEPTION 'definition_non_examinee: banque_nationale_placer';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.banque_placement_recu(text)');IF h IS NOT NULL AND h<>'e9f46b12ef5d7559fb2943a7e25a1593' THEN RAISE EXCEPTION 'definition_non_examinee: banque_placement_recu';END IF;
END;$g$;
CREATE TABLE IF NOT EXISTS public.placements_requetes(acteur text,requete text,montant numeric NOT NULL,source text NOT NULL,int_snapshot integer,verdict jsonb,PRIMARY KEY(acteur,requete));
ALTER TABLE public.placements_requetes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.placements_requetes FROM PUBLIC,anon,authenticated;
DO $g$ DECLARE h text;BEGIN SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.creer_placement_national(text,numeric,integer,text)');IF h IS NULL OR h NOT IN('f15dfe9f32729dbabdd5faa982c89f91','4b784747aa0b60b3a5abe4115775a35b') THEN RAISE EXCEPTION 'definition_placement_non_examinee';END IF;END;$g$;
CREATE OR REPLACE FUNCTION public.creer_placement_national_interne(p_personnage text, p_montant numeric, p_int_snapshot integer, p_ville text, p_source text)
 RETURNS placements_bancaires
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_compte comptes_bancaires%ROWTYPE;
  v_pays text;
  v_placement placements_bancaires%ROWTYPE;
  v_id text;
BEGIN
  PERFORM public.exiger_acteur(p_personnage);
  IF p_personnage IS NULL OR btrim(p_personnage) = '' THEN
    RAISE EXCEPTION 'Personnage invalide';
  END IF;

  IF p_montant IS NULL OR p_montant < 500 THEN
    RAISE EXCEPTION 'Montant minimum : 500';
  END IF;

  IF p_ville IS NULL OR btrim(p_ville) = '' THEN
    RAISE EXCEPTION 'Ville invalide';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM placements_bancaires
    WHERE personnage = p_personnage
      AND banque = 'nationale'
      AND type = 'terme'
      AND statut = 'actif'
  ) THEN
    RAISE EXCEPTION 'Un placement Banque nationale est déjà actif';
  END IF;

  SELECT country
  INTO v_pays
  FROM personnages
  WHERE name = p_personnage;

  IF v_pays IS NULL THEN
    RAISE EXCEPTION 'Personnage introuvable';
  END IF;

  IF p_source='liquide' THEN
    UPDATE public.personnages_donnees SET liquide=liquide-p_montant
     WHERE name=p_personnage AND liquide>=p_montant;
    IF NOT FOUND THEN RAISE EXCEPTION 'Liquide insuffisant';END IF;
  ELSIF p_source='compte' THEN
  -- Verrouillage du compte : deux opérations concurrentes
  -- ne peuvent pas utiliser le même solde.
  SELECT *
  INTO v_compte
  FROM comptes_bancaires
  WHERE personnage = p_personnage
    AND banque = 'nationale'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Compte Banque nationale introuvable';
  END IF;

  IF v_compte.solde < p_montant THEN
    RAISE EXCEPTION 'Solde Banque nationale insuffisant';
  END IF;

  UPDATE comptes_bancaires
  SET
    solde = solde - p_montant,
    updated_at = now()
  WHERE id = v_compte.id;

  ELSE RAISE EXCEPTION 'Source invalide';END IF;

  v_id :=
    'terme_' ||
    md5(
      p_personnage ||
      clock_timestamp()::text ||
      random()::text
    );

  INSERT INTO placements_bancaires (
    id,
    personnage,
    pays,
    ville,
    banque,
    type,
    libelle,
    montant,
    visible_fiscalement,
    date_placement,
    prochaine_echeance,
    statut,
    int_snapshot
  )
  VALUES (
    v_id,
    p_personnage,
    v_pays,
    p_ville,
    'nationale',
    'terme',
    'Placement Banque nationale',
    p_montant,
    true,
    now(),
    now() + interval '7 days',
    'actif',
    p_int_snapshot
  )
  RETURNING *
  INTO v_placement;

  -- arg reste volontairement inchangé :
  -- compte bancaire -> placement = transfert patrimonial.

  RETURN v_placement;
END;
$function$;
CREATE OR REPLACE FUNCTION public.creer_placement_national(p_personnage text,p_montant numeric,p_int_snapshot integer,p_ville text)
RETURNS public.placements_bancaires LANGUAGE sql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
 SELECT public.creer_placement_national_interne(p_personnage,p_montant,p_int_snapshot,p_ville,'compte');
$function$;
REVOKE ALL ON FUNCTION public.creer_placement_national_interne(text,numeric,integer,text,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.banque_nationale_placer(p_requete text,p_montant text,p_source text,p_int_snapshot integer) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE moi text:=public.mon_personnage();p public.personnages_donnees%rowtype;r public.placements_requetes%rowtype;
 montant numeric;v jsonb;ligne public.placements_bancaires%rowtype;
BEGIN
 IF moi IS NULL THEN RETURN '{"ok":false,"raison":"acteur_non_authentifie"}';END IF;
 IF p_requete IS NULL OR p_requete!~'^[A-Za-z0-9_-]{1,120}$' OR p_montant IS NULL OR p_montant!~'^[0-9]+$' OR p_source IS NULL OR p_source NOT IN('liquide','compte') OR p_int_snapshot IS NULL THEN RETURN '{"ok":false,"raison":"parametres_invalides"}';END IF;
 montant:=p_montant::numeric;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
 SELECT * INTO r FROM public.placements_requetes WHERE acteur=moi AND requete=p_requete;
 IF FOUND THEN
  IF r.montant<>montant OR r.source<>p_source OR r.int_snapshot IS DISTINCT FROM p_int_snapshot THEN RETURN '{"ok":false,"raison":"requete_reutilisee"}';END IF;
  RETURN r.verdict||'{"rejeu":true}'::jsonb;
 END IF;
 IF p.current_building IS DISTINCT FROM 'banque-nationale' OR p.current_room IS DISTINCT FROM 'accueil_banque' OR coalesce(p.hp,100)<=0 THEN RETURN '{"ok":false,"raison":"pas_sur_place_ou_incapacite"}';END IF;
 IF montant<500 THEN RETURN '{"ok":false,"raison":"minimum_500"}';END IF;
 IF EXISTS(SELECT 1 FROM public.investissements WHERE joueur=moi AND statut='en_cours') THEN RETURN '{"ok":false,"raison":"placement_legacy_actif"}';END IF;
 BEGIN
  v:=public.payer_ordre(moi,'investir',1,0);
  IF v->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'frais_refuses';END IF;
  ligne:=public.creer_placement_national_interne(moi,montant,p_int_snapshot,p.current_city,p_source);
  SELECT pa INTO p.pa FROM public.personnages_donnees WHERE name=moi;
  v:=jsonb_build_object('ok',true,'placement',to_jsonb(ligne),'pa',p.pa);
  INSERT INTO public.placements_requetes VALUES(moi,p_requete,montant,p_source,p_int_snapshot,v);
  RETURN v;
 EXCEPTION WHEN SQLSTATE 'P0001' THEN
  IF SQLERRM IN('frais_refuses','Liquide insuffisant','Solde Banque nationale insuffisant','Compte Banque nationale introuvable','Un placement Banque nationale est déjà actif','Montant minimum : 500','Personnage introuvable','Ville invalide') THEN RETURN jsonb_build_object('ok',false,'raison',SQLERRM);ELSE RAISE;END IF;
 END;
END;$$;
CREATE OR REPLACE FUNCTION public.banque_placement_recu(p_requete text) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT coalesce((SELECT verdict FROM public.placements_requetes WHERE acteur=public.mon_personnage() AND requete=p_requete),'{"ok":false,"raison":"recu_absent"}'::jsonb);
$$;
REVOKE ALL ON FUNCTION public.banque_nationale_placer(text,text,text,integer),public.banque_placement_recu(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.banque_nationale_placer(text,text,text,integer),public.banque_placement_recu(text) TO authenticated;
COMMIT;
