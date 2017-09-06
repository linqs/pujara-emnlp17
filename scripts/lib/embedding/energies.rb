require_relative 'load'
require_relative 'transE'
require_relative 'transH'
require_relative 'stransE'
require_relative '../constants'
require_relative '../distance'
require_relative '../load'

require 'etc'
require 'set'

# gem install thread
require 'thread/pool'

module Energies
   NUM_THREADS = Etc.nprocessors - 1
   MIN_WORK_PER_THREAD = 100

   # If |useShortIdentifier| is true, then only the head and tail will be used as the energy key.
   # It is common to batch all triples of the same relation together, so it is not always necessary
   # in the caller.
   # |entityMapping| and |relationMapping| is used when the triples need to be converted to their surrogate keys
   # (the index into the embeddings).
   # If the triples are already translated, just pass nils for the mappings.
   def Energies.computeEnergies(
         triples,
         entityMapping, relationMapping,
         entityEmbeddings, relationEmbeddings, energyMethod,
         skipBadEnergies = false, useShortIdentifier = false)
      energies = {}

      pool = Thread.pool(NUM_THREADS)
      lock = Mutex.new()

      triples.each_slice([triples.size() / NUM_THREADS + 1, MIN_WORK_PER_THREAD].max()){|threadTriples|
         pool.process{
            threadTriples.each{|triple|
               if (useShortIdentifier)
                  id = triple[0...2].join(':')
               else
                  id = triple.join(':')
               end

               skip = false
               lock.synchronize {
                  if (energies.has_key?(id))
                     skip = true
                  else
                     # Mark the key so others don't try to take it mid-computation.
                     energies[id] = -1
                  end
               }

               if (skip)
                  next
               end

               if (entityMapping == nil)
                  ok, energy = energyMethod.call(
                     entityEmbeddings[triple[Constants::HEAD]],
                     entityEmbeddings[triple[Constants::TAIL]],
                     relationEmbeddings[triple[Constants::RELATION]],
                     triple[Constants::HEAD],
                     triple[Constants::TAIL],
                     triple[Constants::RELATION]
                  )
               else
                  # It is possible for the entity/relation to not exist if it got filtered
                  # out for having too low a confidence score.
                  # For these, just leave them out of the energy mapping.
                  if (!entityMapping.has_key?(triple[Constants::HEAD]) || !entityMapping.has_key?(triple[Constants::TAIL]) || !relationMapping.has_key?(triple[Constants::RELATION]))
                     next
                  end

                  begin
                     ok, energy = energyMethod.call(
                        entityEmbeddings[entityMapping[triple[Constants::HEAD]]],
                        entityEmbeddings[entityMapping[triple[Constants::TAIL]]],
                        relationEmbeddings[relationMapping[triple[Constants::RELATION]]],
                        entityMapping[triple[Constants::HEAD]],
                        entityMapping[triple[Constants::TAIL]],
                        relationMapping[triple[Constants::RELATION]]
                     )
                  rescue Exception => ex
                     # TEST
                     puts "EXCEPTION: #{ex}"
                     puts ex.backtrace()
                  end
               end

               if (!skipBadEnergies || ok)
                  lock.synchronize {
                     energies[id] = energy
                  }
               end
            }
         }
      }

      pool.wait(:done)
      pool.shutdown()

      # Remove rejected energies.
      energies.delete_if{|key, value| value == -1}

      return energies
   end

   def Energies.computeTripleFile(triplesPath, datasetDir, embeddingDir, embeddingMethod = nil, distanceType = nil, corrupt = true, &block)
      triples = Load.triples(triplesPath, false)
      Energies.computeTriples(triples, datasetDir, embeddingDir, embeddingMethod, distanceType, corrupt, &block)
   end

   # Compute the energies of all the triples in a file and possibly their corruptions.
   # A block is required.
   # If |corrupt| is true, all corruptions will be computes (usaully A LOT).
   # The block will get called with: [[triple, energy], ...]
   # The list may be empty.
   # If embeddingDir is properly formatted (by scripts/embeddings/computeEmbeddings.rb),
   # then embeddingMethod and distanceType can be inferred.
   def Energies.computeTriples(triples, datasetDir, embeddingDir, embeddingMethod = nil, distanceType = nil, corrupt = true, &block)
      if (block == nil)
         raise("A block is required")
      end

      energyMethod = nil
      if (embeddingMethod == nil && distanceType == nil)
         energyMethod = Energies.getEnergyMethodFromPath(embeddingDir)
      else
         energyMethod = Energies.getEnergyMethod(embeddingMethod, distanceType, embeddingDir)
      end

      entityMapping = Load.idMapping(File.join(datasetDir, Constants::RAW_ENTITY_MAPPING_FILENAME), false)
      relationMapping = Load.idMapping(File.join(datasetDir, Constants::RAW_RELATION_MAPPING_FILENAME), false)
      entityEmbeddings, relationEmbeddings = LoadEmbedding.vectors(embeddingDir)

      if (corrupt)
         Energies.computeCorruptionEnergies(
            triples,
            entityMapping, relationMapping,
            entityEmbeddings, relationEmbeddings, energyMethod,
            &block
         )
      else
         Energies.computeSimpleEnergies(
            triples,
            entityMapping, relationMapping,
            entityEmbeddings, relationEmbeddings, energyMethod,
            &block
         )
      end
   end

   def Energies.computeSimpleEnergies(
         baseTriples,
         entityMapping, relationMapping,
         entityEmbeddings, relationEmbeddings, energyMethod,
         &block)
      if (block == nil)
         raise("A block is required")
      end

      # Note that we use the base triples themselves and not the mapping to pull relations.
      # It is possible we embedded on a relation that we do not know about.
      relations = baseTriples.map{|triple| triple[Constants::RELATION]}.uniq()

      relations.each{|relation|
         validTriples = baseTriples.select{|triple| triple[Constants::RELATION] == relation}

         energies = Energies.computeEnergies(
            validTriples,
            entityMapping, relationMapping,
            entityEmbeddings, relationEmbeddings, energyMethod,
            false, false
         )
         validTriples.clear()

         # Right now the energies are in a map with string key, turn into a list.
         # [[triple, energy], ...]
         # No need to convert the keys to ints now, since we will just write them out.
         energies = energies.to_a().map{|id, energy|
            [id.split(':'), energy]
         }

         block.call(energies)
      }
   end

   def Energies.computeCorruptionEnergies(
         baseTriples,
         entityMapping, relationMapping,
         entityEmbeddings, relationEmbeddings, energyMethod,
         &block)
      if (block == nil)
         raise("A block is required")
      end

      # Note that we use the base triples themselves and not the mapping to pull relations.
      # Is is possible we embedded on a relation that we do not know about.
      relations = baseTriples.map{|triple| triple[Constants::RELATION]}.uniq()

      seenCorruptions = Set.new()
      corruptions = []

      relations.each{|relation|
         seenCorruptions.clear()

         validTriples = baseTriples.select{|triple| triple[Constants::RELATION] == relation}
         validTriples.each{|validTriple|
            corruptions.clear()

            # Corrupt the head and tail for each triple.
            [Constants::HEAD, Constants::TAIL].each{|corruptionTarget|
               entityMapping.keys().each{|corruptComponent|
                  if (corruptionTarget == Constants::HEAD)
                     head = corruptComponent
                     tail = validTriple[Constants::TAIL]
                  else
                     head = validTriple[Constants::HEAD]
                     tail = corruptComponent
                  end

                  id = "#{head}:#{tail}"
                  if (seenCorruptions.include?(id))
                     next
                  end

                  seenCorruptions << id

                  corruption = Array.new(3, 0)
                  corruption[Constants::HEAD] = head
                  corruption[Constants::TAIL] = tail
                  corruption[Constants::RELATION] = relation

                  corruptions << corruption
               }
            }

            energies = Energies.computeEnergies(
               corruptions,
               entityMapping, relationMapping,
               entityEmbeddings, relationEmbeddings, energyMethod,
               false, true
            )
            corruptions.clear()

            # Right now the energies are in a map with string key, turn into a list.
            # [[triple, energy], ...]
            # No need to convert the keys to ints now, since we will just write them out.
            energies = energies.to_a().map{|id, energy|
               head, tail = id.split(':')
               [[head, tail, relation], energy]
            }

            block.call(energies)

            energies.clear()
         }
      }
   end

   # Assume the embedding dir is properly formatted
   # (by scripts/embeddings/computeEmbeddings.rb), and infer an energy method from it.
   def Energies.getEnergyMethodFromPath(embeddingDir)
      embeddingMethod = File.basename(embeddingDir).match(/^([^_]+)_/)[1]
      distanceType = nil

      if (embeddingDir.include?("distance:#{Distance::L1_ID_INT}"))
         distanceType = Distance::L1_ID_STRING
      elsif (embeddingDir.include?("distance:#{Distance::L2_ID_INT}"))
         distanceType = Distance::L2_ID_STRING
      # StransE does it differently.
      elsif (embeddingDir.include?('STransE') && embeddingDir.include?('l1:1'))
         distanceType = Distance::L1_ID_STRING
      elsif (embeddingDir.include?('STransE') && embeddingDir.include?('l1:0'))
         distanceType = Distance::L2_ID_STRING
      end

      return Energies.getEnergyMethod(embeddingMethod, distanceType, embeddingDir)
   end

   # Given an embedding method and distance type, return a proc that will compute the energy.
   def Energies.getEnergyMethod(embeddingMethod, distanceType, embeddingDir)
      if (![Distance::L1_ID_STRING, Distance::L2_ID_STRING].include?(distanceType))
         raise("Unknown distance type: #{distanceType}")
      end

      case embeddingMethod
      when TransE::ID_STRING
         return proc{|head, tail, relation, headId, tailId, relationId|
            TransE.tripleEnergy(distanceType, head, tail, relation)
         }
      when TransH::ID_STRING
         transHWeights = LoadEmbedding.weights(embeddingDir)
         return proc{|head, tail, relation, headId, tailId, relationId|
            TransH.tripleEnergy(head, tail, relation, transHWeights[relationId])
         }
      when STransE::ID_STRING
         weights1, weights2 = STransE.loadWeights(embeddingDir)
         return proc{|head, tail, relation, headId, tailId, relationId|
            STransE.tripleEnergy(distanceType, head, tail, relation, weights1[relationId], weights2[relationId])
         }
      else
         raise "Unknown embedding method: #{embeddingMethod}"
      end
   end

   # Given an embedding method and distance type, return the maximum energy that the method considers
   # not bad. This number is very subjective and I suggest callers find their own value.
   def Energies.getMaxEnergy(embeddingMethod, distanceType, embeddingDir)
      if (![Distance::L1_ID_STRING, Distance::L2_ID_STRING].include?(distanceType))
         raise("Unknown distance type: #{distanceType}")
      end

      case embeddingMethod
      when TransE::ID_STRING
         if (distanceType == Distance::L1_ID_STRING)
            return TransE::MAX_ENERGY_THRESHOLD_L1
         else
            return TransE::MAX_ENERGY_THRESHOLD_L2
         end
      when TransH::ID_STRING
         return TransH::MAX_ENERGY_THRESHOLD
      else
         raise "Unknown embedding method: #{embeddingMethod}"
      end
   end
end
