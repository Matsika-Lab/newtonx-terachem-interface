#!/usr/bin/env perl
#
#====================================================================================
#
# Interface between TeraChem and NewtonX built from the template
# provided by Mario Barbatti, 2021.
#
# Authors:
# Dakshitha Abeygunewardane
# Vaibhav Signh
# Spiridoula Matsika
#
# Matsika Lab,
# Temple University, USA.
# 2025.
#
#====================================================================================
#
use strict;
use warnings;
use File::Copy qw(move copy);
use File::Path qw(remove_tree mkpath);
use Cwd 'abs_path';
use lib join( '/', $ENV{"NX"}, "lib" );
use colib_perl;

# We are using "strict." Thus, all variables must be declared.
my ( $mld, $mdle, $BASEDIR, $DEBUG, $JAD, $JND, $ctd, $fpar );
my ( $old_guess, $grad_loc, $nac10_loc, $nac12_loc, $tpp, $tpp_outfile, $e_loc, $molden_ar, $wf_ar );
my ( $nat, $istep, $nstat, $nstatdyn, $ndamp, $kt, $dt, $t, $tmax, $nintc );
my ( $nxrestart, $thres, $killstat, $timekill, $prog, $lvprt, $etot_jump, $etot_drift );
my ( @symb, @zn, @x, @y, @z, @Mass, $ia );
my ( $typeofinput, $type );
my ( @epot, $ns );
my ( $vdoth, $run_flag );
my ( $ncoup, $nc );
my ( @gx, @gy, @gz, @hx, @hy, @hz );
my ($mem);
my (%progconf);

#====================================================================================
#
# 				MAIN EXECUTION BLOCK
#
#====================================================================================

# 1. Define global variables and load simulation status
define_variables();
write_debug_prologue();

# 2. Determine the type of dynamics; this interface only supports non-adiabatic (JND)
determine_dynamics_type();
if ( $typeofinput eq "jad" ) {
    print_STDOUT( "This interface is designed for non-adiabatic dynamics (JND) only.\n", $istep, $kt );
    die "Adiabatic dynamics (JAD) is not supported.";
}

# 3. Read current geometry from NewtonX
read_geom();

# 4. Prepare TeraChem input files
prepare_input();

# 5. Run TeraChem for gradients and non-adiabatic couplings (NACs)
run_terachem();

# 6. Read results from TeraChem and write them for NewtonX
read_energy();
read_gradients();
treat_nacme();

#====================================================================================
#
# 				START SUBROUTINES
#
#====================================================================================

sub define_variables {
    #
    # Defines file paths, environment variables, and loads the simulation status.
    #
    $mld  = $ENV{"NX"};
    $mdle = "run-tera-cas.pl:";

    # TeraChem specific variables
    $tpp         = $ENV{"TeraChem"};
    $tpp_outfile = "tera.out";
    $e_loc       = "GRAD/tera.out";
    $grad_loc    = "GRAD/scr.geom/grad.xyz";
    $nac10_loc   = "NAD_N1N0/scr.geom/grad.xyz"; # NAC between current state (N1) and state below (N0)
    $nac12_loc   = "NAD_N1N2/scr.geom/grad.xyz"; # NAC between current state (N1) and state above (N2)

    # Variables for handling wavefunction restart
    $old_guess = "../INFO_RESTART/WF_OLD/c0";
    $molden_ar = "../INFO_RESTART/MOLDEN_ARCHIVE";
    $wf_ar     = "../INFO_RESTART/WF_ARCHIVE";

    # Create directories for archiving and restart if they don't exist
    mkpath( [ $molden_ar, $wf_ar, "../INFO_RESTART/WF_OLD" ], 0, 0755 );

    $BASEDIR = `pwd`;
    chomp($BASEDIR);

    # NewtonX directories and control files
    $DEBUG = "DEBUG";
    $JAD   = "JOB_AD";
    $JND   = "JOB_NAD";
    $ctd   = "control.d";

    # Load current dynamics status from control.d
    ( $nat, $istep, $nstat, $nstatdyn, $ndamp, $kt, $dt, $t, $tmax, $nintc, $mem, $nxrestart, $thres, $killstat, $timekill, $prog, $lvprt, $etot_jump, $etot_drift ) =
      load_status( $ctd, $mdle );

    %progconf = prog_config($prog);
    $fpar     = $progconf{parfile};
}

sub write_debug_prologue {
    #
    # Writes initial debug messages about the simulation state.
    #
    if ( $lvprt >= 3 ) {
        print_STDOUT( "$mdle has taken over\n",                                       $istep, $kt );
        print_STDOUT( "$mdle running in $BASEDIR\n",                                  $istep, $kt );
        print_STDOUT( "$mdle Dynamics control: \n",                                   $istep, $kt );
        print_STDOUT( "$nat $istep $nstat $nstatdyn $ndamp $kt $dt $t $tmax \n",      $istep, $kt );
        print_STDOUT( "$nintc $mem $nxrestart $thres $killstat $timekill $prog $lvprt\n", $istep, $kt );
        print_STDOUT( "$etot_jump $etot_drift\n\n",                                   $istep, $kt );
    }
}

sub determine_dynamics_type {
    #
    # Checks for JOB_AD/JOB_NAD directories to determine dynamics type.
    #
    if ( $lvprt >= 3 ) { print_STDOUT( "$mdle Checking type of dynamics.\n", $istep, $kt ); }

    # Read type from type_of_dyn.out if it exists
    my $type_from_file = 2;    # Default to non-adiabatic
    my $typeout        = "type_of_dyn.out";
    if ( -s $typeout ) {
        open( my $fh, '<', $typeout ) or die "$mdle Cannot open $typeout: $!";
        $type_from_file = <$fh>;
        chomp $type_from_file;
        close($fh);
    }

    if ( ( -e $JAD ) && ( !-e $JND ) ) {
        $typeofinput = "jad";
    }
    elsif ( ( !-e $JAD ) && ( -e $JND ) ) {
        $typeofinput = "jnd";
    }
    elsif ( ( -e $JAD ) && ( -e $JND ) ) {
        $typeofinput = ( $type_from_file == 1 ) ? "jad" : "jnd";
    }
    else {
        die "$mdle: Could not determine dynamics type. Neither $JAD nor $JND found.";
    }
}


sub read_geom {
    #
    # Reads geometry from NewtonX's 'geom' file and handles the guess wavefunction.
    #
    if ( $lvprt >= 3 ) { print_STDOUT( "$mdle Reading current geometry.\n", $istep, $kt ); }

    open( my $gm_fh, '<', "geom" ) or die "$mdle Cannot open geom: $!";
    $ia = 0;
    while (<$gm_fh>) {
        chomp;
        ( $symb[$ia], $zn[$ia], $x[$ia], $y[$ia], $z[$ia], $Mass[$ia] ) = split;
        $ia++;
    }
    close($gm_fh);

    # Look for a guess wavefunction to use. If a persistent guess ($old_guess) from a
    # previous step exists, use it. Otherwise, look for output from an initial
    # calculation and copy it to the persistent location for subsequent steps.
    my $initial_casscf_guess = "GRAD/scr.geom/c0.casscf";
    my $initial_dft_guess    = "GRAD/scr.geom/c0";

    if ( -e $old_guess ) {
        print "Using existing wavefunction from previous step as guess: $old_guess\n";
    }
    elsif ( -e $initial_casscf_guess ) {
        copy( $initial_casscf_guess, $old_guess ) or die "Failed to copy initial CASSCF guess: $!";
        print "Using initial CASSCF wavefunction as first guess: $initial_casscf_guess\n";
    }
    elsif ( -e $initial_dft_guess ) {
        copy( $initial_dft_guess, $old_guess ) or die "Failed to copy initial DFT guess: $!";
        print "Using initial DFT wavefunction as first guess: $initial_dft_guess\n";
    }
    else {
        print "Guess wavefunction not provided. TeraChem will generate one.\n";
    }
}

sub prepare_input {
    #
    # Prepares TeraChem input files (geom.xyz, start.sp) for all required calculations.
    #
    if ( $lvprt >= 3 ) { print_STDOUT( "$mdle Preparing input for TeraChem.\n", $istep, $kt ); }
    my $au2ang = units("au2ang");

    # Create the new XYZ file with updated coordinates
    my $xyz_file = "geom.xyz";
    open my $fgeom, '>', $xyz_file or die "Could not open $xyz_file: $!";
    print $fgeom scalar(@symb), "\n\n";
    for my $i ( 0 .. $#symb ) {
        my $x_ang = $x[$i] * $au2ang;
        my $y_ang = $y[$i] * $au2ang;
        my $z_ang = $z[$i] * $au2ang;
        print $fgeom "$symb[$i]   $x_ang   $y_ang   $z_ang\n";
    }
    close $fgeom;

    # Copy the geometry to the run folders
    copy( $xyz_file, "GRAD/geom.xyz" )      or die "Failed to copy geom.xyz to GRAD: $!";
    copy( $xyz_file, "NAD_N1N0/geom.xyz" )  or die "Failed to copy geom.xyz to NAD_N1N0: $!";
    copy( $xyz_file, "NAD_N1N2/geom.xyz" )  or die "Failed to copy geom.xyz to NAD_N1N2: $!";

    # Define updates for the start.sp files for each calculation type
    my %updates = (
        'GRAD'     => { castarget => $nstatdyn - 1, cistarget => $nstatdyn - 1 },
        'NAD_N1N0' => { nacstate1 => $nstatdyn - 2, nacstate2 => $nstatdyn - 1 },
        'NAD_N1N2' => { nacstate1 => $nstatdyn - 1, nacstate2 => $nstatdyn }
    );

    # Apply the updates to the start.sp files
    foreach my $dir ( keys %updates ) {
        process_start_sp( "$dir/start.sp", $updates{$dir} );
    }
}

sub process_start_sp {
    #
    # Processes a start.sp file to set target states and the guess wavefunction.
    # It intelligently handles commented lines and existing keywords.
    #
    my ( $file_path, $updates ) = @_;
    
    unless ( -e $file_path ) {
        print_STDOUT("Template input file '$file_path' not found!\n", $istep, $kt);
        die;
    }

    open my $fh, '<', $file_path or die "Could not open '$file_path' for reading: $!";
    my @lines = <$fh>;
    close $fh;

    # --- Keyword Checks (on uncommented lines) ---
    # Check for keywords in the active content and whether a guess WF will be used.
    my $is_rhf_method = 0;
    my $is_casscf_run = 0;
    my $guess_is_provided = -e $old_guess; # This is the crucial check.

    foreach my $line (@lines) {
        next if $line =~ /^\s*#/; # Skip commented lines
        $is_rhf_method = 1 if $line =~ /^\s*method\s+r?hf/;
        $is_casscf_run = 1 if $line =~ /^\s*casscf\s+yes/;
    }

    # --- File Modifications ---

    # 1. Handle guess wavefunction
    if ( $guess_is_provided ) {
        my @filtered_lines;
        # Filter out existing, uncommented 'guess' lines
        foreach my $line (@lines) {
            push @filtered_lines, $line unless ($line !~ /^\s*#/ && $line =~ /^\s*guess\s+\S+/);
        }
        @lines = @filtered_lines;
        # Add the new guess line to the end.
        push @lines, "guess        " . abs_path($old_guess) . "\n";
    }

    # 2. Handle CASSCF orbital generation case (maxit/convthre)
    # If the method is RHF/HF, a subsequent CASSCF is requested, AND a guess is provided,
    # we want to skip the SCF cycle by using the provided guess orbitals.
    if ( $is_rhf_method && $is_casscf_run && $guess_is_provided ) {
        my @filtered_lines;
        # Filter out existing, uncommented maxit/convthre lines
        foreach my $line (@lines) {
            push @filtered_lines, $line unless ($line !~ /^\s*#/ && $line =~ /^\s*(maxit|convthre)\s+/);
        }
        @lines = @filtered_lines;
        # Add the lines required to skip the SCF cycle.
        push @lines, "maxit        0\n";
        push @lines, "convthre     1e7\n";
    }

    # 3. Handle dynamic state updates (castarget, nacstate1, etc.)
    # This is done in-place to preserve line order and comments.
    for my $i ( 0 .. $#lines ) {
        foreach my $key ( keys %$updates ) {
            # If the line contains an active keyword, replace it.
            if ( $lines[$i] !~ /^\s*#/ && $lines[$i] =~ /^\s*$key\s+/ ) {
                $lines[$i] = "$key        $updates->{$key}\n";
                last; # Move to the next line once a keyword is matched and replaced
            }
        }
    }

    open $fh, '>', $file_path or die "Could not open '$file_path' for writing: $!";
    print $fh @lines;
    close $fh;
}

sub run_terachem {
    #
    # Executes TeraChem for all necessary calculations (gradient and NACs).
    #
    if ( $lvprt >= 3 ) { print_STDOUT( "$mdle Executing TeraChem.\n", $istep, $kt ); }

    my @tasks;
    push @tasks, 'GRAD';

    # Determine which NAC calculations are needed based on the current state.
    # State numbers are 1-based, nstat is the total number of states.
    # We need NAC with the state below if not in the ground state.
    if ( $nstatdyn > 1 ) {
        push @tasks, 'NAD_N1N0';
    }
    # We need NAC with the state above if not in the highest state.
    if ( $nstatdyn < $nstat ) {
        push @tasks, 'NAD_N1N2';
    }

    # Execute the tasks
    foreach my $task (@tasks) {
        process_directory($task);
        # Save orbitals after the gradient calculation is complete
        if ( $task eq 'GRAD' ) {
            save_orbitals();
        }
    }
}

sub process_directory {
    #
    # Runs a TeraChem calculation in the specified directory.
    #
    my ($directory) = @_;
    if ( $lvprt >= 3 ) { print_STDOUT( "$mdle Running calculation in $directory.\n", $istep, $kt ); }

    # Run TeraChem. callprog executes it inside the TEMP/ directory.
    my $retval = callprog( $tpp, "/bin/terachem $directory/start.sp > $directory/$tpp_outfile", $mdle );
    if ( $retval != 0 ) {
        print_STDOUT( "Error in TeraChem execution for $directory! Check $directory/$tpp_outfile for details.\n", $istep, $kt );
        die;
    }

    # TeraChem writes to TEMP/scr.geom. We move it to the correct calculation directory.
    my $scratch_source = "scr.geom";
    my $scratch_dest   = "$directory/$scratch_source";
    if ( -d $scratch_source ) {
        remove_tree($scratch_dest) if -d $scratch_dest; # Safely remove old scratch dir
        move( $scratch_source, $scratch_dest ) or die "Failed to move $scratch_source to $scratch_dest: $!";
    }
}

sub save_orbitals {
    #
    # Archives the Molden file and the wavefunction/CI vectors for visualization and restart.
    #
    my $source_dir = "GRAD/scr.geom";

    # Check for casscf.molden for CASSCF or geom.molden for DFT/HF
    my $molden_src = -e "$source_dir/cas.molden" ? "$source_dir/cas.molden" : "$source_dir/geom.molden";
    if ( -e $molden_src ) {
        my $molden_dest = "$molden_ar/$t.molden";
        copy( $molden_src, $molden_dest ) or die "Molden file copy from $molden_src failed: $!";
        print "Archived molden file to $molden_dest\n";
    }

    # Save wavefunction file (c0.casscf for CASSCF, c0 for DFT/HF)
    my $wf_file = -e "$source_dir/c0.casscf" ? "$source_dir/c0.casscf" : "$source_dir/c0";
    if ( -e $wf_file ) {
        copy( $wf_file, $old_guess )      or die "Failed to copy WF to $old_guess: $!";
        copy( $wf_file, "$wf_ar/c$t" ) or die "Failed to archive WF to $wf_ar/c$t: $!";
    }
}

sub read_energy {
    #
    # Reads potential energies from the TeraChem output and writes them to 'epot'.
    #
    if ( $lvprt >= 3 ) { print_STDOUT( "$mdle Reading Epot.\n", $istep, $kt ); }

    # Error check: ensure the output file exists and is not empty.
    unless ( -s $e_loc ) {
        print_STDOUT( "TeraChem output file '$e_loc' not found or is empty. Calculation may have failed.\n", $istep, $kt );
        die;
    }

    # The parsing logic below is specific to TeraChem's output format and may
    # need adjustment if the format changes in future versions.
    my $cas_lines = $nstat + 2;
    my $dft_lines = $cas_lines - 1;

    my $cas_section = `grep -A $cas_lines '  Root   Mult.   Total Energy (a.u.)' $e_loc`;
    my $dft_section = `grep -A $dft_lines '  Root   Total Energy (a.u.)   Ex. Energy' $e_loc`;
    my @total_energies;

    if ($cas_section) {
        my @lines = split( "\n", $cas_section );
        foreach my $line ( @lines[ 2 .. $#lines ] ) {
            my @fields = split( /\s+/, $line );
            push @total_energies, $fields[3] if @fields > 3; # Energy is 4th column
        }
    }
    elsif ($dft_section) {
        my $dft_ground_line = `grep 'FINAL ENERGY:' $e_loc`;
        my @fields          = split( /\s+/, $dft_ground_line );
        push @total_energies, $fields[2] if @fields > 2;

        my @lines = split( "\n", $dft_section );
        foreach my $line ( @lines[ 2 .. $#lines ] ) {
            my @fields = split( /\s+/, $line );
            push @total_energies, $fields[2] if @fields > 2; # Energy is 3rd column
        }
    }
    
    # Check if we successfully parsed the energies
    if ( !@total_energies || $#total_energies + 1 < $nstat ) {
        print_STDOUT( "Could not parse all $nstat state energies from '$e_loc'. Check TeraChem output.\n", $istep, $kt );
        die;
    }

    # Save extracted Total Energy values (in Hartree)
    @epot = @total_energies;

    write_energy();
}

sub write_energy {
    #
    # Writes the potential energies to 'epot' file for NewtonX.
    #
    if ( $lvprt >= 3 ) { print_STDOUT( "$mdle Writing Epot.\n", $istep, $kt ); }

    # Print energies to STDOUT
    print_STDOUT( "--------------------------------------------------\n", $istep, $kt );
    print_STDOUT( "$mdle Energies (Hartree) at time t=$t:\n",          $istep, $kt );
    for my $i ( 0 .. $#epot ) {
        my $state_num = $i + 1;
        printf STDOUT ("State %2d: %20.10f\n", $state_num, $epot[$i]);
    }
    print_STDOUT( "--------------------------------------------------\n", $istep, $kt );

    my $file = "epot";
    if ( -s $file ) {
        copy( $file, "oldepot" ) or die "Failed to copy $file to oldepot: $!";
    }
    open( my $out_fh, '>', $file ) or die "Cannot write to $file: $!";
    foreach (@epot) {
        print $out_fh "$_\n";
    }
    close($out_fh);
    copy( $file, "newepot" ) or die "Failed to copy $file to newepot: $!";
}

sub read_gradients {
    #
    # Reads the energy gradient of the current state from TeraChem's output.
    #
    if ( $lvprt >= 3 ) { print_STDOUT( "$mdle Reading Gradients.\n", $istep, $kt ); }

    # Initialize gradient arrays with zeros
    for ( $ns = 0; $ns < $nstat; $ns++ ) {
        for ( $ia = 0; $ia < $nat; $ia++ ) {
            $gx[$ns][$ia] = $gy[$ns][$ia] = $gz[$ns][$ia] = 0.0;
        }
    }

    # Read the gradient for the current state ($nstatdyn)
    my ( $grad_x_ref, $grad_y_ref, $grad_z_ref ) = read_xyz_vector_file($grad_loc);

    for ( $ia = 0; $ia < $nat; $ia++ ) {
        $gx[ $nstatdyn - 1 ][$ia] = $$grad_x_ref[$ia];
        $gy[ $nstatdyn - 1 ][$ia] = $$grad_y_ref[$ia];
        $gz[ $nstatdyn - 1 ][$ia] = $$grad_z_ref[$ia];
    }

    write_grad();
}

sub write_grad {
    #
    # Writes the energy gradients to 'grad' and 'grad.all' files.
    #
    if ( $lvprt >= 3 ) { print_STDOUT( "$mdle Writing Gradients.\n", $istep, $kt ); }

    # Print the current state's gradient to STDOUT
    print_STDOUT( "$mdle Gradient for state $nstatdyn (Hartree/Bohr):\n", $istep, $kt );
    my $ns_idx = $nstatdyn - 1;
    for ( $ia = 0; $ia < $nat; $ia++ ) {
        printf STDOUT ("%-2s   %15.10f %15.10f %15.10f\n", $symb[$ia], $gx[$ns_idx][$ia], $gy[$ns_idx][$ia], $gz[$ns_idx][$ia]);
    }
    print_STDOUT( "--------------------------------------------------\n", $istep, $kt );

    open( my $out1_fh, '>', "grad.all" ) or die "Cannot write to grad.all: $!";
    open( my $out2_fh, '>', "grad" )     or die "Cannot write to grad: $!";

    for ( $ns = 0; $ns < $nstat; $ns++ ) {
        for ( $ia = 0; $ia < $nat; $ia++ ) {
            print $out1_fh "$gx[$ns][$ia]  $gy[$ns][$ia]  $gz[$ns][$ia]\n";
            if ( $ns == $nstatdyn - 1 ) {
                print $out2_fh "$gx[$ns][$ia]  $gy[$ns][$ia]  $gz[$ns][$ia]\n";
            }
        }
    }
    close($out1_fh);
    close($out2_fh);
}

sub treat_nacme {
    #
    # Processes the non-adiabatic coupling matrix elements (NACME).
    #
    if ( $lvprt >= 3 ) { print_STDOUT( "$mdle Treating couplings.\n", $istep, $kt ); }
    
    # If there is only one state (or fewer), there are no couplings to process.
    return if ($nstat <= 1);

    $run_flag = read_single_value( "which_run_is_that", "" );
    return if ( $run_flag eq "second run" );    # Skip if this is a re-run after a hop

    $ncoup = $nstat * ( $nstat - 1 ) / 2;
    # Intialize coupling arrays with zeros
    for ( $nc = 0; $nc < $ncoup; $nc++ ) {
        for ( $ia = 0; $ia < $nat; $ia++ ) {
            $hx[$nc][$ia] = $hy[$nc][$ia] = $hz[$nc][$ia] = 0.0;
        }
    }

    # Create or update oldh (coupling in the previous step) for interpolation.
    if ( -s "nad_vectors" ) {
        copy( "nad_vectors", "oldh" ) or die "Copy of nad_vectors to oldh failed: $!";
    }
    else {
        write_nacme("oldh");
    }

    # Check vdoth setting in sh.inp. This interface requires explicit NAC calculation.
    $vdoth = getkeyword( "sh.inp", "vdoth", 0 );
    if ( $vdoth != 0 ) {
        print_STDOUT( "The TeraChem interface requires vdoth=0 in sh.inp for NAC calculations.\n", $istep, $kt );
        die;
    }

    read_nacme();
    write_nacme("nad_vectors");

    # Create newh (couplings at current step) BEFORE calling phase adjustment.
    copy( "nad_vectors", "newh" ) or die "Copy to newh failed: $!";
    
    adjust_phase(); # Correct nonadiabatic coupling phases
}

sub read_nacme {
    #
    # This subroutine reads nonadiabatic coupling vectors from TeraChem output.
    # It has been reverted to the original script's logic to ensure correctness.
    #
    if ( $lvprt >= 3 ) { print_STDOUT( "$mdle Reading coupling vectors.\n", $istep, $kt ); }
    
    my ( @nac01x, @nac01y, @nac01z );
    my ( @nac12x, @nac12y, @nac12z );
    my ( $ncc1, $ncc2 );

    # Read the necessary vector files based on the current state
    if ( $nstatdyn > 1 ) {
         my ( $nac_x, $nac_y, $nac_z ) = read_xyz_vector_file($nac10_loc);
         @nac01x = @$nac_x;
         @nac01y = @$nac_y;
         @nac01z = @$nac_z;
    }
    if ($nstatdyn < $nstat) {
        my ( $nac_x, $nac_y, $nac_z ) = read_xyz_vector_file($nac12_loc);
        @nac12x = @$nac_x;
        @nac12y = @$nac_y;
        @nac12z = @$nac_z;
    }

    # Calculate the indices for the coupling vectors
    $ncc1 = ( $nstatdyn * ( $nstatdyn - 1 ) / 2 ) - 1;
    $ncc2 = ( ( $nstatdyn * ( $nstatdyn - 1 ) / 2 ) - 1 ) + $nstatdyn;

    # Populate the @h arrays using the logic from the original script
    for ( $ia = 0; $ia < $nat; $ia++ ) {
        if ( $nstatdyn == 1 ) {
            $hx[$ncc2][$ia] = -$nac12x[$ia];
            $hy[$ncc2][$ia] = -$nac12y[$ia];
            $hz[$ncc2][$ia] = -$nac12z[$ia];
        }
        elsif ( $nstatdyn > 1 ) {
            if ( $nstatdyn != $nstat ) {
                $hx[$ncc1][$ia] = -$nac01x[$ia];
                $hy[$ncc1][$ia] = -$nac01y[$ia];
                $hz[$ncc1][$ia] = -$nac01z[$ia];
                $hx[$ncc2][$ia] = -$nac12x[$ia];
                $hy[$ncc2][$ia] = -$nac12y[$ia];
                $hz[$ncc2][$ia] = -$nac12z[$ia];
            }
            elsif ( $nstatdyn == $nstat ) {
                $hx[$ncc1][$ia] = -$nac01x[$ia];
                $hy[$ncc1][$ia] = -$nac01y[$ia];
                $hz[$ncc1][$ia] = -$nac01z[$ia];
            }
        }
    }
}


sub read_xyz_vector_file {
    #
    # Helper subroutine to read a 3-column vector file (like grad.xyz or NACs).
    #
    my ($file_path) = @_;
    my ( @vec_x, @vec_y, @vec_z );

    unless ( -s $file_path ) {
        print_STDOUT( "Vector file '$file_path' not found or is empty. Calculation may have failed.\n", $istep, $kt );
        die;
    }

    open my $fh, '<', $file_path or die "Could not open vector file '$file_path': $!";
    <$fh>;    # Skip header line 1 (atom count)
    <$fh>;    # Skip header line 2 (comment)

    while ( my $line = <$fh> ) {
        my @fields = split ' ', $line;
        # For grads: symbol, gx, gy, gz
        # For NACs from TC: index, symbol, nx, ny, nz
        # We need the last three columns in both cases.
        push @vec_x, $fields[-3];
        push @vec_y, $fields[-2];
        push @vec_z, $fields[-1];
    }
    close $fh;

    return ( \@vec_x, \@vec_y, \@vec_z );
}

sub write_nacme {
    #
    # Writes the @hx, @hy, @hz arrays to a file for NewtonX.
    #
    my ($file) = @_;
    if ( $lvprt >= 3 ) { print_STDOUT( "$mdle Writing coupling vectors to $file.\n", $istep, $kt ); }

    # Print non-zero NAC vectors to STDOUT
    print_STDOUT( "$mdle Non-adiabatic couplings (1/Bohr):\n", $istep, $kt );
    for ( $nc = 0; $nc < $ncoup; $nc++ ) {
        my $is_zero = 1;
        for ( $ia = 0; $ia < $nat; $ia++ ) {
            if ( $hx[$nc][$ia] != 0.0 || $hy[$nc][$ia] != 0.0 || $hz[$nc][$ia] != 0.0 ) {
                $is_zero = 0;
                last;
            }
        }

        # Only print vectors that have been calculated in this step
        unless ($is_zero) {
            # This logic is to figure out which states I,J this coupling belongs to
            my $I = 0;
            my $J = 0;
            my $temp_sum = 0;
            for my $i ( 2 .. $nstat ) {
                $temp_sum += $i - 1;
                if ( $nc < $temp_sum ) {
                    $I = $i;
                    $J = $nc - ( $temp_sum - ( $i - 1 ) ) + 1;
                    last;
                }
            }
            print_STDOUT( "Coupling between states $I and $J (Vector index $nc):\n", $istep, $kt );
            for ( $ia = 0; $ia < $nat; $ia++ ) {
                printf STDOUT ("  %-2s   %15.10f %15.10f %15.10f\n", $symb[$ia], $hx[$nc][$ia], $hy[$nc][$ia], $hz[$nc][$ia]);
            }
        }
    }
    print_STDOUT( "--------------------------------------------------\n", $istep, $kt );

    open( my $out_fh, '>', $file ) or die "Cannot write to $file: $!";
    for ( $nc = 0; $nc < $ncoup; $nc++ ) {
        for ( $ia = 0; $ia < $nat; $ia++ ) {
            print $out_fh "$hx[$nc][$ia]  $hy[$nc][$ia]  $hz[$nc][$ia]\n";
        }
    }
    close($out_fh);
}

sub adjust_phase {
    #
    # Calls a NewtonX utility to ensure phase consistency of NAC vectors between steps.
    #
    if ( $lvprt >= 3 ) { print_STDOUT( "$mdle Fixing the coupling phase.\n", $istep, $kt ); }

    my $retval = callprogsp( $mld, "escalar", $mdle );
    if ( $retval != 0 ) {
        die "$mdle died during phase adjustment (escalar)\n";
    }
    copy( "nadv", "nad_vectors" ) or die "Copy from nadv failed: $!";

    if ( $lvprt >= 3 ) { copy( "escalar.log", "../$DEBUG/." ) or die "Copy failed: $!"; }
    if ( $lvprt >= 2 ) {
        open( my $ep_fh, '<', "escph" ) or die "Cannot open escph to read: $!";
        print_STDOUT( "The global phase(s) is(are):", $istep, $kt );
        while (<$ep_fh>) {
            chomp;
            print_STDOUT( " $_  ", $istep, $kt );
        }
        print_STDOUT( "\n\n", $istep, $kt );
        close($ep_fh);
    }
}


