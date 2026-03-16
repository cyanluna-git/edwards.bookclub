module Admin
  class MeetingAttendancesController < BaseController
    before_action :set_meeting
    before_action :set_attendance, only: %i[update destroy]

    def create
      attendance = @meeting.meeting_attendances.build(attendance_params)

      if attendance.save
        redirect_to admin_meeting_path(@meeting), notice: "Attendee added."
      else
        redirect_to admin_meeting_path(@meeting), alert: attendance.errors.full_messages.to_sentence
      end
    end

    def update
      if @attendance.update(attendance_params)
        redirect_to admin_meeting_path(@meeting), notice: "Attendance updated."
      else
        redirect_to admin_meeting_path(@meeting), alert: @attendance.errors.full_messages.to_sentence
      end
    end

    def destroy
      @attendance.destroy!
      redirect_to admin_meeting_path(@meeting), notice: "Attendee removed."
    end

    private

    def set_meeting
      @meeting = Meeting.find(params[:meeting_id])
    end

    def set_attendance
      @attendance = @meeting.meeting_attendances.find(params[:id])
    end

    def attendance_params
      params.require(:meeting_attendance).permit(:member_id, :reserve_exempt, :override_points, :note)
    end
  end
end
