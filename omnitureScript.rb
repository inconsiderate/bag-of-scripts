# https://marketing.adobe.com/developer/api-explorer#DataWarehouse.CheckRequest
# Script for pulling down all info from Omniture REST API v1.3
# from a specified date, to whatever other specified date.


require 'httparty'
require 'mysql'
require 'colorize'
require 'pry'
require 'json_object'
require 'pry'


# OMNITURE DATAWAREHOUSE VARIABLES
@rsid           = "omnitureRSID"
@date           = "12/31/15"
@requestID      = "" # leave this blank
@username       = "omnitureUsername"
@secret         = "omnitureSecret"


# LOCAL SQL VARIABLES
@sqlHostname    = "localhost"
@sqlUsername    = "myUsername"
@sqlPassword    = "myPassword"
@sqlDatabase    = "localDatabase"
@sqlTable       = "someTable"


@requestQuery = {
     "Breakdown_List" => [
     "campaign",
     "referrer_domain_v3"
     ],
    "Contact_Name" => "Some Contact Name",
    "Date_From" => "#{@date}",
    "Date_Granularity" => "day",
    "Date_To" => "#{@date}",
    "Report_Name" => "DW API test",
    "Contact_Name" => "some madeup name",
    "Contact_Phone" => "your contact phone number",
    "Date_Type" => "range",
    "Email_Subject" => "Data Warehouse Report",
    "Email_To" => "YOUREMAILHERE",
    "FTP_Host" => "send_via_API",
    "Metric_List" => [
            "visits",
            "visitors",
            "page_views",
            "revenue"
    ],
    "rsid" => "#{@rsid}"
}

def initSQL
    @conn = Mysql.new(@sqlHostname, @sqlUsername, @sqlPassword, @sqlDatabase)
    @conn.query("CREATE TABLE IF NOT EXISTS \
        #{@sqlTable} (
        id int(10) unsigned NOT NULL AUTO_INCREMENT,
        campaign varchar(255) DEFAULT NULL,
        referrer_domain_v3 varchar(255) DEFAULT NULL,
        visits int(11) DEFAULT NULL,
        visitors int(11) DEFAULT NULL,
        page_views int(11) DEFAULT NULL,
        revenue decimal(25,4) DEFAULT NULL,
        )")
    @conn.close
end

def startSQL
    @conn = Mysql.new(@sqlHostname, @sqlUsername, @sqlPassword, @sqlDatabase)
end


def generateHeader
    nonce = Digest::MD5.new.hexdigest(rand().to_s)
    created = Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")
    combo_string = nonce + created + @secret
    sha1_string =  Digest::SHA1.new.hexdigest(combo_string)
    password = Base64.encode64(sha1_string).to_s.chomp("\n")
    return {
      "X-WSSE" => "UsernameToken Username=\"#{@username}\", PasswordDigest=\"#{password}\", Nonce=\"#{nonce}\", Created=\"#{created}\""
    }
end

def decDate
    @dateObject = Date.strptime("#{@date}", "%m/%d/%y")
    @dateObject -= 1
    @date = @dateObject.strftime("%m/%d/%y")
    @date = @date.to_s
end

def omniRequest
    puts "Requesting data for: #{@date}".green
    response = HTTParty.post("https://api.omniture.com/admin/1.3/rest/?method=DataWarehouse.Request",
    :query => @requestQuery,
    :headers => generateHeader)
    puts "Success! Your request ID is: #{response.body}".green
    @requestID = response.body
    return response.body
end

def omniCheck
    messageReady = false
    until messageReady == true
        puts "Not ready yet".green
        puts "Sleeping for 120 seconds...".green
        sleep 120
        puts "Checking if #{@requestID} is ready for retrieval...".green
        response = HTTParty.post("https://api.omniture.com/admin/1.3/rest/?method=DataWarehouse.CheckRequest",
        :query => {
            "Request_Id" => "#{@requestID}"
        },
        :headers => generateHeader)
        puts "Server returned #{response.body[10]} and code: #{response.code}".yellow
        puts "Message: #{response.body}".green
        if response.body[10] == "2"
            messageReady = true
        end
    end
    puts "Request number #{@requestID} for #{@date} is ready!".green
    sleep 2
end

def omniRetrieve
    startSQL
    response = HTTParty.post("https://api.omniture.com/admin/1.3/rest/?method=DataWarehouse.GetReportData",
    :query => {
        "Request_Id" => "#{@requestID}",
        # "Request_Id" => "1650468",
        "rsid" => "#{@rsid}",
        "start_row" => "1"
    },
    :headers => generateHeader)
    data = JSONObject.new response.body
    data.rows[0..-2].each_with_index do |row, i|
        # Some fields will occasionaly be null, and therefor can't be escaped with mysql
        if row[1] != nil
            row1 = @conn.escape_string(row[1])
        else
            row1 = "NULL"
        end
        if row[2] != nil
            row2 = @conn.escape_string(row[2])
        else
            row2 = "NULL"
        end
        if row[3] != nil
            row3 = @conn.escape_string(row[3])
        else
            row3 = "NULL"
        end
        if row[4] != nil
            row4 = @conn.escape_string(row[4])
        else
            row4 = "NULL"
        end
        insertQuery = "INSERT INTO #{@sqlTable} (omniture_code, date, campaign, mobilerep_device_type, referrer_v2, referrer_domain_v3, visits, visitors, page_views, revenue, purchase, page_time, scOpen, scAdd, event14, event21, event1, scCheckout) VALUES ('#{@rsid}', STR_TO_DATE('#{@date}','%m/%d/%y'), '#{row1}', '#{row2}', '#{row3}', '#{row4}', '#{row[5]}', '#{row[6]}', '#{row[7]}', '#{row[8]}', '#{row[9]}', '#{row[10]}', '#{row[11]}', '#{row[12]}', '#{row[13]}', '#{row[14]}', '#{row[15]}', '#{row[16]}')"
        @conn.query(insertQuery)
    end
    puts "#{@requestID} has been successfully inserted for #{@date}.".red
    @conn.close
end

def letsDoThis
    initSQL
    until @date == "01/15/13"
        # send initial API call
        omniRequest
        # check every 120 seconds until the request has been filled
        omniCheck
        # retrieve the data, parse it, and insert into mySQL
        omniRetrieve
        # decrement the date
        decDate
    end
end

letsDoThis
