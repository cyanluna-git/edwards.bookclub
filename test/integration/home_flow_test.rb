require "test_helper"

class HomeFlowTest < ActionDispatch::IntegrationTest
  setup do
    [ MeetingPhoto, MeetingAttendance, Meeting, BookRequest, User, Member, ReservePolicy, FiscalPeriod ].each(&:delete_all)

    @period = FiscalPeriod.create!(
      name: "FY2026",
      start_date: Date.new(2026, 1, 1),
      end_date: Date.new(2026, 12, 31),
      active: true
    )
    @member = Member.create!(
      english_name: "Hannah Lee",
      korean_name: "이한나",
      member_role: "정회원",
      location: "동탄",
      active: true,
      email: "hannah@example.com"
    )
    @guest = Member.create!(
      english_name: "Gerald Park",
      member_role: "Lead",
      location: "천안",
      active: true,
      email: "gerald@example.com"
    )
    meeting = Meeting.create!(
      title: "March Meetup",
      meeting_at: Time.zone.parse("2026-03-12 19:00"),
      location: "천안",
      fiscal_period: @period,
      review: "Good energy"
    )
    MeetingAttendance.create!(meeting:, member: @member, reserve_exempt: false)
    MeetingAttendance.create!(meeting:, member: @guest, reserve_exempt: false)
    BookRequest.create!(
      member: @member,
      fiscal_period: @period,
      title: "Thinking in Systems",
      price: 18000,
      additional_payment: 3000,
      requested_on: Date.new(2026, 3, 1)
    )

    @user = User.create!(
      email: "member@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      role: "member",
      member: @member
    )
  end

  test "home page renders introduction sections and stats" do
    sign_in_as(@user)

    get root_path

    assert_response :success
    assert_match "Edwards 독서동호회", response.body
    assert_match "책을 좋아하는 사람들이 함께 읽고 만나고 기록하는 모임", response.body
    assert_match "이곳은 어떤 모임인가요?", response.body
    assert_match "독서동호회에서 자주 쓰는 기능", response.body
    assert_match "도서 신청", response.body
    assert_match "적립금 확인", response.body
    assert_match "모임 등록과 출석 기록", response.body
    assert_match "이용 흐름", response.body
    assert_match "자주 묻는 질문", response.body
    assert_match "Quick guide", response.body
    assert_match "March Meetup", response.body
    assert_match "FY2026", response.body
    assert_no_match "소개 페이지", response.body
  end

  private

  def sign_in_as(user)
    post session_path, params: { email: user.email, password: "secret123" }
    follow_redirect!
  end
end
