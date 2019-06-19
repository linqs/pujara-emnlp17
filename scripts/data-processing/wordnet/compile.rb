# Complie a wordnet knowledge graph from raw data files.

require_relative '../../lib/constants'

require 'fileutils'

DEFAULT_OUT_DIR = 'WN'

# How much of the data to use for a training set.
TRAINING_PERCENT = 0.90

DATA_FILENAMES = [
   'data.adj',
   'data.adv',
   'data.noun',
   'data.verb'
]

# The relations are from this documentation: https://wordnet.princeton.edu/man/wninput.5WN.html
# The documentation seems a little out-of-date.

# Note, there is one non-unique marker (different between pos) that is ruining the party for everyone
# and forcing us to use embedded hashs instead of just one top level one.
# {pos => {symbol => idString, ...}, ...}
RELATION_SYMBOLS = {
   'n' => {
      '!'  => '_antonym',
      '@'  => '_hypernym',
      '@i' => '_instance_hypernym',
      '~'  => '_hyponym',
      '~i' => '_instance_hyponym',
      '#m' => '_member_holonym',
      '#s' => '_substance_holonym',
      '#p' => '_part_holonym',
      '%m' => '_member_meronym',
      '%s' => '_substance_meronym',
      '%p' => '_part_meronym',
      '='  => '_attribute',
      '+'  => '_derivationally_related_form',
      ';c' => '_synset_domain_topic',
      '-c' => '_member_of_domain_topic',
      ';r' => '_synset_domain_region',
      '-r' => '_member_of_domain_region',
      ';u' => '_synset_domain_usage',
      '-u' => '_member_of_domain_usage'
   },
   'v' => {
      '!'  => '_antonym',
      '@'  => '_hypernym',
      '~'  => '_hyponym',
      '*'  => '_entailment',
      '>'  => '_cause',
      '^'  => '_also_see',
      '$'  => '_verb_group',
      '+'  => '_derivationally_related_form',
      ';c' => '_synset_domain_topic',
      ';r' => '_synset_domain_region',
      ';u' => '_synset_domain_usage'
   },
   'a' => {
      '!'  => '_antonym',
      '&'  => '_similar_to',
      '<'  => '_participle_of_verb',
      '\\' => '_pertainym',
      '='  => '_attribute',
      '^'  => '_also_see',
      ';c' => '_synset_domain_topic',
      ';r' => '_synset_domain_region',
      ';u' => '_synset_domain_usage',
      '+'  => '_derivationally_related_form' # Not in documentation.
   },
   'r' => {
      '!'  => '_antonym',
      '\\' => '_derived_from_adjective',
      ';c' => '_synset_domain_topic',
      ';r' => '_synset_domain_region',
      ';u' => '_synset_domain_usage',
      '+'  => '_derivationally_related_form' # Not in documentation.
   }
}
# Treat adjative satelites the same as adjectives.
RELATION_SYMBOLS['s'] = RELATION_SYMBOLS['a']

def parseFile(path)
   triples = []

   File.open(path, 'r'){|file|
      file.each{|line|
         if (line.start_with?('  '))
            next
         end

         # Remove the gloss.
         line = line.split('|', 2)[0].strip()

         parts = line.split(' ')

         synsetId = parts.shift()

         # Lex filenum
         parts.shift()

         synsetPos = parts.shift()

         # Size is in hex.
         synsetSize = parts.shift().to_i(16)

         # We don't actually care about words.
         for i in 0...synsetSize
            # word
            parts.shift()

            # lex id
            parts.shift()
         end

         # The number of relations is in decimal.
         numRelations = parts.shift().to_i()

         for i in 0...numRelations
            relationSymbol = parts.shift()
            targetSynsetId = parts.shift()
            targetPos = parts.shift()
            # Index into word in target synset.
            parts.shift()

            if (!RELATION_SYMBOLS.include?(synsetPos))
               $stderr.puts("ERROR -- [#{path}::#{file.lineno}]: Unknown synset POS: '#{synsetPos}'")
               exit(2)
            end

            if (!RELATION_SYMBOLS[synsetPos].include?(relationSymbol))
               $stderr.puts("ERROR -- [#{path}::#{file.lineno}]: Unknown relation symbol for POS (#{synsetPos}): '#{relationSymbol}'")
               exit(3)
            end

            triples << [synsetId, targetSynsetId, RELATION_SYMBOLS[synsetPos][relationSymbol]]
         end
      }
   }

   return triples
end

def parseData(dataDir)
   triples = []

   DATA_FILENAMES.each{|filename|
      triples += parseFile(File.join(dataDir, filename))
   }

   return triples
end

def writeData(triples, outDirName)
   datasetDir = File.join(Constants::RAW_DATA_PATH, outDirName)
   FileUtils.mkdir_p(datasetDir)

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

def loadArgs(args)
   if (args.size < 1 || args.size > 2 || args.map{|arg| arg.gsub('-', '').downcase()}.include?('help'))
      puts "USAGE: ruby #{$0} <wordnet database dir> [output dir name]"
      exit(1)
   end

   dataDir = args.shift()
   outDirName = DEFAULT_OUT_DIR

   if (args.size() > 0)
      outDirName = args.shift()
   end

   return dataDir, outDirName
end

def main(args)
   dataDir, outDirName = loadArgs(args)
   triples = parseData(dataDir)
   writeData(triples, outDirName)
end

if ($0 == __FILE__)
   main(ARGV)
end
