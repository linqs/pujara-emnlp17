# PTransE requires knowing the top 500 entity pairs (lowest energy according to TransE) for each corruption.
# It also requires using the entity's surrogate key (index) instead of identifier.

require_relative '../lib/constants'
require_relative '../lib/embedding/energies'
require_relative '../lib/load'

DEFAULT_NUM_PAIRS = 500
BASE_OUTPUT_NAME = 'topEntityPairs'
PAIRS_PAGE_SIZE = 100000

# Here we are taking a performance hit to make the program simpler.
# We will be computing the corruptions each triple at a time.
# This means that there will be some redundancy in calculations.
def computeTopPairs(dataDir, embeddingDir, numPairs)
   allPairs = []

   # We are corrupting the test set.
   triples = Load.triples(File.join(dataDir, Constants::RAW_TEST_FILENAME), false)

   energyMethod = Energies.getEnergyMethodFromPath(embeddingDir)
   entityMapping = Load.idMapping(File.join(dataDir, Constants::RAW_ENTITY_MAPPING_FILENAME), false)
   relationMapping = Load.idMapping(File.join(dataDir, Constants::RAW_RELATION_MAPPING_FILENAME), false)
   entityEmbeddings, relationEmbeddings = LoadEmbedding.vectors(embeddingDir)

   triples.each{|triple|
      # TEST
      puts "Computing #{triple} ..."

      corruptionEnergies = []

      Energies.computeCorruptionEnergies(
            [triple],
            entityMapping, relationMapping,
            entityEmbeddings, relationEmbeddings, energyMethod) {|energies|
         corruptionEnergies += energies

         # TEST
         puts "   Got #{energies.size()} energies"
      }

      topPairs = corruptionEnergies.sort{|a, b| a[1] <=> b[1]}.first(numPairs)

      # Pull out only the entities.
      topPairs.map!{|triple, energy| [triple[Constants::HEAD], triple[Constants::TAIL]]}

      # Translate the ids into surrogate keys.
      topPairs.map!{|head, tail| [entityMapping[head], entityMapping[tail]]}

      allPairs += topPairs

      # TEST
      puts "Computed #{triple}"
   }

   return allPairs.uniq()
end

def parseArgs(args)
   if (args.size() < 2 || args.size() > 3 || args.map{|arg| arg.gsub('-', '').downcase()}.include?('help'))
      puts "USAGE: ruby #{$0} <data dir> <embedding dir> [num pairs]"
      puts "   The output will be placed in /embedding/dir/#{BASE_OUTPUT_NAME}_numPairs.txt"
      puts "   It is up to the caller to rename the file as appropriate for the embedding trainer."
      exit(1)
   end

   dataDir = args.shift()
   embeddingDir = args.shift()
   numPairs = DEFAULT_NUM_PAIRS

   if (args.size() > 0)
      numPairs = args.shift().to_i()
   end

   return dataDir, embeddingDir, numPairs
end

def main(args)
   dataDir, embeddingDir, numPairs = parseArgs(args)
   outPath = File.join(embeddingDir, "#{BASE_OUTPUT_NAME}_#{numPairs}.txt")

   if (File.exists?(outPath))
      puts "Found top pairs already computed: #{outPath}. Skipping."
      return
   end

   puts "Computing top pairs in: #{outPath}."

   topPairs = computeTopPairs(dataDir, embeddingDir, numPairs)
   File.open(outPath, 'w'){|file|
      topPairs.each_slice(PAIRS_PAGE_SIZE).each{|pairs|
         file.puts(pairs.map{|pair| pair.join("\t")}.join("\n"))
      }
   }
end

if ($0 == __FILE__)
   main(ARGV)
end
