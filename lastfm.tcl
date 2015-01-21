# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# lastfm.tcl                                                            #
#                                                                       #
# Gets currently playing song (or latest played song, if none playing   #
# currently) from Last.fm                                               #
#                                                                       #
# Required libraries:                                                   #
# - tdom http://tdom.github.io/                                         #
#                                                                       #
# Version: 0.2                                                          #
# Updated: 22.1.2015                                                    #
#                                                                       #
# Code by Joose                                                         #
# [joose ät joose piste biz]                                            #
# http://github.com/joosera/eggdrop-scripts                             #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if {[namespace exists ::lastfm]} {namespace delete ::lastfm}
namespace eval ::lastfm {

	# Settings ----------------

	# Last.fm API key (Get your own from http://www.last.fm/api )
	set api_key ""

	# Bindings
	bind pub -|- !np [namespace current]::public
	bind msg -|- !np [namespace current]::msg

	# Wait time between commands, in seconds
	set wait 5

	# --------------------------

	array set rest {}

	package require http
	package require tdom

	proc public { nick host handle chan text } {
		set args [split $text]
		set username [lindex $args 0]
		if {$username == ""} {
			set username $nick
		} else {
			set lownick [string tolower $nick]
			set username [string map [list {+} ${lownick} {@} ${lownick}] $username]
		}
		if {[expr [unixtime] - $::lastfm::wait] > [lindex [array get ::lastfm::rest $nick] 1]} {
			putquick "PRIVMSG $chan :[get_recent_track $username]"
			array set ::lastfm::rest [list $nick [unixtime]]
		} else {
			set resting [expr [lindex [array get ::lastfm::rest $nick] 1] - [unixtime] + $::lastfm::wait]
			putquick "NOTICE $nick :Don't spam! (Wait $resting seconds)"
		}
	}

	proc msg { nick host handle text } {
		set args [split $text]
		set username [lindex $args 0]
		set channel [lindex $args 1]
		if {[botonchan $channel] && [onchan $nick $channel]} {
			if {[expr [unixtime] - $::lastfm::wait] > [lindex [array get ::lastfm::rest $nick] 1]} {
				putquick "PRIVMSG $channel :$nick np: [get_recent_track $username]"
				array set ::lastfm::rest [list $nick [unixtime]]
			} else {
				set resting [expr [lindex [array get ::lastfm::rest $nick] 1] - [unixtime] + $::lastfm::wait]
				putquick "NOTICE $nick :Don't spam! (Wait $resting seconds)"
			}
		} else {
			putquick "NOTICE $nick :Errorneous channel \"$channel\""
		}
	}

	proc get_recent_track {user} {
		variable api_key
		if { $api_key == "" } {
			return "API key not set! (Get your own from http://www.last.fm/api )"
		}

		set status ""
		set errorid ""
		set error ""
		set total ""
		set track ""
		set artist ""
		set album ""
		set playtime 0
		set nowplaying false

		set url "http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=[::lastfm::urlencode $user]&api_key=$api_key&limit=1"
		putlog "Last.FM $url"
		set token [http::geturl $url]
		set dom [dom parse [http::data $token]]
		set doc [$dom documentElement]
		http::cleanup $token

		set status [$doc selectNodes {string(/lfm/@status)}]
		set errorid [$doc selectNodes {string(/lfm/error/@code)}]
		if {$status == "failed" && $errorid == 4} {
			set output "This user has made their recent tracks private."
		} elseif {$status == "failed" && $errorid == 6} {
			set output "User not found."
		} elseif {$status == "ok"} {
			set total [$doc selectNodes {string(/lfm/recenttracks/@total)}]
			if {$total == 0} {
				set output "User has no played tracks yet."
			} else {
				set track [$doc selectNodes {string(/lfm/recenttracks/track/name)}]
				set artist [$doc selectNodes {string(/lfm/recenttracks/track/artist)}]
				set album [$doc selectNodes {string(/lfm/recenttracks/track/album)}]
				set playtime [$doc selectNodes {string (/lfm/recenttracks/track/date/@uts)}]
				set nowplaying [$doc selectNodes {string (/lfm/recenttracks/track/@nowplaying)}]

				if {$nowplaying == "true"} {
					set played ""
				} else {
					if {[string is digit $playtime]} {
						set played "Listened at: [clock format $playtime -gmt 1 -format {%d.%m.%Y %H:%M:%S UTC}]"
					}
				}

				set output "$artist - $track[expr {$album!="" ? " ($album)" : ""}][expr {$played!="" ? " <$played>" : ""}]"
			}
		} else {
			set error [$doc selectNodes {string(/lfm/error)}]
			set output "Unknown error (server response: $error)"
		}
		$doc delete
		$dom delete

		return $output
	}

	proc urlencode {string} {
		for {set i 0} {$i <= 256} {incr i} {
			set c [format %c $i]
			if {![string match \[a-zA-Z0-9\] $c]} {
				set map($c) %[format %.2x $i]
			}
		}
		# These are handled specially
		array set map { " " + \n %0d%0a }

		regsub -all \[^a-zA-Z0-9\] $string {$map(&)} string
		# This quotes cases like $map([) or $map($) => $map(\[) ...
		regsub -all {[][{})\\]\)} $string {\\&} string
		return [subst -nocommand $string]
	}
}

# Script loaded
putlog "[file tail [info script]] loaded"
