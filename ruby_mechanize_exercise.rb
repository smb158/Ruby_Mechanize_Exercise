#Using Mechanize/Ruby to automate website forms 
#By Steve Bauer -- 2/26/2015


require 'rubygems'
require 'mechanize'

$agent = Mechanize.new
$agent.user_agent_alias = 'Mac Safari'

#Global Vars - Set these in the settings.cfg file
$captcha_mode = false
$gmail_username = nil
$entries_per_user = 0
$auto_retry_limit = 1
$manual_retry_limit = 1
$total_candy_count = 0

#Objects
class User
  attr_accessor :first_name, :last_name, :address1, :address2, :state, :city, :zipcode, :phone
end

#Methods
def loadRegistrationInfoList()
	user_list = []
	f = File.open('usersList.cfg', 'r') do |f1|  
		while line = f1.gets  
			if(line.include? "NewUser:")
				curr_user = User.new
				user_list << curr_user
			elsif(line.include? "FirstName:")
				curr_user.first_name = line.split(":")[1].chomp
			elsif(line.include? "LastName:")
				curr_user.last_name = line.split(":")[1].chomp
			elsif(line.include? "Address1:")
				curr_user.address1 = line.split(":")[1].chomp
			elsif(line.include? "Address2:")
				curr_user.address2 = line.split(":")[1].chomp
			elsif(line.include? "State:")
				curr_user.state = line.split(":")[1].chomp
			elsif(line.include? "City:")
				curr_user.city = line.split(":")[1].chomp
			elsif(line.include? "Zipcode:")
				curr_user.zipcode = line.split(":")[1].chomp
			elsif(line.include? "Phone:")
				curr_user.phone = line.split(":")[1].chomp
			else
				puts "The line '#{line}' in usersList.cfg is invalid."
			end
		end  
	end
	return user_list
end 

def loadSettings()
	f = File.open('settings.cfg', 'r') do |f1|  
		while line = f1.gets  
			if(line.include? "CaptchaMode:")
				$captcha_mode = line.split(":")[1].chomp.to_i
			elsif(line.include? "AutoRetryLimit:")
				$auto_retry_limit = line.split(":")[1].chomp.to_i
			elsif(line.include? "ManualRetryLimit:")
				$manual_retry_limit = line.split(":")[1].chomp.to_i
			elsif(line.include? "GmailUsername:")
				$gmail_username = line.split(":")[1].chomp
			elsif(line.include? "EntriesPerUser:")
				$entries_per_user = line.split(":")[1].chomp.to_i
			else
				puts "The line '#{line}' in settings.cfg is invalid."
			end
		end  
	end
end 

def manualCaptcha(captcha_filename)
	puts "Please open #{captcha_filename} and manually enter the solution below"
	return STDIN.gets.chomp
end

def autoCaptcha(captcha_filename)
	tesseract_result = `tesseract #{captcha_filename} stdout -psm 7`
	puts "Tesseract returned #{tesseract_result} for #{captcha_filename}"
	return tesseract_result
end

def formFill(reg_form)
	reg_form.field_with(:name => 'User.FirstName').value = $active_user.first_name
	reg_form.field_with(:name => 'User.LastName').value = $active_user.last_name
	reg_form.field_with(:name => 'User.Address.Address1').value = $active_user.address1
	reg_form.field_with(:name => 'User.Address.Address2').value = $active_user.address2
	reg_form.field_with(:name => 'User.Address.City').value = $active_user.city
	reg_form.field_with(:name => 'User.Address.State').value = $active_user.state
	reg_form.field_with(:name => 'User.Address.PostalCode').value = $active_user.zipcode
	reg_form.field_with(:name => 'User.Phone').value = $active_user.phone
	reg_form.checkbox_with(:name => 'User.AgreeToRules').check
	return reg_form
end

def isSuccess(confirmation_page)
	if(confirmation_page.body.include?('Thank you for picking you'))	
		return true
	elsif(confirmation_page.body.include?('The value you entered did not match the security image, try again'))
		puts "Captcha solution was invalid."
		return false
	else
		puts "Something has gone wrong!Page dumped to #{comfirmation_page.save_as 'error.log'} for analysis"
		exit
	end
end

#This method is hideous - absolutely should be rewritten but this script was just for fun

def handleCaptchaAndSubmit(reg_page)
	reg_form = nil
	success_bool = false
	attempt_num = 0
	
	if($captcha_mode == 1)
		#auto with N retries before moving on
		while success_bool == false && attempt_num < $auto_retry_limit
			complete_form = fillFormWithCaptchaResult(findFormInCurrPage(reg_page), autoCaptcha(getCaptchaImage(reg_page)))
			winner_or_error_page = $agent.submit(complete_form)
			success_bool = isSuccess(winner_or_error_page)
			#set reg_page to our winner_or_error_page so next iteration, if it happens, will use that page instead of old stale data
			reg_page = winner_or_error_page
		end
		return success_bool
	elsif($captcha_mode == 2)
		#manual with N retries before moving on
		while success_bool == false && attempt_num < $manual_retry_limit
			complete_form = fillFormWithCaptchaResult(findFormInCurrPage(reg_page),manualCaptcha(getCaptchaImage(reg_page)))
			winner_or_error_page = $agent.submit(complete_form)
			success_bool = isSuccess(winner_or_error_page)
			reg_page = winner_or_error_page
		end
		return success_bool
	elsif($captcha_mode == 3)
		#auto with unlimited retries
		while success_bool == false
			complete_form = fillFormWithCaptchaResult(findFormInCurrPage(reg_page), autoCaptcha(getCaptchaImage(reg_page)))
			winner_or_error_page = $agent.submit(complete_form)
			success_bool = isSuccess(winner_or_error_page)
			reg_page = winner_or_error_page
		end
		return success_bool
	elsif($captcha_mode == 4)
		#manual with unlimited retries
		while success_bool == false
			complete_form = fillFormWithCaptchaResult(findFormInCurrPage(reg_page),manualCaptcha(getCaptchaImage(reg_page)))
			winner_or_error_page = $agent.submit(complete_form)
			success_bool = isSuccess(winner_or_error_page)
			reg_page = winner_or_error_page
		end
		return success_bool
	else
		puts "You entered an invalid captcha mode. Only 1-4 are supported currently."
		exit
	end
end

def findFormInCurrPage(reg_page)
	return reg_page.forms.first
end

def fillFormWithCaptchaResult (reg_form,captcha_results)
	reg_form.field_with(:name => 'Captcha.Value').value = captcha_results
	return reg_form
end

def getCaptchaImage(reg_page)
	#save captcha image
	captcha_filename = reg_page.images.first.fetch.save('captcha.jpg')
end

#Main

puts "\n\n--== Operation Sweet_Tooth V0.5 ==--"

loadSettings()
users_list = loadRegistrationInfoList()
#puts users_list.inspect

users_list.each do |tmp_user|  

	$active_user = tmp_user

	current_entry_count = 0
	while current_entry_count < $entries_per_user  do
	
		puts "User #{$active_user.first_name} #{$active_user.last_name} iteration #{current_entry_count}"
	
		curr_email_addy = $gmail_username + '+' + current_entry_count.to_s + '@gmail.com'
	
		puts "Registering with email: #{curr_email_addy}"
		main_page = $agent.get('http://reesesstartinglineup.com/en-us/Enter')

		email_form = main_page.form_with(:action => '/en-us/LoginWithEmail')
	
		#fill email and request next page
		email_form.Identifier = curr_email_addy
		reg_page = $agent.submit(email_form)

		#lazy grab the form that contains user input boxes
		reg_form = reg_page.forms.first
		
		puts "Filling the form.."
		completed_form = formFill(reg_form)
		
		result_for_current_account = handleCaptchaAndSubmit(reg_page)
		
		if(result_for_current_account == true)
			puts "Entry was successful"
			total_candy_count += 1
		elsif(result_for_current_account == false)
			puts "Entry was unsuccessful"
		end
	
		puts "You have entered #{$total_candy_count} times successfully this session."
		
		sleepy_time = rand(5..15)
		puts "Sleeping for #{sleepy_time} seconds..."
		sleep(sleepy_time)
	end #end of while current_entry < $entries_per_user  do

end #end of users_list.each do |$active_user|

puts "Script has run to completion. Thanks for playing ;)"