require 'readline'
require 'net-telnet'
require 'json'
require 'pry-byebug'

class Player
  def initialize(socket)
    @socket = socket
    @socket.gets # consume banner
  end

  def command(com)
    @socket.puts com

    JSON.parse @socket.gets
  end

  def evaluate(line)
    #dispatcher
    number =  ->(l){ l.to_i.nonzero? }

    case line
    when number
      _play line
      status
    when 'exit', 'x'
      raise Interrupt
    when 'p'
      command('play') # also pause?
      status
    when 'stop'
      command('stop')
      status
    when 'f'
      find
    when '', 'play'
      play
      status
    when 'ls'
      ls
    when 'j', 'next'
      command('next')
      status
    when 'k', 'prev'
      command('prev')
      status
    when 'help'
      help
    when 's', 'status'
      status
    else
      puts 'Unknown command'
    end
  end

  def fetch_playlists
    command('ls')['playlists']
  end

  def _play(index)
    command("goto #{index}")
  end

  def play
    playlists = fetch_playlists.reject { |p| p.empty? || p['name']&.empty? }.map do |playlist|
      "#{playlist['index']}. #{playlist['name']}"
    end

    selection = IO.popen('fzf --reverse', 'r+') do |f|
      f.puts playlists
      f.readlines.map(&:chomp)
    end&.first&.split('.')&.first

    command("play #{selection}") if selection
  end

  def find
    queue = command('qls')['tracks']
    songs = queue.map do |song|
      "#{song['index']}. #{song['title']} - #{song['artist']} (#{song['album']})"
    end

    selection = IO.popen('fzf --reverse', 'r+') do |f|
      f.puts songs
      f.readlines.map(&:chomp)
    end.first

    song_index = selection.split('.').first
    puts song_index
  end

  def ls
    fetch_playlists.each do |playlist|
      puts "#{playlist['index']} - #{playlist['name']}"
    end
  end

  def status
    queue = command('qls')['tracks']
    current = command('status')
    puts '-' * 80
    puts 'Currently playing:'
    puts "#{current['album']} - #{current['artist']}"
    puts

    queue.each do |track|
      marker =
        if track['index'] == current['current_track']
          '=>'
        else
          '  '
        end

      puts "#{marker} #{track['index']}. #{track['title']} - #{track['artist']} (#{track['album']})"
    end
    puts '-' * 80
  end

  def help
  end
end

running = true

Signal.trap('INT') { running = false }
Signal.trap('TERM') { running = false }

socket = TCPSocket.new '192.168.0.100', 6602

player = Player.new(socket)

player.status
while running && line = Readline.readline('cmd> ', true)
  begin
    player.evaluate line
  rescue Interrupt
    running = false
  end
end

puts 'Byez :('
