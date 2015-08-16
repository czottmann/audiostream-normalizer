#!/Users/carlo/.rubies/ruby-2.2.0/bin/ruby

require "optparse"
require "fileutils"


options = {
  :ext_prefix => ".vol"
}

OptionParser.new do |opts|
  opts.banner = "Usage: normalizer.rb [options]"

  opts.on("-fFILE", "--file FILE", "File(s) to normalize (glob allowed!)") do |o|
    options[:files] = o
  end

  opts.on("-ePREFIX", "--ext PREFIX", "File extension prefix for processed file (default: .vol, e.g. video.mkv ➔ video.vol.mkv)") do |o|
    options[:ext_prefix] = o
  end

  opts.on("-mFOLDER", "--move FOLDER", "Folder to move original files to after processing") do |o|
    options[:target_folder] = File.expand_path(o)
  end

  opts.on("-gGAIN", "--gain GAIN", "Gain in dB to apply on top of automatic normalizing (optional)") do |o|
    options[:gain] = o
  end

  opts.on("-h", "--help", "Prints this help") do
    puts <<EOTXT
This script automates the audio normalization of any given video file.

Pass in a file name (a glob pattern will work as well), the script will first
get the maximum volume using ffmpeg, then change the it to be 0.0 dB.  If an
optional gain is specified, it will be applied.

The new video file is then saved with a new file extension (prefixed with '.vol'
by default, e.g. 'video.mkv' will become 'video.vol.mkv'), and the original file
is moved to another folder, so only the processed file will remain in the source
folder.

EOTXT

    puts opts
    exit
  end
end.parse!


def exit_with_error(msg)
  puts "ERROR: #{msg}, exiting!"
  exit 1
end


exit_with_error("ffmpeg couldn't be found") if `which ffmpeg` == ""
exit_with_error("No file name provided") if options[:files] == nil || options[:files].empty?
exit_with_error("Extension prefix must not be empty") if options[:ext_prefix].empty?
exit_with_error("Target must not be empty") if options[:target_folder] == nil || options[:target_folder].empty?
exit_with_error("No target folder name provided") if options[:target_folder] == nil || options[:target_folder].empty?
exit_with_error("Target folder doesn't exist") unless Dir.exist?(options[:target_folder])


################################################################################

files = Dir.glob(File.expand_path(options[:files])).sort
num_files = files.size
gain = options[:gain].to_f

files.each_with_index do |filename, idx|
  current_index = idx + 1
  puts "[#{current_index}/#{num_files}] Working #{filename}…"

  unless File.exist?(filename)
    puts "- ERROR: File doesn't exist, exiting! (#{filename})"
    exit 1
  end

  puts "- Analyzing…"

  output = `ffmpeg -i "#{filename}" -af 'volumedetect' -f null /dev/null 2>&1`
  max_volume = /max_volume: (.*) dB/.match(output)[1].to_f

  puts "  - max volume: #{max_volume} dB"

  if max_volume == 0 && gain == 0
    puts "- Nothing to do, skipping!"
    next
  end

  puts "- Processing…"

  new_volume = max_volume * -1 + gain
  puts "  - new volume: #{new_volume} dB"

  new_filename = filename.gsub(/(\.[^\.]+)$/, options[:ext_prefix] + '\1')
  puts "  - new filename: #{new_filename}"

  output = `ffmpeg -i "#{filename}" -vcodec copy -af "volume=#{new_volume}dB" "#{new_filename}" 2>&1`

  puts "  - new volume set"
  FileUtils.move(filename, options[:target_folder])
  puts "  - original file was moved to #{options[:target_folder]}"
  puts
end
