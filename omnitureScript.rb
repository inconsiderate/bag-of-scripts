# https://marketing.adobe.com/developer/api-explorer

# Script for pulling down all info from Omniture REST API v1.3
# from a specified date, to whatever other specified date.

require 'httparty'
require 'mysql'
require 'colorize'
require 'pry'
require 'json_object'

# OMNITURE DATAWAREHOUSE VARIABLES
@rsid           = "omnitureRSID"
@requestID      = "" # leave this field blank
@username       = "COMPANY:USERNAME"
@secret         = "SUPERSECRETKEY"
@Metric_List    = ["visits", "visitors", "page_views", "revenue"] # List all of the metrics you wish to pull down
@Breakdown_List = ["campaign", "referrer_domain"] # Breakdowns. Is your DB going to be multidimensional?

# Date from which to start the download. Preconfigured to run backwards, as our starting dates were unclear.
# Format is month/day/year : 12/31/99
@date           = "12/31/14"
@stopBefore     = "01/01/09"

# LOCAL SQL DB VARIABLES
@sqlHostname    = "localhost"
@sqlUsername    = "MYUSERNAME"
@sqlPassword    = "MYPASSWORD"
@sqlDatabase    = "LOCALDATABASE"
@sqlTable       = "LOCALTABLENAME"

# Vars to check for server side errors
@waitingCount = 0
@failedDates = []
@insertedDates = []


def requestQuery
    return {
     "Breakdown_List" => @Breakdown_List,
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
     "Metric_List" => @Metric_List,
     "rsid" => "#{@rsid}"
    }
end

def initSQL
    @conn = Mysql.new(@sqlHostname, @sqlUsername, @sqlPassword, @sqlDatabase)
    @conn.query("CREATE TABLE IF NOT EXISTS \
        #{@sqlTable} (
        id int(10) unsigned NOT NULL AUTO_INCREMENT,
        omniture_code
        date date DEFAULT NULL,
        campaign varchar(255) DEFAULT NULL,
        referrer_domain varchar(255) DEFAULT NULL,
        visits int(11) DEFAULT NULL,
        visitors int(11) DEFAULT NULL,
        page_views int(11) DEFAULT NULL,
        revenue decimal(25,4) DEFAULT NULL,
        PRIMARY KEY (id)
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
    :query => requestQuery,
    :headers => generateHeader)
    puts "Your request ID for ".green + "#{@date}".magenta + " is: #{response.body}".green
    @requestID = response.body
    return response.body
end

def deleteLastRequest
    puts "Deleting request number: #{@requestID}...".red
    response = HTTParty.post("https://api.omniture.com/admin/1.3/rest/?method=DataWarehouse.CancelRequest",
    :query => {
        "Request_Id" => "#{@requestID}"
    },
    :headers => generateHeader)
    puts "Request cancelled. Moving on...".green + " Message: #{response.body}".yellow
    @failedDates << @date
end

def omniCheck
    puts "Working on site: #{@rsid}".green
    puts "Current time: #{Time.now}".green
    messageReady = false
    @messageFailed = false
    @waitingCount = 0
    until messageReady == true || @waitingCount > 40 || @messageFailed == true
        puts "Report not ready yet, sleeping for 30 seconds...".green
        sleep 30
        puts "Checking if #{@requestID} is ready for retrieval...".green
        begin
        response = HTTParty.post("https://api.omniture.com/admin/1.3/rest/?method=DataWarehouse.CheckRequest",
            :query => {
                "Request_Id" => "#{@requestID}"
            },
            :headers => generateHeader)
        rescue Net::ReadTimeout
        end
        puts "Server returned code: #{response.code}".green + " Message: #{response.body}".yellow
        if response.body[10] == "2"
            messageReady = true
        elsif response.code == 400
            puts "Errors reported!".red
            @messageFailed = true
        else
            @waitingCount += 1
        end
    end
    if @waitingCount > 40
        @messageFailed = true
        sleep 1
    end
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
    puts "Sample data (first row to be inserted):".green
    puts "#{data.rows[1]}".yellow
    data.rows[0..-2].each_with_index do |row, i|
        # Some fields will occasionaly be null, and must first be escaped

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
        insertQuery = "INSERT INTO #{@sqlTable} (omniture_code, date, campaign, referrer_domain, visits, visitors, page_views, revenue) VALUES ('#{@rsid}', STR_TO_DATE('#{@date}','%m/%d/%y'), '#{row1}', '#{row2}', '#{row3}', '#{row4}', '#{row[5]}', '#{row[6]}', '#{row[7]}', '#{row[8]}')"
        @conn.query(insertQuery)
    end
    puts "#{@requestID} has been successfully inserted into #{@sqlTable} for #{@date}.".green
    @insertedDates << @date

    # the @insertedDates array is only intended to be used when you have problems with
    # lots of empty dates, for easy comparison with @failedDates.
    # Otherwise it can be commented out.
    @conn.close
end

def welcomeGreeting
    puts ""
    puts " ______________________________________________________".magenta
    puts "|                                                      |".magenta
    puts "|   Running omniture retrieval script!                 |".magenta
    puts "|   Messages in ".magenta + "green".green + " are status!                      |".magenta
    puts "|   Messages in ".magenta + "yellow".yellow + " are returned server data!       |".magenta
    puts "|   Messages in ".magenta + "red".red + " are alerts!                        |".magenta
    puts "|______________________________________________________|".magenta
    puts ""
end

def startProgram
    welcomeGreeting
    initSQL
    until @date == @stopBefore
        puts "Preparing table '#{@sqlTable}' in the '#{@sqlDatabase}' database...".green
        # send initial API call
        omniRequest
        # check every 120 seconds until the request has been filled
        omniCheck
        # if omniture returns a 400 error (empty data package), delete the request from the queue
        # and add the failed fate to the skipped list
        if @messageFailed == true
            deleteLastRequest
            # retrieve the data, parse it, insert into loca mySQL, and then increment the date
        else
            puts "Request number #{@requestID} for #{@date} is ready!".green
            omniRetrieve
        end
        puts "Dates that have ".green + "SUCCEEDED".magenta + " so far (and have been inserted):".green
        # @insertedDates.each do |i|
        #     puts i.magenta
        # end
        puts "#{@insertedDates}".magenta
        puts "Dates that have ".green + "FAILED".red + " so far (returned empty datasets):".green
        # @failedDates.each do |i|
        #     puts i.red
        # end
        puts "#{@failedDates}".red
        decDate
    end
    puts "Working on site: #{@rsid}".magenta
    puts "Complete! Inserted up to, but not including #{@stopBefore}".magenta
    puts "Current time: #{Time.now}".magenta
end

def startCLI
    runScriptAgain = "y"
    until runScriptAgain == "n"
        puts "Date is set to DECREMENT.".green
        print "Enter start date: ".green
        @date = gets.chomp
        print "Enter end date (one day less, to request a single day): ".green
        @stopBefore = gets.chomp
        puts "Starting with #{@date} and working down to #{@stopBefore}...".green
        startProgram
        print "Continue? (y/n): ".green
        runScriptAgain = gets.chomp!
    end
end

startProgram
