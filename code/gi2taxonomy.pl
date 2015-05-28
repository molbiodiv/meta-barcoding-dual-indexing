#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Pod::Usage;

use NCBI::Taxonomy;

my %options;

=head1 NAME 

gi2taxonomy.pl

=head1 DESCRIPTION

This script assigns a taxonomy to each gi in a file according to the file format required by QIIME to re-train the RDP-Classifier

=head1 USAGE

  $ perl gi2taxonomy.pl --gis=<file> [--out=<file>] [options]

=head1 OPTIONS

=over 25

=item --gis=<file>

path to the file containing the gis, one per line. 

=cut

$options{'gis=s'} = \(my $opt_gis);


=item [--out=<file>]

path to the desired output file (overwrites)

=cut

$options{'out=s'} = \(my $opt_out);


=item [--species-taxids=<file>]

path to the desired output file to write a list of all species taxids

=cut

$options{'species-taxids=s'} = \(my $opt_species_taxids);


=item [--genus-taxids=<file>]

path to the desired output file to write a list of all genus taxids

=cut

$options{'genus-taxids=s'} = \(my $opt_genus_taxids);


=item [--help] 

show help

=cut

$options{'help|?'} = \(my $opt_help);


=item [--man] 

show man page

=cut

$options{'man'} = \(my $opt_man);

=back




=head1 CODE

=cut


GetOptions(%options) or pod2usage(1);

pod2usage(1) if($opt_help);
pod2usage(-verbose => 99, -sections => "NAME|DESCRIPTION|USAGE|OPTIONS|LIMITATIONS|AUTHORS") if($opt_man);

pod2usage(-msg => "Missing parameter: --gis", -verbose => 0) unless ($opt_gis);

my @gis = ();
if($opt_out){
	open(OUT, ">$opt_out") or die "can't open file: $opt_gis $!";
	select(OUT);
}
open(IN, "<$opt_gis") or die "can't open file: $opt_gis $!";
while(<IN>){
	chomp;
	push(@gis, $_);
}
my %gi_taxonomy = %{NCBI::Taxonomy::getLineagesbyGI(@gis)};
my %uniq_ids = ();
my %genus_taxids = ();
my %species_taxids = ();
my $uniq_counter = 0;
foreach my $gi (keys %gi_taxonomy){
    my %tax_elements;
    foreach my $tax_element (@{$gi_taxonomy{$gi}}){
	$tax_elements{$tax_element->{rank}} = $tax_element->{sciname}."_".$tax_element->{taxid};
	$species_taxids{$tax_element->{taxid}}=1 if($tax_element->{rank} eq "species");
	$genus_taxids{$tax_element->{taxid}}=1 if($tax_element->{rank} eq "genus");
    }
    my $species_string = get_species_string(\%tax_elements);
    my $genus_string = get_genus_string(\%tax_elements, $species_string);
    my $family_string = get_family_string(\%tax_elements, $genus_string);
    my $order_string = get_order_string(\%tax_elements, $family_string);
    my $class_string = get_class_string(\%tax_elements, $order_string);
    my $phylum_string = get_phylum_string(\%tax_elements, $class_string);
    my $kingdom_string = get_kingdom_string(\%tax_elements, $phylum_string);
    my $tax_string = $gi."\tRoot;".$kingdom_string.$phylum_string.$class_string.$order_string.$family_string.$genus_string.$species_string;
    print "$tax_string\n";
}
if($opt_out){
    close OUT or die $!;
}

if($opt_species_taxids){
    open(ST, ">", $opt_species_taxids) or die "$opt_species_taxids $!";
    foreach(keys %species_taxids){
	print ST "$_\n";
    }
    close ST or die "$!";
}

if($opt_genus_taxids){
    open(GT, ">", $opt_genus_taxids) or die "$opt_genus_taxids $!";
    foreach(keys %genus_taxids){
	print GT "$_\n";
    }
    close GT or die "$!";
}

sub get_species_string{
    my $tax_elements = $_[0];
    my $string = "s__";
    if(defined $tax_elements->{species}){
	$string .= $tax_elements->{species}.";";
    }
    elsif(defined $tax_elements->{subspecies}){
	$string .= "sub__".$tax_elements->{subspecies}.";";
    }
    elsif(defined $tax_elements->{varietas}){
	$string .= "var__".$tax_elements->{varietas}.";";
    }
    elsif(defined $tax_elements->{forma}){
	$string .= "for__".$tax_elements->{forma}.";";
    }
    elsif(defined $tax_elements->{"species subgroup"}){
	$string .= "spsub__".$tax_elements->{"species subgroup"}.";";
    }
    elsif(defined $tax_elements->{"species group"}){
	$string .= "spgro__".$tax_elements->{"species group"}.";";
    }
    else{
	$string .= "undef__".$uniq_counter.";";
	$uniq_counter++;
    }
    return $string;
}

sub get_genus_string{
    my $tax_elements = $_[0];
    my $tax_string = $_[1];
    my $string = "g__";
    if(defined $tax_elements->{genus}){
	$string .= $tax_elements->{genus}.";";
    }
    elsif(defined $tax_elements->{subgenus}){
	$string .= "sub__".$tax_elements->{subgenus}.";";
    }
    elsif(defined $tax_elements->{subtribe}){
	$string .= "subtri__".$tax_elements->{subtribe}.";";
    }
    elsif(defined $tax_elements->{tribe}){
	$string .= "tri__".$tax_elements->{tribe}.";";
    }
    elsif(exists $uniq_ids{$tax_string}){
	$string = $uniq_ids{$tax_string};
    }
    else{
	$string .= "undef__".$uniq_counter.";";
	$uniq_ids{$tax_string} = $string;
	$uniq_counter++;
    }
    return $string;
}

sub get_family_string{
    my $tax_elements = $_[0];
    my $tax_string = $_[1];
    my $string = "f__";
    if(defined $tax_elements->{family}){
	$string .= $tax_elements->{family}.";";
    }
    elsif(defined $tax_elements->{subfamily}){
	$string .= "sub__".$tax_elements->{subfamily}.";";
    }
    elsif(defined $tax_elements->{superfamily}){
	$string .= "super__".$tax_elements->{superfamily}.";";
    }
    elsif(exists $uniq_ids{$tax_string}){
	$string = $uniq_ids{$tax_string};
    }
    else{
	$string .= "undef__".$uniq_counter.";";
	$uniq_ids{$tax_string} = $string;
	$uniq_counter++;
    }
    return $string;
}

sub get_order_string{
    my $tax_elements = $_[0];
    my $tax_string = $_[1];
    my $string = "o__";
    if(defined $tax_elements->{order}){
	$string .= $tax_elements->{order}.";";
    }
    elsif(defined $tax_elements->{suborder}){
	$string .= "sub__".$tax_elements->{suborder}.";";
    }
    elsif(defined $tax_elements->{superorder}){
	$string .= "super__".$tax_elements->{superorder}.";";
    }
    elsif(defined $tax_elements->{infraorder}){
	$string .= "infra__".$tax_elements->{infraorder}.";";
    }
    elsif(defined $tax_elements->{parvorder}){
	$string .= "parv__".$tax_elements->{parvorder}.";";
    }
    elsif(exists $uniq_ids{$tax_string}){
	$string = $uniq_ids{$tax_string};
    }
    else{
	$string .= "undef__".$uniq_counter.";";
	$uniq_ids{$tax_string} = $string;
	$uniq_counter++;
    }
    return $string;
}

sub get_class_string{
    my $tax_elements = $_[0];
    my $tax_string = $_[1];
    my $string = "c__";
    if(defined $tax_elements->{class}){
	$string .= $tax_elements->{class}.";";
    }
    elsif(defined $tax_elements->{subclass}){
	$string .= "sub__".$tax_elements->{subclass}.";";
    }
    elsif(defined $tax_elements->{superclass}){
	$string .= "super__".$tax_elements->{superclass}.";";
    }
    elsif(defined $tax_elements->{infraclass}){
	$string .= "infra__".$tax_elements->{infraclass}.";";
    }
    elsif(exists $uniq_ids{$tax_string}){
	$string = $uniq_ids{$tax_string};
    }
    else{
	$string .= "undef__".$uniq_counter.";";
	$uniq_ids{$tax_string} = $string;
	$uniq_counter++;
    }
    return $string;
}

sub get_phylum_string{
    my $tax_elements = $_[0];
    my $tax_string = $_[1];
    my $string = "p__";
    if(defined $tax_elements->{phylum}){
	$string .= $tax_elements->{phylum}.";";
    }
    elsif(defined $tax_elements->{subphylum}){
	$string .= "sub__".$tax_elements->{subphylum}.";";
    }
    elsif(defined $tax_elements->{superphylum}){
	$string .= "super__".$tax_elements->{superphylum}.";";
    }
    elsif(exists $uniq_ids{$tax_string}){
	$string = $uniq_ids{$tax_string};
    }
    else{
	$string .= "undef__".$uniq_counter.";";
	$uniq_ids{$tax_string} = $string;
	$uniq_counter++;
    }
    return $string;
}

sub get_kingdom_string{
    my $tax_elements = $_[0];
    my $tax_string = $_[1];
    my $string = "k__";
    if(defined $tax_elements->{kingdom}){
	$string .= $tax_elements->{kingdom}.";";
    }
    elsif(defined $tax_elements->{subkingdom}){
	$string .= "sub__".$tax_elements->{subkingdom}.";";
    }
    elsif(defined $tax_elements->{superkingdom}){
	$string .= "super__".$tax_elements->{superkingdom}.";";
    }
    elsif(exists $uniq_ids{$tax_string}){
	$string = $uniq_ids{$tax_string};
    }
    else{
	$string .= "undef__".$uniq_counter.";";
	$uniq_ids{$tax_string} = $string;
	$uniq_counter++;
    }
    return $string;
}

=head1 LIMITATIONS

This script requires the NCBI::Taxonomy module, 
written by Frank Förster (frank.foerster@biozentrum.uni-wuerzburg.de) 
and a local copy of the NCBI taxonomy in the appropriate location.

If you encounter a bug please drop me a line.

=head1 AUTHORS

=over

=item * Markus Ankenbrand, markus.ankenbrand@stud-mail.uni-wuerzburg.de

=back

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Markus Ankenbrand

This script is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.10.0 or, at
your option, any later version of Perl 5 you may have available.

=back

