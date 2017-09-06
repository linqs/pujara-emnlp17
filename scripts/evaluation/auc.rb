# We do not expect very large sets of triples in the TEST/VALID sets.

require_relative '../lib/constants'
require_relative '../lib/embedding/energies'
require_relative '../lib/histogram'
require_relative '../lib/load'

require 'set'

ENERGY_THRESHOLD_STEP = 0.50

# Override this.
def loadPositiveTriples(dataDir)
   return Load.triples(File.join(dataDir, Constants::RAW_TEST_FILENAME), false)
end

# Override this.
def loadNegativeTriples(dataDir)
   return []
end

def f1(precision, recall)
   if (precision == 0 && recall == 0)
      return 0
   end

   return 2.0 * (precision.to_f() * recall) / (precision.to_f() + recall)
end

# Return: [[triple, energy], ...]
def calcEvalEnergies(dataDir, embeddingDir, filename, fetchTriplesFunction)
   energiesPath = File.join(embeddingDir, filename)

   # To save memory, we will write all energies out first, and then just read them.
   File.open(energiesPath, 'w'){|file|
      Energies.computeTriples(fetchTriplesFunction.call(), dataDir, embeddingDir, nil, nil, false){|energies|
         file.puts(energies.map{|energy| energy.flatten().join("\t")}.join("\n"))
      }
   }

   return Load.tripleEnergies(energiesPath, false)
end

# Return: [[triple, energy], ...]
def loadEnergies(dataDir, embeddingDir, filename, fetchTriplesFunction)
   energiesPath = File.join(embeddingDir, filename)
   if (File.exists?(energiesPath))
      # TEST
      puts "Found precomputed energies: #{energiesPath}"

      return Load.tripleEnergies(energiesPath, false)
   end

   # TEST
   puts "No precomputed energies found, calculating"

   return calcEvalEnergies(dataDir, embeddingDir, filename, fetchTriplesFunction)
end

def loadEvalEnergies(dataDir, embeddingDir)
   fetchPositiveTriples = Proc.new{loadPositiveTriples(dataDir)}
   fetchNegativeTriples = Proc.new{loadNegativeTriples(dataDir)}

   positiveEnergies = loadEnergies(dataDir, embeddingDir, Constants::POSITIVE_ENERGIES_FILENAME, fetchPositiveTriples)
   negativeEnergies = loadEnergies(dataDir, embeddingDir, Constants::NEGATIVE_ENERGIES_FILENAME, fetchNegativeTriples)

   return positiveEnergies, negativeEnergies
end

def calcAUC(energies, positiveTriples, negativeTriples)
   tp = 0.0
   fp = 0.0

   auc = 0.0
   previousPrecision = 1
   previousRecall = 0

   # Sort by energy.
   energies.sort{|a, b| a[1] <=> b[1]}.each{|triple, energy|
      # Pretend we predict true for all triples.
      if (positiveTriples.include?(triple))
         tp += 1
      elsif (negativeTriples.include?(triple))
         fp += 1
      else
         raise("Could not find triple in positive or negative samples.")
      end

      precision = tp.to_f() / (tp + fp)
      recall = tp.to_f() / positiveTriples.size()

      auc += (recall - previousRecall) * ((precision + previousPrecision) / 2.0)

      previousPrecision = precision
      previousRecall = recall
   }

   auc += (1.0 - previousRecall) * ((0.0 + previousPrecision) / 2.0)

   return auc
end

# Returns: [precision, recall]
def calcStats(energies, positiveTriples, negativeTriples, energyThreshold)
   tp = 0.0
   fp = 0.0
   tn = 0.0
   fn = 0.0

   energies.each{|triple, energy|
      predictPositive = (energy >= energyThreshold)

      actualPositive = nil
      if (positiveTriples.include?(triple))
         actualPositive = true
      elsif (negativeTriples.include?(triple))
         actualPositive = false
      else
         raise("Could not find triple in positive or negative samples.")
      end

      if (predictPositive && actualPositive)
         tp += 1
      elsif (predictPositive && !actualPositive)
         fp += 1
      elsif (!predictPositive && actualPositive)
         fn += 1
      else
         tn += 1
      end
   }

   precision = 0
   if (tp + fp != 0)
      precision = tp.to_f() / (tp + fp)
   end

   recall = 0
   if (tp + fn != 0)
      recall = tp.to_f() / (tp + fn)
   end

   return precision, recall
end

def parseArgs(args)
   if (args.size != 2 || args.map{|arg| arg.gsub('-', '').downcase()}.include?('help'))
      puts "USAGE: ruby #{$0} <data dir> <embedding dir>"
      exit(1)
   end

   dataDir = args.shift()
   embeddingDir = args.shift()

   return dataDir, embeddingDir
end

def main(args)
   dataDir, embeddingDir = parseArgs(args)

   positiveEnergies, negativeEnergies = loadEvalEnergies(dataDir, embeddingDir)

   positiveTriples = Set.new(positiveEnergies.map{|energies| energies[0]})
   negativeTriples = Set.new(negativeEnergies.map{|energies| energies[0]})
   energies = positiveEnergies + negativeEnergies

   puts 'Energy Stats:'
   puts Histogram.generate(energies.map{|triple, energy| energy})
   puts ''

   min, max = energies.map{|triple, energy| energy}.minmax()
   min = min.to_i().to_f()
   max = (max + 1.0).to_i().to_f()

   puts "AUC: #{calcAUC(energies, positiveTriples, negativeTriples)}"
   puts ''

   puts ("%10s %10s %10s %10s\n" % ["threshold", "F1", "Precision", "Recall"])
   (min..max).step(ENERGY_THRESHOLD_STEP).each{|threshold|
      threshold = threshold.round(2)
      precision, recall = calcStats(energies, positiveTriples, negativeTriples, threshold)

      puts ("%10.3f %10.3f %10.3f %10.3f" % [threshold, f1(precision, recall), precision, recall])
   }
end

if ($0 == __FILE__)
   main(ARGV)
end
