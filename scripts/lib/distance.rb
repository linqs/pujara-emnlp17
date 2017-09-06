module Distance
   L1_ID_INT = 0
   L2_ID_INT = 1

   L1_ID_STRING = 'L1'
   L2_ID_STRING = 'L2'

   # This is actual the l1 distance between (head + relation) and tail
   def Distance.l1(head, tail, relation)
      return (tail - (head + relation)).abs()
   end

   # This is actual the l2 distance between (head + relation) and tail
   def Distance.l2(head, tail, relation)
      return (tail - (head + relation)) ** 2
   end
end
