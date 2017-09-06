require_relative '../lib/histogram'
require_relative '../lib/load'

def printGeneralHistogram(valuesFile, min = nil, max = nil)
   if (min == nil || max == nil)
      min = nil
      max = nil

      # First pass is just for min/max
      Load.energies(valuesFile, false){|values|
         values.values().each{|value|
            if (min == nil || value < min)
               min = value
            end

            if (max == nil || value > max)
               max = value
            end
         }
      }
   end

   histogram = Histogram.new(min, max)

   Load.energies(valuesFile, false){|values|
      histogram << values.values()
   }

   puts histogram.to_s()
end

def loadArgs(args)
   if (args.size < 1 || args.size > 2 || args.map{|arg| arg.gsub('-', '').downcase()}.include?('help'))
      puts "USAGE: ruby #{$0} <energy/ranks file> [--normalized]"
      puts "The --normalized flag can be be supplied to signal that the file is already normalized between 0 and 1."
      puts "This utility is meant for energy/rank files, but will work with any file that is formatted: \"id\tvalue\"."
      exit(1)
   end

   valuesFile = args[0]
   normalized = false

   if (args.size() == 2)
      if (args[1] != '--normalized')
         puts "Unknown flag."
         exit(2)
      end

      normalized = true
   end

   return valuesFile, normalized
end

def main(args)
   valuesFile, normalized = loadArgs(args)

   if (normalized)
      printGeneralHistogram(valuesFile, 0.0, 1.0)
   else
      printGeneralHistogram(valuesFile)
   end
end

if ($0 == __FILE__)
   main(ARGV)
end
