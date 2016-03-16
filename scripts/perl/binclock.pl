#!/usr/bin/perl -w

use strict;
use warnings;
use Time::localtime;
use Tk; 


###############################################################################
# variables
###############################################################################
my $hours; 
my $minutes; 
my $seconds;
my @columns; 
my @label;
my $mw = MainWindow->new();
my $counter;


###############################################################################
# logic
###############################################################################
sub showInfo {
    my $text = "BinaryClock\n"
             . "----------------------------------------\n\n" 
             . "Uitleg:\n"
             . "De kolommen staan voor HH MM SS\n"
             . "De waardes van de blokken zijn binair, dus 1, 2, 4 en 8\n\n"
             . "|8|8| |8|8| |8|8|\n"
             . "|4|4| |4|4| |4|4|\n"
             . "|2|2| |2|2| |2|2|\n"
             . "|1|1| |1|1| |1|1|\n\n"
             . "Voorbeeld:\n\n"
             . "|0|\n"
             . "|X| -> 4\n"
             . "|0|\n"
             . "|X| -> 1\n\n"
             . "Opgeteld levert dit '5', dus de betreffende kolom staat\n"
             . "voor deze waarde. Bereken zo alle kolommen om tot het\n"
             . "resultaat te komen.\n" ;
    $mw->messageBox(-font=>"Ansi 8", -type=>'OK', -title=>'Info...', -message=>$text );
}


sub getTime {
   $hours = localtime->hour;
   $hours = ($hours - 12) unless $hours <= 12;
   $minutes = localtime->min;
   $seconds = localtime->sec;
}

sub eenheden {
   return ($_[0] % 10);
}

sub tientallen {
   return ($_[0] / 10);
}

sub firstDraw {
   getTime;
   for (my $regel=0; $regel<4; $regel++) {
      my $color;
      for (my $kolom=0; $kolom<8; $kolom++) {

         if ($kolom==0) { $color = (tientallen($hours) & (1<<(3-$regel)) ? 'green' : 'black'); }
         if ($kolom==1) { $color = (eenheden($hours) & (1<<(3-$regel)) ? 'green' : 'black'); }

         if ($kolom==3) { $color = (tientallen($minutes) & (1<<(3-$regel)) ? 'green' : 'black'); }
         if ($kolom==4) { $color = (eenheden($minutes) & (1<<(3-$regel)) ? 'green' : 'black'); }

         if ($kolom==6) { $color = (tientallen($seconds) & (1<<(3-$regel)) ? 'green' : 'black'); }
         if ($kolom==7) { $color = (eenheden($seconds) & (1<<(3-$regel)) ? 'green' : 'black'); }

         if ($kolom==2 || $kolom==5) {
            $label[$regel][$kolom] = $columns[$kolom]->Label(-height=>1, -width=>1)->pack();
         }
    else {
            $label[$regel][$kolom] = $columns[$kolom]->Label(-background=>$color, -height=>1, -width=>3, -relief=>'groove')->pack();
         }
      }
   }
}

sub reDraw {
   getTime;
   for (my $regel=0; $regel<4; $regel++) {
      my $color;
      for (my $kolom=0; $kolom<8; $kolom++) {
         if ($kolom==0) { $color = (tientallen($hours) & (1<<(3-$regel)) ? 'green' : 'black'); }
         if ($kolom==1) { $color = (eenheden($hours) & (1<<(3-$regel)) ? 'green' : 'black'); }
         if ($kolom==3) { $color = (tientallen($minutes) & (1<<(3-$regel)) ? 'green' : 'black'); }
         if ($kolom==4) { $color = (eenheden($minutes) & (1<<(3-$regel)) ? 'green' : 'black'); }
         if ($kolom==6) { $color = (tientallen($seconds) & (1<<(3-$regel)) ? 'green' : 'black'); }
         if ($kolom==7) { $color = (eenheden($seconds) & (1<<(3-$regel)) ? 'green' : 'black'); }
         if ($kolom==2 || $kolom==5) {}
    else {
       $label[$regel][$kolom]->configure(-background=>$color);
   }
      }
   }
   $mw->after(1000, \&reDraw);
}



###############################################################################
# main
###############################################################################
$mw->optionAdd('*BorderWidth'=>1);
$mw->title("Binary Clock");
$mw->resizable(0,0);

my $topFrame = $mw->Frame(-relief=>'flat')->pack(-side=>'top', -fill=>'x');
my $btnFrame = $mw->Frame()->pack(-side=>'bottom', -fill=>'x');

for (my $i=0; $i<8; $i++) {
   $columns[$i] = $topFrame->Frame()->pack(-side=>'left');
}

# my $footerLabel = $btnFrame->Label(-text=>"Copyright (C) Royke")->pack(-side=>'left');
#start with right most button here!
#my $quitButton = $btnFrame->Button(-text=>"Quit", -command=>\&exit)->pack(-side=>'right');
#my $infoButton = $btnFrame->Button(-text=>"Help", -command=>\&showInfo)->pack(-side=>'right');



firstDraw;
reDraw;

MainLoop;

