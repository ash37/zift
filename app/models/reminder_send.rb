class ReminderSend < ApplicationRecord
  belongs_to :user
  belongs_to :shift

  KINDS = {
    pre_start_30: 'pre_start_30'
  }.freeze

  validates :kind, inclusion: { in: KINDS.values }
end

