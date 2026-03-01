class Message < ApplicationRecord
  belongs_to :conversation, optional: true
end
