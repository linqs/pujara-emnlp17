# Uses the same concepts (and most of code) from ./compileData.rb, but uses a more struct set of data.

require_relative './compileData'
require_relative '../../lib/nelle/constants'
require_relative '../../lib/nelle/load'

MIN_ENTITY_COUNT = 1
MIN_RELATION_COUNT = 1

# Override (shadow, actually).
# Returns [triple, ...], rejectedCount.
def fetchTriples(dataDir, minConfidence)
   return NellELoad.allTriples(dataDir, minConfidence, NellE::STRICT_TRAINING_REL_FILENAMES)
end

# Override (shadow, actually).
# Returns [catPair, ...], rejectedCount.
def fetchCats(dataDir, minConfidence)
   return NellELoad.allCategories(dataDir, minConfidence, NellE::STRICT_TRAINING_CAT_FILENAMES)
end

# Override (shadow, actually).
# Returns [triple, ...]
def fetchTestTriples(dataDir)
   return NellELoad.testTriples(dataDir)

   # Load only positive examples (hence the 0.1.
   # All the test triples actually have 0 or 1, so 0.1 will just leave out the 0s.
   testRels, _ = NellELoad.allTriples(dataDir, 0.1, NellE::STRICT_TEST_REL_FILENAMES)
   testCats, _ = NellELoad.allCategories(dataDir, minConfidence, NellE::STRICT_TEST_CAT_FILENAMES)

   return testRels + testCats
end

def main(args)
   compileData(*parseArgs(args))
end

if (__FILE__ == $0)
   main(ARGV)
end
