require_relative '../lib/constants'
require_relative '../lib/util'

require 'etc'
require 'fileutils'

# gem install thread
require 'thread/pool'

NUM_THREADS = Etc.nprocessors - 1

SOURCE_DIR = File.join('.', 'external-code', 'HolE', 'holographic-embeddings')
HOLE_SCRIPT = File.join(SOURCE_DIR, 'kg', 'run_hole.py')
DATA_PROCESSING_SCRIPT = File.join(SOURCE_DIR, 'scripts', 'pickle_data.py')

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
   'FB15k_TR[300000]',
   'NELLE_00000_INCLUDE_CATS_201704061535',
   'WN18'
]

# We will need TransE embeddings as initization data for STransE.
# All the evaluation methods use the same TransE options.
TRANSE_FB15K_OPTIONS = '[size:100,margin:1,method:1,rate:0.001,batches:100,epochs:1000,distance:0]'
TRANSE_WN_OPTIONS = '[size:100,margin:1,method:0,rate:0.01,batches:100,epochs:1000,distance:0]'

TRANSE_FB15K_SUFFIX = 'bern'
TRANSE_WN_SUFFIX = 'unif'

# All STransE runs will use the same options.
STANDARD_OPTIONS = {
   'test-all' => '50',
   'nb' => '100',
   'me' => '500',
   'margin' => '0.2',
   'lr' => '0.1',
   'ncomp' => '150'
}

def getOptions(dataset)
   options = STANDARD_OPTIONS.clone()

   return options
end

# Copy any data the needs to be.
def copyData(dataset, embeddingDir)
   datasetPath = File.join(Constants::RAW_DATA_PATH, dataset)

   # Check for any requested energy calculations.
   copyFile = ['negative_targets.txt', 'positive_targets.txt']
   copyFile.each{|filename|
      path = File.join(datasetPath, filename)
      if (File.exists?(path))
         FileUtils.cp(path, embeddingDir)
      end
   }
end

# Returns the path the the pickled data.
def genData(dataset, embeddingDir, options)
   datasetPath = File.join(Constants::RAW_DATA_PATH, dataset)
   picklePath = File.absolute_path(File.join(embeddingDir, "#{dataset}.pickle"))

   command = "python3 #{DATA_PROCESSING_SCRIPT} --inDir '#{datasetPath}' --out '#{picklePath}'"

   Util.run(command)

   return picklePath
end

def computeEmbeddings(options, embeddingDir, picklePath)
   outFile = File.join(embeddingDir, 'train.txt')
   errFile = File.join(embeddingDir, 'train.err')

   options['fin'] = picklePath
   options['fout'] = File.join(embeddingDir, "model.pickle")
   stringOptions = options.to_a().sort().map{|key, val| ["--#{key}", val]}.flatten().map{|option| "'#{option}'"}.join(' ')

   command = "python3 '#{HOLE_SCRIPT}' #{stringOptions}"

   Util.run(command, outFile, errFile)
end

def cleanup(options)
end

def processDataset(dataset)
   options = getOptions(dataset)

   stringOptions = options.to_a().sort().map{|pair| pair.join(':')}.join(',')
   embeddingDir = File.absolute_path(File.join(Constants::EMBEDDINGS_PATH, "HolE_#{dataset}_[#{stringOptions}]"))

   if (File.exists?(embeddingDir))
      puts "Embedding dir [#{embeddingDir}] already exists... skipping."
      return
   end

   puts "Processing [#{embeddingDir}]"

   FileUtils.mkdir_p(embeddingDir)

   copyData(dataset, embeddingDir)
   picklePath = genData(dataset, embeddingDir, options)
   computeEmbeddings(options, embeddingDir, picklePath)

   cleanup(options)
end

def setup()
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
