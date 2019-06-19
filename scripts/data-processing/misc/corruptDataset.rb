require_relative '../../lib/constants'
require_relative '../../lib/load'

require 'fileutils'

# Make a copy of a stndard dataset and corrupt a specified percent of the TRAINING tuples.

DEFAULT_CORRUPT_PERCENT = 0.05
DEFAULT_SEED = Random.new_seed()

# Get a lookup for ALL the triples (not just the training).
# Return: {'head:tail:relation' => true, ...}
def getTripleLookup(dataDir)
   triples = []
   Constants::RAW_TRIPLE_FILENAMES.each{|filename|
      triples += Load.triples(File.join(dataDir, filename), false)
   }

   return triples.map{|triple| [triple.join(':'), true]}.to_h()
end

def corrupt(corruptPercent, seed, dataDir)
   random = Random.new(seed)

   triples = Load.triples(File.join(dataDir, Constants::RAW_TRAIN_FILENAME), false)

   entities = Load.idMapping(File.join(dataDir, Constants::RAW_ENTITY_MAPPING_FILENAME), false).keys()
   relations = Load.idMapping(File.join(dataDir, Constants::RAW_RELATION_MAPPING_FILENAME), false).keys()

   # A quick lookup for existance.
   tripleLookup = getTripleLookup(dataDir)

   # Randomly select |corruptPercent| indecies.
   numCorrupt = triples.size() * corruptPercent
   corruptIndecies = (0...triples.size()).to_a().sample(numCorrupt, random: random)

   corruptIndecies.each{|corruptIndex|
      # Loop just in case we create a triple that already exists.
      while (true)
         newTriple = triples[corruptIndex].clone()

         corruptComponent = random.rand(3)
         if (corruptComponent == Constants::HEAD || corruptComponent == Constants::TAIL)
            corruptEntity = entities[random.rand(entities.size())]

            if (corruptComponent == Constants::HEAD)
               newTriple[Constants::HEAD] = corruptEntity
            else
               newTriple[Constants::TAIL] = corruptEntity
            end
         else
            # Corrupt relation
            corruptRelation = relations[random.rand(relations.size())]
            newTriple[Constants::RELATION] = corruptRelation
         end

         if (!tripleLookup.has_key?(newTriple.join(':')))
            triples[corruptIndex] = newTriple
            break
         end
      end
   }

   File.open(File.join(dataDir, Constants::RAW_TRAIN_FILENAME), 'w'){|file|
      file.puts(triples.map{|triple| triple.join("\t")}.join("\n"))
   }
end

def copyDatafiles(sourceDir, outputDir)
   toCopy = [
      Constants::RAW_ENTITY_MAPPING_FILENAME,
      Constants::RAW_RELATION_MAPPING_FILENAME,
      Constants::RAW_TEST_FILENAME,
      Constants::RAW_TRAIN_FILENAME,
      Constants::RAW_VALID_FILENAME
   ]

   toCopy.each{|filename|
      FileUtils.cp(File.join(sourceDir, filename), File.join(outputDir, filename))
   }
end

def corruptDataset(sourceDir, corruptPercent, seed)
   outputDir = File.join(Constants::RAW_DATA_PATH, "#{File.basename(sourceDir)}_CORRUPT[#{("%03d" % (corruptPercent * 100).to_i())}]")

   FileUtils.mkdir_p(outputDir)

   copyDatafiles(sourceDir, outputDir)
   corrupt(corruptPercent, seed, outputDir)
end

def main(args)
   if (args.size() < 1 || args.size() > 3 || args.map{|arg| arg.gsub('-', '').downcase()}.include?('help'))
      puts "USAGE: ruby #{$0} <source dataset dir> [corrupt percent] [seed]"
      puts "Defaults:"
      puts "   corrupt percent - #{DEFAULT_CORRUPT_PERCENT}"
      puts "   seed - ???"
      puts "Note that the output base dir is the dir that a NEW directory containing the dataset will be created."
      puts "The new directory will be named the same as the source one with a '_CORRUPT[<corrupt percent>]' suffix."
      exit(1)
   end

   sourceDir = args.shift()
   corruptPercent = DEFAULT_CORRUPT_PERCENT
   seed = DEFAULT_SEED

   if (args.size() > 0)
      corruptPercent = args.shift.to_f()

      if (corruptPercent < 0 || corruptPercent > 1)
         puts "Expecting corrupt percentage between 0 and 1."
         exit(2)
      end
   end

   if (args.size() > 0)
      seed = args.shift.to_i()
   end

   corruptDataset(sourceDir, corruptPercent, seed)
end

if (__FILE__ == $0)
   main(ARGV)
end
