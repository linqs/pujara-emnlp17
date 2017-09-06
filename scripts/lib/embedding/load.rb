# Moule for working with embedding files.

require_relative 'constants'

module LoadEmbedding
   WEIGHT_EMBEDDING_BASENAME = 'weights'
   ENTITY_EMBEDDING_BASENAME = 'entity2vec'
   RELATION_EMBEDDING_BASENAME = 'relation2vec'

   # Note: The if of the entity/relation is the line index in the file.
   def LoadEmbedding.file(path)
      embeddings = []

      File.open(path, 'r'){|file|
         file.each{|line|
            embeddings << line.strip().split("\t").map{|part| part.strip().to_f()}
         }
      }

      return embeddings
   end

   def LoadEmbedding.weights(embeddingDir)
      # Check if we are workig with unif or bern.
      if (File.exists?(File.join(embeddingDir, WEIGHT_EMBEDDING_BASENAME + '.' + Embedding::PROB_METHOD_UNIF)))
         # Unif
         return LoadEmbedding.file(File.join(embeddingDir, WEIGHT_EMBEDDING_BASENAME + '.' + Embedding::PROB_METHOD_UNIF))
      else
         # Bern
         return LoadEmbedding.file(File.join(embeddingDir, WEIGHT_EMBEDDING_BASENAME + '.' + Embedding::PROB_METHOD_BERN))
      end
   end

   def LoadEmbedding.vectors(embeddingDir)
      entityPath = nil
      relationPath = nil

      # Check if we are workig with unif or bern.
      if (File.exists?(File.join(embeddingDir, ENTITY_EMBEDDING_BASENAME + '.' + Embedding::PROB_METHOD_UNIF)))
         # Unif
         entityPath = File.join(embeddingDir, ENTITY_EMBEDDING_BASENAME + '.' + Embedding::PROB_METHOD_UNIF)
         relationPath = File.join(embeddingDir, RELATION_EMBEDDING_BASENAME + '.' + Embedding::PROB_METHOD_UNIF)
      elsif (File.exists?(File.join(embeddingDir, ENTITY_EMBEDDING_BASENAME + '.' + Embedding::PROB_METHOD_BERN)))
         # Bern
         entityPath = File.join(embeddingDir, ENTITY_EMBEDDING_BASENAME + '.' + Embedding::PROB_METHOD_BERN)
         relationPath = File.join(embeddingDir, RELATION_EMBEDDING_BASENAME + '.' + Embedding::PROB_METHOD_BERN)
      else
         # Another format used by STransE.
         Dir.foreach(embeddingDir){|filename|
            if (filename.end_with?(".#{ENTITY_EMBEDDING_BASENAME}"))
               entityPath = File.join(embeddingDir, filename)
            elsif (filename.end_with?(".#{RELATION_EMBEDDING_BASENAME}"))
               relationPath = File.join(embeddingDir, filename)
            end
         }

         if (entityPath == nil && relationPath == nil)
            raise("Unable to locate entity and relation vector files in: #{embeddingDir}")
         end
      end

      entityEmbeddings = LoadEmbedding.file(entityPath)
      relationEmbeddings = LoadEmbedding.file(relationPath)

      return entityEmbeddings, relationEmbeddings
   end
end
