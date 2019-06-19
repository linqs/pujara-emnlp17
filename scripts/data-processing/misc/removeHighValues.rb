require_relative '../../lib/load'

# Parse all the values and only output those that are within the top given percent.
# Note that we are dropping HIGH values.

DEFAULT_CUTTOFF = 0.5

def outputEnergies(energies, cuttoff)
   min, max = energies.values().minmax()

   maxEnergy = max - ((max - min) * cuttoff)

   energies.each_pair{|id, energy|
      if (energy < maxEnergy)
         puts "#{id}\t#{"%6.5f" % energy}"
      end
   }
end

def loadArgs(args)
   if (args.size < 1 || args.size() > 2 || args.map{|arg| arg.gsub('-', '').downcase()}.include?('help'))
      puts "USAGE: ruby #{$0} <energy file> [cuttoff percent]"
      puts "   cuttoff percent - throw away values in the top cuttoff percent."
      puts "      Default: #{DEFAULT_CUTTOFF}"
      puts "Data will be output to stdout."
      exit(1)
   end

   energiesFile = args[0]
   cuttoff = DEFAULT_CUTTOFF

   if (args.size() == 2)
      cuttoff = args[1].to_f()
   end

   if (cuttoff < 0 || cuttoff > 1)
      puts "Cuttoff should be between 0 and 1."
      exit(2)
   end

   return energiesFile, cuttoff
end

def main(args)
   energiesFile, cuttoff = loadArgs(args)

   energies = Load.energies(energiesFile, false)
   outputEnergies(energies, cuttoff)
end

if ($0 == __FILE__)
   main(ARGV)
end
