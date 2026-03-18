module Admin
  class MeetingsController < BaseController
    before_action :set_meeting, only: %i[show edit update destroy]
    before_action :load_options, only: %i[index show new create edit update]

    def index
      @meetings = Meeting.includes(:fiscal_period, :meeting_attendances, :meeting_photos).ordered_recent
    end

    def show
      @attendances = @meeting.meeting_attendances.includes(:member).order(:created_at, :id).to_a
      @photos = @meeting.meeting_photos.order(:sort_order, :id).to_a
      @attendance = @meeting.meeting_attendances.build(reserve_exempt: false)
      @photo = @meeting.meeting_photos.build(sort_order: next_photo_sort_order)
      @available_members = available_members_for(@meeting)
    end

    def new
      @meeting = Meeting.new(meeting_at: Time.zone.now.change(min: 0), reserve_exempt_default: false)
    end

    def create
      @meeting = Meeting.new(meeting_params)
      @meeting.created_by ||= current_user
      @meeting.reserve_exempt_default ||= false
      auto_assign_fiscal_period(@meeting)

      if @meeting.save
        sync_attendees(@meeting)
        redirect_to admin_meeting_path(@meeting), notice: "Meetup created successfully."
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
        redirect_to admin_meeting_path(@meeting), notice: "Meetup updated successfully."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @meeting.destroy!
      redirect_to admin_meetings_path, notice: "Meeting deleted."
    end

    private

    def set_meeting
      @meeting = Meeting.includes(:fiscal_period, :created_by, :meeting_photos, meeting_attendances: :member).find(params[:id])
    end

    def meeting_params
      params.require(:meeting).permit(:title, :meeting_at, :location, :review, member_ids: [], meeting_photos_attributes: [ :image, :caption, :sort_order ])
    end

    def sync_attendees(meeting)
      submitted_ids = (params.dig(:meeting, :member_ids) || []).map(&:to_i).reject(&:zero?)
      existing_ids = meeting.meeting_attendances.pluck(:member_id)

      # Add new
      (submitted_ids - existing_ids).each do |mid|
        meeting.meeting_attendances.create!(member_id: mid, reserve_exempt: false)
      end

      # Remove unchecked
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

    def available_members_for(meeting)
      taken_ids = meeting.meeting_attendances.pluck(:member_id)
      Member.where(active: true).where.not(id: taken_ids).ordered
    end

    def next_photo_sort_order
      @meeting.meeting_photos.maximum(:sort_order).to_i + 1
    end
  end
end
