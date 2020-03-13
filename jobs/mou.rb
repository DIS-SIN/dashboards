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

# Get the MoU data from the sheet
SCHEDULER.every '10m', :first_in => 0 do |job|
    # Refresh MoU sheets
    mou_sheet.reload

    # Get values from sheet
    mou_amount_all_fiscal = mou_sheet[25, 6]
    mou_amount_current_fiscal = mou_sheet[25, 2]
    draft_amount_total = mou_sheet[26, 6]

    # Get all of the rows that have signed MoUs
    signed_rows = []
    for i in 0..20
        current_row = mou_sheet.rows[i+2] # +2 to skip header rows

        # if the row is marked as signed, save it
        if current_row[6] == "Signed"
            # Read the fiscal amount, but strip leading dollar sign and any commas
            fiscal_amount_stripped = current_row[1].to_s.strip.delete("$ ,")

            # Add to collection of rows that were signed
            signed_rows << {"department" => current_row[0], "fiscal_amount" => fiscal_amount_stripped.to_i}
        end
    end

    # Sort the signed rows based on the fiscal amount in descending order
    signed_rows = signed_rows.sort_by { |hsh| -hsh["fiscal_amount"] }
    
    # We now have a sorted array, the first 5 object are our top 5 departments
    top_departments = []
    for i in 0..4
        top_departments << {'label' => signed_rows[i]["department"]}
    end

    # Send the events to the dashboard to be rendered
    send_event('mou_all_fiscal', { current: mou_amount_all_fiscal})
    send_event('mou_cur_fiscal', { current: mou_amount_current_fiscal})
    send_event('mou_draft_total', { current: draft_amount_total})
    send_event('mou_top_departments', { items: top_departments})
end
