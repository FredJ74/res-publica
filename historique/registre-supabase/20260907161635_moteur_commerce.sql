-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260907161635
-- Nom original      : moteur_commerce
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-07 16:16:35 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : f82cac3814ded05700f4f10327c3c9f3
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =====================================================================
-- LOT 4.0 — MOTEUR GENERIQUE DES COMMERCES : PERSISTANCE ET TRANSACTIONS
-- 8 septembre 2026
-- =====================================================================
-- ⚠️  NON EXECUTEE. Fournie pour relecture.
--
-- ORDRE DE DEPLOIEMENT IMPERATIF : ce fichier D'ABORD, le code ENSUITE.
-- Tous les appels sont fail-closed : tant que ces objets n'existent pas, sbRpc renvoie null,
-- l'action est refusee, et rien n'est ecrit nulle part.
--
-- CE QUE CE FICHIER AJOUTE
--   2 colonnes sur personnages : qualifications, effets_actifs
--   2 tables                   : oeuvres, offres        -- EN LECTURE SEULE pour le navigateur
--   1 rouage interne           : ref_patrimoine_existe  -- non expose
--   5 RPC                      : creer_oeuvre, creer_offre,
--                                acheter_produit_commerce, employer_fonds, repondre_offre
--
-- CE QU'IL NE TOUCHE PAS : les 14 etablissements PNJ historiques d'entreprises, dont aucune ligne
-- n'est migree ni relue. Les fonds v2 gagnent des champs facultatifs (references, salaries,
-- matieresRecherchees, famille) que l'absence rend simplement inertes.
--
-- RLS : le grand chantier securite est separe et ce fichier ne l'ouvre pas. Mais les DEUX tables
-- creees ici naissent en ECRITURE FERMEE -- aucun INSERT, UPDATE ni DELETE direct pour anon et
-- authenticated. Toute ecriture passe par une RPC qui pose elle-meme l'identifiant, les dates et
-- le statut, et qui verifie la qualite du demandeur sur l'actif quand le serveur peut la connaitre.
-- Ces deux tables portent des references typees (auteur, emetteur) : les ouvrir en INSERT direct
-- aurait laisse n'importe quel navigateur ecrire au nom d'un autre PJ. On n'aggrave pas la dette
-- existante, et on n'en cree pas une nouvelle.
--
-- CE QUE CELA NE FAIT PAS : lier une requete a un joueur. Le jeu n'a aucune authentification (voir
-- l'encadre de la section 7) ; ce fichier ferme la fabrication directe, pas l'usurpation par appel.

ALTER TABLE personnages ADD COLUMN IF NOT EXISTS qualifications jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE personnages ADD COLUMN IF NOT EXISTS effets_actifs jsonb NOT NULL DEFAULT '[]'::jsonb;

CREATE TABLE IF NOT EXISTS oeuvres (
  id          text PRIMARY KEY,
  type        text        NOT NULL,
  titre       text        NOT NULL,
  auteur      text,
  country     text,
  jour        integer,
  contenu     text,
  data        jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS oeuvres_auteur_idx ON oeuvres (auteur);
CREATE INDEX IF NOT EXISTS oeuvres_type_idx   ON oeuvres (type);
ALTER TABLE oeuvres ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS oeuvres_select ON oeuvres;
CREATE POLICY oeuvres_select ON oeuvres FOR SELECT USING (true);
DROP POLICY IF EXISTS oeuvres_insert ON oeuvres;
GRANT SELECT ON oeuvres TO anon, authenticated, service_role;
GRANT INSERT ON oeuvres TO service_role;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON oeuvres FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS offres (
  id            text PRIMARY KEY,
  type          text        NOT NULL,
  emetteur      text        NOT NULL,
  destinataire  text        NOT NULL,
  actif         text,
  montant       integer     NOT NULL DEFAULT 0,
  statut        text        NOT NULL DEFAULT 'ouverte',
  data          jsonb       NOT NULL DEFAULT '{}'::jsonb,
  expire_a      timestamptz NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  resolu_a      timestamptz,
  CONSTRAINT offres_statut_valide CHECK (statut IN ('ouverte','acceptee','refusee','expiree','annulee')),
  CONSTRAINT offres_type_valide   CHECK (type IN ('vente_objet','vente_fonds','resiliation_amiable','prestation')),
  CONSTRAINT offres_parties       CHECK (emetteur <> destinataire)
);
CREATE INDEX IF NOT EXISTS offres_destinataire_idx ON offres (destinataire, statut);
CREATE INDEX IF NOT EXISTS offres_emetteur_idx     ON offres (emetteur, statut);
ALTER TABLE offres ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS offres_select ON offres;
CREATE POLICY offres_select ON offres FOR SELECT USING (true);
DROP POLICY IF EXISTS offres_insert ON offres;
GRANT SELECT ON offres TO anon, authenticated, service_role;
GRANT INSERT ON offres TO service_role;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON offres FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION ref_patrimoine_existe(p_ref text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF COALESCE(p_ref, '') = '' THEN RETURN false; END IF;
  IF left(p_ref, 5) = 'orga:' THEN
    RETURN EXISTS (SELECT 1 FROM organisations WHERE id = substr(p_ref, 6));
  ELSIF left(p_ref, 3) = 'pj:' THEN
    RETURN EXISTS (SELECT 1 FROM personnages WHERE name = substr(p_ref, 4));
  ELSIF left(p_ref, 6) = 'ville:' THEN
    RETURN false;
  END IF;
  RETURN EXISTS (SELECT 1 FROM personnages WHERE name = p_ref);
END;
$$;

CREATE OR REPLACE FUNCTION creer_oeuvre(
  p_auteur  text,
  p_type    text,
  p_titre   text,
  p_country text,
  p_jour    integer,
  p_contenu text,
  p_data    jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auteur  text := NULLIF(btrim(COALESCE(p_auteur, '')), '');
  v_type    text := lower(btrim(COALESCE(p_type, '')));
  v_titre   text := btrim(COALESCE(p_titre, ''));
  v_contenu text := COALESCE(p_contenu, '');
  v_data    jsonb;
  v_id      text;
  v_deja    text;
BEGIN
  IF v_titre = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'titre_requis'); END IF;
  IF length(v_titre) > 200 THEN RETURN jsonb_build_object('ok', false, 'raison', 'titre_trop_long'); END IF;
  IF v_type !~ '^[a-z][a-z0-9_]{1,39}$' THEN RETURN jsonb_build_object('ok', false, 'raison', 'type_invalide'); END IF;
  IF length(v_contenu) > 200000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'contenu_trop_volumineux'); END IF;
  IF v_auteur IS NOT NULL AND NOT ref_patrimoine_existe(v_auteur) THEN RETURN jsonb_build_object('ok', false, 'raison', 'auteur_inexistant'); END IF;
  v_data := COALESCE(p_data, '{}'::jsonb);
  IF jsonb_typeof(v_data) <> 'object' THEN v_data := '{}'::jsonb; END IF;
  v_data := v_data - 'id' - 'auteur' - 'created_at' - 'updated_at';
  IF length(v_data::text) > 8000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'data_trop_volumineux'); END IF;
  SELECT id INTO v_deja FROM oeuvres WHERE type = v_type AND titre = v_titre AND COALESCE(auteur, '') = COALESCE(v_auteur, '') LIMIT 1;
  IF v_deja IS NOT NULL THEN RETURN jsonb_build_object('ok', true, 'id', v_deja, 'doublon', true); END IF;
  v_id := 'oeuvre-' || extract(epoch from clock_timestamp())::bigint || '-' || substr(md5(random()::text || COALESCE(v_auteur, '') || v_titre), 1, 8);
  INSERT INTO oeuvres (id, type, titre, auteur, country, jour, contenu, data)
  VALUES (v_id, v_type, v_titre, v_auteur, NULLIF(btrim(COALESCE(p_country, '')), ''), p_jour, NULLIF(v_contenu, ''), v_data);
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'doublon', false);
END;
$$;

CREATE OR REPLACE FUNCTION creer_offre(
  p_emetteur text,
  p_destinataire text,
  p_type text,
  p_actif text,
  p_montant integer,
  p_duree_ms bigint,
  p_data jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  c_offres_max constant integer := 20;
  c_duree_min constant bigint := 3600000;
  c_duree_max constant bigint := 30 * 24 * 3600000;
  c_duree_defaut constant bigint := 3 * 24 * 3600000;
  v_em text := btrim(COALESCE(p_emetteur, ''));
  v_de text := btrim(COALESCE(p_destinataire, ''));
  v_type text := btrim(COALESCE(p_type, ''));
  v_actif text := NULLIF(btrim(COALESCE(p_actif, '')), '');
  v_montant integer := GREATEST(0, COALESCE(p_montant, 0));
  v_duree bigint; v_data jsonb; v_id text; v_deja text; v_ouvertes integer; v_fonds jsonb; v_bail jsonb; v_locataire text; v_bailleur text;
BEGIN
  IF v_em = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'emetteur_requis'); END IF;
  IF v_de = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_requis'); END IF;
  IF v_em = v_de THEN RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_identique'); END IF;
  IF v_type NOT IN ('vente_objet', 'vente_fonds', 'resiliation_amiable', 'prestation') THEN RETURN jsonb_build_object('ok', false, 'raison', 'type_invalide'); END IF;
  IF NOT ref_patrimoine_existe(v_em) THEN RETURN jsonb_build_object('ok', false, 'raison', 'emetteur_inexistant'); END IF;
  IF NOT ref_patrimoine_existe(v_de) THEN RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_inexistant'); END IF;
  v_duree := COALESCE(NULLIF(p_duree_ms, 0), c_duree_defaut);
  IF v_duree < c_duree_min THEN v_duree := c_duree_min; END IF;
  IF v_duree > c_duree_max THEN v_duree := c_duree_max; END IF;
  v_data := COALESCE(p_data, '{}'::jsonb);
  IF jsonb_typeof(v_data) <> 'object' THEN v_data := '{}'::jsonb; END IF;
  v_data := v_data - 'id' - 'type' - 'emetteur' - 'destinataire' - 'montant' - 'statut' - 'expire_a' - 'created_at' - 'resolu_a';
  IF length(v_data::text) > 4000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'termes_trop_volumineux'); END IF;
  IF v_type = 'vente_fonds' THEN
    IF v_actif IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_requis'); END IF;
    SELECT data INTO v_fonds FROM entreprises WHERE id = v_actif;
    IF v_fonds IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
    IF (v_fonds ->> 'proprietaire') IS DISTINCT FROM v_em THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  ELSIF v_type = 'resiliation_amiable' THEN
    IF v_actif IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'bail_requis'); END IF;
    SELECT data INTO v_bail FROM locations_actives WHERE id = v_actif;
    IF v_bail IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'bail_absent'); END IF;
    v_locataire := COALESCE(v_bail ->> 'locataireRef', 'pj:' || COALESCE(v_bail ->> 'locataire', ''));
    SELECT (data::jsonb ->> 'proprietaire') INTO v_bailleur FROM terrains_etat WHERE id = (v_bail ->> 'country') || '_' || (v_bail ->> 'buildingId');
    IF NOT ((v_em = v_locataire AND v_de = v_bailleur) OR (v_em = v_bailleur AND v_de = v_locataire)) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_partie_au_bail'); END IF;
  END IF;
  SELECT count(*) INTO v_ouvertes FROM offres WHERE emetteur = v_em AND statut = 'ouverte' AND expire_a > now();
  IF v_ouvertes >= c_offres_max THEN RETURN jsonb_build_object('ok', false, 'raison', 'quota_offres_ouvertes', 'plafond', c_offres_max); END IF;
  SELECT id INTO v_deja FROM offres WHERE emetteur = v_em AND destinataire = v_de AND type = v_type AND COALESCE(actif, '') = COALESCE(v_actif, '') AND montant = v_montant AND statut = 'ouverte' AND expire_a > now() LIMIT 1;
  IF v_deja IS NOT NULL THEN RETURN jsonb_build_object('ok', true, 'id', v_deja, 'doublon', true); END IF;
  v_id := 'offre-' || extract(epoch from clock_timestamp())::bigint || '-' || substr(md5(random()::text || v_em || v_de), 1, 8);
  INSERT INTO offres (id, type, emetteur, destinataire, actif, montant, statut, data, expire_a)
  VALUES (v_id, v_type, v_em, v_de, v_actif, v_montant, 'ouverte', v_data, now() + make_interval(secs => v_duree / 1000.0));
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'doublon', false, 'statut', 'ouverte', 'montant', v_montant, 'expireDansMs', v_duree);
END;
$$;

CREATE OR REPLACE FUNCTION acheter_produit_commerce(p_acheteur text,p_fonds_id text,p_reference_id text,p_quantite integer,p_objet jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fonds jsonb; v_ref jsonb; v_prix integer; v_stock integer; v_veut integer := GREATEST(0, COALESCE(p_quantite,0)); v_qte integer; v_montant integer; v_arg numeric; v_objet jsonb; v_id_recu text; i integer;
BEGIN
  IF COALESCE(p_acheteur,'')='' OR COALESCE(p_fonds_id,'')='' OR COALESCE(p_reference_id,'')='' THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  IF v_veut<=0 THEN RETURN jsonb_build_object('ok',false,'raison','quantite_invalide'); END IF;
  IF NOT mouvement_titulaire(p_acheteur,0) THEN RETURN jsonb_build_object('ok',false,'raison','acheteur_absent'); END IF;
  SELECT data INTO v_fonds FROM entreprises WHERE id=p_fonds_id FOR UPDATE;
  IF v_fonds IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','fonds_absent'); END IF;
  IF COALESCE(v_fonds->>'statut','actif')<>'actif' THEN RETURN jsonb_build_object('ok',false,'raison','fonds_inactif'); END IF;
  v_ref:=v_fonds->'references'->p_reference_id;
  IF v_ref IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','reference_absente'); END IF;
  IF COALESCE((v_ref->>'active')::boolean,false) IS NOT TRUE THEN RETURN jsonb_build_object('ok',false,'raison','reference_inactive'); END IF;
  v_prix:=GREATEST(0,COALESCE((v_ref->>'prixVente')::numeric,0))::integer;
  v_stock:=GREATEST(0,COALESCE((v_ref->>'stock')::numeric,0))::integer;
  IF v_prix<=0 THEN RETURN jsonb_build_object('ok',false,'raison','prix_non_fixe'); END IF;
  IF v_stock<=0 THEN RETURN jsonb_build_object('ok',false,'raison','rupture_de_stock'); END IF;
  IF left(p_acheteur,5)='orga:' THEN SELECT GREATEST(0,COALESCE((data::jsonb->>'caisse')::numeric,0)) INTO v_arg FROM organisations WHERE id=substr(p_acheteur,6);
  ELSE SELECT COALESCE(arg,0) INTO v_arg FROM personnages WHERE name=CASE WHEN left(p_acheteur,3)='pj:' THEN substr(p_acheteur,4) ELSE p_acheteur END; END IF;
  IF v_arg IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acheteur_absent'); END IF;
  v_qte:=LEAST(v_veut,v_stock,floor(v_arg/v_prix)::integer);
  IF v_qte<=0 THEN RETURN jsonb_build_object('ok',false,'raison','fonds_insuffisants','prixUnitaire',v_prix); END IF;
  v_montant:=v_qte*v_prix;
  IF NOT mouvement_titulaire(p_acheteur,-v_montant) THEN RETURN jsonb_build_object('ok',false,'raison','fonds_insuffisants'); END IF;
  v_ref:=jsonb_set(v_ref,'{stock}',to_jsonb(v_stock-v_qte));
  v_fonds:=jsonb_set(v_fonds,ARRAY['references',p_reference_id],v_ref);
  v_fonds:=jsonb_set(v_fonds,'{caisse}',to_jsonb(GREATEST(0,COALESCE((v_fonds->>'caisse')::numeric,0))+v_montant));
  UPDATE entreprises SET data=v_fonds,updated_at=now() WHERE id=p_fonds_id;
  v_objet:=COALESCE(p_objet,'{}'::jsonb)-'qty'-'exemplaire'||jsonb_build_object('provenance',jsonb_build_object('fondsId',p_fonds_id,'createur',v_fonds->>'proprietaire','etapes','[]'::jsonb));
  IF COALESCE(v_objet->>'regime','empilable')='individuel' THEN
    FOR i IN 1..v_qte LOOP
      v_id_recu:='achat-'||p_fonds_id||'-'||p_reference_id||'-'||extract(epoch from clock_timestamp())::bigint||'-'||i;
      INSERT INTO objets_recus(id,destinataire,expediteur,data) SELECT v_id_recu,CASE WHEN left(p_acheteur,3)='pj:' THEN substr(p_acheteur,4) ELSE p_acheteur END,COALESCE(v_fonds->>'enseigne','Commerce'),(v_objet||jsonb_build_object('qty',1,'exemplaire',jsonb_build_object('id','ex-'||extract(epoch from clock_timestamp())::bigint||'-'||i)))::text WHERE NOT EXISTS(SELECT 1 FROM objets_recus WHERE id=v_id_recu);
    END LOOP;
  ELSE
    v_id_recu:='achat-'||p_fonds_id||'-'||p_reference_id||'-'||extract(epoch from clock_timestamp())::bigint;
    INSERT INTO objets_recus(id,destinataire,expediteur,data) SELECT v_id_recu,CASE WHEN left(p_acheteur,3)='pj:' THEN substr(p_acheteur,4) ELSE p_acheteur END,COALESCE(v_fonds->>'enseigne','Commerce'),(v_objet||jsonb_build_object('qty',v_qte))::text WHERE NOT EXISTS(SELECT 1 FROM objets_recus WHERE id=v_id_recu);
  END IF;
  RETURN jsonb_build_object('ok',true,'quantite',v_qte,'prixUnitaire',v_prix,'montant',v_montant,'stockRestant',v_stock-v_qte);
END;
$$;

CREATE OR REPLACE FUNCTION employer_fonds(p_employeur text,p_fonds_id text,p_salarie text,p_role text,p_taux integer,p_actif boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fonds jsonb; v_salaries jsonb; v_trouve boolean:=false; v_i integer; v_taux integer:=GREATEST(0,COALESCE(p_taux,0));
BEGIN
  IF COALESCE(p_employeur,'')='' OR COALESCE(p_fonds_id,'')='' OR COALESCE(p_salarie,'')='' THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  IF p_employeur=p_salarie THEN RETURN jsonb_build_object('ok',false,'raison','auto_embauche'); END IF;
  SELECT data INTO v_fonds FROM entreprises WHERE id=p_fonds_id FOR UPDATE;
  IF v_fonds IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','fonds_absent'); END IF;
  IF (v_fonds->>'proprietaire') IS DISTINCT FROM p_employeur THEN RETURN jsonb_build_object('ok',false,'raison','pas_proprietaire'); END IF;
  IF left(p_salarie,3)='pj:' AND NOT EXISTS(SELECT 1 FROM personnages WHERE name=substr(p_salarie,4)) THEN RETURN jsonb_build_object('ok',false,'raison','salarie_absent'); END IF;
  v_salaries:=COALESCE(v_fonds->'salaries','[]'::jsonb);
  IF jsonb_array_length(v_salaries)>0 THEN
    FOR v_i IN 0..jsonb_array_length(v_salaries)-1 LOOP
      IF (v_salaries->v_i->>'ref')=p_salarie THEN
        v_salaries:=jsonb_set(v_salaries,ARRAY[v_i::text],(v_salaries->v_i)||jsonb_build_object('role',COALESCE(NULLIF(btrim(COALESCE(p_role,'')),''),'Employé'),'tauxHoraire',v_taux,'actif',COALESCE(p_actif,true)));
        v_trouve:=true;
      END IF;
    END LOOP;
  END IF;
  IF NOT v_trouve THEN
    IF COALESCE(p_actif,true) IS NOT TRUE THEN RETURN jsonb_build_object('ok',false,'raison','salarie_inconnu'); END IF;
    v_salaries:=v_salaries||jsonb_build_array(jsonb_build_object('ref',p_salarie,'role',COALESCE(NULLIF(btrim(COALESCE(p_role,'')),''),'Employé'),'tauxHoraire',v_taux,'actif',true,'depuis',to_char(now() AT TIME ZONE 'Europe/Paris','YYYY-MM-DD')));
  END IF;
  UPDATE entreprises SET data=jsonb_set(v_fonds,'{salaries}',v_salaries),updated_at=now() WHERE id=p_fonds_id;
  RETURN jsonb_build_object('ok',true,'salarie',p_salarie,'actif',COALESCE(p_actif,true),'tauxHoraire',v_taux,'nouveau',NOT v_trouve);
END;
$$;

CREATE OR REPLACE FUNCTION repondre_offre(p_offre_id text,p_acteur text,p_acceptee boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_offre offres%ROWTYPE;
BEGIN
  IF COALESCE(p_offre_id,'')='' OR COALESCE(p_acteur,'')='' THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  SELECT * INTO v_offre FROM offres WHERE id=p_offre_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','offre_absente'); END IF;
  IF v_offre.statut<>'ouverte' THEN RETURN jsonb_build_object('ok',true,'deja_resolue',true,'statut',v_offre.statut); END IF;
  IF v_offre.expire_a<=now() THEN UPDATE offres SET statut='expiree',resolu_a=now() WHERE id=p_offre_id; RETURN jsonb_build_object('ok',false,'raison','offre_expiree'); END IF;
  IF p_acteur=v_offre.destinataire THEN
    UPDATE offres SET statut=CASE WHEN COALESCE(p_acceptee,false) THEN 'acceptee' ELSE 'refusee' END,resolu_a=now() WHERE id=p_offre_id;
    RETURN jsonb_build_object('ok',true,'deja_resolue',false,'statut',CASE WHEN COALESCE(p_acceptee,false) THEN 'acceptee' ELSE 'refusee' END,'type',v_offre.type,'actif',v_offre.actif,'emetteur',v_offre.emetteur,'destinataire',v_offre.destinataire,'montant',v_offre.montant);
  ELSIF p_acteur=v_offre.emetteur AND COALESCE(p_acceptee,false) IS NOT TRUE THEN
    UPDATE offres SET statut='annulee',resolu_a=now() WHERE id=p_offre_id;
    RETURN jsonb_build_object('ok',true,'deja_resolue',false,'statut','annulee');
  END IF;
  RETURN jsonb_build_object('ok',false,'raison','pas_partie_a_l_offre');
END;
$$;

REVOKE EXECUTE ON FUNCTION ref_patrimoine_existe(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION ref_patrimoine_existe(text) TO service_role;
REVOKE EXECUTE ON FUNCTION creer_oeuvre(text,text,text,text,integer,text,jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION creer_oeuvre(text,text,text,text,integer,text,jsonb) TO anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION creer_offre(text,text,text,text,integer,bigint,jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION creer_offre(text,text,text,text,integer,bigint,jsonb) TO anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION acheter_produit_commerce(text,text,text,integer,jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION acheter_produit_commerce(text,text,text,integer,jsonb) TO anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION employer_fonds(text,text,text,text,integer,boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION employer_fonds(text,text,text,text,integer,boolean) TO anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION repondre_offre(text,text,boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION repondre_offre(text,text,boolean) TO anon, authenticated, service_role;