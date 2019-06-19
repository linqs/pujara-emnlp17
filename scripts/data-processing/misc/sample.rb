# Group together all the triples and uniformly sample a new dataset.

require_relative '../../lib/constants'
require_relative '../../lib/load'

require 'fileutils'
require 'set'

SEED = 4
TRAINING_PERCENT = 0.90

def getAllTriples(dataDir)
   triples = []

   Constants::RAW_TRIPLE_FILENAMES.each{|filename|
      triples += Load.triples(File.join(dataDir, filename), false)
   }
   
   return triples
end

def sampleTriples(triples, size)
   return triples.sample(size, random: Random.new(SEED))
end

# Break up into train, test, and valid.
# Returns [train, test, valid]
def partitionTriples(triples)
   trainingSize = (triples.size() * TRAINING_PERCENT).to_i()

   # Both test and valid sets will get this count.
   # The rounding error on odd is a non-issue. The valid will just have one less.
   testSize = ((triples.size() - trainingSize) / 2 + 0.5).to_i()

   triples.shuffle!(random: Random.new(SEED))
   trainingSet = triples.slice(0, trainingSize)
   testSet = triples.slice(trainingSize, testSize)
   validSet = triples.slice(trainingSize + testSize, testSize)

   return trainingSet, testSet, validSet
end

def parseArgs(args)
   if (args.size != 2 || args.map{|arg| arg.gsub('-', '').downcase()}.include?('help'))
      puts "USAGE: ruby #{$0} <data dir> <num triples to sample>"
      puts "   Output will be written in a new directory adjacent to |data dir|, called |data dir|_SAMPLE[N]"
      puts "   Where 'N' is the number of triples sampled (zero padded to 6 digits)."
      exit(1)
   end

   dataDir = args.shift()
   size = args.shift().to_i()

   if (size < 1)
      puts "Number of triples to sample must be at least 1 (found #{size})."
      exit(2)
   end

   return dataDir, size
end

def main(args)
   dataDir, size = parseArgs(args)
   outDir = File.absolute_path(dataDir) + "_SAMPLE[#{"%06d" % size}]"
   FileUtils.mkdir_p(outDir)

   puts "Sampling and creating new dataset in: #{outDir}"

   triples = getAllTriples(dataDir)
   triples = sampleTriples(triples, size)

   Load.writeEntities(File.join(outDir, Constants::RAW_ENTITY_MAPPING_FILENAME), triples)
   Load.writeRelations(File.join(outDir, Constants::RAW_RELATION_MAPPING_FILENAME), triples)

   trainingSet, testSet, validSet = partitionTriples(triples)

   Load.writeTriples(File.join(outDir, Constants::RAW_TRAIN_FILENAME), trainingSet)
   Load.writeTriples(File.join(outDir, Constants::RAW_TEST_FILENAME), testSet)
   Load.writeTriples(File.join(outDir, Constants::RAW_VALID_FILENAME), validSet)
end

if ($0 == __FILE__)
   main(ARGV)
end
