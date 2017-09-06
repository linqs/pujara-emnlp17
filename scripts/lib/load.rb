require_relative 'constants'
require_relative 'math-utils'

module Load
   # Ranks are 0 - 1
   # Shortcut for Load.energies(path, true, true).
   def Load.ranks(path, &block)
      return Load.energies(path, true, true, &block)
   end

   def Load.energies(path, normalize = false, intKeys = true, &block)
      if (block == nil)
         return Load.map(path, normalize, intKeys)
      else
         return Load.mapOnline(path, normalize, intKeys, &block)
      end
   end

   # {id: rank, ...}
   # File sould be: "int\tfloat"
   # Usaully you will want to call Load.ranks or Load.energies.
   def Load.map(path, normalize, intKeys = true)
      values = {}

      File.open(path, 'r'){|file|
         file.each{|line|
            parts = line.split("\t").map{|part| part.strip()}

            if (intKeys)
               key = parts[0].to_i()
            else
               key = parts[0]
            end

            values[key] = parts[1].to_f()
         }
      }

      if (normalize)
         values = MathUtils::normalize(values)
      end

      return values
   end

   # Two passes will be made over the file (to reduce the memory load), one for min/max and one for the callback.
   # Block will be called with {id: rank, ...} of size PAGE_SIZE or less.
   def Load.mapOnline(path, normalize, intKeys = true, &block)
      if (normalize)
         min = -1
         max = -1

         Load.mapOnline(path, false){|values|
            batchMin, batchMax = values.values().minmax()

            if (min == -1 || batchMin < min)
               min = batchMin
            end

            if (max == -1 || batchMax > max)
               max = batchMax
            end
         }
      end

      values = {}

      File.open(path, 'r'){|file|
         file.each{|line|
            parts = line.split("\t").map{|part| part.strip()}

            if (intKeys)
               key = parts[0].to_i()
            else
               key = parts[0]
            end

            values[key] = parts[1].to_f()

            if (values.size() == Constants::PAGE_SIZE)
               if (normalize)
                  values = MathUtils.normalize(values, min, max)
               end

               block.call(values)
               values.clear()
            end
         }
      }

      if (values.size() != 0)
         if (normalize)
            values = MathUtils.normalize(values, min, max)
         end

         block.call(values)
         values.clear()
      end
   end

   # {firstId: secondId, ...}
   # Similar to Load.map, but doesn't do any normalization
   # If a block is passed, then the block will be called with each batch of ids.
   # Note that even if |intKeys| is false, the value (second value) is always expected to be an int.
   def Load.idMapping(path, intKeys = false, &block)
      if (block == nil)
         return Load.idMappingOffline(path, intKeys)
      else
         Load.idMappingOnline(path, intKeys, &block)
         return nil
      end
   end

   def Load.idMappingOffline(path, intKeys = false)
      values = {}

      File.open(path, 'r'){|file|
         file.each{|line|
            parts = line.split("\t").map{|part| part.strip()}

            if (intKeys)
               parts[0] = parts[0].to_i()
            end
            parts[1] = parts[1].to_i()

            values[parts[0]] = parts[1]
         }
      }

      return values
   end

   # Two passes will be made over the file (to reduce the memory load), one for min/max and one for the callback.
   # Block will be called with {id: rank, ...} of size PAGE_SIZE or less.
   def Load.idMappingOnline(path, intKeys = false, &block)
      values = {}

      File.open(path, 'r'){|file|
         file.each{|line|
            parts = line.split("\t").map{|part| part.strip()}

            if (intKeys)
               parts[0] = parts[0].to_i()
            end
            parts[1] = parts[1].to_i()

            values[parts[0]] = parts[1]

            if (values.size() == Constants::PAGE_SIZE)
               block.call(values)
               values.clear()
            end
         }
      }

      if (values.size() != 0)
         block.call(values)
         values.clear()
      end

      return nil
   end

   # [[head, tail, relation], ...]
   # All components must be ints.
   def Load.triples(path, intKeys = true)
      triples = []

      File.open(path, 'r'){|file|
         file.each{|line|
            parts = line.split("\t").map{|part| part.strip()}

            if (intKeys)
               parts.map!{|part| part.to_i()}
            end

            triples << parts
         }
      }

      return triples
   end

   # {id => [head, tail, relation], ...}
   def Load.triplesWithId(path, intKeys = true)
      triples = {}

      File.open(path, 'r'){|file|
         file.each{|line|
            parts = line.split("\t").map{|part| part.strip()}

            if (intKeys)
               parts.map!{|part| part.to_i()}
            end

            triples[parts[0]] = parts[1...4]
         }
      }

      return triples
   end

   # Return: [[triple, energy], ...]
   def Load.tripleEnergies(path, intKeys = true)
      triples = []

      File.open(path, 'r'){|file|
         file.each{|line|
            parts = line.split("\t").map{|part| part.strip()}
            energy = parts.pop().to_f()

            if (intKeys)
               parts.map!{|part| part.to_i()}
            end

            triples << [parts, energy]
         }
      }

      return triples
   end

   def Load.writeEntities(path, triples)
      entities = []
      entities += triples.map{|triple| triple[Constants::HEAD]}
      entities += triples.map{|triple| triple[Constants::TAIL]}
      entities.uniq!()

      File.open(path, 'w'){|file|
         file.puts(entities.map.with_index{|entity, index| "#{entity}\t#{index}"}.join("\n"))
      }
   end

   def Load.writeRelations(path, triples)
      relations = triples.map{|triple| triple[Constants::RELATION]}
      relations.uniq!()

      File.open(path, 'w'){|file|
         file.puts(relations.map.with_index{|relation, index| "#{relation}\t#{index}"}.join("\n"))
      }
   end

   def Load.writeTriples(path, triples)
      File.open(path, 'w'){|file|
         # Head, Tail, Relation
         file.puts(triples.map{|triple| "#{triple[Constants::HEAD]}\t#{triple[Constants::TAIL]}\t#{triple[Constants::RELATION]}"}.join("\n"))
      }
   end
end
