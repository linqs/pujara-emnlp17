module MathUtils
   def MathUtils.normalize(values, min = -1, max = -1)
      if (values.instance_of?(Array))
         return MathUtils.normalizeArray(values, min, max)
      elsif (values.instance_of?(Hash))
         return MathUtils.normalizeHash(values, min, max)
      else
         raise "Unknown type for energy normalization: #{values.class}"
      end
   end

   def MathUtils.normalizeArray(values, min = -1, max = -1)
      if (min == -1 || max == -1)
         min, max = values.minmax()
      end

      values.each_index{|i|
         values[i] = 1.0 - ((values[i] - min) / (max - min))
      }

      return values
   end

   def MathUtils.normalizeHash(values, min = -1, max = -1)
      if (min == -1 || max == -1)
         min, max = values.values().minmax()
      end

      values.keys().each{|key|
         values[key] = 1.0 - ((values[key] - min) / (max - min))
      }

      return values
   end

   def MathUtils.sigmoid(val)
      return 1.0 / (1 + Math.exp(-1.0 * val))
   end

   # Uniquely combine |a| and |b|.
   # Note that if |a| and |b| are ints, we must get an int back:
   #   1/2 * even * odd + int  (wlog)
   # = 1/2 * even + int
   # = int + int
   # https://en.wikipedia.org/wiki/Pairing_function#Cantor_pairing_function
   def MathUtils.cantorPairing(a, b, int = true)
      if (int)
         return (0.5 * (a + b) * (a + b + 1)).to_i() + b
      else
         return 0.5 * (a + b) * (a + b + 1) + b
      end
   end

   def MathUtils.sum(vals)
      return vals.inject(0, :+)
   end

   def MathUtils.mean(vals)
      if (vals.size() == 0)
         return 0
      end

      return MathUtils.sum(vals) / vals.size().to_f()
   end

   def MathUtils.median(vals)
      length = vals.size()
      sorted = vals.sort()

      return (sorted[(length - 1) / 2] + sorted[length / 2]) / 2.0
   end
end
