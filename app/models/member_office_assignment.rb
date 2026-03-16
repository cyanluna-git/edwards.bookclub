class MemberOfficeAssignment < ApplicationRecord
  OFFICE_TYPES = {
    "chairperson" => "회장",
    "secretary" => "총무",
    "site_leader" => "지역 리더"
  }.freeze
  GLOBAL_OFFICE_TYPES = %w[chairperson secretary].freeze

  belongs_to :member
  belongs_to :created_by, class_name: "User", optional: true

  normalizes :office_type, :location, with: ->(value) { value&.strip }

  validates :office_type, :effective_from, presence: true
  validates :office_type, inclusion: { in: OFFICE_TYPES.keys }
  validates :source_key, uniqueness: { scope: :source_system }, allow_nil: true
  validate :effective_to_on_or_after_effective_from
  validate :location_matches_office_type
  validate :non_overlapping_assignment_window

  scope :ordered, -> { order(effective_from: :desc, id: :desc) }
  scope :effective_on, lambda { |date|
    where("effective_from <= ? AND (effective_to IS NULL OR effective_to >= ?)", date, date)
  }
  scope :for_scope, lambda { |office_type, location = nil|
    relation = where(office_type:)
    location.present? ? relation.where(location:) : relation.where(location: nil)
  }

  def global_office?
    office_type.in?(GLOBAL_OFFICE_TYPES)
  end

  def site_leader?
    office_type == "site_leader"
  end

  def office_name
    OFFICE_TYPES.fetch(office_type, office_type)
  end

  def display_label
    return office_name if location.blank?

    "#{office_name} · #{location}"
  end

  def active_on?(date)
    effective_from <= date && (effective_to.blank? || effective_to >= date)
  end

  private

  def effective_to_on_or_after_effective_from
    return if effective_from.blank? || effective_to.blank?
    return if effective_to >= effective_from

    errors.add(:effective_to, "must be on or after the effective from date")
  end

  def location_matches_office_type
    if site_leader? && location.blank?
      errors.add(:location, "must be present for site leader assignments")
    elsif global_office? && location.present?
      errors.add(:location, "must be blank for global office assignments")
    end
  end

  def non_overlapping_assignment_window
    return if office_type.blank? || effective_from.blank?
    return if site_leader? && location.blank?

    overlapping_assignment = self.class
      .where(office_type:)
      .where(location: normalized_scope_location)
      .where.not(id:)
      .any? do |assignment|
        start_a = effective_from
        finish_a = effective_to || Date::Infinity.new
        start_b = assignment.effective_from
        finish_b = assignment.effective_to || Date::Infinity.new

        start_a <= finish_b && start_b <= finish_a
      end

    scope_label = location.presence || office_name
    errors.add(:base, "effective dates overlap an existing assignment for #{scope_label}") if overlapping_assignment
  end

  def normalized_scope_location
    global_office? ? nil : location
  end
end
