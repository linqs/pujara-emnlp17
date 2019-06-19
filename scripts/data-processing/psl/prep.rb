# Create the files that PSL will use.
# Processing:
#  - Copy over the id mapping files (not necessary, but convenient).
#  - Convert all ids in triple files from string identifiers to int identifiers.
#  - List out all the possible targets (test triples and their corruptions).
#  - Compute and output all the energy of all triples (targets).
#
# To save space (since there are typically > 400M targets), we will only write out energies
# that are less than some threshold.
# To signify an energy value that should not be included, the respective tripleEnergy() methods
# will return first return a value of false and then the actual energy value.
# We still return the actual energy so we can log it for later statistics.
#
# We make no strides to be overly efficient here, just keeping it simple.
# We will check to see if a file exists before creating it and skip that step.
# If you want a full re-run, just delete the offending directory.

require_relative '../../lib/constants'
require_relative '../../lib/embedding/energies'
require_relative '../../lib/embedding/load'
require_relative '../../lib/load'

require 'etc'
require 'fileutils'
require 'set'

# gem install thread
require 'thread/channel'
require 'thread/pool'

NUM_THREADS = Etc.nprocessors - 1
SKIP_BAD_ENERGY = false
MIN_WORK_PER_THREAD = 50
WORK_DONE_MSG = '__DONE__'

TARGETS_FILE = 'targets.txt'
ENERGY_FILE = 'energies.txt'
ENERGY_STATS_FILE = 'energyStats.txt'

def copyMappings(datasetDir, outDir)
   if (!File.exists?(File.join(outDir, Constants::RAW_ENTITY_MAPPING_FILENAME)))
      FileUtils.cp(File.join(datasetDir, Constants::RAW_ENTITY_MAPPING_FILENAME), File.join(outDir, Constants::RAW_ENTITY_MAPPING_FILENAME))
   end

   if (!File.exists?(File.join(outDir, Constants::RAW_RELATION_MAPPING_FILENAME)))
      FileUtils.cp(File.join(datasetDir, Constants::RAW_RELATION_MAPPING_FILENAME), File.join(outDir, Constants::RAW_RELATION_MAPPING_FILENAME))
   end
end

def loadIdTriples(path)
   triples = []

   File.open(path, 'r'){|file|
      file.each{|line|
         triples << line.split("\t").map{|part| part.strip().to_i()}
      }
   }

   return triples
end

def convertIdFile(inPath, outPath, entityMapping, relationMapping)
   if (File.exists?(outPath))
      return
   end

   triples = []

   File.open(inPath, 'r'){|file|
      file.each{|line|
         parts = line.split("\t").map{|part| part.strip()}

         parts[Constants::HEAD] = entityMapping[parts[Constants::HEAD]]
         parts[Constants::RELATION] = relationMapping[parts[Constants::RELATION]]
         parts[Constants::TAIL] = entityMapping[parts[Constants::TAIL]]

         triples << parts
      }
   }

   File.open(outPath, 'w'){|file|
      file.puts(triples.map{|triple| triple.join("\t")}.join("\n"))
   }
end

def convertIds(datasetDir, outDir, entityMapping, relationMapping)
   convertIdFile(File.join(datasetDir, Constants::RAW_TEST_FILENAME), File.join(outDir, Constants::RAW_TEST_FILENAME), entityMapping, relationMapping)
   convertIdFile(File.join(datasetDir, Constants::RAW_TRAIN_FILENAME), File.join(outDir, Constants::RAW_TRAIN_FILENAME), entityMapping, relationMapping)
   convertIdFile(File.join(datasetDir, Constants::RAW_VALID_FILENAME), File.join(outDir, Constants::RAW_VALID_FILENAME), entityMapping, relationMapping)
end

# Generate each target and compute the energy for each target.
# We do target generation and energy computation in the same step so we do not urite
# targets that have too high energy.
def computeTargetEnergies(datasetDir, embeddingDir, outDir, energyMethod, maxEnergy, entityMapping, relationMapping)
   if (File.exists?(File.join(outDir, ENERGY_FILE)))
      return
   end

   targetsOutFile = File.open(File.join(outDir, TARGETS_FILE), 'w')
   energyOutFile = File.open(File.join(outDir, ENERGY_FILE), 'w')

   entityEmbeddings, relationEmbeddings = LoadEmbedding.vectors(embeddingDir)
   targets = loadIdTriples(File.join(outDir, Constants::RAW_TEST_FILENAME))

   # The number of corruptions written to disk.
   # We need to keep track so we can assign surrogate keys.
   targetsWritten = 0

   # All the corruptions we have seen for a specific relation.
   # This is to avoid recomputation.
   # This will hold the cantor pairing of the head and tail.
   seenCorruptions = Set.new()

   # To reduce memory consumption, we will only look at one relation at a time.
   relations = targets.map{|target| target[Constants::RELATION]}.uniq()

   # The entities (and relations) have already been assigned surrogate keys that start at 0 and have
   # no holes.
   # So, instead of looking at actual entities, we can just start and zero and count up.
   numEntities = entityMapping.size()

   # [[id, energy], ...]
   energies = []
   corruptions = []

   # We will keep track of all the calculated energies so that we can analyze it later.
   # {energy.round(2) => count, ...}
   energyHistogram = Hash.new{|hash, key| hash[key] = 0}

   relations.each_index{|relationIndex|
      relation = relations[relationIndex]

      seenCorruptions.clear()
      seenCorruptions = Set.new()
      GC.start()

      # Only triples that are using the current relation.
      validTargets = targets.select(){|target| target[Constants::RELATION] == relation}

      validTargets.each{|target|
         # These are already cleared, but I want to make it explicit that we
         # are batching every valid target.
         energies.clear()
         corruptions.clear()

         # Corrupt the head and tail for each triple.
         [Constants::HEAD, Constants::TAIL].each{|corruptionTarget|
            for i in 0...numEntities
               if (corruptionTarget == Constants::HEAD)
                  head = i
                  tail = target[Constants::TAIL]
               else
                  head = target[Constants::HEAD]
                  tail = i
               end

               id = MathUtils.cantorPairing(head, tail)
               if (seenCorruptions.include?(id))
                  next
               end

               seenCorruptions << id

               corruption = Array.new(3, 0)
               corruption[Constants::HEAD] = head
               corruption[Constants::TAIL] = tail
               corruption[Constants::RELATION] = relation

               corruptions << corruption
            end
         }

         energies = Energies.computeEnergies(
            corruptions,
            nil, nil,
            entityEmbeddings, relationEmbeddings, energyMethod,
            false, true
         )
         corruptions.clear()

         # Log all the energies in the histogram.
         energies.values().each{|energy|
            energyHistogram[energy.round(2)] += 1
         }

         # Remove all energies over the threshold.
         energies.delete_if{|id, energy|
            energy > maxEnergy
         }

         # Right now the energies are in a map with string key, turn into a list with a surrogate key.
         # [[index, [head, tail, relation], energy], ...]
         # No need to convert the keys to ints now, since we will just write them out.
         energies = energies.to_a().each_with_index().map{|mapEntry, index|
            head, tail = mapEntry[0].split(':')
            [index + targetsWritten, [head, tail, relation], mapEntry[1]]
         }
         targetsWritten += energies.size()

         if (energies.size() > 0)
            targetsOutFile.puts(energies.map{|energy| "#{energy[0]}\t#{energy[1].join("\t")}"}.join("\n"))
            energyOutFile.puts(energies.map{|energy| "#{energy[0]}\t#{energy[2]}"}.join("\n"))
         end

         energies.clear()
      }
   }

   energyOutFile.close()
   targetsOutFile.close()

   writeEnergyStats(energyHistogram, outDir)
end

def writeEnergyStats(energyHistogram, outDir)
   tripleCount = energyHistogram.values().reduce(0, :+)
   mean = energyHistogram.each_pair().map{|energy, count| energy * count}.reduce(0, :+) / tripleCount.to_f()
   variance = energyHistogram.each_pair().map{|energy, count| count * ((energy - mean) ** 2)}.reduce(0, :+) / tripleCount.to_f()
   stdDev = Math.sqrt(variance)
   min = energyHistogram.keys().min()
   max = energyHistogram.keys().max()
   range = max - min

   # Keep track of the counts in each quartile.
   quartileCounts = [0, 0, 0, 0]
   energyHistogram.each_pair().each{|energy, count|
      # The small subtraction is to offset the max.
      quartile = (((energy - min - 0.0000001).to_f() / range) * 100).to_i() / 25
      quartileCounts[quartile] += count
   }

   # Calculate the median.
   # HACK(eriq): This is slighty off if there is an even number of triples and the
   # two median values are on a break, but it is not worth the extra effort.
   median = -1
   totalCount = 0
   energyHistogram.each_pair().sort().each{|energy, count|
      totalCount += count

      if (totalCount >= (tripleCount / 2))
         median = energy
         break
      end
   }

   File.open(File.join(outDir, ENERGY_STATS_FILE), 'w'){|file|
      file.puts "Num Triples: #{energyHistogram.size()}"
      file.puts "Num Unique Energies: #{tripleCount}"
      file.puts "Min Energy: #{energyHistogram.keys().min()}"
      file.puts "Max Energy: #{energyHistogram.keys().max()}"
      file.puts "Quartile Counts: #{quartileCounts}"
      file.puts "Quartile Percentages: #{quartileCounts.map{|count| (count / tripleCount.to_f()).round(2)}}"
      file.puts "Mean Energy: #{mean}"
      file.puts "Median Energy: #{median}"
      file.puts "Energy Variance: #{variance}"
      file.puts "Energy StdDev: #{stdDev}"
      file.puts "---"
      file.puts energyHistogram.each_pair().sort().map{|pair| pair.join("\t")}.join("\n")
   }
end

def parseArgs(args)
   embeddingDir = nil
   outDir = nil
   datasetDir = nil
   embeddingMethod = nil
   distanceType = nil

   if (args.size() < 1 || args.size() > 5 || args.map{|arg| arg.downcase().gsub('-', '')}.include?('help'))
      puts "USAGE: ruby #{$0} embedding dir [output dir [dataset dir [embedding method [distance type]]]]"
      puts "Defaults:"
      puts "   output dir = inferred"
      puts "   dataset dir = inferred"
      puts "   embedding method = inferred"
      puts "   distance type = inferred"
      puts ""
      puts "All the inferred aguments relies on the emebedding directory"
      puts "being formatted by the scripts/embeddings/computeEmbeddings.rb script."
      puts "The directory that the inferred output directory will be put in is: #{Constants::PSL_DATA_PATH}."
      exit(2)
   end

   if (args.size() > 0)
      embeddingDir = args[0]
   end

   if (args.size() > 1)
      outDir = args[1]
   else
      outDir = File.join(Constants::PSL_DATA_PATH, File.basename(embeddingDir))
   end

   if (args.size() > 2)
      datasetDir = args[2]
   else
      dataset = File.basename(embeddingDir).match(/^[^_]+_(\S+)_\[size:/)[1]
      datasetDir = File.join(Constants::RAW_DATA_PATH, File.join(dataset))
   end

   if (args.size() > 3)
      embeddingMethod = args[3]
   else
      embeddingMethod = File.basename(embeddingDir).match(/^([^_]+)_/)[1]
   end

   if (args.size() > 4)
      distanceType = args[4]
   else
      # TODO(eriq): This may be a little off for TransR.
      if (embeddingDir.include?("distance:#{Distance::L1_ID_INT}"))
         distanceType = Distance::L1_ID_STRING
      elsif (embeddingDir.include?("distance:#{Distance::L2_ID_INT}"))
         distanceType = Distance::L2_ID_STRING
      end
   end

   energyMethod = Energies.getEnergyMethod(embeddingMethod, distanceType, embeddingDir)
   maxEnergy = Energies.getMaxEnergy(embeddingMethod, distanceType, embeddingDir)

   return datasetDir, embeddingDir, outDir, energyMethod, maxEnergy
end

def prepForPSL(args)
   datasetDir, embeddingDir, outDir, energyMethod, maxEnergy = parseArgs(args)

   FileUtils.mkdir_p(outDir)

   entityMapping = Load.idMapping(File.join(datasetDir, Constants::RAW_ENTITY_MAPPING_FILENAME))
   relationMapping = Load.idMapping(File.join(datasetDir, Constants::RAW_RELATION_MAPPING_FILENAME))

   copyMappings(datasetDir, outDir)
   convertIds(datasetDir, outDir, entityMapping, relationMapping)
   computeTargetEnergies(datasetDir, embeddingDir, outDir, energyMethod, maxEnergy, entityMapping, relationMapping)
end

if (__FILE__ == $0)
   prepForPSL(ARGV)
end
