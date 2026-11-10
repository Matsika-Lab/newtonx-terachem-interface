#!/usr/bin/env perl
# SPDX-License-Identifier: GPL-3.0-or-later
#
#====================================================================================
#
# Interface between TeraChem and NewtonX built from the template
# provided by Mario Barbatti, 2021.
#
# Authors:
# Dakshitha Abeygunewardane
# Vaibhav Singh
# Spiridoula Matsika
#
# Matsika Lab,
# Temple University, USA.
# 2025.
#
# The 2026-11-09 revision (version 2.0) was refactored and improved with Claude Code
# (Anthropic), using the Claude Opus 5.5 model. See the Credits section of README.md.
#
# Copyright (C) 2025-2026 the authors above. This program is free software: you can
# redistribute it and/or modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version. It is distributed WITHOUT ANY WARRANTY; see
# the LICENSE file for details.
#
#====================================================================================
#
# NewtonX calls this script from TRAJ/TEMP at every time step. NewtonX has already
# copied JOB_NAD/* and terachem.par into TEMP. The script
#   1. writes one TeraChem input per job: a gradient for the current state and one
#      coupling job per state pair that is needed,
#   2. runs TeraChem for each job, one after another, on the GPU(s) it was given,
#   3. writes epot, grad, grad.all and the phase-corrected nad_vectors/newh for NewtonX.
#
# Options are read from terachem.par (key = value). See docs/terachem-par.md for the full list.
#
use strict;
use warnings;
use File::Copy qw(move copy);
use File::Path qw(remove_tree mkpath);
use Cwd qw(abs_path getcwd);

BEGIN {
    die "run-tera-cas.pl: the NX environment variable is not set.\n" unless defined $ENV{"NX"};
}
use lib join( '/', $ENV{"NX"}, "lib" );
use colib_perl;

our $VERSION = "2.0.0";

#====================================================================================
#                                 DEFAULT OPTIONS
#====================================================================================
# Do not edit these to change a run. Put the keys in terachem.par instead, in the
# trajectory folder (next to control.dyn).

our %DEFAULTS = (
    # CASSCF only ('casscf yes'). 1 = start from the previous step's CASSCF orbitals and
    # skip the SCF (maxit 0). The coupling jobs then start from the same step's gradient
    # job orbitals.
    use_prev_wf => 0,

    # FOMO-CASCI, TDA/TDDFT and hh-TDA (no 'casscf yes'). 1 = start the SCF from the
    # previous step's converged SCF orbitals; the SCF still runs to convergence. The
    # coupling jobs start from the same step's gradient job orbitals.
    use_prev_scf_wf => 0,

    # Which coupling vectors to compute. TeraChem gives one coupling per run.
    #   nx         : the pairs NX lists in transmomin each step, set by jiri.inp (KROSS,
    #                CASCADE, CURRENT, NEVER_STATE, INCLUDE_PAIR) and THRES in control.dyn.
    #                Without jiri.inp, NX 2.4 lists every pair (like 'all' below), so
    #                give a jiri.inp (e.g. kross = 0, current = 1 for neighbours).
    #   neighbours : current state with the states just below and above (up to 2 runs)
    #   current    : current state with every other state (nstat-1 runs)
    #   all        : every pair of states (nstat*(nstat-1)/2 runs)
    couplings => "nx",

    # Phase reference for a coupling pair that was not computed at the previous step.
    #   last     : compare such a pair with its last computed vector, so its sign stays
    #              continuous across the gap. Only the phase fix uses it; NX's
    #              interpolation still starts from the previous step.
    #   previous : compare with the previous step only (as NX's template and versions
    #              before 2.0). A pair that returns after a gap keeps TeraChem's sign.
    phase_ref => "last",

    # 1 = keep a Molden file of the gradient job's orbitals for every step.
    archive_molden => 1,

    # 1 = keep the CASSCF orbitals (c0.casscf) for every step.
    archive_wf => 1,
);

#====================================================================================

our ( $mld, $mdle, $BASEDIR, $DEBUG, $JAD, $JND, $ctd );
our ( $tpp, $tpp_outfile, $parfile, $template_single );
our ( $old_scf_guess, $old_guess, $molden_ar, $wf_ar, $phase_mem );
our ( $nat, $istep, $nstat, $nstatdyn, $ndamp, $kt, $dt, $t, $tmax, $nintc );
our ( $nxrestart, $thres, $killstat, $timekill, $prog, $lvprt, $etot_jump, $etot_drift, $mem );
our ( @symb, @x, @y, @z );
our ( $typeofinput, $run_flag, $layout, %opt, $vdoth_nx );
our ( @epot, @gx, @gy, @gz, @hx, @hy, @hz, $ncoup );
our $CLI = 0;
$mdle = "run-tera-cas.pl:";

if ( !caller && @ARGV && $ARGV[0] eq "--check-options" ) {
    check_options_cli( $ARGV[1] // "terachem.par" );
    exit 0;
}
main() unless caller;

#====================================================================================
#                                MAIN EXECUTION BLOCK
#====================================================================================

sub main {
    define_variables();
    %opt = read_options($parfile);
    check_environment();
    write_debug_prologue();

    determine_dynamics_type();
    read_geom();
    $layout = detect_layout();
    my @jobs = plan_jobs();
    prepare_casscf_guess();
    write_xyz( \@jobs );

    foreach my $job (@jobs) {
        write_job_input($job);
        run_job($job);
        save_orbitals() if $job->{kind} eq "grad";
    }

    read_energy( $jobs[0] );
    write_energy();
    read_gradients( $jobs[0] );
    write_grad();
    # Coupling vectors: written on every step. On an adiabatic step (typeofdyn 1) no
    # pair is computed, so zero couplings are written instead of keeping the last
    # step's. With TD-BA (vdoth = 2) NX writes the couplings itself.
    treat_nacme( [ grep { $_->{kind} eq "nac" } @jobs ] ) if $vdoth_nx == 0;
}

#====================================================================================
#                                SETUP
#====================================================================================

sub define_variables {
    $mld  = $ENV{"NX"};
    $mdle = "run-tera-cas.pl:";

    $tpp             = $ENV{"TeraChem"};
    $tpp_outfile     = "tera.out";
    $parfile         = "terachem.par";
    $template_single = "tera.sp";

    $old_guess     = "../INFO_RESTART/WF_OLD/c0";
    $old_scf_guess = "../INFO_RESTART/WF_OLD/c0_scf";
    $molden_ar     = "../INFO_RESTART/MOLDEN_ARCHIVE";
    $wf_ar         = "../INFO_RESTART/WF_ARCHIVE";
    $phase_mem     = "../INFO_RESTART/WF_OLD/nac_phase_ref";
    mkpath( [ $molden_ar, $wf_ar, "../INFO_RESTART/WF_OLD" ], 0, 0755 );

    $BASEDIR = getcwd();
    $DEBUG   = "DEBUG";
    $JAD     = "JOB_AD";
    $JND     = "JOB_NAD";
    $ctd     = "control.d";

    ( $nat, $istep, $nstat, $nstatdyn, $ndamp, $kt, $dt, $t, $tmax, $nintc, $mem, $nxrestart, $thres, $killstat, $timekill, $prog, $lvprt, $etot_jump, $etot_drift ) =
      load_status( $ctd, $mdle );

    $run_flag = -s "which_run_is_that" ? read_single_value( "which_run_is_that", "" ) : "";
    $run_flag = "" unless defined $run_flag;
}

sub read_options {
    #
    # Reads terachem.par. Accepted forms: "key = value", "key value", optional commas,
    # comments after '#' or '!', and NX namelist markers (&... and /). Unknown keys and
    # bad values stop the run, so a typo cannot be silently ignored.
    #
    my ($file) = @_;
    my %o = %DEFAULTS;
    return %o unless -e $file;

    open my $fh, '<', $file or tc_fail("Cannot open $file: $!");
    while ( my $line = <$fh> ) {
        $line =~ s/[#!].*//;
        $line =~ s/,/ /g;
        next if $line =~ /^\s*$/;
        next if $line =~ /^\s*[&\/]/;
        my ( $key, $value ) = $line =~ /^\s*(\w+)\s*=?\s*(\S+)\s*$/
          or tc_fail("Cannot read this line of $file: $line");
        $key = lc $key;
        tc_fail("Unknown option '$key' in $file. Known options: " . join( ", ", sort keys %DEFAULTS ) . ".")
          unless exists $DEFAULTS{$key};
        $o{$key} = $value;
    }
    close $fh;

    foreach my $k (qw(use_prev_wf use_prev_scf_wf archive_molden archive_wf)) {
        $o{$k} = 1 if $o{$k} =~ /^(yes|true)$/i;
        $o{$k} = 0 if $o{$k} =~ /^(no|false)$/i;
        tc_fail("Option $k in $file must be 0 or 1, not '$o{$k}'.") unless $o{$k} =~ /^[01]$/;
    }
    $o{couplings} = lc $o{couplings};
    $o{couplings} = "neighbours" if $o{couplings} eq "neighbors";
    tc_fail("Option couplings in $file must be nx, neighbours, current or all, not '$o{couplings}'.")
      unless $o{couplings} =~ /^(nx|neighbours|current|all)$/;
    $o{phase_ref} = lc $o{phase_ref};
    tc_fail("Option phase_ref in $file must be previous or last, not '$o{phase_ref}'.")
      unless $o{phase_ref} =~ /^(previous|last)$/;
    return %o;
}

sub check_options_cli {
    #
    # 'run-tera-cas.pl --check-options [file]': validates terachem.par and prints the
    # options in effect. Used by NX at startup (check_thirdparty in colib_perl.pm), so a
    # typo stops the run before any TeraChem time is spent.
    #
    my ($file) = @_;
    $CLI = 1;
    my %o = eval { read_options($file) };
    if ($@) { print STDERR $@; exit 2; }
    print "TeraChem interface $VERSION, options " . ( -e $file ? "from $file" : "(defaults; no terachem.par)" ) . ":\n";
    printf " %-16s = %s\n", $_, $o{$_} foreach sort keys %o;
}

sub check_environment {
    tc_fail("The TeraChem environment variable is not set.") unless defined $tpp && $tpp ne "";
    tc_fail("TeraChem executable not found at $tpp/bin/terachem. Check the TeraChem environment variable.")
      unless -x "$tpp/bin/terachem";
}

sub write_debug_prologue {
    print_STDOUT( "$mdle version $VERSION, options: "
          . join( " ", map { "$_=$opt{$_}" } sort keys %opt )
          . ( -e $parfile ? " (from $parfile)" : " (defaults, no $parfile)" ) . "\n",
        $istep, $kt );
    if ( $lvprt >= 3 ) {
        print_STDOUT( "$mdle running in $BASEDIR\n", $istep, $kt );
        print_STDOUT( "$mdle Dynamics control: \n", $istep, $kt );
        print_STDOUT( "$nat $istep $nstat $nstatdyn $ndamp $kt $dt $t $tmax \n", $istep, $kt );
        print_STDOUT( "$nintc $mem $nxrestart $thres $killstat $timekill $prog $lvprt\n", $istep, $kt );
        print_STDOUT( "$etot_jump $etot_drift\n\n", $istep, $kt );
    }
}

sub determine_dynamics_type {
    #
    # Decides whether this call needs coupling vectors ('jnd') or only energies and the
    # gradient ('jad').
    #   * NX writes the step type to typeofdyn.out. Type 1 is an adiabatic step: pure
    #     adiabatic dynamics, or every energy gap above THRES (control.dyn).
    #   * Otherwise couplings are computed here only with vdoth = 0 in sh.inp. With
    #     vdoth = 2 (TD-BA), NX builds the couplings itself from the energies.
    #   * vdoth = 1 or < 0 need wavefunction overlaps, which this interface cannot give.
    # NX copies JOB_NAD to JOB_AD when JOB_AD is missing, so both folders are usually in
    # TEMP and cannot tell the step type by themselves.
    #
    my $type = 2;
    if ( -s "typeofdyn.out" ) {
        open( my $fh, '<', "typeofdyn.out" ) or tc_fail("Cannot open typeofdyn.out: $!");
        $type = <$fh>;
        close($fh);
        $type =~ s/\s+//g;
    }
    elsif ( -e $JAD && !-e $JND ) {
        $type = 1;
    }
    elsif ( !-e $JAD && !-e $JND ) {
        tc_fail("Could not determine dynamics type. Neither $JAD nor $JND found.");
    }

    # moldyn.pl treats a missing vdoth as 2 (TD-BA); do the same.
    my $vdoth = getkeyword( "sh.inp", "vdoth", 2 );
    $vdoth = 2 if !defined $vdoth || $vdoth eq "";
    $vdoth_nx = $vdoth;
    if ( $type == 1 ) {
        $typeofinput = "jad";
    }
    elsif ( $vdoth == 0 ) {
        $typeofinput = "jnd";
        my $getphase = getkeyword( "sh.inp", "getphase", 1 );
        print_STDOUT( "$mdle WARNING: getphase = $getphase in sh.inp, but this interface always fixes the coupling phase by the scalar product with the previous step (getphase = 1).\n", $istep, $kt )
          if $getphase ne "" && $getphase != 1;
    }
    elsif ( $vdoth == 2 ) {
        $typeofinput = "jad";    # TD-BA: NX computes the couplings after this call
    }
    else {
        tc_fail("vdoth = $vdoth in sh.inp needs wavefunction overlaps, which the TeraChem interface does not provide. Use vdoth = 0 (coupling vectors) or vdoth = 2 (TD-BA).");
    }
    if ( $lvprt >= 2 ) {
        print_STDOUT( "$mdle step type $type, vdoth $vdoth: " . ( $typeofinput eq "jnd" ? "computing coupling vectors" : "energies and gradient only" ) . ".\n", $istep, $kt );
    }
}

sub read_geom {
    open( my $gm_fh, '<', "geom" ) or tc_fail("Cannot open geom: $!");
    @symb = @x = @y = @z = ();
    while ( my $line = <$gm_fh> ) {
        my @f = split ' ', $line;
        next unless @f;
        tc_fail("Bad line in geom: $line") unless @f >= 5;
        push @symb, $f[0];
        push @x,    $f[2];
        push @y,    $f[3];
        push @z,    $f[4];
    }
    close($gm_fh);
    tc_fail( "geom has " . scalar(@symb) . " atoms but control.d says nat = $nat." ) unless @symb == $nat;
}

#====================================================================================
#                                JOB PLANNING AND INPUTS
#====================================================================================

sub detect_layout {
    #
    # 'single': one template, JOB_NAD/tera.sp, from which every input is written.
    # 'legacy': JOB_NAD/GRAD, NAD_N1N0 and NAD_N1N2, each with its own start.sp.
    #
    if ( -e $template_single ) {
        # GRAD/start.sp in TEMP is normally the input this script wrote at the last step;
        # warn only when the user's template folder has one too.
        print_STDOUT( "$mdle Both $template_single and GRAD/start.sp found; using $template_single.\n", $istep, $kt )
          if grep { -e "$_/GRAD/start.sp" } ( $JND, $JAD );
        return "single";
    }
    return "legacy" if -e "GRAD/start.sp";
    tc_fail("No TeraChem template found. Put tera.sp in JOB_NAD/ (or the old GRAD, NAD_N1N0 and NAD_N1N2 folders with start.sp).");
}

sub coupling_pairs {
    #
    # Returns the state pairs [i, j], i < j, NX numbering (1 = lowest state), that need a
    # coupling run at this call.
    #
    my ( $mode, $n, $ns, $flag, $transmomin ) = @_;
    return () if $ns <= 1 || $flag eq "second run";    # after a hop NX only needs the new gradient
    my @pairs;
    if ( $mode eq "nx" ) {
        @pairs = read_transmomin( $transmomin // "transmomin", $ns );
    }
    elsif ( $mode eq "neighbours" ) {
        push @pairs, [ $n - 1, $n ] if $n > 1;
        push @pairs, [ $n, $n + 1 ] if $n < $ns;
    }
    elsif ( $mode eq "current" ) {
        foreach my $k ( 1 .. $ns ) {
            next if $k == $n;
            push @pairs, $k < $n ? [ $k, $n ] : [ $n, $k ];
        }
    }
    else {
        foreach my $j ( 2 .. $ns ) {
            foreach my $i ( 1 .. $j - 1 ) { push @pairs, [ $i, $j ]; }
        }
    }
    return @pairs;
}

sub read_transmomin {
    #
    # Reads the coupling list NX writes every step (write_pair.f90): a 'CI' line, then
    # one line '1 i 1 j' per pair of states i, j (1 = lowest state). An empty list means
    # NX needs no couplings at this step.
    #
    my ( $file, $ns ) = @_;
    tc_fail("$file not found. NX writes it every step from jiri.inp and THRES; set couplings in terachem.par to choose the couplings without it.")
      unless -e $file;
    open my $fh, '<', $file or tc_fail("Cannot open $file: $!");
    my ( @pairs, %seen );
    while ( my $line = <$fh> ) {
        next unless $line =~ /^\s*\d+\s+(\d+)\s+\d+\s+(\d+)\s*$/;
        my ( $i, $j ) = $1 < $2 ? ( $1, $2 ) : ( $2, $1 );
        tc_fail("Bad state pair ($1, $2) in $file for nstat = $ns.") if $i < 1 || $j > $ns || $i == $j;
        push @pairs, [ $i, $j ] unless $seen{"$i-$j"}++;
    }
    close $fh;
    return sort { pair_index(@$a) <=> pair_index(@$b) } @pairs;
}

sub pair_index {
    #
    # Position of pair (i, j), i < j, in NX's coupling list:
    # (2,1), (3,1), (3,2), (4,1), ... -> 0, 1, 2, 3, ...
    #
    my ( $i, $j ) = @_;
    return ( $j - 1 ) * ( $j - 2 ) / 2 + ( $i - 1 );
}

sub plan_jobs {
    my @jobs = ( { kind => "grad", dir => "GRAD" } );
    my @pairs = $typeofinput eq "jnd" ? coupling_pairs( $opt{couplings}, $nstatdyn, $nstat, $run_flag ) : ();

    # Old layout: the two neighbour couplings keep their own folders and templates. Any
    # other pair is written from the coupling template, in its own NAC_i_j folder.
    my ($legacy_nac) = grep { -e $_ } ( "NAD_N1N0/start.sp", "NAD_N1N2/start.sp" );

    foreach my $p (@pairs) {
        my ( $i, $j ) = @$p;
        my $job = { kind => "nac", pair => [ $i, $j ], dir => "NAC_${i}_${j}", template => $template_single };
        if ( $layout eq "legacy" ) {
            if    ( $j == $nstatdyn && $i == $nstatdyn - 1 ) { $job->{dir} = "NAD_N1N0"; }
            elsif ( $i == $nstatdyn && $j == $nstatdyn + 1 ) { $job->{dir} = "NAD_N1N2"; }
            $job->{template} = $job->{dir} =~ /^NAD_N1N[02]$/ ? "$job->{dir}/start.sp" : $legacy_nac;
            tc_fail("No coupling template (NAD_N1N0/start.sp or NAD_N1N2/start.sp) for the pair ($i, $j).")
              unless $job->{template};
        }
        push @jobs, $job;
    }
    $jobs[0]{template} = $layout eq "single" ? $template_single : "GRAD/start.sp";

    if ( $lvprt >= 2 ) {
        print_STDOUT( "$mdle coupling pairs this step (couplings = $opt{couplings}): "
              . ( @pairs ? join( " ", map { "$_->[1]-$_->[0]" } @pairs ) : "none" ) . "\n", $istep, $kt );
    }

    # Read every template now, before any input is written, so a job never starts from
    # an input this script wrote earlier.
    foreach my $job (@jobs) {
        tc_fail("Template input file '$job->{template}' not found.") unless -e $job->{template};
        open my $tfh, '<', $job->{template} or tc_fail("Could not open '$job->{template}': $!");
        $job->{lines} = [<$tfh>];
        close $tfh;
        mkpath( $job->{dir}, 0, 0755 ) unless -d $job->{dir};
    }

    # Refuse RPA coupling jobs before any TeraChem time is spent (see write_job_input).
    if ( @jobs > 1 ) {
        tc_fail("$jobs[1]{template} uses full TDDFT (rpa yes). TeraChem gives no RPA coupling vectors (it writes zeros). Use TDA (cis yes) for coupling vectors, or TD-BA (vdoth = 2 in sh.inp) with RPA.")
          if template_info( $jobs[1]{lines} )->{rpa};
    }
    return @jobs;
}

sub prepare_casscf_guess {
    #
    # A user-supplied first CASSCF guess is used once, when no previous-step orbitals
    # exist yet: JOB_NAD/c0.casscf, or (old layout) JOB_NAD/GRAD/scr.geom/c0.casscf.
    # Only used with use_prev_wf = 1.
    #
    return unless $opt{use_prev_wf};
    return if -e $old_guess;
    foreach my $initial ( "c0.casscf", "GRAD/scr.geom/c0.casscf" ) {
        if ( -e $initial ) {
            copy( $initial, $old_guess ) or tc_fail("Failed to copy initial CASSCF guess $initial: $!");
            print_STDOUT( "$mdle Using $initial as the first CASSCF guess.\n", $istep, $kt );
            return;
        }
    }
}

sub write_xyz {
    my ($jobs) = @_;
    my $au2ang = units("au2ang");
    open my $fgeom, '>', "geom.xyz" or tc_fail("Could not open geom.xyz: $!");
    print $fgeom scalar(@symb), "\n\n";
    for my $i ( 0 .. $#symb ) {
        my $x_ang = $x[$i] * $au2ang;
        my $y_ang = $y[$i] * $au2ang;
        my $z_ang = $z[$i] * $au2ang;
        print $fgeom "$symb[$i]   $x_ang   $y_ang   $z_ang\n";
    }
    close $fgeom;
    foreach my $job (@$jobs) {
        copy( "geom.xyz", "$job->{dir}/geom.xyz" ) or tc_fail("Failed to copy geom.xyz to $job->{dir}: $!");
    }
}

sub template_info {
    #
    # Reads the active (uncommented) keywords of a TeraChem input.
    #
    my ($lines) = @_;
    my %kw;
    foreach my $line (@$lines) {
        my $l = $line;
        $l =~ s/#.*//;
        next unless $l =~ /^\s*(\S+)(?:\s+(.*?))?\s*$/;
        $kw{ lc $1 } = defined $2 ? $2 : "";
    }
    my %info;
    $info{casscf} = ( ( $kw{casscf} // "" ) =~ /^yes/i ) ? 1 : 0;
    $info{cas}    = ( $info{casscf} || ( ( $kw{casci} // "" ) =~ /^yes/i ) ) ? 1 : 0;
    $info{rpa}    = ( ( $kw{rpa} // "" ) =~ /^yes/i ) ? 1 : 0;
    $info{cis}    = ( ( ( $kw{cis} // "" ) =~ /^yes/i ) || ( ( $kw{hhtda} // "" ) =~ /^yes/i ) || $info{rpa} ) ? 1 : 0;
    # Multiplicity of the dynamics states: castargetmult for CAS methods, cismult for
    # TDA/TDDFT and hh-TDA. One multiplicity per run.
    $info{mult} = ( $info{cas} ? $kw{castargetmult} : $kw{cismult} ) // 1;
    $info{mult} =~ s/\s.*//;
    $info{kw} = \%kw;
    return \%info;
}

sub set_keyword {
    #
    # Sets one keyword: replaces every active line with that keyword by one line, in
    # place, or inserts it before 'end' (or at the bottom) if it is not there.
    #
    my ( $lines, $key, $value ) = @_;
    my $done = 0;
    my @out;
    foreach my $line (@$lines) {
        if ( $line !~ /^\s*#/ && $line =~ /^\s*\Q$key\E(\s|$)/i ) {
            next if $done;
            push @out, sprintf( "%-15s %s\n", $key, $value );
            $done = 1;
            next;
        }
        push @out, $line;
    }
    insert_lines( \@out, sprintf( "%-15s %s\n", $key, $value ) ) unless $done;
    @$lines = @out;
}

sub remove_keyword {
    my ( $lines, $key ) = @_;
    @$lines = grep { /^\s*#/ || !/^\s*\Q$key\E(\s|$)/i } @$lines;
}

sub insert_lines {
    #
    # Inserts lines before the first active 'end' line, or at the bottom.
    #
    my ( $lines, @new ) = @_;
    for my $i ( 0 .. $#$lines ) {
        if ( $lines->[$i] =~ /^\s*end\s*$/i ) {
            splice @$lines, $i, 0, @new;
            return;
        }
    }
    $lines->[-1] .= "\n" if @$lines && $lines->[-1] !~ /\n$/;
    push @$lines, @new;
}

sub write_job_input {
    my ($job) = @_;
    my @lines = @{ $job->{lines} };
    my $info  = template_info( \@lines );
    $job->{info} = $info;
    if ( $info->{cas} && !exists $info->{kw}{castargetmult} && ( $info->{kw}{cassinglets} // 1 ) =~ /^0\b/ ) {
        tc_fail("$job->{template} asks for no singlets (cassinglets 0) but sets no castargetmult. Add 'castargetmult 3' (or the multiplicity you run).");
    }
    my $n = $nstatdyn;

    # Run type and states. TeraChem counts states from 0 within the requested
    # multiplicity; NX counts from 1.
    if ( $job->{kind} eq "grad" ) {
        set_keyword( \@lines, "run", "gradient" ) if $layout eq "single";
        if ( $info->{cas} ) {
            set_keyword( \@lines, "castarget", $n - 1 );
        }
        elsif ( $info->{cis} ) {
            set_keyword( \@lines, "cistarget", $n - 1 );
        }
        else {
            tc_fail("$job->{template}: no 'casscf yes', 'casci yes', 'cis yes', 'rpa yes' or 'hhtda yes' found, so the target state cannot be set.");
        }
        # The old templates may set both; keep them consistent.
        foreach my $k (qw(castarget cistarget)) {
            set_keyword( \@lines, $k, $n - 1 ) if exists $info->{kw}{$k};
        }
    }
    else {
        # TeraChem 1.96 finishes RPA coupling runs normally but writes a zero vector.
        tc_fail("$job->{template} uses full TDDFT (rpa yes). TeraChem gives no RPA coupling vectors (it writes zeros). Use TDA (cis yes) for coupling vectors, or TD-BA (vdoth = 2 in sh.inp) with RPA.")
          if $info->{rpa};
        my ( $i, $j ) = @{ $job->{pair} };
        if ( $layout eq "single" ) {
            set_keyword( \@lines, "run", "coupling" );
            remove_keyword( \@lines, $_ ) for qw(castarget cistarget);    # gradient-only keywords
        }
        set_keyword( \@lines, "nacstate1", $i - 1 );
        set_keyword( \@lines, "nacstate2", $j - 1 );
    }

    # TeraChem writes its scratch to ./scr.geom (from 'coordinates geom.xyz'); run_job
    # clears it before the run and moves it into the job folder after. scrdir is not
    # used: TeraChem lowercases keyword values, which breaks paths with capitals.
    remove_keyword( \@lines, "scrdir" );
    set_keyword( \@lines, "coordinates", "geom.xyz" );

    # Wavefunction guess.
    my $guess;
    if ( $info->{casscf} && $opt{use_prev_wf} ) {
        if ( $job->{kind} eq "nac" && -e "GRAD/scr.geom/c0.casscf" ) {
            $guess = abs_path("GRAD/scr.geom/c0.casscf");    # this step's CASSCF orbitals
        }
        elsif ( -e $old_guess ) {
            $guess = abs_path($old_guess);                   # previous step's CASSCF orbitals
        }
        if ($guess) {
            remove_keyword( \@lines, $_ ) for qw(guess maxit convthre);
            insert_lines( \@lines, "guess           $guess\n", "maxit           0\n", "convthre        1e7\n" );
        }
    }
    elsif ( !$info->{casscf} && $opt{use_prev_scf_wf} ) {
        if ( $job->{kind} eq "nac" && -e "GRAD/scr.geom/c0" ) {
            $guess = abs_path("GRAD/scr.geom/c0");           # this step's SCF orbitals
        }
        elsif ( $job->{kind} eq "grad" && -e $old_scf_guess ) {
            $guess = abs_path($old_scf_guess);               # previous step's SCF orbitals
        }
        set_keyword( \@lines, "guess", $guess ) if $guess;
    }

    open my $fh, '>', "$job->{dir}/start.sp" or tc_fail("Could not write '$job->{dir}/start.sp': $!");
    print $fh @lines;
    close $fh;
}

#====================================================================================
#                                RUNNING TERACHEM
#====================================================================================

sub run_job {
    my ($job) = @_;
    my $dir = $job->{dir};
    if ( $lvprt >= 3 ) { print_STDOUT( "$mdle Running calculation in $dir.\n", $istep, $kt ); }

    # Remove results of earlier steps, so a failed run cannot leave old files to be read.
    remove_tree("$dir/scr.geom") if -d "$dir/scr.geom";
    remove_tree("scr.geom")      if -d "scr.geom";
    unlink "$dir/$tpp_outfile";

    my $retval = callprog( $tpp, "/bin/terachem $dir/start.sp > $dir/$tpp_outfile", $mdle );
    if ( $retval != 0 ) {
        tc_fail("TeraChem failed in $dir. Check $dir/$tpp_outfile for details.");
    }

    if ( -d "scr.geom" ) {
        move( "scr.geom", "$dir/scr.geom" ) or tc_fail("Failed to move scr.geom to $dir/scr.geom: $!");
    }

    open my $fh, '<', "$dir/$tpp_outfile" or tc_fail("Cannot open $dir/$tpp_outfile: $!");
    my $finished = grep { /Job finished/ } <$fh>;
    close $fh;
    tc_fail("TeraChem did not finish in $dir (no 'Job finished' line in $dir/$tpp_outfile). It may have been killed, for example by a time limit.")
      unless $finished;
    tc_fail("TeraChem wrote no scratch folder $dir/scr.geom.") unless -d "$dir/scr.geom";
}

sub save_orbitals {
    my $source_dir = "GRAD/scr.geom";

    if ( $opt{archive_molden} ) {
        my $molden_src = -e "$source_dir/cas.molden" ? "$source_dir/cas.molden" : "$source_dir/geom.molden";
        if ( -e $molden_src ) {
            my $molden_dest = "$molden_ar/$t.molden";
            copy( $molden_src, $molden_dest ) or tc_fail("Molden file copy from $molden_src failed: $!");
            print "Archived molden file to $molden_dest\n";
        }
    }

    if ( $opt{use_prev_scf_wf} && !-e "$source_dir/c0.casscf" && -e "$source_dir/c0" ) {
        copy( "$source_dir/c0", $old_scf_guess ) or tc_fail("Failed to copy SCF orbitals to $old_scf_guess: $!");
    }

    my $wf_file = "$source_dir/c0.casscf";
    if ( -e $wf_file ) {
        copy( $wf_file, $old_guess ) or tc_fail("Failed to copy WF to $old_guess: $!");
        if ( $opt{archive_wf} ) {
            copy( $wf_file, "$wf_ar/c$t" ) or tc_fail("Failed to archive WF to $wf_ar/c$t: $!");
        }
    }
}

#====================================================================================
#                                READING RESULTS
#====================================================================================

sub mult_name {
    my ($m) = @_;
    my %names = ( 1 => "singlet", 2 => "doublet", 3 => "triplet", 4 => "quartet", 5 => "quintet" );
    return $names{$m} // tc_fail("castargetmult $m is not supported.");
}

sub parse_energies {
    #
    # Returns the first $nwant state energies (Hartree, as strings) from a TeraChem output.
    #   CASSCF, FOMO-CASCI and hh-TDA print a 'Root Mult. Total Energy' table that
    #   includes the ground state; only rows of the target multiplicity are used.
    #   TDA/TDDFT print 'Root Total Energy' for the excited states only; the ground state
    #   comes from 'FINAL ENERGY'.
    #
    my ( $file, $info, $nwant ) = @_;
    open( my $fh, '<', $file ) or tc_fail("Cannot open $file: $!");
    my @lines = <$fh>;
    close($fh);
    my @e;

    my @starts = grep { $lines[$_] =~ /Root\s+Mult\.\s+Total Energy/ } 0 .. $#lines;
    if (@starts) {
        my $want = mult_name( $info->{mult} );
        my $i = $starts[-1] + 1;
        $i++ while $i <= $#lines && $lines[$i] =~ /^\s*-+\s*$/;
        while ( $i <= $#lines && $lines[$i] =~ /^\s*(\d+)\s+(\w+)\s+(-?\d+\.\d+)/ ) {
            push @e, $3 if lc($2) eq $want;
            $i++;
        }
    }
    else {
        my ($table) = grep { $lines[$_] =~ /Root\s+Total Energy/ } 0 .. $#lines;
        tc_fail("No 'Root Total Energy' table in $file.") unless defined $table;
        my ($gs_line) = grep { /FINAL ENERGY:/ } @lines;
        tc_fail("No 'FINAL ENERGY' line in $file.") unless $gs_line;
        my @f = split ' ', $gs_line;
        push @e, $f[2];
        for ( my $k = $table + 2 ; $k <= $#lines && @e < $nwant ; $k++ ) {
            last unless $lines[$k] =~ /^\s*(\d+)\s+(-?\d+\.\d+)/;
            push @e, $2;
        }
    }

    tc_fail( "Could not read $nwant state energies from $file (found " . scalar(@e) . "). Ask TeraChem for at least $nwant states of the target multiplicity." )
      if @e < $nwant;
    return @e[ 0 .. $nwant - 1 ];
}

sub read_energy {
    my ($grad_job) = @_;
    if ( $lvprt >= 3 ) { print_STDOUT( "$mdle Reading Epot.\n", $istep, $kt ); }
    @epot = parse_energies( "GRAD/$tpp_outfile", $grad_job->{info}, $nstat );
}

sub write_energy {
    print_STDOUT( "--------------------------------------------------\n", $istep, $kt );
    print_STDOUT( "$mdle Energies (Hartree) at time t=$t:\n", $istep, $kt );
    for my $i ( 0 .. $#epot ) {
        printf STDOUT ( "State %2d: %20.10f\n", $i + 1, $epot[$i] );
    }
    print_STDOUT( "--------------------------------------------------\n", $istep, $kt );

    my $file = "epot";
    if ( -s $file ) {
        copy( $file, "oldepot" ) or tc_fail("Failed to copy $file to oldepot: $!");
    }
    open( my $out_fh, '>', $file ) or tc_fail("Cannot write to $file: $!");
    print $out_fh "$_\n" foreach @epot;
    close($out_fh);
    copy( $file, "newepot" ) or tc_fail("Failed to copy $file to newepot: $!");
}

sub read_xyz_vector_file {
    #
    # Reads a TeraChem grad.xyz (gradient or coupling): 2 header lines, then one line
    # per atom whose last three fields are the vector. Checks the atom count.
    #
    my ($file_path) = @_;
    tc_fail("Vector file '$file_path' not found or empty. The calculation may have failed.") unless -s $file_path;

    open my $fh, '<', $file_path or tc_fail("Could not open vector file '$file_path': $!");
    <$fh>;
    <$fh>;
    my ( @vx, @vy, @vz );
    my $num = qr/^-?(?:\d+\.?\d*|\.\d+)(?:[eEdD][-+]?\d+)?$/;
    while ( my $line = <$fh> ) {
        my @f = split ' ', $line;
        next unless @f;
        last if @vx == $nat;
        tc_fail("Bad line in $file_path: $line") unless @f >= 3 && $f[-3] =~ $num && $f[-2] =~ $num && $f[-1] =~ $num;
        push @vx, $f[-3];
        push @vy, $f[-2];
        push @vz, $f[-1];
    }
    close $fh;
    tc_fail( "$file_path has " . scalar(@vx) . " atom lines; expected $nat." ) unless @vx == $nat;
    return ( \@vx, \@vy, \@vz );
}

sub read_gradients {
    if ( $lvprt >= 3 ) { print_STDOUT( "$mdle Reading Gradients.\n", $istep, $kt ); }
    for my $ns ( 0 .. $nstat - 1 ) {
        for my $ia ( 0 .. $nat - 1 ) { $gx[$ns][$ia] = $gy[$ns][$ia] = $gz[$ns][$ia] = 0.0; }
    }
    my ( $gxr, $gyr, $gzr ) = read_xyz_vector_file("GRAD/scr.geom/grad.xyz");
    for my $ia ( 0 .. $nat - 1 ) {
        $gx[ $nstatdyn - 1 ][$ia] = $gxr->[$ia];
        $gy[ $nstatdyn - 1 ][$ia] = $gyr->[$ia];
        $gz[ $nstatdyn - 1 ][$ia] = $gzr->[$ia];
    }
}

sub write_grad {
    print_STDOUT( "$mdle Gradient for state $nstatdyn (Hartree/Bohr):\n", $istep, $kt );
    my $s = $nstatdyn - 1;
    for my $ia ( 0 .. $nat - 1 ) {
        printf STDOUT ( "%-2s   %15.10f %15.10f %15.10f\n", $symb[$ia], $gx[$s][$ia], $gy[$s][$ia], $gz[$s][$ia] );
    }
    print_STDOUT( "--------------------------------------------------\n", $istep, $kt );

    open( my $out1_fh, '>', "grad.all" ) or tc_fail("Cannot write to grad.all: $!");
    open( my $out2_fh, '>', "grad" )     or tc_fail("Cannot write to grad: $!");
    for my $ns ( 0 .. $nstat - 1 ) {
        for my $ia ( 0 .. $nat - 1 ) {
            print $out1_fh "$gx[$ns][$ia]  $gy[$ns][$ia]  $gz[$ns][$ia]\n";
            print $out2_fh "$gx[$ns][$ia]  $gy[$ns][$ia]  $gz[$ns][$ia]\n" if $ns == $nstatdyn - 1;
        }
    }
    close($out1_fh);
    close($out2_fh);
}

#====================================================================================
#                                COUPLINGS
#====================================================================================

sub treat_nacme {
    #
    # Writes nad_vectors for NX, with the phase fixed against the previous step.
    # Order matters (fix of 2026-10-29): escalar compares oldh with the raw newh; after
    # it, newh must hold the phase-corrected couplings, because NX's interpol.f90
    # rebuilds the couplings from oldh and newh at every substep.
    #
    my ($nac_jobs) = @_;
    if ( $lvprt >= 3 ) { print_STDOUT( "$mdle Treating couplings.\n", $istep, $kt ); }
    return if $nstat <= 1;
    return if $run_flag eq "second run";    # nad_vectors of this step are already written

    $ncoup = $nstat * ( $nstat - 1 ) / 2;
    for my $nc ( 0 .. $ncoup - 1 ) {
        for my $ia ( 0 .. $nat - 1 ) { $hx[$nc][$ia] = $hy[$nc][$ia] = $hz[$nc][$ia] = 0.0; }
    }

    if ( -s "nad_vectors" ) {
        copy( "nad_vectors", "oldh" ) or tc_fail("Copy of nad_vectors to oldh failed: $!");
    }
    else {
        write_nacme("oldh");
    }

    # TeraChem's coupling for nacstate1 = i-1, nacstate2 = j-1 (i < j) has the opposite
    # sign to NX's h(j,i); hence the minus sign.
    foreach my $job (@$nac_jobs) {
        my ( $i, $j ) = @{ $job->{pair} };
        my $nc = pair_index( $i, $j );
        my ( $vx, $vy, $vz ) = read_xyz_vector_file("$job->{dir}/scr.geom/grad.xyz");
        unless ( grep { $_ != 0 } @$vx, @$vy, @$vz ) {
            print_STDOUT( "$mdle WARNING: TeraChem returned an all-zero coupling vector for states $j and $i in $job->{dir}. Check that this method gives couplings.\n", $istep, $kt );
        }
        for my $ia ( 0 .. $nat - 1 ) {
            $hx[$nc][$ia] = -$vx->[$ia];
            $hy[$nc][$ia] = -$vy->[$ia];
            $hz[$nc][$ia] = -$vz->[$ia];
        }
    }
    write_nacme("nad_vectors");

    copy( "nad_vectors", "newh" ) or tc_fail("Copy to newh failed: $!");
    my $true_oldh = $opt{phase_ref} eq "last" ? phase_memory_into_oldh() : undef;
    adjust_phase();
    if ($true_oldh) {    # NX's interpolation must see the real previous step
        write_lines( "oldh", $true_oldh );
    }
    update_phase_memory() if $opt{phase_ref} eq "last";
    copy( "nad_vectors", "newh" ) or tc_fail("Copy of phase-corrected nad_vectors to newh failed: $!");
}

sub read_lines {
    my ($f) = @_;
    open my $fh, '<', $f or tc_fail("Cannot open $f: $!");
    my @l = <$fh>;
    close $fh;
    return \@l;
}

sub write_lines {
    my ( $f, $l ) = @_;
    open my $fh, '>', $f or tc_fail("Cannot write $f: $!");
    print $fh @$l;
    close $fh;
}

sub block_is_zero {
    my ( $l, $nc ) = @_;
    for my $ia ( 0 .. $nat - 1 ) {
        return 0 if grep { $_ != 0 } split ' ', $l->[ $nc * $nat + $ia ];
    }
    return 1;
}

sub phase_memory_into_oldh {
    #
    # phase_ref = last: for every pair that is zero in oldh but has a remembered vector,
    # put the remembered vector into oldh for escalar. Returns the real oldh, which the
    # caller restores after escalar, or undef if nothing was changed.
    #
    return undef unless -s $phase_mem;
    my $old = read_lines("oldh");
    my $mem = read_lines($phase_mem);
    return undef unless @$mem == @$old && @$old == $ncoup * $nat;
    my @ref = @$old;
    my @used;
    for my $nc ( 0 .. $ncoup - 1 ) {
        next unless block_is_zero( $old, $nc ) && !block_is_zero( $mem, $nc );
        @ref[ $nc * $nat .. ( $nc + 1 ) * $nat - 1 ] = @$mem[ $nc * $nat .. ( $nc + 1 ) * $nat - 1 ];
        push @used, $nc;
    }
    return undef unless @used;
    write_lines( "oldh", \@ref );
    print_STDOUT( "$mdle phase_ref = last: phase of coupling(s) " . join( ", ", @used ) . " fixed against their last computed vector.\n", $istep, $kt );
    return $old;
}

sub update_phase_memory {
    #
    # Remembers the last phase-corrected, non-zero vector of every pair.
    #
    my $new = read_lines("nad_vectors");
    my $mem = -s $phase_mem ? read_lines($phase_mem) : [];
    $mem = [ ("0.0  0.0  0.0\n") x ( $ncoup * $nat ) ] unless @$mem == $ncoup * $nat;
    for my $nc ( 0 .. $ncoup - 1 ) {
        next if block_is_zero( $new, $nc );
        @$mem[ $nc * $nat .. ( $nc + 1 ) * $nat - 1 ] = @$new[ $nc * $nat .. ( $nc + 1 ) * $nat - 1 ];
    }
    write_lines( $phase_mem, $mem );
}

sub write_nacme {
    my ($file) = @_;
    if ( $lvprt >= 3 ) { print_STDOUT( "$mdle Writing coupling vectors to $file.\n", $istep, $kt ); }

    print_STDOUT( "$mdle Non-adiabatic couplings (1/Bohr):\n", $istep, $kt );
    foreach my $j ( 2 .. $nstat ) {
        foreach my $i ( 1 .. $j - 1 ) {
            my $nc = pair_index( $i, $j );
            next unless grep { $hx[$nc][$_] != 0.0 || $hy[$nc][$_] != 0.0 || $hz[$nc][$_] != 0.0 } 0 .. $nat - 1;
            print_STDOUT( "Coupling between states $j and $i (Vector index $nc):\n", $istep, $kt );
            for my $ia ( 0 .. $nat - 1 ) {
                printf STDOUT ( "  %-2s   %15.10f %15.10f %15.10f\n", $symb[$ia], $hx[$nc][$ia], $hy[$nc][$ia], $hz[$nc][$ia] );
            }
        }
    }
    print_STDOUT( "--------------------------------------------------\n", $istep, $kt );

    open( my $out_fh, '>', $file ) or tc_fail("Cannot write to $file: $!");
    for my $nc ( 0 .. $ncoup - 1 ) {
        for my $ia ( 0 .. $nat - 1 ) {
            print $out_fh "$hx[$nc][$ia]  $hy[$nc][$ia]  $hz[$nc][$ia]\n";
        }
    }
    close($out_fh);
}

sub adjust_phase {
    if ( $lvprt >= 3 ) { print_STDOUT( "$mdle Fixing the coupling phase.\n", $istep, $kt ); }

    my $retval = callprogsp( $mld, "escalar", $mdle );
    tc_fail("Phase adjustment (escalar) failed.") if $retval != 0;
    copy( "nadv", "nad_vectors" ) or tc_fail("Copy from nadv failed: $!");

    if ( $lvprt >= 3 ) { copy( "escalar.log", "../$DEBUG/." ) or tc_fail("Copy of escalar.log failed: $!"); }
    if ( $lvprt >= 2 ) {
        open( my $ep_fh, '<', "escph" ) or tc_fail("Cannot open escph to read: $!");
        print_STDOUT( "The global phase(s) is(are):", $istep, $kt );
        while (<$ep_fh>) {
            chomp;
            print_STDOUT( " $_  ", $istep, $kt );
        }
        print_STDOUT( "\n\n", $istep, $kt );
        close($ep_fh);
    }
}

#====================================================================================

sub tc_fail {
    my ($msg) = @_;
    my $text = ( $mdle // "run-tera-cas.pl:" ) . " ERROR: $msg\n";
    eval { print_STDOUT( $text, $istep // 0, $kt // 1 ) } unless $CLI;
    die $text;
}
