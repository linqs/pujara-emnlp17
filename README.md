# pujara-emnlp17

This repository contains the code necessary to run the experiments from the "Sparsity and Noise: Where Knowledge Graph Embeddings Fall Short"
paper published at EMNLP 2017.

All code snippets will assume that you are in the root directory of this repository (adjacent to this README.md file).

## Requirements

This code requires 
   - ruby 2.2
      - Required gems: `thread`
   - gcc 7.1
   - python 3
      - Required packages: `numpy` and `scikit-learn`

## Directory Structure

This repository is organized with the following directories:
```
data
├── embeddings
├── nelle
└── raw
external-code
scripts
paper
```

### data/raw
This directory contains datasets that are formatted for use in all the embedding methods.

### data/embeddings
This directory contains computed embedding files as well as output from the embedding process.

### data/nelle
Contains source data for Nell 165.

### external-code
A place where other repositories are fetched

### scripts
All the code to parse/clean data, run experiments, and collect results.

### paper
The paper that this code supports.

## Fetching Data

Raw data is available at: https://linqs-data.soe.ucsc.edu/public/pujara-emnlp17/data-raw.tar.gz  
The compressed data is 1.1 GB while the uncompressed data is 5.9 GB.

Raw data **with** embeddings is available at: https://linqs-data.soe.ucsc.edu/public/pujara-emnlp17/data-full.tar.gz  
The compressed data is 3.3 GB while the uncompressed data is 14 GB.

Since embeddings make take days to generate, it is usually preferred to spend the extra time downloading the data instead of generating the embeddings.

### Data Directory Naming
All data directories are named for the method that generated them.

#### data/raw
Some pertinent data is named as follows:
   - `FB15k_CORRUPT[N]`
      - FB15k with `N%` of the triples corrupted.
      - Used in experiment 4.3.

   - `FB15k_RR[N]`
      - FB15k with `~N` triples removed while preserving relational density.
      - Used in experiment 4.2 (the stable data).

   - `FB15k_TR[N]`
      - FB15k with `N` triples removed without preserving relational density.
      - Used in experiments 4.2 and 4.3 (the sparse data).

   - `FB15k_TRADEOFF[I,R,N]`
      - FB15k with `I` triples initilly removed without preserving order, with `R` triples replaced with `N%` noise.
      - Used in experiment 4.4.

#### data/embeddings
Embedding directories are always named as follows:
```
<embedding method>_<data identifier>_[<embedding parameters>]
```
For example, the `TransE_FB15k_CORRUPT[050]_[size:100,margin:1,method:1,rate:0.001,batches:100,epochs:1000,distance:0]` embedding directory has the following properties:
   - Generated with the `TransE` embedding method.
      - Using the following parameters: `size:100,margin:1,method:1,rate:0.001,batches:100,epochs:1000,distance:0`
   - Generated from the `FB15k_CORRUPT[050]` data (FB15k with 50% corrupted).

## Prepping Raw Data

All processed data is provided as part of either the `raw` or `full` archives.
However, if you wish to generate your own data, you may do so with the following scripts:
   - Corrupt Data: `scripts/data-processing/misc/corruptDataset.rb`
   - Remove Relations (stable): `scripts/data-processing/misc/removeRelations.rb`
   - Remove Triples (sparse): `scripts/data-processing/misc/increaseSparsity.rb`
   - Sparsity vs Noise Trade-off: `scripts/data-processing/misc/sparsityNoiseTradeoff.rb`

Each script may be run with no parameters or with with the `-h` flag to get a help prompt.

## Generate Embeddings

All experiments first require embeddings to be generated.
This can be a very time consuming process, potentially taking days to run.
Each script picks up data from `data/raw` and places the result in `data/embedding`.
If the target directory already exists, then that embedding instance will be skipped.
Each of these scripts will utilize all but one code on the host machine.

Before running these experiments, you must make sure you have the appropriate external code.
This can be achieved be running the `fetchExternalCode.sh` script in the `external-code` directory:
```
./external-code/fetchExternalCode.sh
```

If you want to generate the HolE embeddings, you will be required to perform the additional steps of installing a modified `scikit-kg`:
```
cd external-code/HolE/scikit-kge
pip3 install scikit-learn numpy scipy nose  # Or however you install python packages.
python3 setup.py install  # Maybe use: --user
```

Sparsity and Noise Experiments:
   - `scripts/experiments/sparsity/computeSparsityEmbeddings.rb`
   - `scripts/embeddings/computeSTransE.rb`
   - `scripts/embeddings/computeHolE.rb`

Trade-off Experiments:
   - `scripts/experiments/sparsity/computeSparsityNoiseEmbeddings.rb`

NellE Experiments:
   - `scripts/experiments/sparsity/computeNellEmbeddings.rb`

## Collecting Results

Generating embeddings will also evaluate each embedding instance.
There are scripts to parse embedding output directories (data/embedding) and get the results.
Each script will output tab-separated data to stdout.

TransE and TransH can be parsed using: scripts/evaluation/compile/embeddingEval.rb
```
ruby scripts/evaluation/compile/embeddingEval.rb data/embeddings/Trans*
```

HolE: scripts/evaluation/compile/holeEval.rb
```
ruby scripts/evaluation/compile/holeEval.rb data/embeddings/HolE_*
```

STransE: scripts/evaluation/compile/stranseEval.rb
```
ruby scripts/evaluation/compile/stranseEval.rb data/embeddings/STransE_*
```

AUPRC and F1 Nell results from table 2 can be obtained using the `scripts/experiments/sparsity/aucNellE.rb` script.
It accepts two parameters" the first being the path to the raw data directory and the second being the embedding directory.
The following snippet compiles the data for each of the four different embedding methods:
```
ruby scripts/experiments/sparsity/aucNellE.rb 'data/nelle/165' 'data/embeddings/HolE_NELLE_00000_INCLUDE_CATS_201704061535_[lr:0.1,margin:0.2,me:500,nb:100,ncomp:150,test-all:50]'
ruby scripts/experiments/sparsity/aucNellE.rb 'data/nelle/165' 'data/embeddings/STransE_NELLE_00000_INCLUDE_CATS_201704061535_[init:0,l1:1,lrate:0.0001,margin:1,model:1,size:100]'
ruby scripts/experiments/sparsity/aucNellE.rb 'data/nelle/165' 'data/embeddings/TransE_NELLE_00000_INCLUDE_CATS_201704061535_[size:100,margin:1,method:1,rate:0.001,batches:100,epochs:1000,distance:0]'
ruby scripts/experiments/sparsity/aucNellE.rb 'data/nelle/165' 'data/embeddings/TransH_NELLE_00000_INCLUDE_CATS_201704061535_[size:100,margin:1,method:1,rate:0.005,batches:100,epochs:1000,distance:0]'
```
