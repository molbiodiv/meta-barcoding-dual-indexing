#!/bin/bash

for i in $(seq 1 56)
do  
    # Excludes 3, 7, 14, 43 and 52.
    if [ "$i" -eq 3 ] || [ "$i" -eq 7 ] || [ "$i" -eq 14 ] || [ "$i" -eq 43 ] || [ "$i" -eq 52 ]
    then
        continue      # Those fips are not used
    fi
    i=$(printf "%02d" $i)
    curl 'http://bison.usgs.ornl.gov/solrstaging/occurrences/select?q=computedStateFips:(%22'$i'%22)%20AND%20hierarchy_homonym_string:(*-202422-*)&facet.mincount=1&rows=0&facet=true&facet.missing=true&facet.limit=-1&wt=json&indent=true&facet.field=ITISscientificName' | jq ".facet_counts | .facet_fields | .ITISscientificName | .[]" | perl -ne 'chomp; s/"//g;print "$_\t".<>' >$i.checklist
    cut -f1 $i.checklist | cut -f1,2 -s -d" " | sort -u >$i.species
    cut -f1 -d" " $i.species | sort -u >$i.genus
    curl --form button="Save in file" --form fl=@$i.species\
     http://www.ncbi.nlm.nih.gov/Taxonomy/TaxIdentifier/tax_identifier.cgi >$i.species.tsv
    curl --form button="Save in file" --form fl=@$i.genus\
     http://www.ncbi.nlm.nih.gov/Taxonomy/TaxIdentifier/tax_identifier.cgi >$i.genus.tsv
    cut -f7 $i.species.tsv | sort -u | grep -P "\d" >$i.species.taxids
    cut -f7 $i.genus.tsv | sort -u | grep -P "\d" >$i.genus.taxids
done
