-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261030115926.
-- Archivage documentaire seulement ; ne pas rejouer.
-- =====================================================================================
-- LA COMMUNE ACHÈTE UN TERRAIN COMME UN PARTICULIER (29/10/2026, Claude). NON APPLIQUÉE.
-- Application par ChatGPT. Compatible avec l'écran en ligne : sans le nouveau paramètre
-- `acquereur`, rien ne change.
--
-- Décision de Fred : « une mairie suit le même cheminement qu'un PJ particulier ». Quand le
-- maire signe un dépôt (achat direct) ou un compromis, on lui demande s'il achète pour la
-- commune ou en son nom propre.
--   acquereur = 'commune' :
--   - il faut être le maire élu de la ville du terrain (cycles_electoraux) ;
--   - pas de prêt : le prêt national est personnel ;
--   - le dépôt de 1 000 FR, puis le solde chez le notaire, sont pris dans la caisse de la mairie
--     (`salaire_caisse_de('maire', …)`), sous le même verrou. Les PA restent ceux du maire ;
--   - à l'acte, le maire doit toujours être le maire de cette ville ;
--   - le titre est `ville:<pays>:<ville>`, le titulaire que le moteur de chantier sait faire
--     financer par la caisse communale et diriger par le maire.
--   La marque d'achat communal est conservée dans `acquisitionAcquereur`, à côté des
--   `acquisitionVersion` / `acquisitionRequete` existants.
-- Au passage : le moteur de chantier cherchait la caisse de Luthécia sous
-- `republic_mairie_capitale`, alors qu'elle s'appelle `republic_mairie-capitale`. Il passe
-- désormais par `salaire_caisse_de`, la référence déjà utilisée par les recettes municipales.
-- Correction en place : chaque fragment remplacé doit exister une seule fois.
-- =====================================================================================
DO $$
DECLARE d text; f text[]; i int;
  frag text[] := ARRAY[
  -- 1. variables
  'permis text;
BEGIN',
  'permis text;commune boolean:=false;caisse_c text;titulaire_c text;ancien_c text;
BEGIN',
  -- 2. paramètre autorisé
  'k NOT IN(''occupation'',''pret'',''permis'')',
  'k NOT IN(''occupation'',''pret'',''permis'',''acquereur'')',
  -- 3. dépôt / compromis : choix de l'acquéreur
  '  IF permis IS NOT NULL AND (p_action<>''compromis'' OR permis NOT IN(',
  '  IF params ? ''acquereur'' AND params->>''acquereur'' NOT IN(''personnel'',''commune'') THEN RETURN jsonb_build_object(''ok'',false,''raison'',''parametres_invalides'');END IF;
  IF params->>''acquereur''=''commune'' THEN
   IF (SELECT c.data::jsonb->>''eluId'' FROM public.cycles_electoraux c WHERE c.country=p.country AND c.poste_id=''maire'' AND c.city=e->>''city'') IS DISTINCT FROM moi THEN RETURN jsonb_build_object(''ok'',false,''raison'',''pas_maire_de_la_commune'');END IF;
   IF jsonb_typeof(pret)=''object'' THEN RETURN jsonb_build_object(''ok'',false,''raison'',''commune_sans_pret'');END IF;
   commune:=true;
  END IF;
  IF permis IS NOT NULL AND (p_action<>''compromis'' OR permis NOT IN(',
  -- 4. acte : achat communal relu sur le dossier
  '  surface:=(e->>''surface'')::numeric;pa:=1;ordre:=''acte_vente_terrain'';',
  '  surface:=(e->>''surface'')::numeric;pa:=1;ordre:=''acte_vente_terrain'';
  commune:=coalesce(e->>''acquisitionAcquereur'','''') LIKE ''ville:%'';
  IF commune AND (SELECT c.data::jsonb->>''eluId'' FROM public.cycles_electoraux c WHERE c.country=p.country AND c.poste_id=''maire'' AND c.city=e->>''city'') IS DISTINCT FROM moi THEN RETURN jsonb_build_object(''ok'',false,''raison'',''pas_maire_de_la_commune'');END IF;',
  -- 5. titulaire et caisse
  ' -- Tout echec apres le premier paiement leve',
  ' IF commune THEN
  titulaire_c:=''ville:''||p.country||'':''||(e->>''city'');
  caisse_c:=public.salaire_caisse_de(''maire'',p.country,e->>''city'');
  IF caisse_c IS NULL THEN RETURN jsonb_build_object(''ok'',false,''raison'',''caisse_mairie_introuvable'');END IF;
 END IF;
 -- Tout echec apres le premier paiement leve',
  -- 6. le maire ne paie que ses PA
  'INSERT INTO public.acquisitions_transactions_internes VALUES(txid_current(),moi,t.id,ordre,pa,montant);',
  'INSERT INTO public.acquisitions_transactions_internes VALUES(txid_current(),moi,t.id,ordre,pa,CASE WHEN commune THEN 0 ELSE montant END);',
  -- 7. paiement : PA du maire, francs de la caisse communale
  'r:=public.payer_ordre(moi,ordre,pa,montant::integer);IF r->>''ok'' IS DISTINCT FROM ''true'' THEN RAISE EXCEPTION USING ERRCODE=''P0135'',MESSAGE=coalesce(r->>''raison'',''paiement_refuse'');END IF;',
  'r:=public.payer_ordre(moi,ordre,pa,CASE WHEN commune THEN 0 ELSE montant::integer END);IF r->>''ok'' IS DISTINCT FROM ''true'' THEN RAISE EXCEPTION USING ERRCODE=''P0135'',MESSAGE=coalesce(r->>''raison'',''paiement_refuse'');END IF;
 IF commune AND montant>0 THEN
  ancien_c:=current_setting(''rp.caisse_interne'',true);
  PERFORM set_config(''rp.caisse_interne'',''on'',true);
  r:=public.caisse_institution_mouvement(caisse_c,-montant,true);
  PERFORM set_config(''rp.caisse_interne'',coalesce(ancien_c,''''),true);
  IF r->>''ok'' IS DISTINCT FROM ''true'' THEN RAISE EXCEPTION USING ERRCODE=''P0135'',MESSAGE=''caisse_communale_insuffisante'';END IF;
 END IF;',
  -- 8. titre au nom de la commune, sans copropriétaire
  'patch:=jsonb_build_object(''proprietaire'',moi,''coproprietaire'',conjoint,',
  'patch:=jsonb_build_object(''proprietaire'',coalesce(titulaire_c,moi),''coproprietaire'',CASE WHEN commune THEN NULL ELSE conjoint END,',
  -- 9. marque d'achat communal sur le dossier (effacée à l'acte)
  'jsonb_build_object(''acquisitionVersion'',2,''acquisitionRequete'',p_requete,''surface'',surface,''valeur_totale'',prix)',
  'jsonb_build_object(''acquisitionVersion'',2,''acquisitionRequete'',p_requete,''surface'',surface,''valeur_totale'',prix,''acquisitionAcquereur'',CASE WHEN p_action IN(''depot'',''compromis'') THEN titulaire_c END)'
  ];
BEGIN
  d := pg_get_functiondef('public.terrain_acquisition_commande(text,text,jsonb,uuid)'::regprocedure);
  IF position('acquisitionAcquereur' IN d) = 0 THEN
    FOR i IN 1..array_length(frag,1)/2 LOOP
      IF (length(d) - length(replace(d, frag[2*i-1], ''))) / length(frag[2*i-1]) <> 1 THEN
        RAISE EXCEPTION 'fragment_introuvable_acquisition_%', i; END IF;
      d := replace(d, frag[2*i-1], frag[2*i]);
    END LOOP;
    EXECUTE d;
  END IF;

  d := pg_get_functiondef('public.chantier_financeur_verrouiller_interne'::regproc);
  IF position('salaire_caisse_de' IN d) = 0 THEN
    IF (length(d) - length(replace(d, 'c:=p_pays||''_mairie_''||p_ville;', ''))) / length('c:=p_pays||''_mairie_''||p_ville;') <> 1 THEN
      RAISE EXCEPTION 'fragment_introuvable_financeur'; END IF;
    EXECUTE replace(d, 'c:=p_pays||''_mairie_''||p_ville;',
      'c:=public.salaire_caisse_de(''maire'',p_pays,p_ville);IF c IS NULL THEN RAISE EXCEPTION ''caisse_communale_absente'';END IF;');
  END IF;
END $$;
