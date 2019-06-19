-- Link surrogate keys.

UPDATE EntityLiteralStrings ELS
SET entityId = E.id
FROM Entities E
WHERE E.nellId = ELS.entityNellId
;

UPDATE EntityCategories EC
SET entityId = E.id
FROM Entities E
WHERE E.nellId = EC.entityNellId
;

UPDATE Triples T
SET head = E.id
FROM Entities E
WHERE E.nellId = T.headNellId
;

UPDATE Triples T
SET relation = R.id
FROM Relations R
WHERE R.nellId = T.relationNellId
;

UPDATE Triples T
SET tail = E.id
FROM Entities E
WHERE E.nellId = T.tailNellId
;

-- Drop redundant columns.
ALTER TABLE EntityLiteralStrings
DROP COLUMN entityNellId
;

ALTER TABLE EntityCategories
DROP COLUMN entityNellId
;

ALTER TABLE Triples
DROP COLUMN headNellId,
DROP COLUMN relationNellId,
DROP COLUMN tailNellId
;

-- Simple Indexes
CREATE INDEX IX_Triples_head ON Triples (head);
CREATE INDEX IX_Triples_relation ON Triples (relation);
CREATE INDEX IX_Triples_tail ON Triples (tail);
CREATE INDEX IX_Triples_probability_head_relation_tail ON Triples (probability, head, relation, tail);
CREATE INDEX IX_Entities_isConcept_id ON Entities (isConcept, id);
CREATE INDEX IX_EntityCategories_entityId ON EntityCategories (entityId);

-- Enable if we start using literals.
-- CREATE INDEX IX_EntityLiteralStrings_entityId ON EntityLiteralStrings (entityId);

-- Support table

-- Note that these are the number of triples each entity occurs in,
-- NOT the number of total appearances (because of identity relations).

CREATE TABLE EntityCounts (
   id SERIAL CONSTRAINT PK_EntityCounts_id PRIMARY KEY,
   entityId INT NOT NULL REFERENCES Entities,
   entityCount INT,
   centile INT,
   UNIQUE(entityId)
);

CREATE TABLE RelationCounts (
   id SERIAL CONSTRAINT PK_RelationCounts_id PRIMARY KEY,
   relationId INT NOT NULL REFERENCES Relations,
   relationCount INT,
   centile INT,
   UNIQUE(relationId)
);

INSERT INTO EntityCounts
   (entityId, entityCount)
SELECT
   entity,
   COUNT(*) AS entityCount
FROM (
   SELECT
      id AS tripleId,
      head AS entity
   FROM Triples

   UNION

   SELECT
      id AS tripleId,
      tail AS entity
   FROM Triples
) X
GROUP BY entity
;

INSERT INTO RelationCounts
   (relationId, relationCount)
SELECT
   relation,
   COUNT(*) AS relationCount
FROM Triples
GROUP BY relation
;

-- Add in centiles.
UPDATE RelationCounts RC
SET centile = T.tile
FROM (
   SELECT
      id,
      NTILE(100) OVER (ORDER BY relationCount) AS tile
   FROM RelationCounts
) T
WHERE T.id = RC.id
;

UPDATE EntityCounts EC
SET centile = T.tile
FROM (
   SELECT
      id,
      NTILE(100) OVER (ORDER BY entityCount) AS tile
   FROM EntityCounts
) T
WHERE T.id = EC.id
;

CREATE INDEX IX_EntityCounts_entityCount_entityId ON EntityCounts (entityCount, entityId);
CREATE INDEX IX_RelationCounts_relationCount_relationId ON RelationCounts (relationCount, relationId);

CREATE INDEX IX_EntityCounts_centile_entityId ON EntityCounts (centile, entityId);
CREATE INDEX IX_RelationCounts_centile_relationId ON RelationCounts (centile, relationId);

-- Triples that may appear in the embedding data set.
CREATE TABLE CandidateTriples (
   id SERIAL CONSTRAINT PK_CandidateTriples_id PRIMARY KEY,
   tripleId INT NOT NULL REFERENCES Triples UNIQUE
);

INSERT INTO CandidateTriples
   (tripleId)
SELECT T.id
FROM
   Triples T
   JOIN Entities HE ON HE.id = T.head
   JOIN Entities TE ON TE.id = T.tail
   JOIN Relations R ON R.id = T.relation

   -- Limit to only concepts.
   -- The head is always a concept, but just playing it safe.
   JOIN (
      SELECT id
      FROM Entities
      WHERE isConcept = TRUE
   ) HC ON HC.id = T.head
   JOIN (
      SELECT id
      FROM Entities
      WHERE isConcept = TRUE
   ) TC ON TC.id = T.tail

   -- Limit each part to having some number of mentions.
   JOIN (
      SELECT entityId
      FROM EntityCounts
      WHERE entityCount >= 10
   ) HEC ON HEC.entityId = T.head
   JOIN (
      SELECT entityId
      FROM EntityCounts
      WHERE entityCount >= 10
   ) TEC ON TEC.entityId = T.tail
   JOIN (
      SELECT relationId
      FROM RelationCounts
      WHERE relationCount >= 5
   ) RC ON RC.relationId = T.relation
;

CREATE INDEX IX_CandidateTriples_tripleId ON CandidateTriples (tripleId);
