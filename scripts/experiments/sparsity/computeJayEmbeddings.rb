require_relative '../../embeddings/computeAllEmbeddings'
require_relative '../../lib/constants'
require_relative '../../lib/distance'
require_relative '../../lib/embedding/constants'


EX_DATA_DIRS = [
   'NELLE_00000_INCLUDE_CATS_201704061535'
].map{|basename| File.absolute_path(File.join(Constants::RAW_DATA_PATH, basename))}

EX_TRANSE_EXPERIMENTS = {
   'emethod' => 'TransE',
   'data' => EX_DATA_DIRS,
   'args' => {
      'size' => [100],
      'rate' => [0.001],
      'margin' => [1.0],
      'method' => [Embedding::METHOD_BERNOULLI],
      'distance' => [Distance::L1_ID_INT]
   }
}

EX_TRANSH_EXPERIMENTS = {
   'emethod' => 'TransH',
   'data' => EX_DATA_DIRS,
   'args' => {
      'size' => [100],
      'rate' => [0.005],
      'margin' => [0.25],
      'method' => [Embedding::METHOD_BERNOULLI],
      'distance' => [Distance::L1_ID_INT]
   }
}

def main(args)
   # experiments = buildExperiments(EX_TRANSE_EXPERIMENTS) + buildExperiments(EX_TRANSH_EXPERIMENTS)
   experiments = buildExperiments(EX_TRANSE_EXPERIMENTS)
   runAll(experiments)
end

if (__FILE__ == $0)
   main(ARGV)
end
