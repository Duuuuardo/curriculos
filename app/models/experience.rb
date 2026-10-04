class Experience < ApplicationRecord
  include BulletList

  belongs_to :profile
end
