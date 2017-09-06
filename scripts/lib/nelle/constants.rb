module NellE
   # The relation to use for categories when we inject categorty triples for embeddings.
   CAT_RELATION_ID = 0

   # Make sure to leave out the evaluation gold truth.
   TRIPLE_FILENAMES = [
      'label-train-uniq-raw-rel.db.TRAIN',
      'NELL.08m.165.cesv.csv.CandRel_CBL.out',
      'NELL.08m.165.cesv.csv.CandRel_CPL.out',
      'NELL.08m.165.cesv.csv.CandRel_General.out',
      'NELL.08m.165.cesv.csv.CandRel.out',
      'NELL.08m.165.cesv.csv.CandRel_SEAL.out',
      'NELL.08m.165.cesv.csv.PattRel.out',
      'NELL.08m.165.esv.csv.PromRel_General.out',
      'seed.165.rel.uniq.out',
      'seed.165.rel.uniq_te.out',
      'testTargets.additional.Rel.out',
      'testTargets.additional.ValRel.out',
      'testTargets.shangpu.Rel.out',
      'testTargets.shangpu.ValRel.out',
      'trainTargets.Rel.out',
      'trainTargets.ValRel.out',
      'wlTargets.Rel.out'
   ]

   REPLACEMENT_TRIPLE_FILENAMES = [
      'label-train-uniq-raw-rel.db.TRAIN',
      'NELL.08m.165.cesv.csv.CandRel_CBL.out',
      'NELL.08m.165.cesv.csv.CandRel_CPL.out',
      'NELL.08m.165.cesv.csv.CandRel_General.out',
      'NELL.08m.165.cesv.csv.CandRel.out',
      'NELL.08m.165.cesv.csv.CandRel_SEAL.out',
      'NELL.08m.165.cesv.csv.PattRel.out',
      'NELL.08m.165.esv.csv.PromRel_General.out'
   ]

   # Gold truth that we will use for embedding evaluation.
   TEST_TRIPLE_FILENAMES = [
      'label-test-uniq-raw-rel.db.TRAIN'
   ]

   CATEGORY_FILENAMES = [
      'label-train-uniq-raw-cat.db.TRAIN',
      'NELL.08m.165.cesv.csv.CandCat_CBL.out',
      'NELL.08m.165.cesv.csv.CandCat_CMC.out',
      'NELL.08m.165.cesv.csv.CandCat_CPL.out',
      'NELL.08m.165.cesv.csv.CandCat_General.out',
      'NELL.08m.165.cesv.csv.CandCat_Morph.out',
      'NELL.08m.165.cesv.csv.CandCat.out',
      'NELL.08m.165.cesv.csv.CandCat_SEAL.out',
      'NELL.08m.165.cesv.csv.PattCat.out',
      'NELL.08m.165.esv.csv.PromCat_General.out',
      'seed.165.cat.uniq.out',
      'seed.165.cat.uniq_te.out',
      'testTargets.additional.Cat.out',
      'testTargets.additional.ValCat.out',
      'testTargets.shangpu.Cat.out',
      'trainTargets.Cat.out',
      'wlTargets.Cat.out',
      'testTargets.shangpu.ValCat.out',
      'trainTargets.ValCat.out'
   ]

   REPLACEMENT_CATEGORY_FILENAMES = [
      'label-train-uniq-raw-cat.db.TRAIN',
      'NELL.08m.165.cesv.csv.CandCat_CBL.out',
      'NELL.08m.165.cesv.csv.CandCat_CMC.out',
      'NELL.08m.165.cesv.csv.CandCat_CPL.out',
      'NELL.08m.165.cesv.csv.CandCat_General.out',
      'NELL.08m.165.cesv.csv.CandCat_Morph.out',
      'NELL.08m.165.cesv.csv.CandCat.out',
      'NELL.08m.165.cesv.csv.CandCat_SEAL.out',
      'NELL.08m.165.cesv.csv.PattCat.out',
      'NELL.08m.165.esv.csv.PromCat_General.out'
   ]

   # For a stricter set of experiments.

   STRICT_TRAINING_REL_FILENAMES = [
      'NELL.08m.165.cesv.csv.CandRel_CBL.out',
      'NELL.08m.165.cesv.csv.CandRel_CPL.out',
      'NELL.08m.165.cesv.csv.CandRel_General.out',
      'NELL.08m.165.cesv.csv.CandRel.out',
      'NELL.08m.165.cesv.csv.CandRel_SEAL.out',
      'NELL.08m.165.cesv.csv.PattRel.out',
      'NELL.08m.165.esv.csv.PromRel_General.out',
   ]

   STRICT_TRAINING_CAT_FILENAMES = [
      'NELL.08m.165.cesv.csv.CandCat_CBL.out',
      'NELL.08m.165.cesv.csv.CandCat_CMC.out',
      'NELL.08m.165.cesv.csv.CandCat_CPL.out',
      'NELL.08m.165.cesv.csv.CandCat_General.out',
      'NELL.08m.165.cesv.csv.CandCat_Morph.out',
      'NELL.08m.165.cesv.csv.CandCat.out',
      'NELL.08m.165.cesv.csv.CandCat_SEAL.out',
      'NELL.08m.165.cesv.csv.PattCat.out',
      'NELL.08m.165.esv.csv.PromCat_General.out',
   ]

   STRICT_TEST_REL_FILENAMES = [
      'label-test-uniq-raw-rel.db.TRAIN'
   ]

   STRICT_TEST_CAT_FILENAMES = [
      'label-test-uniq-raw-cat.db.TRAIN'
   ]
end
