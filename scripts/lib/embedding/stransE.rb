require_relative '../distance'

require 'csv'
require 'matrix'

module STransE
   ID_STRING = 'STransE'

   ENTITY_EMBEDDING_EXT = 'entity2vec'
   RELATION_EMBEDDING_EXT = 'relation2vec'
   WEIGHT1_EXT = 'W1'
   WEIGHT2_EXT = 'W2'

   # Remember, each param is an embedding vector.
   def STransE.tripleEnergy(distanceType, head, tail, relation, weight1, weight2)
      energy = 0

      head = Matrix.column_vector(head)
      tail = Matrix.column_vector(tail)
      relation = Matrix.column_vector(relation)

      res = (weight1 * head) + relation - (weight2 * tail)
      if (distanceType == Distance::L1_ID_STRING)
         res.each{|val|
            energy += val.abs()
         }
      elsif (distanceType == Distance::L2_ID_STRING)
         res.each{|val|
            energy += val ** 2
         }
         energy = Math.sqrt(energy)
      else
         raise("Unknown distance type: [#{distanceType}]")
      end

      return true, energy
   end

   # Returned objects will be arrays of matrices.
   def STransE.loadWeights(embeddingDir)
      weight1Path = nil
      weight2Path = nil

      Dir.foreach(embeddingDir){|filename|
         if (filename.end_with?(".#{WEIGHT1_EXT}"))
            weight1Path = File.join(embeddingDir, filename)
         elsif (filename.end_with?(".#{WEIGHT2_EXT}"))
            weight2Path = File.join(embeddingDir, filename)
         end
      }

      if (weight1Path == nil || weight2Path == nil)
         raise("Unable to find weight files for STransE.")
      end

      # Get the embedding size.
      match = embeddingDir.match(/,size:(\d+)\]$/)
      if (match == nil)
         raise("Unable to discover embedding size from embessing path for STransE.")
      end
      embeddingSize = match[1].to_i()

      return STransE.loadWeightFile(weight1Path, embeddingSize), STransE.loadWeightFile(weight2Path, embeddingSize)
   end

   # Weights are 3d.
   # Each line holds one matrix.
   # We will just infer matrix size from row length.
   # [relation] = Matrix(entity, entity)
   def STransE.loadWeightFile(path, embeddingSize)
      weights = []
      lineno = 0

      currentMatrix = []
      CSV.foreach(path, {:col_sep => "\t", :converters => :numeric, :skip_blanks => true}){|line|
         lineno += 1

         # Sometimes STransE puts out an extra tab at the end of the line.
         if (line[-1] == nil)
            line.pop()
         end

         currentMatrix << line

         if (lineno % embeddingSize == 0)
            weights << Matrix.rows(currentMatrix)
            currentMatrix = []
         end
      }

      if (currentMatrix.size() != 0)
         raise("Have leftover rows  (#{currentMatric.size()}).")
      end

      return weights
   end
end
