#  Phusion Passenger - http://www.modrails.com/
#  Copyright (C) 2010  Phusion
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; version 2 of the License.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

desc "Run 'sloccount' to see how much code Passenger has"
task :sloccount do
	ENV['LC_ALL'] = 'C'
	begin
		# sloccount doesn't recognize the scripts in
		# bin/ as Ruby, so we make symlinks with proper
		# extensions.
		tmpdir = ".sloccount"
		system "rm -rf #{tmpdir}"
		mkdir tmpdir
		Dir['bin/*'].each do |file|
			safe_ln file, "#{tmpdir}/#{File.basename(file)}.rb"
		end
		sh "sloccount", *Dir[
			"#{tmpdir}/*",
			"lib/phusion_passenger",
			"ext/apache2",
			"ext/nginx",
			"ext/common",
			"ext/oxt",
			"ext/phusion_passenger/*.c",
			"test/**/*.{cpp,rb,h}"
		]
	ensure
		system "rm -rf #{tmpdir}"
	end
end

desc "Convert the NEWS items for the latest release to HTML"
task :news_as_html do
	# The text is in the following format:
	#
	#   Release x.x.x
	#   -------------
	#
	#    * Text.
	#    * More text.
	# * A header.
	#      With yet more text.
	#   
	#   Release y.y.y
	#   -------------
	#   .....
	require 'cgi'
	contents = File.read("NEWS")
	
	# We're only interested in the latest release, so extract the text for that.
	contents =~ /\A(Release.*?)^(Release|Older releases)/m
	
	# Now split the text into individual items.
	items = $1.split(/^ \*/)
	items.shift  # Delete the 'Release x.x.x' header.
	
	puts "<dl>"
	items.each do |item|
		item.strip!
		
		# Does this item have a header? It does if it consists of multiple lines, and
		# the next line is capitalized.
		lines = item.split("\n")
		if lines.size > 1 && lines[1].strip[0..0] == lines[1].strip[0..0].upcase
			puts "<dt>#{lines[0]}</dt>"
			lines.shift
			item = lines.join("\n")
			item.strip!
		end
		
		# Split into paragraphs. Empty lines are paragraph dividers.
		paragraphs = item.split(/^ *$/m)
		
		def format_paragraph(text)
			# Get rid of newlines: convert them into spaces.
			text.gsub!("\n", ' ')
			while text.index('  ')
				text.gsub!('  ', ' ')
			end
			
			# Auto-link to issue tracker.
			text.gsub!(/(bug|issue) #(\d+)/i) do
				url = "http://code.google.com/p/phusion-passenger/issues/detail?id=#{$2}"
				%Q(<{a href="#{url}"}>#{$1} ##{$2}<{/a}>)
			end
			
			text.strip!
			text = CGI.escapeHTML(text)
			text.gsub!(%r(&lt;\{(.*?)\}&gt;(.*?)&lt;\{/(.*?)\}&gt;)) do
				"<#{CGI.unescapeHTML $1}>#{$2}</#{CGI.unescapeHTML $3}>"
			end
			text
		end
		
		if paragraphs.size > 1
			STDOUT.write("<dd>")
			paragraphs.each do |paragraph|
				paragraph.gsub!(/\A\n+/, '')
				paragraph.gsub!(/\n+\Z/, '')
				
				if (paragraph =~ /\A       /)
					# Looks like a code block.
					paragraph.gsub!(/^       /m, '')
					puts "<pre lang=\"ruby\">#{CGI.escapeHTML(paragraph)}</pre>"
				else
					puts "<p>#{format_paragraph(paragraph)}</p>"
				end
			end
			STDOUT.write("</dd>\n")
		else
			puts "<dd>#{format_paragraph(item)}</dd>"
		end
	end
	puts "</dl>"
end

task :compile_app => [LIBCOMMON, LIBBOOST_OXT, :libev] do
	source = ENV['SOURCE'] || ENV['FILE'] || ENV['F']
	if !source
		STDERR.puts "Please specify the source filename with SOURCE=(...)"
		exit 1
	end
	exe    = source.sub(/\.cpp$/, '')
	create_executable(exe, source,
		"-Iext -Iext/common #{LIBEV_CFLAGS} " <<
		"#{PlatformInfo.portability_cflags} " <<
		"#{EXTRA_CXXFLAGS} " <<
		"#{LIBCOMMON} " <<
		"#{LIBBOOST_OXT} " <<
		"#{LIBEV_LIBS} " <<
		"#{PlatformInfo.portability_ldflags} " <<
		"#{EXTRA_LDFLAGS}")
end