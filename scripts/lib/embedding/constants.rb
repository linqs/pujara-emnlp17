module Embedding
   METHOD_UNIFORM = 0
   METHOD_BERNOULLI = 1

   # The different probability methods used by the embeddings.
   # These are often used as extensions to the embedding files.
   PROB_METHOD_UNIF = 'unif'
   PROB_METHOD_BERN = 'bern'

   CODE_PATH = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'external-code', 'KB2E'))
end
