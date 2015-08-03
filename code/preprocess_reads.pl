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

=item --fastq_truncqual=<int>

This value is passed to usearch as -fastq_truncqual (a value of 19 means Q20 filtering)
Default = 19

=cut

$options{'fastq_truncqual=i'} = \( my $opt_fastq_truncqual = 19 );


=item [--help] 		     
			     
show help		     
			     
=cut			     
			     
$options{'help|?'} = \(my $opt_help);
			     
			     
GetOptions(%options) or pod2usage(1);
			     
pod2usage(1) if($opt_help);  
pod2usage( -msg => 'missing output directory --out <dir> to set', -verbose => 0 ) unless ($opt_out);
pod2usage( -msg => 'missing input files', -verbose => 0 ) unless (@ARGV > 1);
			     
=head1 CODE		     
			     
=cut			     
			     
make_path($opt_out.'/joined', $opt_out.'/filtered');

while(@ARGV>0){
    my $r1 = shift(@ARGV);
    my $r2 = shift(@ARGV);
    my @suffix = (".fq", ".fastq");
    my $base = basename($r1,@suffix);
    my $cmd_fj = "fastq-join $r1 $r2 -o $opt_out/joined/$base.%.fq\n";
    print $cmd_fj;
    my $ret_fj = qx($cmd_fj);
    die $ret_fj if $? >> 8;
    print $ret_fj;
    my $cmd_us = "usearch8 -fastq_filter $opt_out/joined/$base.join.fq -fastq_truncqual $opt_fastq_truncqual -fastq_minlen 150 -fastqout $opt_out/filtered/$base.fq";
    print $cmd_us;
    my $ret_us = qx($cmd_us);
    die $ret_us if $? >> 8;
    print $ret_us;
}

=head1 LIMITATIONS

If you encounter a bug, feel free to contact Markus Ankenbrand

=head1 AUTHORS

=over

=item * Markus Ankenbrand, markus.ankenbrand@uni-wuerzburg.de

=back
