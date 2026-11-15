#!/usr/bin/env python3
"""Installe les six décors de stade de Starovka sans toucher aux salles des autres villes."""
from pathlib import Path
import unicodedata
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / 'images/Sovarka/Starovka'
SOURCES = {
    'Vestiaire de football industriel et brumeux.png': 'Starovka_stade_vestiaires.webp',
    'Bureau de football face aux neiges urbaines.png': 'Starovka_stade_bureau_president.webp',
    'Salon des supporters face au stade enneigé.png': 'Starovka_stade_club_supporters.webp',
    'Kiosque de boissons chaudes sous la neige.png': 'Starovka_stade_buvette.webp',
    'Kiosque des supporters sous la neige.png': 'Starovka_stade_boutique.webp',
    'Kiosque de paris enneigé au stade.png': 'Starovka_stade_bookmaker.webp',
}
for original, targetname in SOURCES.items():
    candidates = [p for p in FOLDER.glob('*.png') if unicodedata.normalize('NFC',p.name) == original]
    target = FOLDER / targetname
    if len(candidates) == 1:
        source = candidates[0]
        with Image.open(source) as img:
            assert img.format == 'PNG', source
            rgb = ImageOps.exif_transpose(img).convert('RGB')
            size = rgb.size
            rgb.save(target, 'WEBP', quality=85, method=6)
        with Image.open(target) as chk:
            assert chk.format == 'WEBP' and chk.size == size, target
        assert target.read_bytes()[:4] == b'RIFF' and target.read_bytes()[8:12] == b'WEBP'
        assert target.stat().st_size < source.stat().st_size
        source.unlink()
        print(f'{source.name} -> {target.name}: {target.stat().st_size} octets')
    elif len(candidates) == 0 and target.exists():
        assert target.read_bytes()[:4] == b'RIFF'
    else:
        raise RuntimeError(f'Source manquante / ambiguë: {original} ({len(candidates)})')

path = ROOT / 'data.js'
data = path.read_text(encoding='utf-8')
anchor = "  Object.assign(contexte('ville_a', 'logements-novomirsk'), { name: 'Baraquement Sibirsk-9',"
tag='// STAROVKA_STADE_SIX_DECORS_20261115'
assert data.count(anchor)==1, 'Ancrage du contexte Starovka absent'
if tag not in data:
    insert = """  // STAROVKA_STADE_SIX_DECORS_20261115 — images spécifiques à Starovka.
  // Conserver les ordres existants et le gabarit partagé, hormis la boutique du club
  // créée comme à Novomirsk et Krasnov, avec les commandes existantes.
  {
    const stadeStarovka = contexte('ville_a', 'stade');
    const fondStade = nom => 'images/Sovarka/Starovka/Starovka_stade_' + nom + '.webp';
    Object.assign(stadeStarovka, {
      name: 'Stade de Starovka',
      desc: 'Le stade du Partizan de Starovka, ouvert au vent glacial. Une seule tribune abrite les vestiaires, la buvette et les locaux du club.'
    });
    Object.assign(piece(stadeStarovka,'vestiaires'), {
      imageUrl: fondStade('vestiaires'),
      desc: 'Vestiaires propres, dépouillés, aménagés sous la tribune, avec des douches chaudes fumantes.'
    });
    Object.assign(piece(stadeStarovka,'bureau_president'), {
      imageUrl: fondStade('bureau_president'),
      desc: 'Bureau vitré du président, en haut des gradins. Une coupe trône dans sa vitrine, au-dessus du terrain et de la ville enneigée.'
    });
    Object.assign(piece(stadeStarovka,'siege_supporters'), {
      imageUrl: fondStade('club_supporters'),
      desc: 'Local vitré des supporters, au sommet de la tribune, donnant directement sur le centre du terrain.'
    });
    Object.assign(piece(stadeStarovka,'buvette'), {
      imageUrl: fondStade('buvette'),
      desc: 'Stand extérieur sous les tribunes, où une vendeuse emmitouflée sert des boissons chaudes et de la vodka.',
      excludeOrders: ['choisir_accessoire_club','acheter_accessoire_personnalise']
    });
    Object.assign(piece(stadeStarovka,'guichet_paris'), {
      imageUrl: fondStade('bookmaker'),
      desc: 'Sous les tribunes, un jeune bookmaker bouriate reçoit les paris des spectateurs frigorifiés.'
    });
    stadeStarovka.roomsExtra = stadeStarovka.roomsExtra || {};
    stadeStarovka.roomsExtra.boutique = {
      name: 'Stand des accessoires du Partizan',
      image: '🧣',
      imageBg: 'linear-gradient(135deg,#1c2025,#2d2526)',
      imageUrl: fondStade('boutique'),
      desc: 'Dans les tribunes, le vendeur de vêtements chauds et d’accessoires du Partizan attend ses clients sous la neige.',
      persons: [{name:'Vendeur des accessoires de Starovka (PNJ)',role:'Vendeur des accessoires du club',rel:'neutral',job:'vendeur'}],
      orders: [
        {fn:'choisir_accessoire_club',label:'Acheter un accessoire',pa:0,cost:0,type:'legal',icon:'ti-shirt',successRate:100,desc:'Écharpe, casquette ou maillot du Partizan de Starovka, à choisir.'},
        {fn:'acheter_accessoire_personnalise',label:'Acheter un accessoire personnalisé',pa:0,cost:0,type:'legal',icon:'ti-lock',successRate:100,desc:'Personnalisation premium à venir.'}
      ]
    };
  }
"""
    data=data.replace(anchor,insert+anchor)
    path.write_text(data,encoding='utf8')
else:
    print('Raccordement déjà présent.')
for output in SOURCES.values():
    assert (FOLDER/output).is_file(),output
print('Six WebP validés, six PNG supprimés, contexte Starovka raccordé.')
