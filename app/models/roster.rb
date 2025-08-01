class Roster < ApplicationRecord
    has_many :shifts
has_many :locations, -> { distinct }, through: :shifts
    # enum status: { draft: 0, published: 1 }
end
