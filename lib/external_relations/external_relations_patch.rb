module ExternalRelations

  module ExternalRelationsPatch
    def self.install
      IssuesController.class_eval do
        helper :external_relation_items
      end
    end
  end

  module BulkUpdateWithExrelsToIssuesControllerPatch
    module PrependMethods
      def bulk_update
        super
        bulk_update_with_exrels
      end
    end

    def self.install
      IssuesController.class_eval do
        helper :external_relations
        include ExternalRelationsHelper

        def bulk_update_with_exrels
          @issues.each{|issue|
            Thread.start do
              call_update_issue(issue.id)
            end
          }
        end

        if self.respond_to?(:alias_method_chain) # Rails < 5
          alias_method_chain :bulk_update, :exrels
        else # Rails >= 5
          alias_method :bulk_update_without_exrels, :bulk_update
          prepend PrependMethods
        end
      end
    end
  end

  module DestroyWithExrelsToIssuesControllerPatch
    module PrependMethods
      def destroy
        super
        destroy_with_exrels
      end
    end

    def self.install
      IssuesController.class_eval do
        helper :external_relations
        include ExternalRelationsHelper

        def destroy_with_exrels
          issue_ids = (params[:id] || params[:ids])
          issue_ids = [issue_ids] unless issue_ids.instance_of?(Array)
          issue_ids.each{ |issue_id|
            if Issue.find_by(id: issue_id).nil?
              Thread.start do
                call_delete_issue(issue_id)
              end
            end
          }
        end

        if self.respond_to?(:alias_method_chain) # Rails < 5
          alias_method_chain :destroy, :exrels
        else # Rails >= 5
          alias_method :destroy_without_exrels, :destroy
          prepend PrependMethods
        end
      end
    end
  end
end
