-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260930223042
-- Nom original      : escorts_catalogue_identites
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-30 22:30:42 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 9fbcb9b290d56f3073c10e20b8e02ae5
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
create table if not exists public.escorts_agences (
  pays text primary key,
  nom  text not null
);

comment on table public.escorts_agences is
  'Nom de l''agence d''escorts, UN PAR EMPIRE. Contenu, jamais mutualise : Sovarka n''aura pas la meme que Republia. Lu par l''ecran d''agence et par le libelle de role pose au recrutement.';

insert into public.escorts_agences (pays, nom)
values ('republic', 'Agence Roxane Velours')
on conflict (pays) do nothing;

create table if not exists public.escorts_catalogue (
  escort_id text    primary key,
  pays      text    not null,
  nom       text    not null,
  genre     text    not null check (genre in ('F', 'H')),
  portrait  text    not null,
  vignette  text    not null,
  cadrage   text    not null default '50% 15%',
  rang      integer not null default 0,
  actif     boolean not null default true,
  unique (pays, nom)
);

comment on table public.escorts_catalogue is
  'Les identites d''escorts, une ligne par personnage et par empire. Source unique du nom, du genre et des deux images : plus aucun tirage aleatoire. `escort_id` est stable et porte le recrutement, la relation sociale et les jalons -- le nom affiche peut changer sans rien casser.';

comment on column public.escorts_catalogue.escort_id is
  'Identite stable. Ne se renomme jamais, ne se reutilise jamais : un emploi et une memoire en dependent.';
comment on column public.escorts_catalogue.pays is
  'Empire proprietaire du personnage. Une escort n''existe QUE dans son empire (regle de socle du 1er octobre 2026).';

create index if not exists escorts_catalogue_ecran
  on public.escorts_catalogue (pays, genre, actif, rang);

insert into public.escorts_catalogue (escort_id, pays, nom, genre, portrait, vignette, cadrage, rang) values
  ('escort_natacha',       'republic', 'Natacha',       'F', 'images/escort-f-1-robe-verte.png',      'images/escort-f-1-robe-verte-vignette.jpg',      '50% 15%', 1),
  ('escort_roxane',        'republic', 'Roxane',        'F', 'images/escort-republic.png',            'images/escort-republic-vignette.jpg',            '50% 15%', 2),
  ('escort_veronique',     'republic', 'Véronique',     'F', 'images/escort-f-2-robe-or.png',         'images/escort-f-2-robe-or-vignette.jpg',         '50% 15%', 3),
  ('escort_beatrice',      'republic', 'Béatrice',      'F', 'images/escort-f-3-robe-marine.png',     'images/escort-f-3-robe-marine-vignette.jpg',     '50% 15%', 4),
  ('escort_julien',        'republic', 'Julien',        'H', 'images/escort-h-1-costume-beige.png',   'images/escort-h-1-costume-beige-vignette.jpg',   '50% 15%', 1),
  ('escort_rodolphe',      'republic', 'Rodolphe',      'H', 'images/escort-h-2-chemise-noire.png',   'images/escort-h-2-chemise-noire-vignette.jpg',   '50% 15%', 2),
  ('escort_jean_philippe', 'republic', 'Jean-Philippe', 'H', 'images/escort-h-3-chemise-ouverte.png', 'images/escort-h-3-chemise-ouverte-vignette.jpg', '50% 15%', 3)
on conflict (escort_id) do nothing;

alter table public.escorts_catalogue enable row level security;
alter table public.escorts_agences   enable row level security;
revoke all on table public.escorts_catalogue from public, anon, authenticated;
revoke all on table public.escorts_agences   from public, anon, authenticated;
grant all on table public.escorts_catalogue to service_role;
grant all on table public.escorts_agences   to service_role;

create or replace function public.escorts_agence()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_moi text; v_pays text; v_agence text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;

  SELECT nom INTO v_agence FROM public.escorts_agences WHERE pays = v_pays;
  IF v_agence IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'agence', NULL,
                              'escorts', '[]'::jsonb); END IF;

  RETURN jsonb_build_object(
    'ok', true, 'pays', v_pays, 'agence', v_agence,
    'escorts', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
               'escort_id', c.escort_id, 'nom', c.nom, 'genre', c.genre,
               'portrait', c.portrait, 'vignette', c.vignette, 'cadrage', c.cadrage)
             ORDER BY c.genre, c.rang, c.nom)
        FROM public.escorts_catalogue c
       WHERE c.pays = v_pays AND c.actif), '[]'::jsonb));
END;
$fn$;

comment on function public.escorts_agence() is
  'Le casting d''escorts de l''empire OU SE TROUVE le joueur, et le nom de l''agence qui l''emploie. L''empire est resolu au serveur depuis la position du joueur, jamais transmis par le navigateur. Un empire sans casting rend une liste vide -- etat valide, pas une erreur.';

revoke all on function public.escorts_agence() from public, anon;
grant execute on function public.escorts_agence() to authenticated, service_role;

DO $garde$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.escorts_catalogue WHERE pays = 'republic';
  IF n <> 7 THEN RAISE EXCEPTION 'casting Republia : % identites, 7 attendues', n; END IF;
  SELECT count(*) INTO n FROM public.escorts_catalogue WHERE pays='republic' AND genre='F';
  IF n <> 4 THEN RAISE EXCEPTION 'casting Republia : % femmes, 4 attendues', n; END IF;
  SELECT count(*) INTO n FROM public.escorts_catalogue WHERE pays='republic' AND genre='H';
  IF n <> 3 THEN RAISE EXCEPTION 'casting Republia : % hommes, 3 attendus', n; END IF;
  SELECT count(*) INTO n FROM (
    SELECT portrait FROM public.escorts_catalogue GROUP BY portrait HAVING count(*) > 1) d;
  IF n <> 0 THEN RAISE EXCEPTION '% portrait(s) partage(s) par plusieurs identites', n; END IF;
  SELECT count(*) INTO n FROM (
    SELECT vignette FROM public.escorts_catalogue GROUP BY vignette HAVING count(*) > 1) d;
  IF n <> 0 THEN RAISE EXCEPTION '% vignette(s) partagee(s) par plusieurs identites', n; END IF;
  SELECT count(*) INTO n FROM public.escorts_catalogue WHERE pays <> 'republic';
  IF n <> 0 THEN RAISE EXCEPTION '% identite(s) hors Republia, hors perimetre de ce lot', n; END IF;
END $garde$;