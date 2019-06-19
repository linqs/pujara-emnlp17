require_relative '../../lib/constants'

require 'date'
require 'fileutils'

require 'pg'

OUT_BASENAME = 'NELL'
DB_NAME = 'nell'

# How much of the data to use for a training set.
TRAINING_PERCENT = 0.90

NUM_TILES = 100

DEFAULT_MIN_PROBABILITY = 0.95
DEFAULT_MAX_PROBABILITY = 1.00
DEFAULT_MIN_ENTITY_TILE = 95
DEFAULT_MAX_ENTITY_TILE = 100
DEFAULT_MIN_RELATION_TILE = 10
DEFAULT_MAX_RELATION_TILE = 40

# About the same as Freebase.
DEFAULT_MAX_TRIPLES = 600000

def formatDatasetName(suffix, minProbability, maxProbability, minEntityTile, maxEntityTile, minRelationTile, maxRelationTile, maxTriples)
   probabilityString = "#{"%03d" % (minProbability * 100)}_#{"%03d" % (maxProbability * 100)}"
   entityTile = "#{"%03d" % minEntityTile},#{"%03d" % maxEntityTile}"
   relationTile = "#{"%03d" % minRelationTile},#{"%03d" % maxRelationTile}"
   paramSection = "#{entityTile};#{relationTile};#{maxTriples}"

   return "#{OUT_BASENAME}_#{probabilityString}_[#{paramSection}]_#{suffix}"
end

def fetchTriples(minProbability, maxProbability, minEntityTile, maxEntityTile, minRelationTile, maxRelationTile, maxTriples)
   conn = PG::Connection.new(:host => 'localhost', :dbname => DB_NAME)

   query = "
      SELECT
         T.head,
         T.relation,
         T.tail
      FROM
         Triples T
         JOIN RelationCounts RC ON RC.relationId = T.relation
         JOIN EntityCounts ECH ON ECH.entityId = T.head
         JOIN EntityCounts ECT ON ECT.entityId = T.tail
      WHERE
         T.probability BETWEEN #{minProbability} AND #{maxProbability}
         AND RC.centile BETWEEN #{minRelationTile} AND #{maxRelationTile}
         AND ECH.centile BETWEEN #{minEntityTile} AND #{maxEntityTile}
         AND ECT.centile BETWEEN #{minEntityTile} AND #{maxEntityTile}
      LIMIT #{maxTriples}
   "

   result = conn.exec(query).values()
   conn.close()

   puts "Got #{result.size()} triples"

   return result
end

def writeEntities(path, triples)
   entities = []
   entities += triples.map{|triple| triple[0]}
   entities += triples.map{|triple| triple[2]}
   entities.uniq!

   File.open(path, 'w'){|file|
      file.puts(entities.map.with_index{|entity, index| "#{entity}\t#{index}"}.join("\n"))
   }
end

def writeRelations(path, triples)
   relations = triples.map{|triple| triple[1]}
   relations.uniq!

   File.open(path, 'w'){|file|
      file.puts(relations.map.with_index{|relation, index| "#{relation}\t#{index}"}.join("\n"))
   }
end

def writeTriples(path, triples)
    File.open(path, 'w'){|file|
      # Head, Tail, Relation
      file.puts(triples.map{|triple| "#{triple[0]}\t#{triple[2]}\t#{triple[1]}"}.join("\n"))
    }
end

def printUsage()
   puts "USAGE: ruby #{$0} [min probability [max probability [min entity tile [max entity tile [min relation tile [max relation tile [max triples [suffix]]]]]]]]"
   puts "Defaults:"
   puts "   min probability = #{DEFAULT_MIN_PROBABILITY}"
   puts "   max probability = #{DEFAULT_MAX_PROBABILITY}"
   puts "   min entity tile = #{DEFAULT_MIN_ENTITY_TILE}"
   puts "   max entity tile = #{DEFAULT_MAX_ENTITY_TILE}"
   puts "   min relation tile = #{DEFAULT_MIN_RELATION_TILE}"
   puts "   max relation tile = #{DEFAULT_MAX_RELATION_TILE}"
   puts "   max triples = #{DEFAULT_MAX_TRIPLES}"
   puts "   suffix = now"
   puts ""
   puts "Enities are partitioned into centiles (by count) and the range of tiles specified as arguments will get selected."
   puts "Data will be created in #{Constants::RAW_DATA_PATH}"
end

def parseArgs(args)
   if (args.size() > 8 || args.map{|arg| arg.downcase().gsub('-', '')}.include?('help'))
      printUsage()
      exit(2)
   end

   minProbability = DEFAULT_MIN_PROBABILITY
   maxProbability = DEFAULT_MAX_PROBABILITY
   minEntityTile = DEFAULT_MIN_ENTITY_TILE
   maxEntityTile = DEFAULT_MAX_ENTITY_TILE
   minRelationTile = DEFAULT_MIN_RELATION_TILE
   maxRelationTile = DEFAULT_MAX_RELATION_TILE
   maxTriples = DEFAULT_MAX_TRIPLES
   suffix = DateTime.now().strftime('%Y%m%d%H%M')

   if (args.size() > 0)
      minProbability = args.shift().to_f()
   end

   if (args.size() > 0)
      maxProbability = args.shift().to_f()
   end

   if (args.size() > 0)
      minEntityTile = args.shift().to_i()
   end

   if (args.size() > 0)
      maxEntityTile = args.shift().to_i()
   end

   if (args.size() > 0)
      minRelationTile = args.shift().to_i()
   end

   if (args.size() > 0)
      maxRelationTile = args.shift().to_i()
   end

   if (args.size() > 0)
      maxTriples = args.shift().to_i()
   end

   if (args.size() > 0)
      suffix = args.shift()
   end

   if (minProbability < 0 || minProbability > 1 || maxProbability < 0 || maxProbability > 1)
      puts "Probabilities should be between 0 and 1 inclusive."
      exit(3)
   end

   if (maxTriples < 0)
      puts "Max Triples needs to be non-negative."
      exit(4)
   end

   if (minEntityTile < 1 || maxEntityTile > NUM_TILES || minRelationTile < 1 || maxRelationTile > NUM_TILES)
      puts "Entity/Relation tiles must be in [1, #{NUM_TILES}]."
      exit(5)
   end

   if (minEntityTile > maxEntityTile || minRelationTile > maxRelationTile)
      puts "Entity/Relation tile max must be greater than min."
      exit(6)
   end

   return minProbability, maxProbability, minEntityTile, maxEntityTile, minRelationTile, maxRelationTile, maxTriples, suffix
end

def main(args)
   minProbability, maxProbability, minEntityTile, maxEntityTile, minRelationTile, maxRelationTile, maxTriples, suffix = parseArgs(args)

   datasetDir = File.join(Constants::RAW_DATA_PATH, formatDatasetName(suffix, minProbability, maxProbability, minEntityTile, maxEntityTile, minRelationTile, maxRelationTile, maxTriples))
   FileUtils.mkdir_p(datasetDir)

   puts "Generating #{datasetDir} ..."

   triples = fetchTriples(minProbability, maxProbability, minEntityTile, maxEntityTile, minRelationTile, maxRelationTile, maxTriples)

   writeEntities(File.join(datasetDir, Constants::RAW_ENTITY_MAPPING_FILENAME), triples)
   writeRelations(File.join(datasetDir, Constants::RAW_RELATION_MAPPING_FILENAME), triples)

   # TODO(eriq): We probably need smarter splitting?
   trainingSize = (triples.size() * TRAINING_PERCENT).to_i()

   # Both test and valid sets will get this count.
   # The rounding error on odd is a non-issue. The valid will just have one less.
   testSize = ((triples.size() - trainingSize) / 2 + 0.5).to_i()

   triples.shuffle!
   trainingSet = triples.slice(0, trainingSize)
   testSet = triples.slice(trainingSize, testSize)
   validSet = triples.slice(trainingSize + testSize, testSize)

   writeTriples(File.join(datasetDir, Constants::RAW_TRAIN_FILENAME), trainingSet)
   writeTriples(File.join(datasetDir, Constants::RAW_TEST_FILENAME), testSet)
   writeTriples(File.join(datasetDir, Constants::RAW_VALID_FILENAME), validSet)
end

if (__FILE__ == $0)
   main(ARGV)
end
