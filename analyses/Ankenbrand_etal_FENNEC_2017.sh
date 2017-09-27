#!/bin/bash

############ Dependencies
# usearch has to be obtained and installed manually, since it requires registration. Get it here:
# be sure to download usearch v8.1
# http://www.drive5.com/usearch/

# install fastq-join
git clone https://github.com/brwnj/fastq-join
cd fastq-join
make
cd ..

# install usearch python scripts
mkdir -p python_scripts
cd python_scripts
wget https://drive5.com/python/python_scripts.tar.gz
tar -xzf  python_scripts.tar.gz
cd ..
rm python_scripts.tar.gz

# install seqfilter
git clone https://github.com/BioInf-Wuerzburg/SeqFilter
cd SeqFilter
make
cd  ..

############ setup data/binary directories and log the analysis
# leave f/p/s as is, if you installed them like above.
# the path to usearch must probabably be adapted

script analysis_$(date +%Y%m%d).log
data=$(pwd)
u=/usr/local/bin/usearch
f=./fastq-join/fastq-join
p=./python_scripts
s=./SeqFilter/bin/SeqFilter

############ get reference data
# for direct hits in bavarian species
wget https://github.com/molbiodiv/meta-barcoding-dual-indexing/blob/master/data/viridiplantae_bavaria_2015.fa

# for hiercharical classification of those without hits
wget https://github.com/iimog/meta-barcoding-dual-indexing/raw/v1.1/training/utax/utax_trained.tar.gz
tar xzvf utax_trained.tar.gz
rm utax_trained.tar.gz
$u -makeudb_usearch utax_trained/viridiplantae_all_2014.utax.fa -output utax_trained/viridiplantae_all_2014.utax.udb

############ download raw data of the case study
wget http://www.ebi.ac.uk/ena/data/warehouse/filereport\?accession\=PRJEB8640\&result\=read_run\&fields\=study_accession,secondary_study_accession,sample_accession,secondary_sample_accession,experiment_accession,run_accession,tax_id,scientific_name,instrument_model,library_layout,fastq_ftp,fastq_galaxy,submitted_ftp,submitted_galaxy\&download\=txt -O reads.tsv

for i in $(cut -f13 reads.tsv | grep fastq.gz | perl -pe 's/;/\n/')
do
    wget $i
done
gunzip *.gz
# Fix typo - lowercase j in some samples:
rename 's/Poj/PoJ/' *.fastq

############ Analysis
#create directories
mkdir -p $data/raw
mkdir -p $data/joined

#store file suffixes as variables for forward and reverse reads
RF='_R1_001.fastq';
RR='_R2_001.fastq';

# get sample names
ls  $data/*$RF | sed "s/^.*\/\([a-zA-Z0-9_.-]*\)$/\1/g" | sed "s/$RF//" > samples.txt

# go through all samples and do...
for file in `cat samples.txt` ;
do
 	echo "Processing >>> $file <<<";

 	echo "..join ends";
 	# joining forward and reverse reads
	$f $data/$file$RF $data$file$RR -o $data/joined/$file.%.fq

	# keep R1 files for those that do not join, perhaps they are long enough and of good quality
	cat $data/joined/$file.join.fq $data/joined/$file.un1.fq > $data/joined.$file.fastq

	# move original files
	mv $data/$file$RF $data/raw/
	mv $data/$file$RR $data/raw/

	# filter reads with high expected error rate, that are too short or have Ns
 	echo "..filter";
 	$u -fastq_filter $data/joined.$file.fastq -fastq_maxee 1 -fastq_minlen 200 -fastq_maxns 1 -fastaout filter.$file.fasta
  rm $data/joined.$file.fastq

	# rename sequence names to match their original sample
 	echo "..parse";
	python $p/fasta_number.py filter.$file.fasta $file. > parsed1.$file.fasta
	cat parsed1.$file.fasta | sed "s/_L001//g" | sed "s/\./_/g " > parsed2.$file.fasta
  rm filter.$file.fasta
  rm parsed1.$file.fasta
done

# combine files of all samples to a single file to be searched
cat parsed2.* > all.fasta

# clean up temporary files
rm -r raw/ joined/ parsed* joined.* filter.*

# convert to a barcoding format readable by usearch
cat all.fasta | sed -e "s/^>\([a-zA-Z0-9-]*\)_\(.*$\)$/>\1_\2;barcodelabel=\1/" > all.bc.fasta

# find best direct hits for all filtered sequences with more than 97% identity
$u -usearch_global all.bc.fasta -db viridiplantae_bavaria_2015.fa -id 0.97 -uc output_BV3.uc -fastapairs output_BV3.fasta  -strand plus

# get names and sequences of those without hits, classify them herarchical with utax afterwards
grep "^N[[:space:]]" output_BV3.uc | cut -f 9 > output_BV3.nohit
$s all.bc.fasta --ids output_BV3.nohit --out all.bc.BV3.nohit.fasta
$u -utax all.bc.BV3.nohit.fasta -db utax_trained/viridiplantae_all_2014.utax.udb -utax_rawscore -tt utax_trained/viridiplantae_all_2014.utax.tax -utaxout all.bc.BV3.nohit.utax

# create a pseudo.uc file of the hierarchical classification and filter low quality assignments
perl -ne '
($id, $tax, $sign)=split(/\t/);
@tmp=split(/,/, $tax);
@tax=();
foreach $t (@tmp){
    $t=~s/__/:/g;
    $t=~s/ +/_/g;
    $t=~s/\(([\d.]+)\)//;
    if($1 < 27){last;}
    push @tax, $t;
    $t=~/_(\d+)$/;
    $taxid=$1;
}
next if(@tax == 0);
print "H".("\t"x8)."$id\tt$taxid;tax=".join(",", @tax).";\n"
' all.bc.BV3.nohit.utax | sed "s/,s:.*$//g" >all.bc.BV3.nohit.pseudo.uc

#combine direct hit .uc and the hierarchically classified pseudo.uc
cat output_BV3.uc all.bc.BV3.nohit.pseudo.uc >combined.uc

#convert output format to TAX/OTU-Table (community matrix including taxonomic lineages)
python $p/uc2otutab.py  combined.uc > combined.txt

#split TAX-OTU-Table to OTU and TAX Table respectively
cat combined.txt | sed "s/;tax=.*;//g;s/:/_/g" > combined.otu
cat combined.txt | cut -f 1 | sed "s/;tax=/,/g;s/:/_/g" | sed "s/;//" | sed "s/OTUId/,Kingdom,Phylum,Class,Order,Family,Genus,Species/" > combined.tax
rev combined.tax | cut -f1 -d"," | rev | tail -n+2 | perl -pe 's/_(\d+)$/_$1\t$1/' | sort -u >combined.tax_map
cut -f2 combined.tax_map > combined.taxids
