# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#  Sää v. 3.2, FMI edition                                                                #
#  Näyttää säätietoja eri paikkakunnilta                                                  #
#                                                                                         #
#  Kanavat joilla botin sallitaan säätietoja näyttävän asetetaan partylinessä komennolla  #
#   .chanset #kanava [+|-]saa                                                             #
#  Voi myös asettaa scriptin toimimaan kaikilla kanavilla Asetukset-kohdassa              #
#                                                                                         #
#  Käyttö: !sää <paikkakunta>                                                             #
#                                                                                         #
#  Hakee sään osoitteesta ilmatieteenlaitos.fi (ex. fmi.fi)                               #
#                                                                                         #
#  Code by Joose                                                                          #
#  [joose ät joose piste biz]                                                             #
#  http://github.com/joosera/eggdrop-scripts                                              #
#                                                                                         #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

namespace eval saa_fmi {

	# ---------------------------------------------------------------------------------------------------------- #
	# Asetukset

	# Komento (tai komennot) joilla skripti aktivoituu (oletus "!sää !saa")
	set bind "!saa !sää"

	# Määrittelee vakio-sijainnin jota käytetään jos komentoa käytetään yksinään
	# Jätä tyhjäksi jos haluat että näytetään vain virhe-viesti
	set default_location "Helsinki"

	# Määrittelee toimiiko botti oletuksena kaikilla kanavilla
	# 0 = vain partylinessä määritellyt, 1 = kaikki kanavat
	set allchan 0

	# Jos edellinen kohta on 1, voit tässä määritellä kanavat joilla botti EI vastaa (erottele välilyönnillä)
	set allchan_blacklist ""

	# Sekunteina kuinka usein scriptiä voi käyttää
	set rest_time 10

	# Määrittelee onko lepoaika (kts. edellinen kohta) kanavakohtainen vai globaali
	# 1 = globaali, 2 = kanavakohtainen
	set restmode 2

	# Määrittele miten käyttäjälle ilmoitetaan että lepoaika on voimassa
	# 0 = ei ilmoitusta, 1 = NOTICE, 2 = PRIVMSG
	set rest_msg_method 1

	# Määrittele viesti mikä käyttäjälle ilmoitetaan jos lepoaika on voimassa
	# %time% = jäljellä oleva aika, %channel% = kanava jossa komentoa käytettiin
	set rest_msg "%channel%: Ethän floodaa komentoja (Odota vielä %time% sekuntia)"

	# Määrittele mitä flagia käyeteään debug-tulostukselle (default d, eli partylinessä: .console +d )
	set debugflag d

	# Älä muuta tästä eteenpäin ellet tiedä mitä teet
	# ---------------------------------------------------------------------------------------------------------- #


	set scriptversion "Sää (v. 3.2, FMI edition) by Joose"
	set protection ""
	set allchan_blacklist [string tolower $allchan_blacklist]

	foreach bind [split $saa_fmi::bind " "] {
		bind pub - $bind saa_fmi::pubWeather
	}

	if { $saa_fmi::allchan == 0 } { setudef flag saa }
	if { $saa_fmi::restmode == 2 } { array set rest {}}

	proc pubWeather {nick host hand chan text} {
		set resting ""
		if { (($saa_fmi::allchan == 0) && ([channel get $chan saa])) || (($saa_fmi::allchan == 1) && ([lsearch [split $saa_fmi::allchan_blacklist] [string tolower $chan]] == -1)) }  {
			if {($saa_fmi::restmode == 1)} {
				if {([expr [unixtime] - $saa_fmi::rest_time] > $saa_fmi::protection)} {
					set saa_fmi::protection [unixtime]
					set resting 0
				} else {
					set resting [expr $saa_fmi::rest_time - [unixtime] + $saa_fmi::protection]
				}
			} elseif {($saa_fmi::restmode == 2)} { 
				if {([expr [unixtime] - $saa_fmi::rest_time] > [lindex [array get saa_fmi::rest $chan] 1])} {
					array set saa_fmi::rest [list $chan [unixtime]]
					set resting 0
				} else {
					set resting [expr [lindex [array get saa_fmi::rest $chan] 1] - [unixtime] + $saa_fmi::rest_time]
				}
			} else { return }

			if { $resting == 0 } {
				set haku [saa_fmi::getWeather $text]
				putserv "PRIVMSG $chan :$haku"
				return
			} elseif { $resting > 0 } {
				putloglev $saa_fmi::debugflag * "Debug: Sää resting on channel $chan for $resting seconds"
				set rest_msg [string map [list "%time%" $resting "%channel%" $chan] $saa_fmi::rest_msg]
				switch -- $saa_fmi::rest_msg_method {
					0 {}
					1 {puthelp "NOTICE $nick :$rest_msg"}
					2 {puthelp "PRIVMSG $nick :$rest_msg"}
				}
				return
			} else { return }
		} else { return }
	}

	proc getWeather { text } {
		set id ""
		set label ""
		set value ""
		set sunset ""
		set sunrise ""
		set daylength ""
		set station ""
		set weatherdata ""
		set date ""

		if {($text=="") && ($saa_fmi::default_location=="")} {
			return "Et antanut paikannimeä!"
		} elseif {($text=="") && !($saa_fmi::default_location=="")} {
			set text $saa_fmi::default_location
		}

		set host "ilmatieteenlaitos.fi"

		set url "/paikallissaa?p_p_id=locationmenuportlet_WAR_fmiwwwweatherportlets&p_p_lifecycle=2&p_p_mode=view&doAsUserLanguageId=fi_FI&term=[url_encode $text]"
		set data [saa_fmi::makequery $host $url]

		regexp  {\{\"id\"\:\"([\,\w ]+)\"\,\"label\"\:\"([\,\w ]+)\"\,\"value\"\:\"([\,\w ]+)\"\}} $data -> id label value

		set place [split $id ","]
		set place1 [string totitle [string trim [lindex $place 0]]]
		set place2 [string totitle [string trim [lindex $place 1]]]

		if {$place1 == ""} {
			return "Paikannimellä \"$text\" ei löytynyt säätietoja"
		} elseif {$place2 != ""} {
			set place "${place1}, ${place2}"
			set url "/saa/${place2}/${place1}"
		} else {
			set place "${place1}"
			set url "/saa/${place1}"
		}

		set data [saa_fmi::makequery $host $url]

		# Aurinkoajat
		regexp {<div class="celestial-status">\s*?<div class="celestial-icon"></div>\s*?<div class="celestial-text">\s*?Auringonnousu tänään\s*?<strong>(.*?)</strong>\.\s*?Auringonlasku tänään\s*?<strong>(.*?)</strong>\.\s*?Päivän pituus on\s*?<strong>\s*?(.*?)</strong>\.\s*?</div>\s*?</div>} $data -> sunrise sunset daylength

		# Havaintoasema
		regexp {<select id="_localweatherportlet_WAR_fmiwwwweatherportlets_select" name="station".*?>.*?<option value="\d*?" selected="selected">(.*?)</option>.*?</select>} $data -> station

                # Havaintodata
		regexp {<div class="station-status-text">(.*?)</div>} $data -> weatherdata

		# Havaintoaika
		regexp {<span class="time-stamp-title">.*?</span>\s*?<span class="time-stamp">(.*?)</span>} $weatherdata -> date

		set output "Hakutulos: [saa_fmi::clearText $place]; Havaintoasema: [saa_fmi::clearText $station]; Tuorein säähavainto: [saa_fmi::clearText $date]; "

		set info [regexp -all -inline {<span class="parameter-name-value">\s*?<span class="parameter-name">(.*?)</span>\s*?<span class="parameter-value">(.*?)</span>\s*?</span>} $weatherdata]
		foreach {fullmatch name value} $info {
			set value [expr {$value != "" ? " [saa_fmi::clearText $value]" : ""}]
			append output "[saa_fmi::clearText $name]${value}; "
		}

		append output "Auringonnousu: [saa_fmi::clearText $sunrise]; Auringonlasku: [saa_fmi::clearText $sunset];[expr {$daylength != "" ? " Päivän pituus: [saa_fmi::clearText $daylength];" : ""}]"
		return $output
	}

	proc clearText {text {charset "utf-8"}} {
		set text [encoding convertfrom $charset $text]
		set text [saa_fmi::convertHTML $text]
		regsub -all -- {\<[^\>]*\>|\t} $text "" text
		set text [string trim $text]
		return $text
	}

	proc convertHTML {text} {
		set escapes {
			&nbsp; \xa0 &iexcl; \xa1 &cent; \xa2 &pound; \xa3 &curren; \xa4
			&yen; \xa5 &brvbar; \xa6 &sect; \xa7 &uml; \xa8 &copy; \xa9
			&ordf; \xaa &laquo; \xab &not; \xac &shy; \xad &reg; \xae
			&macr; \xaf &deg; \xb0 &plusmn; \xb1 &sup2; \xb2 &sup3; \xb3
			&acute; \xb4 &micro; \xb5 &para; \xb6 &middot; \xb7 &cedil; \xb8
			&sup1; \xb9 &ordm; \xba &raquo; \xbb &frac14; \xbc &frac12; \xbd
			&frac34; \xbe &iquest; \xbf &Agrave; \xc0 &Aacute; \xc1 &Acirc; \xc2
			&Atilde; \xc3 &Auml; \xc4 &Aring; \xc5 &AElig; \xc6 &Ccedil; \xc7
			&Egrave; \xc8 &Eacute; \xc9 &Ecirc; \xca &Euml; \xcb &Igrave; \xcc
			&Iacute; \xcd &Icirc; \xce &Iuml; \xcf &ETH; \xd0 &Ntilde; \xd1
			&Ograve; \xd2 &Oacute; \xd3 &Ocirc; \xd4 &Otilde; \xd5 &Ouml; \xd6
			&times; \xd7 &Oslash; \xd8 &Ugrave; \xd9 &Uacute; \xda &Ucirc; \xdb
			&Uuml; \xdc &Yacute; \xdd &THORN; \xde &szlig; \xdf &agrave; \xe0
			&aacute; \xe1 &acirc; \xe2 &atilde; \xe3 &auml; \xe4 &aring; \xe5
			&aelig; \xe6 &ccedil; \xe7 &egrave; \xe8 &eacute; \xe9 &ecirc; \xea
			&euml; \xeb &igrave; \xec &iacute; \xed &icirc; \xee &iuml; \xef
			&eth; \xf0 &ntilde; \xf1 &ograve; \xf2 &oacute; \xf3 &ocirc; \xf4
			&otilde; \xf5 &ouml; \xf6 &divide; \xf7 &oslash; \xf8 &ugrave; \xf9
			&uacute; \xfa &ucirc; \xfb &uuml; \xfc &yacute; \xfd &thorn; \xfe
			&yuml; \xff &fnof; \u192 &Alpha; \u391 &Beta; \u392 &Gamma; \u393 &Delta; \u394
			&Epsilon; \u395 &Zeta; \u396 &Eta; \u397 &Theta; \u398 &Iota; \u399
			&Kappa; \u39A &Lambda; \u39B &Mu; \u39C &Nu; \u39D &Xi; \u39E
			&Omicron; \u39F &Pi; \u3A0 &Rho; \u3A1 &Sigma; \u3A3 &Tau; \u3A4
			&Upsilon; \u3A5 &Phi; \u3A6 &Chi; \u3A7 &Psi; \u3A8 &Omega; \u3A9
			&alpha; \u3B1 &beta; \u3B2 &gamma; \u3B3 &delta; \u3B4 &epsilon; \u3B5
			&zeta; \u3B6 &eta; \u3B7 &theta; \u3B8 &iota; \u3B9 &kappa; \u3BA
			&lambda; \u3BB &mu; \u3BC &nu; \u3BD &xi; \u3BE &omicron; \u3BF
			&pi; \u3C0 &rho; \u3C1 &sigmaf; \u3C2 &sigma; \u3C3 &tau; \u3C4
			&upsilon; \u3C5 &phi; \u3C6 &chi; \u3C7 &psi; \u3C8 &omega; \u3C9
			&thetasym; \u3D1 &upsih; \u3D2 &piv; \u3D6 &bull; \u2022
			&hellip; \u2026 &prime; \u2032 &Prime; \u2033 &oline; \u203E
			&frasl; \u2044 &weierp; \u2118 &image; \u2111 &real; \u211C
			&trade; \u2122 &alefsym; \u2135 &larr; \u2190 &uarr; \u2191
			&rarr; \u2192 &darr; \u2193 &harr; \u2194 &crarr; \u21B5
			&lArr; \u21D0 &uArr; \u21D1 &rArr; \u21D2 &dArr; \u21D3 &hArr; \u21D4
			&forall; \u2200 &part; \u2202 &exist; \u2203 &empty; \u2205
			&nabla; \u2207 &isin; \u2208 &notin; \u2209 &ni; \u220B &prod; \u220F
			&sum; \u2211 &minus; \u2212 &lowast; \u2217 &radic; \u221A
			&prop; \u221D &infin; \u221E &ang; \u2220 &and; \u2227 &or; \u2228
			&cap; \u2229 &cup; \u222A &int; \u222B &there4; \u2234 &sim; \u223C
			&cong; \u2245 &asymp; \u2248 &ne; \u2260 &equiv; \u2261 &le; \u2264
			&ge; \u2265 &sub; \u2282 &sup; \u2283 &nsub; \u2284 &sube; \u2286
			&supe; \u2287 &oplus; \u2295 &otimes; \u2297 &perp; \u22A5
			&sdot; \u22C5 &lceil; \u2308 &rceil; \u2309 &lfloor; \u230A
			&rfloor; \u230B &lang; \u2329 &rang; \u232A &loz; \u25CA
			&spades; \u2660 &clubs; \u2663 &hearts; \u2665 &diams; \u2666
			&quot; \x22 &amp; \x26 &lt; \x3C &gt; \x3E &OElig; \u152 &oelig; \u153
			&Scaron; \u160 &scaron; \u161 &Yuml; \u178 &circ; \u2C6
			&tilde; \u2DC &ensp; \u2002 &emsp; \u2003 &thinsp; \u2009
			&zwnj; \u200C &zwj; \u200D &lrm; \u200E &rlm; \u200F &ndash; \u2013
			&mdash; \u2014 &lsquo; \u2018 &rsquo; \u2019 &sbquo; \u201A
			&ldquo; \u201C &rdquo; \u201D &bdquo; \u201E &dagger; \u2020
			&Dagger; \u2021 &permil; \u2030 &lsaquo; \u2039 &rsaquo; \u203A
			&euro; \u20AC &apos; \u0027 &lrm; "" &rlm; ""
		};
		set text [string map [list "\]" "\\\]" "\[" "\\\[" "\$" "\\\$" "\"" "\\\"" "\\" "\\\\"] [string map $escapes $text]]
		regsub -all -- {&#([[:digit:]]{1,5});} $text {[format %c [string trimleft "\1" "0"]]} text
		regsub -all -- {&#x([[:xdigit:]]{1,4});} $text {[format %c [scan "\1" %x]]} text
		catch { set text "[subst "$text"]" }
		return "$text"
	}

	proc url_decode { str } {
		set str [string map [list + { } "\\" "\\\\"] $str]
		regsub -all -- {%([A-Fa-f0-9][A-Fa-f0-9])} $str {\\u00\1} str
		return [subst -novar -nocommand $str]
	}

	proc url_encode { str } {
		return [string map {"\n" "%0A"} [subst [regsub -all {[^-A-Za-z0-9._~\n]} [encoding convertto utf-8 $str] {%[format "%02X" [scan "\\\0" "%c"]]}]]]
	}

	proc makequery {host url {post false} {cookie false} {ssl false} {port false} } {
		if {![string is false $post]} { 
			set haku "POST $url HTTP/1.1\n"
			append haku "Host: ${host}\n"
			if {![string is false $cookie]} {append haku "Cookie: ${cookie}\n"}
			append haku "User-Agent: Mozilla/5.0 ($::tcl_platform(os); U; $::tcl_platform(os) $::tcl_platform(machine); en) TCL/$::tcl_version\n"
			append haku "Content-Length: [string length $post]\n"
			append haku "Content-Type: application/x-www-form-urlencoded\n"
			append haku "Connection: close\n"
			append haku "\n"
			append haku $post
			append haku "\n"
		} else {
			set haku "GET $url HTTP/1.1\n"
			append haku "Host: ${host}\n"
			if {![string is false $cookie]} {append haku "Cookie: ${cookie}\n"}
			append haku "User-Agent: Mozilla/5.0 ($::tcl_platform(os); U; $::tcl_platform(os) $::tcl_platform(machine); en) TCL/$::tcl_version\n"
			append haku "Connection: close\n"
			append haku "\n"
		}

		if {$ssl == true} {
			package require tls
			if {$port == false} {
				set port 443
			}
			set sock [::tls::socket $host $port]
		} else {
			if {$port == false} {
				set port 80
			}
			set sock [socket $host $port]
		}

		puts $sock $haku
		flush $sock
		set out [read $sock]
		close $sock

		set output ""
		#array set header {}
		set in_header 0
		foreach line [split $out "\n"] {
			if {($in_header == 0) && [regexp {^([\w-]*?)\: (.*?)$} $line -> header header_data]} {
				# We are in headers
				# set header("$header") "$header_data"
			} elseif {($in_header == 0) && ($line == "")} {
				# End of headers
				incr in_header
			} elseif {$in_header == 1} {
				# We've got data!
				append output "$line\n"
			}
		}

		return $output
	}
}

putlog "${saa_fmi::scriptversion} loaded"
