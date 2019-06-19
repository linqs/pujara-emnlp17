require_relative '../../lib/constants'
require_relative '../dataSetStats'

NUM_REGEX = '\d+(?:\.\d+)?'
DATA_STATS_HEADERS = [
   'Dataset',
   'Total - Triples',
   'Total - Distinct Entities',
   'Total - Distinct Relations',
   'Total - T/E - Gross Mean',
   'Total - T/R - Gross Mean',
   'Total - R/E - Mean',
   'Total - R/E - Median',
   'Total - E/R - Mean',
   'Total - E/R - Median',
   'Total - T/E - Mean',
   'Total - T/E - Median',
   'Total - T/R - Mean',
   'Total - T/R - Median',
   'Test - Triples',
   'Test - Distinct Entities',
   'Test - Distinct Relations',
   'Test - T/E - Gross Mean',
   'Test - T/R - Gross Mean',
   'Test - R/E - Mean',
   'Test - R/E - Median',
   'Test - E/R - Mean',
   'Test - E/R - Median',
   'Test - T/E - Mean',
   'Test - T/E - Median',
   'Test - T/R - Mean',
   'Test - T/R - Median',
   'Train - Triples',
   'Train - Distinct Entities',
   'Train - Distinct Relations',
   'Train - T/E - Gross Mean',
   'Train - T/R - Gross Mean',
   'Train - R/E - Mean',
   'Train - R/E - Median',
   'Train - E/R - Mean',
   'Train - E/R - Median',
   'Train - T/E - Mean',
   'Train - T/E - Median',
   'Train - T/R - Mean',
   'Train - T/R - Median',
   'Truth - Triples',
   'Truth - Distinct Entities',
   'Truth - Distinct Relations',
   'Truth - T/E - Gross Mean',
   'Truth - T/R - Gross Mean',
   'Truth - R/E - Mean',
   'Truth - R/E - Median',
   'Truth - E/R - Mean',
   'Truth - E/R - Median',
   'Truth - T/E - Mean',
   'Truth - T/E - Median',
   'Truth - T/R - Mean',
   'Truth - T/R - Median'
]

def parseStats(text, datasetName)
   values = [datasetName]
   text.each_line{|line|
      if (match = line.match(/(#{NUM_REGEX})/))
         values << match[1]
      end
   }

   return values.join("\t")
end

def loadArgs(args)
   if (args.size() < 1 || args.map{|arg| arg.gsub('-', '').downcase()}.include?('help'))
      puts "USAGE: ruby #{$0} <data dir> ..."
      puts "   Get the stats on all the data dirs and output each dataset as a tab separated line."
      exit(1)
   end

   return args
end

def main(args)
   dataDirs = loadArgs(args)

   content = [DATA_STATS_HEADERS.join("\t")]
   dataDirs.each{|dataDir|
      datasetName = File.basename(dataDir)
      content << parseStats(genDataStats(dataDir, false, true), datasetName)
   }

   puts content.join("\n")
end

if ($0 == __FILE__)
   main(ARGV)
end
