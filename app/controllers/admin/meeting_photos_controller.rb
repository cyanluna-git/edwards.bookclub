module Admin
  class MeetingPhotosController < BaseController
    before_action :set_meeting
    before_action :set_photo, only: %i[update destroy]

    def create
      photo = @meeting.meeting_photos.build(photo_params)

      if photo.save
        redirect_to admin_meeting_path(@meeting), notice: "Photo record added."
      else
        redirect_to admin_meeting_path(@meeting), alert: photo.errors.full_messages.to_sentence
      end
    end

    def update
      if @photo.update(photo_params)
        redirect_to admin_meeting_path(@meeting), notice: "Photo record updated."
      else
        redirect_to admin_meeting_path(@meeting), alert: @photo.errors.full_messages.to_sentence
      end
    end

    def destroy
      @photo.destroy!
      redirect_to admin_meeting_path(@meeting), notice: "Photo record removed."
    end

    private

    def set_meeting
      @meeting = Meeting.find(params[:meeting_id])
    end

    def set_photo
      @photo = @meeting.meeting_photos.find(params[:id])
    end

    def photo_params
      params.require(:meeting_photo).permit(:source_url, :file_path, :caption, :sort_order)
    end
  end
end
