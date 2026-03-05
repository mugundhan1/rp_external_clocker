#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Long;
use File::Find;
use File::Basename;
use Cwd;


sub usage
{
    print <<STR;

    Usage

      stripGlobalMP.pl -s {SOURCE_DIRECTORY}

        This script searches .LIB files in source directory "s". 
        
        If global .MODEL and .PARAM statements are found in a file, the script removes them and saves the modified file 
        to a sub directory "localizedMP". Also saves is a file containing the removed .MODEL and .PARAM statements.

STR
}

my %opts;

GetOptions(\%opts,
        "sd=s"	# source directory
);

if ( $opts{sd} eq "" ) {
        &usage;
	die "Please specify source directory";
}
else {
        finddepth \&stripGlobalMP, $opts{sd};  
}

sub stripGlobalMP
{
        my $FullFileName;
        my $FullName;
        my $BaseName;
        my $outDir;

        if (m/.*\.lib/i) {

                $FullFileName = $File::Find::name;
                $BaseName = basename($File::Find::name);
                $FullName = cwd;
                $FullName = $FullName . "\\" . $BaseName;

                $outDir = cwd;
                $outDir = $outDir . "\\strippedGlobalMP";

                if (! -e $outDir) {
                        mkdir( $outDir ) or die "Couldn't create $outDir directory, $!";
                }

                open(IN, "<", $FullName) or die "Couldn't open input file, $!\n";
                print STDERR "Read $FullFileName";

                #print STDERR "[INFO]: Processing file $opts{f} with suffix $opts{s}...\n";
                my @lines = <IN>;
                chomp @lines;
                close IN;
                
                # look for .MODEL and .PARAM and move them to array @globals. Move other lines to array @main
                my $enc = 0;
                my $hierLvl = 0;
                my $i = 0;

                my @globals;
                my @main;
                my @final;

                while ($i <= $#lines) {

                        if ($lines[$i] =~ /CDNENCSTART/i) { 
                                $enc = 1;
                                print STDERR "$BaseName: skip encrypted file.\n";
                                last;
                        }

                        else {
                                # remove leading spaces and split current line
                                $lines[$i] =~ s/^\s+//;
                                my @words = split ('\s+', $lines[$i]);
                                
                                if (!defined $words[0]) {}
                                elsif ($words[0] =~ /^\*/) {
                                        push @main, $lines[$i];
                                        #print $i, $lines[$i], "\n";
                                }
                                elsif ($words[0] =~ /^\.param$/i || $words[0] =~ /^\.model$/i) {
                                        if ($hierLvl == 0)
                                        {
                                                # global .MODEL or .PARAM found
                                                push @globals, $lines[$i];
                                                $i++;
                                                while ($i <= $#lines) {
                                                        my @xwords = split ('\s+', $lines[$i]);
                                                        # skip blank line
                                                        if (!defined $xwords[0]) {
                                                                $i++;
                                                        }
                                                        # if the next line is comments
                                                        elsif ($xwords[0] =~ /^\*/) {
                                                                push @globals, $lines[$i];
                                                                $i++;
                                                        }
                                                        # if the next line starts with "+"
                                                        elsif ($lines[$i] =~ m/^\+/) {
                                                                push @globals, $lines[$i];
                                                                $i++;
                                                        }
                                                        else {
                                                                $i--;
                                                                last;
                                                        }
                                                }
                                        }
                                        else {
                                                push @main, $lines[$i];
                                        }
                                }
                                elsif ($words[0] =~ /^.subckt$/i) {
                                        $hierLvl ++;
                                        push @main, $lines[$i];
                                }
                                elsif ($words[0] =~ /^.ends$/i) {
                                        $hierLvl --;
                                        push @main, $lines[$i];
                                }
                                else {
                                        push @main, $lines[$i];
                                }
                                $i++;
                        }
                }
                
                if ( $enc == 0 ) {
                        
                        my $j = 0;
                        if ($#globals > -1) {

                                # save @globals to a new file
                                my @exts = qw(.lib);
                                my($base, $path, $ext) = fileparse($FullName, @exts);
                                my $globalFile = $outDir . "\\" . $base . "_NG" . ".lib";

                                print STDERR ". Global model/param found, write global model/param to $globalFile";
                                open(OUT, ">", $globalFile) or die "Couldn't write to $!\n";

                                $j = 0;
                                while ($j <= $#globals) {
                                        print OUT $globals[$j], "\n";
                                        $j++;
                                }

                                close OUT;


                                # save @main to a new file

                                my $outFile = $outDir . "\\$BaseName";

                                print STDERR ", write cleaned file to $outFile\n";
                                open(OUT, ">", $outFile) or die "Couldn't write to $!\n";
                        
                                $j = 0;

                                while ($j <= $#main) {
                                        print OUT $main[$j], "\n";
                                        $j++;
                                }

                                close OUT;

                        }
                        else {
                                print STDERR ": global model/param not found.\n";
                        }
                
                }
                else {
                        print STDERR ": file is encrypted.\n";
                }

        }
}
