require_relative '../../lib/constants'

NUM_REGEX = '\d+(?:\.\d+)?'
EMBEDDING_EVAL_HEADERS = [
   'Embeddings',
   'Raw - Rank',
   'Raw - Hits@10',
   'Filtered - Rank',
   'Filtered - Hits@10'
]

def parseStats(dataDir, datasetName)
   values = [datasetName]

   File.open(File.join(dataDir, Constants::EMBEDDING_EVAL_FILENAME), 'r'){|file|
      file.each{|line|
         if (match = line.match(/Rank:\s+(#{NUM_REGEX}),\s+Hits@10:\s+(#{NUM_REGEX})/))
            values << match[1]
            values << match[2]
         end
      }
   }

   if (values.size() < EMBEDDING_EVAL_HEADERS.size())
      return nil
   end

   return values.join("\t")
end

def loadArgs(args)
   if (args.size() < 1 || args.map{|arg| arg.gsub('-', '').downcase()}.include?('help'))
      puts "USAGE: ruby #{$0} <embedding dir> ..."
      puts "   Get the embedding evaluation results on all the passed in embedding dirs."
      exit(1)
   end

   return args
end

def main(args)
   dataDirs = loadArgs(args)

   content = [EMBEDDING_EVAL_HEADERS.join("\t")]
   dataDirs.each{|dataDir|
      datasetName = File.basename(dataDir)

      stats = parseStats(dataDir, datasetName)
      if (stats != nil)
         content << stats
      end
   }

   puts content.join("\n")
end

if ($0 == __FILE__)
   main(ARGV)
end
