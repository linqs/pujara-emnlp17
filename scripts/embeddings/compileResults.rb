# Compile the results of embedding evaluations.

EVAL_FILENAME = 'eval.txt'
BASE_DIR = 'results'

DELIMITER = "\t"

def getResults(dir)
   results = {}

   path = File.join(dir, EVAL_FILENAME)
   if (!File.exists?(path))
      return nil
   end

   File.open(path, 'r'){|file|
      results[:model] = File.basename(dir).match(/^([^_]+)_/)[1]

      file.each{|line|
         line.strip!()

         if (line.start_with?('Options: '))
            # ["key: value", ...]
            options = line.sub(/Options: \[(.+)\]$/, '\1').split(', ')

            # [[key, value], ...]
            options.map!{|pair| pair.split(': ')}

            # Remove extra quotes.
            options.map!{|pair| [pair[0], pair[1].gsub("'", '').gsub(/\s/, '')]}

            # Convert to hash.
            options = options.to_h()

            # Special overrdies.

            # Remove outdir
            options.delete('outdir')

            # Simplfy datadir to just the basename.
            if (options.include?('datadir'))
               options['datadir'] = File.basename(options['datadir'])
            end

            results[:options] = options
         elsif (line.start_with?('Raw'))
            match = line.match(/Rank: (\d+(?:\.\d+)?), Hits@10: (\d(?:\.\d+))/)
            results[:raw] = {
               :rank => match[1].to_f(),
               :hitsAt10 => match[2].to_f()
            }
         elsif (line.start_with?('Filtered'))
            match = line.match(/Rank: (\d+(?:\.\d+)?), Hits@10: (\d(?:\.\d+))/)
            results[:filtered] = {
               :rank => match[1].to_f(),
               :hitsAt10 => match[2].to_f()
            }
         elsif (line.start_with?("Processed"))
            # Skip
            next
         else
            $stderr.puts("Unknown line pattern: [#{line}].")
         end
      }
   }

   return results
end

def printResults(results)
   if (results.size() == 0)
      return
   end

   fields = results[0][:options].keys().sort()

   # Print header
   print 'model' + DELIMITER
   print fields.join(DELIMITER)
   puts DELIMITER + ['raw-Rank', 'raw-Hits@10', 'filtered-Rank', 'filtered-Hits@10'].join(DELIMITER)

   # Print data
   results.each{|result|
      print result[:model] + DELIMITER
      print fields.map{|key| result[:options][key]}.join(DELIMITER)
      stats = [result[:raw][:rank], result[:raw][:hitsAt10], result[:filtered][:rank], result[:filtered][:hitsAt10]]
      puts DELIMITER + stats.join(DELIMITER)
   }
end

def main(args)
   dirs = Dir.entries(BASE_DIR).delete_if{|entry| ['.', '..'].include?(entry)}

   # Convert to paths and only keep dirs.
   dirs = dirs.map{|entry| File.join(BASE_DIR, entry)}.delete_if{|path| !File.directory?(path)}

   data = []
   dirs.each{|dir|
      results = getResults(dir)
      if (results == nil)
         next
      end

      data << results
   }

   printResults(data)
end

if (__FILE__ == $0)
   main(ARGV)
end
