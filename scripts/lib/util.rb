require 'open3'

module Util
   def Util.debugPuts(text, debug)
      if (debug)
         puts(text)
      end
   end

   def Util.run(command, outFile=nil, errFile=nil)
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
end
