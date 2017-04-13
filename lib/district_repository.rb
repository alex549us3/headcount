require 'pry'
require 'csv'
require_relative 'district'
require_relative 'enrollment_repository'

class DistrictRepository
  attr_reader :districts

  def load_data(args)
    if args[:enrollment]
      er = EnrollmentRepository.new
      er.load_data(args)
    end
    data_set = args[:enrollment][:kindergarten]
    contents = CSV.open(data_set, {headers: true, header_converters: :symbol})
    @districts = contents.collect do |row|
      row[:name] = row[:location]
      District.new(row)
    end
    contents
  end

  def load_format
  end

  def find_by_name(name)
    @districts.find do |district|
      district.name == name
    end
  end

  def find_all_matching(name)
    district_names = @districts.collect do |district|
      district.name.upcase
    end
    district_names.uniq.grep(/#{name}/)
  end
end
