-- A RELIRE ET JOUER VIA LE CONNECTEUR SUPABASE APRES APPLICATION DE LA MIGRATION.
-- NON EXECUTE pendant la preparation Codex, a la demande du game designer.
-- Compte technique postgres requis. Fixtures anonymes creees en transaction, jamais commitees.
-- Aucun compte existant n'est utilise comme acteur. Les registres de la ville sont
-- temporairement isoles dans la transaction : ne pas decouper ce fichier ni ajouter COMMIT.
-- Succes attendu : exception finale "banc nominations : LES ... EPREUVES SONT VERTES".
-- Cette exception annule TOUT le banc, y compris les utilisateurs auth et les effets des RPC.
BEGIN;

CREATE FUNCTION pg_temp.verifier(p_ok boolean, p_message text) RETURNS void
LANGUAGE plpgsql AS $f$
BEGIN
  IF p_ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ECHEC nominations : %', p_message; END IF;
END;
$f$;

CREATE FUNCTION pg_temp.identite(p_uid uuid) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
  PERFORM set_config('role', 'authenticated', true);
END;
$f$;
CREATE FUNCTION pg_temp.serveur() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('role', 'postgres', true);
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
END;
$f$;
GRANT EXECUTE ON FUNCTION pg_temp.verifier(boolean,text), pg_temp.identite(uuid), pg_temp.serveur() TO authenticated;

DO $banc$
DECLARE
  u_maire uuid := gen_random_uuid(); u_adjoint uuid := gen_random_uuid(); u_candidat uuid := gen_random_uuid();
  suffixe text := substr(gen_random_uuid()::text, 1, 8);
  maire text := 'BancMaire-' || suffixe; adjoint text := 'BancAdjoint-' || suffixe;
  candidat text := 'BancCandidat-' || suffixe;
  ville text; poste text; r jsonb; proposition text; n integer := 0;
  dossier jsonb; dossiers jsonb; falsifie jsonb; cle text; id_blob text := 'republic_national_candidatures_postes';
  instant numeric := extract(epoch FROM now()) * 1000;
  tarif record; fixture record; pa_avant integer;
BEGIN
  PERFORM pg_temp.serveur();
  PERFORM pg_temp.verifier(EXISTS (SELECT 1 FROM public.postes_nommes_regles
    WHERE poste_id='directeur_entrepot' AND nomme_par='maire'), 'migration non appliquee');

  INSERT INTO auth.users (id, is_anonymous) VALUES (u_maire,true),(u_adjoint,true),(u_candidat,true);
  -- Le trigger lier_proprietaire prend auth.uid(), meme lors d'un INSERT technique.
  FOR fixture IN SELECT * FROM (VALUES (u_maire,maire),(u_adjoint,adjoint),(u_candidat,candidat)) x(uid,nom) LOOP
    PERFORM set_config('request.jwt.claim.sub',fixture.uid::text,true);
    PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',fixture.uid)::text,true);
    INSERT INTO public.personnages_donnees (name,country,user_id,career,pa,resources)
    VALUES (fixture.nom,'republic',fixture.uid,'magistrat',100,'{"pop":50}');
  END LOOP;
  PERFORM pg_temp.serveur();

  FOREACH ville IN ARRAY ARRAY['capitale','ville_a','ville_b'] LOOP
    -- Le maire est atteste par le vrai registre electoral ; aucun trigger n'est desactive.
    UPDATE public.personnages_donnees SET poste=NULL
      WHERE country='republic' AND poste->>'id'='maire' AND poste->>'city'=ville;
    UPDATE public.cycles_electoraux SET data=jsonb_build_object('eluId',maire)::text
      WHERE country='republic' AND poste_id='maire' AND city=ville;
    IF NOT FOUND THEN
      INSERT INTO public.cycles_electoraux(id,country,poste_id,city,data)
      VALUES ('banc-nom-'||suffixe||'-'||ville,'republic','maire',ville,jsonb_build_object('eluId',maire)::text);
    END IF;
    UPDATE public.personnages_donnees SET poste=jsonb_build_object('id','maire','city',ville) WHERE name=maire;
    DELETE FROM public.postes_attribues WHERE country='republic' AND city=ville
      AND poste_id IN ('commissaire','maire_adjoint','directeur_entrepot');
    DELETE FROM public.titulaires_pnj WHERE country='republic' AND city=ville
      AND poste_id IN ('commissaire','maire_adjoint','directeur_entrepot');
    INSERT INTO public.postes_attribues(id,country,poste_id,city,titulaire,source,depuis)
    VALUES ('republic_maire_adjoint_'||ville,'republic','maire_adjoint',ville,adjoint,'banc',now()-interval '8 days');
    UPDATE public.personnages_donnees SET poste=jsonb_build_object('id','maire_adjoint','city',ville) WHERE name=adjoint;

    FOREACH poste IN ARRAY ARRAY['commissaire','maire_adjoint','directeur_entrepot'] LOOP
      -- L'adjoint ne peut ni nommer PJ/PNJ ni attribuer une candidature ni revoquer.
      PERFORM pg_temp.identite(u_adjoint);
      r:=public.poste_nommer(poste,ville,'BancPNJ-'||suffixe);
      PERFORM pg_temp.verifier(r->>'raison'='autorite_insuffisante',ville||'/'||poste||' nomination adjoint'); n:=n+1;
      r:=public.poste_attribuer_candidature(poste,ville,candidat);
      PERFORM pg_temp.verifier(r->>'raison'='autorite_insuffisante',ville||'/'||poste||' candidature adjoint'); n:=n+1;
      r:=public.poste_revoquer(poste,ville);
      PERFORM pg_temp.verifier(r->>'raison'='autorite_insuffisante',ville||'/'||poste||' revocation adjoint'); n:=n+1;

      -- Le maire reste territorial ; un appel direct visant une autre ville echoue.
      PERFORM pg_temp.identite(u_maire);
      r:=public.poste_nommer(poste,'autre-ville','BancPNJ-'||suffixe);
      PERFORM pg_temp.verifier(r->>'raison'='autorite_insuffisante',poste||' maire hors territoire'); n:=n+1;

      -- Un maire revoque le PNJ par la porte, pas par DELETE depuis un client.
      -- La suppression de l'ancien adjoint est testee puis son role de fixture est restaure.
      r:=public.poste_revoquer(poste,ville);
      PERFORM pg_temp.verifier((r->>'ok')::boolean,poste||' revocation initiale'); n:=n+1;
      r:=public.poste_nommer(poste,ville,'BancPNJ-'||suffixe);
      PERFORM pg_temp.verifier(r->>'decision'='pnj_en_fonction',poste||' nomination PNJ'); n:=n+1;
      r:=public.poste_revoquer(poste,ville);
      PERFORM pg_temp.verifier(r->>'decision'='pnj_revoque',poste||' revocation PNJ'); n:=n+1;

      -- Proposition PJ : pas de fonction effective avant l'acceptation du destinataire.
      r:=public.poste_nommer(poste,ville,candidat); proposition:=r->>'id';
      PERFORM pg_temp.verifier(r->>'decision'='proposition_envoyee' AND proposition IS NOT NULL,poste||' proposition PJ'); n:=n+1;
      PERFORM pg_temp.identite(u_candidat);
      r:=public.poste_accepter_nomination(proposition);
      PERFORM pg_temp.verifier((r->>'ok')::boolean AND r->>'titulaire'=candidat,poste||' acceptation PJ'); n:=n+1;
      PERFORM pg_temp.identite(u_maire);
      r:=public.poste_revoquer(poste,ville);
      PERFORM pg_temp.verifier(r->>'raison'='titulaire_protege',poste||' protection serveur existante'); n:=n+1;
      PERFORM pg_temp.serveur();
      UPDATE public.postes_attribues SET depuis=now()-interval '8 days'
        WHERE id='republic_'||poste||'_'||ville;
      PERFORM pg_temp.identite(u_maire);
      r:=public.poste_revoquer(poste,ville);
      PERFORM pg_temp.verifier(r->>'decision'='revoque',poste||' revocation PJ'); n:=n+1;
      r:=public.poste_attribuer_candidature(poste,ville,candidat);
      PERFORM pg_temp.verifier((r->>'ok')::boolean AND r->>'titulaire'=candidat,poste||' attribution candidature'); n:=n+1;
      PERFORM pg_temp.serveur();
      UPDATE public.postes_attribues SET depuis=now()-interval '8 days'
        WHERE id='republic_'||poste||'_'||ville;
      PERFORM pg_temp.identite(u_maire); r:=public.poste_revoquer(poste,ville);
      PERFORM pg_temp.verifier((r->>'ok')::boolean,poste||' remise a zero de la fixture'); n:=n+1;
      PERFORM pg_temp.serveur();
      IF poste='maire_adjoint' THEN
        INSERT INTO public.postes_attribues(id,country,poste_id,city,titulaire,source,depuis)
        VALUES ('republic_maire_adjoint_'||ville,'republic','maire_adjoint',ville,adjoint,'banc',now()-interval '8 days');
        UPDATE public.personnages_donnees SET poste=jsonb_build_object('id','maire_adjoint','city',ville) WHERE name=adjoint;
      END IF;
    END LOOP;

    -- Ecriture du dossier : seul le maire decide ; chacun peut encore postuler pour soi.
    cle:='directeur_entrepot|'||ville;
    dossier:=jsonb_build_object('posteId','directeur_entrepot','city',ville,'traitee',false,
      'autoriteNom',maire,'echeanceTs',instant+172800000,
      'candidats',jsonb_build_array(jsonb_build_object('nom',candidat,'depuisTs',instant)));
    dossiers:=jsonb_build_object(cle,dossier);
    INSERT INTO public.batiments_etat(id,country,city,building_id,data)
      VALUES(id_blob,'republic','national','candidatures_postes',to_jsonb('{"candidatures":{}}'::text))
      ON CONFLICT(id) DO UPDATE SET data=excluded.data;
    PERFORM pg_temp.identite(u_candidat);
    r:=public.batiment_etat_sous_cle_ecrire('republic','national','candidatures_postes','candidatures',dossiers);
    PERFORM pg_temp.verifier((r->>'ok')::boolean,'depot personnel '||ville); n:=n+1;

    PERFORM pg_temp.identite(u_adjoint);
    falsifie:=jsonb_set(dossiers,ARRAY[cle,'traitee'],'true'::jsonb);
    r:=public.batiment_etat_sous_cle_ecrire('republic','national','candidatures_postes','candidatures',falsifie);
    PERFORM pg_temp.verifier(r->>'raison'='autorite_insuffisante','adjoint cloture le dossier '||ville); n:=n+1;
    r:=public.batiment_etat_sous_cle_ecrire('republic','national','candidatures_postes','candidatures','{}');
    PERFORM pg_temp.verifier(r->>'raison'='autorite_insuffisante','adjoint efface le dossier '||ville); n:=n+1;
    falsifie:=jsonb_set(dossiers,ARRAY[cle,'autoriteNom'],to_jsonb(adjoint));
    r:=public.batiment_etat_sous_cle_ecrire('republic','national','candidatures_postes','candidatures',falsifie);
    PERFORM pg_temp.verifier(r->>'raison'='autorite_insuffisante','adjoint detourne le nominateur '||ville); n:=n+1;
    falsifie:=jsonb_set(dossiers,ARRAY[cle,'echeanceTs'],to_jsonb(instant));
    r:=public.batiment_etat_sous_cle_ecrire('republic','national','candidatures_postes','candidatures',falsifie);
    PERFORM pg_temp.verifier(r->>'raison'='autorite_insuffisante','adjoint avance le tirage '||ville); n:=n+1;
    falsifie:=jsonb_set(dossiers,ARRAY[cle,'candidats'],jsonb_build_array(jsonb_build_object('nom',maire,'depuisTs',instant)));
    r:=public.batiment_etat_sous_cle_ecrire('republic','national','candidatures_postes','candidatures',falsifie);
    PERFORM pg_temp.verifier(r->>'raison'='autorite_insuffisante','adjoint remplace les candidats '||ville); n:=n+1;
    falsifie:=jsonb_set(dossiers,ARRAY[cle,'candidats'],(dossier->'candidats')||jsonb_build_array(jsonb_build_object('nom',adjoint,'depuisTs',instant)));
    r:=public.batiment_etat_sous_cle_ecrire('republic','national','candidatures_postes','candidatures',falsifie);
    PERFORM pg_temp.verifier((r->>'ok')::boolean,'adjoint reste libre de postuler pour lui-meme '||ville); n:=n+1;
    PERFORM pg_temp.identite(u_maire);
    r:=public.batiment_etat_sous_cle_ecrire('republic','national','candidatures_postes','candidatures',
      jsonb_set(falsifie,ARRAY[cle,'traitee'],'true'::jsonb));
    PERFORM pg_temp.verifier((r->>'ok')::boolean,'maire traite le dossier '||ville); n:=n+1;
    PERFORM pg_temp.serveur();
  END LOOP;

  -- Le vrai payeur doit accepter les tarifs transmis par les modales et les debiter.
  PERFORM pg_temp.identite(u_maire);
  FOR tarif IN SELECT * FROM (VALUES
    ('nommer_commissaire',3),('nommer_directeur_entrepot',3),
    ('gerer_candidature_maire_adjoint',1),('gerer_candidature_directeur_entrepot',1),
    ('revoquer_commissaire',1),('revoquer_maire_adjoint',1),('revoquer_directeur_entrepot',1)
  ) x(fn,pa) LOOP
    PERFORM pg_temp.serveur();
    SELECT pa INTO pa_avant FROM public.personnages_donnees WHERE name=maire;
    PERFORM pg_temp.identite(u_maire);
    r:=public.payer_ordre(maire,tarif.fn,tarif.pa,0);
    PERFORM pg_temp.verifier((r->>'ok')::boolean AND (r->>'pa_preleves')::integer=tarif.pa,'tarif '||tarif.fn); n:=n+1;
    PERFORM pg_temp.serveur();
    PERFORM pg_temp.verifier((SELECT pa=pa_avant-tarif.pa FROM public.personnages_donnees WHERE name=maire),'debit '||tarif.fn); n:=n+1;
  END LOOP;
  RAISE EXCEPTION 'banc nominations : LES % EPREUVES SONT VERTES -- transaction annulee',n;
END;
$banc$;
ROLLBACK;
