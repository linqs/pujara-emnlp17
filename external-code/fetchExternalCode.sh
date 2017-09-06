#!/bin/sh

git clone https://github.com/eriq-augustine/KB2E.git
git clone https://github.com/eriq-augustine/KnowledgeGraphIdentification.git
git clone https://github.com/eriq-augustine/STransE.git

mkdir -p HolE
cd HolE
git clone https://github.com/eriq-augustine/holographic-embeddings.git
git clone https://github.com/eriq-augustine/scikit-kge.git
