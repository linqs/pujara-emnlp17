#!/bin/sh

if [ $# -ne 1 ]; then
   echo "USAGE: $0 <nell file>"
   exit 1
fi

echo "Nell has already been generated. Comment out these lines and rerun to regenerate Nell."
exit 0

NELL_FILE=$1

echo "Dropping old tables ..."
psql nell < sql/drop.sql

echo "Creating Tables ..."
psql nell < sql/create.sql

echo "Building Inserts ..."
ruby parseNell.rb "${NELL_FILE}"

echo "Inserting ..."
echo "   Entities ..."
psql nell <  sql/insert/entities.sql
echo "   Entity Categories ..."
psql nell <  sql/insert/categories.sql
echo "   Relations ..."
psql nell <  sql/insert/relations.sql
echo "   Triples ..."
psql nell <  sql/insert/triples.sql

# psql nell <  sql/insert/literals.sql

echo "Optimizing ..."
psql nell < sql/optimize.sql
