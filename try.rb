# Malika Liyanage 101231500
require 'json'
require 'date'
require 'gosu'
require 'net/http'
require "open-uri"

##
# Contains common file operations
# which are used for this project
module JSONFileOperations
  ##
  # Clears the contents of a file
  #
  # @param [String] filename Name of the file to be cleared
  def clearFile(filename)
    # Removes any existing content in the file
    File.open(filename, "w").truncate(0)
  end

  ##
  # Appends data to a file. If the file already
  # exists in the system, its contents are cleared using the 
  # clearFile method
  #
  # @param [String] filename Name of the file
  # @param [Any]    data     Data to be written
  def updateFile(filename, data)
    # If the file already exists, its existing contents
    # are cleared
    if (File.exists?(filename))
      clearFile(filename)
    end

    File.open(filename,"a").write(data.to_json)
  end

  ##
  # Reads data from file.As this method will be mainly
  # used for reading from json file, only the first line needs
  # to be read
  #
  # @param [String]  filename Name of the file
  # @return [String] data in the file
  def readFromFile(filename)
    data = File.open(filename, "r").read
    return data
  end

end

##
# Handles all weather forecast related
# tasks. User location and weather forecast infromation
# fetching, updating and saving are handled by this class
class WeatherInformation
  include JSONFileOperations

  ##
  # Unique value provided by API service
  API_KEY = ""
  ##
  # URL for weather api call.
  # Documentation: https://openweathermap.org/current
  WEATHER_API_URL = "https://api.openweathermap.org/data/2.5/weather?lat=%{lat}&lon=%{lon}&appid=%{apiKey}"
  ##
  # Filename for weather information saving
  WEATHER_JSON_FILE_NAME = "forecast.json"
  ##
  # URL for ip location api call.
  # Documentation: https://freegeoip.app/
  LOCATION_API_URL = "https://freegeoip.app/json/"
  ##
  # File name for location information saving
  LOCATION_JSON_FILE_NAME = "location.json"
  ##
  # Time in milliseconds after which location information is considered to be
  # expired. Set to 10 minutes
  LOCATION_INFORMATION_EXPIRY_TIME_LIMIT = 600
  ##
  # Time in milliseconds after which weather information is considered to be
  # expired. Set to 60 minutes
  WEATHER_INFORMATION_EXPIRY_TIME_LIMIT = 3600
  ##
  # URL for the weather icon api call
  WEATHER_ICON_URL = "http://openweathermap.org/img/wn/%{symbolId}@2x.png"
  ## 
  # Name for the weather icon file
  WEATHER_ICON_NAME = "weather_symbol.png"

  attr_reader :userLocationInfo, :userWeatherInfo

  ##
  # Inits a Weather Information object
  def initialize
    ##
    # Stores the user's previous location
    # in the format of [latitude, longitude]
    @userPreviousLocation = Array.new(2)
    @locationChanged = false
    getUserLocation
    # If the location has changed then weather information is
    # updated as well, so it doesn't have to be called again. This
    # checks if the weather information has been updated already
    if (@userWeatherInfo.nil?)
      getUserWeather
    end
  end

  ##
  # Checks if the user location information should be updated.
  # This is done if
  #   (1) The user location information is nil
  #   (2) The location information has expired
  #
  # @return [Boolean] Returns true if location info should be updated else false
  def reupdateUserLocation?
    mustUpdate = true

    unless (@userLocationInfo.nil?)
      dateTimeNow = DateTime.iso8601(DateTime.now.to_s)
      # This is the datetime when the location information was last fetched
      fetchDateTime = DateTime.iso8601(@userLocationInfo["fetch_date_time"])

      # Gets the difference between the two datetimes in seconds
      timeDifferenceSeconds = ((dateTimeNow - fetchDateTime) * 24 * 60 * 60).to_i
      mustUpdate = timeDifferenceSeconds > LOCATION_INFORMATION_EXPIRY_TIME_LIMIT
    end

    return mustUpdate
  end

  ##
  # Fetches the user location from the api
  def getUserLocation
    checkLocationFile

    if (reupdateUserLocation?)
      # API call
      apiUri =  URI(LOCATION_API_URL)
      response = Net::HTTP.get(apiUri)

      # Gets the current datetime and merges it with response 
      fetchDateTimeInfo = {"fetch_date_time" => DateTime.now.iso8601(3).to_s}
      @userLocationInfo = JSON.parse(response)
      @userLocationInfo.merge!(fetchDateTimeInfo)

      # Saves the response in file
      updateFile(LOCATION_JSON_FILE_NAME, @userLocationInfo)

      if (userLocationChanged?)
        @locationChanged = true
        getUserWeather
        # Stores the current location values
        @userPreviousLocation[0] = @userLocationInfo["latitude"]
        @userPreviousLocation[1] = @userLocationInfo["longitude"]
        # Resets the flag
        @locationChanged = false
      end

    end

    return @userLocationInfo
  end

  ##
  # Checks if the user weather information should be updated.
  # This is done if
  #   (1) The user weather information is nil
  #   (2) The weather information has expired
  #   (3) The users location has changed
  #
  # @return [Boolean] Returns true if weather info should be updated else false
  def reupdateUserWeather?
    mustUpdate = true

    unless (@userWeatherInfo.nil? || @locationChanged)
      dateTimeNow = DateTime.iso8601(DateTime.now.to_s)
      # DateTime at which weather information was fetched
      fetchDateTime = DateTime.iso8601(@userWeatherInfo["fetch_date_time"])

      # Strips the minutes and seconds off the datetimes. This is done
      # as the hours are needed for comparison
      correctedDateTimeNow = DateTime.parse(dateTimeNow.strftime("%Y-%m-%dT%H:00:00%z"))
      correctedFetchDateTime = DateTime.parse(fetchDateTime.strftime("%Y-%m-%dT%H:00:00%z"))

      # Time difference between them in seconds
      timeDifferenceSeconds = ((correctedDateTimeNow - correctedFetchDateTime) * 24 * 60 * 60).to_i

      mustUpdate = timeDifferenceSeconds >= WEATHER_INFORMATION_EXPIRY_TIME_LIMIT
    end
    return mustUpdate
  end

  ##
  # Fetches the user weather from the api
  def getUserWeather
    checkWeatherFile

    if (reupdateUserWeather?)
      # Filling the values in the 
      # string template
      url = WEATHER_API_URL % {
        lat: @userLocationInfo["latitude"],
        lon: @userLocationInfo["longitude"],
        apiKey: API_KEY
      }
      # API call
      apiUri = URI(url)
      response = Net::HTTP.get(apiUri)

      # Gets the current datetime and merges it with response 
      @userWeatherInfo = JSON.parse(response)
      fetchDateTimeInfo = {"fetch_date_time" => DateTime.now.iso8601(3).to_s}
      @userWeatherInfo.merge!(fetchDateTimeInfo)

      # Saves response in file
      updateFile(WEATHER_JSON_FILE_NAME, @userWeatherInfo)

      # Downloads the neccessary weather icon
      downloadWeatherIcon
    end

    return @userWeatherInfo
  end

  private

  ##
  # This checks if the user's location has changed from 
  # the previously recorded location.
  #
  # @return [Boolean] True/False depending on location change
  def userLocationChanged?
    locationChanged = true
    unless (@userPreviousLocation[0].nil?)
        latitude = @userLocationInfo["latitude"]
        longitude = @userLocationInfo["longitude"]
        locationChanged = !(@userPreviousLocation[0] == latitude &&
          @userPreviousLocation[1] == longitude)
    end

    return locationChanged
  end

  ##
  # Checks if the location save file
  # exists and if it does loads its contents
  # to @userLocationInfo
  def checkLocationFile
    if (File.exists?(LOCATION_JSON_FILE_NAME))
      fileData = readFromFile(LOCATION_JSON_FILE_NAME)
      @userLocationInfo = JSON.parse(fileData)
      @userPreviousLocation[0] = @userLocationInfo["latitude"]
      @userPreviousLocation[1] = @userLocationInfo["longitude"]
    end
  end

  ##
  # Checks if the weather save file
  # exists and if it does loads its contents
  # to @userWeatherInfo
  def checkWeatherFile
    if (File.exists?(WEATHER_JSON_FILE_NAME))
      fileData = readFromFile(WEATHER_JSON_FILE_NAME)
      @userWeatherInfo = JSON.parse(fileData)
    end
  end

  ##
  # Downloads related weather icon from the
  # API and saves it in a png file
  def downloadWeatherIcon
    unless (@userWeatherInfo.nil?)
      # This is a id attached to the response from the api
      # The id corresponds to an image name in the api
      symbolId = @userWeatherInfo["weather"][0]["icon"]
      iconURL = WEATHER_ICON_URL % {
        symbolId: symbolId
      }

      # Downloads image and writes it to a file
      open(iconURL) do |image|
        File.open(WEATHER_ICON_NAME, "wb") do |file|
          file.write(image.read)
        end
      end
    end
  end

end

##
# Holds information regarding the z-order
# of elements in the Gosu Window
module ZOrder
  BACKGROUND, MIDDLE, TOP = *0..2
end

## 
# Handles the front end of the application.
# Makes use of a WeatherInformation class instance
# to get user forecast information, which is then displayed to 
# the user.
class ForecastApp < Gosu::Window
  ##
  # Window width of Weather App
  WIN_WIDTH = 640
  ##
  # Window height of Weather App
  WIN_HEIGHT = 480
  ##
  # Width of the toggle theme button
  BUTTON_WIDTH = 100
  ##
  # Height of the toggle theme button
  BUTTON_HEIGHT = 50

  ##
  # Inits the app
  def initialize
    super(WIN_WIDTH, WIN_HEIGHT, false)
    self.caption = "Weather Forecast"

    # Hash containing the colorschemes
    # Each color sheme has its values stored in 
    # a pair of 3 element integer array
    # This first array is used for holding the rgb values for the
    # background color, the second array for the font color
    @colorShemes = Hash[
      "dark" => [
        [46, 40, 42],
        [230, 230, 230]
      ],
      "light" => [
        [230, 230, 230],
        [46, 40, 42]
      ]
    ]
    @currentScheme = "dark"
    @background = Gosu::Color.rgb(
      @colorShemes[@currentScheme][0][0],
      @colorShemes[@currentScheme][0][1],
      @colorShemes[@currentScheme][0][2]
    )
    @uiFont = Gosu::Font.new(18)
    @primaryFontColor = Gosu::Color.rgb(
      @colorShemes[@currentScheme][1][0],
      @colorShemes[@currentScheme][1][1],
      @colorShemes[@currentScheme][1][2]
    )
    @buttonColor = Gosu::Color.rgb(255, 107, 107)

    # Used for different font levels
    @infoFontLevelOne = Gosu::Font.new(29)
    @infoFontLevelTwo = Gosu::Font.new(23)

    # Fetches location and weather information
    @currentWeatherInfo = WeatherInformation.new
    @weatherForecast = @currentWeatherInfo.userWeatherInfo
    @userLocation = currentLocationString
    @userWeatherMessage = currentWeatherMessage 
    @weatherIcon = Gosu::Image.new("weather_symbol.png")

    # Array containing the toggle theme
    # button starting coordinates
    @buttonCoord = [
      WIN_WIDTH - BUTTON_WIDTH - 10,
      10
    ]

    updateUserDateTime
  end

  def update
    Gosu.button_down? Gosu::KB_ESCAPE 
    Gosu.button_down? Gosu::MsLeft 
    updateUserDateTime

    # Checks if user location information should be 
    # updated
    if (@currentWeatherInfo.reupdateUserLocation?)
      puts "Updating User Location at #{@userTime} #{@userDate}"
      @currentWeatherInfo.getUserLocation
      @userLocation = currentLocationString
    end

    # Checks if the weather information should be updated
    if (@currentWeatherInfo.reupdateUserWeather?)
      puts "Updating Weather Information at #{@userTime} #{@userDate}"
      @weatherForecast = @currentWeatherInfo.getUserWeather
      @userWeatherMessage = currentWeatherMessage 
    end
  end

  def draw
    # Drawing Background
    Gosu.draw_rect(0, 0, WIN_WIDTH, WIN_HEIGHT, @background, ZOrder::BACKGROUND, mode=:default)
    # User Local Date
    @uiFont.draw_text("Date: #{@userDate}",10, 10, ZOrder::MIDDLE, 1.0, 1.0, @primaryFontColor)
    # Draws theme toggle button outline
    Gosu.draw_rect(
      @buttonCoord[0],
      @buttonCoord[1],
      BUTTON_WIDTH, 
      BUTTON_HEIGHT, 
      @buttonColor, 
      ZOrder::MIDDLE, 
      mode=:default
    )
    # Draws text for theme toggle button
    @uiFont.draw_text_rel(
      "Toggle",
      (WIN_WIDTH- BUTTON_WIDTH - 10) + BUTTON_WIDTH/ 2,
      (BUTTON_HEIGHT) /2 + 10, 
      ZOrder::TOP, 
      0.5,
      0.5,
      1.0, 
      1.0, 
      @primaryFontColor
    )
    # Draws user day of the week and local time
    @infoFontLevelTwo.draw_text_rel(
      "#{@userDay}, #{@userTime}", 
      WIN_WIDTH / 2, 
      WIN_HEIGHT / 2 - 110, 
      ZOrder::MIDDLE, 
      0.5, 
      0.5, 
      1.0, 
      1.0, 
      @primaryFontColor
    )
    # Draws Users Current Location Address
    @infoFontLevelOne.draw_text_rel(
      "#{@userLocation}", 
      WIN_WIDTH / 2, 
      WIN_HEIGHT / 2 - 80, 
      ZOrder::MIDDLE, 
      0.5, 
      0.5, 
      1.0, 
      1.0, 
      @primaryFontColor
    )
    # Draws the weather icon
    @weatherIcon.draw_rot(
      WIN_WIDTH / 2,
      WIN_HEIGHT / 2,
      ZOrder::MIDDLE,
      0,
      0.5,
      0.5,
      2,
      2
    )
    # Draws Current Forecast's Temperature
    @infoFontLevelOne.draw_text_rel(
      "#{convertToCelcius(@weatherForecast["main"]["temp"])}°C", 
      WIN_WIDTH / 2, 
      WIN_HEIGHT / 2 + 70, 
      ZOrder::MIDDLE, 
      0.5, 
      0.5, 
      1.0, 
      1.0, 
      @primaryFontColor
    )
    # Draws the weather message
    @infoFontLevelTwo.draw_text_rel(
      "#{@userWeatherMessage}", 
      WIN_WIDTH / 2, 
      WIN_HEIGHT / 2 + 100, 
      ZOrder::MIDDLE, 
      0.5, 
      0.5, 
      1.0, 
      1.0, 
      @primaryFontColor
    )
    # Draws forecast humidity
    @uiFont.draw_text(
      "Humidity: #{@weatherForecast["main"]["humidity"]}%", 
      10, 
      WIN_HEIGHT - 30, 
      ZOrder::MIDDLE, 
      1.0, 
      1.0, 
      @primaryFontColor
    )
    # Draws forecast wind speed
    @uiFont.draw_text_rel(
      "Wind: #{@weatherForecast["wind"]["speed"]}m/s", 
      WIN_WIDTH / 2, 
      WIN_HEIGHT - 30, 
      ZOrder::MIDDLE, 
      0.5, 
      0.0, 
      1.0, 
      1.0, 
      @primaryFontColor
    )
    # Draws forecast pressure
    @uiFont.draw_text_rel(
      "Pressure: #{@weatherForecast["main"]["pressure"]}hPa", 
      WIN_WIDTH - 10, 
      WIN_HEIGHT - 30, 
      ZOrder::MIDDLE, 
      1.0,
      0.0,
      1.0, 
      1.0, 
      @primaryFontColor
    )
  end

  private

  ##
  # Adds cursor to window
  def needs_cursor?
    true
  end

  ##
  # Updates the app datetime to user local datetime.
  # Updates the following attributes.
  #   @userTime - current local time in Hour:Minute:Second format
  #   @userDate - current local date in Year-Month-Date format
  #   @userDay  - current day of the week
  def updateUserDateTime
    today = DateTime.now
    @userTime = today.strftime("%H:%M:%S")
    @userDate = today.strftime("%F")
    @userDay = today.strftime("%A")
  end
  
  ##
  # Returns the description in the api response,
  # capitalizes it as well.
  #
  # @return [String] Capitalized version of the description
  def currentWeatherMessage
    return @weatherForecast["weather"][0]["description"].split.map(&:capitalize)*' '
  end
  
  ##
  # Returns a string containing the users location.
  # Its in the format
  #   City Region, Country
  # 
  # @return [String] User's current location
  def currentLocationString
    locationInfo = @currentWeatherInfo.userLocationInfo
    return "#{locationInfo["city"]} #{locationInfo["region_name"]}, #{locationInfo["country_name"]}"
  end

  ## 
  # Converts temperature from Kelvin to Celcius.
  #
  # @return [Float] Temperature in Celcius rouned to 1dp
  def convertToCelcius(temperature)
    return (temperature - 273.15).round(1)
  end

  ##
  # Checks if a button has been pressed.
  # Reused from weekly tasks
  def button_down(id)
    case id
    when Gosu::KB_ESCAPE
      close
    when Gosu::MsLeft
      if (mouse_over_button?(mouse_x, mouse_y))
        toggleTheme
      end
    else
      super
    end
  end

  ## 
  # Checks if the mouse cursor is over the theme toggle button
  # 
  # @return [Boolean] True/False depending on whether the cursor is over the
  # button
  def mouse_over_button?(mouse_x, mouse_y)
    if (mouse_x > @buttonCoord[0] && mouse_x < @buttonCoord[0] + BUTTON_WIDTH) && 
        (mouse_y > @buttonCoord[1] && mouse_y < @buttonCoord[1] + BUTTON_HEIGHT)
      true
    else
      false
    end
  end

  ## 
  # Toggles the colorsheme between light/dark
  def toggleTheme
    @currentScheme == "dark" ? @currentScheme = "light" : @currentScheme = "dark"

    # Updating the current background and font colors
    # with the new theme
    @background = Gosu::Color.rgb(
      @colorShemes[@currentScheme][0][0],
      @colorShemes[@currentScheme][0][1],
      @colorShemes[@currentScheme][0][2]
    )
    @uiFont = Gosu::Font.new(18)
    @primaryFontColor = Gosu::Color.rgb(
      @colorShemes[@currentScheme][1][0],
      @colorShemes[@currentScheme][1][1],
      @colorShemes[@currentScheme][1][2]
    )
  end

end

window = ForecastApp.new
window.show