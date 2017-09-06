require_relative '../constants'

module ReverbLoad
   def ReverbLoad.triples(path)
      triples = []

      File.open(path, 'r'){|file|
         file.each{|line|
            parts = line.split("\t").map{|part| part.strip()}
            confidence = parts.pop().to_f()

            triple = Array.new(3)
            triple[Constants::HEAD] = parts[0]
            triple[Constants::TAIL] = parts[2]
            triple[Constants::RELATION] = parts[1]

            triples << triple
         }
      }

      return triples.uniq()
   end

   # Returns: [[triple, isValid (boolean), confidence], ...]
   def ReverbLoad.annotations(path)
      data = []

      File.open(path, 'r'){|file|
         file.each{|line|
            row = line.split("\t").map{|part| part.strip().downcase()}

            parts = row[2].gsub(/(^\()|(\)$)/, '').split(';').map{|part| part.strip().gsub(' ', '_')}

            if (parts.size() != 3)
               puts "Rejecting annotation triple with incorrect size. Line #{file.lineno}. [#{row[2]}]."
               next
            end

            triple = Array.new(3)
            triple[Constants::HEAD] = parts[0]
            triple[Constants::TAIL] = parts[2]
            triple[Constants::RELATION] = parts[1]

            data << [
               triple,
               row[0] == '1',
               row[1].to_f()
            ]
         }
      }

      return data
   end

   def ReverbLoad.fullFileFormat(path)
      triples = []

      File.open(path, 'r'){|file|
         file.each{|line|
            parts = line.split("\t").map{|part| part.strip().downcase()}

            triple = Array.new(3)
            triple[Constants::HEAD] = parts[4]
            triple[Constants::TAIL] = parts[6]
            triple[Constants::RELATION] = parts[5]

            triples << triple
         }
      }

      return triples
   end
end
