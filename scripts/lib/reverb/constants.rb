require_relative '../constants'

module Reverb
   DATA_DIR_NAME = 'reverb'
   DATA_PATH = File.join(Constants::DATA_PATH, Reverb::DATA_DIR_NAME)

   DATA_FILENAME = 'data.txt'

   FULL_DATA_FILENAME = 'reverb_clueweb_tuples-1.1.txt'
   FULL_DATA_PATH = File.join(Reverb::DATA_PATH, Reverb::FULL_DATA_FILENAME)

   # Compiled annotations written out to the RAW data directory.
   ANNOTATIONS_RAW_FILENAME = 'annotations.txt'

   ANNOTATIONS_DIR = 'annotations'
   # Relative to the base data dir (where DATA_FILENAME lives).
   ANNOTATIONS_FILE_RELPATH = File.join(Reverb::ANNOTATIONS_DIR, 'reverb-scored.txt')
end
