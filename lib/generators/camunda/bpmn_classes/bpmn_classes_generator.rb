module Camunda
  module Generators
    # Parses the BPMN file and creates task classes according to the ID of the process file and the ID of
    # each task. It checks each task and only creates it if the topic name is the same as the process ID. This
    # allows one to have some tasks be handled outside the Rails app. It confirms that the ID's are valid Ruby constant names.
    class BpmnClassesGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)
      argument :bpmn_file, type: :string
      class_option :model_path, type: :string, default: 'app/bpmn'

      # @return [String] The id of the BPMN process
      def validate_module_name
        puts "The id of the BPMN process is: #{colored_module_name}. That will be your module name."
        validate_constant_name(module_name)
      end

      # Creates a class name to be used for the task classes created to perform external tasks.
      def validate_class_names
        bpmn_xml.modularized_class_names.each do |class_name|
          validate_constant_name(class_name.demodulize, module_name)
        end
        puts set_color("External tasks with the same topic name as the BPMN id will be created.", :bold)
        colorized_class_names = bpmn_xml.modularized_class_names.map! { |class_name| set_color class_name, :red }
        puts colorized_class_names.join("\n")
      end

      # Creates module names to be used for the task classes to perform external tasks.
      def create_module
        template 'bpmn_module.rb.template', File.join(model_path, "#{module_name.underscore}.rb")
      end

      # Creates the correct classes from the bpmn file to be used in the provided generator template for the classes
      # needed to run external tasks.
      def create_classes
        bpmn_xml.class_names_with_same_bpmn_id_as_topic.each do |class_name|
          template 'bpmn_class.rb.template',
                   File.join(model_path, module_name.underscore, "#{class_name.underscore}.rb"), class_name: class_name
        end
      end

      private

      # Validates constant names by attempting to create a Ruby constant
      def validate_constant_name(name, module_name=nil)
        top_level = module_name.nil? ? Module.new : module_name.constantize
        colorized_name = set_color name, :red
        begin
          Object.const_set(name, top_level)
        rescue NameError
          puts "Cannot create a class/module with name #{colorized_name}. Not a valid name."
          puts "You must set the ID in Camunda to be the name of a Ruby style constant"
        end
        return unless name.include?("_")

        puts "Class name #{colorized_name} should not have an underscore _."
        puts "Underscores are valid Ruby constant names, but likely you have not changed the name from the default."
      end

      def model_path
        options['model_path']
      end

      def module_name
        @module_name ||= bpmn_xml.module_name
      end

      def bpmn_xml
        @bpmn_xml ||= BpmnXML.new(File.open(bpmn_file))
      end

      def colored_module_name
        @colored_module_name ||= set_color module_name, :red
      end
    end
  end
end
