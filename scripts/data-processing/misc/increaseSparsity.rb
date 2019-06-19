# Increase sparsity in a dataset by removing triples.
# Uniformly select a relation and then uniformly select a triple using that relation and delete it.
# No relation/entity will be left without any triples (as long as they already appear in a triple).

require_relative '../../lib/constants'
require_relative '../../lib/load'

require 'fileutils'

SEED = 4

DELETED_TRIPLES_FILENAME = 'removedTriples.txt'

def removeTriples(dataDir, outDir, numRemove)
   inPath = File.join(dataDir, Constants::RAW_TRAIN_FILENAME)
   outPath = File.join(outDir, Constants::RAW_TRAIN_FILENAME)
   rand = Random.new(SEED)

   triples = Load.triples(inPath, false)
   removedTriples = []

   # Build a map keyed by relation for.
   # {relation => [triple, ...], ...}
   relationMap = Hash.new{|hash, key| hash[key] = []}
   triples.each{|triple|
      relationMap[triple[Constants::RELATION]] << triple
   }

   # Just a list of all the relation keys.
   relations = relationMap.keys()

   for i in 0...numRemove
      # Loop just in case we need to bail on a relation that only has one triple left.
      while (true)
         relation = relations[rand.rand(relations.size())]

         if (relationMap[relation].size() <= 1)
            next
         end

         removedTriples << relationMap[relation].delete_at(rand.rand(relationMap[relation].size()))
         break
      end
   end

   # Put all the triples back together.
   triples = []
   relationMap.values().each{|relationTriples|
      triples += relationTriples
   }

   File.open(outPath, 'w'){|file|
      file.puts(triples.map{|triple| triple.join("\t")}.join("\n"))
   }

   File.open(File.join(outDir, DELETED_TRIPLES_FILENAME), 'w'){|file|
      file.puts(removedTriples.map{|triple| triple.join("\t")}.join("\n"))
   }
end

def parseArgs(args)
   if (args.size != 2 || args.map{|arg| arg.gsub('-', '').downcase()}.include?('help'))
      puts "USAGE: ruby #{$0} <data dir> <num triples to remove>"
      puts "   Output will be written in a new directory adjacent to |data dir|, called |data dir|_TR[N]"
      puts "   Where 'N' is the number of relations to remove (zero padded to 6 digits)."
      puts "   'TR' stands for 'Triple Reduced'."
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
   outDir = File.absolute_path(dataDir) + "_TR[#{"%06d" % numRemove}]"
   FileUtils.mkdir_p(outDir)

   puts "Increasing sparsity and creating new dataset in: #{outDir}"

   # The map files, test, and valid all get moved over unchanged.
   toCopy = [
      Constants::RAW_ENTITY_MAPPING_FILENAME,
      Constants::RAW_RELATION_MAPPING_FILENAME,
      Constants::RAW_TEST_FILENAME,
      Constants::RAW_VALID_FILENAME
   ]

   toCopy.each{|filename|
      FileUtils.cp(File.join(dataDir, filename), File.join(outDir, filename))
   }

   removeTriples(dataDir, outDir, numRemove)
end

if ($0 == __FILE__)
   main(ARGV)
end
