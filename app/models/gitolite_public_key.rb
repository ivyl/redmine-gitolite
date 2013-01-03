require 'open3'

class GitolitePublicKey < ActiveRecord::Base
  STATUS_ACTIVE = 1
  STATUS_LOCKED = 0

  belongs_to :user
  validates_uniqueness_of :title, :scope => :user_id
  validates_uniqueness_of :identifier, :score => :user_id
  validates_presence_of :title, :key, :identifier
  
  named_scope :active, {:conditions => {:active => GitolitePublicKey::STATUS_ACTIVE}}
  named_scope :inactive, {:conditions => {:active => GitolitePublicKey::STATUS_LOCKED}}
  
  validate :has_not_been_changed, :is_valid_key
  
  before_validation :set_identifier
  
  def has_not_been_changed
    unless new_record?
      %w(identifier key user_id).each do |attribute|
        errors.add(attribute, 'may not be changed') unless changes[attribute].blank?
      end
    end
  end

  def is_valid_key
    valid = check_key(key)
    if !valid
      begin
        key = "#{key}\n"
        valid = check_key(key)
        if !valid
          errors[:base] = "invalid key"
        else
          self.key = key
        end
      rescue
        errors[:key] = "invalid key"
      end
    end
  end

  def check_key(key)
    File.open('/tmp/check_key', 'w') {|f| f.write(key)}
    stdin, stdout, stderr = Open3.popen3('ssh-keygen -l -f /tmp/check_key')
    data = stdout.gets()
    hash_regex = /([0-9a-f][0-9a-f](:[0-9a-f][0-9a-f])+)/
    matching = hash_regex.match data
    File.delete('/tmp/check_key')
    if matching == nil
      false
    else
      true
    end
  end
  
  def set_identifier
    self.identifier ||= "#{self.user.login.underscore}@#{self.title.underscore}".gsub(/[^0-9a-zA-Z-_]/,'_')
  end
    
  def to_s ; title ; end
  
  def location
    self.title.underscore.gsub(/[^0-9a-zA-Z-_]/,'_')
  end
  
  def owner
    self.user.login.underscore.gsub(/[^0-9a-zA-Z-_]/,'_')
  end
end
