#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

# Convert from tax file format (RDP output style)
# 2241223    Root;k__Viridiplantae;p__Streptophyta;c__asterids;o__Asterales;f__Campanulaceae;g__Adenophora;s__Adenophora khasiana
# To rdp training input style
# taxid*taxon_name*parent_taxid*depth*rank
# 0*Root*-1*0*rootrank
# And utax output style
# taxid <TAB> parent_taxid <TAB> taxon_name <TAB> rank
# Also output a map of id to taxid

# USAGE: perl tax2rdp.pl <taxonomy.tax> <sequences.fa> [prefix]

my $prefix = "taxonomy";
$prefix = $ARGV[2] if($ARGV[2]);
my @rank = ("rootrank", "kingdom", "phylum", "class", "order", "family", "genus", "species", "sub1", "sub2", "sub3", "sub4");
my %fullline;
my %entries;
my $id = 0;
my %map;
open(IN, '<', $ARGV[0]) or die "$!";
while(<IN>){
    chomp;
    my ($gid, $levels) = split(/\t/);
    $fullline{$gid} = $levels;
    my @levels = split(/;/, $levels);
    my $parentid = -1;
    for(my $i=0; $i<@levels; $i++){
	my $level = $levels[$i];
	unless(exists $entries{$level}){
	    $entries{$level}={id=>$id++, name=>$level, parent=>$parentid, depth=>$i};
	}
	$parentid = $entries{$level}{id};
    }
    $map{$gid} = $entries{$levels[@levels-1]}{id};
}
close IN or die "$!";

open(RDP, '>', "$prefix.rdp.tax") or die "$!";
open(UTAX, '>', "$prefix.utax.tax") or die "$!";
foreach my $key (sort {$entries{$a}{id} <=> $entries{$b}{id}} keys %entries){
    print RDP "$entries{$key}{id}*$entries{$key}{name}*$entries{$key}{parent}*$entries{$key}{depth}*$rank[$entries{$key}{depth}]\n";
    print UTAX "$entries{$key}{id}\t$entries{$key}{parent}\t$entries{$key}{name}\t$rank[$entries{$key}{depth}]\n";
}
close RDP or die "$!";
close UTAX or die "$!";
open(MAP, '>', "$prefix.gi_tax.map") or die "$!";
foreach my $gid (keys %map){
    print MAP "$gid\t$map{$gid}\n";
}
close MAP or die "$!";

open(FA, '<', "$ARGV[1]") or die "$!";
open(RDP_FA, '>', "$prefix.rdp.fa") or die "$!";
open(UTAX_FA, '>', "$prefix.utax.fa") or die "$!";
my $printOK = 0;
while(<FA>){
    if(/^>(\d+)/){
	if(exists $fullline{$1}){
		$printOK = 1;
		print RDP_FA ">$1 $fullline{$1}\n";
		print UTAX_FA ">$1;tax=$map{$1}; $fullline{$1}\n";
	} else {
		$printOK = 0;
		print STDERR "No tax information for gi: $1, skipping...\n";
	}
    }
    else{ 
	if($printOK) {
		print RDP_FA "$_";
		print UTAX_FA "$_";	
		}
	}
}
close FA or die "$!";
close RDP_FA or die "$!";
close UTAX_FA or die "$!";
