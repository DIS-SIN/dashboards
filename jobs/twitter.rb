require "twitter"
require "cgi"
require "json"

#### Get your twitter keys & secrets:
#### https://dev.twitter.com/docs/auth/tokens-devtwittercom
twitter_json = File.read("./jobs/keys/twitter.json")
twitter_config = JSON.parse(twitter_json)

twitter = Twitter::REST::Client.new do |config|
  config.consumer_key = twitter_config["consumer_key"]
  config.consumer_secret = twitter_config["consumer_secret"]
  config.access_token = twitter_config["access_token"]
  config.access_token_secret = twitter_config["token_secret"]
end

# Read a file with a json array of 'search_terms'
# These terms can be hashtags, usernames, or anything else
# that the twitter API supports searching by
# 
# params:
#   file_name - the file to look for in the twitter resource folder
def read_search_term_file(file_name)
  file = File.open "jobs/twitter_resources/#{file_name}.json"
  data = JSON.load file
  file.close
  return data["search_terms"]
end

# Given a search term file, construct a string to
# send to the twitter search API from the file
# 
# params:
#   file_name - the file to look for in the twitter resource folder
def get_search_string(file_name)
  element_count = 25
  # get the data from the json file, returning the field search terms
  json_data = read_search_term_file(file_name)

  # calc the initial size to allocate for search string, 16 times the number of elements
  size = 16*element_count
  search_string = String.new(str="", capacity: size)

  # get element_count number of random elements from the data then
  # concat each element together into large search string
  json_data.sample(element_count).each do |search_term|
    search_string << + CGI.escape(search_term) << "+OR+"
  end

  return search_string
end

# When given an array of tweets from the twitter API
# read each tweet (differently for normal tweets or retweets) and
# update the array with our relevent information
#
# params
#   tweets - response from twitter api search, an array of tweets
def parse_twitter_api_response(tweets)
  tweets = tweets.map do |tweet|
    if tweet.attrs[:retweeted_status] then
      { created_at: tweet.created_at.getlocal.strftime("%l:%M%p - %b %e, %Y"), name: tweet.user.name, body: "Retweet: " << CGI.unescapeHTML(tweet.attrs[:retweeted_status][:full_text]), avatar: tweet.user.profile_image_url_https, screen_name: "@" + tweet.user.screen_name}
    else
      { created_at: tweet.created_at.getlocal.strftime("%l:%M%p - %b %e, %Y"), name: tweet.user.name, body: CGI.unescapeHTML(tweet.attrs[:full_text]), avatar: tweet.user.profile_image_url_https, screen_name: "@" + tweet.user.screen_name }
    end
  end

  return tweets
end

begin
  # Schedule retreiving tweets from the twitter API
  SCHEDULER.every "5m", :first_in => 0 do |job|

    ###### Begin retreiving hashtags ######
    # initial attempt at retreiving tweets
    tweets_hashtags = twitter.search(get_search_string("hashtag_search_terms"), options={tweet_mode: "extended"}).take(25)
    
    # if the number of tweets is 0, retry
    breakout_counter = 0 # breakout counter to prevent looping forever, if we get timed out or the API has an issue
    while tweets_hashtags.count < 1
      tweets_hashtags = twitter.search(get_search_string("hashtag_search_terms"), options={tweet_mode: "extended"}).take(25)  

      breakout_counter = breakout_counter + 1
      if breakout_counter == 5 then
          break
      end
    end

    if tweets_hashtags then
      # decontruct the twitter response, keeping what data we need
      parsed_hashtag_tweets = parse_twitter_api_response(tweets_hashtags)

      puts "Hashtag Search Successful. Tweets detecting. Sending event. (twitter.rb)"
      send_event("twitter_hashtag_terms", comments: parsed_hashtag_tweets)
    else
      print "\e[33mNo Tweets Found by the Twitter Widget. Ensure your search term in twitter.rb is correct.\e[0m"
    end
    ###### End retreiving hashtags ######

    ###### Begin retreiving DigiAcademyCAN and AcademieNumCAN tweets ######
    # initial attempt at retreiving tweets
    tweets_digiacad_en = twitter.search("from:DigiAcademyCAN", options={tweet_mode: "extended", result_type: "recent"}).take(3)
    tweets_digiacad_fr = twitter.search("from:AcademieNumCAN", options={tweet_mode: "extended", result_type: "recent"}).take(3)

    # if the number of english tweets is 0, retry
    breakout_counter = 0 # breakout counter to prevent looping forever, if we get timed out or the API has an issue
    while tweets_digiacad_en.count < 2
      tweets_digiacad_en = twitter.search("from:DigiAcademyCAN", options={tweet_mode: "extended", result_type: "recent"}).take(3)

      breakout_counter = breakout_counter + 1
      if breakout_counter == 5 then
          break
      end
    end
    
    # if the number of english tweets is 0, retry
    breakout_counter = 0 # breakout counter to prevent looping forever, if we get timed out or the API has an issue
    while tweets_digiacad_fr.count < 2
      tweets_digiacad_fr = twitter.search("from:AcademieNumCAN", options={tweet_mode: "extended", result_type: "recent"}).take(3)

      breakout_counter = breakout_counter + 1
      if breakout_counter == 5 then
          break
      end
    end

    if tweets_digiacad_fr && tweets_digiacad_en then
      # decontruct the twitter response, keeping what data we need
      parsed_en_tweets = parse_twitter_api_response(tweets_digiacad_en)
      parsed_fr_tweets = parse_twitter_api_response(tweets_digiacad_fr)
    
      puts "DigitalAcademy Search Successful. Tweets detecting. Sending event. (twitter.rb)"
      send_event("twitter_digiacad_en", comments: parsed_en_tweets)
      send_event("twitter_digiacad_fr", comments: parsed_fr_tweets)
    else
      print "\e[33mNo Tweets Found by the Twitter Widget. Ensure your search term in twitter.rb is correct.\e[0m"
    end
    ###### End retreiving user tweets ######
  end

rescue Twitter::Error
  puts "\e[33mFor the twitter widget to work, you need to put in your twitter API keys in the jobs/twitter.rb file.\e[0m"
end

