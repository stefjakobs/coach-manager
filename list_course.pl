#!/usr/bin/perl -wT

######
# Copyright (c) 2013-2015 Stefan Jakobs
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

my %courses;
my ($error, $success);
my %config = read_config();

# Kann die Item-List aus config.cf nicht nutzen, da die richtige Sortierung nötig ist
my @course_keys = ( 'id', 'name', 'startdate', 'enddate', 'starttime', 'endtime' );

sub list_courses() {
   my %item_list = %{$config{'V_COURSE_ITEMS'}};
   print_link_list($config{'S_LIST_COURSE'});
   print <<"EOF"; 
   <h3>&Uuml;bersicht der angelegten Kurse</h3>
   <form action="$config{'S_LIST_COURSE'}" name="list_course" method="post">
   <table border=1>
   <tr>
EOF
   foreach (@course_keys) { 
      print "      <th>$item_list{$_}</th>" ."\n";
   }
   print "      <th>l&ouml;schen</th>\n";
   print "      <th>bearbeiten</th>\n";
   print "   </tr>\n";
   foreach my $id (sort {$a cmp $b} keys %courses) {
      print "   <tr>\n";
      foreach my $item (@course_keys) {
         print "      <td class=\"td_content\">$courses{$id}{$item}</td>" ."\n";
      }
      print "      <td><input class=\"button\" type=\"submit\" name=\"submit:$id\" value=\"l&ouml;schen\"></td>\n";
      print "      <td><a href=$config{'S_EDIT_COURSE'}?id=$id>bearbeiten</a></td>\n";
      print "   </tr>\n";
   }
   print "</table>\n";
   
   print <<"EOF"; 
   <p class="attention">
   ACHTUNG: Das L&ouml;schen eines Kurses l&ouml;scht gleichzeitig alle
      dazugeh&ouml;rigen Trainingstage!! </p>
   <input class="input_form_simple" type="checkbox" name="confirmed">
   <p>Ich bin mir sicher, dass ich den ausgew&auml;hlten Kurs l&ouml;schen m&ouml;chte.</p>
   </form>
EOF
}


# Connect to the database.
my $dbh = init_db(\%config);
my $cgi = CGI->new;

if (defined($ENV{'REQUEST_METHOD'}) and uc($ENV{'REQUEST_METHOD'}) eq "POST") {
   print_start_html($cgi, 'Kurse anzeigen');
   %courses = get_table_list($dbh, $config{T_COURSE});
   list_courses();
   foreach my $id (keys %courses) {
      if ( defined($cgi->param('confirmed')) and defined($cgi->param("submit:$id")) ) {
         eval { $dbh->do("DELETE FROM $config{'T_COURSE'} WHERE id = " . $id ) };
         if ($@) {
            $error .= "Failed to delete course $id:<br>\n $@ \n";
         } else {
            $success .= "Kurs $id erfolgreich entfernt.";
         }
      } elsif ( defined($cgi->param("submit:$id")) ) {
         print "<p class=\"notice\"> Nichts gel&ouml;scht: Vergessen zu best&auml;tigen?</p>";
      }
   }
   if ($error) { print "<p class=\"error\">$error</p>\n"; }
   if ($success) { print "<p class=\"notice\">$success</p>\n"; }
} else {
   print_start_html($cgi, 'Kurse anzeigen');
   %courses = get_table_list($dbh, $config{T_COURSE});
   list_courses();
}
print_end_html($cgi);

1;
