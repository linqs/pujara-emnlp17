require_relative '../../lib/constants'

NUM_REGEX = '\d+(?:\.\d+)?'
EMBEDDING_EVAL_HEADERS = [
   'Embeddings',
   'Raw - Rank',
   'Raw - Hits@10',
   'Filtered - Rank',
   'Filtered - Hits@10'
]
OUTPUT_FILENAME = 'train.err'

def parseStats(dataDir, datasetName)
   values = [datasetName]

   outPath = File.join(dataDir, OUTPUT_FILENAME)
   if (!File.exists?(outPath))
      puts "ERROR - Could not locate stats for: #{dataDir}"
      return nil
   end

   File.open(File.join(outPath), 'r'){|file|
      # Only pick the last stats.
      file.reverse_each{|line|
         if (match = line.match(/^INFO:EX-KG:\[\d+\] VALID: MRR = #{NUM_REGEX}\/#{NUM_REGEX}, Mean Rank = (#{NUM_REGEX})\/(#{NUM_REGEX}), Hits@10 = (#{NUM_REGEX})\/(#{NUM_REGEX})$/))
            values << match[1]
            values << (match[3].to_f() / 100.0).round(4)
            values << match[2]
            values << (match[4].to_f() / 100.0).round(4)

            break
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
      puts "   Get the embedding evaluation results on all the passed in StransE embedding dirs."
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
