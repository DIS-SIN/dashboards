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

# get episodes list from file
episodes_file = File.read("./jobs/busrides_resources/episodes.json")
episodes_list = JSON.parse(episodes_file)

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

def getDeviceMetrics(data)

  desktop = 0
  tablet = 0
  mobile = 0

  # Get meter info for devices
  data.rows.each do |row|

    if row[0].eql?("desktop") then
      desktop = row[1].to_i
    elsif row[0].eql?("tablet") then
      tablet = row[1].to_i
    else row[0].eql?("mobile")
      mobile = row[1].to_i
    end
  end

  device_total = data.totals_for_all_results["ga:users"].to_f
  desktop = desktop / device_total * 100
  tablet = tablet / device_total * 100
  mobile = mobile / device_total * 100

  return [desktop.to_i, tablet.to_i, mobile.to_i]

end


SCHEDULER.every '12h', :first_in => 0 do
  analytics = getCredentials(service, key_file)

  ga_response = analytics.get_ga_data("ga:" + profile_id, "7daysAgo", "yesterday","ga:users,ga:newUsers")
  ga_comparative = analytics.get_ga_data("ga:" + profile_id, "14daysAgo", "7daysAgo", "ga:users,ga:newUsers")
  
  ga_topArticles = analytics.get_ga_data("ga:" + profile_id, 
  "7daysAgo",
  "yesterday",
  "ga:pageviews",
  sort:"-ga:pageviews",
  dimensions: "ga:pagePath",
  filters: "ga:pagePath=@/en/ep-,ga:pagePath=@/fr/ep-", #,ga:pagePath=@\\fr\\ep-
  max_results: 5
)

  users = ga_response.totals_for_all_results["ga:users"]
  newUsers = ga_response.totals_for_all_results["ga:newUsers"]
  # returnUsers = users.to_i - newUsers.to_i

  previous_users = ga_comparative.totals_for_all_results["ga:users"]
  previous_newUsers = ga_comparative.totals_for_all_results["ga:newUsers"]
  # previous_returnUsers = previous_users.to_i - previous_newUsers.to_i

  top_episodes = []
  # for each of the pages that were in the top
  # read the pagePath (from GA) and remove the 
  ga_topArticles.rows.each do |row|
    if row[0].include?("/en/ep-") then
      item = row[0].gsub("/en/ep-","")
      item = item.gsub("-en/","")
      top_episodes << { 'label' => episodes_list[item] + " {EN}"}
    elsif row[0].include?("/fr/ep-") then
      item = row[0].gsub("/fr/ep-","")
      item = item.gsub("-fr/","")
      top_episodes << { 'label' =>  episodes_list[item] + " {FR}"}
    else
      top_episodes << { 'label' =>  row[0]}
    end
  end

  puts "Busride analytics data read succesfully. Sending event. (busrides.rb)"
  send_event("busrides_7d_episode_list", { items: top_episodes })
  # Testing for Search API
  #page_url = "/en/ep-22-en" + "/"

  #page_index = ga_topArticles.rows.index{ |row| row[0] == page_url }
  #puts page_index
  #if page_index then
  #  puts ga_topArticles.rows[page_index][1]
  #end


  send_event('busrides_7d_users', current: users, last: previous_users)
  send_event('busrides_7d_newUsers', current: newUsers, last: previous_newUsers)
  # send_event('busrides_7d_returnUsers', current: returnUsers, last: previous_returnUsers)
end

SCHEDULER.every '12h', :first_in => 0 do

  analytics = getCredentials(service, key_file)
  ## Start and end dates
  startDate = DateTime.now - 30
  startDate = startDate.strftime("%Y-%m-%d")
  endDate = DateTime.now.strftime("%Y-%m-%d")
  comparative_startDate = DateTime.now - 60
  comparative_startDate = comparative_startDate.strftime("%Y-%m-%d")


  ga_response = analytics.get_ga_data("ga:" + profile_id, startDate, endDate,"ga:users,ga:newUsers")
  ga_comparative = analytics.get_ga_data("ga:" + profile_id, comparative_startDate, startDate, "ga:users,ga:newUsers")
  ga_referrers = analytics.get_ga_data("ga:" + profile_id, startDate, endDate, "ga:users", dimensions:"ga:source", start_index:2, max_results:5, sort:"-ga:users")
  ga_device = analytics.get_ga_data("ga:" + profile_id, startDate, endDate, "ga:users", dimensions:"ga:deviceCategory")
  ga_device_compartive = analytics.get_ga_data("ga:" + profile_id, comparative_startDate, startDate, "ga:users", dimensions:"ga:deviceCategory")

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

  users = ga_response.totals_for_all_results["ga:users"]
  newUsers = ga_response.totals_for_all_results["ga:newUsers"]
  # returnUsers = users.to_i - newUsers.to_i

  deviceMetrics = getDeviceMetrics(ga_device)
  deviceMetrics_comparative = getDeviceMetrics(ga_device_compartive)

  send_event('busrides_desktop', value: deviceMetrics[0] , last: deviceMetrics_comparative[0])
  send_event('busrides_tablet',  value: deviceMetrics[1], last: deviceMetrics_comparative[1])
  send_event('busrides_mobile',  value: deviceMetrics[2], last: deviceMetrics_comparative[2])

  previous_users = ga_comparative.totals_for_all_results["ga:users"]
  previous_newUsers = ga_comparative.totals_for_all_results["ga:newUsers"]
  # previous_returnUsers = previous_users.to_i - previous_newUsers.to_i

  send_event('busrides_30d_users', current: users, last: previous_users)
  send_event('busrides_30d_newUsers', current: newUsers, last: previous_newUsers)
  # send_event('busrides_30d_returnUsers', current: returnUsers, last: previous_returnUsers)

  top_referrers = []

  ga_referrers.rows.each do |row|
    top_referrers << { 'label' => row[0], 'value' => row[1] + " users" }
  end

  top_referrers.each do |referrer|
    if referrer["label"].eql?("t.co")
      referrer["label"] = "twitter"
    end
  end

  send_event("busrides_30d_referrers", { items: top_referrers })

  top_episodes = []
  # for each of the pages that were in the top
  # read the pagePath (from GA) and remove the 
  top_pages_monthly.rows.each do |row|
    if row[0].include?("/en/ep-") then
      item = row[0].gsub("/en/ep-","")
      item = item.gsub("-en/","")
      top_episodes << { 'label' =>  episodes_list[item] + " {EN}"}
    elsif row[0].include?("/fr/ep-") then
      item = row[0].gsub("/fr/ep-","")
      item = item.gsub("-fr/","")
      top_episodes << { 'label' =>  episodes_list[item] + " {FR}"}
    else
      top_episodes << { 'label' =>  row[0]}
    end

    send_event("busrides_30d_episode_list", { items: top_episodes })
  end
end
