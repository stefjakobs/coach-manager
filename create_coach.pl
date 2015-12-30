#!/usr/bin/perl -wT

######
# Copyright (c) 2013-2016 Stefan Jakobs
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

my $error;
my $sth;
my ($first_name, $last_name, $birthday, $email, $telephone, $license, $mode, $id) = ( '', '', '', '', '', '', '', '');
my ($active) = (1);
my $cgi = CGI->new;
my @checked = ("", "checked");

my %config = read_config();

## Gleiches Formular wie in edit_coach.pl, aber ohne ID Feld
sub print_formular() {
   print <<"EOF"; 
   <h3> Trainer anlegen </h3>
   <p>F&uuml;lle das Formular aus und lege dann den Trainer durch klicken des Buttons an:</p>
   <div id="edit-form">
   <form action="$config{'S_CREATE_COACH'}" name="add_coach" method="post">
   <table>
      <tr>
         <td class="create_td">Vorname:</td>
         <td class="create_td"><input class="input_form" type="text" name="first_name" value="$first_name"></td>
      </tr><tr>
         <td class="create_td">Nachname:</td>
         <td class="create_td"><input class="input_form" type="text" name="last_name" value="$last_name"></td>
      </tr><tr>
         <td class="create_td">Geburtsdatum:</td>
         <td class="create_td"><input class="input_form" type="text" name="birthday" value="$birthday"></td>
      </tr><tr>
         <td class="create_td">E-Mailadresse:</td>
         <td class="create_td"><input class="input_form" type="text" name="email" value="$email"></td>
      </tr><tr>
         <td class="create_td">Telefonnummer:</td>
         <td class="create_td"><input class="input_form" type="text" name="telephone" value="$telephone"></td>
      </tr><tr>
         <td class="create_td">Trainer Lizenz:</td>
         <td class="create_td"><input class="input_form" type="text" name="license" value="$license"></td>
      </tr><tr>
         <td class="create_td">Aktiv:</td>
         <td class="create_td"><input class="input_form" type="checkbox" name="active" $checked[$active]></td>
      </tr><tr>
         <td class="create_td"></td>
         <td class="create_td"><input class="button" type="submit" name="submit" value="Trainer anlegen"></td>
      </tr>
   </table>
   </form>
   </div>
EOF
}

sub untaint_input() {
   ## untaint input
   if ( defined($cgi->param('first_name')) and $cgi->param('first_name') =~ /^[\wßäüö]+$/i ) {
      $first_name = $cgi->param('first_name');
   } else {
      $error .= "Vorname darf nur aus Buchstaben bestehen!<br>";
   }
   if ( defined($cgi->param('last_name')) and $cgi->param('last_name') =~ /^[\wßäüö]+$/i ) {
      $last_name = $cgi->param('last_name');
   } else {
      $error .= "Nachname darf nur aus Buchstaben bestehen!<br>";
   }
   if ( defined($cgi->param('birthday')) and $cgi->param('birthday') =~ /^\d{4}-\d{2}-\d{2}$/ ) {
      $birthday = $cgi->param('birthday');
   } else {
      $error .= "Geburtstag muss das Format JJJJ-MM-DD haben!<br>";
   }
   if ( defined($cgi->param('email')) and $cgi->param('email') =~ /^[.\w!#$%&'*+\/=?^_`{|}~-]+@[-_.\w]+\.[a-zA-Z]{2,3}$|^$/ ) {
      $email = $cgi->param('email');
   } else {
      $error .= 'E-Mail muss das Format name@doman.tld haben!<br>';
   }
   if ( defined($cgi->param('telephone')) and $cgi->param('telephone') =~ /[\d +-\/]{5,15}$|^$/ ) {
      $telephone = $cgi->param('telephone');
   } else {
      $error .= 'Telefonnummer darf nur aus Zahlen, +,-,/ bestehen!<br>';
   }
   if ( defined($cgi->param('license')) and $cgi->param('license') =~ /^[ABCD]$|^$/i ) {
      $license = uc($cgi->param('license')); 
   } else {
      $error .= "Lizenz muss A,B,C oder D sein!<br>";
   }
   if ( defined($cgi->param('active')) ) {
      $active = 1;
   } else {
      $active = 0;
   }
}

# Connect to the database.
my $dbh = init_db(\%config);


# Read in text
if (defined($ENV{'REQUEST_METHOD'}) and uc($ENV{'REQUEST_METHOD'}) eq "POST") {
   print_start_html($cgi, 'Trainer angelegt');
   print_link_list($config{'S_CREATE_COACH'});
   untaint_input();

   if (! defined($error)) {
      eval { $dbh->do("INSERT INTO $config{'T_COACH'} ( lastname, firstname, birthday, email, telephone, license, active )
                       VALUES (\"$last_name\", \"$first_name\", \"$birthday\", \"$email\", \"$telephone\", \"$license\", \"$active\")" ) };
      $error .= "Insert failed: $@\n" if $@;
   }

   print_formular();
   if (defined($error)) {
      print "<p class=\"error\">$error</p>";
   } else {
      print "<p class=\"notice\">Trainer $first_name $last_name wurde angelegt.</p>";
   }
} else {
   #$cgi->header('multipart/form-data');
   print_start_html($cgi, 'Trainer anlegen');
   print_link_list($config{'S_CREATE_COACH'});
   print_formular();
}
print_end_html($cgi);

1;
