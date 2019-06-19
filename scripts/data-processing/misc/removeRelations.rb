# Remove triples without significantly decreasing sparsity.
# Uniformly select a relation and remove all triples using that relation.
# When we pass the specified number of triples to remove, stop.

require_relative '../../lib/constants'
require_relative '../../lib/load'

require 'fileutils'
require 'set'

SEED = 4

REMOVED_RELATIONS_FILENAME = 'removedRelations.txt'
REMOVED_TRIPLES_BASENAME = 'removedTriples'

# Choose the relations to remove and return their ids.
# Note that we only look at the training set for removal counts.
def chooseRemovalRelations(dataDir, outDir, numRemove)
   rand = Random.new(SEED)

   triples = Load.triples(File.join(dataDir, Constants::RAW_TRAIN_FILENAME), false)
   removedRelations = []

   # Build a map with relation counts.
   relationMap = Hash.new{|hash, key| hash[key] = 0}
   triples.each{|triple|
      relationMap[triple[Constants::RELATION]] += 1
   }
  
   # Just a list of all the relation keys.
   relations = relationMap.keys()

   removedCount = 0
   while (removedCount < numRemove)
      relation = relations[rand.rand(relations.size())]
      relations.delete(relation)
      removedCount += relationMap[relation]
      removedRelations << relation
   end

   File.open(File.join(outDir, REMOVED_RELATIONS_FILENAME), 'w'){|file|
      file.puts(removedRelations.sort().join("\n"))
   }

   return Set.new(removedRelations)
end

# The int indexes (second value in the file) needs to be re done since no holes are allowed.
def removeRelationsFromMap(dataDir, outDir, removedRelations)
   inPath = File.join(dataDir, Constants::RAW_RELATION_MAPPING_FILENAME)
   outPath = File.join(outDir, Constants::RAW_RELATION_MAPPING_FILENAME)

   relationMap = Load.idMapping(inPath, false)
   outputRelations = []

   relationMap.each{|id, index|
      if (!removedRelations.include?(id))
         outputRelations << "#{id}\t#{outputRelations.size()}"
      end
   }

   File.open(outPath, 'w'){|file|
      file.puts(outputRelations.join("\n"))
   }
end

def removeRelationsFromTriples(dataDir, outDir, filename, outSuffix, removedRelations)
   inPath = File.join(dataDir, filename)
   outPath = File.join(outDir, filename)

   triples = Load.triples(inPath, false)
   removedTriples = []

   triples.each_index().to_a().reverse().each{|index|
      if (removedRelations.include?(triples[index][Constants::RELATION]))
         removedTriples << triples.delete_at(index)
      end
   }

   File.open(outPath, 'w'){|file|
      file.puts(triples.map{|triple| triple.join("\t")}.join("\n"))
   }

   File.open(File.join(outDir, "#{REMOVED_TRIPLES_BASENAME}_#{outSuffix}.txt"), 'w'){|file|
      file.puts(removedTriples.map{|triple| triple.join("\t")}.join("\n"))
   }
end

def parseArgs(args)
   if (args.size != 2 || args.map{|arg| arg.gsub('-', '').downcase()}.include?('help'))
      puts "USAGE: ruby #{$0} <data dir> <num triples to remove>"
      puts "   Output will be written in a new directory adjacent to |data dir|, called |data dir|_RR[N]"
      puts "   Where 'N' is the number of relations to remove (zero padded to 6 digits)."
      puts "   'RR' stands for 'Relations Removed'."
      exit(1)
   end

   dataDir = args.shift()
   numRemove = args.shift().to_i()

   if (numRemove < 1)
      puts "Number of triples to remove must be at least 1 (found #{numRemove})."
      exit(2)
   end

   return dataDir, numRemove
end

def main(args)
   dataDir, numRemove = parseArgs(args)
   outDir = File.absolute_path(dataDir) + "_RR[#{"%06d" % numRemove}]"
   FileUtils.mkdir_p(outDir)

   puts "Removing triples and creating new dataset in: #{outDir}"

   # Copy over the entity mapping.
   FileUtils.cp(File.join(dataDir, Constants::RAW_ENTITY_MAPPING_FILENAME), File.join(outDir, Constants::RAW_ENTITY_MAPPING_FILENAME))

   removedRelations = chooseRemovalRelations(dataDir, outDir, numRemove)
   removeRelationsFromMap(dataDir, outDir, removedRelations)

   replaceFiles = [
      [Constants::RAW_TEST_FILENAME, 'test'],
      [Constants::RAW_TRAIN_FILENAME, 'train'],
      [Constants::RAW_VALID_FILENAME, 'valid']
   ]

   replaceFiles.each{|filename, suffix|
      removeRelationsFromTriples(dataDir, outDir, filename, suffix, removedRelations)
   }
end

if ($0 == __FILE__)
   main(ARGV)
end
