########################################################################################
# $Id: 45_Energymanager 1202 2017-06-27 11:00:00Z                                    $ #
# Modul um den Energiehaushalt zu managen                                              #
#                                                                                      #
# Martin Schottmann, 2017                                                              #
#                                                                                      #
########################################################################################
#
#  This programm is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#  A copy is found in the textfile GPL.txt and important notices to the license
#  from the author is found in LICENSE.txt distributed with these scripts.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
########################################################################################

package main;

use strict;
use warnings;
#use Data::Dumper; #Zum Entwickeln und Debuggen, gibt ganze Arrays im Log aus!

#***** Werte die auf der Oberfläche gesetzt werden können
my %sets = (
  "ein" => "noArg",
  "aus" => "noArg",
  "Aktivieren" => "noArg",
  "Prüfen" => "noArg");

#***** Ich benutze keine gets. zum testen von Funktionalität kann dies benutzt werden
my %gets = (
  );

############################################################ INITIALIZE #####
# Die Funktion wird von Fhem.pl nach dem Laden des Moduls 
# aufgerufen und bekommt einen Hash für das Modul als zentrale 
# Datenstruktur übergeben.
sub Energymanager_Initialize($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};
  Log3 "global",4,"ENERGYMANAGER (?) >> Initialize";

  $hash->{DefFn}    = "ENERGYMANAGER_Define";
  $hash->{UndefFn}  = "ENERGYMANAGER_Undef";
  $hash->{SetFn}    = "ENERGYMANAGER_Set";
  $hash->{GetFn}    = "ENERGYMANAGER_Get";
  $hash->{AttrFn}   = "ENERGYMANAGER_Attr";
  $hash->{AttrList} = " Uhrzeit"
    . " Verbraucher-schalten"
#   . " automatic-modus:on,off"
    . " Tage-aktiv"
    . " Bedingung";
  Log3 "global",4,"ENERGYMANAGER (?) << Initialize";
}

################################################################ DEFINE #####
# Die Define-Funktion eines Moduls wird von Fhem aufgerufen wenn 
# der Define-Befehl für ein Geräte ausgeführt wird und das Modul 
# bereits geladen und mit der Initialize-Funktion initialisiert ist
sub Energymanager_Define($$) {
  my ($hash,$def) = @_;
  my $name = $hash->{NAME};
  Log3 $name,5,"ENERGYMANAGER ($name) >> Define";
  
  my @a = split( "[ \t][ \t]*", $def );

  #beim Anlegen ist der Wert "aktiv"
  $hash->{STATE} = "ein";

  #Als Vorgabe einige Attribute definieren, das macht weniger Arbeit als sie
  #bei jedem ENERGYMANAGER komplett neu zu erfassen
  $attr{$name}{"Uhrzeit"} = "0:00";
  $attr{$name}{"Verbraucher-schalten"} = "EG_WZ_PHASE_PARTY:off,EG_WZ_PHASE_DAUER:off,EG_WZ_PHASE_KOMFORT:off";
  $attr{$name}{"Tage-aktiv"} = "Montag,Dienstag,Mittwoch,Donerstag,Freitag";
  $attr{$name}{"devStateIcon"} = 'ein:general_an@green:aus aus:general_aus:ein';
  $attr{$name}{"webCmd"} = "Aktivieren";
  $attr{$name}{"room"} = "Energie";
  $attr{$name}{"group"} = "Automatik";

  if (Value("at_ENERGYMANAGER_$name") eq "") {
    fhem("define at_ENERGYMANAGER_$name at *0:00:00 set $name Prüfen")
  }
  my $at_raum = AttrVal("at_ENERGYMANAGER_$name",'room',undef);
  if (undef $at_raum) {
    fhem("attr at_ENERGYMANAGER_$name room Rolladen");
    fhem("attr at_ENERGYMANAGER_$name group check");
  }

  Log3 $name,5,"ENERGYMANAGER ($name) << Define";
}

################################################################# UNDEF #####
# wird aufgerufen wenn ein Gerät mit delete gelöscht wird oder bei 
# der Abarbeitung des Befehls rereadcfg, der ebenfalls alle Geräte 
# löscht und danach das Konfigurationsfile neu abarbeitet.
sub Energymanager_Undef($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};
  Log3 $name,5,"ENERGYMANAGER ($name) >> Undef";
#  RemoveInternalTimer($hash);
  Log3 $name,5,"ENERGYMANAGER ($name) << Undef";
}

#################################################################### SET #####
sub Energymanager_Set($@) {
  my ($hash,@a) = @_;
  my $name = $hash->{NAME};
  Log3 $name,5,"ENERGYMANAGER ($name) >> Set";
 
  #FEHLERHAFTE PARAMETER ABFRAGEN
  if ( @a < 2 ) {
    Log3 $name,3,"\"set ENERGY\" needs at least an argument << Set";
    return "\"set ENERGY\" needs at least an argument";
  }
  #my $name = shift @a;
  my $opt =  $a[1]; #shift @a;
  my $value = "";
  $value = $a[2] if defined $a[2]; #join("", @a);

  #mögliche Set Eigenschaften und erlaubte Werte zurückgeben wenn ein unbekannter
  #Befehl kommt, dann wird das auch automatisch in die Oberfläche übernommen
  if(!defined($sets{$opt})) {
    my $param = "";
    foreach my $val (keys %sets) {
        $param .= " $val:$sets{$val}";
    }
    if ($opt ne "?") {
      Log3 $name,3,"Unknown argument $opt, choose one of $param";
    }
    Log3 $name,5,"ENERGYMANAGER ($name) << Set";
    return "Unknown argument $opt, choose one of $param";
  }

  #***** Aktivieren *****#
  if ($opt eq "Aktivieren") { 
    starteSzenario($hash);

  #***** Automatik:ein|aus *****#
  } elsif ($opt eq "ein" || $opt eq "aus") {
    $hash->{STATE} = $opt;
    Log3 $name,5,"Automatik Modus ist $opt";

  #***** Prüfen *****#
  } elsif ($opt eq "Prüfen") { 
    checkAktivity($hash);
  
  #***** *****#
  } else {
    Log3 $name,3,"Unbekannter Befehl $opt";
  }
  #Uhrzeit für nächsten Start prüfen
  my $attrZeit = AttrVal($name,'Uhrzeit',undef);
  setzeStartTimer($name,$attrZeit);

  Log3 $name,5,"ENERGYMANAGER ($name) << Set";
}
#*****************************************************************
# diese prüfung wird täglich zur vorgegebenen Szenario-Uhrzeit durchgeführt. 
# Es wird geprüft ob alle Voraussetzungen des Szenario erfüllt werden.
# wenn ja wird das Szenario aktiviert und die ENERGYs in die entsprechende
# Position gefahren.
# Es wird der Timer auf den nächsten Tag zum prüfen gesetzt.
sub checkAktivity($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};
  Log3 $name,5,"ENERGYMANAGER ($name) >> checkAktivity";

  #***** Automatik-Modus aus *****#
  if ($hash->{STATE} eq "aus") {
    Log3 $name,5,"ENERGYMANAGER ($name) << checkAktivity (ist deaktiviert)";
    return;
  }
  #***** Wochentag in Liste *****#
  my $heute = Value('Kalender_Feiertage');
  # Feiertag?
  if ($heute ne "none" and $heute ne "") {
    $heute = "Feiertag";
  # Urlaub in Google Kalender eingetragen?
  } elsif(Value('kalender.urlaub') eq "ja") {
    $heute = "Feiertag";
  # Wochentag heraussuchen  
  } else {
    my ($Sekunden, $Minuten, $Stunden, $Monatstag, $Monat,$Jahr, $Wochentag, $Jahrestag, $Sommerzeit) = localtime(time);
    my @Wochentage = qw(Sonntag Montag Dienstag Mittwoch Donnerstag Freitag Samstag);
    $heute = $Wochentage[$Wochentag];
  }
  my $wochentage = AttrVal($name,'Tage-aktiv',undef);
  if (!defined $wochentage) {
    Log3 $name,4,"ENERGYMANAGER ($name) Attribut Tage-aktiv nicht definiert << checkAktivity";
    return;
  }
  if (index($wochentage, $heute) == -1) {
    Log3 $name,4,"ENERGYMANAGER ($name) << checkAktivity ($heute nicht enthalten in $wochentage)";
    return;
  }
  #***** Pennen aktiv? ****#
  my $party = Value('Party');
  my ($Sekunden, $Minuten, $Stunden, $Monatstag, $Monat,$Jahr, $Wochentag, $Jahrestag, $Sommerzeit) = localtime(time);
  
  if ($party eq "ja") {
    Log3 $name,5,"Partymodus aktiv";
    my $vor10 = UhrzeitVergleich("$Stunden:$Minuten:$Sekunden","0:00:00");
    if ($vor10 == -1) {
      Log3 $name,4,"Szenario schaltet vor 0 Uhr, aber 'Partymodus' ist aktiv -> Szenario nicht starten";
      return;
    }
  }

  #***** Stimmt Uhrzeit? *****#
  my $zeit = AttrVal($name,'Uhrzeit',undef);
  $zeit = getUhrzeit($name,$zeit);
  my $zeitVergleich = UhrzeitVergleich("$Stunden:$Minuten:$Sekunden","$zeit");
  if ($zeitVergleich == -1) {
    #Das Ereignis wird später ausgeführt (im Frühling ist der Sonnenuntergang jeden Tag etwas später).
    #sonst wird der Timer gesetzt und in 2min nochmal aktiviert
    Log3 $name,4,"Zu früh, das Szenario wird erst später aktiviert ($Stunden:$Minuten:$Sekunden < $zeit)";
    return;
  }

  #***** Optional:Bedingung in Atr erfüllt *****#  
  #MeinWetter.heute.max ist ein PRoxyReading auf eine Weather Komponente (höchsttemperatur heute)
  my $bedingungen = AttrVal($name,'Bedingung',undef); 	#MeinWetter.heute.max:>:28
  if (defined $bedingungen) {
	my $ergebnis = eval($bedingungen);
    if(!$ergebnis){
      Log3 $name,4,"$name: Bedingung $bedingungen nicht wahr << checkAktivity";
      return;
    }
	else {
	  Log3 $name,4,"$name: Bedingung $bedingungen ist wahr << checkAktivity";
	}
  }
  #wenn alle Prüfungen ok sind, wird gestartet
  starteSzenario($hash);

  Log3 $name,5,"ENERGYMANAGER ($name) << checkAktivity";
}

#********************************************************
# Das Szenario wird ohne weitere Prüfung aktiviert und die
# ENERGYs entsprechend eingestellt, wird unter anderem von
# checkAktivity() bei Erfolg aufgerufen
sub starteSzenario($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};
  Log3 $name,5,"ENERGYMANAGER ($name) >> starteSzenario";

  #Event auslösen, bedeutet Last auf dem System, aber so kann
  #ich das gerade aktive Event in einem dummy speichern und
  #anzeigen. Der Name des Readings sollte unverwechselbar sein
  readingsSingleUpdate($hash, 'ENERGYMANAGER_aktiviert','ja',1);

  my $aVal = AttrVal($name,'Rolladen-positionen',undef);
  if (!defined $aVal) {
      return "Attribut Rolladen-positionen ist nicht definiert!";
  }
  my @listen = split( "#", $aVal ); #@listen = wohn.ENERGY,schlaf.ENERGY:geschlossen ess.ENERGY:schlitz wohn.tuer.ENERGY:offen
  foreach my $gruppe (@listen) {              #$gruppe = wohn.ENERGY,schlaf.ENERGY:geschlossen
    my @array = split(":",$gruppe);           #@array = [1] wohn.ENERGY,schlaf.ENERGY [2] geschlossen
    my @ENERGYs = split(",",$array[0]);        #@ENERGYs = [1] wohn.ENERGY [2] schlaf.ENERGY
    foreach my $ENERGY (@ENERGYs) {             #$ENERGY = wohn.ENERGY
      # ENERGY Eigenschaften prüfen und anwenden
      my $r_enabled = AttrVal($ENERGY,'automatic-enabled','on');
      if ($r_enabled eq "off") {
        next;
      }
      my $r_delay = AttrVal($ENERGY,'automatic-delay','0');
      my $befehl = "set $ENERGY $array[1]";
      if ($r_delay ne "0") {
	#verzögert ausführen
	$befehl = "define at_".$ENERGY."_delay at +00:". sprintf('%02d',$r_delay) .":00 " . $befehl;
      }
      fhem($befehl);
      Log3 $name,5,$befehl;
    }
  }
  Log3 $name,5,"ENERGYMANAGER ($name) << starteSzenario";
}

#******************* Hilfsfunktion
#***** Prüfe ob Zeit 1 < Zeit2 ist
# Zeit1 > Zeit2 : return 1
# Zeit1 = Zeit2 : return 0
# Zeit1 < Zeit2 : return -1
sub UhrzeitVergleich($$)
{
  my ($zeit1,$zeit2) = @_;
  Log3 "UhrzeitVergleich",5,"$zeit1 vor $zeit2 ?";
  my @z1 = split(":", $zeit1);
  my @z2 = split(":", $zeit2);

  #Stunden vergleichen
  return 1  if (int($z1[0]) > int($z2[0]));
  return -1 if (int($z1[0]) < int($z2[0]));
  #Minuten vergleichen
  return 1  if (int($z1[1]) > int($z2[1]));
  return -1 if (int($z1[1]) < int($z2[1]));
  #Sekunden vergleichen
  return 1  if (int($z1[2]) > int($z2[2]));
  return -1 if (int($z1[2]) < int($z2[2]));

  #bei exakt gleicher Zeit gib false zurück
  return 0;
}

#*************************** Hilfsfunktion
# gibt die Uhrzeit von Namen zurück, z.B.
# wird Sonnenaufgang in 8:00 übersetzt.
# die Namen müssen als entsprechende Dummy 
# in FHEM existieren
sub getUhrzeit($$)
{
  my ($name,$val) = @_;
  Log3 $name,5,"ENERGYMANAGER ($name) >> getUhrzeit";

  if ($val =~ /^(\d|[01]\d|2[0-3]):[0-5]\d$/) {
    Log3 $name,5,"ENERGYMANAGER ($name) << getUhrzeit return $val:00 [1]";
    return "$val:00";
  }
  my $zeit = Value($val);
  if ($zeit =~ /^(\d|[01]\d|2[0-3]):[0-5]\d:[0-5]\d$/) {
    Log3 $name,5,"ENERGYMANAGER ($name) << getUhrzeit return $zeit [2]";
    return $zeit;
  } 

  Log3 $name,5,"ENERGYMANAGER ($name) << getUhrzeit return 10:00:00 (unbekannt) [3]";
  return "10:00:00";
}

################################################################### GET #####
#
sub Energymanager_Get($@) {
  my ($hash, @a) = @_;
  my $name = $hash->{NAME};

  if ( @a < 2 ) {
    return "\"get ENERGY\" needs at least one argument";
  }

  #existiert die abzufragende Eigenschaft in der Liste %gets (Am Anfang)
  #die Oberfläche liest hier auch die möglichen Parameter aus indem sie
  #die Funktion mit dem Parameter ? aufruft
  my $opt = $a[1];
  if(!$gets{$opt}) {
    my @cList = keys %gets;
    return "Unknown argument $opt, choose one of " . join(" ", @cList);
  }
}

################################################################## ATTR #####
#
sub Energymanager_Attr(@) {
  my ($cmd,$name,$aName,$aVal) = @_;
  Log3 $name,5,"ENERGYMANAGER ($name) >> Attr";  
  # $cmd can be "del" or "set"
  # aName and aVal are Attribute name and value
  if ($cmd eq "set") {
    #***** Regex *****#
    if ($aName eq "Regex") {
      eval { qr/$aVal/ };
      if ($@) {
        Log3 $name, 3, "ENERGY: Invalid regex in attr $name $aName $aVal: $@";
	return "Invalid Regex $aVal";
      }

    #***** Uhrzeit *****#
    } elsif ($aName eq "Uhrzeit") {
      #hier einen Timer setzen, der die nächste Uhrzeit setzt
      setzeStartTimer($name,$aVal);
    }
  }
  Log3 $name,5,"ENERGYMANAGER ($name) << Attr";
  return undef;
}
#************************************** Hilfsfunktion
# setzt einen Timer für den nächsten Start
sub setzeStartTimer($$) {
  my ($name,$aVal) = @_;
  Log3 $name,5,"ENERGYMANAGER ($name) >> setzeStartTimer";

  my $zeit = getUhrzeit($name,$aVal);
  my $at_name = "at_ENERGYMANAGER_" . $name;
  my $befehl = "modify " . $at_name . " *" . $zeit;
  fhem($befehl);

  Log3 $name,5,"Energymanager ($name) << setzeStartTimer";
}

1;

=pod
=begin html

<a name="ENERGYMANAGER"></a>
<h3>ENERGY</h3>
<ul>
<p>The module ENERGYMANAGER offers easy away to make simple automatism to your Home.<br> 
		You can define multiple Szenarios and set a starttime. One Szenario is active every time.
    It is still under construction, there are some hardcoded dependencies and the Attributes 
    and set commands are still in german language.
    <h4>Example</h4>
			<p>
				<code>define szenario.day.work ENERGYMANAGER</code>
				<br />
			</p><a name="ENERGYMANAGER_Define"></a>
			<h4>Define</h4>
			<p>
				<code>define &lt;Szenario&gt; ENERGYMANAGER</code> 
				<br /><br /> Define a ENERGYMANAGER szenario.<br />
			</p>
			 <a name="ENERGYMANAGER_Set"></a>
	 <h4>Set</h4>
			<ul>
				<li><a name="ENERGYMANAGER_ein">
						<code>set &lt;Szenario&gt; ein</code></a><br />
						enable this szenario</li>
				<li><a name="ENERGYMANAGER_aus">
						<code>set &lt;Szenario&gt; aus</code></a><br />
						disable this szenario</li>		
				<li><a name="ENERGYMANAGER_pruefen">
						<code>set &lt;Szenario&gt; Prüfen</code></a><br />
						check if all conditions are true and if, activate the szenario</li>						
				<li><a name="ENERGYMANAGER_aktivieren">
						<code>set &lt;Szenario&gt; Aktivieren</code></a><br />
						activate the szenario even if some conditions are false</li>						
			</ul>
			<a name="ENERGYMANAGER_Attr"></a>
			<h4>Attributes</h4>
			<ul>
				<li><a name="ENERGYMANAGER_rolladen-positionen"><code>attr &lt;Szenario&gt; rolladen-positionen RolladenName[,Rolladen2Name]:Position</code></a>
					<br />set the positionto drive your power sockets when szenario will be activated.<BR/>
							Commaseparated list of your power socketss, then seperated by : the position of your power socketss</li>
				<li><a name="ENERGYMANAGER_Tage-aktiv"><code>attr &lt;Szenario&gt; Tage-aktiv	&lt;string&gt;</code></a>
					<br />The Name of the Days you want to activate the scenario, kommaseparated
          <BR/>allowed Names are: Montag,Dienstag,Mittwoch,Donnerstag,Freitag,Samstag,Sonntag,Feiertag</li>
				<li><a name="ENERGYMANAGER_Uhrzeit"><code>attr &lt;Szenario&gt; Uhrzeit	&lt;time&gt;</code></a>
					<br />set the Time for your Szenario to activate<BR/>
          Format is in 24h, examples: 6:14, 19:00. Variable Names with a comparable time string as state also allowed</li>
				<li><a name="ENERGY_automatic-Bedingung"><code>attr &lt;Szenario&gt; Bedingung &lt;string&gt;</code></a>
					<br />additional conditions that must be true to activate the szenario</li>
			</ul>
      <a name="ENERGYMANAGER_environment"></a>
      <h4>Environment</h4>
      <ul>
        <li>Kalender_Feiertage
          <BR/>if value not equal "ne" then the attribute "Tage-aktiv" is only valid if it is set to "Feiertag"
        </li>
        <li>kalender.urlaub
          <BR/>if value is equal to "ja" then the attribute "Tage-aktiv" is only valid if it is set to "Feiertag"
        </li>
        <li>Pennen
          <BR/>if value is equal to "ja" every szenario bevor 0:00 clock are not activated
        </li>
      </ul>
</ul>
=end html

=cut
