require 'googleauth'
require 'google_drive'

# Get the environment configured authorization
scopes =  ['https://www.googleapis.com/auth/drive.readonly']
authorization = Google::Auth::ServiceAccountCredentials.make_creds(json_key_io: File.open("./jobs/keys/engagement-tracker-269420-3d8bb98dab6a.json"), scope: scopes)

# Clone and set the subject
auth_client = authorization.dup
auth_client.sub = 'is.admin@da-an.ca'
auth_client.fetch_access_token!

# Create an auth session with Google Drive using service account
session = GoogleDrive::Session.from_access_token(auth_client)
google_worksheet = session.spreadsheet_by_key("1APS9XScf2weoSBQscubTFfUQ12IbG-yWVbdF3Jw4xeo")
mou_sheet = google_worksheet.worksheets[0]

# Helper function
def remove_Formatting(value)
  format_removed_value = value.to_s.strip.delete("$ ,")
  return format_removed_value.to_i
end


def parse_MOU(sheet)
  # load data from sheet
  parsed_object = []
  sheet.rows.each do |row|
    parsed_object.push({
      'department' => row[0],
      'f19' => remove_Formatting(row[1]),
      'f20' => remove_Formatting(row[2]),
      'f21' => remove_Formatting(row[3]),
      'f22' => remove_Formatting(row[4]),
      'status' => row[6],
    })
  end

  # drop anything that doesn't have a status
  parsed_object.reject!{|row| !["Signed",
  "Draft",
  "Discussions",
  "Requested",
  "Declined",
  "Not Pursued"].include?(row["status"])}

  return parsed_object
end





# Get the MoU data from the sheet
SCHEDULER.every '10m', :first_in => 0 do |job|
    # Refresh MoU sheets
    mou_sheet.reload

    mou_data = parse_MOU(mou_sheet)

    # mou ammount for all fiscal years
    mou_amount_all_fiscal = 0
    mou_data.each do |mou|
      if (mou["status"] == "Signed")
        mou_amount = mou["f19"] + mou["f20"] + mou["f21"] + mou["f22"]
        mou_amount_all_fiscal = mou_amount_all_fiscal + mou_amount
      end
    end

    #mou ammount this fical
    mou_amount_current_fiscal = 0
    mou_data.each do |mou|
      if(mou["status" == "Signed"])
        mou_amount_current_fiscal = mou_amount_current_fiscal + mou["f20"]
      end
    end
    # draft total amount all fiscal years
    draft_amount_total = 0
    mou_data.each do |mou|
      if(mou["status"] == "Draft")
        mou_amount = mou["f19"] + mou["f20"] + mou["f21"] + mou["f22"]
        draft_amount_total = draft_amount_total + mou_amount
      end
    end

    # Get all of the rows that have signed MoUs
    signed_rows = mou_data.reject{|mou| !mou["status"]=="Signed"}

    # Sort the signed rows based on the fiscal amount in descending order
    signed_rows.sort_by!{ |hsh| -hsh["f19"] }
    
    # We now have a sorted array, the first 5 object are our top 5 departments
    top_departments = []
    for i in 0..4
        top_departments << {'label' => signed_rows[i]["department"], 'value' => ("$" + signed_rows[i]["f19"].to_s)}
    end

    # Send the events to the dashboard to be rendered
    send_event('mou_all_fiscal', { current: mou_amount_all_fiscal})
    send_event('mou_cur_fiscal', { current: mou_amount_current_fiscal})
    send_event('mou_draft_total', { current: draft_amount_total})
    send_event('mou_top_departments', { items: top_departments})
end
