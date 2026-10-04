class Project < ApplicationRecord
  include BulletList

  belongs_to :profile
end
