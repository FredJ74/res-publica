// Banc : logements sociaux communaux du socle (décisions de Fred, 29/10/2026).
// Répétition serveur en transaction annulée (terrain 4 de Luthécia) : voir RELAIS.md.
const vm = require('vm'), fs = require('fs'), path = require('path');
const R = path.join(__dirname, '..', '..'), lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const m = lire('migrations/20261029220000_logements_sociaux_communaux.sql');
const je = lire('plateau-justice-economie.js'), ch = lire('plateau-chantiers.js'), ls = lire('plateau-logements-sociaux.js'), rt = lire('plateau-router.js');
let n = 0, ko = 0; const t = (nom, ok) => { n++; if (!ok) ko++; console.log((ok ? 'ok   ' : 'ECHEC') + ' ' + nom); };
t('trois paliers au bareme commun (12/18/24 jours, 5 000 FR/jour)', /'logements_petit','Logements sociaux — petit bâtiment',12/.test(m) && /'logements_moyen',[^)]*,18\)/.test(m) && /'logements_barre',[^)]*,24\)/.test(m) && /v\.j\*5000/.test(m));
t('4 / 6 / 10 appartements, moitie petits (30 FR) moitie grands (60 FR)', /WHEN 'logements_petit' THEN 4 WHEN 'logements_moyen' THEN 6 WHEN 'logements_barre' THEN 10/.test(m) && /'loyer',30,'logementSocial',true,'bonusMoralSommeil',3,'bonusSanteSommeil',4/.test(m) && /'loyer',60,'logementSocial',true,'bonusMoralSommeil',5,'bonusSanteSommeil',7/.test(m));
t('permis reserve a la commune', /logements_reserves_commune/.test(m) && /LIKE ''ville:%''|LIKE 'ville:%'/.test(m));
t('surface : moyen des 2 000 m2, barre au-dela de 2 200 m2', /logements_moyen'' AND coalesce\(\(etat->>''surface''\)::numeric,0\)<2000/.test(m) && /logements_barre'' AND coalesce\(\(etat->>''surface''\)::numeric,0\)<=2200/.test(m));
t('le maire elu depose le permis d un terrain de la commune', /etat->>''proprietaire''=''ville:''\|\|pays\|\|'':''\|\|ville AND \(SELECT c\.data::jsonb->>''eluId''/.test(m));
t('pas de location directe d un logement social', /logement_attribue_par_adjoint/.test(m));
t('loyer social interdit par la porte des lots du titulaire', /loyer_fixe_par_adjoint/.test(m));
t('attribution, loyer et tableau reserves a l adjoint atteste', (m.match(/public\.logements_sociaux_ville_adjoint\(moi\)/g) || []).length === 3 && /poste_est_atteste\(d\.name,d\.poste,d\.country\)/.test(m));
t('chaque changement de loyer est historise', /'acte','loyer_social','acteur',moi,'lot',p_lot,'ancien',ancien,'nouveau',p_loyer/.test(m));
t('demande : residence, une seule en attente, 1 PA', /residence_requise/.test(m) && /demande_deja_en_cours/.test(m) && /payer_ordre\(moi, 'demander_logement_social', 1, 0\)/.test(m));
t('fragments remplaces une seule fois', (m.match(/fragment_introuvable_/g) || []).length >= 7);
const pc = lire('migrations/20261029222000_permis_commune_par_caisse.sql');
t('permis d un terrain de la commune paye par la caisse de la mairie, PA du maire', /ELSIF etat->>''proprietaire''=''ville:''\|\|pays\|\|'':''\|\|ville THEN paiement:=public\.permis_commune_payer_interne/.test(pc) && /caisse_institution_mouvement\(caisse, -100, true\)/.test(pc) && /SET pa = pa - 1/.test(pc));
t('caisse insuffisante : rien n est preleve', /IF coalesce\(solde,0\) < 100 THEN RETURN jsonb_build_object\('ok',false,'raison','caisse_communale_insuffisante'\); END IF;\s*UPDATE public\.personnages_donnees SET pa/.test(pc));
const rd = lire('migrations/20261029223000_logements_sociaux_resiliation_domicile.sql');
t('depart de la ville : baux sociaux hors nouvelle ville resilies, appartement libere', /AFTER UPDATE OF domicile ON public\.personnages_donnees/.test(rd) && /data->>'logementSocial' = 'true'/.test(rd) && /'acte','resiliation_depart'/.test(rd));
t('attribution refusee a un demandeur qui n habite plus la ville', /demandeur_non_resident/.test(rd)
  && m.includes("  idb := t.country||':'||t.building_id||':lot_dyn_'||regexp_replace(p_lot,'[^A-Za-z0-9_-]','_','g')||':'||ville;\n  SELECT coalesce(day,1) INTO jour"));
// Écran
const ctx = { window: {}, console, document: {}, localStorage: { getItem() {} } }; vm.createContext(ctx);
vm.runInContext(ch, ctx); const D = vm.runInContext('DUREES_CONSTRUCTION', ctx);
t('ecran : durees 12/18/24', D.logements_petit === 12 && D.logements_moyen === 18 && D.logements_barre === 24);
t('ecran : paliers proposes seulement si palierProposable (permis et construction)', (je.match(/if \(!palierProposable\(key, ts(Permis)?\)\) return;/g) || []).length === 2);
t('ecran : seuils de surface 0 / 2000 / 2201', /logements_petit:[^\n]*surfaceMin: 0 \}/.test(je) && /logements_moyen:[^\n]*surfaceMin: 2000 \}/.test(je) && /logements_barre:[^\n]*surfaceMin: 2201 \}/.test(je));
t('ecran : un logement social n est pas propose a la location libre', /l\.destination !== 'logement_social'/.test(je));
t('ecran : ordres routes vers le socle', /demanderLogementSocialCommun\(pa, cost\)/.test(rt) && /ouvrirTableauLogementsSociaux\(\)/.test(rt));
t('ecran : tableau de bord (loyer par appartement, attribution)', /logement_social_loyer_fixer/.test(ls) && /logement_social_attribuer/.test(ls) && /logements_sociaux_tableau/.test(ls));
console.log(`\n${n - ko}/${n} tests passes`); process.exit(ko ? 1 : 0);
