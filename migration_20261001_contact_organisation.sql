-- ===========================================================================
-- METTRE EN RELATION, SANS RIEN SAVOIR (1er octobre 2026)
-- ---------------------------------------------------------------------------
-- CE QUE FAIT PAT HOUNETTE, ET CE QU'IL NE FAIT PAS. Il ne recrute personne, ne
-- negocie rien, ne transmet aucun detail. Il envoie un message a quelqu'un, et
-- s'arrete la. Toute la mecanique ci-dessous est construite autour de ce vide :
-- c'est lui qui la rend robuste.
--
-- LA GARANTIE N'EST PAS UNE PROMESSE, C'EST UNE SIGNATURE. Le joueur raconte son
-- projet a Pat (« C'est quoi ton projet ? T'as besoin de quoi ? »). Ce texte ne
-- doit jamais etre conserve ni retransmis. On ne s'est donc pas contente de ne
-- pas l'ecrire : contact_organisation_demander() N'A PAS DE PARAMETRE pour le
-- recevoir. Le texte ne quitte pas le navigateur, parce qu'aucune porte ne
-- s'ouvre pour lui. Une regle qu'on pourrait oublier d'appliquer a ete remplacee
-- par une forme qui ne permet pas de l'enfreindre.
--
-- POURQUOI C'EST GENERIQUE ALORS QU'IL N'Y A QU'UN PASSEUR. Les noms ne parlent
-- ni de Pat ni du crime : un PASSEUR met en relation avec un TYPE
-- d'organisation. Le jour ou un autre empire aura son propre intermediaire -- la
-- regle de socle interdit de reutiliser Pat ailleurs qu'a Republia -- il suffira
-- d'une ligne dans contacts_organisations_passeurs. Aucune mecanique criminelle
-- n'est touchee ici, et aucune n'est supposee exister : ce fichier ne connait
-- que des organisations, des membres et des courriers.
--
-- CE QUI N'EST PAS ICI. Aucun cron. Le game design dit « Si t'as rien dans trois
-- jours, tu reviens me voir » : c'est le retour du joueur qui declenche
-- l'organisation suivante, pas une passe nocturne. Rien ne tourne quand personne
-- ne demande rien.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. QUI PEUT METTRE EN RELATION -- liste fermee
-- ---------------------------------------------------------------------------
-- Sans cette table, un client pourrait reclamer une mise en relation au nom de
-- n'importe quel PNJ, et obtenir un courrier signe de lui. La liste porte aussi
-- le `pays` : un passeur appartient a un empire, comme tout personnage.
--
-- `expediteur` est le nom affiche dans la boite du destinataire. Il est stocke
-- ici plutot que deduit de l'identifiant : rien, en base, ne sait traduire
-- 'pat_hounette' en « Pat Hounette », et le deviner serait inventer.
create table if not exists public.contacts_organisations_passeurs (
  passeur           text not null,
  type_organisation text not null,
  pays              text not null,
  expediteur        text not null,
  primary key (passeur, type_organisation)
);

comment on table public.contacts_organisations_passeurs is
  'Liste FERMEE des PNJ capables de mettre un joueur en relation avec une organisation, et avec quel type. Un passeur appartient a un empire : la regle de socle interdit de partager un personnage entre plusieurs empires.';

insert into public.contacts_organisations_passeurs (passeur, type_organisation, pays, expediteur) values
  ('pat_hounette', 'criminelle', 'republic', 'Pat Hounette')
on conflict (passeur, type_organisation) do nothing;

-- ---------------------------------------------------------------------------
-- 2. CE QUE LE PASSEUR A DEJA FAIT POUR CE JOUEUR
-- ---------------------------------------------------------------------------
-- Deux informations, pas une de plus : QUAND il a envoye son dernier message, et
-- QUELLES organisations il a deja sollicitees. La premiere porte le refus de
-- trois jours, la seconde l'escalade vers l'organisation suivante.
--
-- Ce qui n'y figure pas : le projet du joueur, ce dont il a besoin, ce qu'il a
-- repondu. Rien de tout cela n'arrive jusqu'ici (voir l'en-tete).
create table if not exists public.contacts_organisations (
  joueur                   text        not null,
  passeur                  text        not null,
  type_organisation        text        not null,
  derniere_demande         timestamptz not null default now(),
  -- Tableau JSON d'identifiants d'organisations, dans l'ordre de sollicitation.
  organisations_contactees jsonb       not null default '[]'::jsonb,
  primary key (joueur, passeur, type_organisation)
);

comment on table public.contacts_organisations is
  'Etat d''une mise en relation : date de la derniere demande (porte le refus de trois jours) et organisations deja sollicitees (porte l''escalade vers la suivante). Ne contient AUCUNE donnee sur le projet du joueur -- la RPC qui ecrit ici n''a aucun parametre pour en recevoir.';

alter table public.contacts_organisations_passeurs enable row level security;
alter table public.contacts_organisations          enable row level security;
revoke all on table public.contacts_organisations_passeurs from public, anon, authenticated;
revoke all on table public.contacts_organisations          from public, anon, authenticated;
grant all on table public.contacts_organisations_passeurs to service_role;
grant all on table public.contacts_organisations          to service_role;

-- ---------------------------------------------------------------------------
-- 2 bis. LIRE UN BLOB ECRIT PAR UN NAVIGATEUR
-- ---------------------------------------------------------------------------
-- `organisations.data` est du TEXTE produit par JSON.stringify cote client. Un
-- `data::jsonb` direct leverait une exception sur une seule ligne malformee -- et
-- cette exception ferait tomber la mise en relation POUR TOUT LE MONDE, pas
-- seulement pour l'organisation fautive. PostgreSQL n'offrant pas de cast
-- tolerant, on en pose un : la ligne illisible est simplement ignoree.
--
-- Nomme comme les deux helpers jsonb_* deja presents, et deliberement generique :
-- toute lecture serveur d'un blob client a le meme besoin.
create or replace function public.jsonb_ou_null(p_texte text)
returns jsonb
language plpgsql
immutable
as $fn$
BEGIN
  RETURN p_texte::jsonb;
EXCEPTION WHEN others THEN
  RETURN NULL;
END;
$fn$;

comment on function public.jsonb_ou_null(text) is
  'Cast tolerant texte -> jsonb : rend NULL au lieu de lever si le texte n''est pas du JSON. Pour lire un blob ecrit par un navigateur sans qu''une seule ligne malformee fasse tomber toute une mecanique.';

revoke all on function public.jsonb_ou_null(text) from public, anon;
grant execute on function public.jsonb_ou_null(text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. PAT ACCEPTE-T-IL D'EN REPARLER ? -- lecture seule
-- ---------------------------------------------------------------------------
-- Appelee au clic, AVANT que Pat ne pose ses questions. Sans elle, il demanderait
-- « C'est quoi ton projet ? » puis refuserait : le game design veut qu'il refuse
-- tout de suite (« Je t'ai dit trois jours... t'es sourd ou quoi ? »).
--
-- Elle n'autorise rien. Le delai est retranche une seconde fois, pour de vrai,
-- dans contact_organisation_demander() : un client qui mentirait ici n'y
-- gagnerait rien.
create or replace function public.contact_organisation_etat(
  p_passeur text, p_type_organisation text)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_moi text; v_e record; v_restant integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  IF NOT EXISTS (SELECT 1 FROM public.contacts_organisations_passeurs p
                  WHERE p.passeur = p_passeur AND p.type_organisation = p_type_organisation) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'passeur_inconnu'); END IF;

  SELECT * INTO v_e FROM public.contacts_organisations c
   WHERE c.joueur = v_moi AND c.passeur = p_passeur
     AND c.type_organisation = p_type_organisation;

  IF v_e IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'peut_demander', true,
                              'jours_restants', 0, 'deja_contactees', 0); END IF;

  -- Arrondi au jour SUPERIEUR : a 2 jours et 3 heures, il reste « un jour ».
  v_restant := greatest(0, ceil(extract(epoch from
                 (v_e.derniere_demande + interval '3 days') - now()) / 86400.0)::integer);

  RETURN jsonb_build_object(
    'ok', true,
    'peut_demander', (now() >= v_e.derniere_demande + interval '3 days'),
    'jours_restants', v_restant,
    'deja_contactees', jsonb_array_length(v_e.organisations_contactees));
END;
$fn$;

comment on function public.contact_organisation_etat(text, text) is
  'Ce passeur accepte-t-il une nouvelle demande de ce joueur, et depuis combien de temps ? Lecture seule, sous le jeton du joueur. N''autorise rien : le delai est retranche pour de vrai dans contact_organisation_demander().';

-- ---------------------------------------------------------------------------
-- 3 bis. QUELLE ORGANISATION ? -- la STRATEGIE, isolee
-- ---------------------------------------------------------------------------
-- POURQUOI CETTE FONCTION EXISTE SEULE. Repondre « laquelle ? » et « que se
-- passe-t-il ensuite ? » sont deux questions distinctes, et seule la premiere est
-- susceptible de changer. Le jour ou la selection regardera l'activite recente, la
-- reputation ou la proximite, c'est CE CORPS et lui seul qui changera : la mise en
-- relation, le courrier, le delai et l'escalade n'en savent rien.
--
-- LA STRATEGIE D'AUJOURD'HUI, ET LA RAISON QUI LA JUSTIFIE. La plus nombreuse,
-- aucun autre critere. Ce n'est pas une recherche d'equite entre organisations --
-- c'est assume : le but est de maximiser la probabilite qu'un nouveau joueur
-- obtienne vite une reponse HUMAINE. L'experience du joueur passe avant la
-- repartition des sollicitations. Quiconque remplacera ce corps devra donc dire
-- quel objectif il poursuit a la place.
--
-- POURQUOI `p_joueur` EST LA ALORS QUE RIEN NE LE LIT. Une strategie de proximite
-- aurait besoin de son empire, une strategie de reputation de son passe. Si la
-- signature ne les prevoyait pas, changer de strategie forcerait a changer AUSSI
-- l'appelant -- precisement ce que cette extraction doit eviter. Le parametre est
-- donc un point d'extension, et son inutilite actuelle est volontaire.
--
-- CE QU'ELLE NE FAIT PAS : elle n'ecrit rien, n'envoie rien, ne verrouille rien.
-- STABLE, et interdite au client comme au joueur : la strategie du jeu n'est pas
-- une information publique.
--
-- Rend un objet { id, nom, chef, membres }, ou NULL s'il n'y a personne a
-- solliciter -- un etat VALIDE, pas une erreur.
create or replace function public.contact_organisation_choisir(
  p_joueur text, p_type_organisation text, p_exclues jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_r jsonb;
BEGIN
  -- `organisations.data` est un blob JSON ecrit par le client : on le lit, on n'y
  -- ecrit rien, et on ne suppose la presence d'aucune cle (coalesce partout).
  --
  -- Une organisation SANS CHEF est ecartee ici et non par l'appelant : il n'y a
  -- personne a qui ecrire, donc ce n'est pas un choix valide -- c'est une question
  -- de selection, pas d'envoi.
  --
  -- A nombre de membres egal, l'identifiant tranche. Ce n'est pas un critere de
  -- jeu : c'est la seule facon de rendre le resultat reproductible plutot que
  -- dependant du plan d'execution.
  SELECT jsonb_build_object(
           'id',      o.id,
           'nom',     coalesce(d->>'nom', 'une organisation'),
           'chef',    d->>'chef',
           'membres', jsonb_array_length(coalesce(d->'membres', '[]'::jsonb)))
    INTO v_r
    FROM public.organisations o
    CROSS JOIN LATERAL (SELECT public.jsonb_ou_null(o.data) AS d) j
   WHERE d IS NOT NULL
     AND d->>'type' = p_type_organisation
     AND coalesce(d->>'chef', '') <> ''
     AND NOT (coalesce(p_exclues, '[]'::jsonb) ? o.id)
   ORDER BY jsonb_array_length(coalesce(d->'membres', '[]'::jsonb)) DESC, o.id ASC
   LIMIT 1;
  RETURN v_r;
END;
$fn$;

comment on function public.contact_organisation_choisir(text, text, jsonb) is
  'STRATEGIE DE SELECTION, isolee pour pouvoir changer seule : quelle organisation du type demande solliciter, en excluant celles deja contactees. Aujourd''hui la plus nombreuse -- non par equite, mais pour maximiser la chance d''une reponse humaine rapide. `p_joueur` est un point d''extension (proximite, reputation) que la strategie actuelle ignore volontairement. N''ecrit rien. Rend NULL s''il n''y a personne a solliciter, ce qui est un etat valide.';

revoke all on function public.contact_organisation_choisir(text, text, jsonb) from public, anon, authenticated;
grant execute on function public.contact_organisation_choisir(text, text, jsonb) to service_role;

-- ---------------------------------------------------------------------------
-- 4. LA MISE EN RELATION
-- ---------------------------------------------------------------------------
-- CE QU'ELLE N'A PAS COMME PARAMETRE : le projet du joueur. C'est la garantie
-- centrale du chantier, et elle tient a cette signature.
--
-- AUCUN FILTRAGE. Le game design est explicite : tout joueur peut demander cette
-- mise en relation, et Pat ne juge personne. Pas de caracteristique requise, pas
-- de reputation, pas de quete prealable, pas de cout.
--
-- ELLE NE CHOISIT PAS L'ORGANISATION, elle la DEMANDE a
-- contact_organisation_choisir(). Cette fonction-ci porte ce qui ne changera pas --
-- le delai, le courrier, l'escalade, la trace -- et ignore entierement selon quel
-- critere l'organisation a ete retenue.
create or replace function public.contact_organisation_demander(
  p_passeur text, p_type_organisation text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  v_moi     text;
  v_passeur record;
  v_e       record;
  v_orga    jsonb;
  v_nom     text;
  v_corps   text;
  v_id      text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_passeur FROM public.contacts_organisations_passeurs p
   WHERE p.passeur = p_passeur AND p.type_organisation = p_type_organisation;
  IF v_passeur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'passeur_inconnu'); END IF;

  -- Verrou sur la ligne d'etat : deux clics simultanes ne doivent pas solliciter
  -- deux organisations d'un coup, ni deux fois la meme.
  SELECT * INTO v_e FROM public.contacts_organisations c
   WHERE c.joueur = v_moi AND c.passeur = p_passeur
     AND c.type_organisation = p_type_organisation
     FOR UPDATE;

  IF v_e IS NOT NULL AND now() < v_e.derniere_demande + interval '3 days' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_non_ecoule',
             'jours_restants', greatest(1, ceil(extract(epoch from
               (v_e.derniere_demande + interval '3 days') - now()) / 86400.0)::integer)); END IF;

  -- LA STRATEGIE EST AILLEURS. Tout ce que cette fonction sait, c'est qu'il faut
  -- une organisation de ce type que ce joueur n'a pas encore sollicitee ; selon
  -- quel critere elle est retenue ne la concerne pas.
  v_orga := public.contact_organisation_choisir(
              v_moi, p_type_organisation,
              coalesce(v_e.organisations_contactees, '[]'::jsonb));

  IF v_orga IS NULL THEN
    -- Rien a solliciter : soit aucune organisation de ce type n'existe, soit
    -- toutes ont deja ete contactees. Le delai de trois jours N'EST PAS consomme
    -- -- Pat n'a envoye aucun message, il n'a aucune raison de faire attendre.
    RETURN jsonb_build_object('ok', false, 'raison',
             CASE WHEN v_e IS NULL OR jsonb_array_length(v_e.organisations_contactees) = 0
                  THEN 'aucune_organisation' ELSE 'toutes_contactees' END); END IF;

  -- LE MESSAGE EST MINIMAL, ET C'EST VOULU. Rien du projet, rien du besoin : le
  -- nom du joueur, et une invitation a le contacter.
  --
  -- LE BOUTON NE VOYAGE PAS DANS LE HTML. Le corps porte un MARQUEUR TEXTUEL
  -- inerte, '[[act:ecrire_a|<nom>]]', que les deux sanitisations du client
  -- laissent passer et que forum.js transforme en vrai bouton a partir de sa
  -- table blanche ACTIONS_MAIL. Format identique a marqueurActionMail() cote
  -- navigateur, separateurs retires du nom pour la meme raison qu'elle le fait :
  -- un nom exotique ne doit pouvoir ni casser ni etendre le marqueur. Le banc
  -- .scratch/banc_contact_organisation.py verifie que les deux formats
  -- concordent encore.
  v_nom   := regexp_replace(v_moi, '[|\[\]]', '', 'g');
  v_corps := 'J''ai rencontré quelqu''un qui cherche un service. Contacte '
          || v_nom || ' de ma part.' || chr(10) || chr(10)
          || '[[act:ecrire_a|' || v_nom || ']]';

  -- Insertion directe, comme toutes les RPC joueur de ce jeu qui notifient un
  -- tiers (voir militaire_candidature_accepter) : mail_systeme_envoyer exige
  -- est_appel_serveur() et refuserait un appel venu d'un navigateur.
  v_id := 'co-' || (extract(epoch from clock_timestamp()) * 1000)::bigint
               || '-' || substr(md5(random()::text), 1, 6);
  INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
  VALUES (v_id, v_passeur.expediteur, (v_orga->>'chef'), 'Quelqu''un à contacter', v_corps,
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'), false);

  INSERT INTO public.contacts_organisations
         (joueur, passeur, type_organisation, derniere_demande, organisations_contactees)
  VALUES (v_moi, p_passeur, p_type_organisation, now(), jsonb_build_array(v_orga->>'id'))
  ON CONFLICT (joueur, passeur, type_organisation) DO UPDATE
     SET derniere_demande = now(),
         organisations_contactees =
           public.contacts_organisations.organisations_contactees || jsonb_build_array(v_orga->>'id');

  -- CE QUI EST RENDU AU CLIENT NE NOMME PAS L'ORGANISATION. Pat ne transmet aucun
  -- detail, dans les deux sens : le joueur ne doit pas apprendre qui a ete
  -- sollicite. Le rang sert seulement a savoir qu'il y a eu escalade.
  RETURN jsonb_build_object('ok', true, 'rang',
           coalesce(jsonb_array_length(v_e.organisations_contactees), 0) + 1);
END;
$fn$;

comment on function public.contact_organisation_demander(text, text) is
  'Un passeur envoie un message a l''organisation du type demande comptant le plus de membres, jamais encore sollicitee pour ce joueur. Aucun filtrage : tout joueur peut demander. N''A AUCUN PARAMETRE pour le projet du joueur, et c''est la garantie que rien n''en est conserve. Ne nomme pas l''organisation dans sa reponse.';

revoke all on function public.contact_organisation_etat(text, text)      from public, anon;
revoke all on function public.contact_organisation_demander(text, text)  from public, anon;
grant execute on function public.contact_organisation_etat(text, text)     to authenticated, service_role;
grant execute on function public.contact_organisation_demander(text, text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. GARDES
-- ---------------------------------------------------------------------------
DO $garde$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.contacts_organisations_passeurs;
  IF n < 1 THEN RAISE EXCEPTION 'aucun passeur declare'; END IF;
  SELECT count(*) INTO n FROM public.contacts_organisations_passeurs WHERE pays IS NULL;
  IF n <> 0 THEN RAISE EXCEPTION '% passeur(s) sans empire', n; END IF;
  -- Les deux RPC doivent etre fermees a anon : une mise en relation engage un
  -- personnage, elle n'existe pas sans joueur authentifie.
  SELECT count(*) INTO n FROM pg_proc p
    JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public'
     AND p.proname IN ('contact_organisation_etat', 'contact_organisation_demander')
     AND has_function_privilege('anon', p.oid, 'execute');
  IF n <> 0 THEN RAISE EXCEPTION '% RPC de mise en relation encore ouverte(s) a anon', n; END IF;
END $garde$;
