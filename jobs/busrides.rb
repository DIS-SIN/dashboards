require 'date'
require 'google/apis/analytics_v3'
require 'json'

max_amount = 100
visitors = 0

# Update these to match your own apps credentials
key_file = "./jobs/keys/busrides-analytics-e3ff89f459a1.json" # File containing your private key
profile_id = "203959040" # Analytics profile ID.

Analytics = Google::Apis::AnalyticsV3
service = Analytics::AnalyticsService.new

def getCredentials(service, key_file)

  # Open Google credentials json
  google_json = File.open(key_file)

  # Authorize with Google
  scope = ['https://www.googleapis.com/auth/analytics.readonly']
  service.authorization = Google::Auth::ServiceAccountCredentials.make_creds(json_key_io: google_json, scope: scope)

  # Close Google credentials json
  google_json.close
  return service
end


# Start the scheduler
SCHEDULER.every '10s', :first_in => 0 do

  # Request a token for our service account
  analytics = getCredentials(service, key_file)

  # Get the analytics API
  realtime_response = analytics.get_realtime_data("ga:" + profile_id, "ga:activeVisitors")

  visitors = realtime_response.totals_for_all_results["ga:activeVisitors"]
  send_event('visitor_count_real_time', current: visitors )

  
end

SCHEDULER.every '12h', :first_in => 0 do
  analytics = getCredentials(service, key_file)

  ga_response = analytics.get_ga_data("ga:" + profile_id, "7daysAgo", "yesterday","ga:users,ga:newUsers")

  users = ga_response.rows[0][0]
  newUsers = ga_response.rows[0][1]
  returnUsers = users.to_i - newUsers.to_i

  send_event('busrides_users', current: users)
  send_event('busrides_newUsers', current: newUsers)
  send_event('busrides_returnUsers', current: returnUsers)
end

SCHEDULER.every '12h', :first_in => 0 do

  analytics = getCredentials(service, key_file)
  ## Start and end dates
  startDate = DateTime.now - 30
  startDate = startDate.strftime("%Y-%m-%d")
  endDate = DateTime.now.strftime("%Y-%m-%d")

  # Get Google Analytics data for total visitors
  # Note the trailing to_i - See: https://github.com/Shopify/dashing/issues/33
  visitors_last_month = analytics.get_ga_data("ga:" + profile_id, startDate,endDate, "ga:visitors").rows[0][0].to_i

  # Update the dashboard
  send_event("visitor_count",   { current: visitors_last_month })


  # Get the Google Analytics data for top pages in the last month
  top_pages_monthly = analytics.get_ga_data("ga:" + profile_id, 
    startDate,
    endDate,
    "ga:pageviews",
    sort:"-ga:pageviews",
    dimensions: "ga:pagePath",
    filters: "ga:pagePath=@/en/ep-,ga:pagePath=@/fr/ep-", #,ga:pagePath=@\\fr\\ep-
    max_results: 5
  )

  top_episodes = []
  # for each of the pages that were in the top
  # read the pagePath (from GA) and remove the 
  top_pages_monthly.rows.each do |row|
    if row[0].include?("/en/ep-") then
      item = row[0].gsub("/en/ep-","")
      item = item.gsub("-en/","")
      top_episodes << { 'label' =>  "Episode " + item}
    elsif row[0].include?("/fr/ep-") then
      item = row[0].gsub("/fr/ep-","")
      item = item.gsub("-fr/","")
      top_episodes << { 'label' =>  "Episode " + item}
    else
      top_episodes << { 'label' =>  item}
    end

    puts "Busride analytics data read succesfully. Sending event. (busrides.rb)"
    send_event("episode_list", { items: top_episodes })
  end
end
