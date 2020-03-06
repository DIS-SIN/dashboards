require "google_drive"

# Create an auth session with Google Drive using service account
session = GoogleDrive::Session.from_service_account_key("./jobs/keys/engagement-tracker-269420-3d8bb98dab6a.json")

# Get summary worksheet of Engagement Tracker

summary_sheet = session.spreadsheet_by_key("1D6c_rgfxr8vEQ6sj-EU9-NeetmNIEjTbv6aHK9BMA1Y").worksheets[0]
events_sheet = session.spreadsheet_by_key("1D6c_rgfxr8vEQ6sj-EU9-NeetmNIEjTbv6aHK9BMA1Y").worksheets[2]
engagements_sheet = session.spreadsheet_by_key("1D6c_rgfxr8vEQ6sj-EU9-NeetmNIEjTbv6aHK9BMA1Y").worksheets[1]

# Summary Variables
engagement_activites = 0
events = 0
busrides = 0
innovate_on_demand = 0
slack = 0
newsletters = 0
gccollab = 0
twitter = 0

SCHEDULER.every '10m', :first_in => 0 do |job|
  # Refresh all sheets
  summary_sheet.reload
  events_sheet.reload
  engagements_sheet.reload

  # Get Summary Sheet details
  engagement_activites = summary_sheet[2,2]
  events = summary_sheet[3,2]
  busrides = summary_sheet[6,2]
  innovate_on_demand = summary_sheet[7,2]
  slack = summary_sheet[10,2]
  newsletters = summary_sheet[11,2]
  gccollab = summary_sheet[12,2]
  twitter = summary_sheet[13,2]
  total_outreach = summary_sheet[16,2]

  send_event('engagement_activities', { current: engagement_activites })
  send_event('engagement_events', { current: events })
  send_event('engagement_iod', { current: innovate_on_demand })
  send_event('engagement_newsletters', { current: newsletters })
  send_event('engagement_twitter', { current: twitter })
  send_event('engagement_busrides', { current: busrides })
  send_event('engagement_total_outreach', { current: total_outreach })
  
  # Get Twitter Analytics Summary
  tweet_amount = summary_sheet[29,2]
  tweet_percent = summary_sheet[29,3]
  impression_amount = summary_sheet[30,2]
  impression_percent = summary_sheet[30,3]
  profile_visit_amount = summary_sheet[31,2]
  profile_visit_percent = summary_sheet[31,3]
  mentions_amount = summary_sheet[32,2]
  mentions_percent = summary_sheet[32,3]
  followers_amount = summary_sheet[33,2]
  followers_percent = summary_sheet[33,3]

  # Send Twitter Analytics Events
  send_event('ta_tweets', { current: tweet_amount, difference: tweet_percent})
  send_event('ta_impression', { current: impression_amount, difference: impression_percent})
  send_event('ta_profile_visits', { current: profile_visit_amount, difference: profile_visit_percent})
  send_event('ta_mentions', { current: mentions_amount, difference: mentions_percent})
  send_event('ta_followers', { current: followers_amount, difference: followers_percent})

  # Events Variables

  events_virtual = 0
  events_in_person = 0

  # Get events list

  x = events_sheet.num_rows.to_i - 2

  while x >=0
    if (Integer(events_sheet.rows[x][5]) rescue false)
      events_virtual = events_virtual + events_sheet.rows[x][5].to_i
    end

    if (Integer(events_sheet.rows[x][6]) rescue false)
      events_in_person = events_in_person + events_sheet.rows[x][6].to_i
    end

    x = x - 1
  end

  send_event('event_type', { slices: [
    ['Type', 'Participants'],
    ['Virtual', events_virtual],
    ['In Person', events_in_person]
  ]})

  send_event('engagement_goal', { value: ((engagement_activites.to_i + events.to_i) / 25000.0 * 100).to_i })

  # Engagement Variabless
  engagement_speaker = 0
  engagement_workshop = 0
  engagement_presentation = 0
  engagement_kiosk = 0
  engagement_meetup = 0

  # Get engagements list
  x = engagements_sheet.num_rows.to_i - 2

  while x >= 0
    if (Integer(engagements_sheet.rows[x][7]) rescue false)
      case engagements_sheet.rows[x][2]
      when /speaker/i
        engagement_speaker += 1
      when /workshop/i
        engagement_workshop += 1
      when /presentation/i
        engagement_presentation += 1
      when /kiosk/i
        engagement_kiosk += 1
      when /meetup/i
        engagement_meetup += 1
      else
        put "unknown value:" + engagements_sheet.rows[x][2]
      end
    end
    x = x -1
  end


  send_event('engagement_type', { slices: [
    ["Type", "Participants"],
    ["Speaker", engagement_speaker],
    ["Workshop", engagement_workshop],
    ["Presentation", engagement_presentation],
    ["Kiosk", engagement_kiosk],
    ["Meetup", engagement_meetup]
  ]})
 



end