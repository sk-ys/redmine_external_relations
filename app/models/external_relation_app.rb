class ExternalRelationApp < ActiveRecord::Base
  validates_presence_of :app_name, :app_title
  validates_uniqueness_of :app_name

  has_many :issue_from_apps, :class_name => 'ExternalRelation', :foreign_key => 'issue_from_app_id', :dependent => :delete_all
  has_many :issue_to_apps, :class_name => 'ExternalRelation', :foreign_key => 'issue_to_app_id', :dependent => :delete_all

  def deletable?
    id != 1
  end

  def editable?
    if id == 1
      return app_name == "local"
    else
      return true
    end
  end
end
