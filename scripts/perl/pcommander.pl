#!/usr/bin/perl

#use strict;
use warnings;
use Tk;
use Tk::HList;
use Cwd;
use subs qw/accept get_filename read_config refresh_dirs show_dialog show_dir show_file/;
use subs qw/file_attributes tkc_exit write_config do_cmd start_cmd view_text view_text_mode/;
use subs qw/find_text/;

use constant MAXTEXT  => 1000000;  # Limit textfile size to something sane
# try to be OS independent
use constant ROOTDIR  => '/';
use constant UPLEVEL  => '/..';

my $VER = "0.1";

# OS dependent vars
my ($modifier, $filesep, $tmpdir);
if ($^O eq 'MSWin32') {
   $ENV{ HOME } = 'C:/' unless $ENV{ HOME };
   $modifier = 'Control';   # Windows uses ctrl+key
   $filesep = "\\";
   $tmpdir = "C:\\tmp\\";
} else {
   $modifier = 'Meta';    # Unix uses alt+key
   $filesep = "/";
   $tmpdir = "/tmp/";
}

my $docdir = '/usr/share/doc/tkc';

# If config file gets messed up, delete it to return to defaults
my $config_file   = '.tkc.rc'; 
my %config=(Box_height   => 20,    # file box height
      Box_width    => 30,    # file box width
      Path_L      => ROOTDIR,   # Left box path
      Path_R      => ROOTDIR,   # Right box path
      Show_hidden_L => 0,   # Show hidden files
      Show_hidden_R => 0,
      Dirs_first_L  => 0,   # show dirs before files
      Dirs_first_R  => 0,
      Case_fold_L   => 0,   # mix U/lc
      Case_fold_R   => 0,
      Size_L      => 1,   # display size of files
      Size_R      => 1,
      Sort_L      => 'a',  # alpha, date or size
      Sort_R      => 'a' );

# Default button bindings, overwritten by config file values
# Always have at least the editor and viewer.
# Add a new file type by adding three lines:
#   %apps    are the applications to run when the file is run
#   %filepat  are regular expressions which match the filename
#          $badpat never matches, app string is saved in .tkc.rc
#   %icons   are 12 X 12 pixmaps to display next to the name
$badpat = 'a b c';

$apps{ 'Browser' } = 'firefox file:%n &';
$filepat{ 'Browser' } = '\.s?html?$';
$icons{ 'Browser' } = \$NSIMG;

$apps{ 'Adobe' } = 'acroread %n &';
$filepat{ 'Adobe' } = '\.pdf$';
$icons{ 'Adobe' } = \$PDFIMG;

$apps{ 'MP3' } = 'mpg123 -q %l &';
$filepat{ 'MP3' } = '\.mp3$';
$icons{ 'MP3' } = \$IMG;

$apps{ 'Image' } = 'eog %l &';
$filepat{ 'Image' } = '\.(gif|jpe?g|xpm|tiff?|bmp|p[gbp]m|png)$';
$icons{ 'Image' } = \$IMG;

$apps{ 'Pack' } = 'gzip %l%q';
$filepat{ 'Pack' } = $badpat;
$icons{ 'Pack' } = '';

$apps{ 'Unpack' } = 'gunzip %l%q';
$filepat{ 'Unpack' } = $badpat;
$icons{ 'Unpack' } = '';

$apps{ 'Print' } = 'lpr -p %l%q';
$filepat{ 'Print' } = $badpat;
$icons{ 'Print' } = '';

$apps{ 'Spreadsheet' } = '/usr/lib/openoffice/program/soffice.bin %n';
$filepat{ 'Spreadsheet' } = '\.gnumeric$';
$icons{ 'Spreadsheet' } = \$SPDIMG;

$apps{ 'Java' } = 'java -jar %b &';
$filepat{ 'Java' } = '\.jar$';
$icons{ 'Java' } = \$JAVIMG;

$apps{ 'Editor' } = 'gvim %n &' ;
$filepat{ 'Editor' } = $badpat;
$icons{ 'Editor' } = '';

$apps{ 'Writer' } = '/usr/lib/openoffice/program/soffice.bin %n';
$filepat{ 'Writer' } = '\.(doc|sxw)$';
$icons{ 'Writer' } = \$TXTIMG;

$apps{ 'Shell' } = 'gnome-terminal --working-directory=%p &';
$filepat{ 'Shell' } = $badpat;

# Viewer is last because it might overlap other filepats
$apps{ 'Viewer' } = '%v %n';
$filepat{ 'Viewer' } = '^READ';
$icons{ 'Viewer' } = \$TXTIMG;


my ($dir_L, $dir_R);
my ($box_L, $box_R);

sub refresh_dirs {
   show_dir ( $dir_L->cget( "-text" ), $box_L );
   show_dir ( $dir_R->cget( "-text" ), $box_R );
}

# Read the config file.  The format  of all lines is:
# <keyword> = <value>
sub read_config {
   chdir;
   open (CFG, $config_file) || return 0;
   SW: while ( <CFG> ) {
   chomp;      # get rid of newline (if present)
   next SW if /^\#/;
   if ( /^\/(\w*)\s*=\s*(.*)/ ) {
      $filepat{ $1 } = $2;
      next SW;
   }
   if ( /^(\w*)\s*=\s*(.*)/ ) {
      if (exists( $config{ $1 } )) {
         $config{ $1 } = $2;
      } 
      else {
         $apps{ $1 } = $2;
      }
      next SW;
   }
   }
}

# Update the config file on exit
sub write_config {
   $config{"Path_L"} = $dir_L->cget( "-text" );
   $config{"Path_R"} = $dir_R->cget( "-text" );
   chdir;
   open (CFGW, '>', $config_file) or return 0;
   foreach my $k ( keys %config ) {
      printf CFGW "%s = %s\n", $k, $config{ $k };
   }
   foreach my $k ( keys %apps ) {
      printf CFGW "%s = %s\n", $k, $apps{ $k };
      printf CFGW "/%s = %s\n", $k, $filepat{ $k };
   }
   close CFGW;
}


######################## Debug Subroutines ###################

# Try to determine box size from font metrics
# font linespace = 18 pixels?
#   box_height 16 = 232  wid 60 = 451
#              20 = 288     70 = 521
#   pixels = 14 * lines + 8
#          =  7 * chars + 31 (scrollbar & images)
sub get_size {
   require Tk::Font;
   my ($font, $f_wid, $f_ht);
   $font = $dir_L->fontCreate(-family=>"Courier", -size=>9  );
   printf("%s\n",$font->Pattern);
   $f_ht = $font->metrics(-linespace);
   $f_wid = $font->measure("Amblyopias")/10;
   printf("Font height: %d\n",$f_ht);
   printf("Font width:  %d\n",$f_wid);
   printf("L: Wid: %d Ht: %d (%d)\n",$box_L->Width,
     $box_L->Height, $box_L->Height / $f_ht);
}

# print the options for a widget
# This is handy for testing.
sub print_widget {
   my $arg = shift;
   my @list = ( $arg->configure ); 
   my $opt;
   printf("\nConfig options:\n");
   foreach $opt (@list) {
   printf("%s => %s\n",$opt->[0],$opt->[4]);
   }
}

########################### Subroutines ######################

# Configure display options dialog box
# Displays current options as a grid with options for left box on left, right on right.
# User may change values in dialog box, then accept changes with OK. 
# Cancel will close the dialog without changing the options.
sub config_dpy {
   my ($Show_hidden_L, $Dirs_first_L, $Case_L, $Sort_L, $Size_L) = 
   ($config{Show_hidden_L}, $config{Dirs_first_L}, $config{Case_fold_L}, 
   $config{Sort_L}, $config{Size_L});
   my ($Show_hidden_R, $Dirs_first_R, $Case_R, $Sort_R, $Size_R) = 
   ($config{Show_hidden_R}, $config{Dirs_first_R},  $config{Case_fold_R}, 
   $config{Sort_R}, $config{Size_R});
   my $db = $Mainwin->Toplevel;
   my $f1=$db->Frame;
   $f1->Label(-text=>"Configure Display")->grid(-sticky=>'w', -columnspan => 2, -column=>0, -row => 0);
   $f1->Checkbutton(-variable=>\$Show_hidden_L)->grid(-sticky=>'w', -column=>0,-row=>1);
   $f1->Checkbutton(-text=>"Show hidden files", -variable=>\$Show_hidden_R)->grid(-sticky=>'w', -column=>1,-row=>1);
   $f1->Checkbutton(-variable=>\$Dirs_first_L)->grid(-sticky=>'w', -column=>0,-row=>2);
   $f1->Checkbutton(-text=>"Show directories first", -variable=>\$Dirs_first_R)->grid(-sticky=>'w', -column=>1,-row=>2);
   $f1->Checkbutton(-variable=>\$Size_L)->grid(-sticky=>'w', -column=>0,-row=>3);
   $f1->Checkbutton(-text=>"Show file sizes", -variable=>\$Size_R)->grid(-sticky=>'w', -column=>1,-row=>3);
   $f1->Checkbutton(-variable=>\$Case_L)->grid(-sticky=>'w', -column=>0,-row=>4);
   $f1->Checkbutton(-text=>"Fold case", -variable=>\$Case_R)->grid(-sticky=>'w', -column=>1,-row=>4);
   $f1->Radiobutton(-variable=>\$Sort_L, -value=>'a')->grid(-sticky=>'w', -column=>0,-row=>5);
   $f1->Radiobutton(-variable=>\$Sort_L, -value=>'d')->grid(-sticky=>'w', -column=>0,-row=>6);
   $f1->Radiobutton(-variable=>\$Sort_L, -value=>'s')->grid(-sticky=>'w', -column=>0,-row=>7);
   $f1->Radiobutton(-text=>"Sort by name", -variable=>\$Sort_R, -value=>'a')->grid(-sticky=>'w', -column=>1,-row=>5);
   $f1->Radiobutton(-text=>"Sort by date", -variable=>\$Sort_R, -value=>'d')->grid(-sticky=>'w', -column=>1,-row=>6);
   $f1->Radiobutton(-text=>"Sort by size", -variable=>\$Sort_R, -value=>'s')->grid(-sticky=>'w', -column=>1,-row=>7);
   my $f2=$db->Frame;
   my $ok = $f2->Button( -text => "OK", -width =>9,-command =>sub {
        ($config{Show_hidden_L}, $config{Dirs_first_L}, $config{Case_fold_L}, 
         $config{Sort_L}, $config{Size_L}) =
       ($Show_hidden_L, $Dirs_first_L, $Case_L, $Sort_L, $Size_L);
        ($config{Show_hidden_R}, $config{Dirs_first_R},  $config{Case_fold_R}, 
         $config{Sort_R}, $config{Size_R}) =
       ($Show_hidden_R, $Dirs_first_R, $Case_R, $Sort_R, $Size_R);
        $db->destroy;
     } )->pack(-side=>"left", -fill=>"x");
   my $can = $f2->Button( -text => "Cancel", -width =>9,-command =>sub { $db->destroy; } )->pack(-side=>"right", -fill=>"x");
   $f1->pack(-side=>"top", -expand=>1);
   $f2->pack(-side=>"bottom", -expand=>1);
   $db->raise;              # make viewable
   $db->grab;               # set local grab
   $db->tkwait('window',$db);   # wait for window event
   refresh_dirs;
}

# Configure applications dialog box, add slider if too tall
sub config_apps {
   my @pl = (-side=>'top', -anchor=>'w');
   my $db = $Mainwin->Toplevel;
   my $f1=$db->Frame;
   foreach my $k ( keys %apps ) {
      $f1->Label(-text=>"$k")->pack(@pl);
      $f1->Entry(-textvariable=>\$apps{ $k }, -width=>40, -background=>"white")->pack;
   }
   my $f2=$db->Frame;
   my $ok = $f2->Button( -text => "OK", -width =>9,-command =>sub { $db->destroy; } )->pack(-side=>"left", -fill=>"x");
   $f1->pack(-side=>"top", -expand=>1);
   $f2->pack(-side=>"bottom", -expand=>1);
   $db->raise;                  # make viewable
   $db->grab;                   # set local grab
   $db->tkwait('window',$db);   # wait for window event
}

# Configure applications dialog box
# +++ Needs a cancel button?
sub config_filepats {
   my @pl = (-side=>'top', -anchor=>'w');
   my $db = $Mainwin->Toplevel;
   my $f1=$db->Frame;
   foreach my $k ( keys %apps ) {
      if ($filepat{$k} ne $badpat) {
         $f1->Label(-text=>"Filename pattern for $k")->pack(@pl);
         $f1->Entry(-textvariable=>\$filepat{ $k }, -width=>40, -background=>"white")->pack;
      }
   }
   my $f2=$db->Frame;
   my $ok = $f2->Button( -text => "OK", -width =>9,-command =>sub { $db->destroy; } )->pack(-side=>"left", -fill=>"x");
   $f1->pack(-side=>"top", -expand=>1);
   $f2->pack(-side=>"bottom", -expand=>1);
   $db->raise;                  # make viewable
   $db->grab;                   # set local grab
   $db->tkwait('window',$db);   # wait for window event
}

# Make a date string from ctime
sub make_date {
   my $ctime = shift;
   my $now = shift;
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($ctime);
   if ($now - $ctime < 24 * 60 * 60) {
      $yday = sprintf("%02d:%02d:%02d",$hour,$min,$sec);
   } else {
      $yday = sprintf("%d/%d/%02d",$mon+1,$mday,$year%100);
   }
   return $yday;
}

# Return just the filename from a full entry
# Args:
#   full entry
# Removes trailing size or date
sub get_filename {
   my $text = shift;
   $text =~ s| \(.*||;
   return $text;
}

########################### Commands ######################

# Process quit command
sub tkc_exit {
   my $nosave = shift;
   write_config unless $nosave;
   exit;
}

# double-clicking acts only on the active element.
# The action to be taken is already determined in the 'data' attribute
#
sub up_L {
   my $sel = $dir_L->cget( "-text" );
   accept($box_L, $dir_L, $sel);
}

sub up_R {
   my $sel = $dir_R->cget( "-text" );
   accept($box_R, $dir_R, $sel);
}

sub accept_L {
   my $sel = shift;
   accept($box_L, $dir_L, $sel);
}

sub accept_R {
   my $sel = shift;
   accept($box_R, $dir_R, $sel);
}

sub accept {
   my $box = shift;
   my $dir = shift;
   my $sel = shift;
   my $entry = $sel;  # entry left as-is

   # convert to full pathname
   $sel = get_filename($sel);
   $sel =~ s|\*|/|;
   $sel =~ s|//|/|;
   my $current = $dir->cget( "-text" );

   #get file type
   my $type = $box->info("data",$entry);
   if ($type eq "DIR") {
      # Go up
      if ( $current eq $sel ) {
         $sel = $sel . UPLEVEL;
      }
      chdir $sel;
      $sel = cwd;
      $dir->configure( -text => $sel );
      show_dir($sel, $box);
   } 
   elsif ($type eq "EXE") {
      # execute it with an arg
      chdir $current;
      my $cmd = $sel . " &";
      my $rc = show_dialog( $cmd, 0 );
      if ( $rc < 0 ) {
         return;
      }
      system $cmd;
   } 
   elsif ($type eq "FILE") {
      # Default action is to show file info
      # +++ should do menu: ren, move, etc. ?
      show_file( $sel );
   } 
   else {
      # Special type in @apps, call start_cmd to deal with it
      $box->selectionSet($entry);
      start_cmd($type);
   } 
}

# Print help to a dialog box.  Help is a tearoff menu and non-modal so
# it can be kept on the screen while learning tkc.
sub help_menu {
   my $h = shift;
   my $text;
   if ($h eq 'about') {
   $text = "PerlCommander ${VER}\n"
           . "Atos Origin BV\n"
       . "Perl/Tk version $Tk::VERSION\n";
   $Mainwin->messageBox( -icon => 'info', -type => OK, -title => $h, -message => $text );
   }
}

{
# Block to create lexical variables
   my ( $dial, $dial_arg, $dial_f1, $dial_f2, $dial_e, $multi );

# Show command in a modal dialog box, allow edit. 
#   "arg to display", "multi"
# return 0 (ok), 1 (all), -2 (skip), -1 (cancel)
sub show_dialog {
   ($dial_arg, $multi) = ( @_ );
   my $rc = 0;
   $dial = $Mainwin->Toplevel(-takefocus=>1);
   $dial_f1=$dial->Frame;
   $dial_f1->Label(-text=>"Edit parameters:")->pack;
   $dial_e = $dial_f1->Entry(-width=>40, -background=>"white",-textvariable=>\$dial_arg )->pack;
   $dial_f2=$dial->Frame;
   $dial_f2->Button( -text => "OK", -width =>9,-command =>sub { $dial->grabRelease; $rc=0;$dial->destroy;  } )->pack(-side=>"left", -fill=>"x");
   if ($multi) {
      $dial_f2->Button( -text => "All", -width =>9,-command =>sub { $dial->grabRelease; $rc=1; $dial->destroy;  } )->pack(-side=>"left", -fill=>"x");
      $dial_f2->Button( -text => "Skip", -width =>9, -command =>sub { $dial->grabRelease; $rc=-2;$dial->destroy; } )->pack(-side=>"left", -fill=>"x");
   }
   $dial_f2->Button( -text => "Cancel", -width =>9, -command =>sub { $dial->grabRelease; $rc=-1; $dial->destroy; } )->pack(-side=>"right", -fill=>"x");
   $dial_f1->pack(-side=>"top", -expand=>1);
   $dial_f2->pack(-side=>"bottom", -expand=>1);
   $dial->raise;                    # make it viewable before trying to grab
   $dial->grab;                     # set local grab
   $dial_e->icursor('e');           # Set cursor at end of line
   $dial_e->focus;                  # set the focus
   $dial->tkwait('window',$dial);   # wait for window event
   $_[0] = $dial_arg;               # set the edited value
   return $rc;
   }
}

# Show system info in a modal dialog box. 
# return string or Null if canceled
sub sysinfo_dialog {
   my $db = $Mainwin->Toplevel(-takefocus=>1);
   my $f1=$db->Frame;
   my $row = 0;
   $f1->Label(-text=>"System Information")->grid(-sticky=>'n', -columnspan => 2, -column=>0, -row => $row);
   $row++;
   my $var=`hostname`;
   chomp $var;
   $f1->Label(-text=>"Hostname:")->grid(-sticky=>'w', -column=>0,-row=>$row);
   $f1->Label(-text=>$var)->grid(-sticky=>'w', -column=>1,-row=>$row);
   $row++;
   $var=`uname -s`;
   chomp $var;
   $var .=  " ver " . `uname -r`;
   chomp $var;
   $f1->Label(-text=>"OS:")->grid(-sticky=>'w', -column=>0,-row=>$row);
   $f1->Label(-text=>$var)->grid(-sticky=>'w', -column=>1,-row=>$row);
   $row++;
   $var=`uname -m`;
   chomp $var;
   $f1->Label(-text=>"CPU:")->grid(-sticky=>'w', -column=>0,-row=>$row);
   $f1->Label(-text=>$var)->grid(-sticky=>'w', -column=>1,-row=>$row);
   $row++;
   # Memory
   $var="";
   if ( open (INPUT, "</proc/meminfo" ) ) {
      while ( <INPUT> ) {
     chomp;
     if ( /^MemTotal:\s*(.*)/ ) { $var=$1; }
   }
      close (INPUT);
   }
   if ( $var ) {
      $f1->Label(-text=>"Memory:")->grid(-sticky=>'w', -column=>0,-row=>$row);
      $f1->Label(-text=>$var)->grid(-sticky=>'w', -column=>1,-row=>$row);
      $row++;
   }
   # Disk
   if ( open (INPUT, "</proc/partitions" ) ) {
      while ( <INPUT> ) {
         chomp;
         my ($maj, $min, $bks, $nam) = split;
         if ( $nam && $nam =~ /^hd[a-z]$/ ) { 
            $bks = int( $bks * 512 / 1000000 );
            $f1->Label(-text=>"Disk $nam:")->grid(-sticky=>'w', -column=>0, -row=>$row);
            $f1->Label(-text=>"$bks MB")->grid(-sticky=>'w', -column=>1, -row=>$row);
            $row++;
         }
      }
      close (INPUT);
   }
   # OK button
   $f2=$db->Frame;
   $f2->Button( -text => "OK", -width =>9,-command =>sub { $db->grabRelease; $db->destroy;  } )->pack(-side=>"left", -fill=>"x");
   $f1->pack(-side=>"top", -expand=>1);
   $f2->pack(-side=>"bottom", -expand=>1);
   $db->raise;                   # make it viewable before trying to grab
   $db->grab;                    # set local grab
   $db->tkwait('window',$db);    # wait for window event
}


# Start an app
# This executes an app managed by start_menu
# Macros in the start call are:
#   %l - source filename list (space separated)
#   %n - source filenames, one at a time, quotes spaces
#   %t - target directory
#   %p - current path
#   %q - show a dialog with OK/cancel
#   &  - dont wait for completion 
sub start_cmd {
   printf("DEBUG: Entering sub start_cmd\n");
   my $cmd;      # command name (index into app hash)
   $_ = shift;
   my $source;   # directory with selected files
   my $target;   # directory in other box
   my $rc;
   my $arg = '';  # aggregate arg with spaces

   my @sel = $$cur_box->info("selection");
   for (my $ix = 0; $ix <= $#sel; $ix++) {
      $sel[$ix] =~ s|\*|/|;
      $sel[$ix] =~ s|//|/|;
      $arg .= "\"$sel[$ix]\" ";
   }
   if ($$cur_box == $box_L ) {
      $source = $dir_L->cget( "-text" );
      $target = $dir_R->cget( "-text" );
   } 
   elsif ($$cur_box == $box_R ) {
      $source = $dir_R->cget( "-text" );
      $target = $dir_L->cget( "-text" );
   } 

   # +++ These should really all be taken from the @apps list
   $cmd = '';
   SWITCH: {
      $cmd = $apps{'Editor'}, last SWITCH if /^edit/;
      $cmd = $apps{'Viewer'}, last SWITCH if (/^view/ || /^Viewer/);
      $cmd = 'cp %l %t',     last SWITCH if /^copy/;
      $cmd = 'rm %n%q',      last SWITCH if /^del/;
      $cmd = 'ln %l %t%q',   last SWITCH if /^link/;
      $cmd = 'mv %l %t%q',   last SWITCH if /^move/;
      $cmd = 'mv %l %l%q',   last SWITCH if /^ren/;
      $cmd = 'mkdir %p%q',   last SWITCH if /^mkdir/;
      $cmd = $apps{'Browser'}, last SWITCH if /^Browser/;
      $cmd = $apps{'Adobe'},  last SWITCH if /^Adobe/;
      $cmd = $apps{'MP3'},   last SWITCH if /^MP3/;
      $cmd = $apps{'Image'},  last SWITCH if /^Image/;
      $cmd = $apps{'Pack'},   last SWITCH if /^pack/;
      $cmd = $apps{'Unpack'}, last SWITCH if /^unpack/;
      $cmd = 'Chmod %n',     last SWITCH if /^chmod/;
      $cmd = $apps{'Print'},  last SWITCH if /^print/;
      $cmd = $apps{'Spreadsheet'}, last SWITCH if /^Spreadsheet/;
      $cmd = $apps{'Java'},   last SWITCH if /^Java/;
      $cmd = $apps{'Writer'}, last SWITCH if /^Writer/;
      $cmd = $apps{'Shell'},  last SWITCH if /^Shell/;
      $cmd = 'finfo', last SWITCH if /^finfo/;
   }

   # Do macro substitution
   if ( $cmd =~ /%l/ ) {
      if ( $#sel < 0 ) {
         return;
      }
      $cmd =~ s|%l|$arg|g;
   }

   # basename is filename to last '.', then same as %n
   if ( $cmd =~ /%b/ ) {
      for (my $f=0; $f <= $#sel; $f++){
         $sel[$f] =~ s|^.*/(.*)\.(.*)$|$1|;
      }
      $cmd =~ s|%b|%n|g;
   }

   $cmd =~ s|%t|"$target"|g;
   $cmd =~ s|%p|"$source"|g;

   CAN: {
   if ( $cmd =~ /%n/ ) {
      foreach $file (@sel){
         my $c = $cmd;
         my $f = $file;
         $f =~ s/ /\\ /g;  # quote spaces in file for %n
         $c =~ s|%n|$f|g;
         # break from loop on cancel
         $rc = do_cmd ( $c, $file, $#sel );
         last CAN if ($rc == -1);
         if ($rc == 1) {
            # do All
            $cmd =~ s|%q||g;
         }
      }
   } 
   else {
      do_cmd ( $cmd, $arg, 0 );
   }
   }
   refresh_dirs;
}

# Evaluate cmd 
# Return codes same as show_dialog
sub do_cmd {
   my $cmd = shift;
   my $arg = shift;
   my $multi = shift;
   my $rc = 0;

   # Check for dialog box
   if ( $cmd =~ /%q/ ) {
   $cmd =~ s|%q||g;
   $rc = show_dialog($cmd, $multi);
   if ( $rc < 0 ) {
      return $rc;
   }
   }
   if ($cmd eq '') {
   $Mainwin->messageBox( -icon => 'error', -type => OK, -title => 'Error',
            -message => 'No value set for ' . $_ );
   } elsif ($cmd =~ '^rm ') {
   # Special processing to do different things to del files or directories
   if ( -d $arg ) {
      # +++ This wont delete a non-empty dir, need a dialog
      rmdir $arg;
   } else {
      unlink ($arg);
   }
   } elsif ($cmd =~ '^mkdir ') {
   eval $cmd;
   } elsif ($cmd eq 'finfo') {
   show_file( $arg );
   } elsif ($cmd =~ /^Chmod/ ) {
   file_attributes( $arg );
   } elsif ($cmd =~ /^%v/ ) {
   view_text($Mainwin, $arg );
   } else {
   system $cmd;
   }
   return $rc;
}

# Modified to only show one level
# Selects file types for calling special apps.
# +++ Should do something about filenames which actually contain '*'
sub show_dir {
   my ($entry_path, $h) = @_;
   my ($Show_hidden, $Dirs_first, $Case, $Sort, $Size) =  ($h == $box_L ) ?
   ($config{Show_hidden_L}, $config{Dirs_first_L}, $config{Case_fold_L}, 
   $config{Sort_L}, $config{Size_L}) :
   ($config{Show_hidden_R}, $config{Dirs_first_R}, $config{Case_fold_R},  
    $config{Sort_R}, $config{Size_R});
   chdir $entry_path;
   $entry_path = cwd;
   opendir H, $entry_path;
   my(@dirent) = grep ! /^\.\.?$/, readdir H;
   closedir H;
   $h->delete( "all" );
   $h->add($entry_path,  -text => "..", -image => $FOLDIMG, -data => 'DIR');

   # Put directory into sval to sort
   my @sval;
   my $ix=0;
   my $now = time;
   foreach $_ (@dirent) {
   my $name = $_;
   if (( $_ =~ /^\./ ) && ( ! $Show_hidden )) {
   } else {
      my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
     $atime,$mtime,$ctime,$blksize,$blocks)
     = stat($name);

      $size = 0 if !defined($size);  # not set on symbolic links
      $ctime = 0 if !defined($ctime);  # not set on symbolic links

      # $sortval string is value followed by entry
      # Assumes '|' does not appear in name
      my $sortname = $Case ? lc : $_;
      if ($Sort eq 's') {
     if (-d $name) {  # dont show or sort on size for directories
        $sortval = "00000000$sortname |$_";
     } else {
        $sortval = sprintf "%9d |%s (%d)",$size,$_,$size;
     }
      } elsif ($Sort eq 'd') {
     $sortval = sprintf "%012d |%s (%s)",$ctime,$_,make_date($ctime,$now);
      } else {
     if ($Size) {
        $sortval = sprintf "%s |%s (%d)",$sortname,$_,$size;
     } else {
        $sortval = "$sortname |$_";
     }
      }
      if( $Dirs_first && (-d $name)) {
     $sortval = "\t".$sortval;   # Assumes \t less than any char
      }
      
      $sval[$ix] = $sortval;
      $ix++;
   }

   }
   
   # stringwise sort
   my @sorted = sort @sval;

   # Now add the files into the box
   for ($b = 0; $b < $ix; $b++) {
   my $found_app = 0;
      my ($foo, $text);

   # Extract the entry
   ($foo, $text) = split (/\|/, $sorted[$b]);
   my $name = get_filename ($text);
   my $fname = "$entry_path/$name";
   my $file = "$entry_path\*$name";

   # Classify the file
     SW: {
   # Directory
    if (-d $name) {
       $h->add($file,  -text => $text, -image => $FOLDIMG, -data => 'DIR');
       last SW;
    }
    # app in filepat
    foreach my $k ( keys %apps ) {
       if ( $name =~ /$filepat{$k}/ ) { 
      my $iref = $icons{$k};
      $h->add($file,  -text => $text, -image => $$iref, -data => $k );
      last SW;
       }
    }
    # executable
    if ( -x $name ) {
       $h->add($file,  -text => $text, -image => $EXEIMG, -data => 'EXE');
       last SW;
    }
    # default action
    $h->add($file,  -text => $text, -image => $FILEIMG, -data => 'FILE');
     }
   }
} # end show_dir

# File information
#   file info: name, size, owner/grp, perms, type, link, dates
sub show_file {
   my $name = shift;
   if ($name eq '') { 
   return; 
   }
   my ($i, $who, $m, $c);
   my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
   $atime,$mtime,$ctime,$blksize,$blocks)
   = stat($name);
   if (!defined($size)) {
   $Mainwin->messageBox( -icon => 'error', -type => OK, -title => 'Error',
            -message => "Can\'t stat $name" );
   return;
   }
   my @pl = (-side=>'top', -anchor=>'w', -fill=>'none' );
   my $db = $Mainwin->Toplevel;
   my $f1=$db->Frame;
   $f1->Label(-text=>sprintf("Name:\t%s",$name))->pack(@pl);
   my $sz = sprintf("Size:\t%d",$size);
   if ($size > 10000000) {
   $sz .= sprintf(" (%d MB)",$size/1000000);
   } elsif ($size > 10000) {
   $sz .= sprintf(" (%d KB)",$size/1000);
   }
   $f1->Label(-text=>$sz)->pack(@pl);
   $f1->Label(-text=>sprintf("Owner:\t%d",$uid))->pack(@pl);
   $f1->Label(-text=>sprintf("Group:\t%d",$gid))->pack(@pl);
   $f1->Label(-text=>sprintf("Links:\t%d",$nlink))->pack(@pl);
   my $s="";
   for ($who=2; $who >= 0; $who--) {   # select owner, group or other
   $m = $mode >> (3 * $who);
   $s .= ($m & 4) ? "r" : "-";
   $s .= ($m & 2) ? "w" : "-";
   $c  = ($m & 1) ? "x" : "-";
   if (($who == 2) &&            # setuid bit
      ($mode & 0x800)) {
     $c = ($m & 1) ? "s" : "S";
   }
   elsif (($who == 1) &&          # setgid bit
       ($mode & 0x400)) {
     $c = ($m & 1) ? "s" : "S";
   }
   elsif (($who == 0) &&          # sticky bit
       ($mode & 0x200)) {
     $c = ($m & 1) ? "t" : "T";
      }
   $s .= $c;
   }
   $f1->Label(-text=>sprintf("Mode:\t%s",$s))->pack(@pl);
   my $date = localtime($mtime);
   $f1->Label(-text=>sprintf("Modify:\t%s",$date))->pack(@pl);

   my $ftype = `file $name`;
   $ftype =~ s/.*: //;
   $f1->Label(-text=>sprintf("Type:\t%s",$ftype))->pack(@pl);
   
   $f1->pack(-side=>"top", -expand=>0);
   my $f2=$db->Frame;
   my $ok = $f2->Button( -text => "OK", -width =>9,
         -command =>sub { $db->destroy; } )
   ->pack(-side=>"left", -fill=>"x");
   $f2->pack(-side=>"bottom", -expand=>1);
   $db->raise;              # make viewable
   $db->grab;               # set local grab
   $db->tkwait('window',$db);   # wait for window event
}

# Dialog box for chmod for one file
#  display current permissions
#  get user input
#  if cancel, just return
#  if OK, change the attributes
# +++ For a list of files, need 3-value checkboxes:
#   N/A   - not all files have same value and not modified
#   set   - all files have value set, or user wants to set all files
#   unset - all files have value not set, or user wants to unset all files
# +++ Also need 3 buttons
#   OK - set modified values for all files
#   Cancel - leave all files unchanged
#   Reset - set all boxes back to current state of files
#
sub file_attributes {
   my @pl = (-side=>'top', -anchor=>'w');
   my $name = shift;
   if ($name eq '') { 
   return; 
   }
   my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
   $atime,$mtime,$ctime,$blksize,$blocks)
   = stat($name);
# +++ Should check for null return
   my @p;
   my ($i);
   for ($i = 11; $i >= 0; $i--) {
   $p[$i] = ($mode >> $i) & 1;
   }
   my $db = $Mainwin->Toplevel(-takefocus=>1);
   my $f1=$db->Frame;
      $f1->Label(-text=>$name)->grid(-row=>0, -columnspan=>4, -sticky=>'w');
      $f1->Label(-text=>"File Attributes")
     ->grid(-row=>1, -columnspan=>4, -sticky=>'w');
      $f1->Label(-text=>"User")->grid(-row=>2, -column=>0);
      $f1->Label(-text=>"Group")->grid(-row=>2, -column=>1);
      $f1->Label(-text=>"Other")->grid(-row=>2, -column=>2);
      $f1->Checkbutton(-text=>"", -variable=>\$p[8])->grid(-row=>3, -column=>0);
      $f1->Checkbutton(-text=>"", -variable=>\$p[5])->grid(-row=>3, -column=>1);
      $f1->Checkbutton(-text=>"", -variable=>\$p[2])->grid(-row=>3, -column=>2);
      $f1->Label(-text=>"Read")->grid(-row=>3, -column=>3, -sticky=>'w');
      $f1->Checkbutton(-text=>"", -variable=>\$p[7])->grid(-row=>4, -column=>0);
      $f1->Checkbutton(-text=>"", -variable=>\$p[4])->grid(-row=>4, -column=>1);
      $f1->Checkbutton(-text=>"", -variable=>\$p[1])->grid(-row=>4, -column=>2);
      $f1->Label(-text=>"Write")->grid(-row=>4, -column=>3, -sticky=>'w');
      $f1->Checkbutton(-text=>"", -variable=>\$p[6])->grid(-row=>5, -column=>0);
      $f1->Checkbutton(-text=>"", -variable=>\$p[3])->grid(-row=>5, -column=>1);
      $f1->Checkbutton(-text=>"", -variable=>\$p[0])->grid(-row=>5, -column=>2);
      $f1->Label(-text=>"Execute")->grid(-row=>5, -column=>3, -sticky=>'w');
      $f1->Checkbutton(-text=>"", -variable=>\$p[11])->grid(-row=>6, -column=>0);
      $f1->Checkbutton(-text=>"", -variable=>\$p[10])->grid(-row=>6, -column=>1);
      $f1->Checkbutton(-text=>"", -variable=>\$p[9])->grid(-row=>6, -column=>2);
      $f1->Label(-text=>"SUID,SGID,Sticky")
     ->grid(-row=>6, -column=>3, -sticky=>'w');
   my $f2=$db->Frame;
   my $ok = $f2->Button( -text => "OK", -width =>9,
         -command =>sub { 
        $mode &= 0xF000;
        for ($i = 11; $i >= 0; $i--) {
       $mode |= $p[$i] ? (1 << $i) : 0;
        }
        chmod $mode, $name;
        $db->destroy; } )
   ->pack(-side=>"left", -fill=>"x");
   my $can = $f2->Button( -text => "Cancel", -width =>9,
     -command =>sub { $db->destroy; } )->pack(-side=>"right", -fill=>"x");
   $f1->pack(-side=>"top", -expand=>1);
   $f2->pack(-side=>"bottom", -expand=>1);
   $db->raise;              # make viewable
   $db->grab;               # set local grab
   $db->tkwait('window',$db);   # wait for window event
   refresh_dirs;
}

{ # begin block lexical scoped variables for callback context
   my ($text, $astr, $str, $mode, $ftext, $search_pt, $search_len);
   my $afont = '-*-Helvetica-Medium-R-Normal--*-140-*-*-*-*-*-*';
   my $hfont = '-*-Courier-Medium-R-Normal--*-140-*-*-*-*-*-*';
   my $case = 0;

# Show text from $filename in viewer. $mw = main window.
# For really big files we want to only read a portion into 
# memory at a time, but let's let Perl worry about that for now.
# Search for string, starting at $search_pt.
# $search_pt is beginning of text when loaded, moves with
#   each search, wraps around to beginning.
#   +++ option for search reverse (rindex)? (bind to BS)
# binds ^f to search, enter to Find/Next, esc to quit
sub view_text_mode {
   my $hex;
   $text->delete('1.0', 'end');
   $astr = $str;
   if ($mode eq 'A') {
   $text->configure( -font => $afont );
   $astr =~ s/\r//g;  # Remove DOS newlines +++ wrong for Apple
   $text->insert('end', $astr);
   } elsif ($mode eq 'F') {
   $text->configure( -font => $hfont );
   $astr =~ s/\r//g;
   $text->insert('end', $astr);
   } else {
   $text->configure( -font => $hfont );
   for (my $ix=0; $ix < length($str); $ix+=8) {
      local $_;
      $hex = substr($str,$ix,8);
      my $l = sprintf ("%6x: ",$ix);
      for (my $ib=0; $ib<8; $ib++) {
     $l .= ($ib >= length($hex)) ? "   " :
        sprintf("%02x ",ord(substr($hex,$ib)));
      }
      $_ = $hex;
      tr/\n\r\t\000/./;
      $text->insert('end', $l." |".$_."|\n");
   }
   }
   $text->update;
}

sub search_adj {
   my $mw = shift;
   my $a;
   if ($case) {
   $a = index $astr, $ftext, $search_pt;
   if ($a < 0) {$a = index $astr, $ftext;}
   } else {
   $a = index lc($astr), lc($ftext), $search_pt;
   if ($a < 0) {$a = index lc($astr), lc($ftext);}
   }
   if ($a < 0) {$mw->bell; } 
   else {
   # highlight the search term
   $text->tagDelete(STAG);
   $search_len = length($ftext);
   my $e = $a + $search_len;
   $text->tagAdd(STAG, "1.0 + $a chars", "1.0 + $e chars");
   $text->tagConfigure(STAG, -background => "pink" );
   $text->see( "1.0 + $a chars" );
   $search_pt = $a+1;
   }
}

sub find_text {
   my @pl = (-side=>'top', -anchor=>'w');
   my $tl = shift;
   $search_pt = 0;
   $ftext = '';
   my $db = $tl->Toplevel;
   my $f1=$db->Frame;
   $f1->Label(-text=>"Text: ")->pack(@pl);
   my $e = $f1->Entry(-textvariable=>\$ftext, -width=>40, 
        -background=>"white" )->pack;
   $f1->Checkbutton(-text=>"Match case", -variable=>\$case)->pack;
   my $f2=$db->Frame;
   $f2->Button( -text => "Find", -width =>9,
         -command => [ \&search_adj, $db ] )
   ->pack(-side=>"left", -fill=>"x");
   $f2->Button( -text => "Done", -width =>9,
         -command =>sub { $db->destroy; } )
   ->pack(-side=>"left", -fill=>"x");
   $f1->pack(-side=>"top", -expand=>1);
   $f2->pack(-side=>"bottom", -expand=>1);
   $db->raise;              # make viewable
   $e->focus;
   $tl->bind("Tk::Entry", '<Return>', [ \&search_adj, $db ] );
   $db->bind('<Escape>', sub { $db->destroy; } );
   $db->tkwait('window',$db);   # wait for window event
}

sub view_text {
   my $mw = shift;
   my $filename = shift;
   require Tk::ROText;
   $mode = 'A';

   my $tl = $mw->Toplevel(-title => $filename);
   my $menubar = $tl->Menu(-type => 'menubar');
   $tl->configure(-menu => $menubar);
   my $file_menu = $menubar->cascade(-label => '~File', -tearoff => 0);
   $file_menu->command(-label => 'TEXT', 
       -command => sub {$mode='A'; view_text_mode;} );
   $file_menu->command(-label => 'FIXED', 
       -command => sub {$mode='F'; view_text_mode;} );
   $file_menu->command(-label => 'HEX', 
       -command => sub {$mode='H'; view_text_mode;} );
   $file_menu->command(-label => 'close', 
       -command => sub { $tl->destroy; } );
   my $search_menu = $menubar->cascade(-label => '~Search', -tearoff => 0 );
   $search_menu->command(-label => 'Find',
                 -command => sub { 
                        find_text($tl); } );

   $text = $tl->Scrolled('ROText',
   -background => 'white',
      -scrollbars => 'e',
      -wrap      => 'word',
      -width     => 80,
      -height    => 30,
      -font      => $afont,
      -setgrid   => 1,
   )->pack(-expand => 1, -fill => 'both');

   $text->tagConfigure('title',
      -font => '-*-Helvetica-Bold-R-Normal--*-180-*-*-*-*-*-*',
   );

   $str = '';
   open (TFILE, $filename) &&
      binmode(TFILE) &&
    read (TFILE, $str, MAXTEXT) &&
      close TFILE;

   if (! $str) {
   $str = "UNABLE TO OPEN FILE $filename.\n";
   }
   $search_pt = 0;
   # Fast key bindings
   $tl->bind("Tk::Toplevel", '<Control-f>', [ \&find_text, $tl ] );
   $tl->bind('<Escape>', sub { $tl->destroy; } );
   view_text_mode;
}
} # end of lexical scope block

####################### Pixmaps ##########################

# Read the config file
read_config;
   
$Mainwin = MainWindow->new( -title => 'PerlCommander' );

# Executable file marker
$EXEIMG = $Mainwin->Pixmap(-data => <<'EOF');
/* XPM */
static char * exe_xpm[] = {
"12 12 3 1",
"   c None",
".   c #FF6060",
"+   c #8F6060",
"  .    .   ",
" .+.   .+.  ",
".+++. .+++. ",
"+.+++.+++.+ ",
" +.+++++.+  ",
"  +.+++.+   ",
"  .+++++.   ",
" .+++.+++.  ",
".+++.+.+++. ",
"+.+.+ +.+.+ ",
" +.+   +.+  ",
"  +    +   "};
EOF

# Browser file marker
$NSIMG = $Mainwin->Pixmap(-data => <<'EOF');
/* XPM */
static char * ns_xpm[] = {
"12 12 7 1",
"   c None",
".   c #000000",
"b   c #001410",
"C   c #F7F7F7",
"D   c #002428",
"$   c #004D51",
"%   c #6196A6",
"............",
".....bbbb...",
"bbCCbbbbCCbb",
"bbbCCbbbCbbb",
"DDDCDCDDCDDD",
"DD$C$$C$C$DD",
"$$$C$$$CC$$$",
"$$$C$$$$C$$$",
"$$%C%%%%C%$$",
"$%CC......%$",
"%..........%",
"............"};
EOF

# Acrobat file marker
$PDFIMG = $Mainwin->Pixmap(-data => <<'EOF');
/* XPM */
static char * pdf_xpm[] = {
"12 12 4 1",
"   c None",
".   c #FF0000",
"+   c #000000",
"@   c #890000",
"......+.....",
".....@+@....",
".....+++....",
"....@+++@...",
"....+++++...",
"...@++@++@..",
"...+++.+++..",
"..@++@.@++@.",
"..+++...+++.",
".@++@@@.@++@",
".++++++..+++",
"+++++++@.@++"};
EOF

# Up a level
$UPIMG = $Mainwin->Pixmap(-data => <<'EOF');
/* XPM */
static char * up_xpm[] = {
"12 12 3 1",
"   c None",
".   c #505050",
"+   c #000000",
"    .     ",
"   .+.    ",
"   .+++.   ",
"  .+++++.   ",
" .+++++++.  ",
".+++++++++. ",
"   .+.    ",
"   .+.    ",
"   .+.    ",
"   .+.    ",
"   .+.    ",
"   .+.    "};
EOF

# Home
$HOMEIMG = $Mainwin->Pixmap(-data => <<'EOF');
/* XPM */
static char * home_xpm[] = {
"12 12 3 1",
"   c None",
".   c #505050",
"+   c #000000",
"    .     ",
"   .+.    ",
"   .+++.   ",
"  .+++++.   ",
" .+++++++.  ",
".+++++++++. ",
".+.    .+. ",
".+.    .+. ",
".+.    .+. ",
".+.    .+. ",
".+.    .+. ",
".+++++++++. "};
EOF

# Root
$ROOTIMG = $Mainwin->Pixmap(-data => <<'EOF');
/* XPM */
static char * root_xpm[] = {
"12 12 3 1",
"   c None",
".   c #505050",
"+   c #000000",
"       ...",
"      .++.",
"      .++. ",
"     .++   ",
"    .++.   ",
"   .++.   ",
"   .++.    ",
"  .++.     ",
" .++.      ",
".++.      ",
"...       ",
"         "};
EOF

# Image image
$IMG = $Mainwin->Pixmap(-data => <<'EOF');
/* XPM */
static char * rgb_xpm[] = {
"12 12 4 1",
"   c None",
".   c #0000FF",
"+   c #00E000",
"@   c #FF0000",
"............",
"............",
"............",
"............",
"++++++++++++",
"++++++++++++",
"++++++++++++",
"++++++++++++",
"@@@@@@@@@@@@",
"@@@@@@@@@@@@",
"@@@@@@@@@@@@",
"@@@@@@@@@@@@"};
EOF

# Spreadsheet image
$SPDIMG = $Mainwin->Pixmap(-data => <<'EOF');
/* XPM */
static char * spd_xpm[] = {
"12 12 3 1",
"   c None",
".   c #000000",
"+   c #FFFFFF",
"............",
".+++++.++++.",
".+++++.++++.",
".+++++.++++.",
".+++++.++++.",
".+++++.++++.",
"............",
".+++++.++++.",
".+++++.++++.",
".+++++.++++.",
".+++++.++++.",
"............"};
EOF

# Java class image
$JAVIMG = $Mainwin->Pixmap(-data => <<'EOF');
/* XPM */
static char * jav_xpm[] = {
"12 12 3 1",
"   c None",
".   c #000000",
"+   c #0000FF",
"  ++++++++++",
"  ++++++++++",
"     +++   ",
"     +++   ",
"     +++   ",
"     +++   ",
"     +++   ",
"     +++   ",
"+++   +++   ",
"+++  +++   ",
" ++++++    ",
"  +++      "};
EOF

# Text file
$TXTIMG = $Mainwin->Pixmap(-data => <<'EOF');
/* XPM */
static char * text_xpm[] = {
"12 12 6 1",
"   c None",
".   c #FFFFFF",
"+   c #000000",
"@   c #8F8080",
"#   c #BFBFBF",
"$   c #7F7F7F",
".+++++++++++",
".+.........+",
".+.@@@@@@..+",
".+.@@@@@@..+",
".+...@@....+",
".+...@@...#+",
"#+...@@...$$",
"$$...@@...+#",
"+#...@@...+.",
"+.........+.",
"+.........+.",
"+++++++++++."};
EOF


   unless (defined $folderImage) {
   require Tk::Pixmap;
   $folderImage = $Mainwin->Pixmap(-file => Tk->findINC('folder.xpm'));
   }
   unless (defined $fileImage) {
   require Tk::Pixmap;
   $fileImage   = $Mainwin->Pixmap(-file => Tk->findINC('file.xpm'));
   }

$FILEIMG = $Mainwin->Pixmap(-file => Tk->findINC('file.xpm'));
$FOLDIMG = $Mainwin->Pixmap(-file => Tk->findINC('folder.xpm'));

###################### Draw the Application ########################

# Top Menu frame
$menubar = $Mainwin->Menu(-type => 'menubar')->pack(-fill=>'x', -side=>'top');

$file_menu = $menubar->cascade(-label => '~File', -tearoff => 0);
  $file_menu->command(-label => 'chmod',   -command => [\&start_cmd, 'chmod']);
  $file_menu->command(-label => 'pack',   -command => [\&start_cmd, 'pack']);
  $file_menu->command(-label => 'unpack',  -command => [\&start_cmd, 'unpack']);
  $file_menu->separator;
  $file_menu->command(-label => 'info',   -command => [\&start_cmd, 'finfo']);
  $file_menu->command(-label => 'print',   -command => [\&start_cmd, 'print']);
  $file_menu->command(-label => 'test',   -command => [\&get_size]);
  $file_menu->separator;
  $file_menu->command(-label => 'quit - no save', -command => [\&tkc_exit, 1 ]);
  $file_menu->command(-label => 'quit',   -command => [\&tkc_exit, '' ]);

$cmd_menu = $menubar->cascade(-label => '~Commands', -tearoff => 0);
  $cmd_menu->command(-label => 'System Info',  -command => [\&sysinfo_dialog ]);
  $cmd_menu->command(-label => 'Shell',   -command => [\&start_cmd, 'Shell' ]);
  $cmd_menu->command(-label => 'Refresh',  -command => [\&refresh_dirs ]);

$start_menu = $menubar->cascade(-label => '~Config', -tearoff => 0);
  $start_menu->command(-label => 'display',  -command => [\&config_dpy ]);
  $start_menu->command(-label => 'apps',  -command => [\&config_apps ]);
  $start_menu->command(-label => 'filepats',  -command => [\&config_filepats ]);

$help_menu = $menubar->cascade(-label => '~Help', -tearoff => 1);
 # $help_menu->command(-label => 'Pod', -command => [\&help_menu, 'pod']);
  $help_menu->command(-label => 'About',  -command => [\&help_menu, 'about']);


# Toolbar - icons for freqently used commands.  If implemented,
# these will use row 1 and move file boxes and buttons down
# NOT YET IMPLEMENTED

# Buttons
@ent = qw/-padx 1 -pady 1  -fill none -side left /;
my $lcmd = $Mainwin->Frame;
foreach my $b ( 'view', 'edit', 'mkdir', 'copy', 'move', 'rename', 'link', 'del' ) {
   $lcmd->Button( -text => $b, -width=>5, -command => [\&start_cmd, $b] )->pack(@ent);
}
$lcmd->Button( -text => 'quit', -width=>5, -command => [\&tkc_exit, '' ] )->pack(@ent);
$lcmd->pack(-fill=>'x', -side=>'bottom', -anchor=>'s');

# Two HList directory boxes in two frames

$f_L = $Mainwin->Frame;
$f2_L = $f_L->Frame->pack(-side => 'top', -padx => 4, -fill=>'x', -expand =>0 );
$dir_L = $f2_L->Label(-text => $config{Path_L}, -relief => 'sunken' )
   ->pack(-side => 'left', -padx => 4, -fill=>'x', -expand =>1 );
$f2_L->Button( -image=>$UPIMG,  -command => [\&up_L ] )
   ->pack(-side => 'right', -fill=>'none', -expand =>0 );
$f2_L->Button( -image=>$HOMEIMG,  -command => sub {
   my $sel = $ENV{ HOME };
   $dir_L->configure( -text => $sel );
   show_dir( $sel, $box_L); } )
   ->pack(-side => 'right', -fill=>'none', -expand =>0 );
$f2_L->Button( -image=>$ROOTIMG,  -command => sub {
   my $sel = ROOTDIR;
   $dir_L->configure( -text => $sel );
   show_dir( $sel, $box_L); } )
   ->pack(-side => 'right', -fill=>'none', -expand =>0 );
$box_L = $f_L->Scrolled( HList, -separator => '*', -selectmode => "extended",
       -background => "white", -width => $config{Box_width},
   -height => $config{Box_height},
       -indent => 10, -scrollbars => "e", -itemtype => "imagetext" )
       ->pack(-fill=>'both', -side=>'bottom', -expand=>1 );
$f_L->pack(-fill=>'both', -side=>'left', -expand=>1 );

$f_R = $Mainwin->Frame;
$f2_R = $f_R->Frame->pack(-side => 'top', -padx => 4, -fill=>'x', -expand =>0 );
$dir_R = $f2_R->Label(-text => $config{Path_R}, -relief => 'sunken' )
   ->pack(-side => 'left', -padx => 4, -fill => 'x', -expand =>1 );
$f2_R->Button( -image=>$UPIMG,  -command => [\&up_R ] )
   ->pack(-side => 'right', -fill=>'none', -expand =>0 );
$f2_R->Button( -image=>$HOMEIMG,  -command => sub {
   my $sel = $ENV{ HOME };
   $dir_R->configure( -text => $sel );
   show_dir( $sel, $box_R); } )
   ->pack(-side => 'right', -fill=>'none', -expand =>0 );
$f2_R->Button( -image=>$ROOTIMG,  -command => sub {
   my $sel = ROOTDIR;
   $dir_R->configure( -text => $sel );
   show_dir( $sel, $box_R); } )
   ->pack(-side => 'right', -fill=>'none', -expand =>0 );
$box_R = $f_R->Scrolled( HList, -separator => '*', -selectmode => "extended",
   -background => "white", -width => $config{Box_width}, 
       -height => $config{Box_height},
       -indent => 10, -scrollbars => "e", -itemtype => "imagetext" )
      ->pack(-fill=>'both', -side=>'bottom', -expand=>1 );
$f_R->pack(-fill=>'both', -side=>'right', -expand=>1);

# On press and release, turn off selection in other box
# On double click, call accept
$box_L->configure( -command => [\&accept_L ], 
     -browsecmd => sub { $box_R->selectionClear; $box_R->anchorClear; $cur_box = \$box_L; }  );
$box_R->configure( -command => [\&accept_R ],
     -browsecmd => sub { $box_L->selectionClear; $box_L->anchorClear; $cur_box = \$box_R; }  );

$cur_box = \$box_R; 
show_dir ( $config{Path_L}, $box_L );
show_dir ( $config{Path_R}, $box_R );

################################ Now just do it ##########################

MainLoop;
