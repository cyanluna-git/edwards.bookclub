require "test_helper"

class MemberPortalFlowTest < ActionDispatch::IntegrationTest
  setup do
    [MeetingPhoto, MeetingAttendance, Meeting, MemberOfficeAssignment, BookRequest, User, Member, ReservePolicy, FiscalPeriod].each(&:delete_all)

    @period = FiscalPeriod.create!(name: "FY2026", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 12, 31), active: true)
    ReservePolicy.create!(member_role: "정회원", attendance_points: 5000, effective_from: @period.start_date, effective_to: @period.end_date)

    @member = Member.create!(english_name: "Hannah Lee", korean_name: "이현아", member_role: "정회원", location: "천안", active: true)
    @other_member = Member.create!(english_name: "Gerald Park", member_role: "Lead", active: true)
    meeting = Meeting.create!(title: "March Meetup", meeting_at: Time.zone.parse("2026-03-12 19:00"), location: "천안", fiscal_period: @period, review: "Great discussion")
    MeetingAttendance.create!(meeting:, member: @member, reserve_exempt: false)
    MeetingPhoto.create!(meeting:, source_url: "https://example.com/march.jpg", caption: "March", sort_order: 1)

    @book_request = BookRequest.create!(member: @member, fiscal_period: @period, title: "Thinking in Systems", request_status: "Approved", price: 18000, additional_payment: 3000, requested_on: Date.new(2026, 3, 1))
    @other_request = BookRequest.create!(member: @other_member, fiscal_period: @period, title: "Deep Work", request_status: "Requested", requested_on: Date.new(2026, 3, 2))

    @member_user = User.create!(email: "member@example.com", password: "secret123", password_confirmation: "secret123", role: "member", member: @member)
    @orphan_user = User.create!(email: "orphan@example.com", password: "secret123", password_confirmation: "secret123", role: "member")
    @admin = User.create!(email: "admin@example.com", password: "secret123", password_confirmation: "secret123", role: "admin")
  end

  test "member sees only their own dashboard data" do
    sign_in_as(@member_user)

    get member_root_path

    assert_response :success
    assert_match "Your book club space", response.body
    assert_match "KRW 5,000", response.body
    assert_match "March Meetup", response.body
    assert_no_match "Deep Work", response.body
    assert_no_match "Manage members", response.body
  end

  test "member can create and update their own book request" do
    sign_in_as(@member_user)

    post member_book_requests_path, params: {
      book_request: {
        title: "Atomic Habits",
        author: "James Clear",
        publisher: "Avery",
        requested_on: "2026-04-01",
        rating: "5",
        comment: "Worth discussing",
        link_url: "https://example.com/atomic-habits",
        fiscal_period_id: @period.id
      }
    }

    created = @member.book_requests.find_by!(title: "Atomic Habits")
    assert_redirected_to member_book_request_path(created)

    patch member_book_request_path(created), params: {
      book_request: {
        comment: "Updated note",
        rating: "4"
      }
    }

    created.reload
    assert_equal "Updated note", created.comment
    assert_equal "4", created.rating
    assert_equal "Requested", created.request_status
  end

  test "member can delete their own book request" do
    sign_in_as(@member_user)

    assert_difference -> { @member.book_requests.count }, -1 do
      delete member_book_request_path(@book_request)
    end

    assert_redirected_to member_book_requests_path
    follow_redirect!
    assert_match "Book request deleted successfully.", response.body
  end

  test "member can search aladin and prefill their request form" do
    sign_in_as(@member_user)

    lookup = Integrations::Aladin::BookSearch::Result.new(
      enabled: true,
      query: "Deep Work",
      items: [
        Integrations::Aladin::BookSearch::Item.new(
          title: "Deep Work",
          author: "Cal Newport",
          publisher: "Grand Central",
          price_sales: BigDecimal("22000"),
          cover_url: "https://example.com/deep-work.jpg",
          link_url: "https://www.aladin.co.kr/shop/wproduct.aspx?ItemId=2"
        )
      ],
      error_message: nil
    )

    with_aladin_lookup(lookup) do
      get new_member_book_request_path, params: { aladin_query: "Deep Work" }
    end

    assert_response :success
    assert_match "Search Aladin", response.body
    assert_match "Deep Work", response.body

    get new_member_book_request_path, params: {
      prefill: {
        title: "Deep Work",
        author: "Cal Newport",
        publisher: "Grand Central",
        price: "22000",
        cover_url: "https://example.com/deep-work.jpg",
        link_url: "https://www.aladin.co.kr/shop/wproduct.aspx?ItemId=2"
      }
    }

    assert_response :success
    assert_match 'value="Deep Work"', response.body
    assert_match 'value="Cal Newport"', response.body
    assert_match 'value="Grand Central"', response.body
    assert_match 'value="22000"', response.body
    assert_match @member.display_name, response.body
  end

  test "member cannot access another members request" do
    sign_in_as(@member_user)

    get member_book_request_path(@other_request)

    assert_response :not_found
  end

  test "member request pages tolerate legacy non-url cover values" do
    sign_in_as(@member_user)
    @book_request.update!(cover_url: "[Record]")

    get member_book_requests_path
    assert_response :success

    get member_book_request_path(@book_request)
    assert_response :success
  end

  test "orphan member user is handled safely" do
    sign_in_as(@orphan_user)

    get member_root_path

    assert_response :success
    assert_match "No linked member profile", response.body

    get member_book_requests_path

    assert_redirected_to member_root_path
  end

  test "admins are redirected away from member portal" do
    sign_in_as(@admin)

    get member_root_path

    assert_redirected_to admin_dashboard_path
  end

  test "chairperson managers are redirected away from member portal" do
    chairperson_member = Member.create!(english_name: "Gerald Park", member_role: "정회원", active: true)
    chairperson_member.member_office_assignments.create!(office_type: "chairperson", effective_from: @period.start_date)
    chairperson_user = User.create!(email: "gerald.park@edwardsvacuum.com", password: "alskqp10", password_confirmation: "alskqp10", role: "member", member: chairperson_member)

    sign_in_as(chairperson_user, password: "alskqp10")

    get member_root_path

    assert_redirected_to admin_dashboard_path
  end

  private

  def sign_in_as(user, password: "secret123")
    post session_path, params: { email: user.email, password: password }
    follow_redirect!
  end

  def with_aladin_lookup(result)
    original = Integrations::Aladin::BookSearch.method(:call)
    Integrations::Aladin::BookSearch.define_singleton_method(:call) { |**| result }
    yield
  ensure
    Integrations::Aladin::BookSearch.define_singleton_method(:call) { |**kwargs| original.call(**kwargs) }
  end
end
