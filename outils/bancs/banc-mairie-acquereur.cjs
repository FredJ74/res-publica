// Banc : la commune achète un terrain comme un particulier (décision de Fred, 29/10/2026).
// Répétition serveur en transaction annulée (Luthécia, terrain 4) : voir RELAIS.md.
const fs = require('fs'), path = require('path');
const R = path.join(__dirname, '..', '..'), lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const m = lire('migrations/20261029210000_mairie_acquereur_terrain.sql'), c = lire('plateau-terrain-banque.js');
let n = 0, ko = 0; const t = (nom, ok) => { n++; if (!ok) ko++; console.log((ok ? 'ok   ' : 'ECHEC') + ' ' + nom); };
t('serveur : seul le maire elu de la ville du terrain achete pour la commune', (m.match(/poste_id=''maire'' AND c\.city=e->>''city''\) IS DISTINCT FROM moi/g) || []).length === 2);
t('serveur : une commune n emprunte pas', /commune_sans_pret/.test(m));
t('serveur : francs pris dans la caisse de la mairie, PA du maire', /payer_ordre\(moi,ordre,pa,CASE WHEN commune THEN 0 ELSE montant::integer END\)/.test(m) && /caisse_institution_mouvement\(caisse_c,-montant,true\)/.test(m));
t('serveur : caisse resolue par salaire_caisse_de (Luthecia comprise)', /caisse_c:=public\.salaire_caisse_de\(''maire''/.test(m) && /c:=public\.salaire_caisse_de\(''maire'',p_pays,p_ville\)/.test(m));
t('serveur : titre ville:<pays>:<ville> sans coproprietaire', /titulaire_c:=''ville:''\|\|p\.country\|\|'':''/.test(m) && /CASE WHEN commune THEN NULL ELSE conjoint END/.test(m));
t('serveur : chaque fragment remplace doit exister une seule fois', /fragment_introuvable_acquisition_/.test(m));
t('ecran : la question n est posee qu au maire de la ville courante', /p\?\.id==='maire'&&p\?\.city===state\.currentCity/.test(c));
t('ecran : question posee au depot et au compromis', /if\(action==='depot'\|\|action==='compromis'\)\{\s*const qui=await terrainChoisirAcquereur\(\)/.test(c));
t('ecran : acquereur transmis seulement pour la commune', /params=\{\.\.\.params,acquereur:'commune'\}/.test(c));
console.log(`\n${n - ko}/${n} tests passes`); process.exit(ko ? 1 : 0);
