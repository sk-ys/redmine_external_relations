class ExternalRelation < ActiveRecord::Base
  validates_presence_of :issue_to_id, :issue_from_id, :issue_to_app_id, :issue_from_app_id
  validates_numericality_of :issue_to_id, :issue_from_id, :issue_to_app_id, :issue_from_app_id, only_integer: true, greater_than: 0
  validate :validate_issue_external_relation

  belongs_to :issue_from_app, :class_name => 'ExternalRelationApp'
  belongs_to :issue_to_app, :class_name => 'ExternalRelationApp'

  scope :with_app_name, -> do
    issue_from_app = ExternalRelationApp.arel_table.alias('issue_from_app')
    issue_to_app = ExternalRelationApp.arel_table.alias('issue_to_app')

    issue_from_apps = arel_table.join(issue_from_app, Arel::Nodes::OuterJoin)
        .on(issue_from_app[:id].eq arel_table[:issue_from_app_id]).join_sources
    issue_to_apps = arel_table.join(issue_to_app, Arel::Nodes::OuterJoin)
        .on(issue_to_app[:id].eq arel_table[:issue_to_app_id]).join_sources

    joins(issue_from_apps, issue_to_apps).
    select("external_relations.*, "\
           "issue_from_app.app_name as issue_from_app_name, "\
           "issue_to_app.app_name as issue_to_app_name")
  end

  def validate_issue_external_relation
    if issue_from_id && issue_to_id && issue_from_app_id && issue_to_app_id
      if issue_from_app_id == issue_to_app_id && issue_from_id == issue_to_id
        errors.add :base, :invalid
      end

      if not_exist_issue?
        errors.add :base, :invalid
      end

      if duplicate?
        errors.add :base, :invalid
      end
    end
  end

  def duplicate?
    where_str = ""
    where_str << "issue_from_app_id=#{issue_from_app_id} and "
    where_str << "issue_from_id=#{issue_from_id} and "
    where_str << "issue_to_app_id=#{issue_to_app_id} and "
    where_str << "issue_to_id=#{issue_to_id}"
    ExternalRelation.where(where_str).present?
  end

  def not_exist_issue?
    issue = nil
    if issue_from_app_id == 1
      issue = Issue.find_by_id(issue_from_id)
      if issue.present?
        return true unless Project.find_by_id(issue.project_id).module_enabled?(:external_relations)
      else
        return true
      end
    end

    issue = nil
    if issue_to_app_id == 1
      issue = Issue.find_by_id(issue_to_id)
      if issue.present?
        return true unless Project.find_by_id(issue.project_id).module_enabled?(:external_relations)
      else
        return true
      end
    end

    return false
  end
end
