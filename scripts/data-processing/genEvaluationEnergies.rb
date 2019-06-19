require_relative '../lib/constants'
require_relative '../lib/distance'
require_relative '../lib/histogram'
require_relative '../lib/load'
require_relative '../lib/embedding/energies'
require_relative '../lib/embedding/load'

require 'date'
require 'fileutils'
require 'set'

# Write out all the energies we need to evaluate the embeddings.

EVAL_TARGETS_FILENAME = 'eval_targets.txt'
EVAL_ENERGIES_FILENAME = 'eval_energies.txt'

def entityHistogram(entities, bucketSize = 10)
   counts = Hash.new{|hash, key| hash[key] = 0}
   entities.each{|entity|
      counts[entity] += 1
   }

   puts Histogram.generate(counts.values())
end

def getAllEntities(datasetDir)
   entities = []

   Constants::RAW_TRIPLE_FILENAMES.each{|filename|
      File.open(File.join(datasetDir, filename), 'r'){|file|
         file.each{|line|
            parts = line.split("\t").map{|part| part.strip()}
            entities << parts[Constants::HEAD]
            entities << parts[Constants::TAIL]
         }
      }
   }

   entityHistogram(entities)

   entities.uniq!()
   entities.sort!()

   return entities
end

# Write out evaluation data for the embeddings.
# We will pick up the triples in Constants::RAW_TEST_FILENAME, corrupt them, compute their energies, and write them out.
def writeEvalData(datasetDir, embeddingDir, embeddingMethod, distanceType)
   evaltargetsPath = File.join(embeddingDir, EVAL_TARGETS_FILENAME)
   evalEnergiesPath = File.join(embeddingDir, EVAL_ENERGIES_FILENAME)

   baseTriples = []
   File.open(File.join(datasetDir, Constants::RAW_TEST_FILENAME), 'r'){|file|
      file.each{|line|
         baseTriples << line.split("\t").map{|part| part.strip()}
      }
   }

   entities = getAllEntities(datasetDir)

   # Keep track of what we see in the baseTriples (test set) and not just the entire corpus.
   relations = baseTriples.map{|triple| triple[2]}.uniq().sort()

	entityMapping = Load.idMapping(File.join(datasetDir, Constants::RAW_ENTITY_MAPPING_FILENAME), false)
	relationMapping = Load.idMapping(File.join(datasetDir, Constants::RAW_RELATION_MAPPING_FILENAME), false)

   entityEmbeddings, relationEmbeddings = LoadEmbedding.vectors(embeddingDir)
   energyMethod = Energies.getEnergyMethod(embeddingMethod, distanceType, embeddingDir)

   # Get all the corruptions.
   # We are going to be very careful and only keep the corruptions that matter in evaluation.
   # This mean that any corrupted triple with energy greater than the target (baseTriple)
   # should not be written down.
   # However, there can be overlap in the corruptions that each target generates
   # ie. [Foo, Bar, Baz] and [Foo, Choo, Baz] will generate some of the same corruptions.
   # So, we will calculate the energy for the targets up-front and keep track of the highest energy for
   # each (head, relation) and (tail, relation) pair.

   baseEnergies = Energies.computeEnergies(
         baseTriples, entityMapping, relationMapping,
         entityEmbeddings, relationEmbeddings, energyMethod, false)

   # {Constants::HEAD => {head => {relation => cuttoffEnergy}, ...}, (same for Constants::TAIL)}.
   # Note that because of the later queries on this structure, we cannot use the auto-creation syntax.
   cuttoffEnergies = {
      Constants::HEAD => {},
      Constants::TAIL => {}
   }

   baseEnergies.each_pair{|idString, energy|
      triple = idString.split(':')

      # Insert missing keys.
      if (!cuttoffEnergies[Constants::HEAD].has_key?(triple[0]))
         cuttoffEnergies[Constants::HEAD][triple[0]] = {}
      end

      if (!cuttoffEnergies[Constants::TAIL].has_key?(triple[1]))
         cuttoffEnergies[Constants::TAIL][triple[1]] = {}
      end

      # Check to see if we have a higher skyline.
      if (!cuttoffEnergies[Constants::HEAD][triple[0]].has_key?(triple[2]) || energy > cuttoffEnergies[Constants::HEAD][triple[0]][triple[2]])
         cuttoffEnergies[Constants::HEAD][triple[0]][triple[2]] = energy
      end

      if (!cuttoffEnergies[Constants::TAIL][triple[1]].has_key?(triple[2]) || energy > cuttoffEnergies[Constants::TAIL][triple[1]][triple[2]])
         cuttoffEnergies[Constants::TAIL][triple[1]][triple[2]] = energy
      end
   }

   targetsOutFile = File.open(evaltargetsPath, 'w')
   energyOutFile = File.open(evalEnergiesPath, 'w')

   # The count of all energies we have actually written out.
   # We need this to keep a consistent surrogate key.
   energiesWritten = 0

   # All the triples we have considered.
   totalTriples = 0

   # All the energies we have computed.
   totalEnergies = 0

   # For curosity, keep track of how many triples we dropped for having too high energy.
   droppedEnergies = 0

   # We will work with one relation at a time.
   # This way we can keep a set of the triples we have already computed.
   # We do not want to recompute any triples, and at the same time we
   # want to keep our set of seen triples small so that we don't run
   # out of memory.

   # To prevent recomputation, we will leep track of the "constant entities"
   # (the entitiy that is held constant while the other one is iterated)
   # that we have seen for each relation.
   # If we are holding the Constants::TAIL constant and we see an entity that we have
   # held constant in the Constants::HEAD, then skip it.
   # Note that if the set of corruptions was complete, then we could just do some math.
   seenConstantEntitys = Set.new()
   triples = []

   relations.each{|relation|
      puts "Relation: #{relation}"

      seenConstantEntitys.clear()

      # cuttoffEnergies has a built-in list of (head, relation) and (tail, relation)
      # pairings. We just need to add the last component to generate corruptions.
      # constantEntityType will be Constants::HEAD or Constants::TAIL
      # We will need to make sure to do Constants::HEAD first.
      cuttoffEnergies.keys().sort().each{|constantEntityType|
         cuttoffEnergies[constantEntityType].each_key{|constantEntity|
            batchStartTime = (Time.now().to_f() * 1000.0).to_i()

            if (!cuttoffEnergies[constantEntityType][constantEntity].has_key?(relation))
               next
            end

            if (constantEntityType == Constants::HEAD)
               seenConstantEntitys << constantEntity
            end

            # Gather all the triples in this batch.
            entities.each{|entity|
               # Avoid duplicates.
               if (constantEntityType == Constants::TAIL && seenConstantEntitys.include?(entity))
                  next
               end

               if (constantEntityType == Constants::HEAD)
                  head = constantEntity
                  tail = entity
               else
                  head = entity
                  tail = constantEntity
               end

               triples << [head, tail, relation]
            }

            totalTriples += triples.size()

            # Process the batch
            energies = Energies.computeEnergies(
                  triples, entityMapping, relationMapping,
                  entityEmbeddings, relationEmbeddings, energyMethod,
                  false, true)

            initialSize = energies.size()
            totalEnergies += energies.size()

            energies.delete_if{|idString, energy|
               head, tail = idString.split(':').map{|part| part}

               # Check to see if we beat the cuttoff.
               goodHead = (cuttoffEnergies[Constants::HEAD].has_key?(head) && cuttoffEnergies[Constants::HEAD][head].has_key?(relation)) && (energy <= cuttoffEnergies[Constants::HEAD][head][relation])
               goodTail = (cuttoffEnergies[Constants::TAIL].has_key?(tail) && cuttoffEnergies[Constants::TAIL][tail].has_key?(relation)) && (energy <= cuttoffEnergies[Constants::TAIL][tail][relation])

               !goodHead && !goodTail
            }

            droppedEnergies += (initialSize - energies.size())

            # Right now the energies are in a map with string key, turn into a list with a surrogate key.
            # [[index, [head, tail, relation], energy], ...]
            # No need to convert the keys to ints now, since we will just write them out.
            energies = energies.to_a().each_with_index().map{|mapEntry, index|
               head, tail = mapEntry[0].split(':')
               [index + energiesWritten, [head, tail, relation], mapEntry[1]]
            }
            energiesWritten += energies.size()

            if (energies.size() > 0)
               targetsOutFile.puts(energies.map{|energy| "#{energy[0]}\t#{energy[1].join("\t")}"}.join("\n"))
               energyOutFile.puts(energies.map{|energy| "#{energy[0]}\t#{energy[2]}"}.join("\n"))
            end

            batchEndTime = (Time.now().to_f() * 1000.0).to_i()
            puts "Batch Size: #{triples.size()} (#{energies.size()}) -- [#{batchEndTime - batchStartTime} ms]"

            energies.clear()
            triples.clear()
         }
      }
   }

   puts "Triples Considered: #{totalTriples}"
   puts "Energies Considered: #{totalEnergies}"
   puts "Energies Written: #{energiesWritten}"
   puts "Energies Dropped: #{droppedEnergies}"

   targetsOutFile.close()
   energyOutFile.close()
end

def main(args)
   datasetDir, embeddingDir, embeddingMethod, distanceType = parseArgs(args)
   writeEvalData(datasetDir, embeddingDir, embeddingMethod, distanceType)
end

def parseArgs(args)
   embeddingDir = nil
   datasetDir = nil
   embeddingMethod = nil
   distanceType = nil

   if (args.size() < 1 || args.size() > 4 || args.map{|arg| arg.downcase().gsub('-', '')}.include?('help'))
      puts "USAGE: ruby #{$0} <embedding dir> [dataset dir [embedding method [distance type]]]"
      puts "Defaults:"
      puts "   dataset dir = inferred"
      puts "   embedding method = inferred"
      puts "   distance type = inferred"
      puts ""
      puts "All the inferred aguments relies on the source and emebedding directory"
      puts "being formatted by the evalAll.rb script."
      exit(2)
   end

   embeddingDir = args.shift()

   if (args.size() > 0)
      datasetDir = args.shift()
   else
      dataset = File.basename(embeddingDir).match(/^[^_]+_(\S+)_\[size:/)[1]
      datasetDir = File.join(Constants::RAW_DATA_PATH, File.join(dataset))
   end

   if (args.size() > 0)
      embeddingMethod = args.shift()
   else
      embeddingMethod = File.basename(embeddingDir).match(/^([^_]+)_/)[1]
   end

   if (args.size() > 0)
      distanceType = args.shift()
   else
      # TODO(eriq): This may be a little off for TransR.
      if (embeddingDir.include?("distance:#{Distance::L1_ID_INT}"))
         distanceType = Distance::L1_ID_STRING
      elsif (embeddingDir.include?("distance:#{Distance::L2_ID_INT}"))
         distanceType = Distance::L2_ID_STRING
      end
   end

   return datasetDir, embeddingDir, embeddingMethod, distanceType
end

if (__FILE__ == $0)
   main(ARGV)
end
