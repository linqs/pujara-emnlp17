# A convenience script for prep all the evaluation data for PSL.

require_relative 'prep'
require_relative '../../lib/constants'

def prepAll(dataDir)
   Dir.entries(dataDir).sort().each{|dir|
      if (['.', '..'].include?(dir))
         next
      end

      path = File.join(dataDir, dir)

      begin
         puts "Prepping: #{path}"
         prepForPSL([path])
      rescue Exception => ex
         puts "Failed to prep #{path}"
         puts ex.message()
         puts ex.backtrace()
      end
   }
end

def main(args)
   if (args.size() > 1 || args.map{|arg| arg.downcase().gsub('-', '')}.include?('help'))
      puts "USAGE: ruby #{$0} [data dir]"
      puts "data dir defaults to #{Constants::EMBEDDINGS_PATH}"
      exit(1)
   end

   dataDir = Constants::EMBEDDINGS_PATH
   if (args.size() == 1)
      dataDir = args[0]
   end

   prepAll(dataDir)
end

if (__FILE__ == $0)
   main(ARGV)
end
