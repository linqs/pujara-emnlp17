# Create datasets for measuring the tradeoff between sparsity and noise.
# We will start with a dataset that has the most sparsity.
# We will then start adding triples what were removed, but we will corrupt a certian percent of these triples.

require_relative '../../lib/constants'
require_relative '../../lib/load'

require 'fileutils'

SEED = 4

# Min is always 0.
MAX_REMOVAL_TRIPLES = 300000
REMOVAL_TRIPLES_STEP = 50000

# Min corruption is alwasy 0.0.
MAX_CORRUPTION = 0.90
CORRUPTION_STEP = 0.10

# We will keep track of the triples that have been removed from the dataset.
REMOVED_TRIPLES_FILENAME = 'removedTriples.txt'

# We will keep track of the triples that were corrupted when added back (along with the corruption used).
CORRUPTED_TRIPLES_FILENAME = 'corruptedTriples.txt'

# Return: [data triples], [removed triples]
def removeTriples(dataDir, numRemove, rand)
   inPath = File.join(dataDir, Constants::RAW_TRAIN_FILENAME)

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

   return triples, removedTriples
end

def writeDataset(baseDataDir, triples, removedTriples, corruptedTriples,
      numBaseRemoved, numCurrentlyRemoved, corruptPercent)
   params = "#{'%06d' % numBaseRemoved},#{'%06d' % numCurrentlyRemoved},#{("%03d" % (corruptPercent * 100).to_i())}"
   dataDir = File.absolute_path(baseDataDir) + "_TRADEOFF[#{params}]"

   puts "Creating data dir: #{dataDir}"
   FileUtils.mkdir_p(dataDir)

   File.open(File.join(dataDir, Constants::RAW_TRAIN_FILENAME), 'w'){|file|
      file.puts(triples.map{|triple| triple.join("\t")}.join("\n"))
   }

   File.open(File.join(dataDir, REMOVED_TRIPLES_FILENAME), 'w'){|file|
      file.puts(removedTriples.map{|triple| triple.join("\t")}.join("\n"))
   }

   File.open(File.join(dataDir, CORRUPTED_TRIPLES_FILENAME), 'w'){|file|
      file.puts(corruptedTriples.map{|triple| triple.join("\t")}.join("\n"))
   }

   # The map files, test, and valid all get moved over unchanged.
   toCopy = [
      Constants::RAW_ENTITY_MAPPING_FILENAME,
      Constants::RAW_RELATION_MAPPING_FILENAME,
      Constants::RAW_TEST_FILENAME,
      Constants::RAW_VALID_FILENAME
   ]

   toCopy.each{|filename|
      FileUtils.cp(File.join(baseDataDir, filename), File.join(dataDir, filename))
   }
end

# Get a lookup for ALL the triples (not just the training).
# Return: {'head:tail:relation' => true, ...}
def getTripleLookup(dataDir)
   triples = []
   Constants::RAW_TRIPLE_FILENAMES.each{|filename|
      triples += Load.triples(File.join(dataDir, filename), false)
   }

   return triples.map{|triple| [triple.join(':'), true]}.to_h()
end

# Corrupt triples from |triples| in place.
# Store all corruptions in |corruptions| and check there to make sure
# that we don't double corrupt.
def corrupt(triples, corruptions, numCorrupt, rand, entities, relations, tripleLookup)
   if (numCorrupt == 0)
      return
   end

   if (numCorrupt > triples.size())
      raise("Trying to corrupt more triples than we have (#{numCorrupt} / #{triples.size()}).")
   end

   # Randomly select |numCorrupt| indecies.
   corruptIndecies = (0...triples.size()).to_a().sample(numCorrupt, random: rand)

   # Change any indeces that have already been corrupted.
   # Note that this is not at all efficient, but there should not be too many that don't match.
   corruptIndecies.each_index{|i|
      while (corruptions.has_key?(triples[corruptIndecies[i]].join(':')))
         newIndex = rand.rand(triples.size())
         while (corruptIndecies.include?(newIndex))
            newIndex = rand.rand(triples.size())
         end

         corruptIndecies[i] = newIndex
      end
   }

   corruptIndecies.each{|corruptIndex|
      # Loop just in case we create a triple that already exists.
      while (true)
         newTriple = triples[corruptIndex].clone()

         corruptComponent = rand.rand(3)
         if (corruptComponent == Constants::HEAD || corruptComponent == Constants::TAIL)
            corruptEntity = entities[rand.rand(entities.size())]

            if (corruptComponent == Constants::HEAD)
               newTriple[Constants::HEAD] = corruptEntity
            else
               newTriple[Constants::TAIL] = corruptEntity
            end
         else
            # Corrupt relation
            corruptRelation = relations[rand.rand(relations.size())]
            newTriple[Constants::RELATION] = corruptRelation
         end

         if (!tripleLookup.has_key?(newTriple.join(':')))
            corruptions[triples[corruptIndex].join(':')] = [
               triples[corruptIndex].clone(),
               newTriple.clone()
            ]

            triples[corruptIndex] = newTriple
            break
         end
      end
   }
end

# Returns: {
#    :numRemovedTriples => int,
#    :corruptPercent => float,
#    :addTriples => [],
#    :removedTriples => [],
#    :corruptions => {tripleId (see getTripleLookup()) => [original, corruption]}
# }
# |baseDatasets| should be a data structure like the one above for all the datasets this is based off of.
# |numRemovedTriples| and |corruptPercent| should always be at least as small/large as the base datasets respectivley.
# The add triples and corruptions will be unioned, while the removed triples will be intersected.
# Finally, we will make up the difference in triples to add and corrupted triples.
def buildDataset(baseDatasets, numRemovedTriples, corruptPercent, rand, entities, relations, tripleLookup)
   if (baseDatasets.size() == 0)
      raise("Need some base data!")
   end

   addTriples = []
   removedTriples = baseDatasets[0][:removedTriples]
   corruptions = {}

   baseDatasets.each{|baseDataset|
      if (baseDataset[:numRemovedTriples] < numRemovedTriples)
         raise("Derived dataset cannot have a number of removed triples more than a base dataset.")
      end

      if (baseDataset[:corruptPercent] > corruptPercent)
         raise("Derived dataset cannot have less corruption than a base dataset.")
      end

      addTriples |= baseDataset[:addTriples]
      removedTriples &= baseDataset[:removedTriples]
      corruptions.merge!(baseDataset[:corruptions])
   }

   requiredAddTriples = MAX_REMOVAL_TRIPLES - numRemovedTriples
   if (requiredAddTriples < addTriples.size())
      raise("Too many added triples, this should not happen... (#{addTriples.size()}, #{requiredAddTriples})")
   end

   # Add in any additional triples we need.
   if (addTriples.size() < requiredAddTriples)
      toAdd = removedTriples.sample(requiredAddTriples - addTriples.size(), random: rand)
      addTriples += toAdd
      removedTriples -= toAdd
   end

   requiredCorruptions = ((MAX_REMOVAL_TRIPLES - numRemovedTriples) * corruptPercent).to_i()
   if (requiredCorruptions < corruptions.size())
      raise("Uh-oh... too many corruptions from the union. Change seed?")
   end

   # Corrupt any additional triples.
   corrupt(addTriples, corruptions, requiredCorruptions - corruptions.size(), rand, entities, relations, tripleLookup)

   return {
      :numRemovedTriples => numRemovedTriples,
      :corruptPercent => corruptPercent,
      :addTriples => addTriples,
      :removedTriples => removedTriples,
      :corruptions => corruptions
   }
end

def run(dataDir, rand)
   # All datasets in this experiment will share one base one (where no triples have been re-added).
   triples, removedTriples = removeTriples(dataDir, MAX_REMOVAL_TRIPLES, rand)
   writeDataset(dataDir, triples, removedTriples, [], MAX_REMOVAL_TRIPLES, MAX_REMOVAL_TRIPLES, 0.0)

   entities = Load.idMapping(File.join(dataDir, Constants::RAW_ENTITY_MAPPING_FILENAME), false).keys()
   relations = Load.idMapping(File.join(dataDir, Constants::RAW_RELATION_MAPPING_FILENAME), false).keys()

   # A quick lookup for existance.
   tripleLookup = getTripleLookup(dataDir)

   # We have to be very careful about the triples that we decide to corrupt at each level.
   # Each level has to build on both the triples used at the previous sparsity and noise levels.
   # So, we are going to need to do a dynamic programming scheme.

   numRemovalLevels = MAX_REMOVAL_TRIPLES / REMOVAL_TRIPLES_STEP
   numCorruptionLevels = (MAX_CORRUPTION / CORRUPTION_STEP).to_i()

   # [sparsityLevel][corruptionLevel] = {
   #    :numRemovedTriples => int,
   #    :corruptPercent => float,
   #    :addTriples => [],
   #    :removedTriples => [],
   #    :corruptions => {indexInRemovedTriples => [original, corruption]}
   # }
   datasets = []
   for i in 0...numRemovalLevels
      datasets << [nil] * numCorruptionLevels
   end

   # First fill in the top left (min sparsity and min corruption)
   baseDataset = {
      :numRemovedTriples => MAX_REMOVAL_TRIPLES,
      :corruptPercent => 0.0,
      :addTriples => [],
      :removedTriples => removedTriples,
      :corruptions => {}
   }
   datasets[0][0] = buildDataset(
      [baseDataset],
      MAX_REMOVAL_TRIPLES - REMOVAL_TRIPLES_STEP, CORRUPTION_STEP,
      rand, entities, relations, tripleLookup
   )


   # Fill in the left column (increasing sparsity, constantcorruption).
   for i in 1...numRemovalLevels
      datasets[i][0] = buildDataset(
         [datasets[i - 1][0]],
         MAX_REMOVAL_TRIPLES - (REMOVAL_TRIPLES_STEP * (i + 1)), CORRUPTION_STEP,
         rand, entities, relations, tripleLookup
      )
   end

   # Fill in the top row (constant sparsity, increasing corruption).
   for j in 1...numCorruptionLevels
      datasets[0][j] = buildDataset(
         [datasets[0][j - 1]],
         MAX_REMOVAL_TRIPLES - REMOVAL_TRIPLES_STEP, CORRUPTION_STEP * (j + 1),
         rand, entities, relations, tripleLookup
      )
   end

   # Now compute the middle cells.
   # Note(eriq): We originally were going to let a cell depend on both the one above and to
   # the left of it. This will work for number of corruptions, but will generate too
   # many triples at each level.
   # Instead, we will let columns be largely independent (except for the common ancestor).

   for i in 1...numRemovalLevels
      for j in 1...numCorruptionLevels
         removedCount = MAX_REMOVAL_TRIPLES - (REMOVAL_TRIPLES_STEP * (i + 1))
         corruption = CORRUPTION_STEP * (j + 1)

         datasets[i][j] = buildDataset(
            [datasets[i - 1][j]],
            removedCount, corruption,
            rand, entities, relations, tripleLookup
         )
      end
   end

   datasets.flatten().each{|dataset|
      writeDataset(
         dataDir,
         triples + dataset[:addTriples], dataset[:removedTriples], dataset[:corruptions].values(),
         MAX_REMOVAL_TRIPLES, dataset[:numRemovedTriples], dataset[:corruptPercent]
      )
   }
end

def parseArgs(args)
   if (args.size != 1 || args.map{|arg| arg.gsub('-', '').downcase()}.include?('help'))
      puts "USAGE: ruby #{$0} <data dir>"
      puts "   Output will be written in several new directories adjacent to |data dir|,"
      puts "   called |data dir|_TRADEOFF[N,M,C]"
      puts "   Where 'N' is the base number of relations removed (zero padded to 6 digits);"
      puts "   'M' is the number of triples removed currently;"
      puts "   and 'C' is the corruption percent for the added triples."
      exit(1)
   end

   dataDir = args.shift()

   return dataDir
end

def main(args)
   dataDir = parseArgs(args)
   rand = Random.new(SEED)

   run(dataDir, rand)
end

if ($0 == __FILE__)
   main(ARGV)
end
