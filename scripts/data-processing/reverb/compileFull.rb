require_relative '../../lib/constants'
require_relative '../../lib/load'
require_relative '../../lib/reverb/constants'
require_relative '../../lib/reverb/load'

require 'date'
require 'fileutils'
require 'set'

TRAINING_PERCENT = 0.90

# Break up into train, test, and valid.
# Returns [train, test, valid]
def partitionTriples(triples)
   trainingSize = (triples.size() * TRAINING_PERCENT).to_i()

   # Both test and valid sets will get this count.
   # The rounding error on odd is a non-issue. The valid will just have one less.
   testSize = ((triples.size() - trainingSize) / 2 + 0.5).to_i()

   triples.shuffle!()
   trainingSet = triples.slice(0, trainingSize)
   testSet = triples.slice(trainingSize, testSize)
   validSet = triples.slice(trainingSize + testSize, testSize)

   return trainingSet, testSet, validSet
end

def compileData()
   suffix = DateTime.now().strftime('%Y%m%d%H%M')

   outDir = File.join(Constants::RAW_DATA_PATH, "REVERB_FULL_#{suffix}")
   FileUtils.mkdir_p(outDir)

   puts "Creating new dataset in #{outDir}"

   triples = ReverbLoad.fullFileFormat(Reverb::FULL_DATA_PATH)

   Load.writeEntities(File.join(outDir, Constants::RAW_ENTITY_MAPPING_FILENAME), triples)
   Load.writeRelations(File.join(outDir, Constants::RAW_RELATION_MAPPING_FILENAME), triples)

   trainingSet, testSet, validSet = partitionTriples(triples)

   Load.writeTriples(File.join(outDir, Constants::RAW_TRAIN_FILENAME), trainingSet)
   Load.writeTriples(File.join(outDir, Constants::RAW_TEST_FILENAME), testSet)
   Load.writeTriples(File.join(outDir, Constants::RAW_VALID_FILENAME), validSet)
end

def parseArgs(args)
   if (args.size() > 0 || args.map{|arg| arg.downcase().strip().sub(/^-+/, '')}.include?('help'))
      puts "USAGE: ruby #{$0}"
      exit(1)
   end

   return
end

def main(args)
   compileData(*parseArgs(args))
end

if (__FILE__ == $0)
   main(ARGV)
end
