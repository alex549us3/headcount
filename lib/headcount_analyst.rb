require_relative '../lib/district_repository'

class HeadcountAnalyst
  attr_reader :dr

  def initialize(dr)
    @dr = dr
  end

  def average_kindergarten_participation_for_district(name)
    district = @dr.find_by_name(name)
    sum =
    district.enrollment.kindergarten_participation_by_year.reduce(0) do |a, b|
      if b[1] == 'N/A'
        b[1] = 0
      end
      a + b[1]
    end
    average =
      sum / district.enrollment.kindergarten_participation_by_year.length
    (average.to_f*1000).floor/1000.0
  end

  def kindergarten_participation_rate_variation(name, arg)
    district_1 = average_kindergarten_participation_for_district(name)
    district_2 = average_kindergarten_participation_for_district(arg[:against])
    variation = district_1 / district_2
    (variation.to_f*1000).floor/1000.0
  end

  def kindergarten_participation_rate_variation_trend(name, arg)
    district_1 = @dr.find_by_name(name)
    district_1_data = district_1.enrollment.kindergarten_participation_by_year
    district_2 = @dr.find_by_name(arg[:against])
    district_2_data = district_2.enrollment.kindergarten_participation_by_year
    variation = district_1_data.merge(district_2_data) do |key, oldval, newval|
      variation = oldval / newval
      (variation.to_f*1000).floor/1000.0
    end
  end

  def average_high_school_graduation_rates_for_district(name)
    district = @dr.find_by_name(name)
    sum = district.enrollment.graduation_rate_by_year.reduce(0) do |a, b|
      if b[1] == 'N/A'
        b[1] = 0
      end
      a + b[1]
    end
    average = sum / district.enrollment.graduation_rate_by_year.length
    (average.to_f*1000).floor/1000.0
  end

  def high_school_graduation_rate_variation(name, arg)
    district_1 = average_high_school_graduation_rates_for_district(name)
    district_2 =
      average_high_school_graduation_rates_for_district(arg[:against])
    variation = district_1 / district_2
    (variation.to_f*1000).floor/1000.0
  end

  def kindergarten_participation_against_high_school_graduation(name)
    variation = kindergarten_participation_rate_variation(
      name, :against => 'COLORADO') /
    high_school_graduation_rate_variation(name, :against => 'COLORADO')
    variation.round(3)
  end

  def kindergarten_participation_correlates_with_high_school_graduation(arg)
    if arg[:for] == 'STATEWIDE'
      statewide_correlation
    elsif arg[:for]
      district_correlation(arg[:for])
    elsif arg[:across]
      counter = 0
      arg[:across].each do |district|
        variation =
          kindergarten_participation_against_high_school_graduation(district)
        if variation > 0.6 && variation < 1.5
          counter += 1
        end
      end
      percent = counter / arg[:across].length
      if percent >= 0.7
        true
      else
        false
      end
    end
  end

  def district_correlation(state)
    variation =
      kindergarten_participation_against_high_school_graduation(state)
    if variation > 0.6 && variation < 1.5
      true
    else
      false
    end
  end

  def statewide_correlation
    counter = 0
    @dr.districts.each do |district|
      next if district.name == 'COLORADO'
      name = district.name
      variation =
        kindergarten_participation_against_high_school_graduation(name)
      if variation > 0.6 && variation < 1.5
        counter += 1
      end
    end
    percent = counter / (@dr.districts.length - 1)
    if percent >= 0.7
      true
    else
      false
    end
  end

  def top_statewide_test_year_over_year_growth(args)
    if args[:grade] == 3
      if args[:subject].nil?
        if args[:weighting].nil?
          top_statewide_test_year_growth_third_grade_all_subjects(args)
        else
          top_statewide_test_year_growth_third_grade_weighted_validator(args)
        end
      else
        grade_three_year_over_year(args)
      end
    elsif args[:grade] == 8
      if args[:subject].nil?
        if args[:weighting].nil?
          top_statewide_test_year_growth_eighth_grade_all_subjects(args)
        else
          top_statewide_test_year_growth_eighth_grade_weighted_validator(args)
        end
      else
        grade_eight_year_over_year(args)
      end
    elsif args[:grade].nil?
      raise InsufficientInformationError
    else
      raise UnknownDataError
    end
  end

  def grade_three_year_over_year(args)
    districts_growth = []
    @dr.districts.each do |district|
        year_data = district.statewide_test.third_grade.to_a
        top_statewide_test_year_growth_one_subject(
          args, district, districts_growth, year_data)
      end
      select_top_district_or_districts(args, districts_growth)
    end

  def grade_eight_year_over_year(args)
    districts_growth = []
    @dr.districts.each do |district|
      year_data = district.statewide_test.eighth_grade.to_a
      top_statewide_test_year_growth_one_subject(
        args, district, districts_growth, year_data)
    end
    select_top_district_or_districts(args, districts_growth)
  end

  def top_statewide_test_year_growth_one_subject(
    args, district, districts_growth, year_data)
    value = false
    until value
      if year_data.length == 0
        value = true
      elsif year_data[0][1][args[:subject]] == "N/A"
        year_data.slice!(0)
      else
        value = true
      end
    end
    value = false
    until value
      if year_data.length == 0
        value = true
      elsif year_data[-1][1][args[:subject]] == "N/A"
        year_data.slice!(-1)
      else
        value = true
      end
    end
    year_data = year_data.to_h
    if year_data.length > 1
      growth = (year_data.max[1][args[:subject]] -
                year_data.min[1][args[:subject]]) /
                (year_data.max[0] - year_data.min[0])
      districts_growth << [district.name, growth]
    end
  end

  def top_statewide_test_year_growth_third_grade_all_subjects(args)
    districts_growth = []
    @dr.districts.each do |district|
      year_data = district.statewide_test.third_grade.to_a
      top_statewide_test_year_growth_all_subjects_weighted(
        args, year_data, district, districts_growth)
    end
    select_top_district_or_districts(args, districts_growth)
  end



  def top_statewide_test_year_growth_eighth_grade_all_subjects(args)
    districts_growth = []
    @dr.districts.each do |district|
    year_data = district.statewide_test.eighth_grade.to_a
    top_statewide_test_year_growth_all_subjects_weighted(
      args, year_data, district, districts_growth)
    end
    select_top_district_or_districts(args, districts_growth)
  end


  def top_statewide_test_year_growth_third_grade_weighted_validator(args)
    if args[:weighting][:math] +
       args[:weighting][:reading] +
       args[:weighting][:writing] != 1
      raise UnknownDataError
    else
      districts_growth = []
      @dr.districts.each do |district|
      year_data = district.statewide_test.third_grade.to_a
        top_statewide_test_year_growth_all_subjects_weighted(
          args, year_data, district, districts_growth)
      end
      select_top_district_or_districts(args, districts_growth)
    end
  end



  def top_statewide_test_year_growth_eighth_grade_weighted_validator(args)
    if args[:weighting][:math] +
       args[:weighting][:reading] +
       args[:weighting][:writing] != 1
      raise UnknownDataError
    else
      districts_growth = []
      @dr.districts.each do |district|
      year_data = district.statewide_test.eighth_grade.to_a
        top_statewide_test_year_growth_all_subjects_weighted(
          args, year_data, district, districts_growth)
      end
      select_top_district_or_districts(args, districts_growth)
    end
  end


  def top_statewide_test_year_growth_all_subjects_weighted(
    args, year_data, district, districts_growth)
    value = false
    until value
      if year_data.length == 0
        value = true
      elsif year_data[0][1][:math] == "N/A" ||
            year_data[0][1][:reading] == "N/A" ||
            year_data[0][1][:writing] == "N/A"
        year_data.slice!(0)
      else
        value = true
      end
    end
    value = false
    until value
      if year_data.length == 0
        value = true
      elsif year_data[-1][1][:math] == "N/A" ||
            year_data[-1][1][:reading] == "N/A" ||
            year_data[-1][1][:writing] == "N/A"
        year_data.slice!(-1)
      else
        value = true
      end
    end
    year_data = year_data.to_h
    if year_data.length > 1
      math_growth = (year_data.max[1][:math] -
                     year_data.min[1][:math]) /
                (year_data.max[0] - year_data.min[0])
      reading_growth = (year_data.max[1][:reading] -
                        year_data.min[1][:reading]) /
                (year_data.max[0] - year_data.min[0])
      writing_growth = (year_data.max[1][:writing] -
                        year_data.min[1][:writing]) /
                (year_data.max[0] - year_data.min[0])
      growth = (math_growth + reading_growth + writing_growth)/3
      if args[:weighting].nil?
        districts_growth << [district.name, growth] unless unwanted(district)
      else
        weighted_growth = (math_growth * args[:weighting][:math]) +
                          (reading_growth * args[:weighting][:reading]) +
                          (writing_growth * args[:weighting][:writing])
        districts_growth << [district.name, growth, weighted_growth]
      end
    end
   select_top_district_or_districts(args, districts_growth)
  end

  def select_top_district_or_districts(args, districts_growth)
    if args[:top].nil?
      if args[:weighting].nil?
        top = districts_growth.max_by do |district|
          district[1]
        end
      top_district = [top[0], (top[1]*1000).floor/1000.0]
      else
        top = districts_growth.max_by do |district|
          district[2]
        end
      top_district = [top[0], (top[2]*1000).floor/1000.0]
      end
    else
      number = args[:top]
      top_districts = []
      number.times do
        top = districts_growth.max_by do |district|
          district[1]
        end
        best_district = [top[0], (top[1]*1000).floor/1000.0]
        top_districts << best_district
        index_value = districts_growth.index(top)
        districts_growth.slice!(index_value)
      end
      top_districts
    end
  end

  def unwanted(district)
    district.name == "CENTER 26 JT" || district.name == "MANCOS RE-6"
  end

end