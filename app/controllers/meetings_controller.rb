class MeetingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_meeting, only: %i[show edit update]
  before_action :authorize_owner!, only: %i[edit update]
  before_action :load_options, only: %i[new create edit update]

  def index
    @meetings = Meeting.includes(:fiscal_period, :meeting_attendances, :meeting_photos).ordered_recent
  end

  def show
    @attendances = @meeting.meeting_attendances.includes(:member).order(:created_at, :id).to_a
    @photos = @meeting.meeting_photos.order(:sort_order, :id).to_a
  end

  def new
    @meeting = Meeting.new(meeting_at: Time.zone.now.change(min: 0), reserve_exempt_default: false)
  end

  def create
    @meeting = Meeting.new(meeting_params)
    @meeting.created_by = current_user
    @meeting.reserve_exempt_default ||= false
    auto_assign_fiscal_period(@meeting)

    if @meeting.save
      sync_attendees(@meeting)
      redirect_to meeting_path(@meeting), notice: "Meetup created successfully."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    @meeting.assign_attributes(meeting_params)
    auto_assign_fiscal_period(@meeting)

    if @meeting.save
      sync_attendees(@meeting)
      redirect_to meeting_path(@meeting), notice: "Meetup updated successfully."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_meeting
    @meeting = Meeting.includes(:fiscal_period, :created_by, :meeting_photos, meeting_attendances: :member).find(params[:id])
  end

  def authorize_owner!
    return if can_manage_club? || @meeting.created_by == current_user

    redirect_to meeting_path(@meeting), alert: "You can only edit meetups you created."
  end

  def meeting_params
    params.require(:meeting).permit(:title, :meeting_at, :location, :review, member_ids: [], meeting_photos_attributes: [:image, :caption, :sort_order])
  end

  def sync_attendees(meeting)
    submitted_ids = (params.dig(:meeting, :member_ids) || []).map(&:to_i).reject(&:zero?)
    existing_ids = meeting.meeting_attendances.pluck(:member_id)

    (submitted_ids - existing_ids).each do |mid|
      meeting.meeting_attendances.create!(member_id: mid, reserve_exempt: false)
    end

    meeting.meeting_attendances.where(member_id: existing_ids - submitted_ids).destroy_all
  end

  def auto_assign_fiscal_period(meeting)
    return if meeting.meeting_at.blank?

    period = FiscalPeriod.where("start_date <= ? AND end_date >= ?", meeting.meeting_at, meeting.meeting_at).first
    period ||= FiscalPeriod.find_by(active: true)
    meeting.fiscal_period = period
  end

  def load_options
    @fiscal_period_options = FiscalPeriod.order(start_date: :desc)
    @members_by_location = Member.where(active: true).ordered.group_by { |m| m.location.presence || "미정" }
  end
end
