-- ===========================================================================
-- LE CATALOGUE DES ESCORTS -- DES IDENTITES, PLUS DES TIRAGES (1er octobre 2026)
-- ---------------------------------------------------------------------------
-- CE QUE CE FICHIER REMPLACE. Jusqu'ici, une escort n'etait pas une personne :
-- c'etait un prenom tire au hasard dans une liste et un portrait tire au hasard
-- dans une autre, assembles a l'embauche et perdus au rechargement de la page.
-- Rien ne pouvait donc se souvenir d'elle -- ni le joueur, ni le serveur.
--
-- LA REGLE DE SOCLE QUI COMMANDE CE FICHIER (arbitree le 1er octobre 2026) :
--   « Les mecaniques peuvent etre mutualisees entre les empires. Les contenus
--     ne le sont jamais. Un PNJ n'est jamais mutualise entre plusieurs empires :
--     chaque empire possede son propre casting de personnages. »
-- Ce fichier en est l'application litterale. La MECANIQUE -- cette table, sa RPC,
-- l'ecran d'agence -- est commune aux quatre empires. Le CONTENU -- les lignes --
-- appartient a un empire et a un seul. Republia recoit ses sept identites ici ;
-- Sovarka, El Estado et Al-Khalija recevront les leurs lors de leur propre
-- developpement, par de simples insertions, sans une ligne de code de plus.
--
-- POURQUOI EN BASE ET NON DANS data.js. Le serveur doit valider contre une liste
-- FERMEE l'identite que le navigateur lui transmet, au recrutement comme a la
-- relation sociale. Meme motif que le catalogue legislatif de Seb Lex : la
-- verite est lue en base, le client n'envoie qu'un identifiant. Loger ces
-- identites dans data.js imposerait en plus un miroir a maintenir -- la famille
-- de dettes dont ce projet a deja souffert avec les couts d'ordres et les
-- regles de postes. Ici, il n'y a pas de miroir : il n'y a qu'une source.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. L'AGENCE, QUI EST UN CONTENU ET NON UNE MECANIQUE
-- ---------------------------------------------------------------------------
-- Le nom « Agence Roxane Velours » etait ecrit en dur a SEPT endroits, dont la
-- RPC employe_recruter : une escort embauchee a Novomirsk etait enregistree par
-- le serveur comme relevant d'une agence de Republia. C'est exactement ce que la
-- regle de socle interdit. Le nom devient donc une donnee, propre a l'empire.
create table if not exists public.escorts_agences (
  pays text primary key,
  nom  text not null
);

comment on table public.escorts_agences is
  'Nom de l''agence d''escorts, UN PAR EMPIRE. Contenu, jamais mutualise : Sovarka n''aura pas la meme que Republia. Lu par l''ecran d''agence et par le libelle de role pose au recrutement.';

insert into public.escorts_agences (pays, nom)
values ('republic', 'Agence Roxane Velours')
on conflict (pays) do nothing;

-- ---------------------------------------------------------------------------
-- 2. LES IDENTITES
-- ---------------------------------------------------------------------------
-- `escort_id` est la cle de voute de tout le chantier. C'est elle, et jamais le
-- nom affiche, que porteront le recrutement (l'identifiant d'emploi en derive),
-- la relation sociale (pnj_social_relations.pnj_id) et les regles de jalon.
-- Renommer une escort ne casse donc ni un contrat en cours, ni un souvenir.
--
-- LES DEUX IMAGES SONT OBLIGATOIRES, par decision de game design : le portrait
-- fait partie integrante de l'identite, et le joueur ne doit jamais choisir un
-- simple nom dans une liste. Une identite sans visage serait impossible a
-- presenter : la contrainte NOT NULL rend cet etat IMPOSSIBLE A ENREGISTRER,
-- plutot que detectable apres coup.
create table if not exists public.escorts_catalogue (
  escort_id text    primary key,
  pays      text    not null,
  nom       text    not null,
  genre     text    not null check (genre in ('F', 'H')),
  portrait  text    not null,
  vignette  text    not null,
  -- Cadrage CSS (object-position) du visage dans une image de scene large.
  -- Meme convention que `photoPos` dans data.js. Ajustable sans regenerer
  -- l'image ni rejouer de migration.
  cadrage   text    not null default '50% 15%',
  -- Ordre d'affichage dans le bandeau, AU SEIN D'UN GENRE. Dans une liste on ne
  -- le remarquerait pas ; dans une galerie c'est une mise en scene.
  rang      integer not null default 0,
  actif     boolean not null default true,
  -- Deux escorts homonymes dans un meme empire seraient indiscernables a l'ecran.
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

-- ---------------------------------------------------------------------------
-- 3. LE CASTING DE REPUBLIA -- quatre femmes, trois hommes
-- ---------------------------------------------------------------------------
-- Chemins RELATIFS, servis par Vercel. Les anciennes references pointaient vers
-- raw.githubusercontent.com : un chemin relatif ne depend ni d'un domaine tiers,
-- ni du nom de la branche.
--
-- Les vignettes sont derivees des portraits par reduction (400 px de large,
-- ~35 Ko contre ~2 Mo) : un bandeau de quatre femmes coute ainsi 136 Ko au lieu
-- de 8 Mo. Sans elles, l'ecran serait injouable en connexion ordinaire.
--
-- Natacha et Julien gardent le portrait qu'ils ont deja en jeu. Beatrice et
-- Jean-Philippe recoivent les deux portraits dont les noms de fichier etaient
-- intervertis, corriges le 1er octobre (commit d235eb3). Roxane reprend
-- escort-republic.png, qui ne sert donc plus d'avatar de repli.
insert into public.escorts_catalogue (escort_id, pays, nom, genre, portrait, vignette, cadrage, rang) values
  ('escort_natacha',       'republic', 'Natacha',       'F', 'images/escort-f-1-robe-verte.png',      'images/escort-f-1-robe-verte-vignette.jpg',      '50% 15%', 1),
  ('escort_roxane',        'republic', 'Roxane',        'F', 'images/escort-republic.png',            'images/escort-republic-vignette.jpg',            '50% 15%', 2),
  ('escort_veronique',     'republic', 'Véronique',     'F', 'images/escort-f-2-robe-or.png',         'images/escort-f-2-robe-or-vignette.jpg',         '50% 15%', 3),
  ('escort_beatrice',      'republic', 'Béatrice',      'F', 'images/escort-f-3-robe-marine.png',     'images/escort-f-3-robe-marine-vignette.jpg',     '50% 15%', 4),
  ('escort_julien',        'republic', 'Julien',        'H', 'images/escort-h-1-costume-beige.png',   'images/escort-h-1-costume-beige-vignette.jpg',   '50% 15%', 1),
  ('escort_rodolphe',      'republic', 'Rodolphe',      'H', 'images/escort-h-2-chemise-noire.png',   'images/escort-h-2-chemise-noire-vignette.jpg',   '50% 15%', 2),
  ('escort_jean_philippe', 'republic', 'Jean-Philippe', 'H', 'images/escort-h-3-chemise-ouverte.png', 'images/escort-h-3-chemise-ouverte-vignette.jpg', '50% 15%', 3)
on conflict (escort_id) do nothing;

-- ---------------------------------------------------------------------------
-- 4. FERMETURE
-- ---------------------------------------------------------------------------
-- Les deux tables sont fermees en lecture directe : tout passe par la RPC, qui
-- resout elle-meme l'empire du joueur. Un client ne peut donc pas demander le
-- casting d'un empire ou il ne se trouve pas.
alter table public.escorts_catalogue enable row level security;
alter table public.escorts_agences   enable row level security;
revoke all on table public.escorts_catalogue from public, anon, authenticated;
revoke all on table public.escorts_agences   from public, anon, authenticated;
grant all on table public.escorts_catalogue to service_role;
grant all on table public.escorts_agences   to service_role;

-- ---------------------------------------------------------------------------
-- 5. CE QUE L'ECRAN D'AGENCE A LE DROIT DE SAVOIR
-- ---------------------------------------------------------------------------
-- L'EMPIRE N'EST PAS UN PARAMETRE. Il est resolu par le serveur depuis la
-- position du joueur, jamais transmis par le navigateur. Le lot du 30 septembre
-- a montre le prix de l'erreur inverse : quatre RPC recevaient leur juridiction
-- du client et pouvaient etre appelees en annoncant un empire sans Assemblee.
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
  -- Un empire sans agence est un etat VALIDE : son casting n'est pas encore
  -- ecrit. L'ecran le dira sobrement au lieu d'inventer des personnes.
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

-- ---------------------------------------------------------------------------
-- 6. GARDES
-- ---------------------------------------------------------------------------
DO $garde$
DECLARE n integer; v jsonb;
BEGIN
  SELECT count(*) INTO n FROM public.escorts_catalogue WHERE pays = 'republic';
  IF n <> 7 THEN RAISE EXCEPTION 'casting Republia : % identites, 7 attendues', n; END IF;

  SELECT count(*) INTO n FROM public.escorts_catalogue WHERE pays='republic' AND genre='F';
  IF n <> 4 THEN RAISE EXCEPTION 'casting Republia : % femmes, 4 attendues', n; END IF;

  SELECT count(*) INTO n FROM public.escorts_catalogue WHERE pays='republic' AND genre='H';
  IF n <> 3 THEN RAISE EXCEPTION 'casting Republia : % hommes, 3 attendus', n; END IF;

  -- Deux identites ne peuvent pas se partager un visage : ce serait deux fois la
  -- meme personne sous deux noms.
  SELECT count(*) INTO n FROM (
    SELECT portrait FROM public.escorts_catalogue GROUP BY portrait HAVING count(*) > 1) d;
  IF n <> 0 THEN RAISE EXCEPTION '% portrait(s) partage(s) par plusieurs identites', n; END IF;

  SELECT count(*) INTO n FROM (
    SELECT vignette FROM public.escorts_catalogue GROUP BY vignette HAVING count(*) > 1) d;
  IF n <> 0 THEN RAISE EXCEPTION '% vignette(s) partagee(s) par plusieurs identites', n; END IF;

  -- Aucune identite hors Republia dans ce lot : le perimetre est explicite.
  SELECT count(*) INTO n FROM public.escorts_catalogue WHERE pays <> 'republic';
  IF n <> 0 THEN RAISE EXCEPTION '% identite(s) hors Republia, hors perimetre de ce lot', n; END IF;
END $garde$;
