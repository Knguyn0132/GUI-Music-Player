require 'rubygems'
require 'gosu'
require './input_functions'

TOP_COLOR = Gosu::Color.new(0xFF1EB1FA)	#lighter blue
BOTTOM_COLOR = Gosu::Color.new(0xFF1D4DB5) #blue
TRACKS_POSITION = 550
WIDTH = 800
HEIGHT = 600
module ZOrder
  BACKGROUND, PLAYER, UI = *0..2
end

module Genre
  POP, CLASSIC, JAZZ, ROCK = *1..4
end

GENRE_NAMES = ['Null', 'Pop', 'Classic', 'Jazz', 'Rock']

class ArtWork
	attr_accessor :bmp, :dim
	def initialize(file, leftX, topY)
		@bmp = Gosu::Image.new(file) # takes the file path as an argument and loads the image data from that file. The resulting Gosu::Image object is then assigned to the @bmp instance variable.
		@dim = Dimension.new(leftX, topY, leftX + @bmp.width(), topY + @bmp.height())
	end
end

# Put your record definitions here
class Album 

	attr_accessor :title, :artist, :artwork, :tracks
	def initialize (title, artist, artwork, tracks)
		@title = title
		@artist = artist
		@artwork = artwork
		@tracks = tracks
	end
end


class Track
	attr_accessor :name, :location, :dim
	def initialize(name, location, dim)
		@name = name
		@location = location
		@dim = dim
	end
	
end

class Dimension
	attr_accessor :leftX, :topY, :rightX, :bottomY
	def initialize(leftX, topY, rightX, bottomY)
		@leftX = leftX
		@topY = topY
		@rightX = rightX
		@bottomY = bottomY
	end
end




class MusicPlayerMain < Gosu::Window

	def initialize
	    super WIDTH, HEIGHT, false
	    self.caption = "Music Player"
	    @background = BOTTOM_COLOR
			@player = TOP_COLOR
			@track_font = Gosu::Font.new(30)
			@albums = read_albums()
		# Reads in an array of albums from a file and then prints all the albums in the
		# array to the terminal
		####
			@album_playing = -1
	    @track_playing = -1
		####
	end

  # Put in your code here to load albums and tracks
  def read_track(a_file, index)
  		name = a_file.gets.chomp
  		location = a_file.gets.chomp

  		leftX = TRACKS_POSITION
			topY = 40 * index + 100
			rightX = leftX + @track_font.text_width(name)
			bottomY = topY + @track_font.height()
			dim = Dimension.new(leftX, topY, rightX, bottomY)
			
			track = Track.new(name, location, dim)
			return track
  end

  def read_tracks(a_file)
		count = a_file.gets.chomp.to_i
		tracks = Array.new()
	
		i = 0
		while i < count
			track = read_track(a_file, i)
			tracks << track
			i += 1
		end
		
		return tracks
	end


	def read_album(a_file, i)
		title = a_file.gets.chomp
		artist = a_file.gets.chomp
		# --- Dimension of an album's artwork ---
		if i % 2 == 0
			leftX = 30
		else
			leftX = 250
		end
		topY = 190 * (i / 2) + 30 + 20 * (i/2)
		artwork = ArtWork.new(a_file.gets.chomp, leftX, topY)
		# -------------------------------------
		tracks = read_tracks(a_file)
		album = Album.new(title, artist, artwork, tracks)
		return album
	end

	def read_albums()
		a_file = File.new("albums.txt", "r")
		count = a_file.gets.chomp.to_i
		albums = Array.new()

		i = 0
		while i < count
			album = read_album(a_file, i)
			albums << album
			i += 1
	  	end

		a_file.close()
		return albums
	end

  # Draws the artwork on the screen for all the albums

  def draw_albums (albums)
    # complete this code
    ####
    i = 0
	  while i < albums.length
	    album = albums[i]
	    album.artwork.bmp.draw(album.artwork.dim.leftX, album.artwork.dim.topY, z = ZOrder::PLAYER) # draw method is indeed part of the Gosu library and specifically belongs to the Gosu::Image class. 
	    i += 1
	  end
		####
  end

  def draw_tracks(album)
  	i = 0
	  while i < album.tracks.length
	    track = album.tracks[i]
	    display_track(track)
	    i += 1
	  end
	end

	# Takes a String title and an Integer ypos
  # You may want to use the following:
  def display_track(track)
  	@track_font.draw(track.name, TRACKS_POSITION, track.dim.topY, ZOrder::PLAYER, 1.0, 1.0, Gosu::Color::BLACK)
  end

	def draw_current_playing(i, album)
		Gosu.draw_rect(album.tracks[i].dim.leftX - 15, album.tracks[i].dim.topY, 5, @track_font.height(), Gosu::Color::YELLOW, z = ZOrder::PLAYER)
	end

  # Detects if a 'mouse sensitive' area has been clicked on
  # i.e either an album or a track. returns true or false

  def area_clicked(leftX, topY, rightX, bottomY)
     # complete this code
    if mouse_x > leftX && mouse_x < rightX && mouse_y > topY && mouse_y < bottomY
			return true
		end
		return false
  end


  


  # Takes a track index and an Album and plays the Track from the Album

  def playTrack(track, album)
  	 # complete the missing code
  			@song = Gosu::Song.new(album.tracks[track].location)
  			@song.play(false)
  			#not loop
    # Uncomment the following and indent correctly:
  	#	end
  	# end
  end

# Draw a coloured background using TOP_COLOR and BOTTOM_COLOR

	def draw_background
				draw_quad(0,0, TOP_COLOR, 0, HEIGHT, TOP_COLOR, WIDTH, 0, BOTTOM_COLOR, WIDTH, HEIGHT, BOTTOM_COLOR, z = ZOrder::BACKGROUND)
	end

# Not used? Everything depends on mouse actions.

	def update
		if @album_playing >= 0 && @song == nil
			@track_playing = 0
			playTrack(0, @albums[@album_playing])
		end
		
		# If an album has been selecting, play all songs in turn
		if @album_playing >= 0 && @song != nil && (not @song.playing?) #check if current song has finished playing
			@track_playing = (@track_playing + 1) % @albums[@album_playing].tracks.length() #get the remainder after the division
			playTrack(@track_playing, @albums[@album_playing])
		end
	end

 # Draws the album images and the track list for the selected album

	def draw
		# Complete the missing code
		draw_background()
		draw_albums(@albums)
		# If an album is selected => display its tracks
		if @album_playing >= 0
			draw_tracks(@albums[@album_playing])
			draw_current_playing(@track_playing, @albums[@album_playing])
		end
	end

 	def needs_cursor?; true; end

	# If the button area (rectangle) has been clicked on change the background color
	# also store the mouse_x and mouse_y attributes that we 'inherit' from Gosu
	# you will learn about inheritance in the OOP unit - for now just accept that
	# these are available and filled with the latest x and y locations of the mouse click.

	def button_down(id)
		case id
	    when Gosu::MsLeft
	    	# What should happen here?
	    	##########
	    	if @album_playing >= 0
		    	# --- Check which track was clicked on ---
		    	for i in 0..@albums[@album_playing].tracks.length() - 1
			    	if area_clicked(@albums[@album_playing].tracks[i].dim.leftX, @albums[@album_playing].tracks[i].dim.topY, @albums[@album_playing].tracks[i].dim.rightX, @albums[@album_playing].tracks[i].dim.bottomY)
			    		playTrack(i, @albums[@album_playing])
			    		@track_playing = i #update the track playing
			    		break
			    	end
			    end
				end

			# --- Check which album was clicked on ---
				for i in 0..@albums.length() - 1
					if area_clicked(@albums[i].artwork.dim.leftX, @albums[i].artwork.dim.topY, @albums[i].artwork.dim.rightX, @albums[i].artwork.dim.bottomY)
					@album_playing = i #update album
					@song = nil #set song to new so it plays the first track
					break
					end
				end
	    
	    end
		end

	end

# Show is a method that loops through update and draw

MusicPlayerMain.new.show if __FILE__ == $0