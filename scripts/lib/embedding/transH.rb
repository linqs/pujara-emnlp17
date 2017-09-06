module TransH
   ID_STRING = 'TransH'

   MAX_ENERGY_THRESHOLD = 10.0

   # Remember, each param is an embedding vector.
   def TransH.tripleEnergy(head, tail, relation, weight)
      headSum = 0.0
      tailSum = 0.0

      head.each_index{|i|
         headSum += head[i] * weight[i]
         tailSum += tail[i] * weight[i]
      }

      energy = 0.0
      head.each_index{|i|
         energy += ((tail[i] - tailSum * weight[i]) - (head[i] - headSum * weight[i]) - relation[i]).abs()
      }

      ok = true
      if (energy > MAX_ENERGY_THRESHOLD)
         ok = false
      end

      return ok, energy
   end
end
