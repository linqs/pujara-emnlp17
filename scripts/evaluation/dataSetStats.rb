# Given a raw dataset, give some stats.

require_relative '../lib/constants'
require_relative '../lib/load'
require_relative '../lib/math-utils'

def tripleStats(label, triples)
   # Get stats on relations per entity and entities per relation.
   # {entity: {relation: count, ...}, ...}
   entities = Hash.new{|hash, key| hash[key] = Hash.new{|innerHash, innerKey| innerHash[innerKey] = 0}}
   relations = Hash.new{|hash, key| hash[key] = Hash.new{|innerHash, innerKey| innerHash[innerKey] = 0}}

   # Triples per entity/realtion.
   entityTripleCounts = Hash.new{|hash, key| hash[key] = 0}
   relationTripleCounts = Hash.new{|hash, key| hash[key] = 0}

   triples.each{|triple|
      entities[triple[Constants::HEAD]][triple[Constants::RELATION]] += 1
      entities[triple[Constants::TAIL]][triple[Constants::RELATION]] += 1

      relations[triple[Constants::RELATION]][triple[Constants::HEAD]] += 1
      relations[triple[Constants::RELATION]][triple[Constants::TAIL]] += 1

      entityTripleCounts[triple[Constants::HEAD]] += 1
      entityTripleCounts[triple[Constants::TAIL]] += 1
      relationTripleCounts[triple[Constants::RELATION]] += 1
   }

   # For each entity, how many relatoions did it touch.
   # Visa-versa for relations.
   relationsPerEntities = entities.values().map{|relations| relations.size()}
   entitiesPerRelation = relations.values().map{|entities| entities.size()}

   triplesPerEntity = entityTripleCounts.values()
   triplesPerRelation = relationTripleCounts.values()

   content = []

   content << "#{label} Triples:"
   content << "   Num Triples: #{triples.size()}"

   content << "   Num Distinct Entities:  #{entities.size()}"
   content << "   Num Distinct Relations: #{relations.size()}"

   content << "   Triples / Entities:  #{triples.size().to_f() / entities.size()}"
   content << "   Triples / Relations: #{triples.size().to_f() / relations.size()}"

   content << "   Relations per Entity:"
   content << "      Mean:   #{MathUtils.mean(relationsPerEntities)}"
   content << "      Median: #{MathUtils.median(relationsPerEntities)}"

   content << "   Entities per Relation:"
   content << "      Mean:   #{MathUtils.mean(entitiesPerRelation)}"
   content << "      Median: #{MathUtils.median(entitiesPerRelation)}"

   content << "   Triples per Entity:"
   content << "      Mean:   #{MathUtils.mean(triplesPerEntity)}"
   content << "      Median: #{MathUtils.median(triplesPerEntity)}"

   content << "   Triples per Relation:"
   content << "      Mean:   #{MathUtils.mean(triplesPerRelation)}"
   content << "      Median: #{MathUtils.median(triplesPerRelation)}"

   return content.join("\n")
end

def dataStats(dataDir)
   # Note that we don't care about int keys.
   testTriples = Load.triples(File.join(dataDir, Constants::RAW_TEST_FILENAME), false)
   trainTriples = Load.triples(File.join(dataDir, Constants::RAW_TRAIN_FILENAME), false)
   validTriples = Load.triples(File.join(dataDir, Constants::RAW_VALID_FILENAME), false)

   statSets = [
      ['Total', testTriples + trainTriples + validTriples],
      ['Test', testTriples],
      ['Train', trainTriples],
      ['Valid', validTriples]
   ]

   content = []
   statSets.each{|label, triples|
      content << tripleStats(label, triples)
   }
   return content.join("\n")
end

def loadArgs(args)
   if (args.size() < 1 || args.size() > 2 || args.map{|arg| arg.gsub('-', '').downcase()}.include?('help'))
      puts "USAGE: ruby #{$0} <data dir> --write"
      puts "   Use --write to also write the output to a file called '#{Constants::STATS_FILENAME}' in the data directory."
      exit(1)
   end

   dataDir = args.shift()
   writeToFile = false

   if (args.size() > 0)
      arg = args.shift()
      if (arg != '--write')
         puts "Unknown arg: #{arg}"
         exit(2)
      end

      writeToFile = true
   end

   return dataDir, writeToFile
end

def genDataStats(dataDir, writeToStdout = false, writeToFile = true)
   statsPath = File.join(dataDir, Constants::STATS_FILENAME)

   # Check for the output file first.
   existingStats = false
   if (File.exists?(statsPath))
      output = IO.read(statsPath)
      existingStats = true
   else
      output = dataStats(dataDir)
   end

   if (writeToStdout)
      puts output
   end

   if (writeToFile && !existingStats)
      File.open(statsPath, 'w'){|file|
         file.puts(output)
      }
   end

   return output
end

def main(args)
   dataDir, writeToFile = loadArgs(args)
   genDataStats(dataDir, true, writeToFile)
end

if ($0 == __FILE__)
   main(ARGV)
end
