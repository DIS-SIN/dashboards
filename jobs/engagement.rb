require "google_drive"

# Create an auth session with Google Drive using service account
session = GoogleDrive::Session.from_service_account_key("./jobs/keys/engagement-tracker-269420-3d8bb98dab6a.json")

# Get summary worksheet of Engagement Tracker

summary = session.spreadsheet_by_key("1D6c_rgfxr8vEQ6sj-EU9-NeetmNIEjTbv6aHK9BMA1Y").worksheets[0]
engagement_activites = 0
events = 0
innovate_on_demand = 0
newsletters = 0
twitter = 0

# :first_in sets how long it takes before the job is first run. In this case, it is run immediately
SCHEDULER.every '10m', :first_in => 0 do |job|
  summary.reload
  engagement_activites = summary[2,2]
  events = summary[3,2]
  innovate_on_demand = summary[7,2]
  newsletters = summary[11,2]
  twitter = summary[13,2]
  send_event('activities', { current: engagement_activites })
  send_event('events', { current: events })
  send_event('innovate_on_demand', { current: innovate_on_demand })
  send_event('newsletters', { current: newsletters })
  send_event('twitter', { current: twitter })

end