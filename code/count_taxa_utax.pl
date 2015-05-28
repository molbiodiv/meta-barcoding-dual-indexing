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

count_taxa_utax.pl

=head1 DESCRIPTION

Counts taxa in the utax output file. Ignoring classifications below a user defined cutoff.
For each classification the count in the file is given.

=head1 USAGE

  $ perl count_taxa_utax.pl --in=<file> [--cutoff=<int>] >out

=cut

=head1 OPTIONS

=over 25

=item --in=<file>

The input file for the count script (output file of utax)
Format:
<seqid> TAB <taxonomy> TAB [+-]
The taxonomy is a comma separated list of taxonomic levels with rawscore in parentheses
Example:
M02015:76:000000000-AABWE:1:1101:16880:1430	k__Viridiplantae_33090(60.0),p__Streptophyta_35493(60.0),c__sub__asterids_71274(45.0),o__Asterales_4209(43.1),f__Asteraceae_4210(43.1),g__Bidens_42336(35.1),s__Bidens cronquistii_172207(30.1)	+

=cut

$options{'in=s'} = \( my $opt_in );

=item --cutoff=<int>

Rawscore cutoff for classifications to trust.
Taxonomic assignments are truncated at the first classification with rawscore lower than cutoff.
Default = 0

=cut

$options{'cutoff=i'} = \( my $opt_cutoff = 0 );

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
    my $taxonomy = (split(/\t/))[1];
    my $trunc = truncate_tax_by_score($taxonomy);
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
    my $tax = $_[0];
    my @tax = split(/,/, $tax);
    my @string = ();
    for(my $i=0; $i<@tax; $i++){
	my $opening_bracket = index($tax[$i], '(', length($tax[$i])-7);
	my $closing_bracket = index($tax[$i], ')', length($tax[$i])-2);
	my $rank = substr($tax[$i], 0, $opening_bracket);
	my $score = substr($tax[$i], $opening_bracket+1, $closing_bracket-$opening_bracket-1);
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
