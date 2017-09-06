# Enumerate over the options and generate all the Nell-based datasets.
# Abandoning triples per relation because we can't get enough triples.

GEN_SCRIPT_PATH = File.join('scripts', 'data-processing', 'nell', 'genDatasetFiles.rb')
PRECISION = 2

MIN_CONFIDENCE = 0.50
MAX_CONFIDENCE = 1.00
CONFIDENCE_STEP = 0.10

# Triples Per Entity
# 0 actually isn't a 
MIN_ENTITY_CENTILE = 1
MAX_ENTITY_CENTILE = 100
ENTITY_CENTILE_STEP = 25

MIN_RELATION_CENTILE = 1
MAX_RELATION_CENTILE = 100

MAX_TRIPLES = 600000

def genDataset(minConfidence, maxConfidence, minEntityCentile, maxEntityCentile, minRelationCentile, maxRelationCentile, maxTriples)
   args = [
      minConfidence,
      maxConfidence,
      minEntityCentile,
      maxEntityCentile,
      minRelationCentile,
      maxRelationCentile,
      maxTriples
   ]

   puts "ruby #{GEN_SCRIPT_PATH} #{args.map{|arg| "'#{arg}'"}.join(' ')}"
   puts `ruby #{GEN_SCRIPT_PATH} #{args.map{|arg| "'#{arg}'"}.join(' ')}`
end

def crossproductParams()
   paramSets = []

   minConfidence = MIN_CONFIDENCE
   while (minConfidence < MAX_CONFIDENCE)
      maxConfidence = (minConfidence + CONFIDENCE_STEP).round(PRECISION)

      minEntityCentile = MIN_ENTITY_CENTILE
      while (minEntityCentile < MAX_ENTITY_CENTILE)
         maxEntityCentile = minEntityCentile + ENTITY_CENTILE_STEP - 1

         paramSets << [minConfidence, maxConfidence, minEntityCentile, maxEntityCentile, MIN_RELATION_CENTILE, MAX_RELATION_CENTILE, MAX_TRIPLES]

         minEntityCentile = maxEntityCentile + 1
      end

      minConfidence = maxConfidence
   end

   return paramSets
end

def detailedParams()
   paramSets = []

   # Confidence
   minConfidence = 0.50
   while (minConfidence < 1.00)
      maxConfidence = (minConfidence + 0.05).round(PRECISION)

      paramSets << [minConfidence, maxConfidence, 76, 100, MIN_RELATION_CENTILE, MAX_RELATION_CENTILE, MAX_TRIPLES]

      minConfidence = maxConfidence
   end

   return paramSets
end

def main()
   paramSets = detailedParams() + crossproductParams()

   paramSets.each{|paramSet|
      genDataset(*paramSet)
   }
end

if ($0 == __FILE__)
   main()
end
