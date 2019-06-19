require_relative '../../lib/constants'
require_relative '../../lib/load'
require_relative '../../lib/reverb/constants'
require_relative '../../lib/reverb/load'

require 'date'
require 'fileutils'
require 'set'

TRAINING_PERCENT = 0.90
FLAG_ANNOTATIONS = '--annotations'

# Will get annotations, reject bad ones, and write the full set to the out dir.
def fetchAnnotations(dataDir, outDir, trainingTriples)
   relations = Set.new(trainingTriples.map{|triple| triple[Constants::RELATION]})

   entities = []
   trainingTriples.each{|triple|
      entities << triple[Constants::HEAD]
      entities << triple[Constants::TAIL]
   }
   entities = Set.new(entities)

   annotations = ReverbLoad.annotations(File.join(dataDir, Reverb::ANNOTATIONS_FILE_RELPATH))
   testSet = []

   # TEST
=begin
   annotations = []
   File.open('test2.txt', 'r'){|file|
      file.each{|line|
         parts = line.split("\t").map{|part| part.strip().downcase().gsub(' ', '_')}
         valid = parts.shift() == '1'
         parts.shift()

         parts[1], parts[2] = parts[2], parts[1]

         annotations << [
            parts,
            valid,
            1.0
         ]
      }
   }
=end

   # Go backwards.
   rejectedCount = 0
   (0...(annotations.size())).to_a().reverse().each{|i|
      annotation = annotations[i]

      if (!entities.include?(annotation[0][Constants::HEAD]))
         puts "Rejecting annotation because head (#{annotation[0][Constants::HEAD]}) is not a known entity."
         annotations.delete_at(i)
         rejectedCount += 1
         next
      end

      if (!entities.include?(annotation[0][Constants::TAIL]))
         puts "Rejecting annotation because tail (#{annotation[0][Constants::TAIL]}) is not a known entity."
         annotations.delete_at(i)
         rejectedCount += 1
         next
      end

      if (!entities.include?(annotation[0][Constants::RELATION]))
         puts "Rejecting annotation because relation (#{annotation[0][Constants::RELATION]}) is not a known relaiton."
         annotations.delete_at(i)
         rejectedCount += 1
         next
      end
   }

   puts "Rejected #{rejectedCount} / #{annotations.size() + rejectedCount} annotations for unknown components."

   # Write out the full annotations for reference.
   File.open(File.join(outDir, Reverb::ANNOTATIONS_RAW_FILENAME), 'w'){|file|
      file.puts(annotations.map{|annotation| annotation.flatten().join("\t")}.join("\n"))
   }

   # Remove negative examples.
   annotations.delete_if{|annotation| !annotation[1]}

   return annotations.map{|annotation| annotation[0]}
end

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

def compileData(dataDir, suffix, useAnnotations)
   triples = ReverbLoad.triples(File.join(dataDir, Reverb::DATA_FILENAME))

   if (useAnnotations)
      suffix = "ANNOTATIONS_#{suffix}"
   end

   outDir = File.join(Constants::RAW_DATA_PATH, "REVERB_#{suffix}")
   FileUtils.mkdir_p(outDir)

   puts "Creating new dataset in #{outDir}"

   Load.writeEntities(File.join(outDir, Constants::RAW_ENTITY_MAPPING_FILENAME), triples)
   Load.writeRelations(File.join(outDir, Constants::RAW_RELATION_MAPPING_FILENAME), triples)

   if (useAnnotations)
      trainingSet = triples
      validSet = []
      testSet = fetchAnnotations(dataDir, outDir, triples)
   else
      trainingSet, testSet, validSet = partitionTriples(triples)
   end

   Load.writeTriples(File.join(outDir, Constants::RAW_TRAIN_FILENAME), trainingSet)
   Load.writeTriples(File.join(outDir, Constants::RAW_TEST_FILENAME), testSet)
   Load.writeTriples(File.join(outDir, Constants::RAW_VALID_FILENAME), validSet)
end

def parseArgs(args)
   if (args.size() < 1 || args.size() > 3 || args.map{|arg| arg.downcase().strip().sub(/^-+/, '')}.include?('help'))
      puts "USAGE: ruby #{$0} <data dir> [suffix] [#{FLAG_ANNOTATIONS}]"
      puts "   If #{FLAG_ANNOTATIONS} is supplied, then the test set will come directly from the annotations file."
      exit(1)
   end

   dataDir = args.shift()
   suffix = DateTime.now().strftime('%Y%m%d%H%M')
   useAnnotations = false

   if (args.include?(FLAG_ANNOTATIONS))
      useAnnotations = true
      args.delete(FLAG_ANNOTATIONS)
   end

   if (args.size() > 0)
      suffix = args.shift()
   end

   return dataDir, suffix, useAnnotations
end

def main(args)
   compileData(*parseArgs(args))
end

if (__FILE__ == $0)
   main(ARGV)
end
