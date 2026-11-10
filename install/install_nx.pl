#!/usr/bin/env perl
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Installs the TeraChem interface into a NewtonX 2.4 or 2.6 installation.
#
#   perl install/install_nx.pl [--dry-run] [--no-tests] [NX_BIN]
#
# NX_BIN is NewtonX's bin folder (default: $NX). The script
#   1. copies run-tera-cas.pl and run_tera_ic.pl into NX_BIN (mode 755),
#   2. registers TeraChem as prog = 21.0 in NX_BIN/lib/colib_perl.pm: prog_config,
#      check_thirdparty, read_credits and test_list,
#   3. adds the test MD-TERA-CASSCF-NAD-VEC to NX_BIN/../test-nx (unless --no-tests).
#
# Every file it replaces is first saved as <file>.bak.<date-time>. The colib edits sit
# between '>>> newtonx-terachem-interface' marker comments, so running the script again
# replaces them instead of adding a second copy. Older hand-made TeraChem blocks for
# prog 21.0 are removed. Other programs' blocks are not touched.
#
use strict;
use warnings;
use File::Copy qw(copy);
use File::Path qw(mkpath);
use File::Basename qw(dirname);
use File::Temp qw(tempfile);
use Cwd qw(abs_path);
use POSIX qw(strftime);

my ( $dry, $notests, @args ) = ( 0, 0 );
foreach (@ARGV) {
    if    ( $_ eq "--dry-run" )  { $dry     = 1; }
    elsif ( $_ eq "--no-tests" ) { $notests = 1; }
    elsif (/^-/) { die "usage: perl install/install_nx.pl [--dry-run] [--no-tests] [NX_BIN]\n"; }
    else         { push @args, $_; }
}
my $nx = $args[0] // $ENV{NX} // die "Give the NewtonX bin folder, or set NX.\n";
$nx = abs_path($nx) // die "No such folder: $args[0]\n";
my $colib = "$nx/lib/colib_perl.pm";
die "$colib not found. Is $nx the NewtonX bin folder?\n" unless -e $colib;
my $repo  = abs_path( dirname( abs_path(__FILE__) ) . "/.." );
my $stamp = strftime( "%Y%m%d-%H%M%S", localtime );
my $tag   = "newtonx-terachem-interface";

print $dry ? "Dry run: nothing is written.\n" : "", "NewtonX bin: $nx\nInterface:   $repo\n\n";

#------------------------------------------------------------------------------------
# colib_perl.pm blocks
#------------------------------------------------------------------------------------

my %block;
$block{prog_config} = <<'EOT';
  if (($prog >= 20.95) and ($prog < 21.05)){
      %progconf=(progname   => "terachem",
                 methodname => "terachem",
                 ic         => "y",
                 dyn        => "y",
                 hyb        => "n",
                 ip         => "n",
                 key        => sprintf("%4.1f",21.0),
                 label      => "TeraChem",
                 method     => "CASSCF/FOMO-CASCI/TDA/hh-TDA/RPA",
                 parfile    => "terachem.par",
                 nad_exec   => "y",
                 lvprt_d    => 1,
                 vdoth_d    => 0,
                 never_state_d  => 0,
                 cio_options_d  => "NULL",
                 cisc_options_d => "NULL",
                 cprog_d    => 0,
                 progic     => "run_tera_ic.pl",
                 progdyn    => "run-tera-cas.pl");
    }
EOT

$block{check_thirdparty} = <<'EOT';
     ## TERACHEM ##
     #----------------------------------------------------------------------------
     if ($progname eq "terachem") {
       if (($type eq "ic") or ($type eq "dyn")){
         my $tc = $ENV{"TeraChem"};
         if (!defined($tc) or !-x "$tc/bin/terachem"){
           exit_error("TeraChem not found. Set the TeraChem variable to the TeraChem folder (the one with bin/terachem).",$mdle);
         }
       }
       if ($type eq "dyn"){
         my $vd = getkeyword("$BASEDIR/sh.inp","vdoth",2);   # NX's own default is 2
         if ($vd < 0){
           exit_error("vdoth = $vd is not supported by the TeraChem interface. Use vdoth = 0 (coupling vectors), 1 (overlaps, CAS methods only) or 2 (TD-BA).",$mdle);
         }
         if ($vd == 1){
           my $am = getkeyword("$BASEDIR/sh.inp","adjmom",-1);   # NX's default with vdoth = 1 is -1
           if ($am ne "" and $am >= 0){
             exit_error("adjmom = $am in sh.inp cannot be used with vdoth = 1. Time-derivative couplings give no coupling vector, so the momentum after a hop can only be rescaled along the velocity. Set adjmom = -1 in sh.inp, or leave it out.",$mdle);
           }
         }
         # Validate and show terachem.par with the interface's own reader.
         my $chk = `$ENV{"NX"}/run-tera-cas.pl --check-options $BASEDIR/$progpar 2>&1`;
         if ($? != 0){exit_error("Problem in $progpar: $chk",$mdle);}
         print_STDOUT("$chk\n");
       }
     }

EOT

$block{read_credits} = <<'EOT';
    if ($code eq "terachem"){
       $value =        "-----------------------------------------------------------------------\n";
       $value = $value."NEWTON-X/TeraChem interface, Matsika Lab, Temple University\n";
       $value = $value."github.com/Matsika-Lab/newtonx-terachem-interface\n";
       $value = $value."-----------------------------------------------------------------------\n";
    }
EOT

$block{test_list} = <<'EOT';
   # TERACHEM CASSCF NAD-VEC
   $counter++;
   if ($ind == $counter){
       $progname    = "TERACHEM       ";
       $method      = $cas;
       $description = "Dynamics, Non-adiabatic with coupling vectors";
       $dir         = "MD-TERA-CASSCF-NAD-VEC";
       $prog        = "$mld/moldyn.pl > moldyn.log";
       $file        = "RESULTS/dyn.out";
       $reg_exp     = $string[2];
       $field       = 5;
       $eps         = $e2;
   }

EOT

# Where each block goes: inside sub <name>, before the first line matching the anchor.
my %anchor = (
    prog_config      => qr/^\s*return %progconf;/m,
    check_thirdparty => qr/^\s*## HYBRID ##/m,
    read_credits     => qr/^\s*return \$value;/m,
    test_list        => qr/^\s*# STATISTICAL ANALYSIS/m,
);

my $text = slurp($colib);
my $orig = $text;

foreach my $name (qw(prog_config check_thirdparty read_credits test_list)) {
    # Earlier runs of this script.
    my $n = ( $text =~ s/^[^\n]*>>> \Q$tag\E: \Q$name\E >>>.*?<<< \Q$tag\E: \Q$name\E <<<[^\n]*\n//msg );
    print "colib: replaced the earlier $name block\n" if $n;
}
# Older hand-made TeraChem entries (as in the first README).
if ( $text =~ s/^[ \t]*if \(\(\$prog >= 20\.95\) and \(\$prog < 21\.05\)\)\s*\{\s*\n\s*%progconf\s*=\s*\(\s*progname\s*=>?\s*"terachem".*?progdyn[^\n]*\n\s*\}[ \t]*\n//ms ) {
    print "colib: removed an older TeraChem prog_config block (prog 21.0)\n";
}
# Older hand-made check_thirdparty block: the '## Terachem ##' header, its dashed line
# and the 'if ($progname eq "terachem") { ... }' block, found by brace matching so
# that nothing after it is touched.
while ( $text =~ /^[ \t]*## *terachem *##[ \t]*\n(?:[ \t]*#-*[ \t]*\n)?[ \t]*if *\(\$progname eq "terachem"\) *\{/img ) {
    my ( $start, $pos, $depth ) = ( $-[0], $+[0], 1 );
    while ( $depth > 0 && $pos < length $text ) {
        my $c = substr( $text, $pos++, 1 );
        $depth++ if $c eq "{";
        $depth-- if $c eq "}";
    }
    die "colib: unbalanced braces in the old TeraChem check_thirdparty block; fix it by hand.\n" if $depth;
    $pos++ while $pos < length($text) && substr( $text, $pos, 1 ) =~ /[ \t]/;
    $pos++ if substr( $text, $pos, 1 ) eq "\n";
    substr( $text, $start, $pos - $start ) = "";
    print "colib: removed an older TeraChem check_thirdparty block\n";
    pos($text) = $start;
}

# The test is listed in test_list only if its folder is installed below.
my $tests_dir = abs_path("$nx/..") . "/test-nx";
my $add_test  = !$notests && -d $tests_dir;

foreach my $name (qw(prog_config check_thirdparty read_credits test_list)) {
    next if $name eq "test_list" && !$add_test;
    my $start = index( $text, "sub $name" );
    die "colib: sub $name not found; this does not look like NewtonX 2.4 or 2.6.\n" if $start < 0;
    pos($text) = $start;
    $text =~ /$anchor{$name}/g or die "colib: insertion point for $name not found.\n";
    my $at = $-[0];
    my $ins = "    # >>> $tag: $name >>>\n$block{$name}    # <<< $tag: $name <<<\n";
    substr( $text, $at, 0 ) = $ins;
    print "colib: added the TeraChem $name block\n";
}

# Compile check of the edited module before anything is written.
my ( $tfh, $tmp ) = tempfile( "colib_check_XXXX", TMPDIR => 1, SUFFIX => ".pm", UNLINK => 1 );
print $tfh $text;
close $tfh;
my $out = `"$^X" -c "$tmp" 2>&1`;
die "The edited colib_perl.pm does not compile; nothing was changed.\n$out" unless $out =~ /syntax OK/;
print "colib: edited file compiles\n";

#------------------------------------------------------------------------------------
# Write
#------------------------------------------------------------------------------------

if ( $text ne $orig ) {
    install_text( $colib, $text );
}
foreach my $script (qw(run-tera-cas.pl run_tera_ic.pl)) {
    install_file( "$repo/$script", "$nx/$script", 0755 );
}

unless ($notests) {
    my $tests = $tests_dir;
    if ( -d $tests ) {
        my $name = "MD-TERA-CASSCF-NAD-VEC";
        copy_tree( "$repo/tests/nx/$name",                  "$tests/$name" );
        copy_tree( "$repo/tests/nx/STANDARD-RESULTS/$name", "$tests/STANDARD-RESULTS/$name" );
    }
    else {
        print "No test-nx folder next to $nx; test not installed.\n";
    }
}

print $dry ? "\nDry run finished.\n" : "\nDone. Set prog = 21.0 in control.dyn to use TeraChem.\n";

#------------------------------------------------------------------------------------

sub slurp { local ( @ARGV, $/ ) = @_; return <>; }

sub backup {
    my ($f) = @_;
    return unless -e $f;
    my $b = "$f.bak.$stamp";
    print "backup: $b\n";
    copy( $f, $b ) or die "Cannot back up $f: $!\n" unless $dry;
}

sub install_text {
    my ( $dest, $content ) = @_;
    backup($dest);
    print "write:  $dest\n";
    return if $dry;
    # Write a temporary file and rename it, so a running NewtonX never reads a half-written file.
    my $tmp = "$dest.new.$$";
    open my $fh, '>', $tmp or die "Cannot write $tmp: $!\n";
    print $fh $content;
    close $fh or die "Cannot write $tmp: $!\n";
    chmod( ( stat $dest )[2] & 07777, $tmp ) if -e $dest;
    rename $tmp, $dest or die "Cannot replace $dest: $!\n";
}

sub install_file {
    my ( $src, $dest, $mode ) = @_;
    die "$src not found\n" unless -e $src;
    if ( -e $dest && slurp($src) eq slurp($dest) ) {
        chmod $mode, $dest unless $dry;
        print "same:   $dest\n";
        return;
    }
    backup($dest);
    print "copy:   $dest\n";
    return if $dry;
    my $tmp = "$dest.new.$$";
    copy( $src, $tmp ) or die "Cannot copy $src to $tmp: $!\n";
    chmod $mode, $tmp;
    rename $tmp, $dest or die "Cannot replace $dest: $!\n";
}

sub copy_tree {
    my ( $src, $dest ) = @_;
    die "$src not found\n" unless -d $src;
    if ( -e $dest ) {
        if ( system( "diff", "-rq", $src, $dest ) == 0 ) {
            print "same:   $dest\n";
            return;
        }
        my $b = "$dest.bak.$stamp";
        print "backup: $b\n";
        rename $dest, $b or die "Cannot back up $dest: $!\n" unless $dry;
    }
    print "copy:   $dest\n";
    return if $dry;
    mkpath( dirname($dest) );
    system( "cp", "-r", $src, $dest ) == 0 or die "Cannot copy $src to $dest\n";
}
