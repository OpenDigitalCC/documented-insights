-- sql/05_add_multilingual_stopwords.sql
-- Add multilingual stopwords for European languages

-- French stopwords
INSERT INTO stopwords (word, language) VALUES
    ('les','french'),('des','french'),('pour','french'),('dans','french'),
    ('une','french'),('est','french'),('que','french'),('pas','french'),
    ('plus','french'),('sur','french'),('qui','french'),('avec','french'),
    ('sont','french'),('nous','french'),('ont','french'),('peut','french'),
    ('aux','french'),('par','french'),('tout','french'),('mais','french'),
    ('ses','french'),('cette','french'),('ces','french'),('leurs','french'),
    ('dont','french'),('nos','french'),('lui','french'),('tous','french'),
    ('fait','french'),('faire','french'),('leurs','french'),('sans','french'),
    ('aussi','french'),('encore','french'),('donc','french'),('où','french'),
    ('leur','french'),('sous','french'),('entre','french'),('depuis','french'),
    ('tant','french'),('moins','french'),('même','french'),('celui','french'),
    ('celle','french'),('ceux','french'),('celles','french'),('chez','french'),
    ('vers','french'),('ainsi','french'),('toute','french'),('toutes','french'),
    ('quelques','french'),('plusieurs','french'),('chaque','french')
ON CONFLICT (word) DO NOTHING;

-- German stopwords
INSERT INTO stopwords (word, language) VALUES
    ('die','german'),('der','german'),('und','german'),('ist','german'),
    ('den','german'),('das','german'),('nicht','german'),('von','german'),
    ('dem','german'),('mit','german'),('des','german'),('sich','german'),
    ('auch','german'),('wird','german'),('auf','german'),('für','german'),
    ('als','german'),('ein','german'),('eine','german'),('oder','german'),
    ('zum','german'),('zur','german'),('über','german'),('wird','german'),
    ('werden','german'),('wurde','german'),('können','german'),('kann','german'),
    ('sind','german'),('bei','german'),('aus','german'),('durch','german'),
    ('wie','german'),('nach','german'),('mehr','german'),('sein','german'),
    ('seine','german'),('einer','german'),('eines','german'),('einem','german'),
    ('einen','german'),('sowie','german'),('nur','german'),('unter','german'),
    ('haben','german'),('hat','german'),('aber','german'),('bereits','german'),
    ('bzw','german'),('bzw.','german'),('z.b.','german'),('etc','german'),
    ('bereits','german'),('insbesondere','german'),('beispielsweise','german')
ON CONFLICT (word) DO NOTHING;

-- Italian stopwords  
INSERT INTO stopwords (word, language) VALUES
    ('della','italian'),('delle','italian'),('dei','plural'),('degli','italian'),
    ('una','italian'),('uno','italian'),('nella','italian'),('nel','italian'),
    ('con','italian'),('per','italian'),('sono','italian'),('stato','italian'),
    ('gli','italian'),('alla','italian'),('dal','italian'),('anche','italian'),
    ('più','italian'),('tra','italian'),('sia','italian'),('sul','italian'),
    ('dalla','italian'),('fino','italian'),('tutto','italian'),('tutti','italian'),
    ('questa','italian'),('questo','italian'),('questi','italian'),('queste','italian'),
    ('ogni','italian'),('già','italian'),('dove','italian'),('quando','italian'),
    ('mentre','italian'),('ancora','italian'),('invece','italian'),('infatti','italian'),
    ('quindi','italian'),('inoltre','italian'),('proprio','italian'),('ancora','italian')
ON CONFLICT (word) DO NOTHING;

-- Spanish stopwords
INSERT INTO stopwords (word, language) VALUES
    ('los','spanish'),('las','spanish'),('del','spanish'),('una','spanish'),
    ('para','spanish'),('con','spanish'),('por','spanish'),('como','spanish'),
    ('sobre','spanish'),('este','spanish'),('esta','spanish'),('estos','spanish'),
    ('estas','spanish'),('sin','spanish'),('entre','spanish'),('desde','spanish'),
    ('hasta','spanish'),('cuando','spanish'),('donde','spanish'),('cada','spanish'),
    ('todos','spanish'),('todas','spanish'),('todo','spanish'),('toda','spanish'),
    ('otro','spanish'),('otra','spanish'),('otros','spanish'),('otras','spanish'),
    ('mismo','spanish'),('misma','spanish'),('tal','spanish'),('tanto','spanish'),
    ('además','spanish'),('también','spanish'),('sino','spanish'),('aunque','spanish'),
    ('mientras','spanish'),('porque','spanish'),('durante','spanish')
ON CONFLICT (word) DO NOTHING;

-- Dutch stopwords
INSERT INTO stopwords (word, language) VALUES
    ('het','dutch'),('een','dutch'),('van','dutch'),('voor','dutch'),
    ('met','dutch'),('worden','dutch'),('zijn','dutch'),('ook','dutch'),
    ('naar','dutch'),('bij','dutch'),('aan','dutch'),('als','dutch'),
    ('over','dutch'),('onder','dutch'),('uit','dutch'),('nog','dutch'),
    ('deze','dutch'),('dit','dutch'),('die','dutch'),('dat','dutch'),
    ('alle','dutch'),('door','dutch'),('tussen','dutch'),('zonder','dutch'),
    ('wordt','dutch'),('kunnen','dutch'),('moet','dutch'),('meer','dutch'),
    ('andere','dutch'),('veel','dutch'),('enkele','dutch'),('tijdens','dutch')
ON CONFLICT (word) DO NOTHING;

-- Portuguese stopwords
INSERT INTO stopwords (word, language) VALUES
    ('dos','portuguese'),('das','portuguese'),('uma','portuguese'),('para','portuguese'),
    ('com','portuguese'),('por','portuguese'),('como','portuguese'),('sobre','portuguese'),
    ('este','portuguese'),('esta','portuguese'),('estes','portuguese'),('estas','portuguese'),
    ('sem','portuguese'),('entre','portuguese'),('desde','portuguese'),('até','portuguese'),
    ('quando','portuguese'),('onde','portuguese'),('cada','portuguese'),('todos','portuguese'),
    ('todas','portuguese'),('todo','portuguese'),('toda','portuguese'),('outro','portuguese'),
    ('outra','portuguese'),('outros','portuguese'),('outras','portuguese'),('mesmo','portuguese'),
    ('mesma','portuguese'),('além','portuguese'),('também','portuguese'),('porque','portuguese')
ON CONFLICT (word) DO NOTHING;

-- Common English words not in original list
INSERT INTO stopwords (word, language) VALUES
    ('are','english'),('where','english'),('here','english'),('both','english'),
    ('either','english'),('neither','english'),('within','english'),('often','english'),
    ('always','english'),('never','english'),('via','english'),('per','english'),
    ('among','english'),('whilst','english'),('including','english'),('regarding','english'),
    ('concerning','english'),('towards','english'),('upon','english'),('across','english'),
    ('along','english'),('around','english'),('beyond','english'),('despite','english'),
    ('during','english'),('following','english'),('next','english'),('previous','english'),
    ('using','english'),('given','english'),('become','english'),('becomes','english'),
    ('becoming','english'),('became','english'),('else','english'),('elsewhere','english'),
    ('hereby','english'),('herein','english'),('thereof','english'),('whereby','english'),
    ('wherein','english'),('throughout','english'),('unless','english'),('whether','english')
ON CONFLICT (word) DO NOTHING;
