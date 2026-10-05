-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919175153
-- Nom original      : pools_couvertures_quatre_empires
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-19 17:51:53 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 43e46b23188d46d92200d29c8ad35a14
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
-- POOLS DE COUVERTURES — quatre empires, 6 identites masculines et 6 feminines
-- chacun (48 au total). Creation deleguee par le game designer.
--
-- REGLES APPLIQUEES : aucune personnalite reelle ; saveur discrete, jamais au
-- point qu'un nom trahisse un espion -- l'univers est deja peuple de PNJ aux
-- noms legerement appuyes (Martial Bouterin, Ginette Conteneur, Pascal
-- Paguevite), donc une identite trop sage detonnerait autant qu'une blague.
-- Les quatre VRAIES identites sont interdites de pool. Les deux couvertures
-- prototypes deja utilisees sont conservees : José Bayamoréna (El Estado) et
-- Foued Al-Khali (Al-Khalija).

ALTER TABLE public.renseignement_couvertures
  ADD COLUMN IF NOT EXISTS sexe text CHECK (sexe IN ('H', 'F'));
ALTER TABLE public.renseignement_identites_reelles
  ADD COLUMN IF NOT EXISTS sexe text CHECK (sexe IN ('H', 'F'));

UPDATE public.renseignement_identites_reelles SET sexe = 'F' WHERE role = 'conseiller';
UPDATE public.renseignement_identites_reelles SET sexe = 'H' WHERE role IN ('traducteur','garde','coordinateur');

INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES
  -- REPUBLIA — francophones ordinaires et credibles
  ('republic','Lucien Marchand','H'),   ('republic','Gilbert Ferrand','H'),
  ('republic','Émile Sauvageot','H'),   ('republic','Roland Quesnel','H'),
  ('republic','Damien Lavigne','H'),    ('republic','Hubert Toussaint','H'),
  ('republic','Solange Bertrand','F'),  ('republic','Madeleine Ferrier','F'),
  ('republic','Régine Delcourt','F'),   ('republic','Josiane Marteau','F'),
  ('republic','Colette Vasseur','F'),   ('republic','Henriette Pommier','F'),
  -- SOVARKA — coherence patronymique slave/sovarkienne, entierement fictive
  ('soviet','Piotr Zabline','H'),       ('soviet','Guennadi Vostrov','H'),
  ('soviet','Mikhaïl Sourenko','H'),    ('soviet','Arkadi Lemenov','H'),
  ('soviet','Vassili Tchoudine','H'),   ('soviet','Iouri Bratsev','H'),
  ('soviet','Lioudmila Vareneva','F'),  ('soviet','Zoïa Malinova','F'),
  ('soviet','Nadia Berestova','F'),     ('soviet','Irina Soulkova','F'),
  ('soviet','Tatiana Ovreïko','F'),     ('soviet','Galina Stroumina','F'),
  -- EL ESTADO — hispanophones fictifs (José Bayamoréna conserve)
  ('narco','José Bayamoréna','H'),      ('narco','Ramón Delgadillo','H'),
  ('narco','Aurelio Pinzón','H'),       ('narco','Nicolás Berruga','H'),
  ('narco','Teodoro Escalante','H'),    ('narco','Ignacio Vidalba','H'),
  ('narco','Remedios Caldera','F'),     ('narco','Pilar Monterroso','F'),
  ('narco','Dolores Vaquerín','F'),     ('narco','Amparo Riestra','F'),
  ('narco','Consuelo Barranco','F'),    ('narco','Esperanza Ordóñez','F'),
  -- AL-KHALIJA — arabophones fictifs (Foued Al-Khali conserve)
  ('khalija','Foued Al-Khali','H'),     ('khalija','Nabil Ben Azzouz','H'),
  ('khalija','Slimane Al-Faridi','H'),  ('khalija','Tarek Ben Hazem','H'),
  ('khalija','Mourad Al-Chennoui','H'), ('khalija','Rachid Ben Tayeb','H'),
  ('khalija','Samira Al-Zahiri','F'),   ('khalija','Leïla Ben Jaloud','F'),
  ('khalija','Nadjma Al-Harouni','F'),  ('khalija','Houda Ben Sassi','F'),
  ('khalija','Yasmina Al-Dibani','F'),  ('khalija','Farida Ben Mokhtar','F')
ON CONFLICT (pays, nom) DO UPDATE SET sexe = EXCLUDED.sexe;

-- Garde-fou structurel : une vraie identite ne peut jamais entrer dans un pool.
DELETE FROM public.renseignement_couvertures c
 WHERE EXISTS (SELECT 1 FROM public.renseignement_identites_reelles i
                WHERE i.vrai_nom = c.nom);
