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


my $error;
my $sth;
my ($first_name, $last_name, $birthday, $email, $telephone, $license, $active, $id);
my $cgi = CGI->new;
my %config = read_config();
my @checked = ("", "checked");


## gleiches Formular wie in create_coach.pl, aber mit ID Feld
sub print_formular() {
   print <<"EOF"; 
   <body>
   <h3> Trainer bearbeiten </h3>
   <p>F&uuml;lle das Formular aus und klicke auf best&auml;tige mit dem Button</p>
   <div id="edit-form">
   <form action="$config{'S_EDIT_COACH'}" name="edit_coach" method="post">
   <table>
      <input type="hidden" name="id" value="$id"></td>
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
         <td class="create_td"><input class="button" type="submit" name="submit" value="&Auml;nderungen &uuml;bernehmen"></td>
      </tr>
   </table>
   </form>
   </div>
   </body>
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
   if ( defined($cgi->param('email')) and $cgi->param('email') =~ /^[.\w!#$%&'*+\/=?^_\`{|}~-]+@[-_.\w]+\.[a-zA-Z]{2,3}$|^$/ ) {
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
   $id = $cgi->param('id');
}

# Connect to the database.
my $dbh = init_db(\%config);


# Read in text
if (defined($ENV{'REQUEST_METHOD'}) and uc($ENV{'REQUEST_METHOD'}) eq "POST") {
   print_start_html($cgi, 'Trainer bearbeitet');
   print_link_list($config{'S_LIST_COACH'});
   untaint_input();

   if (! defined($error)) {
      eval { $dbh->do("UPDATE $config{'T_COACH'} SET lastname=\"$last_name\", firstname=\"$first_name\",
		                 birthday=\"$birthday\", email=\"$email\", telephone=\"$telephone\",
						     license=\"$license\", active=\"$active\" WHERE id = $id " ) };
      $error .= "Alter failed: $@\n UPDATE $config{'T_COACH'} SET lastname=\"$last_name\", firstname=\"$first_name\", birthday=\"$birthday\", email=\"$email\", telephone=\"$telephone\", license=\"$license\", active=\"$active\" WHERE id = $id " if $@;
   }

   print_formular();
   if (defined($error)) {
      print "<p class=\"error\">$error</p>";
   } else {
      print "<p class=\"notice\">Trainer $first_name $last_name wurde ge&auml;ndert.</p>";
   }
} else {
   if (defined($cgi->param('id')) and $cgi->param =~ /^\d+$/) {
      $sth = $dbh->prepare("SELECT * FROM $config{'T_COACH'} WHERE id = " . $cgi->param('id'));
      if (!$sth) { 
         $error .= "select failed: " . $dbh->errstr . "\n";
      } else {
         $sth->execute();
         my $ref     = $sth->fetchrow_hashref(); 
         $last_name  = $ref->{'lastname'};
         $first_name = $ref->{'firstname'};
         $birthday   = $ref->{'birthday'};
         $email      = $ref->{'email'};
         $telephone  = $ref->{'telephone'};
         $license    = $ref->{'license'};
         $active     = $ref->{'active'};
         $id         = $cgi->param('id');
         $sth->finish();
      }
      print_start_html($cgi, 'Trainer bearbeiten');
      print_link_list($config{'S_LIST_COACH'});
      print_formular();
   } else {
      print_start_html($cgi, 'Fehler: falscher Modus!');
   }
}
print_end_html($cgi);

1;
