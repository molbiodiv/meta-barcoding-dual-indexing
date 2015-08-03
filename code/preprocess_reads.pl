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

preprocess_reads.pl

=head1 DESCRIPTION

This script wraps the preprocessing of multiple fastq files.
Input are multiple unjoined ITS2 read fastq files and output is a folder with joined and filtered fastq files.
The steps are join (with fastq-join) and filter (with usearch).
Requirements (tested versions): fastq-join (Version 1.01.759), usearch (Version v8.0.1477)
The readfiles have to be alternating first read and second read of the same sample.
With most naming schemes this should be automatically the case when using wildcards but be aware of this requirement if you face problems.
The file name of the first read file will be used for the joined and filtered files.

=head1 USAGE

  $ perl preprocess_reads.pl --out=<dir> [options] <sample1_1>.fq <sample1_2>.fq [<sample2_1>.fq <sample2_2>.fq ...]

=cut

=head1 OPTIONS

=over 25

=item --out=<dir>

Output directory will contain a joined and filtered subfolder with the respective reads

=cut

$options{'out=s'} = \( my $opt_out );

=item --utax-db=<file>

Path to the utax database file in fasta or udb format

=cut

$options{'utax-db=s'} = \( my $opt_utax_db );

=item --utax-taxtree=<file>

Path to the utax taxtree file

=cut

$options{'utax-taxtree=s'} = \( my $opt_utax_tt );

=item --utax-rawscore-cutoff=<int>

This value is passed to the counting script and takes the cuts the classification at the first level with rawscore below the cutoff
Default = 20

=cut

$options{'utax-rawscore-cutoff=i'} = \( my $opt_utax_rs_cutoff = 20 );

=item --fastq_truncqual=<int>

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

=item [--help] 		     
			     
show help		     
			     
=cut			     
			     
$options{'help|?'} = \(my $opt_help);
			     
			     
GetOptions(%options) or pod2usage(1);
			     
pod2usage(1) if($opt_help);  
pod2usage( -msg => 'missing output directory --out <dir> to set', -verbose => 0 ) unless ($opt_out);
pod2usage( -msg => 'fastq-join not in path and bin not specified --fastq-join-bin <path> to set', -verbose => 0 ) unless ($opt_fastq_join_bin);
pod2usage( -msg => 'usearch not in path and bin not specified --usearch-bin <path> to set', -verbose => 0 ) unless ($opt_usearch_bin);
pod2usage( -msg => 'utax-db is required to classify with utax --utax-db <path> to set', -verbose => 0 ) unless ($opt_utax_db);
pod2usage( -msg => 'utax-taxtree is required to classify with utax --utax-taxtree <path> to set', -verbose => 0 ) unless ($opt_utax_tt);
pod2usage( -msg => 'missing input files', -verbose => 0 ) unless (@ARGV > 1);
chomp($opt_fastq_join_bin);
chomp($opt_usearch_bin);

=head1 CODE		     
			     
=cut			     
			     
make_path($opt_out.'/joined', $opt_out.'/filtered', $opt_out.'/utax', $opt_out.'/count');

while(@ARGV>0){
    my $r1 = shift(@ARGV);
    my $r2 = shift(@ARGV);
    my @suffix = (".fq", ".fastq");
    my $base = basename($r1,@suffix);

    # Join with fastq-join
    my $cmd_fj = "$opt_fastq_join_bin $r1 $r2 -o $opt_out/joined/$base.%.fq\n";
    print $cmd_fj;
    my $ret_fj = qx($cmd_fj);
    die $ret_fj if $? >> 8;
    print $ret_fj;

    # Filter with usearch
    my $cmd_us = "$opt_usearch_bin -fastq_filter $opt_out/joined/$base.join.fq -fastq_truncqual $opt_fastq_truncqual -fastq_minlen 150 -fastqout $opt_out/filtered/$base.fq";
    print $cmd_us;
    my $ret_us = qx($cmd_us);
    die $ret_us if $? >> 8;
    print $ret_us;

    # Classify with utax
    my $cmd_ut = "$opt_usearch_bin -utax $opt_out/filtered/$base.fq -db $opt_utax_db -utax_rawscore -tt $opt_utax_tt -utaxout $opt_out/utax/$base.utax\n";
    print $cmd_ut;
    my $ret_ut = qx($cmd_ut);
    die $ret_ut if $? >> 8;
    print $ret_ut;

    # Count with custom script
    my $cmd_co = "perl $FindBin::RealBin/count_taxa_utax.pl --in $opt_out/utax/$base.utax --cutoff $opt_utax_rs_cutoff >$opt_out/count/$base.utax.count\n";
    print $cmd_co;
    my $ret_co = qx($cmd_co);
    die $ret_co if $? >> 8;
    print $ret_co;
}

# Aggregate counts with custom script
my $cmd_ag = "perl $FindBin::RealBin/aggregate_counts.pl $opt_out/count/*.utax.count >$opt_out/utax_aggregated_counts.tsv\n";
$cmd_ag .= "perl -i -pe 's/$opt_out\\/count\\///g;s/\\.utax\\.count//g' $opt_out/utax_aggregated_counts.tsv\n";
print $cmd_ag;
my $ret_ag = qx($cmd_ag);
die $ret_ag if $? >> 8;
print $ret_ag;

=head1 LIMITATIONS

If you encounter a bug, feel free to contact Markus Ankenbrand

=head1 AUTHORS

=over

=item * Markus Ankenbrand, markus.ankenbrand@uni-wuerzburg.de

=back
