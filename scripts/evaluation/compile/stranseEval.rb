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

   outFile = nil
   Dir.foreach(dataDir){|filename|
      if (filename.end_with?('.log.txt'))
         outFile = filename
         break
      end
   }

   if (outFile == nil)
      puts "ERROR - Could not locate stats for: #{dataDir}"
      return nil
   end

   File.open(File.join(dataDir, outFile), 'r'){|file|
      file.each{|line|
         if (match = line.match(/^\s+Raw scores .* on test set: (#{NUM_REGEX})\s+.*\s+(#{NUM_REGEX})$/))
            values << match[1]
            values << match[2]
         elsif (match = line.match(/^\s+Filtered scores .* on test set: (#{NUM_REGEX})\s+.*\s+(#{NUM_REGEX})$/))
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
