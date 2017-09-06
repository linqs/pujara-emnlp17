class Histogram
   @@OFFSET = 0.0000001
   @@DEFAULT_NUM_BUCKETS = 10

   def initialize(min, max, numBuckets = @@DEFAULT_NUM_BUCKETS)
      @min = min
      @max = max
      @buckets = Array.new(numBuckets, 0)
      @count = 0
   end

   def addData(data)
      if (!data.kind_of?(Numeric) && !data.kind_of?(Array))
         raise "Expecting histogram data to be either numeric of Array of numerics. Got #{data.class}."
      end

      if (data.kind_of?(Numeric))
         addToBucket(data)
      end

      data.each_index{|i|
         if (!data[i].kind_of?(Numeric))
            raise "Expecting histogram data in Array to be numeric. Got: #{data[i].class} on index #{i}."
         end

         addToBucket(data[i])
      }
   end

   def <<(data)
      addData(data)
   end

   def to_s()
      rtn = []

      rtn << "Count: #{@count}"
      rtn << "Min: #{@min}, Max: #{@max}"

      step = (@max - @min) / @buckets.size().to_f()
      @buckets.each_index{|i|
         rtn << "[#{"%07.4f" % (@min + step * i)}, #{"%07.4f" % (@min + step * (i + 1))}): #{@buckets[i]}"
      }

      return rtn.join("\n")
   end

   def addToBucket(value)
      @count += 1

      value = (value - @min).to_f() / (@max - @min)

      # Offset is for max value.
      bucket = (value * @buckets.size() - @@OFFSET).to_i()
      @buckets[bucket] += 1
   end

   # Creates a histogram and returns it as a string.
   def self.generate(data, numBuckets = @@DEFAULT_NUM_BUCKETS)
      min, max = data.minmax()

      hist = Histogram.new(min, max, numBuckets)
      hist << data
      return hist.to_s()
   end

   private :addToBucket
end
