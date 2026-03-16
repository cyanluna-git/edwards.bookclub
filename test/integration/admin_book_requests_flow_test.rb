require "test_helper"

class AdminBookRequestsFlowTest < ActionDispatch::IntegrationTest
  setup do
    [MeetingPhoto, MeetingAttendance, Meeting, BookRequest, User, Member, ReservePolicy, FiscalPeriod].each(&:delete_all)

    @period = FiscalPeriod.create!(name: "FY2026", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 12, 31), active: true)
    @member = Member.create!(english_name: "Hannah Lee", member_role: "정회원", location: "천안", active: true)
    @leader = Member.create!(english_name: "Gerald Park", member_role: "Lead:총무", location: "분당", active: true)
    ReservePolicy.create!(member_role: "정회원", attendance_points: 5000, effective_from: @period.start_date, effective_to: @period.end_date)
    ReservePolicy.create!(member_role: "Lead", attendance_points: 10000, effective_from: @period.start_date, effective_to: @period.end_date)

    meeting = Meeting.create!(title: "Reserve Meetup", meeting_at: Time.zone.parse("2026-03-12 19:00"), fiscal_period: @period)
    MeetingAttendance.create!(meeting:, member: @member, reserve_exempt: false)
    MeetingAttendance.create!(meeting:, member: @leader, reserve_exempt: false)

    @book_request = BookRequest.create!(
      member: @member,
      fiscal_period: @period,
      title: "Thinking in Systems",
      author: "Donella Meadows",
      request_status: "Approved",
      price: 18000,
      additional_payment: 3000,
      requested_on: Date.new(2026, 3, 1)
    )

    @admin = User.create!(email: "admin@example.com", password: "secret123", password_confirmation: "secret123", role: "admin")
    @member_user = User.create!(email: "member@example.com", password: "secret123", password_confirmation: "secret123", role: "member", member: @member)
  end

  test "admin can filter requests and see reserve snapshot" do
    sign_in_as(@admin)

    get admin_book_requests_path, params: { member_id: @member.id, request_status: "Approved", fiscal_period_id: @period.id, requested_from: "2026-03-01", requested_to: "2026-03-31" }

    assert_response :success
    assert_match "Thinking in Systems", response.body
    assert_match "Reserve balance", response.body
    assert_match "KRW 15,000", response.body
  end

  test "admin can create and update a book request" do
    sign_in_as(@admin)

    post admin_book_requests_path, params: {
      book_request: {
        member_id: @leader.id,
        fiscal_period_id: @period.id,
        title: "Deep Work",
        author: "Cal Newport",
        publisher: "Grand Central",
        request_status: "Requested",
        price: "22000",
        additional_payment: "2000",
        requested_on: "2026-04-01",
        rating: "5",
        comment: "Strong recommendation",
        link_url: "https://example.com/deep-work",
        cover_url: "https://example.com/deep-work.jpg"
      }
    }

    created = BookRequest.find_by!(title: "Deep Work")
    assert_redirected_to admin_book_request_path(created)

    patch admin_book_request_path(created), params: {
      book_request: {
        request_status: "Purchased",
        price: "25000",
        additional_payment: "5000",
        comment: "Purchased for April"
      }
    }

    assert_redirected_to admin_book_request_path(created)
    created.reload
    assert_equal "Purchased", created.request_status
    assert_equal BigDecimal("25000"), created.price
    assert_equal BigDecimal("5000"), created.additional_payment
  end

  test "member users cannot access book request admin screens" do
    sign_in_as(@member_user)

    get admin_book_requests_path

    assert_redirected_to root_path
  end

  test "show page exposes reserve-relevant fields" do
    sign_in_as(@admin)

    get admin_book_request_path(@book_request)

    assert_response :success
    assert_match "Net cash effect", response.body
    assert_match "Donella Meadows", response.body
    assert_match "Approved", response.body
  end

  private

  def sign_in_as(user)
    post session_path, params: { email: user.email, password: "secret123" }
    follow_redirect!
  end
end
