module Intrigue
module Entity
class File < Intrigue::Model::Entity

  def self.metadata
    {
      :name => "File",
      :description => "A Local File",
      :user_creatable => false
    }
  end

  def validate_entity
    name =~ /^\w.*$/
  end

  def enrichment_tasks
    ["enrich/file"]
  end

end
end
end
