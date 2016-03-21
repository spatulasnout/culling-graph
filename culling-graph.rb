# encoding: utf-8
#
# The Culling damage log parser & grapher
#
# This utility reads the logfile for The Culling at:
#   %LOCALAPPDATA%/Victory/Saved/Logs/Victory.log
#
# It renders stats to an HTML file in %TEMP%, then opens
# that file for viewing using the default web browser.
# 
# Github: https://github.com/spatulasnout/culling-graph
# 
# Binary compiled with: ocra --no-enc culling-graph.rb
#
# Copyright (c) 2016 Bill Kelly.  All Rights Reserved.
# 
# Redistribution and use in source and binary forms, with or without 
# modification, are permitted provided that the following conditions 
# are met: 
# 
# 1. Redistributions of source code must retain the above copyright 
# notice, this list of conditions and the following disclaimer.  
# 
# 2. Redistributions in binary form must reproduce the above 
# copyright notice, this list of conditions and the following 
# disclaimer in the documentation and/or other materials provided 
# with the distribution.  
# 
# 3. Neither the name of the copyright holder nor the names of its 
# contributors may be used to endorse or promote products derived 
# from this software without specific prior written permission.  
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND 
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, 
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
# DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT HOLDER OR 
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF 
# USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED 
# AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN 
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
# POSSIBILITY OF SUCH DAMAGE.  

require 'date'
require 'cgi'

PROG_VER = "1.0"

class Logger
  def initialize
    @prefix = ""
  end

  def trace(options=EMPTYHASH)
    # TODO: check loglevel
    log("TRCE", yield, options)
  end

  def info(options=EMPTYHASH)
    # TODO: check loglevel
    log("INFO", yield, options)
  end

  def dbg(options=EMPTYHASH)
    # TODO: check loglevel
    log("DBG_", yield, options)
  end

  def warn(options=EMPTYHASH)
    # TODO: check loglevel
    log("WARN", yield, options)
  end

  def error(options=EMPTYHASH)
    # TODO: check loglevel
    log("ERR!", yield, options)
  end

  def fatal(options=EMPTYHASH)
    log("FATAL", yield, options)
  end

  protected
  
  EMPTYHASH = {}.freeze
  EMPTYSTR = "".freeze
  NEWLINE = "\n".freeze
  TSTAMP_FMT = "%Y-%m-%d %H:%M:%S.%L %a".freeze
  PID_FMT = "%05d:%08d".freeze
  
  def log(loglevel_tag, msg, options={})
    tstamp = Time.now.strftime(TSTAMP_FMT)
    pid_str = PID_FMT % [Process.pid, Fiber.current.object_id]
    annotation = options[:annotation] || EMPTYSTR
    line = "[#{tstamp}] [#{pid_str}] #{loglevel_tag} #{@prefix}#{annotation}#{msg}\n"
    writelog(msg)
  end
  
  def writelog(msg)
    puts msg
  end
end # Logger


module ANSI
  Reset   = "0"
  Bright  = "1"
  
  Black   = "30"
  Red     = "31"
  Green   = "32"
  Yellow  = "33"
  Blue    = "34"
  Magenta = "35"
  Cyan    = "36"
  White   = "37"
  
  BGBlack   = "40"
  BGRed     = "41"
  BGGreen   = "42"
  BGYellow  = "43"
  BGBlue    = "44"
  BGMagenta = "45"
  BGCyan    = "46"
  BGWhite   = "47"

  def color(*colors)
    "\033[#{colors.join(';')}m"
  end
  
  def colorize(str, start_color, end_color = Reset)
    start_color = start_color.join(";") if start_color.respond_to? :join
    end_color = end_color.join(";") if end_color.respond_to? :join
    "#{color(start_color)}#{str}#{color(end_color)}"
  end
  
  def red(str);     colorize(str, Red) end
  def green(str);   colorize(str, Green) end
  def yellow(str);  colorize(str, Yellow) end
  def blue(str);    colorize(str, Blue) end
  def magenta(str); colorize(str, Magenta) end
  def cyan(str);    colorize(str, Cyan) end
  def white(str);   colorize(str, White) end

  def bright_red(str);      colorize(str, [Bright, Red]) end
  def bright_green(str);    colorize(str, [Bright, Green]) end
  def bright_yellow(str);   colorize(str, [Bright, Yellow]) end
  def bright_blue(str);     colorize(str, [Bright, Blue]) end
  def bright_magenta(str);  colorize(str, [Bright, Magenta]) end
  def bright_cyan(str);     colorize(str, [Bright, Cyan]) end
  def bright_white(str);    colorize(str, [Bright, White]) end
  
  extend self
end # ANSI


module CullingStatsConstants
  PLAYER_SELF = :self
end # CullingStatsConstants


class CullingMatchStats
  include Enumerable

  attr_accessor :start_time, :end_time
  
  DamageRec = Struct.new(:tstamp, :inflictor, :receiver, :dmg, :annotation)
  
  def initialize(match_start_time)
    @start_time = match_start_time
    @damage_log = []
  end

  def each
    @damage_log.each {|rec| yield rec}
  end
  
  def log_damage(tstamp, inflictor, receiver, dmg, mystery, annotation)
    # puts "log_damage: #{[inflictor, receiver, dmg, annotation].inspect}"
    @damage_log << DamageRec.new(tstamp, inflictor, receiver, dmg, annotation)
  end
  
  def find_max_damage
    maxd = 0.0
    @damage_log.each do |rec|
      dmg = rec.dmg
      maxd = dmg if dmg > maxd
    end
    maxd
  end
end # CullingMatchStats


class CullingStats
  include Enumerable
  include CullingStatsConstants

  attr_reader :matches
  
  def initialize
    @matches = []
  end
  
  def each
    @matches.each {|match| yield match}
  end
  
  def new_match(tstamp)
    # puts "new match {"
    @matches << CullingMatchStats.new(tstamp)
  end
  
  def cur_match
    @matches.last
  end
  
  def end_match(tstamp)
    # puts "} end match"
    cur_match.end_time = tstamp
  end
  
  def log_damage(tstamp, inflictor, receiver, dmg, mystery, annotation)
    cur_match.log_damage(tstamp, inflictor, receiver, dmg, mystery, annotation)
  end
  
  def find_max_damage
    maxd = 0.0
    @matches.each do |match|
      dmg = match.find_max_damage
      maxd = dmg if dmg > maxd
    end
    maxd
  end
end # CullingStats


class CullingDamageLogParser
  attr_reader :last_tstamp

  def initialize(logger)
    @logger = logger
    @last_tstamp = Time.at(0).utc
    @parse_state = nil
    @stats = nil
  end
  
  def parse_damage_per_match(logpath)
    @stats = CullingStats.new
    self.parse_state = method(:st_find_match_start)
    IO.foreach(logpath) do |line|
      line.chomp!
      if line =~ %r{\A\[(\d{4})\.(\d\d)\.(\d\d)-(\d\d)\.(\d\d)\.(\d\d):(\d\d\d)\]\[[\s\d]+\](.*)\z}
        msg = $8
        year,month,day,hour,min,sec = $1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, "#$6.#$7".to_f
        tstamp = DateTime.new(year,month,day,hour,min,sec)
        parse_line(tstamp, msg)
        @last_tstamp = tstamp
      end
    end
    @stats
  end
  
  protected
  
  def parse_state=(parse_proc)
    @parse_state = parse_proc
  end
  
  def parse_line(tstamp, msg)
    @parse_state.call(tstamp, msg)
  end
  
  def st_find_match_start(tstamp, msg)
    # %r{\A(?:LogLoad: LoadMap: (?!CharacterSelect)|LogLevel: ActivateLevel|LogAudio:.*MatchStarted)}
    if msg =~ %r{\ALogLevel: ActivateLevel}
      # puts "match start: #{msg}"
      @stats.new_match(tstamp)
      self.parse_state = method(:st_accum_match_stats)
    end
  end
  
  def st_accum_match_stats(tstamp, msg)
    if msg =~ %r{\AVictoryDamage:Display: You Hit (.*?) for (\d+\.\d+) damage \((\d+\.\d+) m\)(?:\s+(.*))?}
      inflictor = CullingStats::PLAYER_SELF
      receiver = $1
      dmg = $2.to_f
      mystery = $3.to_f
      annotation = $4  # optional
      @stats.log_damage(tstamp, inflictor, receiver, dmg, mystery, annotation)
    elsif msg =~ %r{\AVictoryDamage:Display: Struck by (.*?) for (\d+\.\d+) damage \((\d+\.\d+) m\)(?:\s+(.*))?}
      inflictor = $1
      receiver = CullingStats::PLAYER_SELF
      dmg = $2.to_f
      mystery = $3.to_f
      annotation = $4  # optional
      @stats.log_damage(tstamp, inflictor, receiver, dmg, mystery, annotation)
    elsif msg =~ %r{\ALogLoad: LoadMap: CharacterSelect}
      @stats.end_match tstamp
      self.parse_state = method(:st_find_match_start)      
    end
  end
  
end # CullingDamageLogParser


class CullingDamageHTMLRenderer

  def initialize(logger)
    @logger = logger
  end

  def render(stats, outfile_path)
    max_dmg = stats.find_max_damage
    File.open(outfile_path, "wb") do |io|
      io.print html_doc_pre
      stats.each_with_index do |match, i|
        render_match(io, match, i, max_dmg)
      end
      io.print html_doc_post
    end
  end
  
  protected
  
  BAR_WIDTH_MAX = 600  # arbitrary
  SELF_COLOR = "57F"
  OPP_COLOR  = "F75"
  
  def render_match(io, match, i, max_dmg)
    match_start = match.start_time.strftime("%A %Y-%m-%d %H:%M:%S")
    io.print html_match_pre(match_start, i+1)
    render_match_rows(io, match, max_dmg)
    io.print html_match_post
  end
  
  def render_match_rows(io, match, max_dmg)
    epoch = Time.at(0).utc
    start_time = match.start_time
    damage_totals = Hash.new(0.0)
    match.each do |rec|
      event_time = rec.tstamp
      time_ofst = (event_time.to_time.to_f - start_time.to_time.to_f)
      event_time_str = (epoch + time_ofst).strftime("%H:%M:%S.%L")
      dmg_total = (damage_totals[rec.inflictor] += rec.dmg)
      io.puts html_match_row(rec, max_dmg, event_time_str, dmg_total)
    end
  end
  
  def html_match_row(rec, max_dmg, event_time_str, dmg_total)
    we_inflicted = (rec.inflictor == CullingStats::PLAYER_SELF)
    dmg_str = ("%4.2f" % [rec.dmg])
    ttl_str = ("(%4.2f)" % [dmg_total])
    bar_width_px = bar_dmg_to_width(max_dmg, rec.dmg)
    bar_color = (we_inflicted) ? SELF_COLOR : OPP_COLOR
    inflictor_esc  = CGI.escape_html(rec.inflictor.to_s)
    receiver_esc   = CGI.escape_html(rec.receiver.to_s)
    annotation_esc = CGI.escape_html(rec.annotation.to_s)
    if we_inflicted
      inf_class = "self"
      rec_class = "opp"
    else
      inf_class = "opp"
      rec_class = "self"
    end
    %{<tr><td class="time">#{event_time_str}</td><td class="#{inf_class}">#{inflictor_esc}</td><td class="#{rec_class}">#{receiver_esc}</td><td class="dmg #{inf_class}">#{dmg_str}</td ><td class="dmg #{inf_class}">#{ttl_str}</td><td><span class="bar" style="width:#{bar_width_px}px; background-color:##{bar_color}" >&nbsp;</span></td><td class="ann #{rec_class}">#{annotation_esc}</td></tr>}
  end
  
  def bar_dmg_to_width(max_dmg, dmg)
    BAR_WIDTH_MAX * (dmg / max_dmg)
  end
  
  def html_match_pre(match_start, match_num)
    <<ENDHTML
  <fieldset><legend><b>Match #{match_num} @ #{match_start}</b></legend>

    <table width="100%" border="0" cellspacing="2" cellpadding="0">
      <tr><th class="time">match clock</th><th>inflictor</th><th>receiver</th><th class="dmg">damage</th><th class="dmg">total</th><th><span class="bar" style="width:#{BAR_WIDTH_MAX}px" >&nbsp;</span></th><th class="ann">crit</th></tr>
ENDHTML
  end
  
  def html_match_post
    <<ENDHTML
    </table>
  </fieldset>
  <br />
  <br />
ENDHTML
  end
  
  def html_doc_pre
    <<ENDHTML
<html>
<head>
  <style>
body {
  background-color: #222222;
  color: white;
  margin: 0;
  margin-top: 64px;
  padding: 0;
  text-align: center;
  font-size: 80%;
  font-family: Verdana, Geneva, Arial, Helvetica, sans-serif;
  font-weight: normal;
}

td {
  text-align: left;
}

th {
  font-variant: small-caps;
  text-align: left;
}

input, textarea, select, option, button, .button, .checkbox {
  color: white;
  background-color: #e7f0f3;
}

fieldset {
  text-align: center;
  font-size: 150%;
}

fieldset, button, .button {
  padding: 2px;
  -webkit-border-radius: 1em;
  -khtml-border-radius: 1em;
  -moz-border-radius: 1em;
  -o-border-radius: 1em;
  border-radius: 1em;
}

th.dmg, td.dmg, th.ann, td.ann {
  text-align: right;
}

th.time {
  text-align: left;
}

td.time {
  font-family: monospace;
}

span.bar {
  display: inline-block;
  text-align: left;
}

td.self {
  color: ##{SELF_COLOR};
}

td.opp {
  color: ##{OPP_COLOR};
}
  </style>
</head>
<body>
ENDHTML
  end
  
  def html_doc_post
    <<ENDHTML
</body>
</html>
ENDHTML
  end
  
end # CullingDamageHTMLRenderer

def banner
  the_txt = <<'ENDTEXT'
    --.--|   |,---.
      |  |---||--- 
      |  |   ||    
      `  `   '`---'   
ENDTEXT

  culling_txt = <<'ENDTEXT'
   ____  _     _     _     _  _      _____
  /   _\/ \ /\/ \   / \   / \/ \  /|/  __/
  |  /  | | ||| |   | |   | || |\ ||| |  _
  |  \__| \_/|| |_/\| |_/\| || | \||| |_//
  \____/\____/\____/\____/\_/\_/  \|\____\
ENDTEXT

  the_txt.each_line {|line| puts ANSI.bright_white(line.chomp)}
  culling_txt.each_line {|line| puts ANSI.bright_red(line.chomp)}
  puts
  puts
  puts ANSI.bright_blue("     DAMAGE STATS PARSER / GRAPHER v#{PROG_VER}")
end

###############################################################################

begin
  logger = Logger.new

  banner
  puts
  puts
  
  logpath = File.join(ENV['LOCALAPPDATA'], "Victory/Saved/Logs/Victory.log")

  (test(?f, logpath)) or raise("Sorry, The Culling logfile not found at: #{logpath.inspect}")
  
  puts ANSI.yellow("Parsing log data...")
  
  parser = CullingDamageLogParser.new(logger)
  stats = parser.parse_damage_per_match(logpath)

  (stats.matches.empty?) and raise("Sorry, no match data found in The Culling logfile.")
  
  tmpdir = ((tmp = ENV['TEMP'].to_s).empty?) ? (ENV['TEMP']) : tmp
  tmpdir = tmpdir.tr("\\", "/")
  tstamp = parser.last_tstamp.strftime("%Y-%m-%d-%H-%M-%S")

  html_outfile = File.join(tmpdir, "culling-damage-#{tstamp}.html")

  puts
  puts ANSI.yellow("Rendering stats to HTML... [ #{html_outfile.inspect} ]")

  renderer = CullingDamageHTMLRenderer.new(logger)
  renderer.render(stats, html_outfile)

  puts
  puts ANSI.yellow("Sending HTML file to web browser...")
  sleep 1
  
  system("start", html_outfile) or raise("Failed to send stats HTML to web browser.")
  sleep 1
  
  puts
  puts ANSI.yellow("Exiting...")
  sleep 3
rescue Exception => ex
  $stderr.puts("\n\n" + ANSI.bright_red("ERROR: #{ex.message}"))
  $stderr.print("\npress <enter> to quit")
  gets
  raise
end
