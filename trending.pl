#!/usr/bin/perl -wT

######
# Copyright (c) 2015-2019 Stefan Jakobs
#
# This file is part of coach-manager.
#
# coach-manager is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# coach-manager is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with coach-manager.  If not, see <http://www.gnu.org/licenses/>.
#
#####################################################################
# This was written by:
#       Stefan Jakobs <projects@localside.net>
#
# Please send all comments, suggestion, bug reports, etc
#       to projects@localside.net
#
#####################################################################

use strict;
no warnings 'deprecated';
use DBI;
use CGI;
use lib '.';
use functions;

## global variables
my $error;
my $object;
my @course_ids;
my %course_list;
my %active_course_list;
my %courses_checked;
my $cgi = CGI->new;

my %config = read_config();

# Connect to the database.
my $dbh = init_db(\%config);

## Subroutines

sub print_formular($) {
   my $get = shift;
   print <<"EOF"; 
   <h3> Trending </h3>
   <div id="control">
      <form action="$config{'S_TRENDING'}" name="trending" method="post" class="input_form">
EOF

   foreach (sort {$course_list{$a} cmp $course_list{$b}} keys %course_list) {
      if ($get eq 'get') {
         if (defined($active_course_list{$_})) {
            $courses_checked{$_}='checked';
         }
      }
      if (defined($courses_checked{$_})) {
         print "         <input type=\"checkbox\" name=\"course_id\" value=\"$_\" $courses_checked{$_} > $course_list{$_} </br>\n";
      } else {
         print "         <input type=\"checkbox\" name=\"course_id\" value=\"$_\" > $course_list{$_} </br>\n";
      }
   }

   print <<"EOF";
         <input class="button" type="submit" name="submit" value="Grafik neu aufbauen">
      </form>
   </div>
   <div id="image">
EOF

   if ($config{'debug'}) {
      $object = '<object width="800px" height="400px" data=';
   } else {
      $object = '<img src=';
   }
   if (@course_ids) {
      print "       ${object}\"generate_image.pl?course_id=" . join('&course_id=', @course_ids) ."\" />";
   } else {
      print "       ${object}\"generate_image.pl\" />\n";
   }
   print <<"EOF";
   </div>
EOF
}


sub untaint_input() {
   ## untaint input
   if ( defined($cgi->param('course_id')) and $cgi->param('course_id') =~ /^(?:[0-9]+|all)$/i ) {
      push(@course_ids, $cgi->param('course_id'));
      foreach ($cgi->param('course_id')) {
         $courses_checked{$_}='checked';
      }
   } elsif ( defined($cgi->param('course_id')) ) {
      $error .= "Kurs-ID darf nur aus Zahlen bestehen!<br>";
   } else {
      $error .= "Bitte eine Auswahl treffen!<br>";
   }
}

## MAIN ##

## Get all course names
%course_list = get_course_list($dbh, $config{'T_COURSE'});

## Get all active course names
%active_course_list = get_active_course_list($dbh, $config{'T_COURSE'});


# Read in text
if (defined($ENV{'REQUEST_METHOD'}) and uc($ENV{'REQUEST_METHOD'}) eq "POST") {
   untaint_input();

   print_start_html($cgi, "Trending");
   print_link_list($config{'S_TRENDING'});

   print_formular('post');
   if (defined($error)) {
      print "<p class=\"error\">$error</p>";
   }
} else {
   $cgi->header('multipart/form-data');
   print_start_html($cgi, 'Trending');
   print_link_list($config{'S_TRENDING'});
   print_formular('get');
}
print_end_html($cgi);

