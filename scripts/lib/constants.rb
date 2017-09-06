module Constants
   # Datasets
   NELL_DATASET = 'NELL'
   FB15K_DATASET = 'FB15k'

   DATASETS = [NELL_DATASET, FB15K_DATASET]

   # Files

   # Names
   RAW_DIR_NAME = 'raw'
   PSL_DIR_NAME = 'psl-prepped'
   NELLE_DIR_NAME = 'nelle'

   RAW_TEST_FILENAME = 'test.txt'
   RAW_TRAIN_FILENAME = 'train.txt'
   RAW_VALID_FILENAME = 'valid.txt'
   RAW_ENTITY_MAPPING_FILENAME = 'entity2id.txt'
   RAW_RELATION_MAPPING_FILENAME = 'relation2id.txt'

   RAW_TRIPLE_FILENAMES = [RAW_TEST_FILENAME, RAW_TRAIN_FILENAME, RAW_VALID_FILENAME]

   STATS_FILENAME = 'stats.txt'
   EMBEDDING_EVAL_FILENAME = 'eval.txt'

   # These belong in the embedding directory.
   EVAL_ENERGIES_FILENAME = 'eval_energies_full.txt'
   POSITIVE_ENERGIES_FILENAME = 'eval_energies_positive.txt'
   NEGATIVE_ENERGIES_FILENAME = 'eval_energies_negative.txt'

   # Paths
   DATA_PATH = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..', 'data'))
   RAW_DATA_PATH = File.join(DATA_PATH, RAW_DIR_NAME)
   PSL_DATA_PATH = File.join(DATA_PATH, PSL_DIR_NAME)
   NELLE_DATA_PATH = File.join(DATA_PATH, NELLE_DIR_NAME)
   EMBEDDINGS_PATH = File.join(DATA_PATH, 'embeddings')

   RAW_FB15K_PATH = File.join(RAW_DATA_PATH, FB15K_DATASET)

   FB_ENTITY_NAMES_PATH = File.join(DATA_PATH, 'misc', 'FB15k_entityNames.txt')

   # Triples
   # In most cases, we want to put triples in an Array with the following indecies.
   # Also, this is the order they will be in files.
   HEAD = 0
   TAIL = 1
   RELATION = 2

   # Misc
   PAGE_SIZE = 10000
end
