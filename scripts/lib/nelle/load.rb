require_relative 'constants'

module NellELoad
   def NellELoad.triples(path, minConfidence = 0.0)
      triples = []
      rejectedCount = 0

      File.open(path, 'r'){|file|
         file.each{|line|
            parts = line.split("\t").map{|part| part.strip()}

            confidence = parts.pop().to_f()
            parts.map!{|part| part.to_i()}

            if (confidence < minConfidence)
               rejectedCount += 1
               next
            end

            triples << parts
         }
      }

      return triples, rejectedCount
   end

   def NellELoad.triplesWithRejected(path, minConfidence = 0.0)
      triples = []
      rejected = []

      File.open(path, 'r'){|file|
         file.each{|line|
            parts = line.split("\t").map{|part| part.strip()}

            confidence = parts.pop().to_f()
            parts.map!{|part| part.to_i()}

            if (confidence < minConfidence)
               rejected << parts
            else
               triples << parts
            end
         }
      }

      return triples, rejected
   end

   # Just get all the unique triples as an Array.
   def NellELoad.allTriples(sourceDir, minConfidence = 0.0, tripleFilenames = NellE::TRIPLE_FILENAMES)
      triples = []
      rejectedCount = 0

      tripleFilenames.each{|filename|
         newTriples, newRejectedCount = NellELoad.triples(File.join(sourceDir, filename), minConfidence)

         rejectedCount += newRejectedCount
         triples += newTriples
      }
      triples.uniq!()

      return triples, rejectedCount
   end

   # Get gold standard evaluation triples.
   def NellELoad.testTriples(sourceDir)
      triples = []

      NellE::TEST_TRIPLE_FILENAMES.each{|filename|
         # These files have either 0 or 1, but we will only consider positive triples.
         newTriples, newRejectedCount = NellELoad.triples(File.join(sourceDir, filename), 0.1)
         triples += newTriples
      }
      triples.uniq!()

      return triples
   end

   def NellELoad.categories(path, minConfidence = 0.0)
      cats = []
      rejectedCount = 0

      File.open(path, 'r'){|file|
         file.each{|line|
            parts = line.split("\t").map{|part| part.strip()}
            if (parts[2].to_f() < minConfidence)
               rejectedCount += 1
               next
            end

            cats << parts[0...2].map{|part| part.to_i()}
         }
      }

      return cats, rejectedCount
   end

   # Just get all the unique categories as an Array.
   def NellELoad.allCategories(sourceDir, minConfidence = 0.0, catFilenames = NellE::CATEGORY_FILENAMES)
      cats = []
      rejectedCount = 0

      catFilenames.each{|filename|
         newCats, newRejectedCount = NellELoad.categories(File.join(sourceDir, filename), minConfidence)

         rejectedCount += newRejectedCount
         cats += newCats
      }
      cats.uniq!()

      return cats, rejectedCount
   end

   def NellELoad.writeEntities(path, triples)
      entities = []
      entities += triples.map{|triple| triple[0]}
      entities += triples.map{|triple| triple[1]}
      entities.uniq!

      File.open(path, 'w'){|file|
         file.puts(entities.map.with_index{|entity, index| "#{entity}\t#{index}"}.join("\n"))
      }
   end

   def NellELoad.writeRelations(path, triples)
      relations = triples.map{|triple| triple[2]}
      relations.uniq!

      File.open(path, 'w'){|file|
         file.puts(relations.map.with_index{|relation, index| "#{relation}\t#{index}"}.join("\n"))
      }
   end

   def NellELoad.writeTriples(path, triples)
      File.open(path, 'w'){|file|
         # Head, Tail, Relation
         file.puts(triples.map{|triple| "#{triple[0]}\t#{triple[1]}\t#{triple[2]}"}.join("\n"))
      }
   end
end
