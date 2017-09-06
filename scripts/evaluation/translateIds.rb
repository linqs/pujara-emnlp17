require_relative '../lib/constants'
require_relative '../lib/load'

require 'set'

require 'pg'

# Take in an energy/ranks file, keep the top N, and convert the ids to human readable triples.
# We are assuming that N is fairly small (<= 100).

TRIPLES_FILE = 'targets.txt'
DB_NAME = 'nell'
DEFAULT_SAMPLE_SIZE = 10

# Relations are already named, so we just need the entities.
# We were not able to recover all entities, so we will leave any we can't find as it.
def convertFreebaseMapping(triples)
   entityIds = triples.to_a().map{|triple| [triple[1][:head], triple[1][:tail]]}.flatten().uniq()

   entityMapping = {}
   File.open(Constants::FB_ENTITY_NAMES_PATH, 'r'){|file|
      file.each{|line|
         parts = line.split("\t").map{|part| part.strip()}
         if (ids.include?(parts[0]))
            entityMapping[parts[0]] = parts[1]

            if (entityMapping.size() == entityIds.size())
               break
            end
         end
      }
   }

   triples.each_key{|key|
      if (entityMapping.include?([triples[key][:head]]))
         triples[key][:head] = entityMapping[triples[key][:head]]
      end

      if (entityMapping.include?([triples[key][:tail]]))
         triples[key][:tail] = entityMapping[triples[key][:tail]]
      end
   }

   return triples
end

# Go the last mile and convert Nell integer ids to strings.
def convertNellMapping(triples)
   conn = PG::Connection.new(:host => 'localhost', :dbname => DB_NAME)

   entityIds = triples.to_a().map{|triple| [triple[1][:head], triple[1][:tail]]}.flatten().uniq()
   relationIds = triples.to_a().map{|triple| triple[1][:relation]}.uniq()

   query = "
      SELECT
         id,
         nellId
      FROM Entities
      WHERE id IN (#{entityIds.join(', ')})
   "
	entityMapping = conn.exec(query).values().map{|id, nellId| [id.to_i(), nellId]}.to_h()

   query = "
      SELECT
         id,
         nellId
      FROM Relations
      WHERE id IN (#{relationIds.join(', ')})
   "
	relationMapping = conn.exec(query).values().map{|id, nellId| [id.to_i(), nellId]}.to_h()

   conn.close()

   triples.each_key{|key|
      triples[key][:head] = entityMapping[triples[key][:head]]
      triples[key][:tail] = entityMapping[triples[key][:tail]]
      triples[key][:relation] = relationMapping[triples[key][:relation]]
   }

   return triples
end

def fetchDatasetMapping(ids, mappingPath)
   mapping = {}

   File.open(mappingPath){|file|
      file.each{|line|
         parts = line.split("\t").map{|part| part.strip().to_i()}
         if (ids.include?(parts[1]))
            mapping[parts[1]] = parts[0]

            if (mapping.size() == ids.size())
               break
            end
         end
      }
   }

   return mapping
end

def convertToDatasetIds(triples, datasetDir)
   # Instead of reading all the entities and relations into memory, just load the ones we will need.
   entities = Set.new(triples.to_a().map{|triple| [triple[1][:head], triple[1][:tail]]}.flatten())
   relations = Set.new(triples.to_a().map{|triple| triple[1][:relation]})

   entityMapping = fetchDatasetMapping(entities, File.join(datasetDir, Constants::RAW_ENTITY_MAPPING_FILENAME))
   relationMapping = fetchDatasetMapping(relations, File.join(datasetDir, Constants::RAW_RELATION_MAPPING_FILENAME))

   triples.each_key{|key|
      triples[key][:head] = entityMapping[triples[key][:head]]
      triples[key][:tail] = entityMapping[triples[key][:tail]]
      triples[key][:relation] = relationMapping[triples[key][:relation]]
   }

   return triples
end

# Mark each triple as either valid or invalid (will add a :valid key).
def findValidTriples(triples, pslDataDir)
   triples.each_value{|triple|
      triple[:valid] = false
   }

   # Make the check easier with an additional mapping.
   keyMapping = {}
   triples.each_pair{|id, triple|
      keyMapping["#{triple[:head]},#{triple[:tail]},#{triple[:relation]}"] = id
   }

   Constants::RAW_TRIPLE_FILENAMES.each{|tripleFilename|
      File.open(File.join(pslDataDir, tripleFilename), 'r'){|file|
         file.each{|line|
            parts = line.split("\t").map{|part| part.strip().to_i()}
            key = "#{parts[0]},#{parts[1]},#{parts[2]}"

            if (keyMapping.include?(key))
               triples[keyMapping[key]][:valid] = true
            end
         }
      }
   }

   return triples
end

def convertToTriples(ranks, pslDataDir)
   triples = {}
   ids = Set.new(ranks.keys())

   # Read the triples id file and instead of putting it all in memory, just scan for the correct vailes.
   File.open(File.join(pslDataDir, TRIPLES_FILE), 'r'){|file|
      file.each{|line|
         parts = line.split("\t").map{|part| part.strip().to_i()}
         if (ids.include?(parts[0]))
            triples[parts[0]] = {
               :head => parts[1],
               :tail => parts[2],
               :relation => parts[3],
               :rank => ranks[parts[0]]
            }

            # Got 'um, bail out.
            if (triples.size() == ranks.size())
               break
            end
         end
      }
   }

   if (triples.size() != ranks.size())
      $stderr.puts("Unable to find all the triples, bailing out.")
      exit(3)
   end

   return triples
end

# TODO(eriq): Pretty sloppy work here.
def loadArgs(args)
   if (args.size < 3 || args.size() > 5 || args.map{|arg| arg.gsub('-', '').downcase()}.include?('help'))
      $stderr.puts "USAGE: ruby #{$0} <rank file> <psl data dir> <dataset dir> [sampleSize] [--normalize]"
      exit(1)
   end

   ranksFile = args[0]
   pslDataDir = args[1]
   datasetDir = args[2]
   sampleSize = DEFAULT_SAMPLE_SIZE
   normalize = false

   if (args.size() > 3)
      sampleSize = args[3].to_i()
   end

   if (args.size() > 4)
      normalize = true
   end

   datasetType = nil
   Constants::DATASETS.each{|dataset|
      if (datasetDir.include?(dataset))
         datasetType = dataset
         break
      end
   }

   return ranksFile, normalize, sampleSize, pslDataDir, datasetDir, datasetType
end

def main(args)
   ranksFile, normalize, sampleSize, pslDataDir, datasetDir, datasetType = loadArgs(args)

   if (!(Constants::DATASETS.include?(datasetType)))
      $stderr.puts("Unknown dataset type: #{datasetType}")
      exit(4)
   end

   ranks = Load.energies(ranksFile, normalize)

   # Keep the top |sampleSize| triples.
   ranks = ranks.to_a().sort{|a, b| -1 * (a[1] <=> b[1])}[0...sampleSize].to_h()

   triples = convertToTriples(ranks, pslDataDir)
   triples = findValidTriples(triples, pslDataDir)

   triples = convertToDatasetIds(triples, datasetDir)

   if (datasetType == Constants::NELL_DATASET)
      triples = convertNellMapping(triples)
   elsif (datasetType == Constants::FB15K_DATASET)
      triples = convertFreebaseMapping(triples)
   end

   triples.to_a().sort{|a, b| -1 * (a[1][:rank] <=> b[1][:rank])}.each{|id, triple|
      puts "#{triple[:valid] ? 'O' : 'X'} -- #{triple[:head]} :: #{triple[:relation]} :: #{triple[:tail]}"
   }
end

if ($0 == __FILE__)
   main(ARGV)
end
