require_relative 'computeEmbeddings'
require_relative '../lib/constants'
require_relative '../lib/distance'
require_relative '../lib/embedding/constants'

require 'etc'
require 'fileutils'
require 'open3'

# gem install thread
require 'thread/pool'

# TODO(eriq): Must compile embedding programs first.

NUM_THREADS = Etc.nprocessors - 1

FB15K_DATA_DIR = File.absolute_path(File.join(Constants::RAW_DATA_PATH, 'FB15k'))
FB15K_005_DATA_DIR = File.absolute_path(File.join(Constants::RAW_DATA_PATH, 'FB15k_005'))
FB15K_010_DATA_DIR = File.absolute_path(File.join(Constants::RAW_DATA_PATH, 'FB15k_010'))
FB15K_050_DATA_DIR = File.absolute_path(File.join(Constants::RAW_DATA_PATH, 'FB15k_050'))

NELL_DATA_DIR = File.absolute_path(File.join(Constants::RAW_DATA_PATH, 'NELL_95'))

UNCERTIAN_NELL_DIRS = [
   'NELL_050_080_[005,005]_201701141040',
   'NELL_050_080_[020,005]_201701141040',
   'NELL_050_080_[020,020]_201701141040',
   'NELL_050_080_[050,050]_201701141040',
   'NELL_050_080_[100,100]_201701141040',
   'NELL_050_100_[005,005]_201701141040',
   'NELL_050_100_[020,005]_201701141040',
   'NELL_050_100_[020,020]_201701141040',
   'NELL_050_100_[050,050]_201701141040',
   'NELL_050_100_[100,100]_201701141040',
   'NELL_080_090_[005,005]_201701141040',
   'NELL_080_090_[020,005]_201701141040',
   'NELL_080_090_[020,020]_201701141040',
   'NELL_080_090_[050,050]_201701141040',
   'NELL_080_090_[100,100]_201701141040',
   'NELL_090_100_[005,005]_201701141040',
   'NELL_090_100_[020,005]_201701141040',
   'NELL_090_100_[020,020]_201701141040',
   'NELL_090_100_[050,050]_201701141040',
   'NELL_090_100_[100,100]_201701141040',
   'NELL_095_100_[005,005]_201701141040',
   'NELL_095_100_[020,005]_201701141040',
   'NELL_095_100_[020,020]_201701141040',
   'NELL_095_100_[050,050]_201701141040',
   'NELL_095_100_[100,100]_201701141040',
   'NELL_100_100_[005,005]_201701141040',
   'NELL_100_100_[020,005]_201701141040',
   'NELL_100_100_[020,020]_201701141040',
   'NELL_100_100_[050,050]_201701141040',
   'NELL_100_100_[100,100]_201701141040'
].map{|basename| File.absolute_path(File.join(Constants::RAW_DATA_PATH, basename))}

SPARSITY_DATA_DIRS = [
   'NELL_000_100_[001,100;010,040;600000]_201703310225',
   'NELL_000_100_[001,100;010,040;600000]_201703310225_CR[020]',
   'NELL_000_100_[001,100;010,040;600000]_201703310225_CR[040]',
   'NELL_000_100_[001,100;010,040;600000]_201703310225_CR[050]',
   'NELL_000_100_[001,100;010,040;600000]_201703310225_CR[060]',
].map{|basename| File.absolute_path(File.join(Constants::RAW_DATA_PATH, basename))}

TRANSE_EXPERIMENTS = {
   'emethod' => 'TransE',
   'data' => [FB15K_DATA_DIR, FB15K_005_DATA_DIR, FB15K_010_DATA_DIR, FB15K_050_DATA_DIR, NELL_DATA_DIR] + UNCERTIAN_NELL_DIRS,
   'args' => {
      'size' => [50, 100],
      'rate' => [0.01],
      'margin' => [1.0],
      'method' => [Embedding::METHOD_UNIFORM, Embedding::METHOD_BERNOULLI],
      'distance' => [Distance::L1_ID_INT, Distance::L2_ID_INT]
   }
}

TRANSH_EXPERIMENTS = {
   'emethod' => 'TransH',
   'data' => [FB15K_DATA_DIR, FB15K_005_DATA_DIR, FB15K_010_DATA_DIR, FB15K_050_DATA_DIR, NELL_DATA_DIR] + UNCERTIAN_NELL_DIRS,
   'args' => {
      'size' => [50, 100],
      'rate' => [0.01],
      'margin' => [1.0],
      'method' => [Embedding::METHOD_UNIFORM, Embedding::METHOD_BERNOULLI],
      'distance' => [Distance::L1_ID_INT]
   }
}

# Make sure the core settings mirror TRANSE since that is the seed data.
TRANSR_EXPERIMENTS = {
   'emethod' => 'TransR',
   'data' => [FB15K_DATA_DIR, FB15K_005_DATA_DIR, FB15K_010_DATA_DIR, FB15K_050_DATA_DIR, NELL_DATA_DIR],
   'args' => {
      'size' => [50, 100],
      'rate' => [0.01],
      'margin' => [1.0],
      'method' => [Embedding::METHOD_UNIFORM, Embedding::METHOD_BERNOULLI],
      'distance' => [Distance::L1_ID_INT, Distance::L2_ID_INT]
   }
}

# A new set of experiments revolving around confidence and sparsity.
SPARSITY_TRANSE_EXPERIMENTS = {
   'emethod' => 'TransE',
   'data' => SPARSITY_DATA_DIRS,
   'args' => {
      'size' => [100],
      'rate' => [0.001],
      'margin' => [1.0],
      'method' => [Embedding::METHOD_BERNOULLI],
      'distance' => [Distance::L1_ID_INT]
   }
}

SPARSITY_TRANSH_EXPERIMENTS = {
   'emethod' => 'TransH',
   'data' => SPARSITY_DATA_DIRS,
   'args' => {
      'size' => [100],
      'rate' => [0.005],
      'margin' => [0.25],
      'method' => [Embedding::METHOD_BERNOULLI],
      'distance' => [Distance::L1_ID_INT]
   }
}

# TransR needs some additional params.
def buildTransRExperiments(experimentsDefinition)
   experiments = buildExperiments(experimentsDefinition)

   experiments.each{|experiment|
      # TransE is the seed data, so grab the data from there.
      seeDataDir = getOutputDir(experiment).sub('TransR', 'TransE')
      experiment['args']['seeddatadir'] = seeDataDir

      # TODO(eriq): We are actually missing a set of experiments here.
      # The seed method and outer method are actually independent.
      experiment['args']['seedmethod'] = experiment['args']['method']
   }

   return experiments
end

# Take a condensed definition of some experiments and expand it out.
# TODO(eriq): This is pretty hacky and not robust at all.
def buildExperiments(experimentsDefinition)
   experiments = []

   experimentsDefinition['data'].each{|dataset|
      experimentsDefinition['args']['size'].each{|embeddingSize|
         experimentsDefinition['args']['method'].each{|method|
            experimentsDefinition['args']['distance'].each{|distance|
               experimentsDefinition['args']['rate'].each{|rate|
                  experiments << {
                     'emethod' => experimentsDefinition['emethod'],
                     'data' => dataset,
                     'args' => {
                        'size' => embeddingSize,
                        'margin' => 1,
                        'method' => method,
                        'rate' => rate,
                        'batches' => 100,
                        'epochs' => 1000,
                        'distance' => distance
                     }
                  }
               }
            }
         }
      }
   }

   return experiments
end

def runAll(experiments)
   pool = Thread.pool(NUM_THREADS)

   experiments.each{|experiment|
      pool.process{
         begin
            runExperiment(experiment, false)
         rescue Exception => ex
            puts "Failed to train #{getId(experiment)}"
            puts ex.message()
            puts ex.backtrace()
         end
      }
   }

   pool.wait(:done)
   pool.shutdown()
end

def main(args)
   # experiments = buildExperiments(SPARSITY_TRANSE_EXPERIMENTS) + buildExperiments(SPARSITY_TRANSH_EXPERIMENTS)
   experiments = buildExperiments(SPARSITY_TRANSE_EXPERIMENTS)

   # experiments = buildExperiments(TRANSE_EXPERIMENTS) + buildExperiments(TRANSH_EXPERIMENTS)
   # Some methods require data from other experiments and must be run after.
   # experiments2 = buildTransRExperiments(TRANSR_EXPERIMENTS)

   runAll(experiments)
   # runAll(experiments2)
end

if (__FILE__ == $0)
   main(ARGV)
end
