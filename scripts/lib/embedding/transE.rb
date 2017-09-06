require_relative '../distance'

module TransE
   ID_STRING = 'TransE'

   MAX_ENERGY_THRESHOLD_L1 = 10.0
   MAX_ENERGY_THRESHOLD_L2 = 1.0

   # Remember, each param is an embedding vector.
   def TransE.tripleEnergy(distanceType, head, tail, relation)
      energy = 0

      head.each_index{|i|
         if (distanceType == Distance::L1_ID_STRING)
            energy += Distance.l1(head[i], tail[i], relation[i])
         elsif (distanceType == Distance::L2_ID_STRING)
            energy += Distance.l2(head[i], tail[i], relation[i])
         else
            raise("Unknown distance type: [#{distanceType}]")
         end
      }

      ok = true
      if (distanceType == Distance::L1_ID_STRING && energy > MAX_ENERGY_THRESHOLD_L1)
         ok = false
      elsif (distanceType == Distance::L2_ID_STRING && energy > MAX_ENERGY_THRESHOLD_L2)
         ok = false
      end

      return ok, energy
   end
end
