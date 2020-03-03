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
  busrdides = summary_sheet[6,2]
  innovate_on_demand = summary_sheet[7,2]
  slack = summary_sheet[10,2]
  newsletters = summary_sheet[11,2]
  gccollab = summary_sheet[12,2]
  twitter = summary_sheet[13,2]
  total_outreach = summary_sheet[16,2]

  # Events Variables

  events_virtual = 0
  events_in_person = 0

  # Get events list

  x = events_sheet.num_rows.to_i - 2

  while x >=0
    if (Integer(events_sheet.rows[x][5]) rescue false)
      events_virtual = events_virtual + events_sheet.rows[x][5].to_i
    end

    if (Integer(events_sheet.rows[x][5]) rescue false)
      events_in_person = events_in_person + events_sheet.rows[x][6].to_i
    end

    x = x - 1
  end

  send_event('event_type', { slices: [
    ['Type', 'Participants'],
    ['Virtual', events_virtual],
    ['In Person', events_in_person]
  ]})

  send_event('engagement_goal', { value: ((events_in_person + events_virtual) / 25000.0 * 100).to_i })

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
 

  send_event('engagement_activities', { current: engagement_activites })
  send_event('engagement_events', { current: events })
  send_event('engagement_iod', { current: innovate_on_demand })
  send_event('engagement_newsletters', { current: newsletters })
  send_event('engagement_twitter', { current: twitter })
  send_event('engagement_busrides', { current: busrdides })
  send_event('engagement_total_outreach', { current: total_outreach })

end