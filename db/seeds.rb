# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
# Seed the initial operating baseline inferred from the PBIX report.
active_period = FiscalPeriod.find_or_create_by!(name: "FY2026") do |period|
  period.start_date = Date.new(2026, 1, 1)
  period.end_date = Date.new(2026, 12, 31)
  period.active = true
end

ReservePolicy.find_or_create_by!(member_role: "정회원", effective_from: active_period.start_date) do |policy|
  policy.attendance_points = 5_000
  policy.effective_to = active_period.end_date
end

["Lead", "Lead:총무"].each do |role_name|
  ReservePolicy.find_or_create_by!(member_role: role_name, effective_from: active_period.start_date) do |policy|
    policy.attendance_points = 10_000
    policy.effective_to = active_period.end_date
  end
end

admin_email = ENV.fetch("BOOKCLUB_ADMIN_EMAIL", "admin@edwards-bookclub.local")
admin_password = ENV.fetch("BOOKCLUB_ADMIN_PASSWORD", "changeme123!")

User.find_or_create_by!(email: admin_email) do |user|
  user.role = "admin"
  user.password = admin_password
  user.password_confirmation = admin_password
end
