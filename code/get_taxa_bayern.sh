#!/bin/bash

# Retrieve taxnames from bayernflora.de
perl -MLWP::Simple -e 'for ("A".."Z"){
    $content = get("http://daten.bayernflora.de/de/checklist_pflanzen.php?ab=$_&st=U&dt=");
    push @hits , $content=~/pcheck6\b[^>]*>([^<]*)/g;
}
print join("\n", @hits);' > bayern.species.txt

# Get taxids to the names from NCBI Taxonomy
# to get all taxids of the lineage use --form lng=1
# to exclude common names use --form nocommons=1
curl --form button="Save in file" --form fl=@bayern.species.txt\
 https://www.ncbi.nlm.nih.gov/Taxonomy/TaxIdentifier/tax_identifier.cgi\
 >bayern.species.taxids.tsv

# Assess assignment quality
# 1 - the incoming name is primary name for a taxon in the database
# 2 - the incoming name is a secondary name for a taxon in the database (it could be listed as a synonym, a misspelling, a common name, or several other nametypes)
# 3 - the incoming name is not found in the database
# + - the incoming name is duplicated in the database
echo "Assignment quality for species:"
cut -f1 bayern.species.taxids.tsv | sort | uniq -c
echo

# there are too many unasigned species so 
# remove subspecies and tribe information by cutting after the second word
# also remove lines that have a '&times' or 'x' as a word, as those are hybrids

cut -f1,2 -d" " bayern.species.txt | grep -v "&times" | grep -vw "x" | sort -u\
 >bayern.species.cleaned.txt
curl --form button="Save in file" --form fl=@bayern.species.cleaned.txt\
 https://www.ncbi.nlm.nih.gov/Taxonomy/TaxIdentifier/tax_identifier.cgi\
 >bayern.species.cleaned.taxids.tsv
echo "Assignment quality for species (cleaned):"
cut -f1 bayern.species.cleaned.taxids.tsv | sort | uniq -c
echo
cut -f7 bayern.species.cleaned.taxids.tsv | sort -gu | tail -n+2 >bayern.species.cleaned.taxids

# Repeat those steps on genus level 
# (using the lineage information for the species would be better due to non-unique genus names)
# But the lineage has arbitrary rank levels (some have subgenus, etc.) so not directly comparable
cut -f1 -d" " bayern.species.txt | sort -u >bayern.genus.txt
curl --form button="Save in file" --form fl=@bayern.genus.txt\
 https://www.ncbi.nlm.nih.gov/Taxonomy/TaxIdentifier/tax_identifier.cgi\
 >bayern.genus.taxids.tsv
echo "Assignment quality for genera:"
cut -f1 bayern.genus.taxids.tsv | sort | uniq -c
echo
cut -f7 bayern.genus.taxids.tsv | sort -gu | tail -n+2 >bayern.genus.taxids
