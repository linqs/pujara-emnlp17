require_relative '../lib/load'

require 'set'

DEFAULT_CORRUPTIONS_FILE = 'targets.txt'

# set[[head, tail, relation], ...]
def loadValidTriples(dataDir)
   triples = Set.new()

   Constants::RAW_TRIPLE_FILENAMES.each{|filename|
      triples += Load.triples(File.join(dataDir, filename))
   }

   return triples
end

# {id: [head, tail, relation], ...}
def loadCorruptions(corruptionsPath)
   return Load.triplesWithId(corruptionsPath)
end

def loadTestTriples(dataDir)
   return Set.new(Load.triples(File.join(dataDir, Constants::RAW_TEST_FILENAME)))
end

def evalCorruption(triple, corruptHead, ranks, validTriples, corruptions)
   # [[id, value], ...]
   corruptionRanks = []

   # The id for this triple.
   tripleId = -1

   corruptions.each_pair{|corruptionId, corruption|
      # If we are corrupting the head and both the tail and relation match or visa-versa.
      if ((corruptHead && triple[1] == corruption[1] && triple[2] == corruption[2]) ||
          (!corruptHead && triple[0] == corruption[0] && triple[2] == corruption[2]))
         corruptionRanks << [corruptionId, ranks[corruptionId]]
      end

      if (corruption == triple)
         tripleId = corruptionId
      end
   }

   # Sort by rank (desceinding)
   corruptionRanks.sort!{|a, b| -1 * (a[1] <=> b[1])}

   # The first spot is rank 1.
   rawRank = 1
   filteredRank = 1

   rawHitsIn10 = 0
   filteredHitsIn10 = 0

   corruptionRanks.each_index{|i|
      corruptionId = corruptionRanks[i][0]

      if (corruptionId == tripleId)
         rawRank = i + 1
         break
      end

      if (!validTriples.include?(corruptions[corruptionId]))
         filteredRank += 1
      end
   }

   if (rawRank <= 10)
      rawHitsIn10 = 1
   end

   if (filteredRank <= 10)
      filteredHitsIn10 = 1
   end

   return {
      :rawRank => rawRank,
      :filteredRank => filteredRank,
      :rawHitsIn10 => rawHitsIn10,
      :filteredHitsIn10 => filteredHitsIn10
   }
end

def runEval(ranks, validTriples, corruptions, testTriples)
   rawRank = 0
   filteredRank = 0

   rawHitsIn10 = 0
   filteredHitsIn10 = 0

   testTriples.each{|testTriple|
      [true, false].each{|corruptionTarget|
         stats = evalCorruption(testTriple, corruptionTarget, ranks, validTriples, corruptions)

         rawRank += stats[:rawRank]
         filteredRank += stats[:filteredRank]
         rawHitsIn10 += stats[:rawHitsIn10]
         filteredHitsIn10 += stats[:filteredHitsIn10]
      }
   }

   numCorruptions = testTriples.size() * 2.0

   puts "Raw      -- Rank: #{rawRank / numCorruptions}, Hits@10: #{rawHitsIn10 / numCorruptions}"
   puts "Filtered -- Rank: #{filteredRank / numCorruptions}, Hits@10: #{filteredHitsIn10 / numCorruptions}"
end

def parseArgs(args)
   if (args.size < 2 || args.size > 4 || args.map{|arg| arg.gsub('-', '').downcase()}.include?('help'))
      puts "USAGE: ruby #{$0} <data dir> <energy/rank file> [targets/corruptions file [--energies]]"
      puts "The --energies flag can be be supplied to signal that the ranks file actual has energies that need to be converted."
      exit(1)
   end

   dataDir = args.shift()
   ranksFile = args.shift()
   corruptionsPath = File.join(dataDir, DEFAULT_CORRUPTIONS_FILE)
   normalizeEnergies = false

   if (args.size() > 0)
      corruptionsPath = args.shift()
   end

   if (args.size() > 0)
      if (args[0] != '--energies')
         puts "Unknown flag."
         exit(2)
      end

      normalizeEnergies = true
      args.shift()
   end

   return dataDir, ranksFile, corruptionsPath, normalizeEnergies
end

def main(args)
   dataDir, ranksFile, corruptionsPath, normalizeEnergies = parseArgs(args)

   ranks = Load.energies(ranksFile, normalizeEnergies)
   validTriples = loadValidTriples(dataDir)
   corruptions = loadCorruptions(corruptionsPath)

   testTriples = loadTestTriples(dataDir)

   runEval(ranks, validTriples, corruptions, testTriples)
end

if ($0 == __FILE__)
   main(ARGV)
end
