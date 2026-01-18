class Project < ApplicationRecord
  has_many :project_members, dependent: :destroy
  has_many :users, through: :project_members
  has_many :videos, dependent: :destroy
  has_many :comments, dependent: :destroy

  validates :name, presence: true
end
