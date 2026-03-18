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

      if @meeting.save
        redirect_to admin_meeting_path(@meeting), notice: "Meeting created successfully."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @meeting.update(meeting_params)
        redirect_to admin_meeting_path(@meeting), notice: "Meeting updated successfully."
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
      params.require(:meeting).permit(:title, :legacy_title, :meeting_at, :location, :description, :review, :reserve_exempt_default, :fiscal_period_id, meeting_photos_attributes: [ :image, :caption, :sort_order ])
    end

    def load_options
      @fiscal_period_options = FiscalPeriod.order(start_date: :desc)
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
