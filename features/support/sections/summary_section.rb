module Sections
  class SummarySection
    include Virtus.value_object

    values do
      attribute :title, String
      attribute :status, String
    end

    def self.from_element(build_element)
      status_classes = {
        'text-success' => 'success',
        'text-danger'  => 'failed',
        'text-warning' => 'n/a',
      }

      status_class = build_element.find('.status')[:class].split.last
      new(
        title:  build_element.find('.title').text,
        status: status_classes.fetch(status_class),
      )
    end
  end
end