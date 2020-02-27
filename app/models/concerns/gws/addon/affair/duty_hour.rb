module Gws::Addon::Affair::DutyHour
  extend ActiveSupport::Concern
  extend SS::Addon

  included do
    embeds_ids :duty_hours, class_name: 'Gws::Affair::DutyHour'
    permit_params duty_hour_ids: []
  end

  def default_duty_hour
    duty_hours.first || Gws::Affair::DefaultDutyHour.new(cur_site: @cur_site || site)
  end

  # _date は現在は使用していない。将来のシフト勤務サポートのためにある。
  def effective_duty_hour(_date)
    default_duty_hour
  end

  def calc_attendance_date(time = Time.zone.now)
    effective_duty_hour(time).calc_attendance_date(time)
  end

  def affair_start(time)
    effective_duty_hour(time).affair_start(time)
  end

  def affair_end(time)
    effective_duty_hour(time).affair_end(time)
  end

  def affair_next_changed(time)
    effective_duty_hour(time).affair_next_changed(time)
  end

  def night_time_start(time)
    effective_duty_hour(time).night_time_start(time)
  end

  def night_time_end(time)
    effective_duty_hour(time).night_time_end(time)
  end
end