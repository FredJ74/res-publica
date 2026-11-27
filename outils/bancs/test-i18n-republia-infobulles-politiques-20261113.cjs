'use strict';
// Contrôle déterministe du premier lot de descriptions politiques propres à Républia.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..'),read=f=>fs.readFileSync(path.join(root,f),'utf8');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
const evalFn=(src,name)=>{const a=src.indexOf('function '+name+'(');const b=src.indexOf('\n}',a);assert.ok(a>=0&&b>a,name);return src.slice(a,b+2)};
const source=read('plateau-politique.js'),data=read('data.js');
function setup(country='republic',lang='en'){
 const context={RP_I18N_GAME_ENABLED:true,RPPlateauI18n:{language:()=>context.lang},lang};
 context.window=context;vm.createContext(context);
 vm.runInContext('var state = {country:'+JSON.stringify(country)+'};',context);
 vm.runInContext(evalFn(source,'deviseDansTexte'),context);
 vm.runInContext(evalFn(data,'montantDansTexte'),context);
 for(const f of ['i18n/infobulles-communes-resources.js','i18n/republia-infobulles-resources.js','i18n/sovarka-infobulles-resources.js'])vm.runInContext(read(f),context,{filename:f});
 return context;
}
function orderDescs(country){
 const context={console,document:{getElementById(){return null},addEventListener(){},querySelector(){return null}},localStorage:{getItem(){return null}},state:{country}};
 context.window=context;vm.createContext(context);
 vm.runInContext(data.replace(/^const (WORLD|BUILDINGS) =/mg,'var $1 ='),context);
 const d=new Set();
 for(const city of Object.values(context.WORLD[country]||{}))for(const b of city.buildings||[]){
  const c=city.buildingContext?.[b]||{};
  for(const [r,room] of Object.entries({...(context.BUILDINGS[b]?.rooms||{}),...(c.roomsExtra||{})})){
   if(c.roomsExclues?.includes(r))continue;
   const ov=c.roomOverrides?.[r]||{};
   for(const o of [...context.ordresDeclaresDeLaPiece(room,c,r),...(ov.ordersExtra||[])])if(o?.desc)d.add(o.desc);
  }
 }
 return d;
}
test('141 descriptions du catalogue Républia : françaises exactes et réellement affichées',()=>{
 const rep=orderDescs('republic'),sov=orderDescs('soviet'),spec=[...rep].filter(d=>!sov.has(d));
 // Cinq descriptions supplémentaires sont désormais propres à Républia à la suite des exclusions ministérielles en Sovarka.
 // Les 141 entrées de ce lot restent inchangées ; les autres descriptions doivent être suivies séparément.
 // 151 → 150 le 15/11 : « +6 INF +5 DIS +1 POP. » est aussi affichée à Krasnov (quatre bureaux du centre d'affaires), donc commune.
 // 150 → 154 le 15/11 : plus de banques en Sovarka (décision de Fred), les quatre descriptions des guichets bancaires ne s'affichent plus qu'en Républia.
 // 154 → 162 le 16/11 : les huit descriptions distinctes héritées du QHS républicain ne sont plus affichées dans le nouveau bâtiment Goulag de Sovarka. Elles restent affichées en Républia et traduites dans le catalogue commun.
 // 162 → 159 le 20/11 (criminalité lot 7) : « Falsifier un procès-verbal » et les deux accélérations par corruption (permis, rendez-vous) sont supprimés.
 // 159 → 162 le 20/11 (distillerie) : produire des spiritueux, produire du sucre et « Spiritueux de la maison » au pôle de Port-Sainte-Marie.
 // 162 → 163 le 21/11 (lot de Krasnov, point 6) : « Organiser un boycott » n'est plus affiché en Sovarka.
 // 163 → 162 le 22/11 (refonte des informateurs) : les ordres d'informateurs recrutés de la loge et « Recruter un informateur » sont retirés.
 // 162 → 164 le 22/11 au soir (Santé, Suites, point 1) : « boissons et en-cas » (bar de l'hôtel, buvettes de stade) ne s'affiche qu'en Républia (« zakouski » en Sovarka).
 // 164 → 165 le 23/11 (mission Novomirsk, point 5) : « Taxi vers le QHS » masqué en Sovarka tant que le goulag est fermé, sa description ne s'affiche plus qu'en Républia.
 // 165 → 166 le 23/11 (bloc 4, point 32) : « +6 INF +5 DIS +1 POP. » n'est plus affichée à Krasnov (bureaux demandés à la mairie), donc propre à Républia.
 // 166 → 167 le 25/11 au soir (mission du soir, bloc 1A, audit des chances) : descriptions réécrites fidèles au serveur ; 15 nouvelles
 // descriptions propres à Républia remplacent 14 anciennes (la rébellion et l'évasion se décrivent désormais selon le quartier).
 // 167 → 166 le 25/11 en fin de soirée (Fred, 1.8) : « Visiter un détenu » aussi au commissariat (les deux pays), sa description devient commune.
 // 166 → 167 le 27/11 (interrogatoires, modèle du goulag) : la nouvelle description de l'interrogatoire du QHS ne s'affiche qu'en Républia.
  // 167 → 163 le 27/11 (Fred) : placements Helvetia, caisse et stock de la scierie, Propagande d'État présidentielle supprimés.
 assert.equal(spec.length,163,'inventaire réel après séparation du goulag de Sovarka et du QHS républicain');
 const rows=setup('republic','fr').RP_INFOBULLES_REPUBLIA;
 assert.equal(rows.length,138); // −3 le 27/11 (Fred) : placements Helvetia, caisse et stock de la scierie retirés avec leurs ordres.
 // Lignes livrées dont l'ordre est supprimé (criminalité lot 7, 20/11 : le temps ne s'achète pas) : gardées au catalogue.
 // Refonte des informateurs (22/11/2026) : « Écouter le patron » (Marin Dulac) retiré ; sa ligne livrée reste au catalogue.
 // Mission du soir (25/11/2026, 1.2) : descriptions de l'article favorable alignées sur le serveur ; lignes livrées gardées
 // au catalogue jusqu'à la traduction des nouvelles par Codex.
 const HISTORIQUES_SOIR=["Choisir une cible (PJ, organisation, local, gouvernement ou pays) et indiquer le sujet/l'angle souhaite : la redaction redige elle-meme un veritable article favorable, vous n'apparaissez jamais comme commanditaire. Reussite (75% + modificateurs) : 500 FR preleves. Echec : la redaction refuse, aucun frais.","Choisir une cible (PJ, organisation, local, gouvernement ou pays) et indiquer le sujet/l'angle souhaite : la redaction redige elle-meme un veritable article favorable, vous n'apparaissez jamais comme commanditaire. Reussite (75% + modificateurs) : 500 FR preleves, article integre a une prochaine edition de La Tribune. Echec : la redaction refuse, aucun frais."];
 // Mission du soir (25/11/2026, bloc 1A, audit des chances) : descriptions réécrites fidèles au serveur ; lignes livrées gardées
 // au catalogue jusqu'à la traduction des nouvelles par Codex (liste dans docs/soir/BLOC-1A.md).
 const HISTORIQUES_AUDIT=["Campagne de communication massive. +POP important.", "Choisir une cible (PJ, organisation, local, gouvernement ou pays) et indiquer le sujet/l'angle souhaite : la redaction redige elle-meme un veritable article favorable, vous n'apparaissez jamais comme commanditaire. Reussite (75% + modificateurs) : 500 FR preleves, article integre a une prochaine edition de La Tribune. Echec : la redaction refuse, aucun frais.", "Choisir une cible (PJ, organisation, local, gouvernement ou pays) et indiquer le sujet/l'angle souhaite : la redaction redige elle-meme un veritable article favorable, vous n'apparaissez jamais comme commanditaire. Reussite (75% + modificateurs) : 500 FR preleves. Echec : la redaction refuse, aucun frais.", "Contracter un pret. Taux selon dossier.", "Contre-lobbying preventif visant une cible (PJ, organisation, local, gouvernement ou pays) : pendant 7 jours, un futur \"Placer un article favorable\" contre cette meme cible devient beaucoup plus difficile (base 10% au lieu de 75%). N'affecte jamais l'actualite reelle (scandales, condamnations, elections...). Reussite (70% + modificateurs) : 1000 FR preleves. Echec : aucun frais.", "Convaincre un député PNJ. Chance 50% + (CHA+ENT)/2. 1 PA + 100 FR, même en cas d'échec. Légal à Républia.", "Influencer massivement l'opinion publique. +POP.", "Liste : fausse identite, faux casier vierge, faux permis construire, faux contrat. Cree un objet en inventaire.", "Même le propriétaire peut se voler lui-même — mise en scène parodique, bonus de sympathie publique.", "Paralyse les importations/exportations 24h. VOL/10 + ENT/10. -IE. Réservé au chef du Syndicat des Dockers.", "Quasi impossible, une tentative par jour. Echec = peine aggravee de 7 jours.", "Rendre visite a un detenu du QHS. Necessite autorisation.", "Révèle contrebandes en cours. INT/10 + ISN/10. Prérogative min_def ou commissaire.", "Taux tres faible. Consequence severe si echec.", "Tres difficile. Obtenir des privileges ou informations.", "Un extrait de casier affirmant un casier VIERGE, pour n'importe quel PJ. Le vrai casier n'est jamais modifie. Le casier etant national, n'importe lequel des trois greffes suffit. 300 FR et 3 PA preleves a la TENTATIVE. Decouvert : aucun document, et le greffier vous denonce.", "Une copie INTEGRALE et authentique d'un dossier de CE tribunal, en cours ou archive. 300 FR et 3 PA preleves a la TENTATIVE. Decouvert : aucun document, et le greffier vous denonce."];
 const HISTORIQUES=[...HISTORIQUES_SOIR,...HISTORIQUES_AUDIT,"Marin Dulac entend tout ce qui se dit au bar. Revele une rumeur vraie ou generee selon le contexte.","Réduit de moitié le délai restant avant le rendez-vous notarial d'un achat direct.","Reduit de moitie la duree d'instruction restante. Risque de decouverte.","Réduit de moitié la durée d'instruction restante du permis. Risque de découverte."];
 for(const line of rows){assert.equal(line.length,9,line[0]);assert.ok(rep.has(line[0])||HISTORIQUES.includes(line[0]),line[0]);}
 assert.equal(new Set(rows.map(l=>l[0])).size,138);
});
test('Les 141 lignes sont présentes en neuf langues, sans perte de chiffres, devises ou sigles',()=>{
 const rows=setup('republic','en').RP_INFOBULLES_REPUBLIA;
 for(const line of rows){
  for(let i=1;i<line.length;i++){
   const translation=line[i],original=line[0];
   assert.ok(translation.trim(),original+' '+langs[i]);
   assert.notEqual(translation,original,'non traduit: '+original);
   assert.ok(!/[<>"]/.test(translation),'caractère HTML à revoir: '+translation);
   for(const n of original.match(/\d+/g)||[])assert.ok(translation.includes(n),n+' absent '+langs[i]+' : '+original);
   for(const acronym of ['FR','PA','POP','INF','DIS','IS','QHS','ISN'])if(new RegExp('\\b'+acronym+'\\b').test(original)&&acronym!=='PA')
    assert.match(translation,new RegExp('\\b'+acronym+'\\b'),acronym+' absent '+langs[i]+' : '+original);
  }
 }
});
test('Républia : neuf langues et changement de langue sans requête',()=>{
 const ctx=setup();
 const original='Candidatures, nomination (2 PA) et revocation (1 PA) du Premier ministre.';
 const row=ctx.RP_INFOBULLES_REPUBLIA.find(l=>l[0]===original);assert.ok(row);
 for(const [index,lang] of langs.entries()){
  ctx.lang=lang;
  const got=ctx.RPSovarkaInfobullesI18n.desc(original);
  assert.equal(got,row[index],lang);
 }
});
test('Catalogue propre à Républia sans effet sur Sovarka, descriptions communes prioritaires',()=>{
 const rep=setup('republic','en'),sov=setup('soviet','en');
 const sovDescs=orderDescs('soviet');
 const specific=rep.RP_INFOBULLES_REPUBLIA.find(row=>!sovDescs.has(row[0]));
 assert.ok(specific);assert.equal(rep.RPSovarkaInfobullesI18n.desc(specific[0]),specific[1]);
 assert.equal(sov.RPSovarkaInfobullesI18n.desc(specific[0]),specific[0]);
 const common='Voir ce qui est disponible au bar et commander.';
 assert.equal(rep.RPSovarkaInfobullesI18n.desc(common),'See what is available at the bar and order.');
 assert.equal(sov.RPSovarkaInfobullesI18n.desc(common),'See what is available at the bar and order.');
 assert.equal(rep.RPSovarkaInfobullesI18n.desc('Ordre inconnu'),'Ordre inconnu');
});
test('Français exact, coûts et paramètres d’ordre non modifiés',()=>{
 const ctx=setup('republic','fr'),line=ctx.RP_INFOBULLES_REPUBLIA[1];
 assert.equal(ctx.RPSovarkaInfobullesI18n.desc(line[0]),line[0]);
 ctx.lang='en';
 const order=Object.freeze({fn:'nommer_premier_ministre',desc:line[0],cost:0,pa:0});
 const translated=ctx.RPSovarkaInfobullesI18n.descOrdre(order,{desc:line[0]},'FR',{cost:0,pa:0});
 assert.equal(translated,line[1]);assert.equal(order.desc,line[0]);assert.equal(order.cost,0);assert.equal(order.pa,0);
 const html=read('plateau.html');
 assert.ok(html.indexOf('republia-infobulles-resources.js')>html.indexOf('infobulles-communes-resources.js'));
 assert.ok(html.indexOf('republia-infobulles-resources.js')<html.indexOf('sovarka-infobulles-resources.js'));
});
