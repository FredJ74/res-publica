-- ===========================================================================
-- BANC DE LA MISE EN RELATION (1er octobre 2026)
-- ---------------------------------------------------------------------------
-- METHODE : le DDL de PostgreSQL etant transactionnel, ce banc envoie LA
-- MIGRATION ELLE-MEME puis ce bloc dans une seule requete qui se termine par
-- RAISE EXCEPTION. Tout s'execute, tout est annule : on obtient le rapport sans
-- rien persister en production.
--
-- CE QU'IL DOIT PROUVER :
--   B1  aucune organisation du type : refus, et le delai N'EST PAS consomme
--   B2  trois organisations : la PLUS NOMBREUSE est sollicitee, et une seule
--   B3  le courrier part du passeur vers le CHEF, avec le marqueur de bouton
--   B4  le corps ne contient RIEN du projet du joueur
--   B5  deuxieme demande immediate : refus, trois jours restants
--   B6  l'etat refuse aussi, sans rien ecrire
--   B7  trois jours plus tard : ESCALADE vers la deuxieme plus nombreuse
--   B8  puis la troisieme, puis plus rien (toutes_contactees), delai non consomme
--   B9  un passeur inconnu est refuse
--   B10 un SECOND joueur repart de la plus nombreuse : l'etat est par joueur
--   B11 une organisation sans chef est ignoree ; un blob illisible aussi
--   B12 un nom portant | et ] ne casse pas le marqueur
--   B13 anon ne peut executer ni l'une ni l'autre des deux RPC
--   B14 la STRATEGIE de selection s'interroge seule, sans aucune consequence
--   B15 la mise en relation ne choisit plus : elle delegue, et la strategie est
--       privee
--
-- RESULTAT DU 1er OCTOBRE 2026 -- 15 scenarios, aucun echec, tout annule.
-- B14 et B15 ont ete ajoutes apres coup, a la demande du game design : verifier
-- que la strategie de selection est isolee pour pouvoir changer seule. Le
-- comportement de B1 a B13 est reste identique mot pour mot avant et apres
-- l'extraction -- c'est exactement ce qu'on attend d'un refactoring.
--   B14 choix sans exclusion   =zzorg_grosse membres=5
--   B14 avec la grosse exclue  =zzorg_moyenne
--   B14 toutes exclues         =NULL
--   B14 autre type             =zzorg_autre_type
--   B14 type sans organisation =NULL
--   B14 cles rendues           =chef,id,membres,nom
--   B14 courriers inchanges    =5     <- interroger la strategie n'ecrit rien
--   B15 demander lit les organisations =0
--   B15 elle delegue le choix          =1
--   B15 la strategie n'ecrit rien      =0
--   B15 la strategie est privee        =0
--
-- Detail des treize premiers :
--   B1  aucune organisation  ok=false raison=aucune_organisation
--   B1  delai non consomme   lignes etat=0
--   B1  etat                 peut_demander=true
--   B2  premiere demande     ok=true rang=1
--   B2  cles de la reponse   =ok,rang          <- l'organisation n'est pas nommee
--   B2  courriers envoyes    =1
--   B3  expediteur=Pat Hounette destinataire=zzChefGrosse
--   B3  sujet=Quelqu'un a contacter
--   B3  marqueur present     =t
--   B4  corps = phrase arretee + marqueur seulement =t
--   B2  etat : contactees    =["zzorg_grosse"]
--   B5  demande immediate    ok=false raison=delai_non_ecoule jours_restants=3
--   B5  courriers apres refus=1
--   B6  etat                 peut_demander=false jours_restants=3 deja=1
--   B7  apres 3 jours        ok=true rang=2
--   B7  contactees           =["zzorg_grosse", "zzorg_moyenne"]
--   B8  troisieme            ok=true rang=3
--   B8  contactees           =["zzorg_grosse", "zzorg_moyenne", "zzorg_petite"]
--   B8  quatrieme            ok=false raison=toutes_contactees
--   B8  delai non consomme   anciennete=259200 s
--   B8  courriers au total   =3
--   B9  passeur inconnu      ok=false raison=passeur_inconnu
--   B9  type non confie      ok=false raison=passeur_inconnu
--   B10 second joueur        ok=true rang=1 destinataire=zzChefGrosse
--   B11 courriers aux pieges =0        <- sans chef, blob casse, autre type : ignores
--   B11 cast tolerant        blob casse -> NULL
--   B12 nom hostile          ok=true, marqueur propre=t
--   B13 RPC ouvertes a anon  =0 ; tables lisibles en direct =0
--
-- CE QUE B11 A REELLEMENT ATTRAPE : l'organisation la PLUS nombreuse du jeu de
-- test (dix membres) n'a pas de chef, et la deuxieme (huit) est d'un autre type.
-- Si le choix ne regardait que le nombre de membres, le courrier serait parti vers
-- une boite vide. Un banc ou toutes les organisations sont valides n'aurait rien
-- prouve.
--
-- PIEGES CONNUS DE CE DEPOT, deja payes ailleurs :
--   * l'argent d'un personnage vit dans la COLONNE `liquide` (sans objet ici :
--     cette mecanique est gratuite, et c'est le game design qui le dit) ;
--   * une variable PL/pgSQL nommee `U` collisionne avec l'alias de table `u`.
--
-- POUR REJOUER : coller migration_20261001_contact_organisation.sql, puis ce
-- bloc, dans une seule requete.
-- ===========================================================================
DO $banc$
DECLARE
  R text := '';
  A text := 'zzContact1'; B text := 'zzContact2'; C text := 'zzContact|Bad]Name';
  v_u1 uuid; v_u2 uuid; v_u3 uuid;
  v jsonb; n integer; corps text; sujet text; expe text; dest text;
BEGIN
  -- ---- trois comptes sans personnage, trois personnages de test ----
  SELECT u.id INTO v_u1 FROM auth.users u
    LEFT JOIN public.personnages_donnees p ON p.user_id = u.id
   WHERE p.user_id IS NULL LIMIT 1;
  SELECT u.id INTO v_u2 FROM auth.users u
    LEFT JOIN public.personnages_donnees p ON p.user_id = u.id
   WHERE p.user_id IS NULL AND u.id <> v_u1 LIMIT 1;
  SELECT u.id INTO v_u3 FROM auth.users u
    LEFT JOIN public.personnages_donnees p ON p.user_id = u.id
   WHERE p.user_id IS NULL AND u.id NOT IN (v_u1, v_u2) LIMIT 1;
  IF v_u3 IS NULL THEN RAISE EXCEPTION 'banc : moins de trois comptes libres'; END IF;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_u1::text, 'role', 'authenticated')::text, true);
  INSERT INTO public.personnages_donnees (name, country, resources, current_building, current_room)
  VALUES (A, 'republic', jsonb_build_object('pa', 20), 'place-formulaire-liberte', 'place');

  -- =========================================================================
  -- B1 : rien a solliciter
  -- =========================================================================
  v := public.contact_organisation_demander('pat_hounette', 'criminelle');
  R := R || format('B1  aucune organisation  ok=%s raison=%s', v->>'ok', v->>'raison') || E'\n';
  SELECT count(*) INTO n FROM public.contacts_organisations WHERE joueur = A;
  R := R || format('B1  delai non consomme   lignes d''etat=%s (0 attendu)', n) || E'\n';
  v := public.contact_organisation_etat('pat_hounette', 'criminelle');
  R := R || format('B1  etat                 peut_demander=%s', v->>'peut_demander') || E'\n';

  -- =========================================================================
  -- Trois organisations criminelles de tailles differentes, plus deux pieges
  -- =========================================================================
  INSERT INTO public.organisations (id, country_origine, data) VALUES
    ('zzorg_petite', 'republic', json_build_object(
        'id','zzorg_petite','type','criminelle','nom','Les Petites Mains',
        'chef','zzChefPetite','membres', json_build_array(
          json_build_object('nom','a')))::text),
    ('zzorg_grosse', 'republic', json_build_object(
        'id','zzorg_grosse','type','criminelle','nom','La Grosse Famille',
        'chef','zzChefGrosse','membres', json_build_array(
          json_build_object('nom','a'), json_build_object('nom','b'),
          json_build_object('nom','c'), json_build_object('nom','d'),
          json_build_object('nom','e')))::text),
    ('zzorg_moyenne', 'republic', json_build_object(
        'id','zzorg_moyenne','type','criminelle','nom','Les Trois Doigts',
        'chef','zzChefMoyenne','membres', json_build_array(
          json_build_object('nom','a'), json_build_object('nom','b'),
          json_build_object('nom','c')))::text),
    -- PIEGE 1 : la plus nombreuse de toutes, mais SANS CHEF. Personne a qui
    -- ecrire : elle doit etre ignoree, pas provoquer une erreur.
    ('zzorg_sans_chef', 'republic', json_build_object(
        'id','zzorg_sans_chef','type','criminelle','nom','Les Sans-Tete',
        'chef','','membres', json_build_array(
          json_build_object('nom','a'), json_build_object('nom','b'),
          json_build_object('nom','c'), json_build_object('nom','d'),
          json_build_object('nom','e'), json_build_object('nom','f'),
          json_build_object('nom','g'), json_build_object('nom','h'),
          json_build_object('nom','i'), json_build_object('nom','j')))::text),
    -- PIEGE 2 : blob illisible. Doit etre ignore sans faire tomber la mecanique.
    ('zzorg_cassee', 'republic', '{ ceci n''est pas du JSON'),
    -- PIEGE 3 : enorme, mais d'un AUTRE type. Le type est le seul filtre de
    -- nature, et il doit tenir.
    ('zzorg_autre_type', 'republic', json_build_object(
        'id','zzorg_autre_type','type','syndicale','nom','Le Grand Syndicat',
        'chef','zzChefSyndicat','membres', json_build_array(
          json_build_object('nom','a'), json_build_object('nom','b'),
          json_build_object('nom','c'), json_build_object('nom','d'),
          json_build_object('nom','e'), json_build_object('nom','f'),
          json_build_object('nom','g'), json_build_object('nom','h')))::text);

  -- =========================================================================
  -- B2/B3/B4 : la plus nombreuse, un seul courrier, contenu minimal
  -- =========================================================================
  v := public.contact_organisation_demander('pat_hounette', 'criminelle');
  R := R || format('B2  premiere demande     ok=%s rang=%s', v->>'ok', v->>'rang') || E'\n';
  R := R || format('B2  reponse ne nomme pas l''orga  cles=%s',
        (SELECT string_agg(k, ',' ORDER BY k) FROM jsonb_object_keys(v) k)) || E'\n';
  SELECT count(*) INTO n FROM public.mails WHERE from_player = 'Pat Hounette';
  R := R || format('B2  courriers envoyes     =%s (1 attendu)', n) || E'\n';
  SELECT m.subject, m.from_player, m.to_player, m.body INTO sujet, expe, dest, corps
    FROM public.mails m WHERE m.from_player = 'Pat Hounette' ORDER BY m.created_at DESC LIMIT 1;
  R := R || format('B3  expediteur=%s destinataire=%s (zzChefGrosse attendu)', expe, dest) || E'\n';
  R := R || format('B3  sujet=%s', sujet) || E'\n';
  R := R || format('B3  marqueur present      =%s',
        (corps LIKE '%[[act:ecrire_a|' || A || ']]%')) || E'\n';
  R := R || format('B3  nom du joueur cite    =%s', (corps LIKE '%' || A || '%')) || E'\n';
  R := R || format('B4  corps complet         =%s', replace(corps, E'\n', ' / ')) || E'\n';
  -- B4 : aucune trace du projet. Le joueur n'en a transmis aucun -- la RPC n'a
  -- pas de parametre pour en recevoir -- mais on verifie que le corps est bien
  -- la phrase arretee, et rien d'autre.
  R := R || format('B4  corps = phrase arretee + marqueur seulement =%s',
        (corps = 'J''ai rencontré quelqu''un qui cherche un service. Contacte '
                 || A || ' de ma part.' || chr(10) || chr(10)
                 || '[[act:ecrire_a|' || A || ']]')) || E'\n';
  SELECT organisations_contactees::text INTO sujet FROM public.contacts_organisations
   WHERE joueur = A;
  R := R || format('B2  etat : contactees     =%s', sujet) || E'\n';

  -- =========================================================================
  -- B5/B6 : trois jours de refus
  -- =========================================================================
  v := public.contact_organisation_demander('pat_hounette', 'criminelle');
  R := R || format('B5  demande immediate     ok=%s raison=%s jours_restants=%s',
        v->>'ok', v->>'raison', v->>'jours_restants') || E'\n';
  SELECT count(*) INTO n FROM public.mails WHERE from_player = 'Pat Hounette';
  R := R || format('B5  courriers apres refus =%s (toujours 1 attendu)', n) || E'\n';
  v := public.contact_organisation_etat('pat_hounette', 'criminelle');
  R := R || format('B6  etat                  peut_demander=%s jours_restants=%s deja=%s',
        v->>'peut_demander', v->>'jours_restants', v->>'deja_contactees') || E'\n';

  -- =========================================================================
  -- B7/B8 : escalade, puis epuisement
  -- =========================================================================
  -- On recule la derniere demande de trois jours : c'est exactement ce que fait
  -- le temps. Aucune autre facon de tester un delai sans attendre.
  UPDATE public.contacts_organisations SET derniere_demande = now() - interval '3 days'
   WHERE joueur = A;
  v := public.contact_organisation_demander('pat_hounette', 'criminelle');
  R := R || format('B7  apres 3 jours         ok=%s rang=%s', v->>'ok', v->>'rang') || E'\n';
  SELECT m.to_player INTO dest FROM public.mails m
   WHERE m.from_player = 'Pat Hounette' ORDER BY m.created_at DESC, m.id DESC LIMIT 1;
  SELECT organisations_contactees::text INTO sujet FROM public.contacts_organisations
   WHERE joueur = A;
  R := R || format('B7  contactees            =%s (grosse puis moyenne attendu)', sujet) || E'\n';

  UPDATE public.contacts_organisations SET derniere_demande = now() - interval '3 days'
   WHERE joueur = A;
  v := public.contact_organisation_demander('pat_hounette', 'criminelle');
  R := R || format('B8  troisieme             ok=%s rang=%s', v->>'ok', v->>'rang') || E'\n';
  SELECT organisations_contactees::text INTO sujet FROM public.contacts_organisations
   WHERE joueur = A;
  R := R || format('B8  contactees            =%s', sujet) || E'\n';

  UPDATE public.contacts_organisations SET derniere_demande = now() - interval '3 days'
   WHERE joueur = A;
  v := public.contact_organisation_demander('pat_hounette', 'criminelle');
  R := R || format('B8  quatrieme             ok=%s raison=%s', v->>'ok', v->>'raison') || E'\n';
  SELECT extract(epoch from now() - derniere_demande)::integer INTO n
    FROM public.contacts_organisations WHERE joueur = A;
  R := R || format('B8  delai non consomme    anciennete=%s s (environ 259200 attendu)', n) || E'\n';
  SELECT count(*) INTO n FROM public.mails WHERE from_player = 'Pat Hounette';
  R := R || format('B8  courriers au total    =%s (3 attendu)', n) || E'\n';

  -- =========================================================================
  -- B9 : passeur inconnu
  -- =========================================================================
  v := public.contact_organisation_demander('marc_hantile', 'criminelle');
  R := R || format('B9  passeur inconnu       ok=%s raison=%s', v->>'ok', v->>'raison') || E'\n';
  v := public.contact_organisation_demander('pat_hounette', 'mediatique');
  R := R || format('B9  type non confie       ok=%s raison=%s', v->>'ok', v->>'raison') || E'\n';

  -- =========================================================================
  -- B10 : un second joueur repart de zero
  -- =========================================================================
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_u2::text, 'role', 'authenticated')::text, true);
  INSERT INTO public.personnages_donnees (name, country, resources, current_building, current_room)
  VALUES (B, 'republic', jsonb_build_object('pa', 20), 'place-formulaire-liberte', 'place');
  v := public.contact_organisation_demander('pat_hounette', 'criminelle');
  SELECT m.to_player INTO dest FROM public.mails m
   WHERE m.from_player = 'Pat Hounette' ORDER BY m.created_at DESC, m.id DESC LIMIT 1;
  R := R || format('B10 second joueur         ok=%s rang=%s destinataire=%s',
        v->>'ok', v->>'rang', dest) || E'\n';

  -- =========================================================================
  -- B11 : les pieges ont bien ete ignores
  -- =========================================================================
  SELECT count(*) INTO n FROM public.mails
   WHERE from_player = 'Pat Hounette' AND to_player IN ('zzChefSyndicat', '');
  R := R || format('B11 courriers aux pieges  =%s (0 attendu)', n) || E'\n';
  R := R || format('B11 cast tolerant         blob casse -> %s',
        coalesce(public.jsonb_ou_null('{ pas du JSON')::text, 'NULL')) || E'\n';

  -- =========================================================================
  -- B12 : un nom hostile ne casse pas le marqueur
  -- =========================================================================
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_u3::text, 'role', 'authenticated')::text, true);
  INSERT INTO public.personnages_donnees (name, country, resources, current_building, current_room)
  VALUES (C, 'republic', jsonb_build_object('pa', 20), 'place-formulaire-liberte', 'place');
  v := public.contact_organisation_demander('pat_hounette', 'criminelle');
  SELECT m.body INTO corps FROM public.mails m
   WHERE m.from_player = 'Pat Hounette' ORDER BY m.created_at DESC, m.id DESC LIMIT 1;
  R := R || format('B12 nom hostile           ok=%s', v->>'ok') || E'\n';
  R := R || format('B12 marqueur propre       =%s',
        (corps LIKE '%[[act:ecrire_a|zzContactBadName]]%')) || E'\n';
  R := R || format('B12 corps                 =%s', replace(corps, E'\n', ' / ')) || E'\n';

  -- =========================================================================
  -- B13 : anon n'entre pas
  -- =========================================================================
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public'
     AND p.proname IN ('contact_organisation_etat', 'contact_organisation_demander')
     AND has_function_privilege('anon', p.oid, 'execute');
  R := R || format('B13 RPC ouvertes a anon    =%s (0 attendu)', n) || E'\n';
  SELECT count(*) INTO n FROM pg_class c JOIN pg_namespace ns ON ns.oid = c.relnamespace
   WHERE ns.nspname = 'public'
     AND c.relname IN ('contacts_organisations', 'contacts_organisations_passeurs')
     AND (has_table_privilege('anon', c.oid, 'select')
       OR has_table_privilege('authenticated', c.oid, 'select'));
  R := R || format('B13 tables lisibles direct =%s (0 attendu)', n) || E'\n';

  -- =========================================================================
  -- B14 : LA STRATEGIE S'INTERROGE SEULE
  -- =========================================================================
  -- Ce que ce scenario prouve vraiment : on peut poser la question « laquelle ? »
  -- sans declencher la moindre consequence -- aucun courrier, aucun delai, aucune
  -- trace. C'est la definition pratique d'une responsabilite isolee, et c'est ce
  -- qui permettra de remplacer la strategie en ne reecrivant qu'un corps.
  v := public.contact_organisation_choisir(A, 'criminelle', '[]'::jsonb);
  R := R || format('B14 choix sans exclusion   =%s membres=%s',
        v->>'id', v->>'membres') || E'\n';
  v := public.contact_organisation_choisir(A, 'criminelle', '["zzorg_grosse"]'::jsonb);
  R := R || format('B14 avec la grosse exclue  =%s', v->>'id') || E'\n';
  v := public.contact_organisation_choisir(A, 'criminelle',
        '["zzorg_grosse","zzorg_moyenne","zzorg_petite"]'::jsonb);
  R := R || format('B14 toutes exclues         =%s (NULL attendu)',
        coalesce(v::text, 'NULL')) || E'\n';
  v := public.contact_organisation_choisir(A, 'syndicale', '[]'::jsonb);
  R := R || format('B14 autre type             =%s (le syndicat, 8 membres)', v->>'id') || E'\n';
  v := public.contact_organisation_choisir(A, 'mediatique', '[]'::jsonb);
  R := R || format('B14 type sans organisation =%s (NULL attendu)',
        coalesce(v::text, 'NULL')) || E'\n';
  R := R || format('B14 cles rendues           =%s',
        (SELECT string_agg(k, ',' ORDER BY k) FROM jsonb_object_keys(
           public.contact_organisation_choisir(A, 'criminelle', '[]'::jsonb)) k)) || E'\n';
  -- Interroger la strategie n'ecrit RIEN : les compteurs ne bougent pas.
  SELECT count(*) INTO n FROM public.mails WHERE from_player = 'Pat Hounette';
  R := R || format('B14 courriers inchanges    =%s (5 attendu : 3+1+1 des demandes)', n) || E'\n';

  -- =========================================================================
  -- B15 : LA MISE EN RELATION NE CHOISIT PLUS
  -- =========================================================================
  -- Garde structurelle, et non comportementale : si quelqu'un reintroduisait un
  -- SELECT sur les organisations dans contact_organisation_demander, la strategie
  -- redeviendrait diffuse sans qu'aucun test fonctionnel ne s'en plaigne.
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public' AND p.proname = 'contact_organisation_demander'
     AND p.prosrc ILIKE '%public.organisations%';
  R := R || format('B15 demander lit les organisations =%s (0 attendu)', n) || E'\n';
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public' AND p.proname = 'contact_organisation_demander'
     AND p.prosrc ILIKE '%contact_organisation_choisir%';
  R := R || format('B15 elle delegue le choix          =%s (1 attendu)', n) || E'\n';
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public' AND p.proname = 'contact_organisation_choisir'
     AND (p.prosrc ILIKE '%INSERT%' OR p.prosrc ILIKE '%UPDATE%' OR p.prosrc ILIKE '%mails%');
  R := R || format('B15 la strategie n''ecrit rien      =%s (0 attendu)', n) || E'\n';
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public' AND p.proname = 'contact_organisation_choisir'
     AND (has_function_privilege('anon', p.oid, 'execute')
       OR has_function_privilege('authenticated', p.oid, 'execute'));
  R := R || format('B15 la strategie est privee        =%s (0 attendu)', n) || E'\n';

  RAISE EXCEPTION E'\n===== BANC MISE EN RELATION =====\n%', R;
END $banc$;
