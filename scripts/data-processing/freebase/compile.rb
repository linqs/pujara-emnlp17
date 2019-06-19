require_relative '../../lib/constants'
require_relative '../../lib/load'

require 'fileutils'
require 'zlib'

KEY_PREFIXES = [
   'http://rdf.freebase.com/key/',
   'http://rdf.freebase.com/ns/',
   'http://www.w3.org/2000/01/rdf-schema#',
   'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
   'http://www.w3.org/2002/07/owl#',
   'http://www.w3.org/2002/07/owl#'
]

DEFAULT_OUT_DIR = 'FB'

# How much of the data to use for a training set.
TRAINING_PERCENT = 0.90

TRIPLES_OUT_FILE = 'triples.txt'
PAGE_SIZE = 10000

def parseKey(text)
   text = text.gsub(/(^<)|(>$)/, '')

   KEY_PREFIXES.each{|keyPrefix|
      text = text.sub(keyPrefix, '')
   }

   return text
end

def writeData(triples, datasetDir)
   puts "Writing #{triples.size()} triples to #{datasetDir}"

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
      file.puts(triples.map{|triple| "#{triple[Constants::HEAD]}\t#{triple[Constants::TAIL]}\t#{triple[Constants::RELATION]}"}.join("\n"))
    }
end

def getTriples(path, datasetDir)
   outPath = File.join(datasetDir, TRIPLES_OUT_FILE)

   if (File.exists?(outPath))
      return Load.triples(outPath, false)
   end

   triples = []
   outFile = File.open(TRIPLES_OUT_FILE, 'w')

   if (path.end_with?('.gz'))
      inFile = Zlib::GzipReader.open(path)
   else
      inFile = File.open(path, 'r')
   end

   page = 0
   inFile.each{|line|
      # Strip off the anglebrackets and key prefix.
      parts = line.sub(/\.\s*$/, '').strip().split(' ', 3).map{|part| parseKey(part)}

      # Input format is (head, relation, tail), output is (head, tail, relation)
      triples << [parts[0], parts[2], parts[1]]

      if (triples.size() == PAGE_SIZE)
         outFile.puts(triples.map{|triple| triple.join("\t")}.join("\n"))
         triples.clear()

         puts "Wrote page #{page} (#{(page + 1) * PAGE_SIZE} triples)."
         page += 1
      end
   }

   if (triples.size() == PAGE_SIZE)
      outFile.puts(triples.map{|triple| triple.join("\t")}.join("\n"))
   end

   outFile.close()
   inFile.close()

   return triples
end

def loadArgs(args)
   if (args.size < 1 || args.size > 2 || args.map{|arg| arg.gsub('-', '').downcase()}.include?('help'))
      puts "USAGE: ruby #{$0} <freebase dump> [output dir name]"
      exit(1)
   end

   dumpPath = args.shift()
   outDirName = DEFAULT_OUT_DIR

   if (args.size() > 0)
      outDirName = args.shift()
   end

   return dumpPath, outDirName
end

def main(args)
   dumpPath, outDirName = loadArgs(args)

   datasetDir = File.join(Constants::RAW_DATA_PATH, outDirName)
   FileUtils.mkdir_p(datasetDir)

   triples = getTriples(dumpPath, datasetDir)
   writeData(triples, datasetDir)
end

if ($0 == __FILE__)
   main(ARGV)
end
