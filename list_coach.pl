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
use utf8;
use lib '.';
use functions;

my %coaches;
my ($error, $success);
my %config = read_config();

# Kann die Liste aus config.cf nicht nehmen, da sie falsch sortiert ist
my @coach_keys = ('id', 'firstname', 'lastname', 'license', 'birthday', 'email', 'telephone', 'active');

sub list_coaches() {
   my %item_list = %{$config{'V_COACH_ITEMS'}};
   print_link_list($config{'S_LIST_COACH'});
   print <<"EOF"; 
   <h3>&Uuml;bersicht der angelegten Trainer</h3>
   <form action="$config{'S_LIST_COACH'}" name="list_coach" method="post">
   <table border=1>
      <tr>
EOF
   foreach (@coach_keys) {
      print "      <th>$item_list{$_}</th>" ."\n";
   }
   print "      <th>l&ouml;schen</th>\n";
   print "      <th>bearbeiten</th>\n";
   print "   </tr>\n";
   foreach my $id (sort{$coaches{$a}{'firstname'} cmp $coaches{$b}{'firstname'}} keys %coaches) {
      print "   <tr>\n";
      foreach my $item (@coach_keys) {
         print "      <td class=\"td_content\">$coaches{$id}{$item}</td>" ."\n";
      }
      print "      <td><input class=\"button\" type=\"submit\" name=\"delete:$id\" value=\"l&ouml;schen\"></td>\n";;
      print "      <td><a href=$config{S_EDIT_COACH}?id=$id>bearbeiten</a></td>\n";
      print "   </tr>\n";
   }
   print "</table>\n";
   print <<"EOF"; 
   <p class="attention">
   ACHTUNG: Das L&ouml;schen eines Trainers l&ouml;scht gleichzeitig dessen Abrechnungsdaten! </p>
   <input class="input_form_simple" type="checkbox" name="confirmed">
      <p>Ich bin mir sicher, dass ich den ausgew&auml;hlten Trainer l&ouml;schen m&ouml;chte.</p>
   </form>
EOF
}


# Connect to the database.
my $dbh = init_db(\%config);
my $cgi = CGI->new;

#$ENV{'REQUEST_METHOD'} =~ tr/a-z/A-Z/;
if (defined($ENV{'REQUEST_METHOD'}) and $ENV{'REQUEST_METHOD'} eq "POST") {
   print_start_html($cgi, 'Trainer anzeigen');
   %coaches = get_table_list($dbh, $config{T_COACH});
   list_coaches();
   
   foreach my $id (keys %coaches) {
      if ( defined($cgi->param('confirmed')) and defined($cgi->param("delete:$id")) ) {
         eval { $dbh->do("DELETE FROM $config{'T_COACH'} WHERE id = " . $id ) };
         if ($@) {
            $error .= "Failed to delete coach $id:<br>\n $@ \n";
         } else {
            $success .= "Trainer $id erfolgreich entfernt.";
         }
      } elsif ( defined($cgi->param("delete:$id")) ) {
         print "<p class=\"notice\"> Nichts gel&ouml;scht: Vergessen zu best&auml;tigen?</p>";
      }
   }
   if ($error) { print "<p class=\"error\">$error</p>\n"; }
   if ($success) { print "<p class=\"notice\">$success</p>\n"; }
} else {
   print_start_html($cgi, 'Trainer anzeigen');
   %coaches = get_table_list($dbh, $config{T_COACH});
   list_coaches();
}
print_end_html($cgi);

1;
