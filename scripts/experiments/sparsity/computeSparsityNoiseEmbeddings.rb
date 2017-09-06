require_relative '../../embeddings/computeAllEmbeddings'
require_relative '../../lib/constants'
require_relative '../../lib/distance'
require_relative '../../lib/embedding/constants'


EX_DATA_DIRS = [
   'FB15k_TRADEOFF[300000,000000,010]',
   'FB15k_TRADEOFF[300000,000000,020]',
   'FB15k_TRADEOFF[300000,000000,030]',
   'FB15k_TRADEOFF[300000,000000,040]',
   'FB15k_TRADEOFF[300000,000000,050]',
   'FB15k_TRADEOFF[300000,000000,060]',
   'FB15k_TRADEOFF[300000,000000,070]',
   'FB15k_TRADEOFF[300000,000000,080]',
   'FB15k_TRADEOFF[300000,000000,090]',
   'FB15k_TRADEOFF[300000,050000,010]',
   'FB15k_TRADEOFF[300000,050000,020]',
   'FB15k_TRADEOFF[300000,050000,030]',
   'FB15k_TRADEOFF[300000,050000,040]',
   'FB15k_TRADEOFF[300000,050000,050]',
   'FB15k_TRADEOFF[300000,050000,060]',
   'FB15k_TRADEOFF[300000,050000,070]',
   'FB15k_TRADEOFF[300000,050000,080]',
   'FB15k_TRADEOFF[300000,050000,090]',
   'FB15k_TRADEOFF[300000,100000,010]',
   'FB15k_TRADEOFF[300000,100000,020]',
   'FB15k_TRADEOFF[300000,100000,030]',
   'FB15k_TRADEOFF[300000,100000,040]',
   'FB15k_TRADEOFF[300000,100000,050]',
   'FB15k_TRADEOFF[300000,100000,060]',
   'FB15k_TRADEOFF[300000,100000,070]',
   'FB15k_TRADEOFF[300000,100000,080]',
   'FB15k_TRADEOFF[300000,100000,090]',
   'FB15k_TRADEOFF[300000,150000,010]',
   'FB15k_TRADEOFF[300000,150000,020]',
   'FB15k_TRADEOFF[300000,150000,030]',
   'FB15k_TRADEOFF[300000,150000,040]',
   'FB15k_TRADEOFF[300000,150000,050]',
   'FB15k_TRADEOFF[300000,150000,060]',
   'FB15k_TRADEOFF[300000,150000,070]',
   'FB15k_TRADEOFF[300000,150000,080]',
   'FB15k_TRADEOFF[300000,150000,090]',
   'FB15k_TRADEOFF[300000,200000,010]',
   'FB15k_TRADEOFF[300000,200000,020]',
   'FB15k_TRADEOFF[300000,200000,030]',
   'FB15k_TRADEOFF[300000,200000,040]',
   'FB15k_TRADEOFF[300000,200000,050]',
   'FB15k_TRADEOFF[300000,200000,060]',
   'FB15k_TRADEOFF[300000,200000,070]',
   'FB15k_TRADEOFF[300000,200000,080]',
   'FB15k_TRADEOFF[300000,200000,090]',
   'FB15k_TRADEOFF[300000,250000,010]',
   'FB15k_TRADEOFF[300000,250000,020]',
   'FB15k_TRADEOFF[300000,250000,030]',
   'FB15k_TRADEOFF[300000,250000,040]',
   'FB15k_TRADEOFF[300000,250000,050]',
   'FB15k_TRADEOFF[300000,250000,060]',
   'FB15k_TRADEOFF[300000,250000,070]',
   'FB15k_TRADEOFF[300000,250000,080]',
   'FB15k_TRADEOFF[300000,250000,090]',
   'FB15k_TRADEOFF[300000,300000,000]'
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
   experiments = buildExperiments(EX_TRANSE_EXPERIMENTS)

   # puts experiments
   runAll(experiments)
end

if (__FILE__ == $0)
   main(ARGV)
end
