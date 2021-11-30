# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(number)
  stripped_num = number.delete '-(). '
  if stripped_num.length == 11 && stripped_num.start_with?('1')
    stripped_num[1..10]
  elsif stripped_num.length == 10
    stripped_num
  else
    'Bad Number'
  end
end

def convert_to_hours(reg_date)
  t = Time.strptime(reg_date, '%m/%d/%Y %k:%M')
  t.hour
end

def find_average_hours(csv)
  hours = []
  csv.each do |row|
    reg_date = row[:regdate]
    hours << convert_to_hours(reg_date)
  end
  hours.reduce(0) { |sum, current| sum + current } / hours.length
end

def convert_to_days(reg_date)
  d = Date.strptime(reg_date, '%m/%d/%Y %k:%M')
  d.wday
end

def find_average_day(csv)
  days = []
  csv.each do |row|
    reg_date = row[:regdate]
    days << convert_to_days(reg_date)
  end
  average_day = days.max_by { |day| days.count(day) }
  Date::DAYNAMES[average_day]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  filename = "output/thanks_#{id}.html"
  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_number = clean_phone_number(row[:homephone])
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)
end

p find_average_hours(contents) # 15
p find_average_day(contents) # "Monday"
