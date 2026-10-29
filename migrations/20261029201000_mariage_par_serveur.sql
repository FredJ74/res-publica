-- =====================================================================================
-- MARIAGE PAR LE SERVEUR (29/10/2026, Claude). NON APPLIQUÉE — application par ChatGPT.
-- Compatible avec l'écran en ligne : n'ajoute que des fonctions et une colonne.
--
-- Décision de Fred : « en Républia, on ne peut pas être marié contre son gré ».
-- Défaut démontré (Jean Jaaj, transaction annulée) : l'écran écrivait lui-même `mariages` et
-- `demandes_mariage`. Un joueur pouvait donc s'unir à un autre sans son accord, ou accepter sa
-- propre demande. Or le mariage a des effets réels : copropriété à l'achat de terrain
-- (`terrain_acquisition_commande`), courrier au conjoint, état civil.
-- Dans le même circuit, le tirage du PNJ se faisait dans le navigateur et les 200 FR de la
-- cérémonie avec un PNJ n'étaient retirés que de l'affichage. La dissolution écrivait une colonne
-- absente (`raison_dissolution`) : divorce et veuvage échouaient en silence.
--
-- Contrat :
--   mariage_demander(requete, destinataire, relation) : 1 PA (ordre demander_mariage).
--     Joueur → demande en attente. PNJ → tirage serveur ; s'il accepte, 200 FR puis union.
--   mariage_repondre(demande, accepter) : seul le destinataire répond à une demande en attente.
--   mariage_officialiser(requete, conjoint) : exige une demande ACCEPTÉE entre les deux, les deux
--     dans la même pièce et aucun des deux déjà marié ; 2 PA + 200 FR (ordre officialiser_mariage).
--   mariage_dissoudre(raison) : divorce par un conjoint, 1 PA + 200 FR (ordre
--     demander_divorce) ; veuvage seulement si la succession du demandeur est ouverte.
-- La fermeture des écritures directes de l'écran est dans 20261029201100 (après livraison).
-- =====================================================================================
ALTER TABLE public.mariages ADD COLUMN IF NOT EXISTS raison_dissolution text;

CREATE OR REPLACE FUNCTION public.mariage_actif_de(p_nom text)
RETURNS public.mariages LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ SELECT * FROM public.mariages WHERE statut = 'actif' AND p_nom IN (conjoint1, conjoint2) LIMIT 1 $$;
REVOKE ALL ON FUNCTION public.mariage_actif_de(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.mariage_demander(p_requete uuid, p_destinataire text, p_relation text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); p record; dest text := nullif(btrim(coalesce(p_destinataire,'')),'');
  est_pj boolean; r jsonb; d jsonb; chance int; tirage int; v_id text;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR dest IS NULL OR dest = moi THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = moi FOR UPDATE;
  IF EXISTS (SELECT 1 FROM public.demandes_mariage WHERE id = 'demande-mariage-'||p_requete)
     OR EXISTS (SELECT 1 FROM public.mariages WHERE id = 'mariage-'||p_requete) THEN
    RETURN jsonb_build_object('ok',true,'rejeu',true); END IF;
  IF (public.mariage_actif_de(moi)).id IS NOT NULL THEN RETURN jsonb_build_object('ok',false,'raison','deja_marie'); END IF;
  IF (public.mariage_actif_de(dest)).id IS NOT NULL THEN RETURN jsonb_build_object('ok',false,'raison','destinataire_deja_marie'); END IF;
  est_pj := EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = dest);
  IF est_pj AND EXISTS (SELECT 1 FROM public.demandes_mariage WHERE statut IN ('en_attente','acceptee')
       AND ((demandeur = moi AND destinataire = dest) OR (demandeur = dest AND destinataire = moi))) THEN
    RETURN jsonb_build_object('ok',false,'raison','demande_deja_en_cours'); END IF;
  r := public.payer_ordre(moi, 'demander_mariage', 1, 0);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN RETURN r; END IF;
  IF est_pj THEN
    v_id := 'demande-mariage-'||p_requete;
    INSERT INTO public.demandes_mariage(id, demandeur, destinataire, country, statut)
      VALUES (v_id, moi, dest, coalesce(p.country,'republic'), 'en_attente');
    RETURN r || jsonb_build_object('ok',true,'pnj',false,'demandeId',v_id);
  END IF;
  -- PNJ : le tirage a lieu ici. La relation (allié / ennemi) n'est connue que du navigateur ;
  -- l'appartenance au groupe est relue sur la présence.
  chance := CASE
    WHEN EXISTS (SELECT 1 FROM public.presences pr, jsonb_array_elements(CASE WHEN jsonb_typeof(pr.groupe_pnj::jsonb)='array' THEN pr.groupe_pnj::jsonb ELSE '[]' END) g
                 WHERE pr.name = moi AND g->>'nom' = dest) THEN 80
    WHEN p_relation = 'ally' THEN 70 WHEN p_relation = 'enemy' THEN 5 ELSE 35 END;
  tirage := 1 + floor(random() * 100)::int;
  IF tirage > chance THEN RETURN r || jsonb_build_object('ok',true,'pnj',true,'accepte',false); END IF;
  d := public.debiter_fonds_ordinaires(moi, 200);
  IF d->>'ok' IS DISTINCT FROM 'true' THEN
    RETURN r || jsonb_build_object('ok',true,'pnj',true,'accepte',true,'celebre',false,'raison','fonds_insuffisants'); END IF;
  INSERT INTO public.mariages(id, conjoint1, conjoint2, country, statut, jour_union, city)
    VALUES ('mariage-'||p_requete, moi, dest, coalesce(p.country,'republic'), 'actif', coalesce(p.day,1), p.current_city);
  RETURN jsonb_build_object('ok',true,'pnj',true,'accepte',true,'celebre',true,'mariageId','mariage-'||p_requete)
    || jsonb_strip_nulls(jsonb_build_object('pa',(SELECT pa FROM public.personnages_donnees WHERE name=moi),
         'arg',d->'arg','liquide',d->'liquide'));
END;
$function$;
REVOKE ALL ON FUNCTION public.mariage_demander(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mariage_demander(uuid,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.mariage_repondre(p_demande text, p_accepter boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); dm record;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT * INTO dm FROM public.demandes_mariage WHERE id = p_demande FOR UPDATE;
  IF NOT FOUND OR dm.destinataire IS DISTINCT FROM moi THEN RETURN jsonb_build_object('ok',false,'raison','demande_introuvable'); END IF;
  IF dm.statut <> 'en_attente' THEN RETURN jsonb_build_object('ok', dm.statut = CASE WHEN p_accepter THEN 'acceptee' ELSE 'refusee' END,'raison','deja_repondu','statut',dm.statut); END IF;
  UPDATE public.demandes_mariage SET statut = CASE WHEN p_accepter THEN 'acceptee' ELSE 'refusee' END WHERE id = p_demande;
  RETURN jsonb_build_object('ok',true,'statut',CASE WHEN p_accepter THEN 'acceptee' ELSE 'refusee' END,'demandeur',dm.demandeur);
END;
$function$;
REVOKE ALL ON FUNCTION public.mariage_repondre(text,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mariage_repondre(text,boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.mariage_officialiser(p_requete uuid, p_conjoint text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); p record; c record; dm record; r jsonb; v_id text := 'mariage-'||p_requete;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_conjoint IS NULL OR p_conjoint = moi THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  IF EXISTS (SELECT 1 FROM public.mariages WHERE id = v_id) THEN RETURN jsonb_build_object('ok',true,'rejeu',true,'mariageId',v_id); END IF;
  -- Verrous dans un ordre stable pour que deux célébrations croisées ne se bloquent pas.
  PERFORM 1 FROM public.personnages_donnees WHERE name IN (moi, p_conjoint) ORDER BY name FOR UPDATE;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = moi;
  SELECT * INTO c FROM public.personnages_donnees WHERE name = p_conjoint;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','conjoint_introuvable'); END IF;
  SELECT * INTO dm FROM public.demandes_mariage WHERE statut = 'acceptee'
    AND ((demandeur = moi AND destinataire = p_conjoint) OR (demandeur = p_conjoint AND destinataire = moi))
    ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','consentement_absent'); END IF;
  IF (public.mariage_actif_de(moi)).id IS NOT NULL OR (public.mariage_actif_de(p_conjoint)).id IS NOT NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','deja_marie'); END IF;
  IF p.current_city IS DISTINCT FROM c.current_city OR p.current_building IS DISTINCT FROM c.current_building
     OR p.current_room IS DISTINCT FROM c.current_room OR p.country IS DISTINCT FROM c.country THEN
    RETURN jsonb_build_object('ok',false,'raison','conjoint_absent'); END IF;
  r := public.payer_ordre(moi, 'officialiser_mariage', 2, 200);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN RETURN r; END IF;
  INSERT INTO public.mariages(id, conjoint1, conjoint2, country, statut, jour_union, city)
    VALUES (v_id, moi, p_conjoint, coalesce(p.country,'republic'), 'actif', coalesce(p.day,1), p.current_city);
  UPDATE public.demandes_mariage SET statut = 'celebree' WHERE id = dm.id;
  RETURN r || jsonb_build_object('ok',true,'mariageId',v_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.mariage_officialiser(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mariage_officialiser(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.mariage_dissoudre(p_raison text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); m public.mariages; r jsonb := '{}'::jsonb;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_raison IS NULL OR p_raison NOT IN ('divorce','veuvage') THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name = moi FOR UPDATE;
  -- Rejeu naturel : une seconde demande trouve « non_marie » et ne paie rien.
  m := public.mariage_actif_de(moi);
  IF m.id IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_marie'); END IF;
  IF p_raison = 'veuvage' THEN
    IF NOT EXISTS (SELECT 1 FROM public.successions WHERE defunt = moi) THEN
      RETURN jsonb_build_object('ok',false,'raison','succession_non_ouverte'); END IF;
  ELSE
    r := public.payer_ordre(moi, 'demander_divorce', 1, 200);
    IF r->>'ok' IS DISTINCT FROM 'true' THEN RETURN r; END IF;
  END IF;
  UPDATE public.mariages SET statut = 'dissous', raison_dissolution = p_raison, dissous_at = now() WHERE id = m.id;
  RETURN r || jsonb_build_object('ok',true,'mariageId',m.id,
    'conjoint', CASE WHEN m.conjoint1 = moi THEN m.conjoint2 ELSE m.conjoint1 END);
END;
$function$;
REVOKE ALL ON FUNCTION public.mariage_dissoudre(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mariage_dissoudre(text) TO authenticated;
