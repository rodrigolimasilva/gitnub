$VERBOSE = nil
require 'rubygems'
require 'pathname'
require 'osx/cocoa'


# Do some mangling to the load order so grit will use our bundled 
# items instead of the gem versions.
#
libdir = OSX::NSBundle.mainBundle.resourcePath.stringByAppendingPathComponent("lib").fileSystemRepresentation
$:.unshift(libdir, "#{libdir}/grit/lib", "#{libdir}/mime-types/lib", "#{libdir}/open4/lib", "#{libdir}/diff-lcs/lib")

require 'grit'

# Require some core extensions
#
require 'time_extensions'
require 'string_extensions'
require 'osx_notify'

# Custom gravatar cell support
#
OSX.ns_import 'CommitSummaryCell'
include OSX

# we use ENV['PWD'] instead of Dir.getwd if it exists so
# `open GitNub` will work, since that launches us at / but leaves ENV['PWD'] intact
#
pwd = Pathname.new(ENV['PWD'].nil? ? Dir.getwd : ENV['PWD'])
REPOSITORY_LOCATION = pwd + `cd #{pwd} && git rev-parse --git-dir 2>/dev/null`.chomp
