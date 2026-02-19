class CommentSnapshot < ApplicationRecord
  belongs_to :comment

  def readonly?
    persisted?
  end
end
