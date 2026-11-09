#!/usr/bin/env perl
#
#====================================================================================
#
# TeraChem interface for NewtonX initial conditions and absorption spectra
# (initcond.pl, prog = 21.0). Built from the NX template by Mario Barbatti, 2021.
#
# Matsika Lab, Temple University, USA.
#
#====================================================================================
#
# initcond.pl calls this script once per geometry, from TEMP/, after copying JOB_AD/*
# there. The script
#   1. writes ic.sp from the template (tera.sp, or start.sp) with 'run energy',
#   2. runs TeraChem once (output in geom.out),
#   3. writes epot.<ifs> (or epot0.<ifs> for the reference geometry, when the file
#      'zero' exists) and oos.<ifs> for ifs = nis+1 .. nfs, as NX expects.
#
# Oscillator strengths are from state nis to state ifs, in the length gauge. For
# nis = 1 the values TeraChem prints are used. For nis > 1 they are computed from the
# transition dipoles as f = 2/3 * dE * |T|^2.
#
# It shares the TeraChem helpers of run-tera-cas.pl, which must be in the same folder.
#
use strict;
use warnings;
use File::Path qw(remove_tree);
use Cwd qw(getcwd abs_path);
use File::Basename qw(dirname);

BEGIN {
    die "run_tera_ic.pl: the NX environment variable is not set.\n" unless defined $ENV{"NX"};
}
use lib join( '/', $ENV{"NX"}, "lib" );
use colib_perl;
require( dirname( abs_path(__FILE__) ) . "/run-tera-cas.pl" ) unless defined &main::parse_energies;

our $out_ic = "geom.out";
our $inp_ic = "ic.sp";

main_ic() unless caller;

sub main_ic {
    $main::mdle = "run_tera_ic.pl:";
    $main::tpp  = $ENV{"TeraChem"};
    check_environment();

    my $nis   = getkeyword( "initqp_input", "nis",   1 );
    my $nfs   = getkeyword( "initqp_input", "nfs",   2 );
    my $lvprt = getkeyword( "initqp_input", "lvprt", 1 );
    $main::lvprt = $lvprt;
    tc_fail("nis ($nis) and nfs ($nfs) in initqp_input must be different states, both 1 or more.")
      unless $nis >= 1 && $nfs >= 1 && $nfs != $nis;
    my $mxns = $nis > $nfs ? $nis : $nfs;
    my $epotf = -e "zero" ? "epot0" : "epot";

    # Geometry
    open my $g, '<', "geom" or tc_fail("Cannot open geom: $!");
    $main::nat = grep { /\S/ } <$g>;
    close $g;
    read_geom();
    write_xyz( [] );

    # Input
    my $template = -e "tera.sp" ? "tera.sp" : "start.sp";
    tc_fail("No TeraChem template (tera.sp or start.sp) in JOB_AD.") unless -e $template;
    open my $fh, '<', $template or tc_fail("Cannot open $template: $!");
    my @lines = <$fh>;
    close $fh;
    my $info = template_info( \@lines );
    set_keyword( \@lines, "run",    "energy" );
    remove_keyword( \@lines, "scrdir" );                 # TeraChem lowercases paths
    set_keyword( \@lines, "coordinates", "geom.xyz" );   # scratch goes to ./scr.geom
    open $fh, '>', $inp_ic or tc_fail("Cannot write $inp_ic: $!");
    print $fh @lines;
    close $fh;

    # Run
    remove_tree("scr.geom") if -d "scr.geom";
    unlink $out_ic;
    my $retval = callprog( $main::tpp, "/bin/terachem $inp_ic > $out_ic", $main::mdle );
    tc_fail("TeraChem failed. Check $out_ic for details.") if $retval != 0;
    open $fh, '<', $out_ic or tc_fail("Cannot open $out_ic: $!");
    my $finished = grep { /Job finished/ } <$fh>;
    close $fh;
    tc_fail("TeraChem did not finish (no 'Job finished' line in $out_ic). It may have been killed, for example by a time limit.")
      unless $finished;

    # Energies and oscillator strengths
    # As initcond.pl expects (and run_bagel_initcond.pl writes): one file pair per state
    # ifs = 1 .. max(nis, nfs), ifs != nis; epot.<ifs> holds the two energies in
    # ascending state order, oos.<ifs> the oscillator strength between nis and ifs.
    my @e = parse_energies( $out_ic, $info, $mxns );
    my %f = parse_oscillators( $out_ic, $info, $nis, $mxns, \@e );

    for my $ifs ( grep { $_ != $nis } 1 .. $mxns ) {
        my ( $lo, $hi ) = $ifs < $nis ? ( $ifs, $nis ) : ( $nis, $ifs );
        open my $o, '>', "$epotf.$ifs" or tc_fail("Cannot write $epotf.$ifs: $!");
        print $o "$e[$lo-1]\n$e[$hi-1]\n";
        close $o;
        open $o, '>', "oos.$ifs" or tc_fail("Cannot write oos.$ifs: $!");
        print $o "$f{$ifs}\n";
        close $o;
    }

    if ( $lvprt >= 2 ) {
        my $au2ev = units("au2ev");
        print_STDOUT( "$main::mdle state   energy (a.u.)    dE from $nis (eV)   f($nis<->state)\n" );
        for my $ifs ( grep { $_ != $nis } 1 .. $mxns ) {
            print_STDOUT( sprintf( "%s %5d %16.8f %14.4f %14.6f\n", $main::mdle, $ifs, $e[ $ifs - 1 ], ( $e[ $ifs - 1 ] - $e[ $nis - 1 ] ) * $au2ev, $f{$ifs} ) );
        }
    }
}

sub parse_oscillators {
    #
    # Returns { ifs => f } for every ifs = 1 .. $mxns other than nis, where f is the
    # oscillator strength between states nis and ifs (the lower to the higher).
    #
    # TeraChem prints, by method:
    #   CASSCF/FOMO-CASCI: '<Mult> state electronic transitions:' blocks with a
    #     'Transition Tx Ty Tz |T| Osc.' table; rows 'i -> j', 1 = ground state.
    #   hh-TDA: an Osc. column in the 'Root Mult. Total Energy' table, and a
    #     'Transition Tx Ty Tz |T|' table; rows 'i -> j', 1 = ground state.
    #   TDA/TDDFT: an Osc. column in the second 'Root Total Energy' table (ground to
    #     root); the 'Transition' table is between excited roots only (root r = state r+1).
    #
    my ( $file, $info, $nis, $mxns, $e ) = @_;
    open my $fh, '<', $file or tc_fail("Cannot open $file: $!");
    my @lines = <$fh>;
    close $fh;

    my $want     = mult_name( $info->{mult} );
    my $has_mult = grep { /Root\s+Mult\.\s+Total Energy/ } @lines;    # CAS and hh-TDA
    my $shift    = $has_mult ? 0 : 1;                                  # TDA roots -> NX states
    my ( %osc, %tdm );

    # Transition-dipole tables (length gauge only).
    my ( $in_table, $block_ok ) = ( 0, 1 );
    foreach my $l (@lines) {
        if ( $l =~ /^\s*(\w+) state electronic transitions/ )            { $block_ok = ( lc($1) eq $want ); next; }    # CAS
        if ( $l =~ /Transition dipole moments between (\w+) states/ ) { $block_ok = ( lc($1) eq $want || lc($1) eq "excited" ); next; }
        if ( $l =~ /^\s*Transition\s+Tx\s+Ty\s+Tz/ ) { $in_table = 1; next; }
        if ( $l =~ /^\s*Transition\s+Px/ )          { $in_table = 0; next; }
        next unless $in_table;
        next if $l =~ /^\s*-+\s*$/;
        if ( $l =~ /^\s*(\d+)\s*->\s*(\d+)\s+(.*)$/ ) {
            next unless $block_ok;
            my ( $i, $j ) = ( $1 + $shift, $2 + $shift );
            my @c = split ' ', $3;
            $tdm{$i}{$j} //= $c[3];                                   # |T|
            $osc{$i}{$j} //= $c[4] if @c >= 5 && !$shift;            # Osc. column (CAS)
            next;
        }
        $in_table = 0;
    }

    # Ground-state oscillator strengths printed in the energy tables.
    {
        for my $k ( 0 .. $#lines ) {
            if ( $lines[$k] =~ /Root\s+Mult\.\s+Total Energy.*Osc\./ ) {    # hh-TDA
                my $state = 0;
                for ( my $r = $k + 1 ; $r <= $#lines ; $r++ ) {
                    next if $lines[$r] =~ /^\s*-+\s*$/;
                    last unless $lines[$r] =~ /^\s*\d+\s+(\w+)\s+-?\d+\.\d+(.*)$/;
                    next unless lc($1) eq $want;
                    $state++;
                    my @c = split ' ', $2;
                    $osc{1}{$state} //= $c[-1] if $state > 1 && @c >= 4;
                }
            }
            if ( $lines[$k] =~ /Root\s+Total Energy.*Osc\./ ) {              # TDA/TDDFT
                for ( my $r = $k + 1 ; $r <= $#lines ; $r++ ) {
                    next if $lines[$r] =~ /^\s*-+\s*$/;
                    last unless $lines[$r] =~ /^\s*(\d+)\s+-?\d+\.\d+\s+\S+\s+(\S+)/;
                    $osc{1}{ $1 + 1 } //= $2;
                }
            }
        }
    }

    my %f;
    for my $ifs ( grep { $_ != $nis } 1 .. $mxns ) {
        my ( $lo, $hi ) = $ifs < $nis ? ( $ifs, $nis ) : ( $nis, $ifs );
        if ( defined $osc{$lo}{$hi} ) {
            $f{$ifs} = $osc{$lo}{$hi};
        }
        elsif ( defined $tdm{$lo}{$hi} ) {
            my $de = $e->[ $hi - 1 ] - $e->[ $lo - 1 ];
            $f{$ifs} = sprintf( "%.6f", 2.0 / 3.0 * $de * $tdm{$lo}{$hi}**2 );
        }
        else {
            tc_fail("No oscillator strength or transition dipole between states $lo and $hi in $file. Ask TeraChem for more states, and check the multiplicity.");
        }
    }
    return %f;
}
