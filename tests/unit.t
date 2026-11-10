#!/usr/bin/env perl
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Unit tests for run-tera-cas.pl that need no GPU and no TeraChem.
# Run from the repository root:  NX=/path/to/NX/bin prove -v tests/unit.t
# The fixtures are real TeraChem 1.96 outputs from short uracil and ethylene runs.
#
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;

BEGIN {
    plan skip_all => "set NX to a NewtonX bin folder (colib_perl.pm is needed)" unless $ENV{NX};
}

my $root = "$FindBin::Bin/..";
my $fx   = "$FindBin::Bin/fixtures";
require "$root/run-tera-cas.pl";

# fail() prints through NX's print_STDOUT; keep the test output clean.
no warnings qw(redefine once);
*main::print_STDOUT = sub { };
use warnings 'redefine';

sub slurp { local ( @ARGV, $/ ) = @_; <> }
sub dies_like { my ( $code, $re, $name ) = @_; eval { $code->() }; like( $@, $re, $name ); }

#--------------------------------------------------------------------------------
subtest 'pair_index matches NX ordering (2,1),(3,1),(3,2),(4,1)...' => sub {
    my @order = ( [ 1, 2 ], [ 1, 3 ], [ 2, 3 ], [ 1, 4 ], [ 2, 4 ], [ 3, 4 ], [ 1, 5 ] );
    is( main::pair_index(@{ $order[$_] }), $_, "pair (@{$order[$_]}) -> $_" ) for 0 .. $#order;

    # The old script's formulas for the two neighbour couplings of state n.
    for my $n ( 2 .. 6 ) {
        is( main::pair_index( $n - 1, $n ), $n * ( $n - 1 ) / 2 - 1,          "old ncc1 for n=$n" );
        is( main::pair_index( $n, $n + 1 ), $n * ( $n - 1 ) / 2 - 1 + $n,     "old ncc2 for n=$n" );
    }
};

subtest 'coupling_pairs' => sub {
    my $p = sub { join " ", map { "$_->[0]-$_->[1]" } main::coupling_pairs(@_) };
    is( $p->( "neighbours", 1, 3, "" ),           "1-2",                     "ground state" );
    is( $p->( "neighbours", 2, 3, "" ),           "1-2 2-3",                 "middle state" );
    is( $p->( "neighbours", 3, 3, "" ),           "2-3",                     "top state" );
    is( $p->( "current",    2, 4, "" ),           "1-2 2-3 2-4",             "current" );
    is( $p->( "all",        2, 4, "" ),           "1-2 1-3 2-3 1-4 2-4 3-4", "all" );
    is( $p->( "all",        2, 4, "second run" ), "",                        "no couplings after a hop" );
    is( $p->( "neighbours", 1, 1, "" ),           "",                        "one state" );
};

subtest 'read_options' => sub {
    my $d = tempdir( CLEANUP => 1 );
    my %o = main::read_options("$d/none.par");
    is_deeply( \%o, \%main::DEFAULTS, "missing file gives defaults" );

    open my $fh, '>', "$d/a.par";
    print $fh "&terachem\n use_prev_scf_wf = 1,  # comment\n couplings all\n archive_wf = no\n/\n";
    close $fh;
    %o = main::read_options("$d/a.par");
    is( $o{use_prev_scf_wf}, 1,     "key = value with comma and comment" );
    is( $o{couplings},       "all", "key value without =" );
    is( $o{archive_wf},      0,     "no -> 0" );
    is( $o{use_prev_wf},     0,     "unset key keeps default" );

    open $fh, '>', "$d/b.par"; print $fh "use_prev_scf = 1\n"; close $fh;
    dies_like( sub { main::read_options("$d/b.par") }, qr/Unknown option 'use_prev_scf'/, "typo stops the run" );
    open $fh, '>', "$d/c.par"; print $fh "couplings = some\n"; close $fh;
    dies_like( sub { main::read_options("$d/c.par") }, qr/neighbours, current or all/, "bad coupling mode" );
    open $fh, '>', "$d/f.par"; print $fh "phase_ref = last\n"; close $fh;
    is( { main::read_options("$d/f.par") }->{phase_ref}, "last", "phase_ref = last" );
    open $fh, '>', "$d/g.par"; print $fh "phase_ref = memory\n"; close $fh;
    dies_like( sub { main::read_options("$d/g.par") }, qr/previous or last/, "bad phase_ref" );
    open $fh, '>', "$d/e.par"; print $fh "couplings = neighbors\n"; close $fh;
    is( { main::read_options("$d/e.par") }->{couplings}, "neighbours", "US spelling accepted" );
};

subtest 'set_keyword, remove_keyword, insert before end' => sub {
    my @l = ( "basis 6-31g\n", "# castarget 5\n", "CASTARGET   0   # note\n", "end\n", "after end\n" );
    main::set_keyword( \@l, "castarget", 2 );
    is( scalar( grep { /^castarget\s+2$/ } @l ), 1, "replaced in place, case-insensitive" );
    is( $l[1], "# castarget 5\n", "comment untouched" );
    main::set_keyword( \@l, "scrdir", "/x/scr" );
    is( $l[3], "scrdir          /x/scr\n", "new keyword inserted before end" );
    is( $l[4], "end\n",                    "end stays after it" );
    main::remove_keyword( \@l, "castarget" );
    ok( !grep( { /^castarget/i } @l ), "removed" );

    my @m = ( "casscfmaxiter 100\n", "maxit 50" );
    main::remove_keyword( \@m, "maxit" );
    is_deeply( \@m, ["casscfmaxiter 100\n"], "only the exact keyword is removed" );
};

subtest 'template_info' => sub {
    my $i = main::template_info( [ "casscf yes\n", "castargetmult 3\n" ] );
    ok( $i->{casscf} && $i->{cas} && !$i->{cis}, "casscf" );
    is( $i->{mult}, 3, "multiplicity" );
    $i = main::template_info( [ "casci  yes\n", "fon yes\n" ] );
    ok( !$i->{casscf} && $i->{cas}, "fomo-casci" );
    $i = main::template_info( [ "hhtda yes\n" ] );
    ok( $i->{cis} && !$i->{cas}, "hh-tda" );
    $i = main::template_info( [ "rpa yes\n" ] );
    ok( $i->{rpa} && $i->{cis} && !$i->{cas}, "full TDDFT (rpa yes) is a CIS-type method" );
    $i = main::template_info( [ "# casscf yes\n", "cis yes\n" ] );
    ok( !$i->{casscf} && $i->{cis}, "commented casscf ignored" );
    is( $i->{mult}, 1, "default multiplicity" );
};

subtest 'parse_energies on real outputs' => sub {
    for my $m (qw(fomo hhtda tda casscf)) {
        my $info = main::template_info( [ $m eq "tda" ? "cis yes\n" : $m eq "hhtda" ? "hhtda yes\n" : "casci yes\n" ] );
        my @e    = main::parse_energies( "$fx/$m.grad.tera.out", $info, 3 );
        is( join( "\n", @e ) . "\n", slurp("$fx/$m.epot"), "$m energies match the recorded epot" );
    }
    my @rpa = main::parse_energies( "$fx/rpa.grad.tera.out", main::template_info( ["rpa yes\n"] ), 2 );
    is( $rpa[1], "-78.33242756", "RPA: excited state from the Root Total Energy table" );
    my $info = main::template_info( ["casci yes\n"] );
    dies_like( sub { main::parse_energies( "$fx/fomo.grad.tera.out", $info, 4 ) }, qr/Could not read 4 state energies/, "too few states" );
    $info = main::template_info( [ "casci yes\n", "castargetmult 3\n" ] );
    dies_like( sub { main::parse_energies( "$fx/fomo.grad.tera.out", $info, 1 ) }, qr/found 0/, "no triplet rows in a singlet run" );
};

subtest 'read_xyz_vector_file' => sub {
    $main::nat = 12;
    my ( $x, $y, $z ) = main::read_xyz_vector_file("$fx/fomo.nac.xyz");
    is( scalar(@$x), 12, "12 atoms" );
    is( $x->[0], "-1.1530715053", "value kept as written" );

    $main::nat = 13;
    dies_like( sub { main::read_xyz_vector_file("$fx/fomo.nac.xyz") }, qr/12 atom lines; expected 13/, "atom count checked" );
    my $d = tempdir( CLEANUP => 1 );
    open my $fh, '>', "$d/bad.xyz"; print $fh "1\nx\nC 0.1 nan 0.2\n"; close $fh;
    $main::nat = 1;
    dies_like( sub { main::read_xyz_vector_file("$d/bad.xyz") }, qr/Bad line/, "non-numeric value" );
    dies_like( sub { main::read_xyz_vector_file("$d/missing.xyz") }, qr/not found or empty/, "missing file" );
};

subtest 'transmomin (couplings = nx)' => sub {
    my $d = tempdir( CLEANUP => 1 );
    open my $fh, '>', "$d/tm"; print $fh "CI\n1  3  1  1\n1  3  1  2\n1  2  1  3\n"; close $fh;
    my $p = sub { join " ", map { "$_->[0]-$_->[1]" } main::coupling_pairs(@_) };
    is( $p->( "nx", 3, 3, "", "$d/tm" ), "1-3 2-3", "pairs read, sorted to i<j, duplicates dropped" );
    is( $p->( "nx", 3, 3, "second run", "$d/tm" ), "", "second run still skips" );
    open $fh, '>', "$d/empty"; print $fh "CI\n"; close $fh;
    is( $p->( "nx", 2, 3, "", "$d/empty" ), "", "THRES can leave the list empty" );
    open $fh, '>', "$d/bad"; print $fh "CI\n1  4  1  1\n"; close $fh;
    dies_like( sub { main::coupling_pairs( "nx", 2, 3, "", "$d/bad" ) }, qr/Bad state pair/, "state above nstat" );
    dies_like( sub { main::coupling_pairs( "nx", 2, 3, "", "$d/none" ) }, qr/not found/, "missing transmomin" );
    my $f = "$fx/transmomin.uracil";
    is( $p->( "nx", 3, 3, "", $f ), "1-3 2-3", "real NX file (jiri.inp current = 1)" ) if -e $f;
};

subtest 'triplet runs (one multiplicity)' => sub {
    my $info = main::template_info( [ "casci yes\n", "castargetmult 3\n" ] );
    is_deeply( [ main::parse_energies( "$fx/fomo_triplet.grad.tera.out", $info, 3 ) ],
        [ "-77.92020106", "-77.67251230", "-77.66894133" ], "FOMO triplets" );
    $info = main::template_info( [ "hhtda yes\n", "cismult 3\n" ] );
    is( $info->{mult}, 3, "hh-TDA multiplicity from cismult" );
    my @hh = main::parse_energies( "$fx/hhtda_triplet.grad.tera.out", $info, 3 );
    is( scalar(@hh), 3, "hh-TDA triplet rows" );
    $info = main::template_info( [ "hhtda yes\n" ] );
    dies_like( sub { main::parse_energies( "$fx/hhtda_triplet.grad.tera.out", $info, 1 ) }, qr/found 0/, "singlet run finds no triplet rows" );
};

subtest 'run_tera_ic.pl oscillator strengths' => sub {
    require "$root/run_tera_ic.pl";
    my %want = (
        fomo   => [ "casci yes\n", { 2 => "0.0733",     3 => "0.1950" } ],
        casscf => [ "casci yes\n", { 2 => "0.3283",     3 => "0.0000" } ],
        hhtda  => [ "hhtda yes\n", { 2 => "0.00222222", 3 => "0.78597363" } ],
        tda    => [ "cis yes\n",   { 2 => "0.0003",     3 => "0.2244" } ],
        fomo_triplet => [ "casci yes\ncastargetmult 3\n", { 2 => "0.0057" } ],
        rpa          => [ "rpa yes\n",   { 2 => "0.1600" } ],
    );
    for my $m ( sort keys %want ) {
        my ( $tpl, $f ) = @{ $want{$m} };
        my $info = main::template_info( [ split /(?<=\n)/, $tpl ] );
        my $nfs  = 1 + scalar keys %$f;
        my @e    = main::parse_energies( "$fx/$m.grad.tera.out", $info, $nfs );
        my %got  = main::parse_oscillators( "$fx/$m.grad.tera.out", $info, 1, $nfs, \@e );
        is_deeply( \%got, $f, "$m: f from the ground state" );
    }
    # nis = 2: computed from |T| and energies; TeraChem printed 0.0137 for 2 -> 3.
    my $info = main::template_info( ["casci yes\n"] );
    my @e    = main::parse_energies( "$fx/fomo.grad.tera.out", $info, 3 );
    my %got  = main::parse_oscillators( "$fx/fomo.grad.tera.out", $info, 2, 3, \@e );
    ok( abs( $got{3} - 0.0137 ) < 5e-4, "fomo 2 -> 3 from |T|: $got{3} vs printed 0.0137" );
    # TDA 2 -> 3: root 1 -> root 2 in the excited-state table.
    $info = main::template_info( ["cis yes\n"] );
    @e    = main::parse_energies( "$fx/tda.grad.tera.out", $info, 3 );
    %got  = main::parse_oscillators( "$fx/tda.grad.tera.out", $info, 2, 3, \@e );
    my $de = $e[2] - $e[1];
    ok( abs( $got{3} - 2 / 3 * $de * 0.0511**2 ) < 1e-6, "tda 2 -> 3 uses the root 1 -> 2 dipole" );
};

subtest 'run-tera-cas.pl --check-options (used by NX at startup)' => sub {
    my $d = tempdir( CLEANUP => 1 );
    open my $fh, '>', "$d/ok.par"; print $fh "couplings = current\n"; close $fh;
    open $fh, '>', "$d/bad.par"; print $fh "coupling = all\n"; close $fh;
    my $out = `"$^X" "$root/run-tera-cas.pl" --check-options "$d/ok.par" 2>&1`;
    is( $? >> 8, 0, "valid file: exit 0" );
    like( $out, qr/couplings\s+= current/, "prints the options in effect" );
    $out = `"$^X" "$root/run-tera-cas.pl" --check-options "$d/bad.par" 2>&1`;
    isnt( $? >> 8, 0, "unknown key: non-zero exit" );
    like( $out, qr/Unknown option 'coupling'/, "names the bad key" );
    $out = `"$^X" "$root/run-tera-cas.pl" --check-options "$d/none.par" 2>&1`;
    like( $out, qr/defaults; no terachem.par/, "missing file: defaults" );
};

subtest 'examples/ templates' => sub {
    my %want = ( casscf => "cas", "fomo-casci" => "cas", tda => "cis", "hh-tda" => "cis", "rpa-tdba" => "rpa" );
    for my $m ( sort keys %want ) {
        my $f = "$root/examples/$m/tera.sp";
        ok( -e $f, "$m: template exists" ) or next;
        open my $fh, '<', $f; my @l = <$fh>; close $fh;
        my $i = main::template_info( \@l );
        ok( $i->{ $want{$m} }, "$m: recognised as $want{$m}" );
        my @managed = grep { exists $i->{kw}{$_} } qw(run castarget cistarget nacstate1 nacstate2 scrdir);
        is_deeply( \@managed, [], "$m: no keywords the interface manages" );
    }
};

subtest 'run_tera_ic.pl end to end with a fake TeraChem' => sub {
    # initcond.pl layout: BASE/TEMP is the working folder, BASE/DEBUG takes stderr.
    my %e = ( 1 => "-78.01902772", 2 => "-77.71732133", 3 => "-77.59084718" );    # casscf fixture
    for my $case ( [ 1, { 2 => [ 1, 2, "0.3283" ], 3 => [ 1, 3, "0.0000" ] } ],
                   [ 2, { 1 => [ 1, 2, "0.3283" ], 3 => [ 2, 3, "0.3602" ] } ] ) {
        my ( $nis, $want ) = @$case;
        my $base = tempdir( CLEANUP => 1 );
        mkdir "$base/$_" for qw(TEMP DEBUG tc tc/bin);
        open my $fh, '>', "$base/tc/bin/terachem";
        print $fh "#!/bin/sh\nmkdir -p scr.geom\ncat '$fx/casscf.grad.tera.out'\n";
        close $fh;
        chmod 0755, "$base/tc/bin/terachem";
        system( "cp", "$root/tests/nx/MD-TERA-CASSCF-NAD-VEC/geom", "$base/TEMP/geom" );
        system( "cp", "$root/examples/casscf/tera.sp", "$base/TEMP/tera.sp" );
        open $fh, '>', "$base/TEMP/initqp_input";
        print $fh " &dat\n nis = $nis\n nfs = 3\n lvprt = 1\n /\n";
        close $fh;
        my $out = `cd "$base/TEMP" && TeraChem="$base/tc" "$^X" "$root/run_tera_ic.pl" 2>&1`;
        is( $? >> 8, 0, "nis = $nis: exit 0" ) or diag $out;
        for my $ifs ( sort keys %$want ) {
            my ( $lo, $hi, $f ) = @{ $want->{$ifs} };
            is( slurp("$base/TEMP/epot.$ifs"), "$e{$lo}\n$e{$hi}\n", "nis = $nis: epot.$ifs holds states $lo and $hi" );
            is( slurp("$base/TEMP/oos.$ifs"), "$f\n", "nis = $nis: oos.$ifs" );
        }
        ok( !-e "$base/TEMP/epot.$nis", "nis = $nis: no file for nis itself" );
        open $fh, '<', "$base/TEMP/ic.sp"; my $sp = join "", <$fh>; close $fh;
        like( $sp, qr/^run\s+energy$/m, "input runs an energy" );
        unlike( $sp, qr/^\s*(castarget|nacstate1|scrdir)\b/m, "no dynamics-only keywords" );
    }
};

subtest 'phase_ref = last: phase memory' => sub {
    my $d = tempdir( CLEANUP => 1 );
    local ( $main::nat, $main::ncoup ) = ( 2, 3 );
    local $main::phase_mem = "$d/mem";
    local $main::opt{phase_ref} = "last";
    chdir $d;
    # pair 0 present now and before; pair 1 missing in oldh but remembered; pair 2 absent
    main::write_lines( "oldh", [ "1 0 0\n", "0 1 0\n", "0 0 0\n", "0 0 0\n", "0 0 0\n", "0 0 0\n" ] );
    main::write_lines( $main::phase_mem, [ "9 9 9\n", "9 9 9\n", "-2 0 0\n", "0 -2 0\n", "0 0 0\n", "0 0 0\n" ] );
    my $true = main::phase_memory_into_oldh( { 0 => 1, 1 => 1 } );
    is_deeply( main::read_lines("oldh"), [ "1 0 0\n", "0 1 0\n", "-2 0 0\n", "0 -2 0\n", "0 0 0\n", "0 0 0\n" ],
        "only the missing pair is taken from memory" );
    is( $true->[2], "0 0 0\n", "the real oldh is returned for restoring" );
    main::write_lines( "nad_vectors", [ "3 0 0\n", "0 3 0\n", "0 0 0\n", "0 0 0\n", "0 0 5\n", "0 0 5\n" ] );
    main::update_phase_memory("nad_vectors");
    is_deeply( main::read_lines($main::phase_mem), [ "3 0 0\n", "0 3 0\n", "-2 0 0\n", "0 -2 0\n", "0 0 5\n", "0 0 5\n" ],
        "memory keeps the last non-zero vector of each pair" );
    main::write_lines( "oldh", [ "1 0 0\n", "0 1 0\n", "0 0 0\n", "0 0 0\n", "0 0 0\n", "0 0 0\n" ] );
    my $none = main::phase_memory_into_oldh( { 0 => 1 } );
    ok( !defined $none, "a remembered pair that is not computed now is left alone" );
    chdir $root;
};

subtest 'NewtonX 2.6: reference set so that every sign is kept' => sub {
    my $d = tempdir( CLEANUP => 1 );
    local ( $main::nat, $main::ncoup, $main::istep, $main::lvprt ) = ( 1, 3, 5, 1 );
    local $ENV{NX} = $d;
    chdir $d;
    open my $fh, '>', "phase_correction" or die;
    close $fh;
    chmod 0755, "phase_correction";
    open $fh, '>', "sh.inp" or die;
    print $fh " &input\n vdoth = 0\n /\n";
    close $fh;
    main::write_lines( "nad_vectors-dt",  [ "3 0 0\n", "0 0 0\n", "1 1 0\n" ] );
    main::write_lines( "nad_vectors-2dt", [ "10 0 0\n", "2 0 0\n", "0 0 0\n" ] );
    main::write_lines( "nad_vectors",     [ "1 0 0\n", "-2 0 0\n", "0 0 0\n" ] );
    main::shield_returning_pairs( { 0 => 1, 1 => 1 } );
    my @h1 = ( [ 3, 0, 0 ], [ 0, 0, 0 ], [ 1, 1, 0 ] );
    my @h0 = ( [ 1, 0, 0 ], [ -2, 0, 0 ], [ 0, 0, 0 ] );
    my @h2 = map { [ split ] } @{ main::read_lines("nad_vectors-2dt") };
    for my $k ( 0 .. 2 ) {
        my @href = map { 2 * $h1[$k][$_] - $h2[$k][$_] } 0 .. 2;
        ok( abs( $href[$_] - $h0[$k][$_] ) < 1e-12, "pair $k component $_: href = h(t)" ) for 0 .. 2;
    }
    unlink "phase_correction";
    main::write_lines( "nad_vectors-2dt", [ "10 0 0\n", "2 0 0\n", "0 0 0\n" ] );
    main::shield_returning_pairs( { 0 => 1 } );
    is( main::read_lines("nad_vectors-2dt")->[0], "10 0 0\n", "no change without NewtonX's phase_correction (NX 2.4)" );
    chdir $root;
};

done_testing();
