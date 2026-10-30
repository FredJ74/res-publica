-- #219 PRÉPARÉE : conserve jet, reçu et mouvement collectif existants.
-- Les références 223400+ doivent être installées avant activation.
DO $fuite$
DECLARE s text;a integer;b integer;t text;
BEGIN
 s:=pg_get_functiondef('public.police_fuite_personnage_interne(text,text)'::regprocedure);
 IF position('-- fuite_direction_commune_v1' IN s)>0 THEN RETURN;END IF;
 a:=position(' IF v_i.street IS NOT NULL THEN' IN s);
 b:=position(' UPDATE public.police_interceptions SET expires_at=now()' IN s);
 IF a=0 OR b<=a OR position('Déplacement délégué au moteur commun' IN substring(s FROM a FOR b-a))=0 THEN
  RAISE EXCEPTION 'police_destination_non_examinee';END IF;
 s:=overlay(s placing '' FROM a FOR b-a);
 t:=' UPDATE public.police_interceptions SET fuite_tentee=true WHERE personnage=v_nom AND rencontre=p_rencontre;';
 IF position(t IN s)=0 THEN RAISE EXCEPTION 'police_fuite_jet_non_examine';END IF;
 s:=replace(s,t,$c$
 -- fuite_direction_commune_v1 : géographie validée avant de consommer le jet.
 v_receipt:=public.navigation_destination_fuite_interne(v_nom);
 IF NOT coalesce((v_receipt->>'ok')::boolean,false) THEN RETURN v_receipt;END IF;
 v_destination:=v_receipt->>'destination';
$c$||t);
 EXECUTE s;
END $fuite$;
