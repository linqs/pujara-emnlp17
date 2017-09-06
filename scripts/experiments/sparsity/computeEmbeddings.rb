require_relative '../../embeddings/computeAllEmbeddings'
require_relative '../../lib/constants'
require_relative '../../lib/distance'
require_relative '../../lib/embedding/constants'


EX_DATA_DIRS = [
   'FB15k',
   'FB15k_CORRUPT[010]',
   'FB15k_CORRUPT[020]',
   'FB15k_CORRUPT[030]',
   'FB15k_CORRUPT[040]',
   'FB15k_CORRUPT[050]',
   'FB15k_CR[100]',
   'FB15k_CR[200]',
   'FB15k_CR[300]',
   'FB15k_CR[400]',
   'FB15k_CR[500]',
   'FB15k_CR[600]',
   'FB15k_TR[050000]',
   'FB15k_TR[100000]',
   'FB15k_TR[150000]',
   'FB15k_TR[200000]',
   'FB15k_TR[250000]',
   'FB15k_TR[300000]',
   'FB15k_RR[050000]',
   'FB15k_RR[100000]',
   'FB15k_RR[150000]',
   'FB15k_RR[200000]',
   'FB15k_RR[250000]',
   'FB15k_RR[300000]',
   # 'NELL_SPARSE_075_100_[3.3478;600000]_201704051023',
   'NELLE_00000_INCLUDE_CATS_201704061535',
   'REVERB_201704120113'
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

EX_TRANSR_EXPERIMENTS = {
   'emethod' => 'TransR',
   'data' => EX_DATA_DIRS,
   'args' => {
      'size' => [100],
      'rate' => [0.001],
      'margin' => [1.0],
      'method' => [Embedding::METHOD_BERNOULLI],
      'distance' => [Distance::L1_ID_INT]
   }
}

def main(args)
   # experiments = buildExperiments(EX_TRANSE_EXPERIMENTS) + buildExperiments(EX_TRANSH_EXPERIMENTS)
   # experiments = buildExperiments(EX_TRANSE_EXPERIMENTS)
   experiments = buildTransRExperiments(EX_TRANSR_EXPERIMENTS)

   puts experiments

   # TEST
   #runAll(experiments)
end

if (__FILE__ == $0)
   main(ARGV)
end
