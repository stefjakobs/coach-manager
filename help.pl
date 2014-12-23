#!/usr/bin/perl -wT

######
# Copyright (c) 2013 Stefan Jakobs
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
use utf8;
use CGI;
use lib '.';
use functions;

my $cgi = CGI->new;

my %config = read_config();

## Adminportal 
sub print_help_msg() {
   print <<"EOF"; 
   <h2> Hilfe </h2>
   <p class="p_black"> Nachfolgend einige Hilfen zum Verwenden dieses Webdienstes. </p>
   <h3>&Uuml;bersicht</h3>
   <p class="p_black">Die &Uuml;bersicht zeigt immer den aktuellen Monat an. In der Matrix sind
   die aktiven Trainer &uuml;ber die Trainingstage dargestellt. Zus&auml;tzlich
   wird eine Zeile f&uuml;r die Anzahl der Teilnehmer, sowie eine Zeile mit jeweils
   einer Checkbox pro Tag angezeigt. Letzte dient dazu einen Termin als ausgefallen
   zu markieren.</p>
   <p class="p_black">&Auml;nderungen werden erst nach einem Klick auf den Knopf '&Uuml;bernehmen'
   in der Datenbank gespeichert. Ein erneuter Aufruf der Seite (z.B. mittels Klick
   auf '&Uuml;bersicht') l&ouml;scht die &Auml;nderungen und ruft die Seite mit den
   alten Einstellungen wieder auf.</p>
   <p class="p_black">Die &Uuml;bersichtsseite setzt einen Session Cookie, der 10 Minuten g&uuml;ltig
   ist. Dieser wird beim Klick auf den Knopf '&Uuml;bernehmen' ausgewertet und die &Auml;nderungen
   werden nur &uuml;bernommen, wenn der Cookie g&uuml;ltig ist. Ansonsten werden die &Auml;nderungen
   verworfen und die Seite neu geladen.</p>
   <p class="p_black">Damit die Matrix &uuml;berhaupt Traingstage anzeigt, m&uuml;ssen zuvor Kurse
   angelegt werden.<p class="p_black">

   <h3>Kurse anlegen</h3>
   <p class="p_black">Ein Kurs muss einen eindeutigen Namen erhalten. Weiterhin muss er beim Anlegen
   ein Startdatum erhalten und ein Enddatum. Ausgehend vom Startdatum wird f&uuml;r
   einen Kurs periodisch ein w&ouml;chentlicher Trainingstag angelegt bis das Enddatum
   erreicht oder &uuml;berschritten wurde.</p>
   <p class="p_black">Beispiel: Als Startdatum wird Mittwoch der 16. Oktober 2013 (2013-10-16)
   eingetragen. Als Enddatum wird Dienstag der 29. Oktober 2013 (2013-10-29)
   eingetragen. Dann werden die folgenden Trainingstage erstellt und in der
   &Uuml;bersicht dargestellt:</p>
   <ul>
     <li>Mi, 16.10.13</li>
     <li>Mi, 23.10.13</li>
   </ul>
   <p class="p_black">Das Startdatum legt fest auf welchen Wochentag die Trainingstage eines Kurses
   fallen. Es ist nicht m&ouml;glich das Startdatum im nachhinein zu &auml;ndern.
   In einem solchen Fall muss der Kurs gel&ouml;scht und neu angelegt werden.</p>
   <p class="p_black">Die Startzeit und Endzeit sind nur f&uuml;r die sp&auml;tere Abrechnung wichtig.
   </p>
   
   <h3>Kurse anzeigen</h3>
   <p class="p_black">Die Seite 'Kurse anzeigen' listet alle eingetragenen Kurse mit seinen Namen,
   seiner eindeutigen ID und den Trainingszeiten auf. Über die Links 'l&ouml;schen'
   und 'bearbeiten' kann ein Kurs gel&ouml;scht bzw. seine Daten ver&auml;ndert
   werden.</p>
   <p class="notice">ACHTUNG: Das l&ouml;schen eines Kurses entfernt alle
   Trainingstage mit den zugeordneten Anwesenheitseinstellungen. Eine Abrechnung
   ist danach nicht mehr m&ouml;glich.</p>

   <h3>Trainer anlegen</h3>
   <p class="p_black">Auf der Seite 'Trainer anlegen' können Trainer eingerichtet werden. Dabei muss
   mindestens der Vorname, Nachname sowie ein Geburtsdatum eingegeben werden.
   Beim Eintragen sind folgende Regeln zu beachten:</p>
   <ul>
     <li>Vorname, Nachname: Diese d&uuml;rfen nur aus den Buchstaben A-Z,a-z,&auml;,
   &uuml;,&ouml;,&szuml; bestehen.</li>
     <li>Geburtsdatum: Dieses muss in dem Format JJJJ-MM-DD (z.B. 2013-10-11)
     angegeben werden.</li>
     <li>E-Mailadresse: Dieses Feld ist optional. Evtl. k&ouml;nnen nicht alle
     E-Mailadressen eingegeben werden. Dies bitte als Bug melden.</li>
     <li>Telefonr: Dieses Feld ist optionale. Die Nummer darf nur aus den
     Zeichen: 0-9, ,/,-,+ bestehen.</li>
     <li>Trainerlizenz: Dieses Feld ist optional. Es k&ouml;nnen nur die Zeichen
     A,B,C,D verwendet werden.</li>
     <li>Aktiv: Diese Checkbox bestimmt, ob ein Trainer in der &Uuml;bersicht
     angezeigt wird.</li>
   </ul>

   <h3>Trainer anzeigen</h3>
   <p class="p_black">Die Seite 'Trainer anzeigen' listet alle eingetragenen Trainer mit den
   jeweiligen Daten auf. Hier werden auch inaktive Trainer angezeigt.
   &Uuml;ber die Links 'l&ouml;schen' und 'bearbeiten' K&ouml;nnen Trainer
   entfernt oder deren Daten bearbeitet werden.</p>

EOF
}


print_start_html($cgi, 'Hilfe');
print_link_list('');
print_help_msg();
print_end_html($cgi);

1;
