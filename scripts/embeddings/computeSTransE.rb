require_relative '../lib/constants'
require_relative '../lib/util'

require 'etc'
require 'fileutils'

# gem install thread
require 'thread/pool'

NUM_THREADS = Etc.nprocessors - 1

SOURCE_DIR = File.join('.', 'external-code', 'STransE')
COMPILE_COMMAND = "g++ -I '#{File.absolute_path(SOURCE_DIR)}' STransE.cpp -o STransE -O2 -fopenmp -lpthread"

DATASETS = [
   'FB15k',
   'FB15k_CORRUPT[010]',
   'FB15k_CORRUPT[020]',
   'FB15k_CORRUPT[030]',
   'FB15k_CORRUPT[040]',
   'FB15k_CORRUPT[050]',
   'FB15k_RR[050000]',
   'FB15k_RR[100000]',
   'FB15k_RR[150000]',
   'FB15k_RR[200000]',
   'FB15k_RR[250000]',
   'FB15k_RR[300000]',
   'FB15k_TR[050000]',
   'FB15k_TR[100000]',
   'FB15k_TR[150000]',
   'FB15k_TR[200000]',
   'FB15k_TR[250000]',
   'FB15k_TR[300000]'
   # 'NELLE_00000_INCLUDE_CATS_201704061535',
   # 'WN18'
]

# We will need TransE embeddings as initization data for STransE.
# All the evaluation methods use the same TransE options.
TRANSE_FB15K_OPTIONS = '[size:100,margin:1,method:1,rate:0.001,batches:100,epochs:1000,distance:0]'
TRANSE_WN_OPTIONS = '[size:100,margin:1,method:0,rate:0.01,batches:100,epochs:1000,distance:0]'

TRANSE_FB15K_SUFFIX = 'bern'
TRANSE_WN_SUFFIX = 'unif'

# All STransE runs will use the same options.
STANDARD_OPTIONS = {
   'model' => '1',
   'l1' => '1',
   'init' => '0'
}

DATA_FILES_TO_COPY = [
   Constants::RAW_TEST_FILENAME,
   Constants::RAW_TRAIN_FILENAME,
   Constants::RAW_VALID_FILENAME,
   Constants::RAW_ENTITY_MAPPING_FILENAME,
   Constants::RAW_RELATION_MAPPING_FILENAME
]

def getOptions(dataset)
   options = STANDARD_OPTIONS.clone()

   if (dataset.start_with?('WN'))
      options['size'] = '50'
      options['margin'] = '5'
      options['lrate'] = '0.0005'
   else
      options['size'] = '100'
      options['margin'] = '1'
      options['lrate'] = '0.0001'
   end

   stringOptions = options.to_a().sort().map{|pair| pair.join(':')}.join(',')
   options['data'] = File.absolute_path(File.join(Constants::EMBEDDINGS_PATH, "STransE_#{dataset}_[#{stringOptions}]"))

   return options
end

def copyData(dataset, options)
   # Copy the data files into the new embedding dir.
   DATA_FILES_TO_COPY.each{|filename|
      FileUtils.cp(File.join(Constants::RAW_DATA_PATH, dataset, filename), options['data'])
   }

   # Copy over the corresponding TransE data as initization data.
   if (dataset.start_with?('WN'))
      initOptions = TRANSE_WN_OPTIONS
      initSuffix = TRANSE_WN_SUFFIX
   else
      initOptions = TRANSE_FB15K_OPTIONS
      initSuffix = TRANSE_FB15K_SUFFIX
   end

=begin  Init is not working well, skip it.
   FileUtils.cp(
      File.join(Constants::EMBEDDINGS_PATH, "TransE_#{dataset}_#{initOptions}", "entity2vec.#{initSuffix}"),
      File.join(options['data'], 'entity2vec.init')
   )

   FileUtils.cp(
      File.join(Constants::EMBEDDINGS_PATH, "TransE_#{dataset}_#{initOptions}", "relation2vec.#{initSuffix}"),
      File.join(options['data'], 'relation2vec.init')
   )
=end
end

def computeEmbeddings(options)
   outFile = File.join(options['data'], 'out_train.txt')
   errFile = File.join(options['data'], 'out_train.err')

   # STransE requires a trailing slash (separator).
   options['data'] += File::SEPARATOR
   stringOptions = options.to_a().sort().map{|key, val| ["-#{key}", val]}.flatten().map{|option| "'#{option}'"}.join(' ')
   # Remove the trailing slash.
   options['data'] = options['data'][0...-1]

   command = "cd '#{SOURCE_DIR}' && ./STransE #{stringOptions}"

   Util.run(command, outFile, errFile)
end

def cleanup(options)
   # Remove all the data files we copied over for training.
   DATA_FILES_TO_COPY.each{|filename|
      FileUtils.rm(File.join(options['data'], filename))
   }
end

def processDataset(dataset)
   options = getOptions(dataset)
   if (File.exists?(options['data']))
      puts "Embedding dir [#{options['data']}] already exists... skipping."
      return
   end

   puts "Processing [#{options['data']}]"

   FileUtils.mkdir_p(options['data'])
   copyData(dataset, options)

   computeEmbeddings(options)

   cleanup(options)
end

def setup()
   Util.run("cd '#{SOURCE_DIR}' && #{COMPILE_COMMAND}")
end

def main(args)
   setup()

   pool = Thread.pool(NUM_THREADS)

   DATASETS.each{|dataset|
      pool.process{
         begin
            processDataset(dataset)
         rescue Exception => ex
            puts "Failed to train #{dataset}"
            puts ex.message()
            puts ex.backtrace()
         end
      }
   }

   pool.wait(:done)
   pool.shutdown()
end

if (__FILE__ == $0)
   main(ARGV)
end
