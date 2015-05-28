#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::RealBin/lib";
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use Getopt::Long;
use Pod::Usage;
use Log::Log4perl qw(:no_extra_logdie_message);

my %options = ();

#TODO set name, description and usage
=head1 NAME 

count_taxa_rdp.pl

=head1 DESCRIPTION

Counts taxa in the rdp output file. Ignoring classifications below a user defined cutoff.
For each classification the count in the file is given.

=head1 USAGE

  $ perl count_taxa_rdp.pl --in=<file> [--cutoff=<int>] >out

=cut

=head1 OPTIONS

=over 25

=item --in=<file>

The input file for the count script (output file of rdp)
Format:
<seqid> TAB <-|> TAB <taxonomy with cutoffs>
The taxonomy is a TAB separated list of taxonomic levels with rank and bootstrap
Example:
M02015:76:000000000-AABWE:1:1101:14153:1434		Root	rootrank	1.0	k__Viridiplantae_33090	kingdom	1.0	p__Streptophyta_35493	phylum	1.0	c__sub__rosids_71275	class	1.0	o__Fagales_3502	order	1.0	f__Fagaceae_3503	family	1.0	g__undef__222	genus	0.7	s__uncultured Fagus sylvatica from ectomycorrhiza_197746	species	0.7

=cut

$options{'in=s'} = \( my $opt_in );

=item --cutoff=<int>

Bootstrap cutoff for classifications to trust.
Taxonomic assignments are truncated at the first classification with bootstrap lower than cutoff.
Default = 0

=cut

$options{'cutoff=f'} = \( my $opt_cutoff = 0 );

#verbose, help and man options (delete if not needed)
=item [--[no]verbose] 

verbose is default.

=cut

$options{'verbose!'} = \(my $opt_verbose = 1);


=item [--help] 

show help

=cut

$options{'help|?'} = \(my $opt_help);


=item [--man] 

show man page

=cut

$options{'man'} = \(my $opt_man);


GetOptions(%options) or pod2usage(1);

pod2usage(1) if($opt_help);
pod2usage(-verbose => 99, -sections => "NAME|DESCRIPTION|USAGE|OPTIONS|LIMITATIONS|AUTHORS") if($opt_man);
pod2usage( -msg => 'missing input file use --in <file> to set', -verbose => 0 ) unless ($opt_in);

# init a root logger in exec mode
Log::Log4perl->init(
	\q(
                log4perl.rootLogger                     = DEBUG, Screen
                log4perl.appender.Screen                = Log::Log4perl::Appender::Screen
                log4perl.appender.Screen.stderr         = 1
                log4perl.appender.Screen.layout         = PatternLayout
                log4perl.appender.Screen.layout.ConversionPattern = [%d{MM-dd HH:mm:ss}] [%C] %m%n
        )
);

my $L = Log::Log4perl::get_logger();

=head1 CODE

=cut

my %count;
open(IN, '<', $opt_in) or die "Can't open file: $opt_in.\n$!";
while(<IN>){
    chomp;
    my @taxonomy = split(/\t/);
    my $trunc = truncate_tax_by_score(\@taxonomy);
    $count{$trunc} = 0 unless(exists $count{$trunc});
    $count{$trunc}++;
}
close IN or die "Can't close file: $opt_in.\n$!";
foreach my $tax (sort {$count{$b} <=> $count{$a}} keys %count){
    print "$tax\t$count{$tax}\n";
}

=head2 truncate_tax_by_score

This sub truncates the taxonomic assignment by the rawscore.
It truncates at the first rank with rawscore < cutoff.
Additionally the rawscores are stripped from the taxline.

=cut

sub truncate_tax_by_score{
    my @tax = @{$_[0]};
    my @string = ();
    # Start at index 4 to skip sequence name and rootrank
    for(my $i=5; $i<@tax; $i+=3){
	my $rank = $tax[$i]; 
	my $score = $tax[$i+2];
	if($score >= $opt_cutoff){
	    push(@string, $rank);
	}
	else{
	    last;
	}
    }
    my $string = "unclassified";
    if(@string > 0){
	$string = join(",", @string)
    }
    return $string;
}

=head1 LIMITATIONS

If you encounter a bug, feel free to contact Markus Ankenbrand

=head1 AUTHORS

=over

=item * Markus Ankenbrand, markus.ankenbrand@stud-mail.uni-wuerzburg.de

=back
