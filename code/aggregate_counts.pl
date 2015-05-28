#!/usr/bin/perl

use strict;
use warnings;

my %matrix = ();
foreach my $file (@ARGV){
    open(IN, '<', $file) or die "Can't open file $file\n$!";
    while(<IN>){
	chomp;
	my ($tax, $count) = split(/\t/);
	$matrix{$tax} = {} unless exists($matrix{$tax});
	$matrix{$tax}{$file} = $count;
    }
    close IN or die "$!";
}

print "\t".join("\t", @ARGV)."\n";
foreach my $tax (keys %matrix){
    print $tax;
    for(my $i=0; $i<@ARGV; $i++){
	if(exists $matrix{$tax}{$ARGV[$i]}){
	    print "\t$matrix{$tax}{$ARGV[$i]}";
	}
	else{
	    print "\t0";
	}
    }
    print "\n";
}
