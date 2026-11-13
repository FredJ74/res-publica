'use strict';
// Lecture seule : AST et catalogues dans un VM sans réseau. Aucun module métier importé.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const { gzipSync, gunzipSync } = require('node:zlib');
const { execFileSync } = require('node:child_process');
const acorn = require('./i18n-global/node_modules/acorn');
const html = require('./i18n-global/node_modules/parse5');
const ROOT = path.resolve(__dirname, '../..');
const LOCALES = ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de'];
const NAMES = ['Français', 'Anglais', 'Espagnol', 'Chinois traditionnel', 'Russe', 'Coréen', 'Arabe', 'Portugais brésilien', 'Allemand'];
const hash = s => crypto.createHash('sha256').update(s).digest('hex');
const sort = xs => xs.sort((a,b) => a < b ? -1 : a > b ? 1 : 0);
const normalize = s => String(s).normalize('NFC').replace(/\s+/gu, ' ').trim();
const words = s => (String(s).replace(/\{\{.*?\}\}|\{\w+\}/gu, ' ').match(/[\p{L}\p{N}]+(?:[’'-][\p{L}\p{N}]+)*/gu) || []).length;
const placeholders = s => sort([...String(s).matchAll(/\{\{\s*([^{}]+?)\s*\}\}|\{(\w+)\}|%(?:\d+\$)?[sd]/g)].map(m=>m[1]||m[2]||m[0])).join('|');
const prop = n => n?.name ?? n?.value;
function walk(n, fn, parents = []) {
  if (!n || typeof n !== 'object') return;
  if (typeof n.type === 'string') { fn(n, parents); parents = [...parents,n]; }
  for (const [key,v] of Object.entries(n)) {
    if (key === 'loc') continue;
    if (Array.isArray(v)) for (const x of v) walk(x,fn,parents);
    else if (v && typeof v === 'object') walk(v,fn,parents);
  }
}
function parse(source) { return acorn.parse(source, { ecmaVersion:'latest', sourceType:'module', locations:true, allowReturnOutsideFunction:true }); }
function staticValue(n) {
  if (!n) return undefined;
  if (n.type === 'Literal') return n.value;
  if (n.type === 'TemplateLiteral' && !n.expressions.length) return n.quasis[0].value.cooked;
  if (n.type === 'ArrayExpression') {
    const out = n.elements.map(staticValue); return out.every(v=>v!==undefined) ? out : undefined;
  }
  if (n.type === 'ObjectExpression') {
    const out={}; for (const p of n.properties) { if(p.type!=='Property'||p.computed) return undefined;
      const v=staticValue(p.value); if(v===undefined)return undefined; out[prop(p.key)]=v; } return out;
  }
  return undefined;
}
function flatten(obj, prefix='', out={}) {
  if (typeof obj === 'string') out[prefix]=obj;
  else if(obj && typeof obj === 'object') for(const [k,v] of Object.entries(obj)) flatten(v,prefix?prefix+'.'+k:k,out);
  return out;
}
function domain(file, hint='') {
  const s=file+' '+hint;
  if(/(enigme|mission|quete|calepin|playerMissions|tresor|jodie)/i.test(s))return 'Enquêtes, missions et objectifs';
  if(/(guide|regles|musee|museum|jeremy|pnj|dialogue|scenes)/i.test(s))return 'PNJ, guides et récits';
  if(/(creation|connection|connexion|auth|index\.html)/i.test(s))return 'Création et connexion';
  if(/(orders|order-|ordres|infobulles)/i.test(s))return 'Ordres et descriptions';
  if(/(econom|commerce|produit|product|material|finance|banque|emploi|employment|sales|ventes|entreprise|dealer)/i.test(s))return 'Économie et commerces';
  if(/(justice|police|politique|administration|municipal|civil|social-agency|social-housing|sovarka-(droits|partis|pouvoir|messages|provinces))/i.test(s))return 'Politique, justice et administration';
  if(/(naval|vehicle|vehicule|travel|transport|navigation|plan-rues)/i.test(s))return 'Navigation et transports';
  if(/(forum|courrier|journal|toast|notifications|messages|tracts|communication|directory|repertoire|mail)/i.test(s))return 'Courriers, notifications et journaux';
  if(/(room|pieces|descriptions|data\.js|appartements)/i.test(s))return 'Bâtiments et pièces';
  return 'Interface générale et autres activités';
}
function fragments(value) {
  if (!/<[a-z!/]/i.test(value)) return [{text:normalize(value),key:null}];
  const out=[];
  const doc=html.parseFragment(value);
  function visit(n,key=null) {
    if(['script','style'].includes(n.tagName))return;
    const attrs=Object.fromEntries((n.attrs||[]).map(a=>[a.name,a.value]));
    key=attrs['data-i18n']||key;
    if(n.nodeName==='#text' && normalize(n.value))out.push({text:normalize(n.value),key});
    for(const attr of ['title','placeholder','aria-label','alt','data-rp-tip'])if(attrs[attr])out.push({text:normalize(attrs[attr]),key:attrs['data-i18n-'+attr]||null});
    for(const child of n.childNodes||[])visit(child,key);
  }
  visit(doc);return out;
}
function human(text) {
  if(!text || !/\p{L}/u.test(text.replace(/\{DYNAMIC\}|\{\{[^}]+\}\}/g,'')))return false;
  if(/(?:display|padding|margin|font(?:-size|-family|-weight)?|color|background|border|align-items|flex-direction)\s*:/i.test(text))return false;
  if (/^(?:https?:|data:|[.#][a-z_-]+|[\w./-]+\.(?:js|png|webp|jpg|css|svg|json|mp3))$/i.test(text))return false;
  if(/^[\w$]+(?:[_.:-][\w$]+)+$/.test(text))return false;
  if(/^(?:SELECT |INSERT |UPDATE |CREATE |DELETE |ALTER |\s*function\b|\s*const\b)/i.test(text))return false;
  if(/[{};]/.test(text.replace(/\{\{[^}]*\}\}|\{DYNAMIC\}/g,'')) && /(?:=>|\breturn\b|font-|color:|document\.)/.test(text))return false;
  return true;
}
function symbolic(n) {
  if(n?.type==='Literal'&&typeof n.value==='string')return n.value;
  if(n?.type==='TemplateLiteral')return n.quasis.map(q=>q.value.cooked??q.value.raw).join('{DYNAMIC}');
  if(n?.type==='BinaryExpression'&&n.operator==='+')return symbolic(n.left)+symbolic(n.right);
  return '{DYNAMIC}';
}
function translationStatus(fr,value,neutral) {
  if(typeof value!=='string'||!value.trim())return 'missing';
  if(placeholders(fr)!==placeholders(value))return 'invalid-placeholders';
  if(normalize(fr)===normalize(value))return neutral.has(normalize(fr)) ? 'neutral' : 'identical-review';
  return 'available-unreviewed';
}
function build(root=ROOT, options={}) {
  const policy=JSON.parse(fs.readFileSync(path.join(root,'outils/audits/i18n-global/exclusions.json'),'utf8'));
  const neutral=new Set(policy.neutralExact);
  const tracked=sort(execFileSync('git',['ls-files','-z'],{cwd:root,encoding:'utf8'}).split('\0').filter(Boolean));
  // Untracked fixtures are supported only by the test harness, never through the CLI.
  const all=sort([...new Set([...tracked,...(options.extraFiles||[])])]);
  const files=all.filter(f=>/\.(?:js|html)$/.test(f) && ( !f.includes('/') || f.startsWith('api/') || f.startsWith('i18n/')) && !f.endsWith('.min.js'));
  const sources=files.map(file=>({file,sha256:hash(fs.readFileSync(path.join(root,file))),bytes:fs.statSync(path.join(root,file)).size}));
  const contents=new Map(files.map(f=>[f,fs.readFileSync(path.join(root,f),'utf8')]));
  const trees=new Map(), errors=[];
  for(const file of files.filter(f=>f.endsWith('.js')))try{trees.set(file,parse(contents.get(file)));}catch(e){errors.push({file,error:e.message});}
  const loaded=new Set(), pages=files.filter(f=>f.endsWith('.html'));
  for(const page of pages) for(const m of contents.get(page).matchAll(/<script\b[^>]*src=["']([^"'?]+)(?:\?[^"']*)?["']/g))if(contents.has(m[1]))loaded.add(m[1]);
  // Follow local ES module imports/re-exports and require() without executing them.
  let changed=true;
  while(changed){changed=false;for(const file of [...loaded])walk(trees.get(file),n=>{
    const spec=(n.type==='ImportDeclaration'||n.type==='ExportNamedDeclaration'||n.type==='ExportAllDeclaration')?n.source?.value:
      n.type==='CallExpression'&&n.callee?.name==='require'?staticValue(n.arguments[0]):null;
    if(typeof spec==='string'&&spec.startsWith('.')) {const f=path.posix.normalize(path.posix.join(path.posix.dirname(file),spec));if(contents.has(f)&&!loaded.has(f)){loaded.add(f);changed=true;}}
  });}
  // Server endpoints are deployment entrypoints; their output still requires a runtime check.
  for(const f of files.filter(f=>f.startsWith('api/')))loaded.add(f);
  const registrations=[];
  const addRegistration=(file,key,fr,translations,line,format)=>{
    if(typeof fr!=='string'||!fr.trim())return;
    registrations.push({id:hash(file+'\0'+key+'\0'+fr).slice(0,20),file,key,fr,translations,line,format,loaded:loaded.has(file),domain:domain(file,key)});
  };
  // Discover central registrations in the same script order as pages. Only declarative catalogues execute.
  const catalogFiles=[...new Set(['i18n/resources.js',...[...loaded].filter(f=>/^i18n\/.*(?:resources|forum-ui|order-catalogues-config)\.js$/.test(f)),
    ...files.filter(f=>/^i18n\/.*(?:resources|forum-ui)\.js$/.test(f))])].filter(f=>contents.has(f));
  const sandbox={};sandbox.window=sandbox;
  const context=vm.createContext(sandbox,{codeGeneration:{strings:false,wasm:false}});
  const centralOwners=new Map();
  for(const file of catalogFiles) {
    const before=flatten(sandbox.RP_I18N_RESOURCES?.fr?.translation);
    try{vm.runInContext(contents.get(file),context,{filename:file,timeout:1500});}catch(e){errors.push({file,error:'catalogue-vm: '+e.message});}
    const after=flatten(sandbox.RP_I18N_RESOURCES?.fr?.translation);
    for(const [key,fr] of Object.entries(after))if(before[key]!==fr)centralOwners.set(key,{file,fr});
  }
  const central=Object.fromEntries(LOCALES.map(l=>[l,flatten(sandbox.RP_I18N_RESOURCES?.[l]?.translation)]));
  for(const [key,{file,fr}] of centralOwners){const offset=contents.get(file).indexOf(JSON.stringify(fr));
    addRegistration(file,key,fr,Object.fromEntries(LOCALES.map(l=>[l,central[l][key]])),offset<0?null:contents.get(file).slice(0,offset).split('\n').length,'central');}
  // Guides intentionally keep their French source outside i18n. Respect their existing drift guard.
  const guides=[];
  if(contents.has('i18n/guide-integrity.js'))try{vm.runInContext(contents.get('i18n/guide-integrity.js'),context,{timeout:1000});}catch(e){errors.push({file:'i18n/guide-integrity.js',error:e.message});}
  for(const [file,tree]of trees)if(file==='plateau-personnage.js')walk(tree,n=>{
    if(n.type!=='VariableDeclarator'||n.id.name!=='REGLES'||n.init?.type!=='ObjectExpression')return;
    for(const section of n.init.properties){const name=prop(section.key);if(section.value?.type!=='ObjectExpression')continue;
      const fields=Object.fromEntries(section.value.properties.filter(p=>p.type==='Property').map(p=>[prop(p.key),staticValue(p.value)]));
      const valid=sandbox.RPGuideIntegrity?.valid?.(name,fields)===true&&loaded.has(file)&&contents.get(file).includes("const key='guide.'+section+'.'+champ;");
      for(const field of section.value.properties){const champ=prop(field.key),fr=staticValue(field.value);if(!['titre','contenu'].includes(champ)||typeof fr!=='string')continue;
        const key='guide.'+name+'.'+champ;addRegistration(file,key,fr,Object.fromEntries(LOCALES.map(l=>[l,l==='fr'?fr:central[l][key]])),field.loc.start.line,'guide-source');
        guides.push({file,key,fr,line:field.loc.start.line,valid});
      }
    }
  });
  // Other guides, raw source lookup tables and nine-column matrices use the same existing translators.
  for(const file of files.filter(f=>f.startsWith('i18n/')))walk(trees.get(file),(n)=>{
    if(n.type==='ArrayExpression'&&n.elements.length===9 && n.elements.every(e=>e==null||e.type==='Literal'&&(typeof e.value==='string'||e.value===null))){
      const row=n.elements.map(e=>e?.value);if(row.every((v,i)=>v===LOCALES[i]))return;
      if(row[0])addRegistration(file,'matrix:'+n.loc.start.line,row[0],Object.fromEntries(LOCALES.map((l,i)=>[l,row[i]])),n.loc.start.line,'matrix');
    }
    if(n.type==='ObjectExpression'){
      const p=n.properties.find(p=>p.type==='Property'&&prop(p.key)==='fr');
      if(p&&typeof staticValue(p.value)==='string'&&n.properties.some(q=>prop(q.key)==='id')){
        const id=staticValue(n.properties.find(q=>prop(q.key)==='id')?.value);
        if(typeof id==='string')addRegistration(file,id,staticValue(p.value),Object.fromEntries(LOCALES.map(l=>[l,staticValue(n.properties.find(q=>prop(q.key)===l)?.value)])),n.loc.start.line,'stable-entry');
      }
      if(!p||p.value.type!=='ObjectExpression')return;
      // Object maps of locale -> literal/nested literal tree; skip runtime objects safely.
      const maps={};for(const l of LOCALES){const q=n.properties.find(q=>prop(q.key)===l);maps[l]=flatten(staticValue(q?.value));}
      for(const [key,fr] of Object.entries(maps.fr))addRegistration(file,'local:'+n.loc.start.line+':'+key,fr,Object.fromEntries(LOCALES.map(l=>[l,maps[l][key]])),n.loc.start.line,'locale-map');
    }
  });
  // Collapse duplicate structural extraction, preserving distinct bindings/context.
  const signatures=new Set(registrations.filter(r=>r.format==='central').map(r=>r.file+'\0'+r.fr));
  const regs=registrations.filter(r=>r.format==='central'||!signatures.has(r.file+'\0'+r.fr));
  for(const r of regs)r.status=Object.fromEntries(LOCALES.map(l=>[l,l==='fr'?'source':translationStatus(r.fr,r.translations[l],neutral)]));
  const byText=new Map();for(const r of regs){const k=normalize(r.fr);if(!byText.has(k))byText.set(k,[]);byText.get(k).push(r);}
  const byKey=new Map();for(const r of regs.filter(r=>r.format==='central'))byKey.set(r.key,r);
  const helperKeys=new Map();
  sandbox.RP_I18N_GAME_ENABLED=true;
  sandbox.RPPlateauI18n={language:()=>sandbox.__auditLocale||'fr'};
  for(const file of catalogFiles){
    const localKeys=new Map();
    walk(trees.get(file),n=>{if(n.type!=='ObjectExpression')return;
      const fr=n.properties.find(p=>p.type==='Property'&&prop(p.key)==='fr'&&p.value.type==='ObjectExpression');
      if(!fr)return;
      for(const [key,text]of Object.entries(flatten(staticValue(fr.value)))){
        const r=regs.find(r=>r.file===file&&r.fr===text);if(r)localKeys.set(key,r);
      }
    });
    // Only exported translator functions which read the French map by key qualify.
    const functions=new Set();walk(trees.get(file),n=>{if(n.type!=='FunctionDeclaration')return;
      const body=contents.get(file).slice(n.start,n.end);
      if(/\.fr\s*\[\s*(?:key|cle)\s*\]/.test(body)&&/\[(?:locale|lang|langue)\]\??\.?\[\s*(?:key|cle)\s*\]/.test(body)&&/language\s*\?*\.?\(/.test(body))functions.add(n.id?.name);
    });
    walk(trees.get(file),n=>{if(n.type!=='AssignmentExpression'||n.left.type!=='MemberExpression'||!/^texte/i.test(prop(n.left.property)||'')||!functions.has(n.right.name)||!localKeys.size)return;
      const name=prop(n.left.property),verified=new Map();
      if(typeof sandbox[name]!=='function')return;
      for(const [key,r]of localKeys){const bindings={};
        sandbox.__auditHelper=name;sandbox.__auditKey=key;
        sandbox.__auditVars=Object.fromEntries([...r.fr.matchAll(/\{\{\s*(\w+)\s*\}\}|\{(\w+)\}/g)].map(m=>[m[1]||m[2],m[0]]));
        for(const l of LOCALES.slice(1)){sandbox.__auditLocale=l;
          try{const actual=vm.runInContext('window[window.__auditHelper](window.__auditKey,window.__auditVars)',context,{timeout:1000});
            if(actual===r.translations[l]&&actual!==r.fr)bindings[l]=r.id;
          }catch{/* Not a verified output for this locale. Keep the resource as a candidate. */}
        }
        verified.set(key,{registration:r,bindings});
      }
      helperKeys.set(name,verified);
    });
  }
  // Recognize transparent presentation wrappers without executing them.
  let helperChanged=true;
  while(helperChanged){helperChanged=false;for(const [file,tree]of trees)if(!file.startsWith('i18n/'))walk(tree,n=>{
    if(n.type!=='FunctionDeclaration'||helperKeys.has(n.id?.name))return;
    const param=n.params[0]?.name;if(!param)return;let match=null;
    walk(n.body,(c,ps)=>{if(c.type==='CallExpression'&&c.callee.type==='Identifier'&&helperKeys.has(c.callee.name)&&c.arguments[0]?.name===param&&ps.at(-1)?.type==='ReturnStatement')match=helperKeys.get(c.callee.name);});
    if(match){helperKeys.set(n.id.name,match);helperChanged=true;}
  });}
  const texts=new Map(), rejected=[], dynamic=[], sqlInventory=[];
  const record=(raw,occ)=>{
    for(const frag of fragments(raw)){
      const text=frag.text;if(!human(text)){if(text)rejected.push({file:occ.file,line:occ.line,sha256:hash(text),reason:'technique-ou-non-textuel'});continue;}
      const id=hash(text).slice(0,20);
      let entry=texts.get(id);if(!entry){entry={id,text,words:words(text),occurrences:[]};texts.set(id,entry);}
      const matches=(byText.get(text)||[]).filter(r=>r.loaded);
      const keyed=byKey.get(frag.key||occ.key);
      const binding=occ.binding || (keyed&&normalize(keyed.fr)===text?keyed.id:null);
      const occurrence={...occ,key:frag.key||occ.key||null,binding,resources:matches.map(r=>r.id)};
      if(!entry.occurrences.some(o=>o.file===occ.file&&o.line===occ.line&&o.kind===occ.kind&&o.key===occurrence.key&&o.country===occ.country&&o.city===occ.city&&o.building===occ.building&&o.room===occ.room&&o.order===occ.order))entry.occurrences.push(occurrence);
    }
  };
  for(const g of guides){const r=regs.find(r=>r.file===g.file&&r.key===g.key);
    record(g.fr,{file:g.file,line:g.line,kind:'guide-integrity',certainty:loaded.has(g.file)?'static-render-path':'candidate-review',domain:'PNJ, guides et récits',key:null,binding:g.valid?r?.id:null});}
  // Active building/order definitions: same merge rules as renderer/test of common descriptions.
  const activeOrders=[];
  const dataLines=new Map();walk(trees.get('data.js'),n=>{if(n.type==='Literal'&&typeof n.value==='string'&&!dataLines.has(n.value))dataLines.set(n.value,n.loc.start.line);});
  if(contents.has('data.js')){
    const dataContext={document:{getElementById:()=>null,querySelector:()=>null,addEventListener(){}},localStorage:{getItem:()=>null},state:{country:'soviet'}};
    dataContext.window=dataContext;vm.createContext(dataContext,{codeGeneration:{strings:false,wasm:false}});
    try{
      vm.runInContext(contents.get('data.js').replace(/^const (WORLD|BUILDINGS) =/mg,'var $1 ='),dataContext,{timeout:3000});
      // Reuse all discovered catalogues in page order, including future country-specific tables.
      const tooltipSandbox=sandbox;
      for(const [country,cities] of Object.entries(dataContext.WORLD||{}))for(const [city,cityData] of Object.entries(cities))for(const b of cityData.buildings||[]){
        const c=cityData.buildingContext?.[b]||{};
        for(const [roomId,room] of Object.entries({...dataContext.BUILDINGS?.[b]?.rooms,...c.roomsExtra})){
          if(c.roomsExclues?.includes(roomId))continue;const ov=c.roomOverrides?.[roomId]||{};
          for(const order of [...(ov.orders||room?.orders||[]),...(ov.ordersExtra||[])]){
            for(const field of ['label','desc'])if(typeof order?.[field]==='string'){
              const text=order[field];
              const key=field==='label'?'orders.'+order.fn:null;
              const occ={file:'data.js',line:dataLines.get(text)||null,kind:'active-order-'+field,certainty:'static-render-path',domain:'Ordres et descriptions',country,city,building:b,room:roomId,order:order.fn||null,key};
              // Description lookup is verified per country through the EXISTING pure resolver, never an order.
              if(field==='desc'){
                tooltipSandbox.state={country};vm.runInContext('var state=window.state;',context);
                const api=tooltipSandbox.RPSovarkaInfobullesI18n;
                occ.resolverBindings={};
                for(const l of LOCALES.slice(1)){sandbox.__auditLocale=l;const rendered=api?.desc(text,order.descriptionKey);
                  const keyed=order.descriptionKey?regs.filter(r=>r.key===order.descriptionKey):[];
                  const alias=(sandbox.RP_ORDER_DESCRIPTION_CATALOGUES||[]).find(c=>(c.shared||c.countries?.includes(country))&&c.keys?.[order.descriptionKey])?.keys?.[order.descriptionKey];
                  const candidates=keyed.length?keyed:byText.get(normalize(alias||text))||[];
                  const match=candidates.find(r=>r.loaded&&r.translations[l]===rendered);
                  if(match&&rendered!==text)occ.resolverBindings[l]=match.id;
                }
              }
              activeOrders.push({country,field,text,bindings:occ.resolverBindings});record(text,occ);
            }
          }
        }
      }
    }catch(e){errors.push({file:'data.js',error:'active-world: '+e.message});}
  }
  function scanJS(file,source,tree,lineOffset=0){
    const markedToasts=new Map();
    const expression=s=>s?.expression?.type==='ChainExpression'?s.expression.expression:s?.expression;
    const shape=n=>JSON.stringify(n,(k,v)=>['start','end','loc','raw'].includes(k)?undefined:v);
    walk(tree,block=>{if(block.type!=='BlockStatement')return;
      for(let i=1;i<block.body.length;i++){
        const first=expression(block.body[i-1]),next=expression(block.body[i]);
        if(first?.callee?.name!=='showToast'||prop(next?.callee?.property)!=='markToast'||!source.slice(next.callee.start,next.callee.end).includes('RPI18nPlateau'))continue;
        const r=byKey.get(staticValue(next.arguments[0]));
        if(!r||shape(first.arguments[1])!==shape(next.arguments[1]))continue;
        if(normalize(symbolic(first.arguments[1]))!==normalize(r.fr.replace(/\{\{[^}]+\}\}/g,'{DYNAMIC}')))continue;
        markedToasts.set(first.arguments[1].start,r);markedToasts.set(next.arguments[1].start,r);
      }
    });
    walk(tree,(n,parents)=>{
      const parent=parents.at(-1);
      let raw=null, templated=false;
      // Reconstruct concatenated HTML before parsing; never count opening tags/attributes as prose.
      if(parent?.type==='BinaryExpression'&&parent.operator==='+'&&['Literal','TemplateLiteral','BinaryExpression'].includes(n.type))return;
      if(n.type==='BinaryExpression'&&n.operator==='+'){raw=symbolic(n);templated=true;}
      if(n.type==='Literal'&&typeof n.value==='string')raw=n.value;
      if(n.type==='TemplateLiteral') {raw=n.quasis.map(q=>q.value.cooked??q.value.raw).join('{DYNAMIC}');templated=n.expressions.length>0;}
      if(raw===null||parent?.type==='TemplateElement'||(parent?.type==='Property'&&parent.key===n&&!parent.computed))return;
      const line=n.loc.start.line+lineOffset;
      if(templated)dynamic.push({file,line,kind:'template-interpolated',expressions:n.expressions?.length??null});
      if(file.startsWith('i18n/'))return;
      const toast=markedToasts.get(n.start);
      if(toast){record(toast.fr,{file,line,kind:'annotated-toast',certainty:loaded.has(file)?'static-render-path':'candidate-review',domain:domain(file),key:toast.key});return;}
      const ancestors=[...parents].reverse();
      const property=parent?.type==='Property'?prop(parent.key):null;
      const call=ancestors.slice(0,5).find(p=>p.type==='CallExpression');
      const callName=call?.callee?.name||prop(call?.callee?.property)||'';
      const assignment=ancestors.slice(0,5).find(p=>p.type==='AssignmentExpression');
      const assignName=prop(assignment?.left?.property);
      const visibleField=/^(label|desc|description|title|titre|texte|text|message|contenu|accueil|question|reponse|refus|motif|instruction|objectif|placeholder|help|role|nom|name|welcome|body|html)$/i.test(property||'');
      const sink=/^(textContent|innerText|innerHTML|outerHTML|placeholder|title|ariaLabel)$/.test(assignName||'')||/^(alert|confirm|prompt|toast|showToast|notify|notification|ouvrirDialogue|afficherMessage|showModal)$/i.test(callName);
      const translated=/^(t|translate|texte\w*|text\w*)$/i.test(callName)|| /i18n/i.test(source.slice(call?.callee?.start||0,call?.callee?.end||0));
      // Key usages add a source occurrence directly; a literal key is never an untranslated text.
      const reg=byKey.get(raw);
      if(reg&&translated&&call?.arguments?.[0]===n){record(reg.fr,{file,line,kind:'explicit-key',certainty:loaded.has(file)?'static-render-path':'unlinked-source',domain:domain(file,reg.key),key:raw});return;}
      // Le français de repli d'un appel à clé connue n'est pas un deuxième écran non traduit.
      if(translated&&call?.arguments?.[0]!==n&&byKey.has(staticValue(call?.arguments?.[0])))return;
      const helper=helperKeys.get(callName)?.get(raw),helperReg=helper?.registration;
      if(helperReg&&call?.arguments?.[0]===n){record(helperReg.fr,{file,line,kind:'explicit-helper-key',certainty:loaded.has(file)?'static-render-path':'unlinked-source',domain:domain(file,helperReg.key),key:null,bindings:helper.bindings});return;}
      if(/console\.(log|warn|error|info|debug)/.test(source.slice(call?.start||0,call?.callee?.end||0)))return;
      if(!visibleField&&!sink&&!/[<][a-z]/i.test(raw)&&!(human(raw)&&words(raw)>=4&&/[ àâäéèêëîïôöùûüç’']/i.test(raw)))return;
      const server=file.startsWith('api/');
      const prompt=server&&/(?:_bible-|_pnj-|_deepseek|_aide-themes)/.test(file);
      const certainty=prompt?'ai-context-not-output':server?'server-source-review':loaded.has(file)&&(sink||/<[a-z]/i.test(raw))?'static-render-path':'candidate-review';
      const functionName=ancestors.find(p=>p.type==='FunctionDeclaration')?.id?.name||'';
      record(raw,{file,line,kind:templated?'dynamic-template':sink?'display-sink':visibleField?'display-field':'french-candidate',certainty,domain:domain(file,functionName+' '+(property||'')),key:null});
    });
  }
  for(const [file,tree] of trees)if(file!=='data.js')scanJS(file,contents.get(file),tree);
  // data.js outside active order fields still has rooms, descriptions, names, gains and inactive worlds.
  if(trees.has('data.js'))scanJS('data.js',contents.get('data.js'),trees.get('data.js'));
  for(const file of pages){
    const source=contents.get(file);const doc=html.parse(source,{sourceCodeLocationInfo:true});
    function visit(n,key=null,hidden=false){
      const attrs=Object.fromEntries((n.attrs||[]).map(a=>[a.name,a.value]));
      hidden=hidden||['style','script','template'].includes(n.tagName);
      const effectiveKey=attrs['data-i18n']||key;
      const line=n.sourceCodeLocation?.startLine||1;
      if(n.tagName==='script'&&!attrs.src){const script=(n.childNodes||[]).map(c=>c.value||'').join('');if(script.trim())try{scanJS(file,script,parse(script),line-1);}catch(e){errors.push({file,line,error:'inline: '+e.message});}}
      if(!hidden&&n.nodeName==='#text')record(n.value,{file,line,kind:'html-text',certainty:'static-render-path',domain:domain(file),key:effectiveKey});
      if(!hidden)for(const a of ['placeholder','title','alt','aria-label'])if(attrs[a])record(attrs[a],{file,line,kind:'html-attribute',certainty:'static-render-path',domain:domain(file),key:attrs['data-i18n-'+a]||null});
      for(const c of n.childNodes||[])visit(c,effectiveKey,hidden);
    }visit(doc);
  }
  // Server SQL literals are candidates only, not evidence of currently deployed French output.
  const sqlFiles=all.filter(f=>/^(?:migrations|baseline\/domaines)\/.*\.sql$/.test(f));
  for(const file of sqlFiles){const s=fs.readFileSync(path.join(root,file),'utf8');
    const matches=[...s.matchAll(/(?:RAISE\s+EXCEPTION(?:\s+USING\s+MESSAGE\s*=)?\s*|['"](?:message|texte|description|titre)['"]\s*,\s*)'((?:''|[^'])*)'/gi)];
    sqlInventory.push({file,sha256:hash(s),candidateLiterals:matches.length});
    for(const m of matches)record(m[1].replace(/''/g,"'"),{file,line:s.slice(0,m.index).split('\n').length,kind:'sql-response-candidate',certainty:'server-source-review',domain:domain(file),key:null});
  }
  const overrides=new Map(policy.textOverrides.map(o=>{if(!o.id||!o.reason||!o.source)throw Error('Exclusion sans justification');return [o.id,o];}));
  const entries=sort([...texts.keys()]).map(id=>texts.get(id));
  const regById=new Map(regs.map(r=>[r.id,r]));
  for(const e of entries){
    e.occurrences.sort((a,b)=>JSON.stringify(a)<JSON.stringify(b)?-1:1);
    e.domains=sort([...new Set(e.occurrences.map(o=>o.domain))]);
    e.certainty=e.occurrences.some(o=>o.certainty==='static-render-path')?'static-render-path':e.occurrences.some(o=>o.certainty==='candidate-review')?'candidate-review':e.occurrences.some(o=>o.certainty==='server-source-review')?'server-source-review':'ai-context-not-output';
    e.exclusion=overrides.get(e.id)||null;
    // Deliberately conservative: resource existence never proves its use on the screen.
    e.locales={};for(const l of LOCALES){
      const visible=e.occurrences.filter(o=>o.certainty==='static-render-path');
      const usable=r=>r&&['available-unreviewed','neutral','source'].includes(r.status[l]);
      const available=visible.some(o=>o.resources.some(id=>usable(regById.get(id)))) || e.occurrences.some(o=>o.resources.some(id=>usable(regById.get(id))));
      const wired=visible.length>0&&visible.every(o=>usable(regById.get(o.resolverBindings?.[l]||o.bindings?.[l]||o.binding)));
      e.locales[l]=l==='fr'?'source':wired?'wired-unreviewed':available?'resource-review-binding':'no-confirmed-resource';
    }
  }
  const measured=entries.filter(e=>e.certainty==='static-render-path'&&!e.exclusion);
  function metrics(list,l){const totalWords=list.reduce((s,e)=>s+e.words,0);const wired=list.filter(e=>l==='fr'||e.locales[l]==='wired-unreviewed');
    const available=list.filter(e=>l==='fr'||e.locales[l]!=='no-confirmed-resource');const sum=xs=>xs.reduce((s,e)=>s+e.words,0);
    return {texts:list.length,words:totalWords,wiredTexts:wired.length,wiredWords:sum(wired),resourceTexts:available.length,resourceWords:sum(available),
      unconfirmedTexts:list.length-wired.length,unconfirmedWords:totalWords-sum(wired),withoutResourceTexts:list.length-available.length,withoutResourceWords:totalWords-sum(available),
      wiredTextPercent:list.length?+(100*wired.length/list.length).toFixed(2):null,wiredWordPercent:totalWords?+(100*sum(wired)/totalWords).toFixed(2):null,
      resourceTextPercent:list.length?+(100*available.length/list.length).toFixed(2):null,resourceWordPercent:totalWords?+(100*sum(available)/totalWords).toFixed(2):null};}
  const perLanguage=Object.fromEntries(LOCALES.map(l=>[l,metrics(measured,l)]));
  const domains=sort([...new Set(entries.flatMap(e=>e.domains))]).map(name=>{const list=measured.filter(e=>e.domains.includes(name));return {name,texts:list.length,locales:Object.fromEntries(LOCALES.map(l=>[l,metrics(list,l)]))};});
  const certainty=Object.fromEntries(['static-render-path','candidate-review','server-source-review','ai-context-not-output'].map(c=>{const es=entries.filter(e=>e.certainty===c);return [c,{texts:es.length,words:es.reduce((s,e)=>s+e.words,0)}];}));
  const priority=(e)=>e.occurrences.some(o=>o.kind==='active-order-desc'||/refus|erreur|connexion|creation/i.test(o.file))?1:e.domains.some(d=>/Enquêtes|PNJ/.test(d))?3:e.domains.some(d=>/Bâtiments/.test(d))?4:2;
  const remaining=entries.filter(e=>e.certainty!=='ai-context-not-output'&&!e.exclusion&&LOCALES.slice(1).some(l=>e.locales[l]!=='wired-unreviewed')).map(e=>({id:e.id,priority:priority(e),domain:e.domains[0],words:e.words,certainty:e.certainty,
    reason:priority(e)===1?'Compréhension d’un ordre, d’un refus ou entrée dans le jeu':priority(e)===3?'Compréhension d’une mission ou interaction narrative':priority(e)===4?'Description ou repère de lieu':'Commandes et messages de gameplay',
    missingResources:LOCALES.slice(1).filter(l=>e.locales[l]==='no-confirmed-resource'),bindingReview:LOCALES.slice(1).filter(l=>e.locales[l]==='resource-review-binding')})).sort((a,b)=>a.priority-b.priority||b.words-a.words||(a.id<b.id?-1:1));
  const orderDescriptions={};for(const country of sort([...new Set(activeOrders.map(o=>o.country))])){
    const ds=[...new Set(activeOrders.filter(o=>o.country===country&&o.field==='desc').map(o=>normalize(o.text)))];
    orderDescriptions[country]={texts:ds.length,locales:Object.fromEntries(LOCALES.map(l=>[l,{resourcePresent:ds.filter(t=>l==='fr'||(byText.get(t)||[]).some(r=>r.loaded&&typeof r.translations[l]==='string'&&r.translations[l].trim())).length,resourceAvailable:ds.filter(t=>l==='fr'||(byText.get(t)||[]).some(r=>r.loaded&&['available-unreviewed','neutral'].includes(r.status[l]))).length,
      wired:ds.filter(t=>l==='fr'||activeOrders.filter(o=>o.country===country&&o.field==='desc'&&normalize(o.text)===t).every(o=>{const reg=regById.get(o.bindings?.[l]);return reg&&['available-unreviewed','neutral'].includes(reg.status[l]);})).length
    }]))};
  }
  const snapshotPath=path.join(root,'outils/audits/i18n-global/serveur-agregats.json');
  const serverSnapshot=fs.existsSync(snapshotPath)?JSON.parse(fs.readFileSync(snapshotPath,'utf8')):null;
  const report={schemaVersion:1,baseCommit:execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim(),
    methodHash:hash(fs.readFileSync(__filename)+fs.readFileSync(path.join(__dirname,'i18n-global/package-lock.json'),'utf8')),
    corpusHash:hash(JSON.stringify(sources)+JSON.stringify(sqlInventory)+JSON.stringify(policy)),locales:LOCALES,sourceFiles:sources,sqlFiles:sqlInventory,
    extractionErrors:errors,central:{frenchKeys:Object.keys(central.fr).length,perLocale:Object.fromEntries(LOCALES.map(l=>[l,{missing:Object.keys(central.fr).filter(k=>!central[l][k]),placeholderMismatch:Object.keys(central.fr).filter(k=>central[l][k]&&placeholders(central.fr[k])!==placeholders(central[l][k]))}]))},
    resourceHealth:Object.fromEntries(LOCALES.map(l=>[l,Object.fromEntries(['source','available-unreviewed','neutral','missing','invalid-placeholders','identical-review'].map(s=>[s,regs.filter(r=>r.status[l]===s).length]))])),
    certainty,measuredScope:'Textes uniques des chemins de rendu statiques identifiés ; ni exhaustivité des états du jeu ni validation linguistique.',
    identifiedUniqueTexts:entries.length,occurrences:entries.reduce((s,e)=>s+e.occurrences.length,0),perLanguage,domains,orderDescriptions,
    registrations:regs,entries,remaining,dynamicSites:dynamic,rejected,policy,serverSnapshot,
    unknowns:[
      'Présence en catalogue ≠ branchement correct ≠ qualité linguistique. Les taux sont techniques et conservateurs, jamais un taux certifié de tout le jeu.',
      'Chemin statique ≠ observation en session : droits, progression, pièces inaccessibles et conditions dynamiques nécessitent une recette en jeu.',
      'Contexte IA recensé à part : ce ne sont pas des répliques affichées. Réponses IA, journaux générés et conversation en cours : volume illimité, traduction non certifiée.',
      'Courriers, forums, chats et écrits de joueurs : langue inconnue, volume évolutif, aucun contenu privé lu ou exporté.',
      'Agrégats serveur figés, non additionnables au corpus (doublons possibles), sans certification de traduction ou de langue source.',
      'SQL du dépôt : candidats, peut contenir des définitions remplacées ; non assimilé aux fonctions actuellement déployées.',
      'JS : candidats extraits des littéraux/templates, sans analyse complète des flux ; concaténations, tableaux assemblés et HTML injecté à vérifier.',
      'Texte incrusté dans les images/vidéos, ressources distantes, états non visités, styles CSS : volume de texte inconnu.',
      'Les domaines se recoupent : leur somme peut dépasser le total unique. La segmentation en mots est une convention Unicode, pas une estimation de temps.'
    ]};
  return report;
}
function compare(before,after){
  const b=new Map(before.entries.map(e=>[e.id,e])),a=new Map(after.entries.map(e=>[e.id,e]));
  return {beforeHash:before.corpusHash,afterHash:after.corpusHash,sameMethod:before.methodHash===after.methodHash,sameScope:JSON.stringify(before.policy)===JSON.stringify(after.policy),
    added:[...a.keys()].filter(id=>!b.has(id)),removed:[...b.keys()].filter(id=>!a.has(id)),
    changed:[...a.keys()].filter(id=>b.has(id)&&JSON.stringify(a.get(id).locales)!==JSON.stringify(b.get(id).locales)),
    locales:Object.fromEntries(LOCALES.map(l=>[l,{wiredTexts:after.perLanguage[l].wiredTexts-before.perLanguage[l].wiredTexts,resourceTexts:after.perLanguage[l].resourceTexts-before.perLanguage[l].resourceTexts,unconfirmedWords:after.perLanguage[l].unconfirmedWords-before.perLanguage[l].unconfirmedWords}]))};
}
function markdown(r){
  const pct=n=>n===null?'—':n.toFixed(2)+' %';
  const rows=LOCALES.map((l,i)=>{const m=r.perLanguage[l];return `| ${NAMES[i]} | ${m.texts} | ${m.wiredTexts} | ${pct(m.wiredTextPercent)} | ${pct(m.wiredWordPercent)} | ${m.resourceTexts} | ${m.unconfirmedWords} |`;});
  const lines=['# Tableau de bord internationalisation — Human Gambit','',`Base analysée : \`${r.baseCommit}\`. Empreinte du corpus : \`${r.corpusHash}\`.`,
    '', '**Mesure technique du corpus identifié, pas pourcentage certifié de tout le jeu.** Le français est la référence, pas une traduction. Aucune qualité linguistique native certifiée.',
    '',`**${r.identifiedUniqueTexts} textes distincts repérés**, ${r.occurrences} occurrences dans les sources. ${r.sourceFiles.length} fichiers JS/HTML et ${r.sqlFiles.length} fichiers SQL analysés.`,
    '', '## Périmètre et certitude','', '| Classe | Textes uniques | Mots source |', '|---|---:|---:|',
    ...Object.entries(r.certainty).map(([c,m])=>`| ${c} | ${m.texts} | ${m.words} |`),
    '', 'Les taux suivants portent seulement sur `static-render-path` : un chemin de rendu est identifié, sans preuve que chaque état soit accessible en session. Les autres classes restent visibles, hors dénominateur. Une même chaîne est dédupliquée globalement ; ses occurrences gardent leur contexte. Une seule occurrence non prouvée suffit à empêcher sa certification complète.',
    '', '## Neuf langues','', '| Langue | Corpus | Raccordés prouvés* | Taux textes* | Taux mots* | Ressource disponible** | Mots à traiter/vérifier |','|---|---:|---:|---:|---:|---:|---:|',...rows,
    '', '* Preuve statique stricte : clé explicite de même français, traducteur exporté/wrapper transparent, guide accepté par son garde d’intégrité ou description d’ordre reconnue par le résolveur existant dans son pays, dans chacune des huit langues. C’est un plancher de raccordements identifiés, pas la mesure de toutes les traductions qui fonctionnent. Les valeurs identiques au français restent à vérifier sauf sigles neutres documentés.',
    '', '** Une ressource correspondante peut exister sans preuve de raccordement. Elle ne compte PAS comme texte traduit dans la colonne « raccordés ». Les mots à traiter incluent donc traduction ET vérification des branchements.',
    '', '## Domaines (recouvrements possibles)','', '| Domaine | Textes du corpus | EN raccordés | EN sans ressource | EN mots à traiter/vérifier |','|---|---:|---:|---:|---:|',
    ...r.domains.map(d=>`| ${d.name} | ${d.texts} | ${d.locales.en.wiredTexts} | ${d.locales.en.withoutResourceTexts} | ${d.locales.en.unconfirmedWords} |`),
    '', 'Les neuf langues et leurs volumes par domaine sont détaillés dans `tableau-de-bord.json` → `domains`. Aucun domaine n’est déclaré complet sur la seule présence de clés.',
    '', '### Planchers de preuves par domaine et langue (textes / mots)','', '| Domaine | '+LOCALES.join(' | ')+' |', '|---|'+LOCALES.map(()=>'---:').join('|')+'|',
    ...r.domains.map(d=>'| '+d.name+' | '+LOCALES.map(l=>`${pct(d.locales[l].wiredTextPercent)} / ${pct(d.locales[l].wiredWordPercent)}`).join(' | ')+' |'),
    '', '## Descriptions d’ordres par empire','', '| Empire (identifiant interne) | Descriptions distinctes | Ressources EN présentes | EN différentes du français ou neutres | EN reconnues par le résolveur du pays |','|---|---:|---:|---:|---:|',
    ...Object.entries(r.orderDescriptions).map(([c,m])=>`| ${c} | ${m.texts} | ${m.locales.en.resourcePresent} | ${m.locales.en.resourceAvailable} | ${m.locales.en.wired} |`),
    '', 'Les descriptions communes sont présentes dans plusieurs empires : ne pas additionner ces lignes. Une formule chiffrée inchangée peut être légitimement identique ; elle reste à vérifier si elle ne figure pas dans les sigles neutres. Chaque langue est détaillée dans le JSON.',
    '', '## Catalogue central et autres ressources','',`Le catalogue central expose **${r.central.frenchKeys} clés françaises**. Les tables locales, guides et matrices sont inventoriés séparément (${r.registrations.length} enregistrements après déduplication structurelle). Les traductions supplémentaires sans français de référence ne sont pas artificiellement ajoutées au dénominateur.`,
    '', '| Langue | Clés absentes | Variables incohérentes |','|---|---:|---:|',...LOCALES.map(l=>`| ${l} | ${r.central.perLocale[l].missing.length} | ${r.central.perLocale[l].placeholderMismatch.length} |`),
    '', '## Priorités','', '| Priorité | Textes candidats non entièrement prouvés | Usage |','|---|---:|---|',
    ...[1,2,3,4].map(p=>{const a=r.remaining.filter(e=>e.priority===p);return `| ${p} | ${a.length} | ${a[0]?.reason||'—'} |`;}),
    '', 'Classement automatique à confirmer en jeu. `inventaire.json.gz` fournit texte, identifiant, fichier, ligne, pays et ressources candidates ; `priorites.json.gz` fournit les langues manquantes et les branchements à vérifier. Les descriptions Républia restantes ne sont pas traduites par cet audit.',
    '', '### Exemples de cibles sans ressource confirmée (à vérifier avant traduction)','',
    ...[1,2,3,4].flatMap(p=>r.remaining.filter(e=>e.priority===p&&e.missingResources.includes('en')&&e.certainty==='static-render-path').slice(0,3).map(item=>{const e=r.entries.find(e=>e.id===item.id),o=e.occurrences.find(o=>o.certainty==='static-render-path');return `- Priorité ${p} — ${e.text.slice(0,130).replace(/[|`<>]/g,' ')} — \`${o.file}:${o.line}\` (${e.words} mots source ; identifiant \`${e.id}\`).`;})),
    '', '## Données serveur et limites','',...(r.serverSnapshot?[`Relevé serveur en lecture seule : ${r.serverSnapshot.checkedAt}. Agrégats de références statiques, aucune donnée de personnage.`, '', '| Source | Textes distincts (dans cette source) | Mots séparés par espaces |','|---|---:|---:|',...r.serverSnapshot.rows.map(x=>`| ${x.source} | ${x.distinct_texts} | ${x.whitespace_words} |`)]:['Pas de relevé serveur disponible.']),
    '',...r.unknowns.map(s=>'- '+s),
    '', '## Reproduction et suivi','', 'Voir [le mode d’emploi](README.md). Les rapports ne contiennent aucune donnée de session ou de joueur. Le script ne se connecte pas à Supabase ; le relevé agrégé est explicite et daté.',
    '', `Erreurs d’extraction : **${r.extractionErrors.length}**. Toute erreur est conservée dans le JSON et fait échouer la commande. Les variations se calculent avec \`--previous\` ; un changement de périmètre/exclusions est signalé.`, ''];
  return lines.join('\n');
}
function main(){
  const args=process.argv.slice(2);const get=k=>args.includes(k)?args[args.indexOf(k)+1]:null;
  const output=path.resolve(get('--output')||path.join(ROOT,'outils/audits/i18n-global'));
  const r=build();fs.mkdirSync(output,{recursive:true});
  const writeGzip=(name,value)=>fs.writeFileSync(path.join(output,name+'.json.gz'),gzipSync(JSON.stringify(value)+'\n',{level:9}));
  writeGzip('inventaire',{schemaVersion:r.schemaVersion,baseCommit:r.baseCommit,corpusHash:r.corpusHash,entries:r.entries});
  const summary={...r};delete summary.entries;delete summary.registrations;delete summary.rejected;
  delete summary.remaining;delete summary.dynamicSites;delete summary.sourceFiles;delete summary.sqlFiles;
  summary.files={javascriptHTML:r.sourceFiles.length,sql:r.sqlFiles.length,dynamicSites:r.dynamicSites.length};
  summary.artifacts=['inventaire.json.gz','ressources.json.gz','exclusions-appliquees.json.gz','priorites.json.gz','sources.json.gz'];
  fs.writeFileSync(path.join(output,'tableau-de-bord.json'),JSON.stringify(summary,null,2)+'\n');
  writeGzip('ressources',r.registrations);
  writeGzip('exclusions-appliquees',{policy:r.policy,rejected:r.rejected});
  writeGzip('priorites',r.remaining);
  writeGzip('sources',{sourceFiles:r.sourceFiles,sqlFiles:r.sqlFiles,dynamicSites:r.dynamicSites});
  fs.writeFileSync(path.join(output,'TABLEAU-DE-BORD.md'),markdown(r));
  if(get('--previous')){const prev=JSON.parse(fs.readFileSync(get('--previous'),'utf8'));const inv=JSON.parse(gunzipSync(fs.readFileSync(path.join(path.dirname(get('--previous')),'inventaire.json.gz'))));prev.entries=inv.entries;
    fs.writeFileSync(path.join(output,'variation.json'),JSON.stringify(compare(prev,r),null,2)+'\n');}
  console.log(JSON.stringify({base:r.baseCommit,unique:r.identifiedUniqueTexts,certainty:r.certainty,english:r.perLanguage.en,errors:r.extractionErrors}));
  if(r.extractionErrors.length)process.exitCode=1;
}
if(require.main===module)main();
module.exports={build,compare,markdown,normalize,words,translationStatus,fragments,parse,walk,LOCALES};
