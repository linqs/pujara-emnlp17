require_relative '../../evaluation/auc.rb'
require_relative '../../lib/constants'
require_relative '../../lib/nelle/load'

CAT_TEST_TRIPLES_PATH = File.join(Constants::NELLE_DATA_PATH, '165', 'label-test-uniq-raw-cat.db.TRAIN')
REL_TEST_TRIPLES_PATH = File.join(Constants::NELLE_DATA_PATH, '165', 'label-test-uniq-raw-rel.db.TRAIN')

# Override
def loadPositiveTriples(dataDir)
   loadAllTestTriples()[0]
end

# Override
def loadNegativeTriples(dataDir)
   loadAllTestTriples()[1]
end

# Returns: [positiveTriples, negativeTriples]
def loadAllTestTriples()
   positiveCats, negativeCats = NellELoad.triplesWithRejected(CAT_TEST_TRIPLES_PATH, 0.1)
   positiveRels, negativeRels = NellELoad.triplesWithRejected(REL_TEST_TRIPLES_PATH, 0.1)

   # Inject the relation into the cats.
   positiveCats.map!{|catPair| catPair << NellE::CAT_RELATION_ID}
   negativeCats.map!{|catPair| catPair << NellE::CAT_RELATION_ID}

   # Convert the keys back to strings to work woth more general code.
   positiveTriples = (positiveCats + positiveRels).map{|triple| triple.map{|part| part.to_s()}}
   negativeTriples = (negativeCats + negativeRels).map{|triple| triple.map{|part| part.to_s()}}

   return positiveTriples, negativeTriples
end

if ($0 == __FILE__)
   main(ARGV)
end
