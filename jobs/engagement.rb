require "google_drive"

# Create an auth session with Google Drive using service account
session = GoogleDrive::Session.from_service_account_key("./jobs/keys/engagement-tracker-269420-3d8bb98dab6a.json")

# Get summary worksheet of Engagement Tracker

summary_sheet = session.spreadsheet_by_key("1D6c_rgfxr8vEQ6sj-EU9-NeetmNIEjTbv6aHK9BMA1Y").worksheets[0]
events_sheet = session.spreadsheet_by_key("1D6c_rgfxr8vEQ6sj-EU9-NeetmNIEjTbv6aHK9BMA1Y").worksheets[2]
engagements_sheet = session.spreadsheet_by_key("1D6c_rgfxr8vEQ6sj-EU9-NeetmNIEjTbv6aHK9BMA1Y").worksheets[1]

# Helper functions

def parse_Events(sheet)
  # load data from sheet
  parsed_object = []
  sheet.rows.each do |row|
    parsed_object.push({
      'date' => (Date.parse(row[0]) rescue nil),
      'event' => row[1],
      'description' => row[2],
      'type' => row[3],
      'language' => row[4],
      'virtual' => row[5],
      'inperson' => row[6],
    })
  end

  # remove entries that are not a valid date
  parsed_object.reject!{|item| (!item["date"].respond_to?(:strftime) rescue false)}

  # sort by date
  parsed_object.sort_by!{|item| item["date"]}

  return parsed_object
end

def parse_engagement(sheet)
  parsed_object = []
  sheet.rows.each do |row|
    parsed_object.push({
      'date' => (Date.parse(row[0]) rescue nil),
      'engagement' => row[1],
      'activity' => row[2],
      'location'=> row[5],
      'language'=> row[6],
      'attendees' => row[7]
    })
  end

  # remove entries that are not a valid date
  parsed_object.reject!{|item| (!item["date"].respond_to?(:strftime) rescue false)}

  # sort by date
  parsed_object.sort_by!{|item| item["date"]}

  return parsed_object
end

# 'from' must always be less then 'to'
def date_range(items, from, to)

    date_range_items = items.reject{ |item| item["date"] < from }
    date_range_items.reject!{ |item| item["date"] > to }

  return date_range_items
end

# Events job for:
# # of people reached FYTD |
# # of events FYTD |
# {# of people reached (28days) / # of events (28days)} |
# // Next event (3 next)

SCHEDULER.every '10m', :first_in => 0 do |job|
  events_sheet.reload
  summary_sheet.reload
  today = Date.today

  event_data = parse_Events(events_sheet)

  # of events FYTD
  events_to_date_items = date_range(event_data, Date.strptime("01-04-2019", "%d-%m-%Y"), today)

  send_event("events_num_fytd", { current: events_to_date_items.count })
  
  # of people reached FYTD
  people_reached_fytd = 0
  events_to_date_items.each do |event|
    people_reached_fytd = people_reached_fytd + event["virtual"].to_i + event["inperson"].to_i
  end
  send_event("events_reached_fytd", { current: people_reached_fytd})

  # of events (28days)
  events_28d_items = date_range(event_data, (today - 28), today)

  # of people reached (28days)
  people_reached_28d = 0
  events_28d_items.each do |event|
    people_reached_28d = people_reached_28d + event["virtual"].to_i + event["inperson"].to_i
  end
  send_event("events_28d_summary", { value1: people_reached_28d, value2: events_28d_items.count })

  # next 3 events

  next_3_events = []
  num_of_events = 3

  event_data.each do |event|
    days_away = (event["date"] - today).to_i
    if(days_away >= 0 && num_of_events > 0)
      next_3_events.push({
        'label' => event["event"],
        'value' => event["date"].strftime("%b %-d")
    })
      num_of_events = num_of_events - 1
    end
  end

  send_event("events_next_3", {items: next_3_events, unordered: true})

  # last event
  last_event = nil
  event_data.each do |event|
    days_away = (event["date"] - today).to_i
    if (days_away < 0)
      last_event = event
    end
  end

  send_event("events_text", {items: [{'label' => last_event["event"], 'value' => last_event["date"].strftime("%b %-d")}] , unordered: true})


end

# Engagement jobs for:
# # of activity (28days) |
# number of people reached (28 days) |
# # activities (uncoming 7 days) |
# Total FYTD people reached | 
# % of regional activities / % of virtual activities
# Type (In list form with # of each) |

SCHEDULER.every '10m', :first_in => 0 do |job|
  engagements_sheet.reload
  engagement_data = parse_engagement(engagements_sheet)
  today = Date.today

  # of people reached fytd
  engagement_to_date_items = date_range(engagement_data, Date.strptime("01-04-2019", "%d-%m-%Y"), today)
  people_reached_fytd = 0
  engagement_to_date_items.each do |engagement|
    people_reached_fytd = people_reached_fytd + engagement["attendees"].to_i
  end
  send_event("engagement_reached_fytd", { current: people_reached_fytd})

  # of activities 28 days
  engagements_28d_items = date_range(engagement_data, (today - 28), today)

  # of people reached 28 days
  people_reached_28d = 0
  engagements_28d_items.each do |engagement|
    people_reached_28d = people_reached_28d + engagement["attendees"].to_i
  end

  send_event("engagement_28d_summary", { value1: people_reached_28d, value2: engagements_28d_items.count })

  # of types and count
  engagement_speaker = 0
  engagement_workshop = 0
  engagement_presentation = 0
  engagement_kiosk = 0
  engagement_meetup = 0

  engagement_data.each do |engagement|
    if (Integer(engagement["attendees"]) rescue false)
      case engagement["activity"]
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
        p "unknown value:" + engagement["activity"]
      end
    end

  end
  engagement_list = [
    {'label' => "Speaker", 'value' => engagement_speaker },
    {'label' => "Workshop", 'value' => engagement_workshop },
    {'label' => "Presentation", 'value' => engagement_presentation },
    {'label' => "Kiosk", 'value' => engagement_kiosk },
    {'label' => "Meetup", 'value' => engagement_meetup }
  ]

  engagement_list.sort_by!{|item| -item["value"]}

  send_event('engagement_type', {items: engagement_list, unordered: true})

  # Next 3 Engagements

  next_3_engagements = []
  num_of_engagements = 3

  engagement_data.each do |engagement|
    days_away = (engagement["date"] - today).to_i
    if(days_away >= 0 && num_of_engagements > 0)
      next_3_engagements.push({
        'label' => engagement["engagement"],
        'value' => engagement["date"].strftime("%b %-d")
    })
      num_of_engagements = num_of_engagements - 1
    end
  end

  send_event("engagements_next_3", {items: next_3_engagements, unordered: true})

  # last engagement
  last_engagement = nil
  engagement_data.each do |event|
    days_away = (event["date"] - today).to_i
    if (days_away < 0)
      last_engagement = event
    end
  end

  send_event("engagements_text", {items: [{'label' => last_engagement["engagement"], 'value' => last_engagement["date"].strftime("%b %-d")}], unordered: true})


end




SCHEDULER.every '10m', :first_in => 0 do |job|
  # Refresh all sheets
  summary_sheet.reload

  # Get Twitter Analytics Summary
  tweet_amount = summary_sheet[30,2]
  tweet_percent = summary_sheet[30,3]
  impression_amount = summary_sheet[31,2]
  impression_percent = summary_sheet[31,3]
  profile_visit_amount = summary_sheet[32,2]
  profile_visit_percent = summary_sheet[32,3]
  mentions_amount = summary_sheet[33,2]
  mentions_percent = summary_sheet[33,3]
  followers_amount = summary_sheet[34,2]
  followers_percent = summary_sheet[34,3]

  # Send Twitter Analytics Events
  send_event('ta_tweets', { current: tweet_amount, difference: tweet_percent})
  send_event('ta_impression', { current: impression_amount, difference: impression_percent})
  send_event('ta_profile_visits', { current: profile_visit_amount, difference: profile_visit_percent})
  send_event('ta_mentions', { current: mentions_amount, difference: mentions_percent})
  send_event('ta_followers', { current: followers_amount, difference: followers_percent})

  # Get Engagement Summary numbers
  engagement_total = summary_sheet[5,2].to_i
  engagement_total_outreach = summary_sheet[5,2].to_i + summary_sheet[7,2].to_i
  send_event("engagement_goal", {value: engagement_total})
  send_event("engagement_total_outreach", {current: engagement_total_outreach})

 
end

SCHEDULER.every '10m', :first_in => 0 do |job|
  events_sheet.reload
  engagements_sheet.reload

  event_dates = {}
  event_dates["events"] = []
  engagement_dates = {}
  engagement_dates["events"] = []

  # Get events list

  x = events_sheet.num_rows.to_i - 1

  while x >=0
    if (Date.parse(events_sheet.rows[x][0]) rescue false)
      event_dates['events'].push({'name' => events_sheet.rows[x][2], 'date' => Date.parse(events_sheet.rows[x][0])})
    end
    x = x - 1
  end

  y = engagements_sheet.num_rows.to_i - 1

  while y >=0
    if (Date.parse(engagements_sheet.rows[y][0]) rescue false)
      engagement_dates['events'].push({'name' => engagements_sheet.rows[y][1], 'date' => Date.parse(engagements_sheet.rows[y][0])})
    end
    y = y - 1
  end

  # Remove rows with no date
  event_dates["events"].reject!{|item| item["date"] == nil}
  engagement_dates["events"].reject!{|item| item["date"] == nil}

  #sort the lists by date
  event_dates["events"].sort_by!{|hsh| hsh["date"]}
  engagement_dates["events"].sort_by!{|hsh| hsh["date"]}

  # Get 3 next events / engagements
  events_next3 = []
  engagements_next3 = []

  today = Date.today
  num_of_events = 3
  event_dates["events"].each do |event|
    days_away = (event["date"] - today).to_i
    if(days_away >=0 && num_of_events > 0)
      events_next3 << {
        name: event["name"],
        date: event["date"].strftime('%a %d %b %Y'),
        background: Random.bytes(3).unpack1('H*')
      }
      num_of_events = num_of_events - 1
    end
  end

  engagement_dates["events"].each do |event|
    days_away = (event["date"] - today).to_i
    if(days_away < 15  && days_away > -15)
      engagements_next3 << {
        name: event["name"],
        date: event["date"].strftime('%a %d %b %Y'),
        background: Random.bytes(3).unpack1('H*')
      }
    end
  end

send_event("event_timeline", {events: events_next3})
send_event("engagement_timeline", {events: engagements_next3})

end

