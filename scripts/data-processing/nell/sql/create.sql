-- TODO(eriq): Are cetegories shared between entities and relations?
-- TODO(eriq): Examine the literal strings to see if they are shared.
-- TODO(eriq): Check for other columns that need url decoding.
-- TODO(eriq): Should "value" and "best value" for literal strings be the same?
--             (make best value a self referncing FK?)

-- NOTE(eriq): We are dropping some information in the decomposition.
--             We will no longer know the text associated with a specific triple.
--             We will only know all the text associated with each entity.

-- TODO(eriq): Study the duplication in literals and categories.
--             They most likely should need another table.

CREATE TABLE Entities (
   id SERIAL CONSTRAINT PK_Entities_id PRIMARY KEY,
   isConcept BOOLEAN NOT NULL,
   nellId TEXT NOT NULL UNIQUE
);

CREATE TABLE Relations (
   id SERIAL CONSTRAINT PK_Relations_id PRIMARY KEY,
   nellId TEXT NOT NULL UNIQUE
);

CREATE TABLE Triples (
   id SERIAL CONSTRAINT PK_Triples_id PRIMARY KEY,
   head INT REFERENCES Entities,
   headNellId TEXT NOT NULL, -- Will be dropped after FKs are linked.
   relation INT REFERENCES Relations,
   relationNellId TEXT NOT NULL, -- Will be dropped after FKs are linked.
   tail INT REFERENCES Entities,
   tailNellId TEXT NOT NULL, -- Will be dropped after FKs are linked.
   promotionIteration INT,
   probability FLOAT,
   source TEXT,
   candidateSource TEXT,
   UNIQUE(head, relation, tail)
);

CREATE TABLE EntityLiteralStrings (
   id SERIAL CONSTRAINT PK_EntityLiteralStrings_id PRIMARY KEY,
   entityId INT REFERENCES Entities,
   entityNellId TEXT NOT NULL, -- Will be dropped after FKs are linked.
   literal TEXT,
   bestLiteral TEXT
);

CREATE TABLE EntityCategories (
   id SERIAL CONSTRAINT PK_EntityCategories_id PRIMARY KEY,
   entityId INT REFERENCES Entities,
   entityNellId TEXT NOT NULL, -- Will be dropped after FKs are linked.
   category TEXT
);

/* Sample
01 - Entity
02 - Relation
03 - Value
04 - Iteration of Promotion
05 - Probability
06 - Source
07 - Entity literalStrings
08 - Value literalStrings
09 - Best Entity literalString
10 - Best Value literalString
11 - Categories for Entity
12 - Categories for Value
13 - Candidate Source

01 - concept:personasia:michael_berne
02 - concept:haswikipediaurl
03 - http://en.wikipedia.org/wiki/Michael%20Berne
04 - 710
05 - 0.95
06 - MBL-Iter%3A710-2013%2F03%2F13-12%3A17%3A37-From+ErrorBasedIntegrator+%28AliasMatcher%28%2C%29%29
07 - "Michael Berne" 
08 - "http://en.wikipedia.org/wiki/Michael%20Berne" 
09 - Michael Berne
10 - http://en.wikipedia.org/wiki/Michael%20Berne
11 - 
12 - 
13 - %5BAliasMatcher-Iter%3A621-2012%2F08%2F03-10%3A35%3A59-%3Ctoken%3D%3E-Freebase+7%2F9%2F2012%5D
*/
