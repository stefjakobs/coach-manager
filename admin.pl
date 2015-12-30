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

my $cgi = CGI->new;

my %config = read_config();

## Adminportal 
sub print_formular() {
   print <<"EOF"; 
   <h3> Administration </h3>
   <p>Under construction:</p>

      
   <h3>Wichtige Dokumente</h3>
   <p><a href="GrundlegendeInformationenFuerTrampolintrainer.pdf">Grundlegende Informationen für Trampolintrainer (PDF)</a></p>
   <p><a href="GrundlegendeInformationenFuerTrampolintrainer.tex">Grundlegende Informationen für Trampolintrainer (tex)</a></p>
   <p> </p>
   <p><a href="Protokoll_Versammlung_2014.pdf">Protokoll Versammlung 2014 (PDF)</a></p>
   <p><a href="Versicherungsschein.pdf">Versicherungsschein (PDF)</a></p>
EOF
}

sub untaint_input() {
   ## untaint input
#   if ( defined($cgi->param('first_name')) and $cgi->param('first_name') =~ /^[\wßäüö]+$/i ) {
#      $first_name = $cgi->param('first_name');
#   } else {
#      $error .= "Vorname darf nur aus Buchstaben bestehen!<br>";
#   }
}

# Connect to the database.
my $dbh = init_db(\%config);


# Read in text
if (defined($ENV{'REQUEST_METHOD'}) and uc($ENV{'REQUEST_METHOD'}) eq "POST") {
   print_start_html($cgi, 'Administration');
   print_link_list('');
   untaint_input();

   if (! defined($error)) {
#      eval { $dbh->do("INSERT INTO $config{'T_COACH'} ( lastname, firstname, birthday, email, telephone, license, active )
#                       VALUES (\"$last_name\", \"$first_name\", \"$birthday\", \"$email\", \"$telephone\", \"$license\", \"$active\")" ) };
#      $error .= "Insert failed: $@\n" if $@;
   }

   print_formular();
   if (defined($error)) {
      print "<p class=\"error\">$error</p>";
   } else {
#      print "<p class=\"notice\">Trainer $first_name $last_name wurde angelegt.</p>";
   }
} else {
   print_start_html($cgi, 'Administration');
   print_link_list('');
   print_formular();
}
print_end_html($cgi);

1;
