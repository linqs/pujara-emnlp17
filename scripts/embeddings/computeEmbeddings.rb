require_relative '../lib/constants'
require_relative '../lib/distance'
require_relative '../lib/embedding/constants'

require 'fileutils'
require 'open3'

SEED = 4

COMMAND_TYPE_TRAIN = 'train'
COMMAND_TYPE_EVAL = 'eval'

DEFAULT_EMETHOD = 'TransE'
DEFAULT_DATA_DIR = Constants::RAW_FB15K_PATH
DEFAULT_SIZE = 100
DEFAULT_MARGIN = 1
DEFAULT_METHOD = Embedding::METHOD_UNIFORM
DEFAULT_RATE = 0.01
DEFAULT_BATCHES = 100
DEFAULT_EPOCHS = 1000
DEFAULT_DISTANCE = Distance::L1_ID_INT

# Experiments should looks something like:
# {
#    'emethod' => 'TransE',
#    'data' => '/path/to/dataset',
#    'args' => {
#       'size' => embeddingSize,
#       'margin' => 1,
#       'method' => method,
#       'rate' => 0.01,
#       'batches' => 100,
#       'epochs' => 1000,
#       'distance' => distance
#    }
# }

def getId(experiment)
   method = experiment['emethod']
   data = File.basename(experiment['data'])

   # Make a copy of the args, since we may need to override some for id purposes.
   args = Hash.new().merge(experiment['args'])

   if (args.include?('seeddatadir'))
      args['seeddatadir'] = File.basename(args['seeddatadir'])
   end

   argString = args.keys.map{|key| "#{key}:#{args[key]}"}.join(',')
   return "#{method}_#{data}_[#{argString}]"
end

# Get the dir to put the results.
def getOutputDir(experiment)
   return File.absolute_path(File.join(Constants::EMBEDDINGS_PATH, getId(experiment)))
end

# |type| should be COMMAND_TYPE_TRAIN or COMMAND_TYPE_EVAL
def getCommand(experiment, type)
   binName = File.join('.', 'bin', "#{type}#{experiment['emethod']}")
   outputDir = getOutputDir(experiment)

   args = [
      "--datadir '#{experiment['data']}'",
      "--outdir '#{outputDir}'",
      "--seed #{SEED}"
   ]

   experiment['args'].each_pair{|key, value|
      args << "--#{key} '#{value}'"
   }

   return "#{binName} #{args.join(' ')}"
end

def train(experiment)
   outputDir = getOutputDir(experiment)

   stdoutFile = File.absolute_path(File.join(outputDir, 'train.txt'))
   stderrFile = File.absolute_path(File.join(outputDir, 'train.err'))

   puts "Training: #{getId(experiment)}"

   run("mkdir -p '#{outputDir}'")
   run("cd '#{Embedding::CODE_PATH}' && #{getCommand(experiment, COMMAND_TYPE_TRAIN)}", stdoutFile, stderrFile)
end

def evaluate(experiment)
   outputDir = getOutputDir(experiment)

   stdoutFile = File.absolute_path(File.join(outputDir, 'eval.txt'))
   stderrFile = File.absolute_path(File.join(outputDir, 'eval.err'))

   puts "Evaluating: #{getId(experiment)}"

   run("cd '#{Embedding::CODE_PATH}' && #{getCommand(experiment, COMMAND_TYPE_EVAL)}", stdoutFile, stderrFile)
end

# Do any global setup like copying data.
def globalSetup()
   # Build
   run("cd '#{Embedding::CODE_PATH}' && make clean && make")
end

def run(command, outFile=nil, errFile=nil)
   stdout, stderr, status = Open3.capture3(command)

   if (outFile != nil)
      File.open(outFile, 'w'){|file|
         file.puts(stdout)
      }
   end
   
   if (errFile != nil)
      File.open(errFile, 'w'){|file|
         file.puts(stderr)
      }
   end

   if (status.exitstatus() != 0)
      raise "Failed to run command: [#{command}]. Exited with status: #{status}" + 
            "\n--- Stdout ---\n#{stdout}" +
            "\n--- Stderr ---\n#{stderr}"
   end
end

def runExperiment(experiment, runGlobalSetup = true)
   if (!File.exists?(experiment['data']))
      raise "Missing dataset: [#{experiment['data']}]."
   end

   outputDir = getOutputDir(experiment)
   if (File.exists?(outputDir))
      return
   end

   if (runGlobalSetup)
      globalSetup()
   end

   train(experiment)
   evaluate(experiment)
end

def printUsage()
   puts "USAGE: ruby #{$0} [options]"
   puts "Options:"
   puts "   --emethod VAL  - Embedding method. Usually 'TransE' or 'TransH' Default: [#{DEFAULT_EMETHOD}]"
   puts "   --data VAL     - Dataset directory. Default: [#{DEFAULT_DATA_DIR}]"
   puts "   --size VAL     - Embedding size. Default: [#{DEFAULT_SIZE}]"
   puts "   --margin VAL   - Margin. Default: [#{DEFAULT_MARGIN}]"
   puts "   --method VAL   - Method. 0 = uniform, 1 = bernoulli. Default: [#{DEFAULT_METHOD}]"
   puts "   --rate VAL     - Learning rate. Default: [#{DEFAULT_RATE}]"
   puts "   --batches VAL  - Batch size. Default: [#{DEFAULT_BATCHES}]"
   puts "   --epochs VAL   - Number of epochs. Default: [#{DEFAULT_EPOCHS}]"
   puts "   --distance VAL - Distance method. 0 = L1, 1 = L2. Default: [#{DEFAULT_DISTANCE}]"
end

def parseArgs(args)
   if (args.size() % 2 == 1)
      puts "Found an odd number of args, need an even number."
      printUsage()
      exit(1)
   end

   if (args.map{|arg| arg.strip().gsub('-', '').downcase()}.include?('help'))
      printUsage()
      exit(2)
   end

   experiment = {
      'emethod' => DEFAULT_EMETHOD,
      'data' => DEFAULT_DATA_DIR,
      'args' => {
         'size' => DEFAULT_SIZE,
         'margin' => DEFAULT_MARGIN,
         'method' => DEFAULT_METHOD,
         'rate' => DEFAULT_RATE,
         'batches' => DEFAULT_BATCHES,
         'epochs' => DEFAULT_EPOCHS,
         'distance' => DEFAULT_DISTANCE
      }
   }

   args.each_slice(2){|pair|
      flag = pair[0].sub(/^-+/, '')
      value = pair[1]

      if (['emethod', 'data'].include?(flag))
         experiment[flag] = value
      elsif (['size', 'margin', 'method', 'rate', 'batches', 'epochs', 'distance'].include?(flag))
         experiment['args'][flag] = value
      end
   }

   experiment['data'] = File.absolute_path(experiment['data'])

   return experiment
end

def main(args)
   runExperiment(parseArgs(args))
end

if (__FILE__ == $0)
   main(ARGV)
end
