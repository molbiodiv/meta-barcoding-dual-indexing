#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::RealBin/lib";
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use Getopt::Long;
use Pod::Usage;
use File::Path qw(make_path);
use File::Basename;

my %options = ();

=head1 NAME 

classify_reads.pl

=head1 DESCRIPTION

This script wraps the preprocessing and classification of multiple fastq files.
Input are multiple unjoined ITS2 read fastq files and output is a folder with a tax_table and otu_table for import into phyloseq.
The intermediate files are also preserved.
The steps are join (with fastq-join), filter (with usearch), classify (with usearch or RDPclassifier), count, aggregate and convert.
Requirements (tested versions): fastq-join (Version 1.01.759), usearch (Version v8.0.1477)[, RDPclassifier (Version 2.10.2)]
The readfiles have to be ordered (alternating first read file and second read file of the same sample).
With most naming schemes this should be automatically the case when using wildcards but be aware of this requirement if you face problems.
The file name of the first read file will be used for the joined and filtered files.

=head1 USAGE

  $ perl classify_reads.pl --out=<dir> [options] <sample1_1>.fq <sample1_2>.fq [<sample2_1>.fq <sample2_2>.fq ...]

=cut

=head1 OPTIONS

=over 25

=item --out=<dir>

Output directory will contain a joined and filtered subfolder with the respective reads

=cut

$options{'out=s'} = \( my $opt_out );

=item [--[no]utax]

Should utax be used for classification (default: yes)
If --noutax is used to disable utax and --rdp is not set no classification will be used (only preprocessing: joining, filtering)

=cut

$options{'utax!'} = \( my $opt_utax = 1 );

=item [--[no]rdp]

Should RDPclassifier be used for classification (default: no)
If --rdp is set and utax is not disabled via --noutax both tools are used for classification.

=cut

$options{'rdp!'} = \( my $opt_rdp = 0 );

=item --utax-db=<file>

Path to the utax database file in fasta or udb format (required if not --noutax)

=cut

$options{'utax-db=s'} = \( my $opt_utax_db );

=item --utax-taxtree=<file>

Path to the utax taxtree file (required if not --noutax)

=cut

$options{'utax-taxtree=s'} = \( my $opt_utax_tt );

=item [--utax-rawscore-cutoff=<int>]

This value is passed to the counting script and cuts the classification at the first level with rawscore below the cutoff
Default = 20

=cut

$options{'utax-rawscore-cutoff=i'} = \( my $opt_utax_rs_cutoff = 20 );

=item [--rdp-bootstrap-cutoff=<float>]

This value is passed to the counting script and cuts the classification at the first level with bootstrap below the cutoff
Default = 0.85

=cut

$options{'rdp-bootstrap-cutoff=f'} = \( my $opt_rdp_bootstrap_cutoff = 0.85 );

=item [--fastq_truncqual=<int>]

This value is passed to usearch as -fastq_truncqual (a value of 19 means Q20 filtering)
Default = 19

=cut

$options{'fastq_truncqual=i'} = \( my $opt_fastq_truncqual = 19 );

=item [--fastq-join-bin=<FILE>] 

Path to fastq-join binary file. Default tries if fastq-join is in PATH;

=cut

$options{'fastq-join-bin=s'} = \( my $opt_fastq_join_bin = `which fastq-join 2>/dev/null` );

=item [--usearch-bin=<FILE>] 

Path to usearch binary file. Default tries if usearch is in PATH;
If you have multiple copies of usearch please make sure that usearch version 8 is used.

=cut

$options{'usearch-bin=s'} = \( my $opt_usearch_bin = `which usearch 2>/dev/null` );

=item [--rdp-jar=<FILE>] 

Path to RDPclassifier jar file. (Required if --rdp is used)

=cut

$options{'rdp-jar=s'} = \( my $opt_rdp_jar );

=item [--rdp-train-propfile=<FILE>] 

Path to RDPclassifier train propfile. (Required if --rdp is used)

=cut

$options{'rdp-train-propfile=s'} = \( my $opt_rdp_train_propfile );

=item [--help] 		     
			     
show help		     
			     
=cut			     
			     
$options{'help|?'} = \(my $opt_help);
			     
			     
GetOptions(%options) or pod2usage(1);
			     
pod2usage(1) if($opt_help);  
pod2usage( -msg => 'missing output directory --out <dir> to set', -verbose => 0 ) unless ($opt_out);
pod2usage( -msg => 'fastq-join not in path and bin not specified --fastq-join-bin <path> to set', -verbose => 0 ) unless ($opt_fastq_join_bin);
pod2usage( -msg => 'usearch not in path and bin not specified --usearch-bin <path> to set', -verbose => 0 ) unless ($opt_usearch_bin);
pod2usage( -msg => 'utax-db is required to classify with utax --utax-db <path> to set', -verbose => 0 ) unless ($opt_utax_db || !$opt_utax);
pod2usage( -msg => 'utax-taxtree is required to classify with utax --utax-taxtree <path> to set', -verbose => 0 ) unless ($opt_utax_tt || !$opt_utax);
pod2usage( -msg => 'rdp-jar is required to classify with RDPclassifier --rdp-jar <path> to set', -verbose => 0 ) unless ($opt_rdp_jar || !$opt_rdp);
pod2usage( -msg => 'rdp-train-propfile is required to classify with RDPclassifier --rdp-train-propfile <path> to set', -verbose => 0 ) unless ($opt_rdp_train_propfile || !$opt_rdp);
pod2usage( -msg => 'missing input files', -verbose => 0 ) unless (@ARGV > 1);
chomp($opt_fastq_join_bin);
chomp($opt_usearch_bin);

=head1 CODE		     
			     
=cut			     

# Create output dir structure
make_path($opt_out.'/joined', $opt_out.'/filtered');
make_path($opt_out.'/utax') if($opt_utax);
make_path($opt_out.'/rdp') if($opt_rdp);
make_path($opt_out.'/count') if($opt_utax || $opt_rdp);
open (LOG, ">$opt_out/log") or die "$!";;

while(@ARGV>0){
    my $r1 = shift(@ARGV);
    my $r2 = shift(@ARGV);
    my @suffix = (".fq", ".fastq");
    my $base = basename($r1,@suffix);

    # Join with fastq-join
    my $cmd_fj = "$opt_fastq_join_bin $r1 $r2 -o $opt_out/joined/$base.%.fq\n";
    print_and_execute($cmd_fj);

    # Filter with usearch
    my $cmd_us = "$opt_usearch_bin -fastq_filter $opt_out/joined/$base.join.fq -fastq_truncqual $opt_fastq_truncqual -fastq_minlen 150 -fastqout $opt_out/filtered/$base.fq";
    print_and_execute($cmd_us);

    if($opt_utax){
	# Classify with utax
	my $cmd_ut = "$opt_usearch_bin -utax $opt_out/filtered/$base.fq -db $opt_utax_db -utax_rawscore -tt $opt_utax_tt -utaxout $opt_out/utax/$base.utax\n";
	print_and_execute($cmd_ut);
	
	# Count with custom script
	my $cmd_co = "perl $FindBin::RealBin/count_taxa_utax.pl --in $opt_out/utax/$base.utax --cutoff $opt_utax_rs_cutoff >$opt_out/count/$base.utax.count\n";
	print_and_execute($cmd_co);
    }

    if($opt_rdp){
	# Classify with rdp
	my $cmd_rd = "java -jar $opt_rdp_jar classify --train_propfile $opt_rdp_train_propfile --outputFile $opt_out/rdp/$base.rdp $opt_out/filtered/$base.fq\n";
	print_and_execute($cmd_rd);
	
	# Count with custom script
	my $cmd_cr = "perl $FindBin::RealBin/count_taxa_rdp.pl --in $opt_out/rdp/$base.rdp --cutoff $opt_rdp_bootstrap_cutoff >$opt_out/count/$base.rdp.count\n";
	print_and_execute($cmd_cr);
    }
}

aggregate_and_convert("utax") if($opt_utax);
aggregate_and_convert("rdp") if($opt_rdp);

close LOG or die "$!";

=head2 print_and_execute

This functions takes a string as argument which is executed using the system shell.
The command and its return value are printed on STDOUT and to the log file.
If an error occurs the script dies.

=cut

sub print_and_execute{
    my $cmd = $_[0];
    print $cmd;
    print LOG $cmd;
    my $ret = qx($cmd);
    print LOG $ret;
    die $ret if $? >> 8;
    print $ret;
    return $ret;
}

=head2 aggregate_and_convert

This functions takes a string as argument which is either 'rdp' or 'utax'.
The counts of the respective type will be aggregated and converted into phyloseq compatible files.

=cut

sub aggregate_and_convert{
    my $type = $_[0];
    # Aggregate counts with custom script
    my $cmd_ag = "perl $FindBin::RealBin/aggregate_counts.pl $opt_out/count/*.$type".".count >$opt_out/$type"."_aggregated_counts.tsv\n";
    $cmd_ag .= "perl -i -pe 's/$opt_out\\/count\\///g;s/\\.$type\\.count//g' $opt_out/$type"."_aggregated_counts.tsv\n";
    print_and_execute($cmd_ag);

    # Split aggregated counts into tax_table and otu_table:
    my $cmd_sp = "perl -pe 's/^([^\\t]+)_(\\d+)\\t/TID_\$2\\t/' $opt_out/$type"."_aggregated_counts.tsv >$opt_out/$type"."_otu_table\n";
    $cmd_sp .= "perl -ne 'BEGIN{print \"\#OTU\\tkingdom\\tphylum\\tclass\\torder\\tfamily\\tgenus\\tspecies\\n\"}if(/^([^\\t]+)_(\\d+)\\t/){print \"TID_\$2\\t\"; \$tax=\$1; \$tax=~s/_\\d+,/\\t/g; \$tax=~s/__sub__/__/g; \$tax=~s/__super__/__/g; \$tax=~s/\\t\\w__/\\t/g; \$tax=~s/^\\w__//; \$tax=~s/[^\\w\\d\\s.-]/_/g; print \"\$tax\\n\"; }' $opt_out/$type"."_aggregated_counts.tsv >$opt_out/$type"."_tax_table\n";
    $cmd_sp .= "head -n1 $opt_out/$type"."_aggregated_counts.tsv | perl -pe '$c++;s/\\t/#Sample\\n/;s/\\t/\\t\$c\n/g;s/^#Sample/#Sample\\tNumber;' >$opt_out/mapfile.tsv\n";
    print_and_execute($cmd_sp);
}

=head1 LIMITATIONS

If you encounter a bug, feel free to contact Markus Ankenbrand

=head1 AUTHORS

=over

=item * Markus Ankenbrand, markus.ankenbrand@uni-wuerzburg.de

=back
