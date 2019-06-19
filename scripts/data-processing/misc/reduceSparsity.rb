# Reduce sparsity in a dataset by collapsing a specified number of arbitraty relations into other relations.
# Each collapsed relation will get merged into a unique other relation.

require_relative '../../lib/constants'
require_relative '../../lib/load'

require 'fileutils'

SEED = 4

DEFAULT_NUM_RELATIONS = 10
COLLAPSE_MAP_FILENAME = 'collapseMap.txt'

# Return: {relationToCollapse => relationToCollapseInto, ...}.
def loadCollapseMap(dataDir, numRemove)
   relations = Load.idMapping(File.join(dataDir, Constants::RAW_RELATION_MAPPING_FILENAME), false).keys()
   relations = relations.shuffle(random: Random.new(SEED))[0...(numRemove * 2)]

   # We need twice the number of relations so we can have a unique relations to collapse into.
   if (relations.size() < numRemove * 2)
      puts "ERROR: Not enough relations to collapse. Required at least #{numRemove * 2} relations, found #{relations.size()}"
      exit(3)
   end

   # Collapse source into target.
   collapseMap = {}
   relations.each_slice(2){|source, target|
      collapseMap[source] = target
   }

   return collapseMap
end

def parseArgs(args)
   if (args.size < 1 || args.size > 2 || args.map{|arg| arg.gsub('-', '').downcase()}.include?('help'))
      puts "USAGE: ruby #{$0} <data dir> [num relations to remove]"
      puts "   Output will be written in a new directory adjacent to |data dir|, called |data dir|_CR[N]"
      puts "   Where 'N' is the number of relations removed (zero padded with two zeros)."
      puts "   'CR' stands for 'Collapsed Relations'."
      puts "   |num relations to remove| defaults to #{DEFAULT_NUM_RELATIONS}."
      exit(1)
   end

   dataDir = args.shift()
   numRemove = DEFAULT_NUM_RELATIONS

   if (args.size() > 0)
      numRemove = args.shift.to_i()
   end

   if (numRemove < 1)
      puts "Number of relations to remove must be at least 1 (found #{numRemove})."
      exit(2)
   end

   return dataDir, numRemove
end

def collapseIdMap(dataDir, outDir, collapseMap)
   inPath = File.join(dataDir, Constants::RAW_RELATION_MAPPING_FILENAME)
   outPath = File.join(outDir, Constants::RAW_RELATION_MAPPING_FILENAME)

   # We need to assign new ids to the relations because holes are not allowed in the short ids (second value in the mapping row).
   relationIds = Load.idMapping(inPath, false).keys()
   relationIds.delete_if{|key| collapseMap.has_key?(key)}

   File.open(outPath, 'w'){|file|
      file.puts(relationIds.each_with_index().to_a().map{|id, index| "#{id}\t#{index}"}.join("\n"))
   }
end

def collapseTriples(dataDir, outDir, filename, collapseMap)
   inPath = File.join(dataDir, filename)
   outPath = File.join(outDir, filename)

   triples = Load.triples(inPath, false)

   triples.each_index{|i|
      if (collapseMap.has_key?(triples[i][Constants::RELATION]))
         triples[i][Constants::RELATION] = collapseMap[triples[i][Constants::RELATION]]
      end
   }

   File.open(outPath, 'w'){|file|
      file.puts(triples.map{|triple| triple.join("\t")}.join("\n"))
   }
end

def main(args)
   dataDir, numRemove = parseArgs(args)
   outDir = File.absolute_path(dataDir) + "_CR[#{"%03d" % numRemove}]"
   FileUtils.mkdir_p(outDir)

   puts "Reducing sparsity and creating new dataset in: #{outDir}"

   collapseMap = loadCollapseMap(dataDir, numRemove)

   # Make sure to copy over the entities unchanged.
   FileUtils.cp(File.join(dataDir, Constants::RAW_ENTITY_MAPPING_FILENAME), File.join(outDir, Constants::RAW_ENTITY_MAPPING_FILENAME))
   collapseIdMap(dataDir, outDir, collapseMap)

   Constants::RAW_TRIPLE_FILENAMES.each{|filename|
      collapseTriples(dataDir, outDir, filename, collapseMap)
   }

   # Finally, write out the collape mapping for reference.
   File.open(File.join(outDir, COLLAPSE_MAP_FILENAME), 'w'){|file|
      file.puts(collapseMap.to_a().map{|pair| pair.join("\t")}.join("\n"))
   }
end

if ($0 == __FILE__)
   main(ARGV)
end
