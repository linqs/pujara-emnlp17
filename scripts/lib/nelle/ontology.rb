require_relative '../util'

require 'set'

module Ontology
   # Keys for how we are storing an ontological pairing.
   FORWARD = 0
   REVERSE = 1

   # Ontology types
   DOMAIN = 'Domain'
   INVERSE = 'Inv'
   MUTUAL_EXCLUSION = 'Mut'
   RANGE = 'Range2'
   RELATION_MUTUAL_EXCLUSION = 'RMut'
   RELATION_SUBSUMPTION = 'RSub'
   SUBSUMPTION = 'Sub'

   DEFAULT_EXPAND_MAX_ITERATIONS = 20

   FILENAMES = {
      Ontology::DOMAIN => '165.onto-wbpg.db.Domain.txt',
      Ontology::INVERSE => '165.onto-wbpg.db.Inv.txt',
      Ontology::MUTUAL_EXCLUSION => '165.onto-wbpg.db.Mut.txt',
      Ontology::RANGE => '165.onto-wbpg.db.Range2.txt',
      Ontology::RELATION_MUTUAL_EXCLUSION => '165.onto-wbpg.db.RMut.txt',
      Ontology::RELATION_SUBSUMPTION => '165.onto-wbpg.db.RSub.txt',
      Ontology::SUBSUMPTION => '165.onto-wbpg.db.Sub.txt'
   }

   # Note that the hash that will be returned is NOT just formatted as a Hash or Arrays.
   # The returned structre will be large, but quick for lookups.
   # {
   #    SUBSUMPTION => {
   #       FORWARD => {firstKey => secondKey, ...},
   #       REVERSE => {secondKey => firstKey, ...}
   #    }, ...
   # }
   def Ontology.load(dataDir, intKeys = true)
      ontology = {}

      Ontology::FILENAMES.each_pair{|ontologyType, filename|
         File.open(File.join(dataDir, filename), 'r'){|file|
            forward = {}
            reverse = {}

            file.each{|line|
               parts = line.split("\t").map{|part| part.strip()}

               if (intKeys)
                  parts.map!{|part| part.to_i()}
               end

               forward[parts[0]] = parts[1]
               reverse[parts[1]] = parts[0]
            }

            ontology[ontologyType] = {
               Ontology::FORWARD => forward,
               Ontology::REVERSE => reverse
            }
         }
      }

      return ontology
   end

   def Ontology.expand(triples, ontology, maxIterations = Ontology::DEFAULT_EXPAND_MAX_ITERATIONS, debug = false)
      triples = Set.new(triples)

      # Note that category subsumption does not make sense because we do not know what entity belonging to the supercategoty
      # we should make the replacement with.
      # E1 -> C1 --(subsumption)--> C0 -> {E9, E8, E7}.
      expansionSchemes = [
         {
            :ontologyType => Ontology::RELATION_SUBSUMPTION,
            :ontologyDirection => Ontology::FORWARD,
            :tripleComponent => Constants::RELATION
         },
         {
            :ontologyType => Ontology::INVERSE,
            :ontologyDirection => nil,
            :tripleComponent => nil
         },
      ]

      startingSize = triples.size()
      done = false
      ontologyTriples = Set.new()

      for iteration in 0...maxIterations
         iterationStartingTriples = triples.size()
         Util.debugPuts("Iteration #{iteration} - #{iterationStartingTriples} starting triples", debug)

         ontologyTriples.clear()

         expansionSchemes.each{|expansionScheme|
            if (expansionScheme[:ontologyType] == Ontology::INVERSE)
               newTriples = Ontology.expandInverse(ontology, triples)
            else
               newTriples = Ontology.expandWithOntology(
                     ontology, triples,
                     expansionScheme[:ontologyType], expansionScheme[:ontologyDirection], expansionScheme[:tripleComponent]
               )
            end

            Util.debugPuts("   #{expansionScheme[:ontologyType]}(#{expansionScheme[:tripleComponent]}) -- #{newTriples.size()}", debug)

            ontologyTriples += newTriples
         }

         Util.debugPuts("   #{ontologyTriples.size()} pending new triples", debug)

         triples += ontologyTriples

         Util.debugPuts("   #{triples.size()} ending triples (+#{triples.size() - iterationStartingTriples})", debug)

         if (iterationStartingTriples == triples.size())
            break
         end
      end

      Util.debugPuts("Adding #{triples.size() - startingSize} ontology triples in #{iteration + 1} iterations", debug)
      Util.debugPuts("Ending Size: #{triples.size()}", debug)

      return triples
   end

   # Go through |triples| and replace |tripleComponent| (head, tail, relation)
   # with the value from ontology[ontologyType][ontologyDirection] (asuming triple[tripleComponent] is a mathcing key).
   # Will return only the expanded triples.
   # Note that we do not check to see if the new triple is already part of |triples|.
   def Ontology.expandWithOntology(ontology, triples, ontologyType, ontologyDirection, tripleComponent)
      newTriples = Set.new()

      triples.each{|triple|
         component = triple[tripleComponent]
         if (ontology[ontologyType][ontologyDirection].has_key?(component))
            newTriple = triple.clone()
            newTriple[tripleComponent] = ontology[ontologyType][ontologyDirection][component]
            newTriples << newTriple
         end
      }

      return newTriples
   end

   # Inverse is a special case, since we are not just replacing a single component.
   # We are replacing the relation and swapping the head/tail.
   def Ontology.expandInverse(ontology, triples)
      newTriples = Set.new()

      triples.each{|triple|
         relation = triple[Constants::RELATION]

         [Ontology::FORWARD, Ontology::REVERSE].each{|direction|
            if (ontology[Ontology::INVERSE][direction].has_key?(relation))
               newTriple = Array.new(3, 0)

               newTriple[Constants::HEAD] = triple[Constants::TAIL]
               newTriple[Constants::TAIL] = triple[Constants::HEAD]
               newTriple[Constants::RELATION] = ontology[Ontology::INVERSE][direction][relation]

               newTriples << newTriple
            end
         }
      }

      return newTriples
   end
end
