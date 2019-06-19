require_relative '../../lib/constants'

require 'date'
require 'fileutils'
require 'set'

require 'pg'

OUT_BASENAME = 'NELL_SPARSE'
DB_NAME = 'nell'

# TODO(eriq): Get rid of this once we have the human test/valid data.
# How much of the data to use for a training set.
TRAINING_PERCENT = 0.90

MAINTENANCE_PERIOD = 1000

DEFAULT_MIN_PROBABILITY = 0.95
DEFAULT_MAX_PROBABILITY = 1.00

# Triples Per Entity sparsity target.
DEFAULT_SPARSITY_TARGET_TPE = 3.3478

# About the same as Freebase.
DEFAULT_MAX_TRIPLES = 600000

def formatDatasetName(suffix, minProbability, maxProbability, sparsityTarget, maxTriples)
   probabilityString = "#{"%03d" % (minProbability * 100)}_#{"%03d" % (maxProbability * 100)}"
   paramSection = "#{sparsityTarget};#{maxTriples}"

   return "#{OUT_BASENAME}_#{probabilityString}_[#{paramSection}]_#{suffix}"
end

def fetchTriples(minProbability, maxProbability)
   conn = PG::Connection.new(:host => 'localhost', :dbname => DB_NAME)

   query = "
      SELECT
         T.head,
         T.tail,
         T.relation
      FROM Triples T
      WHERE T.probability BETWEEN #{minProbability} AND #{maxProbability}
   "

   result = conn.exec(query).values()
   conn.close()

   puts "Fetched #{result.size()} triples"

   return result
end

def groomTriples(allTriples, sparsityTarget, maxTriples)
   entityCounts = {}
   entityTriples = Hash.new{|hash, key| hash[key] = []}
   tripleEntities = Hash.new{|hash, key| hash[key] = []}

   entityAdjacencies = Hash.new{|hash, key| hash[key] = []}
   entityAdjacencyCounts = {}

   candidateEntities = nil

   allTriples.each_index{|index|
      entityTriples[allTriples[index][Constants::HEAD].to_i()] << index
      entityTriples[allTriples[index][Constants::TAIL].to_i()] << index

      tripleEntities[index] << allTriples[index][Constants::HEAD].to_i()
      tripleEntities[index] << allTriples[index][Constants::TAIL].to_i()

      entityAdjacencies[allTriples[index][Constants::HEAD].to_i()] << allTriples[index][Constants::TAIL].to_i()
      entityAdjacencies[allTriples[index][Constants::TAIL].to_i()] << allTriples[index][Constants::HEAD].to_i()
   }
   candidateEntities = Set.new(entityTriples.keys())

   entityTriples.each{|entity, triples|
      entityCounts[entity] = triples.size()

      entityAdjacencies[entity].uniq!()
      entityAdjacencyCounts[entity] = entityAdjacencies[entity].size()
   }

   puts "Stats computed"

   tripleIndexes = Set.new()
   activeEntities = Set.new()

   numActiveTriples = 0.0
   numActiveEntities = 0.0

   iteration = 1
   while (tripleIndexes.size() < maxTriples)
      # Best candidate for addition.
      bestEntity = nil
      bestTPE = nil
      bestTripleCount = nil
      bestEntityCount = nil
      seenNon1 = false

      candidateEntities.each{|entity|
         # Note that more than one entity may be added each iteration.
         tripleCount = entityCounts[entity]
         entityCount = entityAdjacencyCounts[entity] + 1
         tpe = (numActiveTriples + tripleCount) / (numActiveEntities + entityCount)

         if (bestEntity == nil || ((sparsityTarget - tpe).abs() < (sparsityTarget - bestTPE).abs()))
            bestEntity = entity
            bestTPE = tpe
            bestTripleCount = tripleCount
            bestEntityCount = entityCount
         end

         if (!seenNon1 && tripleCount != 1)
            seenNon1 = true
         end
      }

      candidateEntities.delete(bestEntity)

      # Recalc stats
      entityTriples[bestEntity].each{|tripleIndex|
         tripleEntities[tripleIndex].each{|entity|
            entityCounts[entity] -= 1
         }
      }

      entityAdjacencies[bestEntity].each{|entity|
         entityAdjacencyCounts[entity] -= 1
      }

      tripleIndexes += entityTriples[bestEntity]
      activeEntities += entityAdjacencies[bestEntity]
      activeEntities << bestEntity

      # Sync the sizes counts.
      numActiveTriples = tripleIndexes.size().to_f()
      numActiveEntities = activeEntities.size().to_f()

      puts "Finished iteration #{"%03d" % iteration} - #{numActiveTriples} / #{numActiveEntities} (#{bestTPE})"
      iteration += 1
   end

   triples = []
   tripleIndexes.each{|tripleIndex|
      triples << allTriples[tripleIndex]
   }

   return triples
end

def writeEntities(path, triples)
   entities = []
   entities += triples.map{|triple| triple[Constants::HEAD]}
   entities += triples.map{|triple| triple[Constants::TAIL]}
   entities.uniq!

   File.open(path, 'w'){|file|
      file.puts(entities.map.with_index{|entity, index| "#{entity}\t#{index}"}.join("\n"))
   }
end

def writeRelations(path, triples)
   relations = triples.map{|triple| triple[Constants::RELATION]}
   relations.uniq!

   File.open(path, 'w'){|file|
      file.puts(relations.map.with_index{|relation, index| "#{relation}\t#{index}"}.join("\n"))
   }
end

def writeTriples(path, triples)
    File.open(path, 'w'){|file|
      # Head, Tail, Relation
      file.puts(triples.map{|triple| triple.join("\t")}.join("\n"))
    }
end

def printUsage()
   puts "USAGE: ruby #{$0} [min probability [max probability [sparsity target [max triples [suffix]]]]]"
   puts "Defaults:"
   puts "   min probability = #{DEFAULT_MIN_PROBABILITY}"
   puts "   max probability = #{DEFAULT_MAX_PROBABILITY}"
   puts "   sparsity target (tpe) = #{DEFAULT_SPARSITY_TARGET_TPE}"
   puts "   max triples = #{DEFAULT_MAX_TRIPLES}"
   puts "   suffix = now"
   puts "Data will be created in #{Constants::RAW_DATA_PATH}"
end

def parseArgs(args)
   if (args.size() > 5 || args.map{|arg| arg.downcase().gsub('-', '')}.include?('help'))
      printUsage()
      exit(2)
   end

   minProbability = DEFAULT_MIN_PROBABILITY
   maxProbability = DEFAULT_MAX_PROBABILITY
   sparsityTarget = DEFAULT_SPARSITY_TARGET_TPE
   maxTriples = DEFAULT_MAX_TRIPLES
   suffix = DateTime.now().strftime('%Y%m%d%H%M')

   if (args.size() > 0)
      minProbability = args.shift().to_f()
   end

   if (args.size() > 0)
      maxProbability = args.shift().to_f()
   end

   if (args.size() > 0)
      sparsityTarget = args.shift().to_f()
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

   return minProbability, maxProbability, sparsityTarget, maxTriples, suffix
end

def main(args)
   minProbability, maxProbability, sparsityTarget, maxTriples, suffix = parseArgs(args)

   datasetDir = File.join(Constants::RAW_DATA_PATH, formatDatasetName(suffix, minProbability, maxProbability, sparsityTarget, maxTriples))
   FileUtils.mkdir_p(datasetDir)

   puts "Generating #{datasetDir} ..."

   triples = fetchTriples(minProbability, maxProbability)
   triples = groomTriples(triples, sparsityTarget, maxTriples)

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
