class HomeController < ApplicationController
  before_action :authenticate_user!

  def show
    active_members = Member.where(active: true)

    @active_period = FiscalPeriod.find_by(active: true)
    @home_stats = {
      active_members_count: active_members.count,
      meetup_count: Meeting.count,
      book_request_count: BookRequest.count,
      location_count: active_members.where.not(location: [ nil, "" ]).distinct.count(:location)
    }
    @recent_meetups = Meeting.includes(:meeting_attendances).order(meeting_at: :desc).limit(3)
  end
end
